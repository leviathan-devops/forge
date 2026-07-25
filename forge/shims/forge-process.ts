/**
 * forge-process.ts — Process shim for FORGE/iOS.
 * Per spec section 4.7.
 *
 * exec() routes through the native bridge (window.__forgeNative.call('runCommand')).
 * execSync() returns empty result with a warning (no synchronous subprocess on iOS).
 */

import { EventEmitter } from './forge-events.js';
import { Buffer } from './forge-buffer.js';

// --- Types ---

export interface ExecOptions {
  cwd?: string;
  env?: Record<string, string>;
  encoding?: string;
  shell?: string;
  timeout?: number;
  maxBuffer?: number;
  killSignal?: string;
  uid?: number;
  gid?: number;
  windowsHide?: boolean;
}

export interface ExecResult {
  stdout: string;
  stderr: string;
  exitCode: number | null;
}

export interface ChildProcess {
  pid: number;
  stdout: any;
  stderr: any;
  stdin: any;
  exitCode: number | null;
  killed: boolean;
  on(event: string, listener: (...args: any[]) => void): void;
  kill(signal?: string): boolean;
}

// --- exec (async via native bridge) ---

export function exec(
  command: string,
  options?: ExecOptions | ((err: Error | null, stdout: string, stderr: string) => void),
  callback?: (err: Error | null, stdout: string, stderr: string) => void,
): ChildProcess {
  // Handle overload: exec(command, callback)
  if (typeof options === 'function') {
    callback = options;
    options = {};
  }

  const opts: ExecOptions = (options as ExecOptions) ?? {};
  const emitter = new EventEmitter();

  const childProc: ChildProcess = {
    pid: -1,
    stdout: new EventEmitter(),
    stderr: new EventEmitter(),
    stdin: new EventEmitter(),
    exitCode: null,
    killed: false,
    on(event: string, listener: (...args: any[]) => void) {
      emitter.on(event, listener);
      return this;
    },
    kill(signal?: string): boolean {
      this.killed = true;
      emitter.emit('close', 137, signal ?? 'SIGTERM');
      return true;
    },
  };

  // Execute via native bridge
  const native = (globalThis as any).window?.__forgeNative;
  if (!native?.call) {
    const err = new Error('[FORGE] Native bridge not available for exec()');
    if (callback) callback(err, '', '');
    emitter.emit('error', err);
    return childProc;
  }

  native
    .call('runCommand', command, {
      cwd: opts.cwd,
      env: opts.env,
      timeout: opts.timeout,
    })
    .then((result: any) => {
      const stdout = typeof result === 'string' ? result : (result?.stdout ?? '');
      const stderr = result?.stderr ?? '';
      const exitCode = result?.exitCode ?? 0;

      childProc.exitCode = exitCode;
      childProc.stdout.emit('data', Buffer.from(stdout));
      childProc.stderr.emit('data', Buffer.from(stderr));
      emitter.emit('exit', exitCode, null);
      emitter.emit('close', exitCode, null);

      if (callback) {
        if (exitCode !== 0) {
          const err = new Error(`Command failed: ${command}\n${stderr}`) as any;
          err.code = exitCode;
          err.stdout = stdout;
          err.stderr = stderr;
          callback(err, stdout, stderr);
        } else {
          callback(null, stdout, stderr);
        }
      }
    })
    .catch((err: any) => {
      const errorMsg = err?.message ?? String(err);
      childProc.exitCode = 1;
      childProc.stderr.emit('data', Buffer.from(errorMsg));
      emitter.emit('error', err);
      emitter.emit('close', 1, null);
      if (callback) callback(err, '', errorMsg);
    });

  return childProc;
}

// --- execSync (returns empty with warning) ---

export function execSync(command: string, options?: ExecOptions): string | Buffer {
  const native = (globalThis as any).window?.__forgeNative;
  const encoding = options?.encoding ?? 'utf8';

  if (native?.log) {
    native.log('warn', `[FORGE] execSync() called but synchronous subprocess execution is not supported on iOS. Command: ${command}`);
  }

  // Return empty result — callers should check and use async exec() instead
  if (encoding === 'buffer') {
    return Buffer.alloc(0);
  }
  return '';
}

// --- spawn (async via native bridge) ---

export function spawn(
  command: string,
  args?: string[] | Record<string, any>,
  options?: Record<string, any>,
): ChildProcess {
  const argArray = Array.isArray(args) ? args : [];
  const fullCommand = `${command} ${argArray.join(' ')}`.trim();

  const emitter = new EventEmitter();

  const childProc: ChildProcess = {
    pid: -1,
    stdout: new EventEmitter(),
    stderr: new EventEmitter(),
    stdin: {
      write(data: any) { return true; },
      end() { return this; },
      on() { return this; },
    } as any,
    exitCode: null,
    killed: false,
    on(event: string, listener: (...args: any[]) => void) {
      emitter.on(event, listener);
      return this;
    },
    kill(signal?: string): boolean {
      this.killed = true;
      emitter.emit('close', 137, signal ?? 'SIGTERM');
      return true;
    },
  };

  const native = (globalThis as any).window?.__forgeNative;
  if (!native?.call) {
    setTimeout(() => {
      emitter.emit('error', new Error('[FORGE] Native bridge not available for spawn()'));
    }, 0);
    return childProc;
  }

  native
    .call('runCommand', fullCommand, {
      cwd: options?.cwd,
      env: options?.env,
    })
    .then((result: any) => {
      const stdout = typeof result === 'string' ? result : (result?.stdout ?? '');
      const stderr = result?.stderr ?? '';
      const exitCode = result?.exitCode ?? 0;
      childProc.exitCode = exitCode;
      childProc.stdout.emit('data', Buffer.from(stdout));
      childProc.stderr.emit('data', Buffer.from(stderr));
      emitter.emit('exit', exitCode, null);
      emitter.emit('close', exitCode, null);
    })
    .catch((err: any) => {
      emitter.emit('error', err);
      emitter.emit('close', 1, null);
    });

  return childProc;
}

export function spawnSync(command: string, args?: string[], options?: any): {
  pid: number;
  output: (string | null)[];
  stdout: string | Buffer;
  stderr: string | Buffer;
  status: number | null;
  error?: Error;
} {
  const native = (globalThis as any).window?.__forgeNative;
  if (native?.log) {
    native.log('warn', `[FORGE] spawnSync() not supported on iOS. Command: ${command}`);
  }
  const encoding = options?.encoding ?? 'utf8';
  const empty = encoding === 'buffer' ? Buffer.alloc(0) : '';
  return {
    pid: -1,
    output: [null, empty as any, empty as any],
    stdout: empty as any,
    stderr: empty as any,
    status: null,
    error: new Error('spawnSync is not supported on iOS'),
  };
}

// --- fork (not supported) ---

export function fork(modulePath: string, args?: string[], options?: any): ChildProcess {
  throw new Error(`[FORGE] fork() is not supported on iOS. Cannot create child processes. Module: ${modulePath}`);
}

export default { exec, execSync, spawn, spawnSync, fork };
