/**
 * forge-sqlite.ts — SQL.js WASM SQLite for FORGE/iOS.
 * Per spec section 4.11.
 */

import { Buffer } from './forge-buffer.js';

interface SqlJsDatabase {
  run(sql: string, params?: any[]): any;
  exec(sql: string): any[];
  prepare(sql: string): SqlJsStatement;
  close(): void;
  export(): Uint8Array;
  getRowsModified(): number;
  create_function(name: string, fn: Function): void;
}

interface SqlJsStatement {
  bind(params?: any): boolean;
  step(): boolean;
  getAsObject(params?: any): any;
  getColumnNames(): string[];
  reset(): void;
  free(): void;
  run(params?: any): void;
}

interface SqlJsStatic {
  Database: new (data?: Uint8Array | null) => SqlJsDatabase;
}

let sqljsPromise: Promise<SqlJsStatic> | null = null;
let sqljsInstance: SqlJsStatic | null = null;

const WASM_URL_CANDIDATES = ['/sql-wasm.wasm', './sql-wasm.wasm', 'sql-wasm.wasm'];

async function loadSqlJs(): Promise<SqlJsStatic> {
  if (sqljsInstance) return sqljsInstance;
  if (sqljsPromise) return sqljsPromise;

  sqljsPromise = (async () => {
    const globalAny = globalThis as any;
    let initSqlJs: any = null;

    if (typeof globalAny.initSqlJs === 'function') {
      initSqlJs = globalAny.initSqlJs;
    } else if (typeof globalAny.require === 'function') {
      try {
        initSqlJs = globalAny.require('sql.js');
        if (initSqlJs?.default) initSqlJs = initSqlJs.default;
      } catch (requireErr) {
        initSqlJs = null;
      }
    }

    if (!initSqlJs) {
      throw new Error('[FORGE] sql.js WASM module not loaded. Ensure sql-wasm.wasm is bundled.');
    }

    let wasmBinary: Uint8Array | undefined;
    const native = globalAny.window?.__forgeNative;

    if (native?.call) {
      try {
        const wasmPath: string = await native.call('getResourcePath', 'sql-wasm.wasm');
        if (wasmPath) {
          const response = await fetch(wasmPath);
          if (response.ok) {
            const arrayBuffer = await response.arrayBuffer();
            wasmBinary = new Uint8Array(arrayBuffer);
          }
        }
      } catch (nativeErr) {
        // Native bridge path lookup failed, try local URLs
      }
    }

    if (!wasmBinary) {
      for (const url of WASM_URL_CANDIDATES) {
        try {
          const response = await fetch(url);
          if (response.ok) {
            const arrayBuffer = await response.arrayBuffer();
            wasmBinary = new Uint8Array(arrayBuffer);
            break;
          }
        } catch (fetchErr) {
          // Try next URL
        }
      }
    }

    const sqlConfig: any = {};
    if (wasmBinary) {
      sqlConfig.wasmBinary = wasmBinary;
    } else {
      sqlConfig.locateFile = (file: string) => WASM_URL_CANDIDATES[0];
    }

    const SQL = await initSqlJs(sqlConfig);
    sqljsInstance = SQL;
    return SQL;
  })();

  return sqljsPromise;
}

export interface DatabaseOptions {
  memory?: boolean;
  readonly?: boolean;
  fileMustExist?: boolean;
}

export class Database {
  private _db: SqlJsDatabase | null = null;
  private _path: string | null = null;
  private _open: boolean = false;
  private _initPromise: Promise<void>;

  constructor(path?: string | Buffer | URL, options?: DatabaseOptions) {
    this._path = typeof path === 'string' ? path : path instanceof Buffer ? path.toString() : null;
    this._initPromise = this._init(options);
  }

  private async _init(options?: DatabaseOptions): Promise<void> {
    const SQL = await loadSqlJs();
    let data: Uint8Array | null = null;

    if (this._path && !options?.memory) {
      const native = (globalThis as any).window?.__forgeNative;
      if (native?.call) {
        try {
          data = await native.call('fs:readFile', this._path);
        } catch (readErr) {
          if (!options?.fileMustExist) {
            data = null;
          } else {
            throw readErr;
          }
        }
      }
    }

    this._db = new SQL.Database(data);
    this._open = true;
    if (options?.readonly) this._db.exec('PRAGMA query_only = ON');
  }

  private async _ensureReady(): Promise<void> {
    await this._initPromise;
    if (!this._open || !this._db) throw new Error('[FORGE] Database is not open');
  }

  async prepare(sql: string, ...params: any[]): Promise<Statement> {
    await this._ensureReady();
    const stmt = this._db!.prepare(sql);
    if (params.length > 0) stmt.bind(params.length === 1 && Array.isArray(params[0]) ? params[0] : params);
    return new Statement(stmt);
  }

  async all(sql: string, ...params: any[]): Promise<Record<string, any>[]> {
    await this._ensureReady();
    const stmt = this._db!.prepare(sql);
    const bindParams = this._normalizeParams(params);
    if (bindParams) stmt.bind(bindParams);
    const results: Record<string, any>[] = [];
    while (stmt.step()) results.push(stmt.getAsObject());
    stmt.free();
    return results;
  }

  async get(sql: string, ...params: any[]): Promise<Record<string, any> | undefined> {
    await this._ensureReady();
    const stmt = this._db!.prepare(sql);
    const bindParams = this._normalizeParams(params);
    if (bindParams) stmt.bind(bindParams);
    let result: Record<string, any> | undefined;
    if (stmt.step()) result = stmt.getAsObject();
    stmt.free();
    return result;
  }

  async run(sql: string, ...params: any[]): Promise<RunResult> {
    await this._ensureReady();
    const bindParams = this._normalizeParams(params);
    const before = this._db!.getRowsModified();
    if (bindParams) this._db!.run(sql, bindParams);
    else this._db!.run(sql);
    const changes = this._db!.getRowsModified() - before;
    return { changes, lastInsertRowid: 0 };
  }

  async exec(sql: string): Promise<void> {
    await this._ensureReady();
    this._db!.exec(sql);
  }

  async each(sql: string, paramsOrCb: any, cb?: (row: Record<string, any>) => void): Promise<number> {
    const params = Array.isArray(paramsOrCb) ? paramsOrCb : [];
    const callback = typeof paramsOrCb === 'function' ? paramsOrCb : cb!;
    await this._ensureReady();
    const stmt = this._db!.prepare(sql);
    if (params.length > 0) stmt.bind(params);
    let count = 0;
    while (stmt.step()) { callback(stmt.getAsObject()); count++; }
    stmt.free();
    return count;
  }

  async persist(): Promise<void> {
    if (!this._db || !this._path) return;
    const data = this._db.export();
    const native = (globalThis as any).window?.__forgeNative;
    if (native?.call) await native.call('fs:writeFile', this._path, data);
  }

  async close(): Promise<void> {
    await this._initPromise;
    if (this._db) {
      try { await this.persist(); } catch (persistErr) { /* non-fatal on close */ }
      this._db.close();
      this._db = null;
      this._open = false;
    }
  }

  private _normalizeParams(params: any[]): any[] | null {
    if (params.length === 0) return null;
    if (params.length === 1) {
      const p = params[0];
      if (Array.isArray(p)) return p;
      if (p && typeof p === 'object' && !ArrayBuffer.isView(p)) return Object.values(p);
    }
    return params;
  }
}

export interface RunResult { changes: number; lastInsertRowid: number | bigint; }

export class Statement {
  private _stmt: SqlJsStatement;
  private _finalized: boolean = false;

  constructor(stmt: SqlJsStatement) { this._stmt = stmt; }

  bind(...params: any[]): boolean {
    return this._stmt.bind(params.length === 1 && Array.isArray(params[0]) ? params[0] : params);
  }
  reset(): void { this._stmt.reset(); }
  finalize(): void { if (!this._finalized) { this._stmt.free(); this._finalized = true; } }
  step(): boolean { return this._stmt.step(); }
  get(params?: any): Record<string, any> { return this._stmt.getAsObject(params); }
  all(params?: any): Record<string, any>[] {
    if (params) this._stmt.bind(params);
    const results: Record<string, any>[] = [];
    while (this._stmt.step()) results.push(this._stmt.getAsObject());
    return results;
  }
  run(params?: any): void { this._stmt.run(params); }
  free(): void { this.finalize(); }
}

export async function openDatabase(path: string, options?: DatabaseOptions): Promise<Database> {
  return new Database(path, options);
}

export default { Database, Statement, openDatabase };
