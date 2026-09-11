/**
 * forge-noop.ts — Empty module for unsupported Node.js APIs.
 * Used for: net, tls, dgram, dns, zlib, cluster, readline, child_process (sync parts).
 *
 * These modules cannot function in a browser/iOS sandbox.
 * Exports no-op stubs that don't throw on import but will throw
 * if actually invoked at runtime.
 */

function noop(): void {
  // Intentionally empty
}

function unsupported(name: string): (...args: any[]) => any {
  return function (...args: any[]): any {
    throw new Error(
      `[FORGE] Node.js '${name}' module is not available in the iOS/browser sandbox. ` +
        `This operation requires a native process which cannot be spawned here.`,
    );
  };
}

// Export a proxy that returns unsupported() for any property access
const noopProxy = new Proxy(
  {},
  {
    get(_target, prop) {
      if (prop === Symbol.toPrimitive) return () => '[FORGE noop module]';
      if (prop === 'then') return undefined; // not a promise
      if (prop === 'default') return noopProxy;
      if (typeof prop === 'string') {
        return unsupported(prop);
      }
      return undefined;
    },
  },
);

export default noopProxy;

export { noop, unsupported };
