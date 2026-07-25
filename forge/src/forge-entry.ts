/**
 * forge-entry.ts — FORGE iOS entry point.
 * Per spec section 4.2.
 *
 * Bootstrap module loaded by the FORGE iOS app.
 * Initializes opencode core, loads Trident plugin, sets up terminal surface,
 * and signals readiness.
 */

import { FORGE_IDENTITY, FORGE_IDENTITY_SHORT } from './forge-identity.js';
import { initializeForgeRuntime, type ForgeConfig, type ForgeNativeBridge } from './forge-runtime.js';
import { createForgeTerminalSurface } from './forge-terminal-surface.js';

const DEFAULT_CONFIG: ForgeConfig = {
  disableVanillaAgents: true,
  defaultAgent: 'trident',
  maxIterations: 50,
  batteryAware: true,
  offlineMode: false,
  cacheEnabled: true,
  identity: FORGE_IDENTITY,
  providers: [],
  plugins: ['trident'],
};

export async function bootstrap(nativeBridge?: Partial<ForgeNativeBridge>): Promise<void> {
  const native = resolveNativeBridge(nativeBridge);

  // Step 1: Terminal surface
  const terminalSurface = createForgeTerminalSurface();
  terminalSurface.write('[FORGE] Booting Trident on iPhone...\n');

  // Step 2: Load config
  const config = await loadConfig(native);
  terminalSurface.write('[FORGE] Configuration loaded\n');

  // Step 3: Load Trident plugin
  let tridentPlugin: any = null;
  try {
    tridentPlugin = await loadTridentPlugin();
    terminalSurface.write('[FORGE] Trident plugin loaded\n');
  } catch (err: any) {
    terminalSurface.write('[FORGE] ERROR loading Trident plugin: ' + (err?.message ?? err) + '\n');
  }

  // Step 4: Inject identity
  if (tridentPlugin) {
    if (tridentPlugin.setIdentity) tridentPlugin.setIdentity(FORGE_IDENTITY);
    if (tridentPlugin.config) tridentPlugin.config.identity = FORGE_IDENTITY_SHORT;
  }

  // Step 5: Initialize runtime
  const runtime = initializeForgeRuntime(config, tridentPlugin, native as ForgeNativeBridge);
  terminalSurface.write('[FORGE] Runtime initialized\n');

  // Step 6: Wire up terminal capture
  const globalAny = globalThis as any;
  if (globalAny.window) {
    globalAny.window.__forge = { runtime, terminal: terminalSurface, config, identity: FORGE_IDENTITY };
    globalAny.window.__forgeOutput = (text: string) => { native.output?.(text); };
  }

  // Step 7: Input handler with battery-aware preprocessing
  const originalInputHandler = globalAny.window?.__forgeOnInput;
  if (originalInputHandler) {
    globalAny.window.__forgeOnInput = async (input: string) => {
      if (config.batteryAware) {
        try {
          const batteryLevel = await native.call?.('getBatteryLevel') ?? 1.0;
          if (batteryLevel < 0.05) {
            terminalSurface.write('[FORGE] Battery critically low — processing limited\n');
          }
        } catch (batteryErr) {
          // Battery check failed — proceed anyway
        }
      }
      return originalInputHandler(input);
    };
  }

  // Step 8: Providers
  if (config.providers && config.providers.length > 0) {
    terminalSurface.write('[FORGE] ' + config.providers.length + ' provider(s) configured\n');
  } else {
    terminalSurface.write('[FORGE] No external providers — offline mode\n');
    config.offlineMode = true;
  }

  // Step 9: Initialize opencode core (optional)
  try {
    await initializeOpencodeCore(config, tridentPlugin);
    terminalSurface.write('[FORGE] opencode core initialized\n');
  } catch (err: any) {
    terminalSurface.write('[FORGE] opencode core warning: ' + (err?.message ?? err) + '\n');
  }

  // Step 10-12: Ready + banner
  terminalSurface.flush();
  terminalSurface.write('[FORGE] Ready. Trident online.\n');
  terminalSurface.flush();
  if (native.ready) native.ready();

  terminalSurface.write('\n+======================================+\n');
  terminalSurface.write('|     TRIDENT AGENT - FORGE / iOS      |\n');
  terminalSurface.write('|     T3 Algorithmic Audit Engine      |\n');
  terminalSurface.write('+======================================+\n\n');
  terminalSurface.flush();
}

function resolveNativeBridge(bridge?: Partial<ForgeNativeBridge>): ForgeNativeBridge {
  const globalAny = globalThis as any;
  const native = bridge ?? globalAny.window?.__forgeNative;
  if (!native) {
    return {
      call: async () => { throw new Error('[FORGE] Native bridge not available'); },
      output: (text: string) => { console.log(text); },
      error: (text: string) => { console.error(text); },
      ready: () => {},
      exit: (code: number) => { console.log('[FORGE] Exit: ' + code); },
    };
  }
  return native as ForgeNativeBridge;
}

async function loadConfig(native: ForgeNativeBridge): Promise<ForgeConfig> {
  try {
    const configJson: string = await native.call('getResource', 'forge-config.json');
    if (configJson) {
      const parsed = JSON.parse(configJson);
      return { ...DEFAULT_CONFIG, ...parsed };
    }
  } catch (loadErr) {
    // Use default config
  }
  return DEFAULT_CONFIG;
}

async function loadTridentPlugin(): Promise<any> {
  try {
    const tridentModule = await import('./vendor/trident-plugin.js').catch(() => null);
    if (tridentModule) return tridentModule.default ?? tridentModule;
    const globalAny = globalThis as any;
    if (globalAny.TridentPlugin) return globalAny.TridentPlugin;
  } catch (importErr) {
    // Plugin not bundled — return stub
  }
  return {
    id: 'trident-stub',
    identity: FORGE_IDENTITY,
    async process(input: string, context: any): Promise<string> {
      const identityPreview = (context.identity ?? '').slice(0, 100);
      const response = '[Trident/FORGE] Received: ' + input + '\nIdentity: ' + identityPreview + '...';
      context.terminal?.write(response + '\n');
      return response;
    },
    setIdentity(identity: string): void { this.identity = identity; },
    config: { identity: FORGE_IDENTITY_SHORT },
  };
}

async function initializeOpencodeCore(config: ForgeConfig, tridentPlugin: any): Promise<void> {
  const globalAny = globalThis as any;
  // Config module
  try {
    const ConfigModule = await import('./vendor/opencode-config.js').catch(() => null);
    if (ConfigModule) {
      const opencodeConfig = ConfigModule.default ?? ConfigModule;
      if (opencodeConfig.load) {
        await opencodeConfig.load({
          agents: config.disableVanillaAgents ? { trident: { default: true } } : {},
          plugins: config.plugins,
        });
      }
    }
  } catch (configErr) { /* Config module not bundled */ }
  // Session module
  try {
    const SessionModule = await import('./vendor/opencode-session.js').catch(() => null);
    if (SessionModule) {
      const Session = SessionModule.default ?? SessionModule;
      if (Session.create) {
        const session = await Session.create({ agent: config.defaultAgent });
        globalAny.__forgeSession = session;
      }
    }
  } catch (sessionErr) { /* Session module not bundled */ }
  // Agent module
  try {
    const AgentModule = await import('./vendor/opencode-agent.js').catch(() => null);
    if (AgentModule) {
      const Agent = AgentModule.default ?? AgentModule;
      if (Agent.register && tridentPlugin) {
        await Agent.register('trident', { identity: FORGE_IDENTITY_SHORT, process: tridentPlugin.process });
      }
    }
  } catch (agentErr) { /* Agent module not bundled */ }
  // Plugin module
  try {
    const PluginModule = await import('./vendor/opencode-plugin.js').catch(() => null);
    if (PluginModule && tridentPlugin) {
      const Plugin = PluginModule.default ?? PluginModule;
      if (Plugin.load) await Plugin.load(tridentPlugin);
    }
  } catch (pluginErr) { /* Plugin module not bundled */ }
}

// Auto-bootstrap on load if native bridge requests it
const globalAny = globalThis as any;
if (globalAny.window?.__forgeNative?.autoBootstrap) {
  bootstrap().catch((err) => {
    console.error('[FORGE] Bootstrap failed:', err);
    globalAny.window?.__forgeNative?.error?.(String(err?.message ?? err));
  });
}

export { FORGE_IDENTITY };
export default bootstrap;
