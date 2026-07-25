/**
 * build-forge-bundle.mjs — esbuild build script for FORGE/iOS.
 * Per spec section 4.4.
 *
 * Bundles the complete FORGE TypeScript layer into a single IIFE
 * file suitable for loading in a WKWebView on iOS.
 *
 * Usage:
 *   node build-forge-bundle.mjs [--watch] [--dev]
 */

import { build, context } from 'esbuild';
import { readFileSync, writeFileSync, existsSync, mkdirSync, copyFileSync } from 'fs';
import { resolve, dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// --- Configuration ---

const ROOT = resolve(__dirname, '..');
const FORGE_SRC = resolve(ROOT, 'forge', 'src');
const FORGE_SHIMS = resolve(ROOT, 'forge', 'shims');
const OUTPUT_DIR = resolve(ROOT, 'iOS', 'FORGE', 'Resources');
const OUTPUT_FILE = join(OUTPUT_DIR, 'forge-bundle.js');

// --- Shim aliases ---

const SHIM_ALIASES = {
  // Node.js built-in modules → FORGE shims
  'fs': join(FORGE_SHIMS, 'forge-fs.ts'),
  'fs/promises': join(FORGE_SHIMS, 'forge-fs.ts'),
  'path': 'path-browserify',
  'path-browserify': 'path-browserify',
  'os': join(FORGE_SHIMS, 'forge-os.ts'),
  'crypto': join(FORGE_SHIMS, 'forge-crypto.ts'),
  'events': join(FORGE_SHIMS, 'forge-events.ts'),
  'stream': join(FORGE_SHIMS, 'forge-stream.ts'),
  'stream/web': join(FORGE_SHIMS, 'forge-stream.ts'),
  'stream/promises': join(FORGE_SHIMS, 'forge-stream.ts'),
  'http': join(FORGE_SHIMS, 'forge-http.ts'),
  'https': join(FORGE_SHIMS, 'forge-http.ts'),
  'http2': join(FORGE_SHIMS, 'forge-http.ts'),
  'url': join(FORGE_SHIMS, 'forge-url.ts'),
  'util': join(FORGE_SHIMS, 'forge-util.ts'),
  'util/types': join(FORGE_SHIMS, 'forge-util.ts'),
  'buffer': join(FORGE_SHIMS, 'forge-buffer.ts'),

  // SQL.js
  'sql.js': 'sql.js',
  'better-sqlite3': join(FORGE_SHIMS, 'forge-sqlite.ts'),
  'node:sqlite': join(FORGE_SHIMS, 'forge-sqlite.ts'),

  // Unsupported modules → noop
  'net': join(FORGE_SHIMS, 'forge-noop.ts'),
  'tls': join(FORGE_SHIMS, 'forge-noop.ts'),
  'dgram': join(FORGE_SHIMS, 'forge-noop.ts'),
  'dns': join(FORGE_SHIMS, 'forge-noop.ts'),
  'dns/promises': join(FORGE_SHIMS, 'forge-noop.ts'),
  'zlib': join(FORGE_SHIMS, 'forge-noop.ts'),
  'zlib-browserify': join(FORGE_SHIMS, 'forge-noop.ts'),
  'cluster': join(FORGE_SHIMS, 'forge-noop.ts'),
  'readline': join(FORGE_SHIMS, 'forge-noop.ts'),
  'readline/promises': join(FORGE_SHIMS, 'forge-noop.ts'),
  'child_process': join(FORGE_SHIMS, 'forge-process.ts'),
  'worker_threads': join(FORGE_SHIMS, 'forge-noop.ts'),
  'perf_hooks': join(FORGE_SHIMS, 'forge-noop.ts'),
  'async_hooks': join(FORGE_SHIMS, 'forge-noop.ts'),
  'inspector': join(FORGE_SHIMS, 'forge-noop.ts'),
  'v8': join(FORGE_SHIMS, 'forge-noop.ts'),
  'vm': join(FORGE_SHIMS, 'forge-noop.ts'),
  'trace_events': join(FORGE_SHIMS, 'forge-noop.ts'),
  'diagnostics_channel': join(FORGE_SHIMS, 'forge-noop.ts'),
  'node:fs': join(FORGE_SHIMS, 'forge-fs.ts'),
  'node:fs/promises': join(FORGE_SHIMS, 'forge-fs.ts'),
  'node:path': 'path-browserify',
  'node:os': join(FORGE_SHIMS, 'forge-os.ts'),
  'node:crypto': join(FORGE_SHIMS, 'forge-crypto.ts'),
  'node:events': join(FORGE_SHIMS, 'forge-events.ts'),
  'node:stream': join(FORGE_SHIMS, 'forge-stream.ts'),
  'node:http': join(FORGE_SHIMS, 'forge-http.ts'),
  'node:https': join(FORGE_SHIMS, 'forge-http.ts'),
  'node:url': join(FORGE_SHIMS, 'forge-url.ts'),
  'node:util': join(FORGE_SHIMS, 'forge-util.ts'),
  'node:buffer': join(FORGE_SHIMS, 'forge-buffer.ts'),
  'node:child_process': join(FORGE_SHIMS, 'forge-process.ts'),
  'node:net': join(FORGE_SHIMS, 'forge-noop.ts'),
  'node:tls': join(FORGE_SHIMS, 'forge-noop.ts'),
  'node:dns': join(FORGE_SHIMS, 'forge-noop.ts'),
  'node:zlib': join(FORGE_SHIMS, 'forge-noop.ts'),
};

// --- esbuild options ---

function createBuildOptions(isDev = false) {
  return {
    entryPoints: [join(FORGE_SRC, 'forge-entry.ts')],
    bundle: true,
    platform: 'browser',
    format: 'iife',
    target: ['safari16'],
    outfile: OUTPUT_FILE,
    minify: !isDev,
    sourcemap: isDev ? 'inline' : false,
    treeShaking: !isDev,
    legalComments: 'none',
    conditions: ['browser', 'default'],
    alias: SHIM_ALIASES,
    inject: [join(FORGE_SHIMS, 'forge-globals.js')],
    define: {
      'process.env.NODE_ENV': JSON.stringify(isDev ? 'development' : 'production'),
      'process.env.FORGE': '"1"',
      'process.env.FORGE_PLATFORM': '"ios"',
      'global': 'globalThis',
      '__dirname': '"/"',
      '__filename': '"/forge-bundle.js"',
      'process.platform': '"darwin"',
      'process.arch': '"arm64"',
    },
    loader: {
      '.wasm': 'binary',
      '.txt': 'text',
      '.md': 'text',
      '.sql': 'text',
      '.json': 'json',
      '.node': 'empty',
      '.css': 'text',
      '.svg': 'text',
    },
    logLevel: 'info',
    banner: {
      js: `/* FORGE Bundle — Trident Agent for iOS. Built ${new Date().toISOString()} */`,
    },
    footer: {
      js: `// End of FORGE bundle`,
    },
    mainFields: ['browser', 'module', 'main'],
    resolveExtensions: ['.browser.ts', '.browser.js', '.ts', '.tsx', '.js', '.jsx', '.json'],
    splitting: false,
    write: true,
    metafile: isDev,
    absWorkingDir: ROOT,
  };
}

// --- Binary resource copy ---

function copyBinaryResources() {
  // Copy sql-wasm.wasm if it exists
  const sqlWasmSources = [
    join(ROOT, 'forge', 'node_modules', 'sql.js', 'dist', 'sql-wasm.wasm'),
    join(ROOT, 'node_modules', 'sql.js', 'dist', 'sql-wasm.wasm'),
  ];

  for (const src of sqlWasmSources) {
    if (existsSync(src)) {
      const dest = join(OUTPUT_DIR, 'sql-wasm.wasm');
      copyFileSync(src, dest);
      console.log(`[FORGE] Copied sql-wasm.wasm to ${dest}`);
      return;
    }
  }

  console.warn('[FORGE] Warning: sql-wasm.wasm not found. SQLite will use CDN fallback.');

  // Copy tree-sitter.wasm if it exists
  const treeSitterSources = [
    join(ROOT, 'forge', 'node_modules', 'web-tree-sitter', 'tree-sitter.wasm'),
    join(ROOT, 'node_modules', 'web-tree-sitter', 'tree-sitter.wasm'),
  ];

  for (const src of treeSitterSources) {
    if (existsSync(src)) {
      const dest = join(OUTPUT_DIR, 'tree-sitter.wasm');
      copyFileSync(src, dest);
      console.log(`[FORGE] Copied tree-sitter.wasm to ${dest}`);
      break;
    }
  }
}

// --- Build verification ---

function verifyBuild() {
  if (!existsSync(OUTPUT_FILE)) {
    throw new Error(`[FORGE] Build failed: output file not created at ${OUTPUT_FILE}`);
  }

  const stats = readFileSync(OUTPUT_FILE);
  const sizeKB = (stats.length / 1024).toFixed(1);

  if (stats.length < 1000) {
    throw new Error(`[FORGE] Build suspicious: output is only ${sizeKB}KB`);
  }

  console.log(`[FORGE] Bundle size: ${sizeKB}KB (${stats.length.toLocaleString()} bytes)`);

  // Verify key exports are present
  const content = stats.toString('utf8');
  const checks = [
    { name: 'FORGE_IDENTITY', pattern: 'FORGE_IDENTITY' },
    { name: 'initializeForgeRuntime', pattern: 'initializeForgeRuntime' },
    { name: 'bootstrap', pattern: 'bootstrap' },
    { name: 'ForgeTerminalSurface', pattern: 'ForgeTerminalSurface' },
    { name: 'processShim', pattern: 'processShim' },
    { name: 'BufferShim', pattern: 'BufferShim' },
  ];

  let allPassed = true;
  for (const check of checks) {
    if (!content.includes(check.pattern)) {
      console.error(`[FORGE] VERIFY FAILED: '${check.name}' not found in bundle`);
      allPassed = false;
    } else {
      console.log(`[FORGE] Verified: ${check.name}`);
    }
  }

  if (!allPassed) {
    throw new Error('[FORGE] Build verification failed — missing expected exports');
  }

  // Write build manifest
  const manifest = {
    builtAt: new Date().toISOString(),
    file: 'forge-bundle.js',
    size: stats.length,
    sizeKB: parseFloat(sizeKB),
    target: 'safari16',
    platform: 'browser',
    format: 'iife',
    checks: checks.map((c) => ({ name: c.name, passed: content.includes(c.pattern) })),
  };

  writeFileSync(
    join(OUTPUT_DIR, 'forge-bundle-manifest.json'),
    JSON.stringify(manifest, null, 2),
  );

  console.log('[FORGE] Build manifest written');
  console.log('[FORGE] BUILD SUCCESSFUL');
}

// --- Main build ---

async function main() {
  const args = process.argv.slice(2);
  const isWatch = args.includes('--watch');
  const isDev = args.includes('--dev') || process.env.NODE_ENV === 'development';

  // Ensure output directory exists
  if (!existsSync(OUTPUT_DIR)) {
    mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  console.log('[FORGE] Starting build...');
  console.log(`[FORGE] Mode: ${isDev ? 'development' : 'production'}`);
  console.log(`[FORGE] Entry: ${join(FORGE_SRC, 'forge-entry.ts')}`);
  console.log(`[FORGE] Output: ${OUTPUT_FILE}`);

  const options = createBuildOptions(isDev);

  if (isWatch) {
    console.log('[FORGE] Watch mode enabled');
    const ctx = await context(options);
    await ctx.watch();

    // Copy binary resources on first run
    copyBinaryResources();

    console.log('[FORGE] Watching for changes... (Ctrl+C to stop)');
  } else {
    const result = await build(options);

    if (result.warnings.length > 0) {
      console.warn(`[FORGE] ${result.warnings.length} warning(s):`);
      for (const w of result.warnings) {
        console.warn(`  ${w.text}`);
      }
    }

    // Copy binary resources
    copyBinaryResources();

    // Verify build
    verifyBuild();

    if (result.metafile) {
      const text = await import('esbuild').then((m) =>
        m.analyzeMetafile(result.metafile, { verbose: false }),
      );
      // Only show in dev mode
      if (isDev) {
        console.log('\n[FORGE] Bundle analysis:\n', text.slice(0, 2000));
      }
    }
  }
}

main().catch((err) => {
  console.error('[FORGE] BUILD FAILED:', err?.message ?? err);
  if (err?.errors) {
    for (const e of err.errors) {
      console.error(`  ${e.text} (${e.location?.file}:${e.location?.line})`);
    }
  }
  process.exit(1);
});
