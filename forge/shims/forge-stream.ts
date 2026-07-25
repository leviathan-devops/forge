/**
 * forge-stream.ts — Minimal stream classes for FORGE/iOS.
 * Per spec section 4.6 (stream module replacement).
 *
 * Extends EventEmitter. Provides Readable/Writable/Transform/PassThrough/Duplex.
 */

import { EventEmitter, type Listener } from './forge-events.js';
import { Buffer } from './forge-buffer.js';

export interface StreamOptions {
  highWaterMark?: number;
  encoding?: string;
  objectMode?: boolean;
  emitClose?: boolean;
  autoDestroy?: boolean;
  destroy?: (err: Error | null, cb: (err: Error | null) => void) => void;
}

export class Stream extends EventEmitter {
  pipe<T extends Writable>(dest: T, options?: { end?: boolean }): T {
    this.on('data', (chunk) => {
      const ok = dest.write(chunk);
      if (!ok) {
        (this as any).pause?.();
        dest.once('drain', () => (this as any).resume?.());
      }
    });
    this.on('end', () => {
      if (options?.end !== false) dest.end();
    });
    this.on('error', (err) => dest.emit('error', err));
    dest.emit('pipe', this);
    return dest;
  }

  unpipe<T extends Writable>(dest?: T): this {
    if (dest) {
      dest.emit('unpipe', this);
    }
    return this;
  }

  destroy(error?: Error | null): this {
    this.emit('close');
    if (error) this.emit('error', error);
    this.removeAllListeners();
    return this;
  }
}

export class Readable extends Stream {
  protected _readableState: {
    buffer: Uint8Array[];
    length: number;
    pipes: Writable[];
    ended: boolean;
    flowing: boolean | null;
    encoding: string | null;
    highWaterMark: number;
    objectMode: boolean;
    destroyed: boolean;
    paused: boolean;
  };

  constructor(options?: StreamOptions) {
    super();
    this._readableState = {
      buffer: [],
      length: 0,
      pipes: [],
      ended: false,
      flowing: null,
      encoding: options?.encoding ?? null,
      highWaterMark: options?.highWaterMark ?? 16384,
      objectMode: options?.objectMode ?? false,
      destroyed: false,
      paused: true,
    };
  }

  _read(_size: number): void {
    // Override in subclass
  }

  push(chunk: any, encoding?: string): boolean {
    const state = this._readableState;
    if (chunk === null) {
      state.ended = true;
      if (state.length === 0) {
        this.emit('end');
      }
      return false;
    }

    let data: any;
    if (!state.objectMode) {
      if (typeof chunk === 'string') {
        data = Buffer.from(chunk, encoding ?? state.encoding ?? 'utf8');
      } else if (chunk instanceof Uint8Array) {
        data = chunk;
      } else {
        data = Buffer.from(chunk);
      }
      state.length += data.length;
    } else {
      data = chunk;
      state.length += 1;
    }

    state.buffer.push(data);

    if (state.flowing === true) {
      this._flow();
    }

    return state.length < state.highWaterMark;
  }

  unshift(chunk: any): boolean {
    const state = this._readableState;
    state.buffer.unshift(chunk);
    state.length += state.objectMode ? 1 : (chunk?.length ?? 0);
    return state.length < state.highWaterMark;
  }

  read(n?: number): any {
    const state = this._readableState;

    if (state.buffer.length === 0) {
      if (state.ended) {
        this.emit('end');
      }
      return null;
    }

    let data: any;
    if (!state.objectMode) {
      const size = n ?? state.length;
      let result = Buffer.alloc(0);
      let remaining = size;

      while (state.buffer.length > 0 && remaining > 0) {
        const chunk = state.buffer[0];
        if (chunk.length <= remaining) {
          result = Buffer.concat([result, Buffer.from(chunk)]);
          state.buffer.shift();
          state.length -= chunk.length;
          remaining -= chunk.length;
        } else {
          const slice = Buffer.from(chunk).subarray(0, remaining);
          result = Buffer.concat([result, slice]);
          state.buffer[0] = Buffer.from(chunk).subarray(remaining);
          state.length -= remaining;
          remaining = 0;
        }
      }
      data = result.length > 0 ? result : null;
      if (data && state.encoding) {
        data = data.toString(state.encoding);
      }
    } else {
      data = state.buffer.shift();
      state.length -= 1;
    }

    if (state.length === 0 && state.ended) {
      this.emit('end');
    }

    return data;
  }

  setEncoding(encoding: string): this {
    this._readableState.encoding = encoding;
    return this;
  }

  pause(): this {
    this._readableState.flowing = false;
    this._readableState.paused = true;
    this.emit('pause');
    return this;
  }

  resume(): this {
    this._readableState.flowing = true;
    this._readableState.paused = false;
    this.emit('resume');
    this._flow();
    return this;
  }

  isPaused(): boolean {
    return this._readableState.paused;
  }

  private _flow(): void {
    const state = this._readableState;
    if (state.flowing !== true) return;

    const emitData = () => {
      while (state.buffer.length > 0 && state.flowing === true) {
        const chunk = state.buffer.shift();
        state.length -= state.objectMode ? 1 : chunk.length;
        this.emit('data', chunk);
      }
      if (state.ended && state.length === 0) {
        this.emit('end');
      }
    };

    emitData();
  }

  pipe<T extends Writable>(dest: T, options?: { end?: boolean }): T {
    this._readableState.flowing = true;
    this._readableState.paused = false;
    super.pipe(dest, options);
    this._flow();
    return dest;
  }

  [Symbol.asyncIterator](): AsyncIterableIterator<any> {
    const readable = this;
    let done = false;

    const onReadable = (): Promise<any> =>
      new Promise((resolve) => {
        readable.once('readable', () => resolve(null));
        readable.once('end', () => resolve(null));
      });

    return {
      [Symbol.asyncIterator]() {
        return this;
      },
      async next(): Promise<IteratorResult<any>> {
        if (done) return { value: undefined, done: true };

        let chunk = readable.read();
        if (chunk === null) {
          if (readable._readableState.ended) {
            done = true;
            return { value: undefined, done: true };
          }
          await onReadable();
          chunk = readable.read();
          if (chunk === null) {
            if (readable._readableState.ended) {
              done = true;
              return { value: undefined, done: true };
            }
            return { value: undefined, done: false };
          }
        }
        return { value: chunk, done: false };
      },
      async return(): Promise<IteratorResult<any>> {
        done = true;
        return { value: undefined, done: true };
      },
    };
  }
}

export class Writable extends Stream {
  protected _writableState: {
    buffer: { chunk: any; cb: Function }[];
    writing: boolean;
    ended: boolean;
    destroyed: boolean;
    decodeStrings: boolean;
    highWaterMark: number;
    objectMode: boolean;
  };

  constructor(options?: StreamOptions & {
    write?: (chunk: any, encoding: string, cb: Function) => void;
    writev?: (chunks: any[], cb: Function) => void;
    final?: (cb: Function) => void;
  }) {
    super();
    this._writableState = {
      buffer: [],
      writing: false,
      ended: false,
      destroyed: false,
      decodeStrings: true,
      highWaterMark: options?.highWaterMark ?? 16384,
      objectMode: options?.objectMode ?? false,
    };

    if (options?.write) {
      (this as any)._write = options.write;
    }
    if (options?.writev) {
      (this as any)._writev = options.writev;
    }
    if (options?.final) {
      (this as any)._final = options.final;
    }
  }

  _write(chunk: any, encoding: string, callback: Function): void {
    // Override in subclass
    callback();
  }

  _writev(chunks: Array<{ chunk: any; encoding: string }>, callback: Function): void {
    for (const { chunk } of chunks) {
      this._write(chunk, 'utf8', () => {});
    }
    callback();
  }

  _final(callback: Function): void {
    callback();
  }

  write(chunk: any, encoding?: string | Function, cb?: Function): boolean {
    if (typeof encoding === 'function') {
      cb = encoding;
      encoding = undefined;
    }

    const state = this._writableState;

    if (state.ended) {
      const err = new Error('write after end');
      this.emit('error', err);
      return false;
    }

    const enc = typeof encoding === 'string' ? encoding : 'utf8';
    let data = chunk;

    if (!state.objectMode && typeof data === 'string' && state.decodeStrings) {
      data = Buffer.from(data, enc);
    }

    const doWrite = () => {
      state.writing = true;
      this._write(data, enc, (err) => {
        state.writing = false;
        if (err) {
          this.emit('error', err);
          if (cb) cb(err);
          return;
        }
        if (cb) cb();
        this.emit('drain');

        // Process buffer
        if (state.buffer.length > 0) {
          const next = state.buffer.shift()!;
          doWriteChunk(next.chunk, next.cb);
        }
      });
    };

    const doWriteChunk = (c: any, callback: Function) => {
      state.writing = true;
      this._write(c, enc, (err) => {
        state.writing = false;
        if (err) {
          this.emit('error', err);
          callback(err);
          return;
        }
        callback();
        this.emit('drain');
        if (state.buffer.length > 0) {
          const next = state.buffer.shift()!;
          doWriteChunk(next.chunk, next.cb);
        }
      });
    };

    if (state.writing) {
      state.buffer.push({ chunk: data, cb: cb ?? (() => {}) });
      return false;
    }

    doWrite();
    return state.buffer.length < state.highWaterMark;
  }

  end(chunk?: any, encoding?: string | Function, cb?: Function): this {
    if (typeof chunk === 'function') {
      cb = chunk;
      chunk = undefined;
    }
    if (typeof encoding === 'function') {
      cb = encoding;
      encoding = undefined;
    }

    if (chunk !== undefined) {
      this.write(chunk, encoding as string);
    }

    const state = this._writableState;
    state.ended = true;

    const finish = () => {
      this._final((err) => {
        if (err) {
          this.emit('error', err);
        } else {
          this.emit('finish');
          if (cb) cb();
        }
      });
    };

    if (state.writing || state.buffer.length > 0) {
      this.once('drain', finish);
    } else {
      finish();
    }

    return this;
  }

  cork(): void {
    // No-op stub
  }

  uncork(): void {
    // No-op stub
  }

  setDefaultEncoding(encoding: string): this {
    return this;
  }
}

export class Duplex extends Readable {
  _writableState: Writable['_writableState'];

  constructor(options?: StreamOptions & {
    read?: () => void;
    write?: (chunk: any, encoding: string, cb: Function) => void;
  }) {
    super(options);
    this._writableState = (new Writable(options) as any)._writableState as Writable['_writableState'];
    if (options?.write) (this as any)._write = options.write;
  }

  _write(chunk: any, encoding: string, callback: Function): void {
    callback();
  }

  write(chunk: any, encoding?: string | Function, cb?: Function): boolean {
    return Writable.prototype.write.call(this, chunk, encoding as any, cb as any);
  }

  end(chunk?: any, encoding?: string | Function, cb?: Function): this {
    return Writable.prototype.end.call(this, chunk, encoding as any, cb as any);
  }
}

export class Transform extends Duplex {
  constructor(options?: StreamOptions & {
    transform?: (chunk: any, encoding: string, cb: (err?: Error | null, data?: any) => void) => void;
    flush?: (cb: (err?: Error | null, data?: any) => void) => void;
  }) {
    super(options);

    const transformFn = options?.transform;
    const flushFn = options?.flush;

    (this as any)._write = (chunk: any, encoding: string, cb: Function) => {
      if (transformFn) {
        transformFn(chunk, encoding, (err, data) => {
          if (err) {
            cb(err);
            return;
          }
          if (data !== undefined) {
            this.push(data);
          }
          cb();
        });
      } else {
        this.push(chunk);
        cb();
      }
    };

    (this as any)._final = (cb: Function) => {
      if (flushFn) {
        flushFn((err, data) => {
          if (err) {
            cb(err);
            return;
          }
          if (data !== undefined) {
            this.push(data);
          }
          cb();
        });
      } else {
        cb();
      }
    };
  }
}

export class PassThrough extends Transform {}

// --- Factory functions ---

export function ReadableFrom(iterable: Iterable<any> | AsyncIterable<any> | string, options?: StreamOptions): Readable {
  const readable = new Readable(options);
  if (typeof iterable === 'string') {
    readable.push(iterable);
    readable.push(null);
  } else {
    (async () => {
      for await (const chunk of iterable as AsyncIterable<any>) {
        if (!readable.push(chunk)) {
          await new Promise((r) => readable.once('drain', r));
        }
      }
      readable.push(null);
    })();
  }
  return readable;
}

export function addChunk(stream: Writable, state: any, chunk: any, cb: Function): void {
  stream.write(chunk, cb);
}

export default {
  Stream,
  Readable,
  Writable,
  Duplex,
  Transform,
  PassThrough,
  ReadableFrom,
};
