/**
 * forge-runtime.ts — Effect runtime setup for FORGE/iOS.
 * Per spec section 4.2.
 *
 * Creates an Effect Layer system with iOS-specific implementations
 * and returns a runtime object with processInput(), getTUIComponent(), destroy().
 */

import { ForgeTerminalSurface } from './forge-terminal-surface.js';
import { FORGE_IDENTITY, FORGE_IDENTITY_SHORT } from './forge-identity.js';

// --- Types ---

export interface ForgeNativeBridge {
  call(method: string, ...args: any[]): Promise<any>;
  output(text: string): void;
  error(text: string): void;
  renderFrame?(grid: any[][]): void;
  ready(): void;
  exit(code: number): void;
  getTerminalSize?(): { cols: number; rows: number };
  getMemoryUsage?(): Record<string, number>;
  getAvailableMemory?(): number;
  sandboxPath?: string;
  cwd?: string;
  uptime?: number;
}

export interface ForgeConfig {
  disableVanillaAgents: boolean;
  defaultAgent: string;
  maxIterations: number;
  batteryAware: boolean;
  offlineMode: boolean;
  cacheEnabled: boolean;
  identity: string;
  providers?: ProviderConfig[];
  plugins?: string[];
}

export interface ProviderConfig {
  id: string;
  name: string;
  baseURL?: string;
  apiKey?: string;
  models: Array<{ id: string; name: string; contextWindow?: number; maxTokens?: number }>;
}

export interface ForgeRuntime {
  processInput(input: string): Promise<string>;
  getTUIComponent(): any;
  destroy(): void;
  getStatus(): ForgeRuntimeStatus;
}

export interface ForgeRuntimeStatus {
  initialized: boolean;
  running: boolean;
  iterations: number;
  lastInput: string | null;
  lastOutput: string | null;
  uptime: number;
  memoryUsage: Record<string, number>;
}

// --- Layer system (simplified Effect-compatible) ---

interface EffectLayer<A> {
  readonly key: symbol;
  readonly build: () => A;
}

class LayerRegistry {
  private layers: Map<symbol, any> = new Map();

  add<A>(layer: EffectLayer<A>): void {
    this.layers.set(layer.key, layer.build());
  }

  get<A>(key: symbol): A | undefined {
    return this.layers.get(key);
  }

  has(key: symbol): boolean {
    return this.layers.has(key);
  }

  build(): Record<symbol, any> {
    return Object.fromEntries(this.layers);
  }
}

export function createForgeLayer(): symbol {
  return Symbol('forge-layer');
}

// --- Runtime implementation ---

export function initializeForgeRuntime(
  config: ForgeConfig,
  tridentPlugin: any,
  nativeBridge: ForgeNativeBridge,
): ForgeRuntime {
  const terminalSurface = new ForgeTerminalSurface(
    nativeBridge.getTerminalSize?.().cols ?? 80,
    nativeBridge.getTerminalSize?.().rows ?? 24,
  );

  const layerRegistry = new LayerRegistry();
  const startTime = Date.now();

  let running = false;
  let iterations = 0;
  let lastInput: string | null = null;
  let lastOutput: string | null = null;
  const sessionStore: Map<string, any> = new Map();
  const pluginRegistry: Map<string, any> = new Map();
  const agentRegistry: Map<string, any> = new Map();
  const providerRegistry: Map<string, any> = new Map();
  let initialized = false;

  // --- Initialize layers ---

  layerRegistry.add<ForgeTerminalSurface>({
    key: Symbol('terminal'),
    build: () => terminalSurface,
  });

  layerRegistry.add<ForgeNativeBridge>({
    key: Symbol('native'),
    build: () => nativeBridge,
  });

  layerRegistry.add<ForgeConfig>({
    key: Symbol('config'),
    build: () => config,
  });

  // --- Set up input handler ---

  const inputHandler = async (input: string): Promise<string> => {
    if (running) {
      terminalSurface.write('[BUSY] Previous request still processing...\n');
      return '[BUSY]';
    }

    running = true;
    iterations++;
    lastInput = input;

    try {
      const result = await processWithAgent(input);
      lastOutput = result;
      running = false;
      return result;
    } catch (err: any) {
      const errorMsg = err?.message ?? String(err);
      terminalSurface.write('[ERROR] ' + errorMsg + '\n');
      lastOutput = '[ERROR] ' + errorMsg;
      running = false;
      throw err;
    }
  };

  // Wire up the native input handler
  const globalAny = globalThis as any;
  if (globalAny.window) {
    globalAny.window.__forgeOnInput = inputHandler;
  }

  // --- Process input through the agent pipeline ---

  async function processWithAgent(input: string): Promise<string> {
    // Check if trident plugin has a process function
    if (tridentPlugin?.process) {
      const context = {
        input,
        config,
        terminal: terminalSurface,
        native: nativeBridge,
        identity: FORGE_IDENTITY,
        sessionStore,
        pluginRegistry,
        agentRegistry,
        providerRegistry,
      };

      const result = await tridentPlugin.process(input, context);
      return typeof result === 'string' ? result : JSON.stringify(result);
    }

    // Fallback: direct agent processing
    if (tridentPlugin?.defaultAgent?.process) {
      const context = {
        input,
        config,
        terminal: terminalSurface,
        native: nativeBridge,
      };
      const result = await tridentPlugin.defaultAgent.process(input, context);
      return typeof result === 'string' ? result : JSON.stringify(result);
    }

    // Ultimate fallback
    const fallback = '[FORGE] No agent processor available. Input: ' + input;
    terminalSurface.write(fallback + '\n');
    return fallback;
  }

  // --- Register plugins ---

  if (tridentPlugin) {
    const pluginId = tridentPlugin.id ?? 'trident';
    pluginRegistry.set(pluginId, tridentPlugin);

    if (tridentPlugin.agents) {
      for (const [name, agent] of Object.entries(tridentPlugin.agents)) {
        agentRegistry.set(name, agent);
      }
    }

    if (tridentPlugin.providers) {
      for (const [name, provider] of Object.entries(tridentPlugin.providers)) {
        providerRegistry.set(name, provider);
      }
    }
  }

  // --- Register config providers ---

  if (config.providers) {
    for (const provider of config.providers) {
      providerRegistry.set(provider.id, provider);
    }
  }

  // --- Initialize session ---

  const sessionId = 'forge-' + Date.now();
  sessionStore.set('current', {
    id: sessionId,
    startTime,
    identity: FORGE_IDENTITY,
    config,
  });

  initialized = true;

  // --- Return runtime object ---

  return {
    processInput: inputHandler,

    getTUIComponent(): any {
      return {
        surface: terminalSurface,
        render(): string {
          const grid = terminalSurface.getCellSnapshot();
          let output = '';
          for (const row of grid) {
            for (const cell of row) {
              output += cell.char;
            }
            output += '\n';
          }
          return output;
        },
        getElement(): any {
          // Native layer renders the cell grid directly via renderFrame().
          // No JS-level React/Ink element is needed for iOS rendering.
          return null;
        },
      };
    },

    destroy(): void {
      terminalSurface.destroy();
      sessionStore.clear();
      pluginRegistry.clear();
      agentRegistry.clear();
      providerRegistry.clear();
      initialized = false;

      const globalAny = globalThis as any;
      if (globalAny.window?.__forgeOnInput) {
        delete globalAny.window.__forgeOnInput;
      }
    },

    getStatus(): ForgeRuntimeStatus {
      return {
        initialized,
        running,
        iterations,
        lastInput,
        lastOutput,
        uptime: Math.floor((Date.now() - startTime) / 1000),
        memoryUsage: nativeBridge.getMemoryUsage?.() ?? {
          rss: 0,
          heapTotal: 0,
          heapUsed: 0,
        },
      };
    },
  };
}

export default { initializeForgeRuntime, createForgeLayer };
