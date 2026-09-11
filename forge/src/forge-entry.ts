/**
 * forge-entry.ts — FORGE iOS entry point.
 * Per spec section 4.2.
 *
 * Bootstrap module loaded by the FORGE iOS app.
 * Initializes opencode core, loads Trident plugin, sets up terminal surface,
 * and signals readiness.
 *
 * Phase-2 status (F-PHASE2-STUB-ONLY): real opencode/Trident JS is NOT vendored.
 * Only forge/src/vendor/*.d.ts type stubs exist. loadTridentPlugin /
 * initializeOpencodeCore surface actionable missing-vendor errors and fall
 * back to an honest Phase-1 terminal demo stub (no fake full agent runtime).
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

/** Repo-relative vendor slots expected for full Phase-2 opencode+Trident. */
export const FORGE_VENDOR_MODULES = {
  tridentPlugin: {
    importPath: './vendor/trident-plugin.js',
    repoPath: 'forge/src/vendor/trident-plugin.js',
    role: 'Trident agent plugin (process / agents / providers)',
  },
  opencodeConfig: {
    importPath: './vendor/opencode-config.js',
    repoPath: 'forge/src/vendor/opencode-config.js',
    role: 'opencode Config.load()',
  },
  opencodeSession: {
    importPath: './vendor/opencode-session.js',
    repoPath: 'forge/src/vendor/opencode-session.js',
    role: 'opencode Session.create()',
  },
  opencodeAgent: {
    importPath: './vendor/opencode-agent.js',
    repoPath: 'forge/src/vendor/opencode-agent.js',
    role: 'opencode Agent.register()',
  },
  opencodePlugin: {
    importPath: './vendor/opencode-plugin.js',
    repoPath: 'forge/src/vendor/opencode-plugin.js',
    role: 'opencode Plugin.load()',
  },
} as const;

/** How to close the Phase-2 vendor gap (printed to terminal + docs). */
export const FORGE_VENDOR_GAP_HINT =
  'Phase-2 gap: ship real JS under forge/src/vendor/ (currently only *.d.ts type stubs). ' +
  'Do not invent a fake agent runtime. Vendor from Trident/opencode packages (OPENCODE_WORKSPACE is read-only reference). ' +
  'Required files: trident-plugin.js, opencode-config.js, opencode-session.js, opencode-agent.js, opencode-plugin.js. ' +
  'Until then: Phase-1 terminal demo stub only (F-PHASE2-STUB-ONLY partial).';

export interface ForgePluginLoadResult {
  plugin: any;
  isStub: boolean;
  missingPath?: string;
  message: string;
}

export interface ForgeOpencodeInitResult {
  loaded: string[];
  missing: Array<{ repoPath: string; role: string }>;
  isFull: boolean;
  message: string;
}

/** Runtime status exposed on window.__forge for native diagnostics. */
export interface ForgePhaseStatus {
  phase: 'phase1-stub' | 'phase2-partial' | 'phase2-full';
  tridentIsStub: boolean;
  opencodeLoaded: string[];
  opencodeMissing: string[];
  vendorGapHint: string;
}

function formatMissingVendorError(
  repoPath: string,
  role: string,
  cause?: unknown,
): Error {
  const causeText =
    cause instanceof Error
      ? cause.message
      : cause
        ? String(cause)
        : 'module not found / import failed';
  return new Error(
    `[FORGE] Missing vendor module for ${role}.\n` +
      `  Expected: ${repoPath}\n` +
      `  Cause: ${causeText}\n` +
      `  Action: add the real JS implementation at that path (only *.d.ts stubs exist today).\n` +
      `  ${FORGE_VENDOR_GAP_HINT}`,
  );
}

/**
 * Attempt dynamic import of an optional vendor module.
 * Paths must be static string literals so esbuild can bundle them when present;
 * when absent, the import rejects at runtime (or stays external) and we surface
 * an actionable error + Phase-1 stub.
 */
async function tryImportVendor(
  kind: keyof typeof FORGE_VENDOR_MODULES,
): Promise<{ mod: any | null; error: unknown | null }> {
  try {
    let mod: any = null;
    switch (kind) {
      case 'tridentPlugin':
        mod = await import('./vendor/trident-plugin.js');
        break;
      case 'opencodeConfig':
        mod = await import('./vendor/opencode-config.js');
        break;
      case 'opencodeSession':
        mod = await import('./vendor/opencode-session.js');
        break;
      case 'opencodeAgent':
        mod = await import('./vendor/opencode-agent.js');
        break;
      case 'opencodePlugin':
        mod = await import('./vendor/opencode-plugin.js');
        break;
      default:
        return { mod: null, error: new Error('unknown vendor kind: ' + String(kind)) };
    }
    if (mod == null) return { mod: null, error: new Error('import resolved to null') };
    return { mod, error: null };
  } catch (err) {
    return { mod: null, error: err };
  }
}

export async function bootstrap(nativeBridge?: Partial<ForgeNativeBridge>): Promise<void> {
  const native = resolveNativeBridge(nativeBridge);

  // Step 1: Terminal surface
  const terminalSurface = createForgeTerminalSurface();
  terminalSurface.write('[FORGE] Booting Trident on iPhone...\n');

  // Step 2: Load config
  const config = await loadConfig(native);
  terminalSurface.write('[FORGE] Configuration loaded\n');

  // Step 3: Load Trident plugin (real vendor or honest Phase-1 stub)
  const loadResult = await loadTridentPlugin();
  const tridentPlugin = loadResult.plugin;
  if (loadResult.isStub) {
    terminalSurface.write('[FORGE] WARNING: Trident vendor missing — Phase-1 STUB mode\n');
    terminalSurface.write('[FORGE] ' + loadResult.message + '\n');
    if (loadResult.missingPath) {
      terminalSurface.write('[FORGE] Missing: ' + loadResult.missingPath + '\n');
    }
  } else {
    terminalSurface.write('[FORGE] Trident plugin loaded (real vendor)\n');
  }

  // Step 4: Inject identity
  if (tridentPlugin) {
    if (tridentPlugin.setIdentity) tridentPlugin.setIdentity(FORGE_IDENTITY);
    if (tridentPlugin.config) tridentPlugin.config.identity = FORGE_IDENTITY_SHORT;
  }

  // Step 5: Initialize runtime
  const runtime = initializeForgeRuntime(config, tridentPlugin, native as ForgeNativeBridge);
  terminalSurface.write('[FORGE] Runtime initialized\n');

  // Step 6: Wire up terminal capture + phase status
  const globalAny = globalThis as any;
  const phaseStatus: ForgePhaseStatus = {
    phase: loadResult.isStub ? 'phase1-stub' : 'phase2-partial',
    tridentIsStub: loadResult.isStub,
    opencodeLoaded: [],
    opencodeMissing: [],
    vendorGapHint: FORGE_VENDOR_GAP_HINT,
  };
  if (globalAny.window) {
    globalAny.window.__forge = {
      runtime,
      terminal: terminalSurface,
      config,
      identity: FORGE_IDENTITY,
      phaseStatus,
      isStub: loadResult.isStub,
    };
    globalAny.window.__forgeOutput = (text: string) => {
      native.output?.(text);
    };
  }

  // Step 7: Input handler with battery-aware preprocessing
  const originalInputHandler = globalAny.window?.__forgeOnInput;
  if (originalInputHandler) {
    globalAny.window.__forgeOnInput = async (input: string) => {
      if (config.batteryAware) {
        try {
          const batteryLevel = (await native.call?.('getBatteryLevel')) ?? 1.0;
          if (batteryLevel < 0.05) {
            terminalSurface.write('[FORGE] Battery critically low — processing limited\n');
          }
        } catch {
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

  // Step 9: Initialize opencode core — fail loud with actionable missing-vendor list
  try {
    const ocResult = await initializeOpencodeCore(config, tridentPlugin);
    phaseStatus.opencodeLoaded = ocResult.loaded;
    phaseStatus.opencodeMissing = ocResult.missing.map((m) => m.repoPath);
    if (ocResult.isFull && !loadResult.isStub) {
      phaseStatus.phase = 'phase2-full';
      terminalSurface.write('[FORGE] opencode core initialized (full vendor)\n');
    } else if (ocResult.loaded.length > 0) {
      phaseStatus.phase = loadResult.isStub ? 'phase1-stub' : 'phase2-partial';
      terminalSurface.write(
        '[FORGE] opencode core partial: loaded=[' +
          ocResult.loaded.join(', ') +
          '] missing=[' +
          ocResult.missing.map((m) => m.repoPath).join(', ') +
          ']\n',
      );
      terminalSurface.write('[FORGE] ' + ocResult.message + '\n');
    } else {
      // All modules missing — throw so catch path prints full actionable error
      throw new Error(ocResult.message);
    }
  } catch (err: any) {
    const msg = err?.message ?? String(err);
    terminalSurface.write('[FORGE] opencode core unavailable (actionable):\n');
    for (const line of String(msg).split('\n')) {
      terminalSurface.write('[FORGE]   ' + line + '\n');
    }
    if (globalAny.window?.__forge) {
      globalAny.window.__forge.phaseStatus = phaseStatus;
      globalAny.window.__forge.isStub = true;
    }
  }

  // Step 10-12: Ready + banner (always — stub must still demo terminal UX)
  terminalSurface.flush();
  if (phaseStatus.phase === 'phase1-stub') {
    terminalSurface.write('[FORGE] Ready (Phase-1 terminal demo / STUB). Full Trident not vendored.\n');
  } else if (phaseStatus.phase === 'phase2-partial') {
    terminalSurface.write('[FORGE] Ready (Phase-2 partial). Some vendor modules still missing.\n');
  } else {
    terminalSurface.write('[FORGE] Ready. Trident online.\n');
  }
  terminalSurface.flush();
  if (native.ready) native.ready();

  terminalSurface.write('\n+======================================+\n');
  terminalSurface.write('|     TRIDENT AGENT - FORGE / iOS      |\n');
  terminalSurface.write('|     T3 Algorithmic Audit Engine      |\n');
  if (phaseStatus.phase === 'phase1-stub') {
    terminalSurface.write('|     MODE: Phase-1 STUB (demo UX)     |\n');
  } else if (phaseStatus.phase === 'phase2-partial') {
    terminalSurface.write('|     MODE: Phase-2 PARTIAL vendor     |\n');
  } else {
    terminalSurface.write('|     MODE: Phase-2 FULL               |\n');
  }
  terminalSurface.write('+======================================+\n\n');
  if (phaseStatus.phase !== 'phase2-full') {
    terminalSurface.write('[FORGE] ' + FORGE_VENDOR_GAP_HINT + '\n\n');
  }
  terminalSurface.flush();
}

function resolveNativeBridge(bridge?: Partial<ForgeNativeBridge>): ForgeNativeBridge {
  const globalAny = globalThis as any;
  const native = bridge ?? globalAny.window?.__forgeNative;
  if (!native) {
    return {
      call: async () => {
        throw new Error('[FORGE] Native bridge not available');
      },
      output: (text: string) => {
        console.log(text);
      },
      error: (text: string) => {
        console.error(text);
      },
      ready: () => {},
      exit: (code: number) => {
        console.log('[FORGE] Exit: ' + code);
      },
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
  } catch {
    // Use default config
  }
  return DEFAULT_CONFIG;
}

/**
 * Load real Trident plugin from vendor, or return an honest Phase-1 demo stub.
 * Never silently pretends the full agent is present.
 */
export async function loadTridentPlugin(): Promise<ForgePluginLoadResult> {
  const slot = FORGE_VENDOR_MODULES.tridentPlugin;

  // 1) Dynamic import of vendored JS
  const { mod: tridentModule, error: importError } = await tryImportVendor('tridentPlugin');
  if (tridentModule) {
    const plugin = tridentModule.default ?? tridentModule;
    if (plugin && (typeof plugin.process === 'function' || plugin.agents || plugin.id)) {
      return {
        plugin,
        isStub: false,
        message: 'Loaded real Trident plugin from ' + slot.repoPath,
      };
    }
  }

  // 2) Global injection (native or prior script tag)
  const globalAny = globalThis as any;
  if (globalAny.TridentPlugin) {
    return {
      plugin: globalAny.TridentPlugin,
      isStub: false,
      message: 'Loaded TridentPlugin from globalThis.TridentPlugin',
    };
  }

  // 3) Honest Phase-1 stub — actionable error details preserved on the stub object
  const missingErr = formatMissingVendorError(
    slot.repoPath,
    slot.role,
    importError ?? new Error('no global TridentPlugin and vendor .js absent'),
  );

  const stub = createPhase1TridentStub(missingErr.message);
  return {
    plugin: stub,
    isStub: true,
    missingPath: slot.repoPath,
    message: missingErr.message,
  };
}

/**
 * Phase-1 terminal demo stub only. Echoes input; does NOT claim audit/agent capability.
 */
function createPhase1TridentStub(loadErrorMessage: string): any {
  return {
    id: 'trident-stub',
    isStub: true,
    identity: FORGE_IDENTITY,
    loadError: loadErrorMessage,
    async process(input: string, context: any): Promise<string> {
      const lines = [
        '[Trident/FORGE Phase-1 STUB] echo only — full agent not vendored.',
        'Input: ' + input,
        'Gap: ' + (FORGE_VENDOR_MODULES.tridentPlugin.repoPath + ' missing'),
        'Hint: ' + FORGE_VENDOR_GAP_HINT,
      ];
      const response = lines.join('\n');
      context.terminal?.write(response + '\n');
      return response;
    },
    setIdentity(identity: string): void {
      this.identity = identity;
    },
    config: { identity: FORGE_IDENTITY_SHORT, stub: true },
  };
}

/**
 * Load opencode core vendor modules. Collects missing paths and returns
 * an actionable summary — does not silently succeed with zero modules.
 */
export async function initializeOpencodeCore(
  config: ForgeConfig,
  tridentPlugin: any,
): Promise<ForgeOpencodeInitResult> {
  const globalAny = globalThis as any;
  const loaded: string[] = [];
  const missing: Array<{ repoPath: string; role: string }> = [];
  const errors: string[] = [];

  // Config module
  {
    const slot = FORGE_VENDOR_MODULES.opencodeConfig;
    const { mod, error } = await tryImportVendor('opencodeConfig');
    if (mod) {
      const opencodeConfig = mod.default ?? mod;
      if (opencodeConfig?.load) {
        await opencodeConfig.load({
          agents: config.disableVanillaAgents ? { trident: { default: true } } : {},
          plugins: config.plugins,
        });
      }
      loaded.push(slot.repoPath);
    } else {
      missing.push({ repoPath: slot.repoPath, role: slot.role });
      errors.push(formatMissingVendorError(slot.repoPath, slot.role, error).message);
    }
  }

  // Session module
  {
    const slot = FORGE_VENDOR_MODULES.opencodeSession;
    const { mod, error } = await tryImportVendor('opencodeSession');
    if (mod) {
      const Session = mod.default ?? mod;
      if (Session?.create) {
        const session = await Session.create({ agent: config.defaultAgent });
        globalAny.__forgeSession = session;
      }
      loaded.push(slot.repoPath);
    } else {
      missing.push({ repoPath: slot.repoPath, role: slot.role });
      errors.push(formatMissingVendorError(slot.repoPath, slot.role, error).message);
    }
  }

  // Agent module
  {
    const slot = FORGE_VENDOR_MODULES.opencodeAgent;
    const { mod, error } = await tryImportVendor('opencodeAgent');
    if (mod) {
      const Agent = mod.default ?? mod;
      if (Agent?.register && tridentPlugin && !tridentPlugin.isStub) {
        await Agent.register('trident', {
          identity: FORGE_IDENTITY_SHORT,
          process: tridentPlugin.process,
        });
      }
      loaded.push(slot.repoPath);
    } else {
      missing.push({ repoPath: slot.repoPath, role: slot.role });
      errors.push(formatMissingVendorError(slot.repoPath, slot.role, error).message);
    }
  }

  // Plugin module
  {
    const slot = FORGE_VENDOR_MODULES.opencodePlugin;
    const { mod, error } = await tryImportVendor('opencodePlugin');
    if (mod) {
      const Plugin = mod.default ?? mod;
      if (Plugin?.load && tridentPlugin && !tridentPlugin.isStub) {
        await Plugin.load(tridentPlugin);
      }
      loaded.push(slot.repoPath);
    } else {
      missing.push({ repoPath: slot.repoPath, role: slot.role });
      errors.push(formatMissingVendorError(slot.repoPath, slot.role, error).message);
    }
  }

  const isFull = missing.length === 0;
  let message: string;
  if (isFull) {
    message = 'All opencode vendor modules loaded: ' + loaded.join(', ');
  } else if (loaded.length === 0) {
    message =
      '[FORGE] opencode core: ALL vendor modules missing.\n' +
      missing.map((m) => `  - ${m.repoPath} (${m.role})`).join('\n') +
      '\n' +
      FORGE_VENDOR_GAP_HINT;
  } else {
    message =
      '[FORGE] opencode core: partial vendor.\n' +
      '  Loaded: ' +
      loaded.join(', ') +
      '\n' +
      '  Missing:\n' +
      missing.map((m) => `  - ${m.repoPath} (${m.role})`).join('\n') +
      '\n' +
      FORGE_VENDOR_GAP_HINT;
  }

  // Surface first error detail for operators debugging import failures
  if (errors.length > 0 && loaded.length === 0) {
    // keep message as the multi-line actionable summary above
  }

  return { loaded, missing, isFull, message };
}

// Auto-bootstrap on load if native bridge requests it.
// Always export window.__forgeBootstrap so the iOS ForgeEngine loadHTMLString
// path can invoke the phase1-stub bootstrap after the IIFE loads (IIFE does
// not attach `export default` to window by itself).
const globalAny = globalThis as any;
if (globalAny.window) {
  globalAny.window.__forgeBootstrap = bootstrap;
}
if (globalAny.window?.__forgeNative?.autoBootstrap) {
  bootstrap().catch((err) => {
    console.error('[FORGE] Bootstrap failed:', err);
    globalAny.window?.__forgeNative?.error?.(String(err?.message ?? err));
  });
}

export { FORGE_IDENTITY };
export default bootstrap;
