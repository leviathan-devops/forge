/**
 * forge-util.ts — Minimal util polyfill for FORGE/iOS.
 * Provides inspect, promisify, format, inherits, callbackify, deprecate, types.
 */

import { EventEmitter } from './forge-events.js';

// --- inspect ---

export interface InspectOptions {
  showHidden?: boolean;
  depth?: number | null;
  colors?: boolean;
  customInspect?: boolean;
  showProxy?: boolean;
  maxArrayLength?: number | null;
  breakLength?: number;
  compact?: boolean | number;
  sorted?: boolean | ((a: string, b: string) => number);
  getters?: 'get' | 'set' | 'both' | false;
}

const ANSI_COLORS = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
  gray: '\x1b[90m',
};

function colorize(str: string, color: keyof typeof ANSI_COLORS, enabled: boolean): string {
  if (!enabled) return str;
  return `${ANSI_COLORS[color]}${str}${ANSI_COLORS.reset}`;
}

export function inspect(value: any, options?: InspectOptions | number, ctx?: any): string {
  const opts: InspectOptions = typeof options === 'number'
    ? { depth: options }
    : options ?? {};

  const depth = opts.depth ?? 2;
  const colors = opts.colors ?? false;
  const maxArrayLength = opts.maxArrayLength ?? 100;

  function formatValue(val: any, currentDepth: number, seen: Set<any>): string {
    if (val === null) return colorize('null', 'bold', colors);
    if (val === undefined) return colorize('undefined', 'gray', colors);
    if (typeof val === 'boolean') return colorize(String(val), 'yellow', colors);
    if (typeof val === 'number') return colorize(String(val), 'yellow', colors);
    if (typeof val === 'bigint') return colorize(`${val}n`, 'yellow', colors);
    if (typeof val === 'string') return colorize(`'${val}'`, 'green', colors);
    if (typeof val === 'symbol') return colorize(val.toString(), 'green', colors);
    if (typeof val === 'function') {
      const name = val.name || 'anonymous';
      return colorize(`[Function: ${name}]`, 'cyan', colors);
    }

    // Circular reference
    if (seen.has(val)) return colorize('[Circular]', 'gray', colors);

    if (currentDepth >= (depth ?? 0)) {
      if (Array.isArray(val)) return colorize('[Array]', 'gray', colors);
      return colorize('[Object]', 'gray', colors);
    }

    seen.add(val);

    try {
      if (Array.isArray(val)) {
        if (val.length === 0) return '[]';
        const items = val.slice(0, maxArrayLength).map((item) => formatValue(item, currentDepth + 1, seen));
        if (val.length > maxArrayLength) {
          items.push(colorize(`... ${val.length - maxArrayLength} more items`, 'gray', colors));
        }
        const indent = '  '.repeat(currentDepth + 1);
        const closingIndent = '  '.repeat(currentDepth);
        return `[\n${indent}${items.join(`,\n${indent}`)}\n${closingIndent}]`;
      }

      if (val instanceof Error) {
        const stack = val.stack ? `\n${val.stack.split('\n').slice(1).join('\n')}` : '';
        return colorize(`[${val.constructor.name}: ${val.message}]`, 'red', colors) + stack;
      }

      if (val instanceof Date) {
        return colorize(`[Date: ${val.toISOString()}]`, 'magenta', colors);
      }

      if (val instanceof RegExp) {
        return colorize(val.toString(), 'red', colors);
      }

      if (val instanceof Map) {
        if (val.size === 0) return 'Map(0) {}';
        const entries = Array.from(val.entries()).map(([k, v]) => {
          return `${formatValue(k, currentDepth + 1, seen)} => ${formatValue(v, currentDepth + 1, seen)}`;
        });
        return `Map(${val.size}) { ${entries.join(', ')} }`;
      }

      if (val instanceof Set) {
        if (val.size === 0) return 'Set(0) {}';
        const entries = Array.from(val).map((v) => formatValue(v, currentDepth + 1, seen));
        return `Set(${val.size}) { ${entries.join(', ')} }`;
      }

      // Plain object
      if (typeof val === 'object') {
        // Check for custom inspect
        if (typeof val.inspect === 'function' && opts.customInspect !== false) {
          return val.inspect(depth, opts);
        }
        if (typeof val[Symbol.toPrimitive] === 'function') {
          const primitive = val[Symbol.toPrimitive]('string');
          if (typeof primitive === 'string') return primitive;
        }

        const keys = Object.keys(val);
        const symbols = Object.getOwnPropertySymbols(val);

        if (keys.length === 0 && symbols.length === 0) {
          return '{}';
        }

        // Check constructor
        const ctor = val.constructor?.name;
        const prefix = ctor && ctor !== 'Object' ? `${ctor} ` : '';

        const entries: string[] = [];
        for (const key of keys) {
          const formattedKey = /^[a-zA-Z_$][a-zA-Z0-9_$]*$/.test(key) ? key : `'${key}'`;
          entries.push(`${colorize(formattedKey, 'bold', colors)}: ${formatValue(val[key], currentDepth + 1, seen)}`);
        }
        for (const sym of symbols) {
          entries.push(`${colorize(`[${sym.toString()}]`, 'bold', colors)}: ${formatValue(val[sym], currentDepth + 1, seen)}`);
        }

        const indent = '  '.repeat(currentDepth + 1);
        const closingIndent = '  '.repeat(currentDepth);
        return `${prefix}{\n${indent}${entries.join(`,\n${indent}`)}\n${closingIndent}}`;
      }
    } finally {
      seen.delete(val);
    }

    return String(val);
  }

  return formatValue(value, 0, new Set());
}

inspect.custom = Symbol.for('nodejs.util.inspect.custom');
inspect.defaultOptions = {
  showHidden: false,
  depth: 2,
  colors: false,
  customInspect: true,
  compact: 3,
  breakLength: 80,
} as InspectOptions;

inspect.colors = {
  boolean: ANSI_COLORS.yellow,
  number: ANSI_COLORS.yellow,
  string: ANSI_COLORS.green,
  bigint: ANSI_COLORS.yellow,
  null: ANSI_COLORS.bold,
  undefined: ANSI_COLORS.gray,
  symbol: ANSI_COLORS.green,
  date: ANSI_COLORS.magenta,
  regexp: ANSI_COLORS.red,
  error: ANSI_COLORS.red,
  name: undefined,
  special: ANSI_COLORS.cyan,
};

inspect.styles = inspect.colors;

// --- format ---

export function format(fmt?: any, ...args: any[]): string {
  if (typeof fmt !== 'string' || args.length === 0) {
    return [fmt, ...args].map((arg) => inspect(arg)).join(' ');
  }

  let i = 0;
  return fmt.replace(/%[sdjifoO%]/g, (match) => {
    if (match === '%%') return '%';
    if (i >= args.length) return match;
    const arg = args[i++];
    switch (match) {
      case '%s': return String(arg);
      case '%d': return Number(arg).toString();
      case '%i': return parseInt(arg, 10).toString();
      case '%f': return parseFloat(arg).toString();
      case '%j':
        try { return JSON.stringify(arg); } catch { return '[Circular]'; }
      case '%o': return inspect(arg, { showHidden: false, depth: 4 });
      case '%O': return inspect(arg, { showHidden: true, depth: 4 });
      case '%f': return String(arg);
      default: return match;
    }
  });
}

// --- promisify ---

export function promisify<TResult>(
  fn: (...args: any[]) => void,
): (...args: any[]) => Promise<TResult> {
  return function (...args: any[]): Promise<TResult> {
    return new Promise((resolve, reject) => {
      fn.call(this, ...args, (err: Error | null, result: TResult) => {
        if (err) reject(err);
        else resolve(result);
      });
    });
  };
}

promisify.custom = Symbol.for('nodejs.util.promisify.custom');

// --- callbackify ---

export function callbackify<TResult>(
  fn: (...args: any[]) => Promise<TResult>,
): (...args: any[]) => void {
  return function (this: any, ...args: any[]): void {
    const cb = args[args.length - 1];
    if (typeof cb !== 'function') {
      throw new TypeError('callbackify: last argument must be a function');
    }
    fn.apply(this, args.slice(0, -1)).then(
      (result) => cb(null, result),
      (err) => cb(err),
    );
  };
}

// --- inherits ---

export function inherits(ctor: any, superCtor: any): void {
  if (ctor === undefined || ctor === null) {
    throw new TypeError('inherits: constructor argument is required');
  }
  if (superCtor === undefined || superCtor === null) {
    throw new TypeError('inherits: super constructor argument is required');
  }
  if (typeof superCtor !== 'function') {
    throw new TypeError('inherits: super constructor must be a function');
  }

  ctor.super_ = superCtor;
  ctor.prototype = Object.create(superCtor.prototype, {
    constructor: {
      value: ctor,
      enumerable: false,
      writable: true,
      configurable: true,
    },
  });
}

// --- deprecate ---

export function deprecate<T extends (...args: any[]) => any>(
  fn: T,
  message: string,
  code?: string,
): T {
  let warned = false;
  const deprecated = function (this: any, ...args: any[]): any {
    if (!warned) {
      warned = true;
      const native = (globalThis as any).window?.__forgeNative;
      if (native?.log) {
        native.log('warn', `[DEPRECATED] ${message}${code ? ` (code: ${code})` : ''}`);
      } else {
        console.warn(`[DEPRECATED] ${message}${code ? ` (code: ${code})` : ''}`);
      }
    }
    return fn.apply(this, args);
  } as T;

  return deprecated;
}

// --- types ---

export const types = {
  isAnyArrayBuffer(value: any): boolean {
    return value instanceof ArrayBuffer || value instanceof SharedArrayBuffer;
  },
  isArrayBuffer(value: any): boolean {
    return value instanceof ArrayBuffer;
  },
  isAsyncFunction(value: any): boolean {
    return typeof value === 'function' && value.constructor?.name === 'AsyncFunction';
  },
  isBigInt64Array(value: any): boolean {
    return value instanceof BigInt64Array;
  },
  isBigUint64Array(value: any): boolean {
    return value instanceof BigUint64Array;
  },
  isBooleanObject(value: any): boolean {
    return typeof value === 'object' && value instanceof Boolean;
  },
  isBoxedPrimitive(value: any): boolean {
    return value instanceof Boolean || value instanceof Number || value instanceof String || value instanceof Symbol;
  },
  isDataView(value: any): boolean {
    return value instanceof DataView;
  },
  isDate(value: any): boolean {
    return value instanceof Date;
  },
  isExternal(value: any): boolean {
    return false;
  },
  isFloat32Array(value: any): boolean {
    return value instanceof Float32Array;
  },
  isFloat64Array(value: any): boolean {
    return value instanceof Float64Array;
  },
  isGeneratorFunction(value: any): boolean {
    return typeof value === 'function' && value.constructor?.name === 'GeneratorFunction';
  },
  isGeneratorObject(value: any): boolean {
    return value !== null && typeof value === 'object' && value[Symbol.toStringTag] === 'Generator';
  },
  isInt8Array(value: any): boolean {
    return value instanceof Int8Array;
  },
  isInt16Array(value: any): boolean {
    return value instanceof Int16Array;
  },
  isInt32Array(value: any): boolean {
    return value instanceof Int32Array;
  },
  isMap(value: any): boolean {
    return value instanceof Map;
  },
  isMapIterator(value: any): boolean {
    return value !== null && typeof value === 'object' && ['Map Iterator', 'Set Iterator'].includes(value[Symbol.toStringTag]);
  },
  isModuleNamespaceObject(value: any): boolean {
    return value !== null && typeof value === 'object' && value[Symbol.toStringTag] === 'Module';
  },
  isNativeError(value: any): boolean {
    return value instanceof Error;
  },
  isNumberObject(value: any): boolean {
    return typeof value === 'object' && value instanceof Number;
  },
  isPromise(value: any): boolean {
    return value instanceof Promise;
  },
  isProxy(value: any): boolean {
    return false;
  },
  isRegExp(value: any): boolean {
    return value instanceof RegExp;
  },
  isSet(value: any): boolean {
    return value instanceof Set;
  },
  isSharedArrayBuffer(value: any): boolean {
    return value instanceof SharedArrayBuffer;
  },
  isStringObject(value: any): boolean {
    return typeof value === 'object' && value instanceof String;
  },
  isSymbolObject(value: any): boolean {
    return typeof value === 'object' && value instanceof Symbol;
  },
  isTypedArray(value: any): boolean {
    return (
      value instanceof Int8Array || value instanceof Uint8Array ||
      value instanceof Uint8ClampedArray || value instanceof Int16Array ||
      value instanceof Uint16Array || value instanceof Int32Array ||
      value instanceof Uint32Array || value instanceof Float32Array ||
      value instanceof Float64Array || value instanceof BigInt64Array ||
      value instanceof BigUint64Array
    );
  },
  isUint8Array(value: any): boolean {
    return value instanceof Uint8Array;
  },
  isUint8ClampedArray(value: any): boolean {
    return value instanceof Uint8ClampedArray;
  },
  isUint16Array(value: any): boolean {
    return value instanceof Uint16Array;
  },
  isUint32Array(value: any): boolean {
    return value instanceof Uint32Array;
  },
  isWeakMap(value: any): boolean {
    return value instanceof WeakMap;
  },
  isWeakSet(value: any): boolean {
    return value instanceof WeakSet;
  },
};

// --- isDeepStrictEqual ---

export function isDeepStrictEqual(val1: any, val2: any): boolean {
  if (val1 === val2) return true;
  if (typeof val1 !== typeof val2) return false;
  if (val1 === null || val2 === null) return val1 === val2;
  if (typeof val1 !== 'object') return val1 === val2;

  if (Array.isArray(val1) !== Array.isArray(val2)) return false;

  const keys1 = Object.keys(val1);
  const keys2 = Object.keys(val2);
  if (keys1.length !== keys2.length) return false;

  for (let i = 0; i < keys1.length; i++) {
    if (keys1[i] !== keys2[i]) return false;
    if (!isDeepStrictEqual(val1[keys1[i]], val2[keys2[i]])) return false;
  }

  return true;
}

// --- TextDecoder/TextEncoder passthrough ---

// TextDecoder/TextEncoder are provided as globals by the ES2022/DOM libs
const { TextDecoder, TextEncoder } = globalThis;
export { TextDecoder, TextEncoder };

// --- debuglog ---

export function debuglog(section: string): (...args: any[]) => void {
  const native = (globalThis as any).window?.__forgeNative;
  const debugEnv = (globalThis as any).process?.env?.NODE_DEBUG ?? '';
  const enabled = debugEnv.includes(section.toUpperCase());

  return (...args: any[]) => {
    if (enabled && native?.log) {
      native.log('debug', `[${section.toUpperCase()}] ${args.map((a) => (typeof a === 'string' ? a : inspect(a))).join(' ')}`);
    }
  };
}

// --- styleText ---

export function styleText(format: string | Record<string, any>, text: string): string {
  return text; // No-op — ANSI colors may not render in TUI
}

export default {
  inspect, format, promisify, callbackify, inherits, deprecate,
  types, isDeepStrictEqual, debuglog, styleText,
  inspectOptions: inspect.defaultOptions,
};
