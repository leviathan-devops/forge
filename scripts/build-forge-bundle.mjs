/**
 * build-forge-bundle.mjs — esbuild pipeline for forge-bundle.js
 *
 * FORGE_ROOT is derived from this script's location (repo root), never
 * hardcoded to OPENCODE_WORKSPACE. esbuild is resolved from forge/node_modules
 * so the script works when invoked as `node scripts/build-forge-bundle.mjs`
 * from the repo root or via `npm run build` from forge/.
 *
 * Closes: F-BUNDLE-HARDCODED-ROOT
 */
import { createRequire } from 'module'
import { existsSync, mkdirSync, statSync } from 'fs'
import { dirname, join, resolve } from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

// Repo root = parent of scripts/
const FORGE_ROOT = resolve(__dirname, '..')
const FORGE_PKG = join(FORGE_ROOT, 'forge')
const SHIMS = join(FORGE_PKG, 'shims')
const ENTRY = join(FORGE_PKG, 'src', 'forge-entry.ts')
const OUT_DIR = join(FORGE_ROOT, 'iOS', 'FORGE', 'Resources')
const COMMITTED_OUTPUT = join(OUT_DIR, 'forge-bundle.js')

// F1 GUARD (2026-08-15): iOS/FORGE/Resources/forge-bundle.js is a COMMITTED
// engine artifact. Silently overwriting it from the (stub-era) forge/src is
// the exact mechanism that regressed the real engine on 2026-08-05 while the
// rebuild "passed". A verifier must never mutate what it verifies.
//   - --out <path>            build to a temp/parity path (safe)
//   - FORCE_BUNDLE_OVERWRITE=1  deliberate overwrite (valid only once the real
//     engine sources are committed under forge/src — F2 closure)
const outIdx = process.argv.indexOf('--out')
const OUTPUT =
  outIdx > -1 && process.argv[outIdx + 1]
    ? resolve(process.argv[outIdx + 1])
    : COMMITTED_OUTPUT
if (OUTPUT === COMMITTED_OUTPUT && process.env.FORCE_BUNDLE_OVERWRITE !== '1') {
  console.error('REFUSED: iOS/FORGE/Resources/forge-bundle.js is a committed artifact (F1 guard).')
  console.error('  The silent rebuild-overwrite is the Aug-5 regression mechanism.')
  console.error('  Use --out <path> for a temp/parity build, or FORCE_BUNDLE_OVERWRITE=1')
  console.error('  (valid only once the real engine sources are committed under forge/src — F2).')
  process.exit(2)
}

// Resolve esbuild from forge/node_modules (not scripts/ or cwd)
const requireFromForge = createRequire(join(FORGE_PKG, 'package.json'))
let esbuild
try {
  esbuild = requireFromForge('esbuild')
} catch (err) {
  console.error('BUILD FAILED: esbuild not found under forge/node_modules')
  console.error(`  Expected package root: ${FORGE_PKG}`)
  console.error('  Run: cd forge && npm install')
  console.error(err.message?.substring(0, 300) ?? err)
  process.exit(1)
}

if (!existsSync(ENTRY)) {
  console.error(`BUILD FAILED: entry not found: ${ENTRY}`)
  process.exit(1)
}

if (!existsSync(OUT_DIR)) {
  mkdirSync(OUT_DIR, { recursive: true })
}

console.log(`FORGE_ROOT: ${FORGE_ROOT}`)
console.log(`Entry: ${ENTRY}`)
console.log(`Output: ${OUTPUT}`)
console.log(`esbuild: ${requireFromForge.resolve('esbuild')}`)

const isRelease =
  process.env.CONFIGURATION === 'Release' ||
  process.argv.includes('--release')

try {
  await esbuild.build({
    entryPoints: [ENTRY],
    bundle: true,
    platform: 'browser',
    format: 'iife',
    target: ['safari16'],
    outfile: OUTPUT,
    minify: isRelease,
    sourcemap: false,
    treeShaking: true,
    alias: {
      fs: join(SHIMS, 'forge-fs.ts'),
      'node:fs': join(SHIMS, 'forge-fs.ts'),
      path: 'path-browserify',
      'node:path': 'path-browserify',
      os: join(SHIMS, 'forge-os.ts'),
      'node:os': join(SHIMS, 'forge-os.ts'),
      crypto: join(SHIMS, 'forge-crypto.ts'),
      'node:crypto': join(SHIMS, 'forge-crypto.ts'),
      events: join(SHIMS, 'forge-events.ts'),
      'node:events': join(SHIMS, 'forge-events.ts'),
      stream: join(SHIMS, 'forge-stream.ts'),
      'node:stream': join(SHIMS, 'forge-stream.ts'),
      child_process: join(SHIMS, 'forge-noop.ts'),
      'node:child_process': join(SHIMS, 'forge-noop.ts'),
      http: join(SHIMS, 'forge-http.ts'),
      'node:http': join(SHIMS, 'forge-http.ts'),
      https: join(SHIMS, 'forge-http.ts'),
      net: join(SHIMS, 'forge-noop.ts'),
      'node:net': join(SHIMS, 'forge-noop.ts'),
      tls: join(SHIMS, 'forge-noop.ts'),
      buffer: join(SHIMS, 'forge-buffer.ts'),
      url: join(SHIMS, 'forge-noop.ts'),
      util: join(SHIMS, 'forge-noop.ts'),
      zlib: join(SHIMS, 'forge-noop.ts'),
    },
    inject: [join(SHIMS, 'forge-globals.js')],
    define: {
      'process.env.NODE_ENV': isRelease ? '"production"' : '"production"',
      'process.platform': '"darwin"',
      global: 'globalThis',
      __dirname: '"/"',
    },
    conditions: ['browser', 'default'],
    logLevel: 'info',
  })

  const size = statSync(OUTPUT).size
  console.log(`BUILD SUCCEEDED! Bundle: ${Math.round(size / 1024)}KB (${size} bytes)`)
  console.log(`Wrote: ${OUTPUT}`)
} catch (error) {
  console.log('BUILD FAILED:')
  if (error.errors) {
    for (const e of error.errors.slice(0, 10)) {
      console.log(`  ${e.text}`)
      if (e.location) console.log(`    at ${e.location.file}:${e.location.line}`)
    }
  } else {
    console.log(error.message?.substring(0, 500) ?? String(error))
  }
  process.exit(1)
}
