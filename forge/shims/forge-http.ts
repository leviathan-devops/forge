/**
 * forge-http.ts — HTTP module shim using fetch() API.
 * Per spec section 4.6 (http/https module replacement).
 *
 * All HTTP requests use the browser fetch() API.
 * createServer() returns a noop (no server capability on iOS).
 */

import { EventEmitter } from './forge-events.js';
import { Buffer } from './forge-buffer.js';

// --- IncomingMessage / ServerResponse ---

export class IncomingMessage extends EventEmitter {
  statusCode: number = 200;
  statusMessage: string = 'OK';
  headers: Record<string, string | string[]> = {};
  httpVersion: string = '1.1';
  method: string = 'GET';
  url: string = '';
  complete: boolean = false;
  private _body: Uint8Array | null = null;
  private _bodyText: string | null = null;
  private _bodyOffset: number = 0;

  constructor(response: Response, body: Uint8Array) {
    super();
    this.statusCode = response.status;
    this.statusMessage = response.statusText;
    this.headers = {};
    response.headers.forEach((value, key) => {
      const existing = this.headers[key];
      if (existing) {
        this.headers[key] = Array.isArray(existing) ? [...existing, value] : [existing, value];
      } else {
        this.headers[key] = value;
      }
    });
    this._body = body;
  }

  get rawHeaders(): string[] {
    const result: string[] = [];
    for (const [key, value] of Object.entries(this.headers)) {
      if (Array.isArray(value)) {
        for (const v of value) {
          result.push(key, v);
        }
      } else {
        result.push(key, value);
      }
    }
    return result;
  }

  setEncoding(encoding: string): void {
    // Stored for toString calls
    this._bodyText = this._body ? new TextDecoder(encoding).decode(this._body) : '';
  }

  read(size?: number): Uint8Array | null {
    if (!this._body || this._bodyOffset >= this._body.length) return null;
    const end = size ? Math.min(this._bodyOffset + size, this._body.length) : this._body.length;
    const chunk = this._body.subarray(this._bodyOffset, end);
    this._bodyOffset = end;
    return chunk;
  }

  pipe(dest: any, options?: any): any {
    if (this._body) {
      dest.write(this._body);
    }
    dest.end();
    this.emit('end');
    return dest;
  }

  async text(): Promise<string> {
    if (this._bodyText !== null) return this._bodyText;
    if (this._body) {
      this._bodyText = new TextDecoder().decode(this._body);
      return this._bodyText;
    }
    return '';
  }

  async json(): Promise<any> {
    return JSON.parse(await this.text());
  }
}

export class ServerResponse extends EventEmitter {
  statusCode: number = 200;
  statusMessage: string = 'OK';
  headers: Record<string, string> = {};
  finished: boolean = false;
  headersSent: boolean = false;
  private _chunks: Uint8Array[] = [];

  writeHead(statusCode: number, headers?: Record<string, string>): this {
    this.statusCode = statusCode;
    if (headers) {
      Object.assign(this.headers, headers);
    }
    this.headersSent = true;
    return this;
  }

  setHeader(name: string, value: string | number | string[]): this {
    this.headers[name] = Array.isArray(value) ? value.join(', ') : String(value);
    return this;
  }

  getHeader(name: string): string | undefined {
    return this.headers[name];
  }

  removeHeader(name: string): this {
    delete this.headers[name];
    return this;
  }

  write(chunk: any, encoding?: string): boolean {
    if (typeof chunk === 'string') {
      this._chunks.push(new TextEncoder().encode(chunk));
    } else {
      this._chunks.push(new Uint8Array(chunk));
    }
    return true;
  }

  end(chunk?: any, encoding?: string): this {
    if (chunk !== undefined) {
      this.write(chunk, encoding);
    }
    this.finished = true;
    this.emit('finish');
    return this;
  }

  flushHeaders(): void {
    this.headersSent = true;
  }
}

// --- ClientRequest ---

export class ClientRequest extends EventEmitter {
  method: string;
  protocol: string;
  host: string;
  port: number;
  path: string;
  headers: Record<string, string>;
  private _body: Uint8Array[] = [];
  private _ended: boolean = false;
  private _aborted: boolean = false;
  private _timeout: ReturnType<typeof setTimeout> | null = null;
  response: IncomingMessage | null = null;

  constructor(url: string | URL, options: any, cb?: (res: IncomingMessage) => void) {
    super();

    if (typeof url === 'string') url = new URL(url);

    this.method = options?.method ?? 'GET';
    this.protocol = url.protocol;
    this.host = url.hostname;
    this.port = url.port ? parseInt(url.port, 10) : (url.protocol === 'https:' ? 443 : 80);
    this.path = url.pathname + url.search;
    this.headers = options?.headers ?? {};

    if (cb) {
      this.on('response', cb);
    }

    if (options?.timeout) {
      this.setTimeout(options.timeout);
    }
  }

  write(chunk: any, encoding?: string): boolean {
    if (this._ended) return false;
    if (typeof chunk === 'string') {
      this._body.push(new TextEncoder().encode(chunk));
    } else {
      this._body.push(new Uint8Array(chunk));
    }
    return true;
  }

  end(chunk?: any, encoding?: string, cb?: Function): this {
    if (typeof chunk === 'function') {
      cb = chunk;
      chunk = undefined;
    }
    if (typeof encoding === 'function') {
      cb = encoding;
      encoding = undefined;
    }

    if (chunk !== undefined) {
      this.write(chunk, encoding);
    }
    this._ended = true;
    this._doRequest().then((cb ?? (() => {})) as () => void);
    return this;
  }

  abort(): void {
    this._aborted = true;
    this.emit('abort');
    this.emit('error', new Error('Request aborted'));
  }

  destroy(err?: Error): this {
    this._aborted = true;
    if (this._timeout) clearTimeout(this._timeout);
    if (err) this.emit('error', err);
    this.emit('close');
    return this;
  }

  setTimeout(timeout: number, cb?: Function): this {
    if (this._timeout) clearTimeout(this._timeout);
    this._timeout = setTimeout(() => {
      this.destroy(new Error(`Request timeout after ${timeout}ms`));
    }, timeout);
    if (cb) this.on('timeout', cb as (...args: any[]) => void);
    return this;
  }

  setHeader(name: string, value: string): this {
    this.headers[name] = value;
    return this;
  }

  getHeader(name: string): string | undefined {
    return this.headers[name];
  }

  removeHeader(name: string): this {
    delete this.headers[name];
    return this;
  }

  private async _doRequest(): Promise<void> {
    if (this._aborted) return;

    const fullUrl = `${this.protocol}//${this.host}${this.port && ![80, 443].includes(this.port) ? `:${this.port}` : ''}${this.path}`;
    const body = this._body.length > 0 ? Buffer.concat(this._body) : undefined;

    try {
      const response = await fetch(fullUrl, {
        method: this.method,
        headers: this.headers,
        body: body && this.method !== 'GET' && this.method !== 'HEAD' ? body : undefined,
        redirect: 'follow',
      });

      const arrayBuffer = await response.arrayBuffer();
      const responseBody = new Uint8Array(arrayBuffer);

      this.response = new IncomingMessage(response, responseBody);
      this.response.complete = true;

      this.emit('response', this.response);
      this.response.emit('data', responseBody);
      this.response.emit('end');
      this.response.emit('close');

      if (this._timeout) clearTimeout(this._timeout);
      this.emit('close');
    } catch (err: any) {
      this.destroy(err);
    }
  }
}

// --- request() ---

export function request(
  options: string | URL | Record<string, any>,
  cb?: (res: IncomingMessage) => void,
): ClientRequest {
  let url: URL;
  let reqOptions: Record<string, any>;

  if (typeof options === 'string') {
    url = new URL(options);
    reqOptions = {};
  } else if (options instanceof URL) {
    url = options;
    reqOptions = {};
  } else {
    const protocol = options.protocol ?? 'http:';
    const host = options.hostname ?? options.host ?? 'localhost';
    const port = options.port ? `:${options.port}` : '';
    const path = options.path ?? '/';
    url = new URL(`${protocol}//${host}${port}${path}`);
    reqOptions = options;
  }

  return new ClientRequest(url, reqOptions, cb);
}

export function get(
  options: string | URL | Record<string, any>,
  cb?: (res: IncomingMessage) => void,
): ClientRequest {
  const req = request(options, cb);
  req.end();
  return req;
}

// --- Agent ---

export class Agent {
  maxSockets: number = Infinity;
  sockets: Record<string, any[]> = {};
  requests: Record<string, any[]> = {};

  createConnection(options: any, cb: Function): void {
    cb(null, {});
  }

  addRequest(req: ClientRequest, options: any): void {
    // No-op — fetch handles connection pooling
  }

  destroy(): void {
    // No-op
  }
}

export const globalAgent = new Agent();

// --- Server (noop) ---

export function createServer(
  requestListener?: (req: IncomingMessage, res: ServerResponse) => void,
): {
  listen: (...args: any[]) => void;
  close: (cb?: Function) => void;
  on: (event: string, cb: Function) => void;
} {
  const native = (globalThis as any).window?.__forgeNative;
  if (native?.log) {
    native.log('warn', '[FORGE] http.createServer() is not supported on iOS. Cannot listen for incoming connections.');
  }

  return {
    listen(...args: any[]) {
      const native = (globalThis as any).window?.__forgeNative;
      if (native?.log) {
        native.log('warn', '[FORGE] http.Server.listen() called but server functionality is not available on iOS.');
      }
      return this;
    },
    close(cb?: Function) {
      if (cb) cb();
    },
    on(event: string, cb: Function) {
      return this;
    },
  };
}

// --- Methods ---

export const METHODS = [
  'ACL', 'BIND', 'CHECKOUT', 'CONNECT', 'COPY', 'DELETE', 'GET',
  'HEAD', 'LINK', 'LOCK', 'M-SEARCH', 'MERGE', 'MKACTIVITY', 'MKCALENDAR',
  'MKCOL', 'MOVE', 'NOTIFY', 'OPTIONS', 'PATCH', 'POST', 'PRI', 'PROPFIND',
  'PROPPATCH', 'PURGE', 'PUT', 'REBIND', 'REPORT', 'SEARCH', 'SOURCE',
  'SUBSCRIBE', 'TRACE', 'UNBIND', 'UNLINK', 'UNLOCK', 'UNSUBSCRIBE',
];

export const STATUS_CODES: Record<number, string> = {
  100: 'Continue', 101: 'Switching Protocols', 102: 'Processing',
  200: 'OK', 201: 'Created', 202: 'Accepted', 203: 'Non-Authoritative Information',
  204: 'No Content', 205: 'Reset Content', 206: 'Partial Content',
  300: 'Multiple Choices', 301: 'Moved Permanently', 302: 'Found',
  303: 'See Other', 304: 'Not Modified', 307: 'Temporary Redirect',
  308: 'Permanent Redirect',
  400: 'Bad Request', 401: 'Unauthorized', 402: 'Payment Required',
  403: 'Forbidden', 404: 'Not Found', 405: 'Method Not Allowed',
  406: 'Not Acceptable', 407: 'Proxy Authentication Required',
  408: 'Request Timeout', 409: 'Conflict', 410: 'Gone',
  411: 'Length Required', 412: 'Precondition Failed', 413: 'Payload Too Large',
  414: 'URI Too Long', 415: 'Unsupported Media Type',
  416: 'Range Not Satisfiable', 417: 'Expectation Failed',
  418: "I'm a Teapot", 429: 'Too Many Requests',
  500: 'Internal Server Error', 501: 'Not Implemented', 502: 'Bad Gateway',
  503: 'Service Unavailable', 504: 'Gateway Timeout', 505: 'HTTP Version Not Supported',
};

export default {
  request,
  get,
  Agent,
  globalAgent,
  createServer,
  ClientRequest,
  IncomingMessage,
  ServerResponse,
  METHODS,
  STATUS_CODES,
};
