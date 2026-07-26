import * as esbuild from 'esbuild'
import { existsSync, statSync } from 'fs'

const FORGE_ROOT = '/home/leviathan/OPENCODE_WORKSPACE/FORGE'
const SHIMS = `${FORGE_ROOT}/forge/shims`
const ENTRY = `${FORGE_ROOT}/forge/src/forge-entry.ts`
const OUTPUT = `${FORGE_ROOT}/iOS/FORGE/Resources/forge-bundle.js`

console.log(`Entry: ${ENTRY}`)
console.log(`Output: ${OUTPUT}`)

try {
    const result = await esbuild.build({
        entryPoints: [ENTRY],
        bundle: true,
        platform: 'browser',
        format: 'iife',
        target: ['safari16'],
        outfile: OUTPUT,
        minify: false,
        sourcemap: false,
        treeShaking: true,
        alias: {
            'fs': `${SHIMS}/forge-fs.ts`,
            'node:fs': `${SHIMS}/forge-fs.ts`,
            'path': 'path-browserify',
            'node:path': 'path-browserify',
            'os': `${SHIMS}/forge-os.ts`,
            'node:os': `${SHIMS}/forge-os.ts`,
            'crypto': `${SHIMS}/forge-crypto.ts`,
            'node:crypto': `${SHIMS}/forge-crypto.ts`,
            'events': `${SHIMS}/forge-events.ts`,
            'node:events': `${SHIMS}/forge-events.ts`,
            'stream': `${SHIMS}/forge-stream.ts`,
            'node:stream': `${SHIMS}/forge-stream.ts`,
            'child_process': `${SHIMS}/forge-noop.ts`,
            'node:child_process': `${SHIMS}/forge-noop.ts`,
            'http': `${SHIMS}/forge-http.ts`,
            'node:http': `${SHIMS}/forge-http.ts`,
            'https': `${SHIMS}/forge-http.ts`,
            'net': `${SHIMS}/forge-noop.ts`,
            'node:net': `${SHIMS}/forge-noop.ts`,
            'tls': `${SHIMS}/forge-noop.ts`,
            'buffer': `${SHIMS}/forge-buffer.ts`,
            'url': `${SHIMS}/forge-noop.ts`,
            'util': `${SHIMS}/forge-noop.ts`,
            'zlib': `${SHIMS}/forge-noop.ts`,
        },
        inject: [`${SHIMS}/forge-globals.js`],
        define: {
            'process.env.NODE_ENV': '"production"',
            'process.platform': '"darwin"',
            'global': 'globalThis',
            '__dirname': '"/"',
        },
        conditions: ['browser', 'default'],
        logLevel: 'info',
    })
    
    const size = statSync(OUTPUT).size
    console.log(`BUILD SUCCEEDED! Bundle: ${Math.round(size/1024)}KB`)
} catch (error) {
    console.log('BUILD FAILED:')
    if (error.errors) {
        for (const e of error.errors.slice(0, 10)) {
            console.log(`  ${e.text}`)
            if (e.location) console.log(`    at ${e.location.file}:${e.location.line}`)
        }
    } else {
        console.log(error.message?.substring(0, 500))
    }
}
