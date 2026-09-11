/**
 * forge-os.ts — OS constants shim for FORGE/iOS.
 * Per spec section 4.6 (os module replacement).
 */

export const platform: string = 'darwin';
export const arch: string = 'arm64';
export const type: string = 'Darwin';
export const release: string = '23.0.0';
export const hostname: string = 'iphone';
export const EOL: string = '\n';
export const devNull: string = '/dev/null';
export const endianness: 'LE' | 'BE' = 'LE';

export const constants = {
  signals: {
    SIGHUP: 1, SIGINT: 2, SIGQUIT: 3, SIGKILL: 9, SIGTERM: 15, SIGSTOP: 17,
  },
  errno: {
    E2BIG: 1, EACCES: 13, EAGAIN: 35, EBADF: 9, EBUSY: 16, ECHILD: 10,
    EDEADLK: 11, EDOM: 33, EEXIST: 17, EFAULT: 14, EFBIG: 27, EINPROGRESS: 36,
    EINTR: 4, EINVAL: 22, EIO: 5, EISDIR: 21, ELOOP: 62, EMFILE: 24,
    EMLINK: 31, ENAMETOOLONG: 63, ENFILE: 23, ENODEV: 19, ENOENT: 2,
    ENOEXEC: 8, ENOLCK: 77, ENOMEM: 12, ENOSPC: 28, ENOSYS: 78,
    ENOTDIR: 20, ENOTEMPTY: 66, ENOTTY: 25, ENXIO: 6, EPERM: 1,
    EPIPE: 32, EROFS: 30, ESPIPE: 29, ESRCH: 3, ETIMEDOUT: 60,
    ETXTBSY: 26, EXDEV: 18,
  },
  priority: {
    PRIORITY_LOW: 19, PRIORITY_BELOW_NORMAL: 10, PRIORITY_NORMAL: 0,
    PRIORITY_ABOVE_NORMAL: -7, PRIORITY_HIGH: -14, PRIORITY_HIGHEST: -20,
  },
  UV_UDP_REUSEADDR: 4,
};

function getSandboxPath(subdir: string): string {
  const native = (globalThis as any).window?.__forgeNative;
  if (native?.sandboxPath) {
    return `${native.sandboxPath}/${subdir}`;
  }
  return `/tmp/${subdir}`;
}

export function tmpdir(): string {
  return getSandboxPath('tmp');
}

export function homedir(): string {
  return getSandboxPath('home');
}

export function userInfo(): {
  username: string;
  uid: number;
  gid: number;
  shell: string;
  homedir: string;
} {
  return {
    username: 'forge',
    uid: 501,
    gid: 20,
    shell: '/bin/forge',
    homedir: homedir(),
  };
}

export function networkInterfaces(): Record<string, any[]> {
  return {};
}

export function cpus(): Array<{
  model: string;
  speed: number;
  times: { user: number; nice: number; sys: number; idle: number; irq: number };
}> {
  return [
    {
      model: 'Apple ARM64',
      speed: 0,
      times: { user: 0, nice: 0, sys: 0, idle: 0, irq: 0 },
    },
  ];
}

export function totalmem(): number {
  return 6 * 1024 * 1024 * 1024;
}

export function freemem(): number {
  const native = (globalThis as any).window?.__forgeNative;
  if (native?.getAvailableMemory) {
    const mem = native.getAvailableMemory();
    if (typeof mem === 'number' && mem > 0) return mem;
  }
  return 2 * 1024 * 1024 * 1024;
}

export function uptime(): number {
  const native = (globalThis as any).window?.__forgeNative;
  if (typeof native?.uptime === 'number') return native.uptime as number;
  return Math.floor(Date.now() / 1000);
}

export function loadavg(): number[] {
  return [0, 0, 0];
}

export function getPriority(): number {
  return 0;
}

export function setPriority(): void {
  // No-op on iOS — process priority cannot be adjusted
}

export default {
  platform, arch, type, release, hostname, EOL, endianness, constants,
  tmpdir, homedir, userInfo, networkInterfaces, cpus, totalmem, freemem,
  uptime, loadavg, getPriority, setPriority,
};
