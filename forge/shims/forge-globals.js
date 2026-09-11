/**
 * forge-globals.js — Process and Buffer injection for FORGE/iOS bundle.
 * Per spec section 4.9.
 *
 * This file is injected into the esbuild bundle via the inject option.
 * It provides global process and Buffer objects.
 */

import { Buffer } from './forge-buffer.js';

const processShim = {
  env: {
    NODE_ENV: 'production',
    FORGE: '1',
    FORGE_PLATFORM: 'ios',
    HOME: '/tmp/home',
    TMPDIR: '/tmp',
    PATH: '/usr/local/bin:/usr/bin:/bin',
    SHELL: '/bin/forge',
    LANG: 'en_US.UTF-8',
    TERM: 'xterm-256color',
    FORCE_COLOR: '1',
    ...((typeof globalThis !== 'undefined' && globalThis.__forgeEnv) || {}),
  },
  platform: 'darwin',
  arch: 'arm64',
  type: 'Darwin',
  release: '23.0.0',
  version: 'v20.0.0',
  versions: { node: '20.0.0', v8: '11.0.0', uv: '1.44.0', openssl: '3.0.0' },
  pid: 1, ppid: 0, title: 'forge',
  argv: ['forge'], execArgv: [], execPath: '/usr/local/bin/forge',
  cwd() {
    const native = (typeof globalThis !== 'undefined' && globalThis.window?.__forgeNative);
    return native?.cwd ?? '/tmp';
  },
  chdir(dir) {
    const native = (typeof globalThis !== 'undefined' && globalThis.window?.__forgeNative);
    if (native?.call) native.call('chdir', dir).then(undefined, function () {});
  },
  stdout: {
    write(data) {
      const native = (typeof globalThis !== 'undefined' && globalThis.window?.__forgeNative);
      if (native?.output) {
        const str = typeof data === 'string' ? data : new TextDecoder().decode(data);
        native.output(str);
      }
      return true;
    },
    end() {}, on() { return this; }, once() { return this; }, emit() { return false; },
    isTTY: true, columns: 80, rows: 24,
    getColorDepth() { return 256; }, hasColors() { return true; },
  },
  stderr: {
    write(data) {
      const native = (typeof globalThis !== 'undefined' && globalThis.window?.__forgeNative);
      if (native?.error) {
        const str = typeof data === 'string' ? data : new TextDecoder().decode(data);
        native.error(str);
      }
      return true;
    },
    end() {}, on() { return this; }, once() { return this; }, emit() { return false; },
    isTTY: true, columns: 80, rows: 24,
    getColorDepth() { return 256; }, hasColors() { return true; },
  },
  stdin: {
    isTTY: true, readable: true,
    on() { return this; }, once() { return this; }, emit() { return false; },
    resume() { return this; }, pause() { return this; }, read() { return null; }, setEncoding() { return this; },
  },
  exit(code) {
    const native = (typeof globalThis !== 'undefined' && globalThis.window?.__forgeNative);
    if (native?.exit) native.exit(code ?? 0);
    throw new Error('[FORGE] process.exit(' + (code ?? 0) + ') called');
  },
  _events: {},
  on(event, listener) {
    if (event === 'uncaughtException' || event === 'unhandledRejection') {
      if (typeof globalThis !== 'undefined') {
        globalThis.addEventListener?.('error', function (e) {
          listener(e.error || new Error(e.message));
        });
        globalThis.addEventListener?.('unhandledrejection', function (e) {
          listener(e.reason || new Error('Unhandled promise rejection'));
        });
      }
    }
    return this;
  },
  once(event, listener) { return this.on(event, function () { listener.apply(null, arguments); }); },
  off() { return this; }, removeListener() { return this; }, removeAllListeners() { return this; },
  emit() { return false; }, addListener() { return this; },
  listeners() { return []; }, listenerCount() { return 0; },
  nextTick(callback) {
    const args = Array.prototype.slice.call(arguments, 1);
    Promise.resolve().then(function () { callback.apply(null, args); });
  },
  hrtime: {
    bigint() {
      const ms = (typeof performance !== 'undefined' ? performance.now() : Date.now());
      return BigInt(Math.floor(ms * 1000000));
    },
  },
  hrtimeBigint() { return this.hrtime.bigint(); },
  memoryUsage() {
    const native = (typeof globalThis !== 'undefined' && globalThis.window?.__forgeNative);
    const mem = native?.getMemoryUsage?.() ?? {};
    return {
      rss: mem.rss ?? 100 * 1024 * 1024, heapTotal: mem.heapTotal ?? 50 * 1024 * 1024,
      heapUsed: mem.heapUsed ?? 25 * 1024 * 1024, external: mem.external ?? 10 * 1024 * 1024,
      arrayBuffers: mem.arrayBuffers ?? 1024 * 1024,
    };
  },
  cpuUsage() { return { user: 0, system: 0 }; },
  resourceUsage() { return {}; },
  uptime() {
    const native = (typeof globalThis !== 'undefined' && globalThis.window?.__forgeNative);
    return native?.uptime ?? Math.floor((typeof performance !== 'undefined' ? performance.now() : Date.now()) / 1000);
  },
  features: {}, moduleLoadList: [], allowedNodeEnvironmentFlags: new Set(),
  _debugProcess() {}, _debugEnd() {},
  assert(condition, message) {
    if (!condition) throw new Error('Assertion failed: ' + (message ?? ''));
  },
  report: {
    getReport() { return { header: { event: 'FORGE', platform: 'ios', arch: 'arm64' } }; },
    writeReport() {},
  },
  binding() { return {}; },
  dlopen() { throw new Error('[FORGE] process.dlopen() not supported on iOS'); },
  umask() { return 0o022; },
  getuid() { return 501; }, getgid() { return 20; },
  geteuid() { return 501; }, getegid() { return 20; },
  setuid() {}, setgid() {}, seteuid() {}, setegid() {}, setgroups() {}, initgroups() {},
  kill() { return true; }, abort() { throw new Error('[FORGE] process.abort() called'); },
  channel: null, connected: false, disconnect() {}, send() { return false; }, ref() {}, unref() {},
  mainModule: undefined,
};

const BufferShim = Buffer;
const globalShim = (typeof globalThis !== 'undefined') ? globalThis : {};

export { processShim as process, BufferShim as Buffer, globalShim as global };
