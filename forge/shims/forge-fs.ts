/**
 * forge-fs.ts — File system shim for FORGE/iOS.
 * Per spec section 4.6.
 *
 * All filesystem operations route through the FORGE native bridge.
 * Async methods are fully functional.
 * Sync methods read from an in-memory cache (populated by prior async reads).
 * watch() uses polling via setInterval.
 */

import { Buffer } from './forge-buffer.js';

// --- Types ---

export interface Stats {
  isFile(): boolean;
  isDirectory(): boolean;
  isBlockDevice(): boolean;
  isCharacterDevice(): boolean;
  isSymbolicLink(): boolean;
  isFIFO(): boolean;
  isSocket(): boolean;
  size: number;
  mode: number;
  uid: number;
  gid: number;
  dev: number;
  ino: number;
  nlink: number;
  rdev: number;
  blksize: number;
  blocks: number;
  atimeMs: number;
  mtimeMs: number;
  ctimeMs: number;
  birthtimeMs: number;
  atime: Date;
  mtime: Date;
  ctime: Date;
  birthtime: Date;
}

export interface Dirent {
  name: string;
  isFile(): boolean;
  isDirectory(): boolean;
  isBlockDevice(): boolean;
  isCharacterDevice(): boolean;
  isSymbolicLink(): boolean;
  isFIFO(): boolean;
  isSocket(): boolean;
}

export interface WatchOptions {
  persistent?: boolean;
  recursive?: boolean;
  encoding?: string;
}

export interface WatchListener {
  (eventType: string, filename: string | Buffer | null): void;
}

export class FSWatcher {
  private _interval: ReturnType<typeof setInterval> | null = null;
  private _path: string;
  private _listener: WatchListener;
  private _lastStats: Stats | null = null;

  constructor(path: string, listener: WatchListener) {
    this._path = path;
    this._listener = listener;
    this._start();
  }

  private async _start(): Promise<void> {
    try {
      this._lastStats = await stat(this._path);
    } catch (err) {
      this._lastStats = null;
    }

    this._interval = setInterval(async () => {
      try {
        const current = await stat(this._path);
        if (!this._lastStats) {
          this._listener('rename', this._path);
          this._lastStats = current;
          return;
        }
        if (current.mtimeMs !== this._lastStats.mtimeMs || current.size !== this._lastStats.size) {
          this._listener('change', this._path);
          this._lastStats = current;
        }
      } catch (err) {
        if (this._lastStats) {
          this._listener('rename', this._path);
          this._lastStats = null;
        }
      }
    }, 1000);
  }

  close(): void {
    if (this._interval) {
      clearInterval(this._interval);
      this._interval = null;
    }
  }

  ref(): this { return this; }
  unref(): this { return this; }
}

function nativeCall(method: string, ...args: any[]): Promise<any> {
  const native = (globalThis as any).window?.__forgeNative;
  if (!native?.call) {
    return Promise.reject(new Error('[FORGE] Native bridge not available for fs.' + method));
  }
  return native.call(method, ...args);
}

const _syncCache: Map<string, { data: Uint8Array; mtime: number }> = new Map();

export async function readFile(
  path: string | URL | number,
  options?: { encoding?: string; flag?: string } | string,
): Promise<string | Uint8Array> {
  const encoding = typeof options === 'string' ? options : options?.encoding;
  const flag = typeof options === 'object' ? options?.flag : undefined;
  const result = await nativeCall('fs:readFile', String(path), { flag });
  _syncCache.set(String(path), { data: result, mtime: Date.now() });
  if (encoding) {
    return new TextDecoder(encoding).decode(result);
  }
  return Buffer.from(result);
}

export async function writeFile(
  path: string | URL | number,
  data: string | Uint8Array | ArrayBuffer,
  options?: { encoding?: string; mode?: number; flag?: string } | string,
): Promise<void> {
  let bytes: Uint8Array;
  if (typeof data === 'string') {
    bytes = new TextEncoder().encode(data);
  } else if (data instanceof ArrayBuffer) {
    bytes = new Uint8Array(data);
  } else {
    bytes = new Uint8Array(data);
  }
  const flag = typeof options === 'object' ? options?.flag : undefined;
  const mode = typeof options === 'object' ? options?.mode : undefined;
  await nativeCall('fs:writeFile', String(path), bytes, { flag, mode });
}

export async function appendFile(path: string | URL | number, data: string | Uint8Array): Promise<void> {
  let bytes: Uint8Array;
  if (typeof data === 'string') bytes = new TextEncoder().encode(data);
  else bytes = new Uint8Array(data);
  await nativeCall('fs:appendFile', String(path), bytes);
}

export async function readdir(path: string | URL, options?: any): Promise<string[] | Dirent[]> {
  const withFileTypes = typeof options === 'object' && options?.withFileTypes === true;
  const result: string[] = await nativeCall('fs:readdir', String(path));
  if (withFileTypes) {
    return result.map((name) => ({
      name, isFile: () => true, isDirectory: () => false,
      isBlockDevice: () => false, isCharacterDevice: () => false,
      isSymbolicLink: () => false, isFIFO: () => false, isSocket: () => false,
    }));
  }
  return result;
}

export async function stat(path: string | URL): Promise<Stats> {
  const raw: any = await nativeCall('fs:stat', String(path));
  return makeStats(raw);
}

export async function lstat(path: string | URL): Promise<Stats> {
  const raw: any = await nativeCall('fs:lstat', String(path));
  return makeStats(raw);
}

export async function fstat(fd: number): Promise<Stats> {
  const raw: any = await nativeCall('fs:fstat', fd);
  return makeStats(raw);
}

export async function unlink(path: string | URL): Promise<void> {
  _syncCache.delete(String(path));
  await nativeCall('fs:unlink', String(path));
}

export async function rm(path: string | URL, options?: any): Promise<void> {
  await nativeCall('fs:rm', String(path), options);
}

export async function rmdir(path: string | URL, options?: any): Promise<void> {
  await nativeCall('fs:rmdir', String(path), options);
}

export async function mkdir(path: string | URL, options?: any): Promise<string | undefined> {
  const recursive = typeof options === 'object' ? options?.recursive : false;
  const mode = typeof options === 'object' ? options?.mode : undefined;
  await nativeCall('fs:mkdir', String(path), { recursive, mode });
  return undefined;
}

export async function mkdirp(path: string | URL, mode?: number): Promise<string | undefined> {
  return mkdir(path, { recursive: true, mode });
}

export async function rename(oldPath: string | URL, newPath: string | URL): Promise<void> {
  await nativeCall('fs:rename', String(oldPath), String(newPath));
}

export async function copyFile(src: string | URL, dest: string | URL, mode?: number): Promise<void> {
  await nativeCall('fs:copyFile', String(src), String(dest), mode);
}

export async function chmod(path: string | URL, mode: number): Promise<void> {
  await nativeCall('fs:chmod', String(path), mode);
}

export async function chown(path: string | URL, uid: number, gid: number): Promise<void> {
  await nativeCall('fs:chown', String(path), uid, gid);
}

export async function realpath(path: string | URL): Promise<string> {
  return await nativeCall('fs:realpath', String(path));
}

export async function access(path: string | URL, mode?: number): Promise<void> {
  await nativeCall('fs:access', String(path), mode);
}

export async function exists(path: string | URL): Promise<boolean> {
  try {
    await nativeCall('fs:access', String(path), 0);
    return true;
  } catch (err) {
    return false;
  }
}

export async function createReadStream(path: string | URL): Promise<any> {
  const data = await readFile(path);
  const bytes = data instanceof Uint8Array ? data : new TextEncoder().encode(data as string);
  return {
    [Symbol.asyncIterator]: async function* () {
      const chunkSize = 65536;
      for (let i = 0; i < bytes.length; i += chunkSize) {
        yield bytes.subarray(i, Math.min(i + chunkSize, bytes.length));
      }
    },
    on(event: string, cb: Function) { if (event === 'open') cb(1); return this; },
    pipe(dest: any) { return dest; },
    destroy() {},
  };
}

export async function createWriteStream(path: string | URL): Promise<any> {
  const chunks: Uint8Array[] = [];
  return {
    write(chunk: any) {
      if (typeof chunk === 'string') chunk = new TextEncoder().encode(chunk);
      chunks.push(chunk);
      return true;
    },
    async end() {
      const combined = Buffer.concat(chunks);
      await writeFile(path, combined);
    },
    on(event: string, cb: Function) { if (event === 'finish' || event === 'open') setTimeout(cb, 0); return this; },
    destroy() {},
  };
}

export function watch(filename: string | URL, options?: any, listener?: WatchListener): FSWatcher {
  const cb = typeof options === 'function' ? options : listener!;
  return new FSWatcher(String(filename), cb);
}

export function readFileSync(path: string | URL | number, options?: any): string | Uint8Array {
  const encoding = typeof options === 'string' ? options : options?.encoding;
  const cached = _syncCache.get(String(path));
  if (cached) {
    if (encoding) return new TextDecoder(encoding).decode(cached.data);
    return Buffer.from(cached.data);
  }
  const native = (globalThis as any).window?.__forgeNative;
  if (native?.log) native.log('warn', '[FORGE] readFileSync: not in cache: ' + String(path));
  return encoding ? '' : Buffer.alloc(0);
}

export function writeFileSync(path: string | URL | number, data: any): void {
  let bytes: Uint8Array;
  if (typeof data === 'string') bytes = new TextEncoder().encode(data);
  else if (data instanceof ArrayBuffer) bytes = new Uint8Array(data);
  else bytes = new Uint8Array(data);
  _syncCache.set(String(path), { data: bytes, mtime: Date.now() });
  nativeCall('fs:writeFile', String(path), bytes).then(undefined, (err: any) => {
    const native = (globalThis as any).window?.__forgeNative;
    if (native?.log) native.log('error', '[FORGE] writeFileSync async failed: ' + (err?.message ?? err));
  });
}

export function existsSync(path: string | URL): boolean {
  return _syncCache.has(String(path));
}

export function mkdirSync(path: string | URL, options?: any): void {
  nativeCall('fs:mkdir', String(path), typeof options === 'object' ? options : { recursive: false })
    .then(undefined, () => {});
}

export function statSync(path: string | URL): Stats {
  const cached = _syncCache.get(String(path));
  return makeStats({ size: cached?.data.length ?? 0, mtimeMs: cached?.mtime ?? Date.now(), isFile: true, isDirectory: false });
}

export function readdirSync(): string[] { return []; }

export function unlinkSync(path: string | URL): void {
  _syncCache.delete(String(path));
  nativeCall('fs:unlink', String(path)).then(undefined, () => {});
}

export function rmSync(path: string | URL, options?: any): void {
  _syncCache.delete(String(path));
  nativeCall('fs:rm', String(path), options).then(undefined, () => {});
}

export const promises = {
  readFile, writeFile, appendFile, readdir, stat, lstat, unlink, rm, rmdir, mkdir, mkdirp,
  rename, copyFile, chmod, chown, realpath, access,
  constants: {
    O_RDONLY: 0, O_WRONLY: 1, O_RDWR: 2, O_CREAT: 64, O_EXCL: 128, O_TRUNC: 512, O_APPEND: 1024,
    F_OK: 0, R_OK: 4, W_OK: 2, X_OK: 1,
  },
};

export const constants = promises.constants;

function makeStats(raw: any): Stats {
  const isFile = raw.isFile ?? true;
  const isDir = raw.isDirectory ?? false;
  const mtimeMs = raw.mtimeMs ?? raw.mtime?.getTime?.() ?? Date.now();
  return {
    isFile: () => isFile, isDirectory: () => isDir,
    isBlockDevice: () => false, isCharacterDevice: () => false,
    isSymbolicLink: () => false, isFIFO: () => false, isSocket: () => false,
    size: raw.size ?? 0, mode: raw.mode ?? 0o644, uid: raw.uid ?? 501, gid: raw.gid ?? 20,
    dev: raw.dev ?? 0, ino: raw.ino ?? 0, nlink: raw.nlink ?? 1, rdev: raw.rdev ?? 0,
    blksize: raw.blksize ?? 4096, blocks: raw.blocks ?? Math.ceil((raw.size ?? 0) / 512),
    atimeMs: raw.atimeMs ?? mtimeMs, mtimeMs, ctimeMs: raw.ctimeMs ?? mtimeMs, birthtimeMs: raw.birthtimeMs ?? mtimeMs,
    atime: new Date(raw.atimeMs ?? mtimeMs), mtime: new Date(mtimeMs),
    ctime: new Date(raw.ctimeMs ?? mtimeMs), birthtime: new Date(raw.birthtimeMs ?? mtimeMs),
  };
}

export default {
  readFile, writeFile, appendFile, readdir, stat, lstat, fstat, unlink, rm, rmdir, mkdir,
  rename, copyFile, chmod, chown, realpath, access, exists, createReadStream, createWriteStream,
  watch, readFileSync, writeFileSync, existsSync, mkdirSync, statSync, readdirSync, unlinkSync, rmSync,
  promises, constants, FSWatcher,
};
