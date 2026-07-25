/**
 * forge-buffer.ts — Buffer class extending Uint8Array for FORGE/iOS.
 * Per spec section 4.6 (Buffer polyfill).
 *
 * Implements the subset of the Node.js Buffer API that opencode
 * and its dependencies actually use at runtime.
 */

const TEXT_ENCODER = new TextEncoder();
const TEXT_DECODER = new TextDecoder();

const BASE64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
const BASE64_LOOKUP = new Uint8Array(256);
for (let i = 0; i < 256; i++) BASE64_LOOKUP[i] = 255;
for (let i = 0; i < BASE64_CHARS.length; i++) BASE64_LOOKUP[BASE64_CHARS.charCodeAt(i)] = i;

const HEX_CHARS = '0123456789abcdef';

export class Buffer extends Uint8Array {
  static readonly poolSize: number = 8192;

  constructor(arg?: any, encodingOrOffset?: string | number, length?: number) {
    if (arg === undefined || arg === null) {
      super(0);
    } else if (typeof arg === 'number') {
      super(arg);
    } else if (arg instanceof Uint8Array || arg instanceof ArrayBuffer) {
      if (typeof encodingOrOffset === 'number') {
        const offset = encodingOrOffset;
        const len = typeof length === 'number' ? length : (arg as ArrayBuffer).byteLength - offset;
        super(arg as ArrayBuffer, offset, len);
      } else {
        super(arg);
      }
    } else if (Array.isArray(arg)) {
      super(arg);
    } else if (typeof arg === 'string') {
      const encoding = typeof encodingOrOffset === 'string' ? encodingOrOffset : 'utf8';
      const encoded = Buffer.encodeString(arg, encoding);
      super(encoded.byteLength);
      this.set(encoded);
    } else if (arg && typeof arg === 'object' && arg.length !== undefined) {
      super(arg.length);
      for (let i = 0; i < arg.length; i++) this[i] = arg[i] & 0xff;
    } else {
      super(0);
    }
  }

  // --- Static factory methods ---

  static alloc(size: number, fill: number | string | Uint8Array = 0, encoding: string = 'utf8'): Buffer {
    const buf = new Buffer(size);
    if (size > 0) {
      if (typeof fill === 'number') {
        buf.fill(fill);
      } else if (typeof fill === 'string') {
        const fillBuf = Buffer.from(fill, encoding);
        if (fillBuf.length === 0) return buf;
        for (let i = 0; i < size; i += fillBuf.length) {
          for (let j = 0; j < fillBuf.length && i + j < size; j++) {
            buf[i + j] = fillBuf[j];
          }
        }
      } else {
        buf.set(fill);
      }
    }
    return buf;
  }

  static allocUnsafe(size: number): Buffer {
    return new Buffer(size);
  }

  static allocUnsafeSlow(size: number): Buffer {
    return new Buffer(size);
  }

  static from(
    value: string | ArrayLike<number> | ArrayBuffer | Uint8Array | Buffer | SharedArrayBuffer,
    encodingOrOffset?: string | number,
    length?: number,
  ): Buffer {
    if (typeof value === 'string') {
      const encoding = typeof encodingOrOffset === 'string' ? encodingOrOffset : 'utf8';
      const encoded = Buffer.encodeString(value, encoding);
      const buf = new Buffer(encoded.byteLength);
      buf.set(encoded);
      return buf;
    }
    if (value instanceof Buffer) {
      const buf = new Buffer(value.byteLength);
      buf.set(value);
      return buf;
    }
    if (value instanceof Uint8Array) {
      if (typeof encodingOrOffset === 'number') {
        const offset = encodingOrOffset;
        const len = typeof length === 'number' ? length : value.byteLength - offset;
        const buf = new Buffer(len);
        buf.set(value.subarray(offset, offset + len));
        return buf;
      }
      const buf = new Buffer(value.byteLength);
      buf.set(value);
      return buf;
    }
    if (value instanceof ArrayBuffer) {
      if (typeof encodingOrOffset === 'number') {
        const offset = encodingOrOffset;
        const len = typeof length === 'number' ? length : value.byteLength - offset;
        return new Buffer(value, offset, len);
      }
      return new Buffer(value);
    }
    if (Array.isArray(value) || (value as any)?.length !== undefined) {
      const arr = Array.from(value as ArrayLike<number>);
      const buf = new Buffer(arr.length);
      for (let i = 0; i < arr.length; i++) buf[i] = arr[i] & 0xff;
      return buf;
    }
    return new Buffer(0);
  }

  static of(...bytes: number[]): Buffer {
    const buf = new Buffer(bytes.length);
    for (let i = 0; i < bytes.length; i++) buf[i] = bytes[i] & 0xff;
    return buf;
  }

  static isBuffer(obj: any): obj is Buffer {
    return obj instanceof Buffer;
  }

  static isEncoding(encoding: string): boolean {
    return ['utf8', 'utf-8', 'ascii', 'latin1', 'binary', 'base64', 'base64url', 'hex', 'ucs2', 'ucs-2', 'utf16le', 'utf-16le'].includes(
      String(encoding).toLowerCase(),
    );
  }

  static concat(list: Uint8Array[], totalLength?: number): Buffer {
    if (totalLength === undefined) {
      totalLength = 0;
      for (const item of list) totalLength += item.byteLength;
    }
    const buf = new Buffer(totalLength);
    let offset = 0;
    for (const item of list) {
      if (offset >= totalLength) break;
      const len = Math.min(item.byteLength, totalLength - offset);
      buf.set(item.subarray(0, len), offset);
      offset += len;
    }
    return buf;
  }

  static byteLength(string: string | ArrayBuffer | Uint8Array | Buffer, encoding: string = 'utf8'): number {
    if (typeof string !== 'string') {
      return (string as ArrayBuffer).byteLength;
    }
    return Buffer.encodeString(string, encoding).byteLength;
  }

  static compare(buf1: Uint8Array, buf2: Uint8Array): number {
    for (let i = 0; i < buf1.byteLength && i < buf2.byteLength; i++) {
      if (buf1[i] < buf2[i]) return -1;
      if (buf1[i] > buf2[i]) return 1;
    }
    if (buf1.byteLength < buf2.byteLength) return -1;
    if (buf1.byteLength > buf2.byteLength) return 1;
    return 0;
  }

  // --- Instance methods ---

  get length(): number {
    return this.byteLength;
  }

  toString(encoding: string = 'utf8', start: number = 0, end: number = this.byteLength): string {
    const slice = this.subarray(start, end);
    return Buffer.decodeBytes(slice, encoding);
  }

  toJSON(): { type: string; data: number[] } {
    return { type: 'Buffer', data: Array.from(this) };
  }

  subarray(start?: number, end?: number): Buffer {
    const view = super.subarray(start, end);
    // Return as Buffer (typed array subarray shares the same buffer)
    return Buffer.from(view.buffer, view.byteOffset, view.byteLength);
  }

  slice(start?: number, end?: number): Buffer {
    return this.subarray(start, end);
  }

  copy(targetBuffer: Uint8Array, targetStart: number = 0, sourceStart: number = 0, sourceEnd: number = this.byteLength): number {
    const len = Math.min(sourceEnd - sourceStart, targetBuffer.byteLength - targetStart, this.byteLength - sourceStart);
    if (len <= 0) return 0;
    for (let i = 0; i < len; i++) {
      targetBuffer[targetStart + i] = this[sourceStart + i];
    }
    return len;
  }

  fill(value: number | string | Uint8Array, offset: number = 0, end: number = this.byteLength, encoding: string = 'utf8'): this {
    if (typeof value === 'number') {
      const val = value & 0xff;
      for (let i = offset; i < end; i++) this[i] = val;
    } else if (typeof value === 'string') {
      const fillBuf = Buffer.from(value, encoding);
      if (fillBuf.length === 0) return this;
      for (let i = offset; i < end; i += fillBuf.length) {
        for (let j = 0; j < fillBuf.length && i + j < end; j++) {
          this[i + j] = fillBuf[j];
        }
      }
    } else {
      for (let i = offset; i < end; i += value.length) {
        for (let j = 0; j < value.length && i + j < end; j++) {
          this[i + j] = value[j];
        }
      }
    }
    return this;
  }

  equals(otherBuffer: Uint8Array): boolean {
    if (this.byteLength !== otherBuffer.byteLength) return false;
    return Buffer.compare(this, otherBuffer) === 0;
  }

  compare(otherBuffer: Uint8Array, targetStart: number = 0, targetEnd: number = otherBuffer.byteLength, sourceStart: number = 0, sourceEnd: number = this.byteLength): number {
    const a = this.subarray(sourceStart, sourceEnd);
    const b = (otherBuffer instanceof Buffer ? otherBuffer : Buffer.from(otherBuffer)).subarray(targetStart, targetEnd);
    return Buffer.compare(a, b);
  }

  indexOf(value: number | string | Uint8Array, byteOffset: number = 0, encoding: string = 'utf8'): number {
    let search: Uint8Array;
    if (typeof value === 'number') {
      const val = value & 0xff;
      for (let i = byteOffset; i < this.byteLength; i++) {
        if (this[i] === val) return i;
      }
      return -1;
    } else if (typeof value === 'string') {
      search = Buffer.from(value, encoding);
    } else {
      search = value;
    }
    if (search.byteLength === 0) return byteOffset;
    if (search.byteLength > this.byteLength - byteOffset) return -1;
    outer: for (let i = byteOffset; i <= this.byteLength - search.byteLength; i++) {
      for (let j = 0; j < search.byteLength; j++) {
        if (this[i + j] !== search[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  includes(value: number | string | Uint8Array, byteOffset: number = 0, encoding: string = 'utf8'): boolean {
    return this.indexOf(value, byteOffset, encoding) !== -1;
  }

  readUInt8(offset: number): number {
    return this[offset];
  }

  writeUInt8(value: number, offset: number): number {
    this[offset] = value & 0xff;
    return offset + 1;
  }

  readUInt16LE(offset: number): number {
    return this[offset] | (this[offset + 1] << 8);
  }

  writeUInt16LE(value: number, offset: number): number {
    this[offset] = value & 0xff;
    this[offset + 1] = (value >> 8) & 0xff;
    return offset + 2;
  }

  readUInt32LE(offset: number): number {
    return (this[offset] | (this[offset + 1] << 8) | (this[offset + 2] << 16) | (this[offset + 3] << 24)) >>> 0;
  }

  writeUInt32LE(value: number, offset: number): number {
    this[offset] = value & 0xff;
    this[offset + 1] = (value >> 8) & 0xff;
    this[offset + 2] = (value >> 16) & 0xff;
    this[offset + 3] = (value >> 24) & 0xff;
    return offset + 4;
  }

  readInt32LE(offset: number): number {
    return this[offset] | (this[offset + 1] << 8) | (this[offset + 2] << 16) | (this[offset + 3] << 24);
  }

  writeInt32LE(value: number, offset: number): number {
    return this.writeUInt32LE(value, offset);
  }

  readDoubleLE(offset: number): number {
    const view = new DataView(this.buffer, this.byteOffset + offset, 8);
    return view.getFloat64(0, true);
  }

  writeDoubleLE(value: number, offset: number): number {
    const view = new DataView(this.buffer, this.byteOffset + offset, 8);
    view.setFloat64(0, value, true);
    return offset + 8;
  }

  write(string: string, offset: number = 0, length: number = this.byteLength - offset, encoding: string = 'utf8'): number {
    const encoded = Buffer.encodeString(string, encoding);
    const len = Math.min(encoded.byteLength, length);
    for (let i = 0; i < len; i++) this[offset + i] = encoded[i];
    return len;
  }

  swap16(): this {
    for (let i = 0; i < this.byteLength - 1; i += 2) {
      const tmp = this[i];
      this[i] = this[i + 1];
      this[i + 1] = tmp;
    }
    return this;
  }

  swap32(): this {
    for (let i = 0; i < this.byteLength - 3; i += 4) {
      let tmp = this[i];
      this[i] = this[i + 3];
      this[i + 3] = tmp;
      tmp = this[i + 1];
      this[i + 1] = this[i + 2];
      this[i + 2] = tmp;
    }
    return this;
  }

  // --- Internal encoding helpers ---

  private static encodeString(str: string, encoding: string): Uint8Array {
    const enc = encoding.toLowerCase();
    switch (enc) {
      case 'utf8':
      case 'utf-8':
        return TEXT_ENCODER.encode(str);
      case 'ascii':
        return Buffer.encodeAscii(str);
      case 'latin1':
      case 'binary':
        return Buffer.encodeLatin1(str);
      case 'base64':
        return Buffer.decodeBase64(str);
      case 'base64url':
        return Buffer.decodeBase64(str.replace(/-/g, '+').replace(/_/g, '/'));
      case 'hex':
        return Buffer.decodeHex(str);
      case 'ucs2':
      case 'ucs-2':
      case 'utf16le':
      case 'utf-16le':
        return Buffer.encodeUtf16le(str);
      default:
        return TEXT_ENCODER.encode(str);
    }
  }

  private static decodeBytes(bytes: Uint8Array, encoding: string): string {
    const enc = encoding.toLowerCase();
    switch (enc) {
      case 'utf8':
      case 'utf-8':
        return TEXT_DECODER.decode(bytes);
      case 'ascii':
        return Buffer.decodeAscii(bytes);
      case 'latin1':
      case 'binary':
        return Buffer.decodeLatin1(bytes);
      case 'base64':
        return Buffer.encodeBase64(bytes);
      case 'base64url':
        return Buffer.encodeBase64(bytes).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
      case 'hex':
        return Buffer.encodeHex(bytes);
      case 'ucs2':
      case 'ucs-2':
      case 'utf16le':
      case 'utf-16le':
        return Buffer.decodeUtf16le(bytes);
      default:
        return TEXT_DECODER.decode(bytes);
    }
  }

  private static encodeAscii(str: string): Uint8Array {
    const buf = new Uint8Array(str.length);
    for (let i = 0; i < str.length; i++) buf[i] = str.charCodeAt(i) & 0x7f;
    return buf;
  }

  private static decodeAscii(bytes: Uint8Array): string {
    let s = '';
    for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i] & 0x7f);
    return s;
  }

  private static encodeLatin1(str: string): Uint8Array {
    const buf = new Uint8Array(str.length);
    for (let i = 0; i < str.length; i++) buf[i] = str.charCodeAt(i) & 0xff;
    return buf;
  }

  private static decodeLatin1(bytes: Uint8Array): string {
    let s = '';
    for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
    return s;
  }

  private static encodeHex(bytes: Uint8Array): string {
    let s = '';
    for (let i = 0; i < bytes.length; i++) {
      s += HEX_CHARS[(bytes[i] >> 4) & 0xf];
      s += HEX_CHARS[bytes[i] & 0xf];
    }
    return s;
  }

  private static decodeHex(str: string): Uint8Array {
    const clean = str.length % 2 === 0 ? str : '0' + str;
    const buf = new Uint8Array(clean.length / 2);
    for (let i = 0; i < buf.length; i++) {
      const hi = clean.charCodeAt(i * 2);
      const lo = clean.charCodeAt(i * 2 + 1);
      buf[i] = (Buffer.hexVal(hi) << 4) | Buffer.hexVal(lo);
    }
    return buf;
  }

  private static hexVal(c: number): number {
    if (c >= 48 && c <= 57) return c - 48;
    if (c >= 97 && c <= 102) return c - 87;
    if (c >= 65 && c <= 70) return c - 55;
    return 0;
  }

  private static encodeBase64(bytes: Uint8Array): string {
    let result = '';
    let i = 0;
    for (; i + 2 < bytes.length; i += 3) {
      const triplet = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
      result += BASE64_CHARS[(triplet >> 18) & 0x3f];
      result += BASE64_CHARS[(triplet >> 12) & 0x3f];
      result += BASE64_CHARS[(triplet >> 6) & 0x3f];
      result += BASE64_CHARS[triplet & 0x3f];
    }
    const remaining = bytes.length - i;
    if (remaining === 1) {
      const triplet = bytes[i] << 16;
      result += BASE64_CHARS[(triplet >> 18) & 0x3f];
      result += BASE64_CHARS[(triplet >> 12) & 0x3f];
      result += '==';
    } else if (remaining === 2) {
      const triplet = (bytes[i] << 16) | (bytes[i + 1] << 8);
      result += BASE64_CHARS[(triplet >> 18) & 0x3f];
      result += BASE64_CHARS[(triplet >> 12) & 0x3f];
      result += BASE64_CHARS[(triplet >> 6) & 0x3f];
      result += '=';
    }
    return result;
  }

  private static decodeBase64(str: string): Uint8Array {
    const clean = str.replace(/[^A-Za-z0-9+/]/g, '');
    const len = Math.floor(clean.length * 3 / 4);
    const buf = new Uint8Array(len);
    let pos = 0;
    for (let i = 0; i < clean.length; i += 4) {
      const a = BASE64_LOOKUP[clean.charCodeAt(i)] ?? 0;
      const b = BASE64_LOOKUP[clean.charCodeAt(i + 1)] ?? 0;
      const c = BASE64_LOOKUP[clean.charCodeAt(i + 2)] ?? 0;
      const d = BASE64_LOOKUP[clean.charCodeAt(i + 3)] ?? 0;
      const triplet = (a << 18) | (b << 12) | (c << 6) | d;
      if (pos < len) buf[pos++] = (triplet >> 16) & 0xff;
      if (pos < len) buf[pos++] = (triplet >> 8) & 0xff;
      if (pos < len) buf[pos++] = triplet & 0xff;
    }
    return buf.subarray(0, pos);
  }

  private static encodeUtf16le(str: string): Uint8Array {
    const buf = new Uint8Array(str.length * 2);
    for (let i = 0; i < str.length; i++) {
      const code = str.charCodeAt(i);
      buf[i * 2] = code & 0xff;
      buf[i * 2 + 1] = (code >> 8) & 0xff;
    }
    return buf;
  }

  private static decodeUtf16le(bytes: Uint8Array): string {
    let s = '';
    for (let i = 0; i + 1 < bytes.length; i += 2) {
      s += String.fromCharCode(bytes[i] | (bytes[i + 1] << 8));
    }
    return s;
  }
}

export default Buffer;
