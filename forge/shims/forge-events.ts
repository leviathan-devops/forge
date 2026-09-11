/**
 * forge-events.ts — EventEmitter implementation for FORGE/iOS.
 * Per spec section 4.10.
 *
 * Minimal but complete EventEmitter compatible with Node.js API.
 */

export type Listener = (...args: any[]) => void;
export type OnceWrapper = { listener: Listener; rawListener: Listener };

const kMaxListeners = 10;
const kCaptureRejectionSymbol = Symbol('kCapture');

export class EventEmitter {
  private _events: Map<string | symbol, any[]> = new Map();
  private _maxListeners: number = kMaxListeners;
  [kCaptureRejectionSymbol]: boolean = false;

  static defaultMaxListeners: number = kMaxListeners;
  static captureRejectionSymbol: symbol = Symbol.for('nodejs.rejection');
  static errorMonitor: symbol = Symbol('events.errorMonitor');

  static once(emitter: EventEmitter, name: string | symbol, options?: any): Promise<any[]> {
    return new Promise((resolve, reject) => {
      if (options?.signal instanceof EventTarget) {
        if ((options.signal as any).aborted) {
          reject(new Error('The operation was aborted'));
          return;
        }
        (options.signal as EventTarget).addEventListener('abort', () => {
          emitter.removeListener(name, onceListener);
          reject(new Error('The operation was aborted'));
        });
      }

      const onceListener = (...args: any[]) => {
        emitter.removeListener(name, onceListener);
        resolve(args);
      };
      emitter.once(name, onceListener);
    });
  }

  static on(emitter: EventEmitter, name: string | symbol, options?: any): AsyncIterableIterator<any[]> {
    const queue: any[][] = [];
    let resolveNext: ((value: IteratorResult<any[]>) => void) | null = null;
    let done = false;

    const listener = (...args: any[]) => {
      if (resolveNext) {
        const r = resolveNext;
        resolveNext = null;
        r({ value: args, done: false });
      } else {
        queue.push(args);
      }
    };

    emitter.on(name, listener);

    const cleanup = () => {
      done = true;
      emitter.removeListener(name, listener);
    };

    if (options?.signal instanceof EventTarget) {
      (options.signal as EventTarget).addEventListener('abort', cleanup);
    }

    return {
      [Symbol.asyncIterator]() {
        return this;
      },
      async next(): Promise<IteratorResult<any[]>> {
        if (queue.length > 0) {
          return { value: queue.shift()!, done: false };
        }
        if (done) {
          return { value: undefined, done: true };
        }
        return new Promise((resolve) => {
          resolveNext = resolve;
        });
      },
      async return(): Promise<IteratorResult<any[]>> {
        cleanup();
        return { value: undefined, done: true };
      },
      async throw(error?: any): Promise<IteratorResult<any[]>> {
        cleanup();
        throw error;
      },
    };
  }

  static listenerCount(emitter: EventEmitter, name: string | symbol): number {
    return emitter.listenerCount(name);
  }

  addListener(eventName: string | symbol, listener: Listener): this {
    if (typeof listener !== 'function') {
      throw new TypeError('The "listener" argument must be of type Function');
    }
    const existing = this._events.get(eventName);
    if (existing) {
      existing.push(listener);
    } else {
      this._events.set(eventName, [listener]);
    }
    this._warnIfNeeded(eventName);
    return this;
  }

  on(eventName: string | symbol, listener: Listener): this {
    return this.addListener(eventName, listener);
  }

  once(eventName: string | symbol, listener: Listener): this {
    if (typeof listener !== 'function') {
      throw new TypeError('The "listener" argument must be of type Function');
    }
    const wrapper: OnceWrapper = {
      listener: (...args: any[]) => {
        this.removeListener(eventName, wrapper.rawListener);
        listener(...args);
      },
      rawListener: null as any,
    };
    wrapper.rawListener = wrapper.listener;
    (wrapper.rawListener as any).__once = true;
    (wrapper.rawListener as any).__original = listener;

    const existing = this._events.get(eventName);
    if (existing) {
      existing.push(wrapper.rawListener);
    } else {
      this._events.set(eventName, [wrapper.rawListener]);
    }
    this._warnIfNeeded(eventName);
    return this;
  }

  prependListener(eventName: string | symbol, listener: Listener): this {
    if (typeof listener !== 'function') {
      throw new TypeError('The "listener" argument must be of type Function');
    }
    const existing = this._events.get(eventName);
    if (existing) {
      existing.unshift(listener);
    } else {
      this._events.set(eventName, [listener]);
    }
    this._warnIfNeeded(eventName);
    return this;
  }

  prependOnceListener(eventName: string | symbol, listener: Listener): this {
    if (typeof listener !== 'function') {
      throw new TypeError('The "listener" argument must be of type Function');
    }
    const wrapper: OnceWrapper = {
      listener: (...args: any[]) => {
        this.removeListener(eventName, wrapper.rawListener);
        listener(...args);
      },
      rawListener: null as any,
    };
    wrapper.rawListener = wrapper.listener;
    (wrapper.rawListener as any).__once = true;

    const existing = this._events.get(eventName);
    if (existing) {
      existing.unshift(wrapper.rawListener);
    } else {
      this._events.set(eventName, [wrapper.rawListener]);
    }
    this._warnIfNeeded(eventName);
    return this;
  }

  removeListener(eventName: string | symbol, listener: Listener): this {
    if (typeof listener !== 'function') {
      throw new TypeError('The "listener" argument must be of type Function');
    }
    const existing = this._events.get(eventName);
    if (!existing) return this;

    const idx = existing.indexOf(listener);
    if (idx !== -1) {
      existing.splice(idx, 1);
      if (existing.length === 0) {
        this._events.delete(eventName);
      }
    }
    return this;
  }

  off(eventName: string | symbol, listener: Listener): this {
    return this.removeListener(eventName, listener);
  }

  removeAllListeners(eventName?: string | symbol): this {
    if (eventName === undefined) {
      this._events.clear();
    } else {
      this._events.delete(eventName);
    }
    return this;
  }

  setMaxListeners(n: number): this {
    if (typeof n !== 'number' || n < 0 || Number.isNaN(n)) {
      throw new RangeError('The value of "n" is out of range');
    }
    this._maxListeners = n;
    return this;
  }

  getMaxListeners(): number {
    return this._maxListeners;
  }

  listeners(eventName: string | symbol): Listener[] {
    const existing = this._events.get(eventName);
    if (!existing) return [];
    return [...existing];
  }

  rawListeners(eventName: string | symbol): Listener[] {
    return this.listeners(eventName);
  }

  listenerCount(eventName: string | symbol): number {
    const existing = this._events.get(eventName);
    return existing ? existing.length : 0;
  }

  eventNames(): (string | symbol)[] {
    return [...this._events.keys()];
  }

  emit(eventName: string | symbol, ...args: any[]): boolean {
    const existing = this._events.get(eventName);
    if (!existing || existing.length === 0) return false;

    const listeners = [...existing];
    for (const listener of listeners) {
      try {
        listener(...args);
      } catch (err) {
        // Emit 'error' if there's an error listener, otherwise throw
        if (eventName !== 'error' && this.listenerCount('error') > 0) {
          this.emit('error', err);
        } else if (eventName === 'error') {
          // Re-throw unhandled error
          throw err;
        }
      }
    }
    return true;
  }

  private _warnIfNeeded(eventName: string | symbol): void {
    const count = this.listenerCount(eventName);
    if (this._maxListeners !== 0 && count > this._maxListeners) {
      const warnStr = `Possible EventEmitter memory leak detected. ${count} ${String(eventName)} listeners added. Use emitter.setMaxListeners() to increase limit`;
      console.warn(warnStr);
    }
  }
}

export default EventEmitter;
