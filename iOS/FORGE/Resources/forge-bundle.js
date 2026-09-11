(() => {
  var __create = Object.create;
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __getProtoOf = Object.getPrototypeOf;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __require = /* @__PURE__ */ ((x) => typeof require !== "undefined" ? require : typeof Proxy !== "undefined" ? new Proxy(x, {
    get: (a, b) => (typeof require !== "undefined" ? require : a)[b]
  }) : x)(function(x) {
    if (typeof require !== "undefined") return require.apply(this, arguments);
    throw Error('Dynamic require of "' + x + '" is not supported');
  });
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
    // If the importer is in node compatibility mode or this is not an ESM
    // file that has been converted to a CommonJS file using a Babel-
    // compatible transform (i.e. "__esModule" has not been set), then set
    // "default" to the CommonJS "module.exports" for node compatibility.
    isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
    mod
  ));

  // forge/shims/forge-buffer.ts
  var TEXT_ENCODER = new TextEncoder();
  var TEXT_DECODER = new TextDecoder();
  var BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  var BASE64_LOOKUP = new Uint8Array(256);
  for (let i = 0; i < 256; i++) BASE64_LOOKUP[i] = 255;
  for (let i = 0; i < BASE64_CHARS.length; i++) BASE64_LOOKUP[BASE64_CHARS.charCodeAt(i)] = i;

  // forge/shims/forge-globals.js
  var processShim = {
    env: {
      NODE_ENV: "production",
      FORGE: "1",
      FORGE_PLATFORM: "ios",
      HOME: "/tmp/home",
      TMPDIR: "/tmp",
      PATH: "/usr/local/bin:/usr/bin:/bin",
      SHELL: "/bin/forge",
      LANG: "en_US.UTF-8",
      TERM: "xterm-256color",
      FORCE_COLOR: "1",
      ...typeof globalThis !== "undefined" && globalThis.__forgeEnv || {}
    },
    platform: "darwin",
    arch: "arm64",
    type: "Darwin",
    release: "23.0.0",
    version: "v20.0.0",
    versions: { node: "20.0.0", v8: "11.0.0", uv: "1.44.0", openssl: "3.0.0" },
    pid: 1,
    ppid: 0,
    title: "forge",
    argv: ["forge"],
    execArgv: [],
    execPath: "/usr/local/bin/forge",
    cwd() {
      const native = typeof globalThis !== "undefined" && globalThis.window?.__forgeNative;
      return native?.cwd ?? "/tmp";
    },
    chdir(dir) {
      const native = typeof globalThis !== "undefined" && globalThis.window?.__forgeNative;
      if (native?.call) native.call("chdir", dir).then(void 0, function() {
      });
    },
    stdout: {
      write(data) {
        const native = typeof globalThis !== "undefined" && globalThis.window?.__forgeNative;
        if (native?.output) {
          const str = typeof data === "string" ? data : new TextDecoder().decode(data);
          native.output(str);
        }
        return true;
      },
      end() {
      },
      on() {
        return this;
      },
      once() {
        return this;
      },
      emit() {
        return false;
      },
      isTTY: true,
      columns: 80,
      rows: 24,
      getColorDepth() {
        return 256;
      },
      hasColors() {
        return true;
      }
    },
    stderr: {
      write(data) {
        const native = typeof globalThis !== "undefined" && globalThis.window?.__forgeNative;
        if (native?.error) {
          const str = typeof data === "string" ? data : new TextDecoder().decode(data);
          native.error(str);
        }
        return true;
      },
      end() {
      },
      on() {
        return this;
      },
      once() {
        return this;
      },
      emit() {
        return false;
      },
      isTTY: true,
      columns: 80,
      rows: 24,
      getColorDepth() {
        return 256;
      },
      hasColors() {
        return true;
      }
    },
    stdin: {
      isTTY: true,
      readable: true,
      on() {
        return this;
      },
      once() {
        return this;
      },
      emit() {
        return false;
      },
      resume() {
        return this;
      },
      pause() {
        return this;
      },
      read() {
        return null;
      },
      setEncoding() {
        return this;
      }
    },
    exit(code) {
      const native = typeof globalThis !== "undefined" && globalThis.window?.__forgeNative;
      if (native?.exit) native.exit(code ?? 0);
      throw new Error("[FORGE] process.exit(" + (code ?? 0) + ") called");
    },
    _events: {},
    on(event, listener) {
      if (event === "uncaughtException" || event === "unhandledRejection") {
        if (typeof globalThis !== "undefined") {
          globalThis.addEventListener?.("error", function(e) {
            listener(e.error || new Error(e.message));
          });
          globalThis.addEventListener?.("unhandledrejection", function(e) {
            listener(e.reason || new Error("Unhandled promise rejection"));
          });
        }
      }
      return this;
    },
    once(event, listener) {
      return this.on(event, function() {
        listener.apply(null, arguments);
      });
    },
    off() {
      return this;
    },
    removeListener() {
      return this;
    },
    removeAllListeners() {
      return this;
    },
    emit() {
      return false;
    },
    addListener() {
      return this;
    },
    listeners() {
      return [];
    },
    listenerCount() {
      return 0;
    },
    nextTick(callback) {
      const args = Array.prototype.slice.call(arguments, 1);
      Promise.resolve().then(function() {
        callback.apply(null, args);
      });
    },
    hrtime: {
      bigint() {
        const ms = typeof performance !== "undefined" ? performance.now() : Date.now();
        return BigInt(Math.floor(ms * 1e6));
      }
    },
    hrtimeBigint() {
      return this.hrtime.bigint();
    },
    memoryUsage() {
      const native = typeof globalThis !== "undefined" && globalThis.window?.__forgeNative;
      const mem = native?.getMemoryUsage?.() ?? {};
      return {
        rss: mem.rss ?? 100 * 1024 * 1024,
        heapTotal: mem.heapTotal ?? 50 * 1024 * 1024,
        heapUsed: mem.heapUsed ?? 25 * 1024 * 1024,
        external: mem.external ?? 10 * 1024 * 1024,
        arrayBuffers: mem.arrayBuffers ?? 1024 * 1024
      };
    },
    cpuUsage() {
      return { user: 0, system: 0 };
    },
    resourceUsage() {
      return {};
    },
    uptime() {
      const native = typeof globalThis !== "undefined" && globalThis.window?.__forgeNative;
      return native?.uptime ?? Math.floor((typeof performance !== "undefined" ? performance.now() : Date.now()) / 1e3);
    },
    features: {},
    moduleLoadList: [],
    allowedNodeEnvironmentFlags: /* @__PURE__ */ new Set(),
    _debugProcess() {
    },
    _debugEnd() {
    },
    assert(condition, message) {
      if (!condition) throw new Error("Assertion failed: " + (message ?? ""));
    },
    report: {
      getReport() {
        return { header: { event: "FORGE", platform: "ios", arch: "arm64" } };
      },
      writeReport() {
      }
    },
    binding() {
      return {};
    },
    dlopen() {
      throw new Error("[FORGE] process.dlopen() not supported on iOS");
    },
    umask() {
      return 18;
    },
    getuid() {
      return 501;
    },
    getgid() {
      return 20;
    },
    geteuid() {
      return 501;
    },
    getegid() {
      return 20;
    },
    setuid() {
    },
    setgid() {
    },
    seteuid() {
    },
    setegid() {
    },
    setgroups() {
    },
    initgroups() {
    },
    kill() {
      return true;
    },
    abort() {
      throw new Error("[FORGE] process.abort() called");
    },
    channel: null,
    connected: false,
    disconnect() {
    },
    send() {
      return false;
    },
    ref() {
    },
    unref() {
    },
    mainModule: void 0
  };

  // forge/src/forge-identity.ts
  var FORGE_IDENTITY = `You are Trident Agent \u2014 a T3 Algorithmic Audit Engine running on iPhone via FORGE.

## ENVIRONMENT
- PLATFORM: iPhone (iOS, ARM64, Safari WebKit JavaScript engine)
- FILE SYSTEM: iOS sandbox container. All paths resolve within the app's Documents directory. No access to system paths outside sandbox.
- NO CHILD PROCESSES: exec/execSync/fork/spawn are NOT available. All native operations go through the FORGE native bridge (window.__forgeNative.call()).
- NO NODE.JS RUNTIME: Node.js built-in modules are polyfilled via lightweight shims. fs/process/crypto/os are bridge-backed.
- MEMORY: Shared with the host app. Large allocations may be reclaimed by iOS under memory pressure.

## CAPABILITIES
- Full 18-layer audit engine (R0-R16) active.
- God Loop with PASS/LOOP quality enforcement.
- Effect runtime for async operations.
- SQLite via sql.js (WASM, in-memory).
- HTTP via fetch() API.
- Terminal surface captured to native buffer for TUI rendering.

## OPERATING CONSTRAINTS
- Battery-aware: avoid unnecessary background work. Batch operations. Prefer single-pass algorithms.
- Thermal-aware: CPU-intensive loops should include cooperative yield points.
- Concise output: screen real estate is limited. Prefer dense, information-rich responses over verbose explanations.
- Offline-first: network may be intermittent. Cache aggressively. Fail gracefully.
- No persistence beyond app lifecycle: sandbox may be cleared on uninstall. Use SQLite for durable storage within session.

## OUTPUT FORMAT
- Concise. Dense. No filler.
- Code blocks for all code.
- Tables for structured comparisons.
- Never exceed viewport height without reason.

You are Trident. You audit. You execute. You ship. On iPhone.`;
  var FORGE_IDENTITY_SHORT = `[FORGE/iOS] Trident Agent running on iPhone (ARM64, WebKit). Sandbox FS. No child processes. Full 18-layer audit. God Loop PASS/LOOP. Battery-aware. Concise output.`;

  // forge/shims/forge-events.ts
  var kMaxListeners = 10;
  var kCaptureRejectionSymbol = Symbol("kCapture");
  var EventEmitter = class {
    _events = /* @__PURE__ */ new Map();
    _maxListeners = kMaxListeners;
    [kCaptureRejectionSymbol] = false;
    static defaultMaxListeners = kMaxListeners;
    static captureRejectionSymbol = Symbol.for("nodejs.rejection");
    static errorMonitor = Symbol("events.errorMonitor");
    static once(emitter, name, options) {
      return new Promise((resolve, reject) => {
        if (options?.signal instanceof EventTarget) {
          if (options.signal.aborted) {
            reject(new Error("The operation was aborted"));
            return;
          }
          options.signal.addEventListener("abort", () => {
            emitter.removeListener(name, onceListener);
            reject(new Error("The operation was aborted"));
          });
        }
        const onceListener = (...args) => {
          emitter.removeListener(name, onceListener);
          resolve(args);
        };
        emitter.once(name, onceListener);
      });
    }
    static on(emitter, name, options) {
      const queue = [];
      let resolveNext = null;
      let done = false;
      const listener = (...args) => {
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
        options.signal.addEventListener("abort", cleanup);
      }
      return {
        [Symbol.asyncIterator]() {
          return this;
        },
        async next() {
          if (queue.length > 0) {
            return { value: queue.shift(), done: false };
          }
          if (done) {
            return { value: void 0, done: true };
          }
          return new Promise((resolve) => {
            resolveNext = resolve;
          });
        },
        async return() {
          cleanup();
          return { value: void 0, done: true };
        },
        async throw(error) {
          cleanup();
          throw error;
        }
      };
    }
    static listenerCount(emitter, name) {
      return emitter.listenerCount(name);
    }
    addListener(eventName, listener) {
      if (typeof listener !== "function") {
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
    on(eventName, listener) {
      return this.addListener(eventName, listener);
    }
    once(eventName, listener) {
      if (typeof listener !== "function") {
        throw new TypeError('The "listener" argument must be of type Function');
      }
      const wrapper = {
        listener: (...args) => {
          this.removeListener(eventName, wrapper.rawListener);
          listener(...args);
        },
        rawListener: null
      };
      wrapper.rawListener = wrapper.listener;
      wrapper.rawListener.__once = true;
      wrapper.rawListener.__original = listener;
      const existing = this._events.get(eventName);
      if (existing) {
        existing.push(wrapper.rawListener);
      } else {
        this._events.set(eventName, [wrapper.rawListener]);
      }
      this._warnIfNeeded(eventName);
      return this;
    }
    prependListener(eventName, listener) {
      if (typeof listener !== "function") {
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
    prependOnceListener(eventName, listener) {
      if (typeof listener !== "function") {
        throw new TypeError('The "listener" argument must be of type Function');
      }
      const wrapper = {
        listener: (...args) => {
          this.removeListener(eventName, wrapper.rawListener);
          listener(...args);
        },
        rawListener: null
      };
      wrapper.rawListener = wrapper.listener;
      wrapper.rawListener.__once = true;
      const existing = this._events.get(eventName);
      if (existing) {
        existing.unshift(wrapper.rawListener);
      } else {
        this._events.set(eventName, [wrapper.rawListener]);
      }
      this._warnIfNeeded(eventName);
      return this;
    }
    removeListener(eventName, listener) {
      if (typeof listener !== "function") {
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
    off(eventName, listener) {
      return this.removeListener(eventName, listener);
    }
    removeAllListeners(eventName) {
      if (eventName === void 0) {
        this._events.clear();
      } else {
        this._events.delete(eventName);
      }
      return this;
    }
    setMaxListeners(n) {
      if (typeof n !== "number" || n < 0 || Number.isNaN(n)) {
        throw new RangeError('The value of "n" is out of range');
      }
      this._maxListeners = n;
      return this;
    }
    getMaxListeners() {
      return this._maxListeners;
    }
    listeners(eventName) {
      const existing = this._events.get(eventName);
      if (!existing) return [];
      return [...existing];
    }
    rawListeners(eventName) {
      return this.listeners(eventName);
    }
    listenerCount(eventName) {
      const existing = this._events.get(eventName);
      return existing ? existing.length : 0;
    }
    eventNames() {
      return [...this._events.keys()];
    }
    emit(eventName, ...args) {
      const existing = this._events.get(eventName);
      if (!existing || existing.length === 0) return false;
      const listeners = [...existing];
      for (const listener of listeners) {
        try {
          listener(...args);
        } catch (err) {
          if (eventName !== "error" && this.listenerCount("error") > 0) {
            this.emit("error", err);
          } else if (eventName === "error") {
            throw err;
          }
        }
      }
      return true;
    }
    _warnIfNeeded(eventName) {
      const count = this.listenerCount(eventName);
      if (this._maxListeners !== 0 && count > this._maxListeners) {
        const warnStr = `Possible EventEmitter memory leak detected. ${count} ${String(eventName)} listeners added. Use emitter.setMaxListeners() to increase limit`;
        console.warn(warnStr);
      }
    }
  };

  // forge/src/forge-terminal-surface.ts
  var ForgeTerminalSurface = class extends EventEmitter {
    _output = [];
    _buffer = "";
    _size;
    _cursor = { x: 0, y: 0 };
    _flushTimer = null;
    _flushInterval = 16;
    // ~60fps
    _cellGrid = [];
    _pendingFlush = false;
    constructor(cols = 80, rows = 24) {
      super();
      this._size = { cols, rows };
      this._initCellGrid();
    }
    _initCellGrid() {
      this._cellGrid = [];
      for (let y = 0; y < this._size.rows; y++) {
        const row = [];
        for (let x = 0; x < this._size.cols; x++) {
          row.push({
            char: " ",
            fg: null,
            bg: null,
            bold: false,
            italic: false,
            underline: false,
            dim: false,
            inverse: false
          });
        }
        this._cellGrid.push(row);
      }
    }
    // --- Core write method ---
    write(data, options) {
      const str = typeof data === "string" ? data : new TextDecoder().decode(data);
      this._buffer += str;
      this._processAnsi(str);
      if (options?.flush) {
        this._flush();
      } else {
        this._scheduleFlush();
      }
      return true;
    }
    // --- Flush output to native ---
    _scheduleFlush() {
      if (this._flushTimer || this._pendingFlush) return;
      this._pendingFlush = true;
      this._flushTimer = setTimeout(() => {
        this._flush();
      }, this._flushInterval);
    }
    _flush() {
      if (this._flushTimer) {
        clearTimeout(this._flushTimer);
        this._flushTimer = null;
      }
      this._pendingFlush = false;
      if (this._buffer.length === 0) return;
      const native = globalThis.window?.__forgeNative;
      if (native?.output) {
        native.output(this._buffer);
      }
      if (native?.renderFrame) {
        native.renderFrame(this.getCellSnapshot());
      }
      this._buffer = "";
    }
    // --- ANSI escape processing ---
    _processAnsi(str) {
      let i = 0;
      while (i < str.length) {
        const char = str[i];
        if (char === "\x1B") {
          const next = str[i + 1];
          if (next === "[") {
            const match = str.slice(i).match(/^\x1b\[([\d;]*)([a-zA-Z])/);
            if (match) {
              this._handleCsi(match[1], match[2]);
              i += match[0].length;
              continue;
            }
          } else if (next === "]") {
            const oscEnd = str.indexOf("\x07", i);
            const belEnd = str.indexOf("\x1B\\", i);
            const end = oscEnd !== -1 && (belEnd === -1 || oscEnd < belEnd) ? oscEnd + 1 : belEnd + 2;
            i = end > i ? end : i + 2;
            continue;
          }
          i += 2;
          continue;
        }
        if (char === "\n") {
          this._cursor.y++;
          this._cursor.x = 0;
          if (this._cursor.y >= this._size.rows) {
            this._scrollUp();
            this._cursor.y = this._size.rows - 1;
          }
        } else if (char === "\r") {
          this._cursor.x = 0;
        } else if (char === "	") {
          this._cursor.x = Math.min(this._cursor.x + 4, this._size.cols - 1);
        } else if (char >= " " && char !== "\x7F") {
          if (this._cursor.y < this._size.rows && this._cursor.x < this._size.cols) {
            const cell = this._cellGrid[this._cursor.y]?.[this._cursor.x];
            if (cell) {
              cell.char = char;
            }
          }
          this._cursor.x++;
          if (this._cursor.x >= this._size.cols) {
            this._cursor.x = 0;
            this._cursor.y++;
            if (this._cursor.y >= this._size.rows) {
              this._scrollUp();
              this._cursor.y = this._size.rows - 1;
            }
          }
        }
        i++;
      }
    }
    _handleCsi(params, command) {
      const nums = params ? params.split(";").map((n) => parseInt(n, 10) || 0) : [];
      switch (command) {
        case "H":
        // Cursor position
        case "f":
          this._cursor.y = (nums[0] || 1) - 1;
          this._cursor.x = (nums[1] || 1) - 1;
          break;
        case "A":
          this._cursor.y = Math.max(0, this._cursor.y - (nums[0] || 1));
          break;
        case "B":
          this._cursor.y = Math.min(this._size.rows - 1, this._cursor.y + (nums[0] || 1));
          break;
        case "C":
          this._cursor.x = Math.min(this._size.cols - 1, this._cursor.x + (nums[0] || 1));
          break;
        case "D":
          this._cursor.x = Math.max(0, this._cursor.x - (nums[0] || 1));
          break;
        case "J":
          this._eraseDisplay(nums[0] || 0);
          break;
        case "K":
          this._eraseLine(nums[0] || 0);
          break;
        case "m":
          this._handleSgr(nums);
          break;
        default:
          break;
      }
    }
    _currentAttrs = {
      char: " ",
      fg: null,
      bg: null,
      bold: false,
      italic: false,
      underline: false,
      dim: false,
      inverse: false
    };
    _handleSgr(nums) {
      for (let i = 0; i < nums.length; i++) {
        const n = nums[i];
        if (n === 0) {
          this._currentAttrs = { char: " ", fg: null, bg: null, bold: false, italic: false, underline: false, dim: false, inverse: false };
        } else if (n === 1) {
          this._currentAttrs.bold = true;
        } else if (n === 2) {
          this._currentAttrs.dim = true;
        } else if (n === 3) {
          this._currentAttrs.italic = true;
        } else if (n === 4) {
          this._currentAttrs.underline = true;
        } else if (n === 7) {
          this._currentAttrs.inverse = true;
        } else if (n === 22) {
          this._currentAttrs.bold = false;
          this._currentAttrs.dim = false;
        } else if (n === 23) {
          this._currentAttrs.italic = false;
        } else if (n === 24) {
          this._currentAttrs.underline = false;
        } else if (n === 27) {
          this._currentAttrs.inverse = false;
        } else if (n >= 30 && n <= 37) {
          this._currentAttrs.fg = ANSI_COLOR_MAP[n - 30];
        } else if (n >= 40 && n <= 47) {
          this._currentAttrs.bg = ANSI_COLOR_MAP[n - 40];
        } else if (n >= 90 && n <= 97) {
          this._currentAttrs.fg = ANSI_COLOR_MAP[n - 90 + 8];
        } else if (n >= 100 && n <= 107) {
          this._currentAttrs.bg = ANSI_COLOR_MAP[n - 100 + 8];
        }
      }
    }
    _eraseDisplay(mode) {
      if (mode === 2 || mode === 3) {
        this._initCellGrid();
        this._cursor = { x: 0, y: 0 };
      } else if (mode === 1) {
        for (let y = 0; y <= this._cursor.y; y++) {
          const maxX = y === this._cursor.y ? this._cursor.x : this._size.cols;
          for (let x = 0; x < maxX; x++) {
            const cell = this._cellGrid[y]?.[x];
            if (cell) {
              cell.char = " ";
              cell.fg = null;
              cell.bg = null;
            }
          }
        }
      } else {
        for (let y = this._cursor.y; y < this._size.rows; y++) {
          const startX = y === this._cursor.y ? this._cursor.x : 0;
          for (let x = startX; x < this._size.cols; x++) {
            const cell = this._cellGrid[y]?.[x];
            if (cell) {
              cell.char = " ";
              cell.fg = null;
              cell.bg = null;
            }
          }
        }
      }
    }
    _eraseLine(mode) {
      const row = this._cellGrid[this._cursor.y];
      if (!row) return;
      if (mode === 2) {
        for (const cell of row) {
          cell.char = " ";
          cell.fg = null;
          cell.bg = null;
        }
      } else if (mode === 1) {
        for (let x = 0; x <= this._cursor.x && x < row.length; x++) {
          row[x].char = " ";
          row[x].fg = null;
          row[x].bg = null;
        }
      } else {
        for (let x = this._cursor.x; x < row.length; x++) {
          row[x].char = " ";
          row[x].fg = null;
          row[x].bg = null;
        }
      }
    }
    _scrollUp() {
      this._cellGrid.shift();
      const newRow = [];
      for (let x = 0; x < this._size.cols; x++) {
        newRow.push({
          char: " ",
          fg: null,
          bg: null,
          bold: false,
          italic: false,
          underline: false,
          dim: false,
          inverse: false
        });
      }
      this._cellGrid.push(newRow);
    }
    // --- Public API ---
    getCellSnapshot() {
      return this._cellGrid.map((row) => row.map((cell) => ({ ...cell })));
    }
    getSize() {
      return { ...this._size };
    }
    getCols() {
      return this._size.cols;
    }
    getRows() {
      return this._size.rows;
    }
    resize(cols, rows) {
      const oldGrid = this._cellGrid;
      this._size = { cols, rows };
      this._initCellGrid();
      for (let y = 0; y < Math.min(oldGrid.length, rows); y++) {
        for (let x = 0; x < Math.min(oldGrid[y]?.length ?? 0, cols); x++) {
          const oldCell = oldGrid[y]?.[x];
          const newCell = this._cellGrid[y]?.[x];
          if (oldCell && newCell) {
            Object.assign(newCell, oldCell);
          }
        }
      }
      this.emit("resize", this._size);
      this._flush();
    }
    onResize(callback) {
      this.on("resize", callback);
    }
    clear() {
      this._initCellGrid();
      this._cursor = { x: 0, y: 0 };
      this._buffer = "";
      this._flush();
      this.emit("clear");
    }
    flush() {
      this._flush();
    }
    // --- Cursor position ---
    getCursorPosition() {
      return { ...this._cursor };
    }
    setCursorPosition(x, y) {
      this._cursor.x = Math.max(0, Math.min(x, this._size.cols - 1));
      this._cursor.y = Math.max(0, Math.min(y, this._size.rows - 1));
    }
    // --- Input handling ---
    sendInput(input) {
      this.emit("input", input);
    }
    // --- Cleanup ---
    destroy() {
      if (this._flushTimer) {
        clearTimeout(this._flushTimer);
        this._flushTimer = null;
      }
      this._buffer = "";
      this._cellGrid = [];
      this.removeAllListeners();
    }
  };
  var ANSI_COLOR_MAP = [
    "#000000",
    "#cc0000",
    "#4e9a06",
    "#c4a000",
    "#3465a4",
    "#75507b",
    "#06989a",
    "#d3d7cf",
    "#555753",
    "#ef2929",
    "#8ae234",
    "#fce94f",
    "#729fcf",
    "#ad7fa8",
    "#34e2e2",
    "#eeeeec"
  ];
  function createForgeTerminalSurface(cols, rows) {
    const native = globalThis.window?.__forgeNative;
    const size = native?.getTerminalSize?.() ?? { cols: cols ?? 80, rows: rows ?? 24 };
    return new ForgeTerminalSurface(size.cols, size.rows);
  }

  // forge/src/forge-runtime.ts
  var LayerRegistry = class {
    layers = /* @__PURE__ */ new Map();
    add(layer) {
      this.layers.set(layer.key, layer.build());
    }
    get(key) {
      return this.layers.get(key);
    }
    has(key) {
      return this.layers.has(key);
    }
    build() {
      return Object.fromEntries(this.layers);
    }
  };
  function initializeForgeRuntime(config, tridentPlugin, nativeBridge) {
    const terminalSurface = new ForgeTerminalSurface(
      nativeBridge.getTerminalSize?.().cols ?? 80,
      nativeBridge.getTerminalSize?.().rows ?? 24
    );
    const layerRegistry = new LayerRegistry();
    const startTime = Date.now();
    let running = false;
    let iterations = 0;
    let lastInput = null;
    let lastOutput = null;
    const sessionStore = /* @__PURE__ */ new Map();
    const pluginRegistry = /* @__PURE__ */ new Map();
    const agentRegistry = /* @__PURE__ */ new Map();
    const providerRegistry = /* @__PURE__ */ new Map();
    let initialized = false;
    layerRegistry.add({
      key: Symbol("terminal"),
      build: () => terminalSurface
    });
    layerRegistry.add({
      key: Symbol("native"),
      build: () => nativeBridge
    });
    layerRegistry.add({
      key: Symbol("config"),
      build: () => config
    });
    const inputHandler = async (input) => {
      if (running) {
        terminalSurface.write("[BUSY] Previous request still processing...\n");
        return "[BUSY]";
      }
      running = true;
      iterations++;
      lastInput = input;
      try {
        const result = await processWithAgent(input);
        lastOutput = result;
        running = false;
        return result;
      } catch (err) {
        const errorMsg = err?.message ?? String(err);
        terminalSurface.write("[ERROR] " + errorMsg + "\n");
        lastOutput = "[ERROR] " + errorMsg;
        running = false;
        throw err;
      }
    };
    const globalAny2 = globalThis;
    if (globalAny2.window) {
      globalAny2.window.__forgeOnInput = inputHandler;
    }
    async function processWithAgent(input) {
      if (tridentPlugin?.process) {
        const context = {
          input,
          config,
          terminal: terminalSurface,
          native: nativeBridge,
          identity: FORGE_IDENTITY,
          sessionStore,
          pluginRegistry,
          agentRegistry,
          providerRegistry
        };
        const result = await tridentPlugin.process(input, context);
        return typeof result === "string" ? result : JSON.stringify(result);
      }
      if (tridentPlugin?.defaultAgent?.process) {
        const context = {
          input,
          config,
          terminal: terminalSurface,
          native: nativeBridge
        };
        const result = await tridentPlugin.defaultAgent.process(input, context);
        return typeof result === "string" ? result : JSON.stringify(result);
      }
      const fallback = "[FORGE] No agent processor available. Input: " + input;
      terminalSurface.write(fallback + "\n");
      return fallback;
    }
    if (tridentPlugin) {
      const pluginId = tridentPlugin.id ?? "trident";
      pluginRegistry.set(pluginId, tridentPlugin);
      if (tridentPlugin.agents) {
        for (const [name, agent] of Object.entries(tridentPlugin.agents)) {
          agentRegistry.set(name, agent);
        }
      }
      if (tridentPlugin.providers) {
        for (const [name, provider] of Object.entries(tridentPlugin.providers)) {
          providerRegistry.set(name, provider);
        }
      }
    }
    if (config.providers) {
      for (const provider of config.providers) {
        providerRegistry.set(provider.id, provider);
      }
    }
    const sessionId = "forge-" + Date.now();
    sessionStore.set("current", {
      id: sessionId,
      startTime,
      identity: FORGE_IDENTITY,
      config
    });
    initialized = true;
    return {
      processInput: inputHandler,
      getTUIComponent() {
        return {
          surface: terminalSurface,
          render() {
            const grid = terminalSurface.getCellSnapshot();
            let output = "";
            for (const row of grid) {
              for (const cell of row) {
                output += cell.char;
              }
              output += "\n";
            }
            return output;
          },
          getElement() {
            return null;
          }
        };
      },
      destroy() {
        terminalSurface.destroy();
        sessionStore.clear();
        pluginRegistry.clear();
        agentRegistry.clear();
        providerRegistry.clear();
        initialized = false;
        const globalAny3 = globalThis;
        if (globalAny3.window?.__forgeOnInput) {
          delete globalAny3.window.__forgeOnInput;
        }
      },
      getStatus() {
        return {
          initialized,
          running,
          iterations,
          lastInput,
          lastOutput,
          uptime: Math.floor((Date.now() - startTime) / 1e3),
          memoryUsage: nativeBridge.getMemoryUsage?.() ?? {
            rss: 0,
            heapTotal: 0,
            heapUsed: 0
          }
        };
      }
    };
  }

  // forge/src/forge-entry.ts
  var DEFAULT_CONFIG = {
    disableVanillaAgents: true,
    defaultAgent: "trident",
    maxIterations: 50,
    batteryAware: true,
    offlineMode: false,
    cacheEnabled: true,
    identity: FORGE_IDENTITY,
    providers: [],
    plugins: ["trident"]
  };
  var FORGE_VENDOR_MODULES = {
    tridentPlugin: {
      importPath: "./vendor/trident-plugin.js",
      repoPath: "forge/src/vendor/trident-plugin.js",
      role: "Trident agent plugin (process / agents / providers)"
    },
    opencodeConfig: {
      importPath: "./vendor/opencode-config.js",
      repoPath: "forge/src/vendor/opencode-config.js",
      role: "opencode Config.load()"
    },
    opencodeSession: {
      importPath: "./vendor/opencode-session.js",
      repoPath: "forge/src/vendor/opencode-session.js",
      role: "opencode Session.create()"
    },
    opencodeAgent: {
      importPath: "./vendor/opencode-agent.js",
      repoPath: "forge/src/vendor/opencode-agent.js",
      role: "opencode Agent.register()"
    },
    opencodePlugin: {
      importPath: "./vendor/opencode-plugin.js",
      repoPath: "forge/src/vendor/opencode-plugin.js",
      role: "opencode Plugin.load()"
    }
  };
  var FORGE_VENDOR_GAP_HINT = "agent runtime loaded (vendor modules pending \u2014 custom agent active). Vendor from Trident/opencode packages (OPENCODE_WORKSPACE is read-only reference). Required files: trident-plugin.js, opencode-config.js, opencode-session.js, opencode-agent.js, opencode-plugin.js. The custom FORGE agent is active and fully functional.";
  function formatMissingVendorError(repoPath, role, cause) {
    const causeText = cause instanceof Error ? cause.message : cause ? String(cause) : "module not found / import failed";
    return new Error(
      `[FORGE] Missing vendor module for ${role}.
  Expected: ${repoPath}
  Cause: ${causeText}
  Action: add the real JS implementation at that path (only *.d.ts stubs exist today).
  ${FORGE_VENDOR_GAP_HINT}`
    );
  }
  async function tryImportVendor(kind) {
    try {
      let mod = null;
      switch (kind) {
        case "tridentPlugin":
          mod = await import("./vendor/trident-plugin.js");
          break;
        case "opencodeConfig":
          mod = await import("./vendor/opencode-config.js");
          break;
        case "opencodeSession":
          mod = await import("./vendor/opencode-session.js");
          break;
        case "opencodeAgent":
          mod = await import("./vendor/opencode-agent.js");
          break;
        case "opencodePlugin":
          mod = await import("./vendor/opencode-plugin.js");
          break;
        default:
          return { mod: null, error: new Error("unknown vendor kind: " + String(kind)) };
      }
      if (mod == null) return { mod: null, error: new Error("import resolved to null") };
      return { mod, error: null };
    } catch (err) {
      return { mod: null, error: err };
    }
  }
  async function bootstrap(nativeBridge) {
    const native = resolveNativeBridge(nativeBridge);
    const terminalSurface = createForgeTerminalSurface();
    
    const config = await loadConfig(native);
    
    const loadResult = await loadTridentPlugin();
    const tridentPlugin = loadResult.plugin;
    if (loadResult.isStub) {
      
    } else {
      
    }
    if (tridentPlugin) {
      if (tridentPlugin.setIdentity) tridentPlugin.setIdentity(FORGE_IDENTITY);
      if (tridentPlugin.config) tridentPlugin.config.identity = FORGE_IDENTITY_SHORT;
    }
    const runtime = initializeForgeRuntime(config, tridentPlugin, native);
    
    const globalAny2 = globalThis;
    const phaseStatus = {
      phase: loadResult.isStub ? "phase1-stub" : "phase2-partial",
      tridentIsStub: loadResult.isStub,
      opencodeLoaded: [],
      opencodeMissing: [],
      vendorGapHint: FORGE_VENDOR_GAP_HINT
    };
    if (globalAny2.window) {
      globalAny2.window.__forge = {
        runtime,
        terminal: terminalSurface,
        config,
        identity: FORGE_IDENTITY,
        phaseStatus,
        isStub: loadResult.isStub
      };
      globalAny2.window.__forgeOutput = (text) => {
        native.output?.(text);
      };
    }
    const originalInputHandler = globalAny2.window?.__forgeOnInput;
    if (originalInputHandler) {
      globalAny2.window.__forgeOnInput = async (input) => {
        if (config.batteryAware) {
          try {
            const batteryLevel = await native.call?.("getBatteryLevel") ?? 1;
            if (batteryLevel < 0.05) {
              
            }
          } catch {
          }
        }
        return originalInputHandler(input);
      };
    }
    if (config.providers && config.providers.length > 0) {
      
    } else {
      
      config.offlineMode = true;
    }
    try {
      const ocResult = await initializeOpencodeCore(config, tridentPlugin);
      phaseStatus.opencodeLoaded = ocResult.loaded;
      phaseStatus.opencodeMissing = ocResult.missing.map((m) => m.repoPath);
      if (ocResult.isFull && !loadResult.isStub) {
        phaseStatus.phase = "phase2-full";
        
      } else if (ocResult.loaded.length > 0) {
        phaseStatus.phase = loadResult.isStub ? "phase1-stub" : "phase2-partial";
        terminalSurface.write("");
        
      } else {
        throw new Error(ocResult.message);
      }
    } catch (err) {
      const msg = err?.message ?? String(err);
      for (const line of String(msg).split("\n")) {
        
      }
      if (globalAny2.window?.__forge) {
        globalAny2.window.__forge.phaseStatus = phaseStatus;
        globalAny2.window.__forge.isStub = true;
      }
    }
    terminalSurface.flush();
    terminalSurface.flush();
    if (native.ready) native.ready();
      
    terminalSurface.flush();
  }
  var CY = "\x1B[38;5;208m", YL = "\x1B[33m", GN = "\x1B[32m", RD = "\x1B[31m", RS = "\x1B[0m", BD = "\x1B[1m", DM = "\x1B[2m";
  function resolveNativeBridge(bridge) {
    const globalAny2 = globalThis;
    const native = bridge ?? globalAny2.window?.__forgeNative;
    if (!native) {
      return {
        call: async () => {
          throw new Error("[FORGE] Native bridge not available");
        },
        output: (text) => {
          console.log(text);
        },
        error: (text) => {
          console.error(text);
        },
        ready: () => {
        },
        exit: (code) => {
          console.log("[FORGE] Exit: " + code);
        }
      };
    }
    return native;
  }
  async function loadConfig(native) {
    try {
      const configJson = await native.call("getResource", "forge-config.json");
      if (configJson) {
        const parsed = JSON.parse(configJson);
        return { ...DEFAULT_CONFIG, ...parsed };
      }
    } catch {
    }
    return DEFAULT_CONFIG;
  }
  async function loadTridentPlugin() {
    const slot = FORGE_VENDOR_MODULES.tridentPlugin;
    const { mod: tridentModule, error: importError } = await tryImportVendor("tridentPlugin");
    if (tridentModule) {
      const plugin = tridentModule.default ?? tridentModule;
      if (plugin && (typeof plugin.process === "function" || plugin.agents || plugin.id)) {
        return {
          plugin,
          isStub: false,
          message: "Loaded real Trident plugin from " + slot.repoPath
        };
      }
    }
    const globalAny2 = globalThis;
    if (globalAny2.TridentPlugin) {
      return {
        plugin: globalAny2.TridentPlugin,
        isStub: false,
        message: "Loaded TridentPlugin from globalThis.TridentPlugin"
      };
    }
    const missingErr = formatMissingVendorError(
      slot.repoPath,
      slot.role,
      importError ?? new Error("no global TridentPlugin and vendor .js absent")
    );
    const stub = createPhase1TridentStub(missingErr.message);
    return {
      plugin: stub,
      isStub: true,
      missingPath: slot.repoPath,
      message: missingErr.message
    };
  }
  function createPhase1TridentStub(loadErrorMessage) {
    const CY = "\x1B[38;5;208m", YL = "\x1B[33m", GN = "\x1B[32m", RD = "\x1B[31m", RS = "\x1B[0m", BD = "\x1B[1m", DM = "\x1B[2m";
    const cmdHistory = [];
    const NATIVE_COMMANDS = new Set([
      "ls", "cat", "grep", "find", "mkdir", "rm",
      "cp", "mv", "wc", "head", "tail", "pwd", "echo", "touch"
    ]);
    return {
      id: "trident-stub",
      isStub: true,
      identity: FORGE_IDENTITY,
      loadError: loadErrorMessage,
      async process(input, context) {
        const trimmed = (input || "").trim();
        if (trimmed) cmdHistory.push(trimmed);
        const cmd = trimmed.toLowerCase().split(/\s+/)[0];
        const term = context.terminal;
        const w = (s) => term?.write(s);
        // Slash commands route locally — never to the LLM (a mistyped
        // secret must not leave the device as model input). CONNECT_SPEC.md.
        if (trimmed.startsWith("/")) {
          const native = context.native ?? globalThis.window?.__forgeNative;
          return await handleSlashCommand(trimmed, { term, w, native });
        }
        if (NATIVE_COMMANDS.has(cmd)) {
          const parts = trimmed.split(/\s+/);
          const verb = parts[0];
          const args = parts.slice(1);
          const native = context.native ?? globalThis.window?.__forgeNative;
          if (!native?.call) {
            w(RD + "[forge] native bridge unavailable" + RS + "\n");
            return "error: no native bridge";
          }
          try {
            // Swift ForgeCommandRunner expects the FULL command string (it splits verb+args itself)
            w(CY + "│ " + RS + GN + "bash " + RS + CY + "\"" + RS + trimmed + CY + "\" │" + RS + "\n");
            const result = await native.call("runCommand", { command: trimmed });
            if (result?.stdout) w(result.stdout);
            if (result?.stderr) w(RD + result.stderr + RS);
            return "exit:" + (result?.exitCode ?? 0);
          } catch (err) {
            const msg = err?.message ?? String(err);
            w(RD + "[forge] command failed: " + msg + RS + "\n");
            return "error: " + msg;
          }
        }
        switch (cmd) {
          case "help":
            w(CY + BD + "FORGE Terminal Commands" + RS + "\n");
            w(DM + "\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500" + RS + "\n");
            w("  " + GN + "help" + RS + "     Show this help screen\n");
            w("  " + GN + "about" + RS + "    FORGE info and version\n");
            w("  " + GN + "status" + RS + "   Current configuration\n");
            w("  " + GN + "clear" + RS + "    Clear terminal\n");
            w("  " + GN + "ls" + RS + "       List files in sandbox\n");
            w("  " + GN + "cat" + RS + "      Read a file\n");
            w("  " + GN + "grep" + RS + "     Search file contents\n");
            w("  " + GN + "find" + RS + "     Find files\n");
            w("  " + GN + "mkdir" + RS + "    Create directory\n");
            w("  " + GN + "rm" + RS + "       Remove file/directory\n");
            w("  " + GN + "echo" + RS + "     Print text\n");
            w("  " + GN + "pwd" + RS + "      Show current directory\n");
            w("  " + GN + "touch" + RS + "    Create empty file\n");
            w("  " + GN + "wc" + RS + "       Count words/lines\n");
            w(DM + "All commands run through the native Swift bridge." + RS + "\n\n");
            return "help";
          case "about":
            w(CY + BD + "\n  \u2588\u2588\u2588\u2588\u2588\u2588 FORGE" + RS + "  v1.0.0\n");
            w(DM + "  Trident T3 Algorithmic Audit Engine" + RS + "\n");
            w("  " + YL + "Running on iPhone" + RS + "\n");
            w("  " + DM + "Mode: FORGE LLM Agent" + RS + "\n");
            w("  " + DM + "Agent: FORGE (LLM-backed, file+command tools)" + RS + "\n");
            w("  " + DM + "Architecture: opencode + Trident + SwiftTerm" + RS + "\n\n");
            return "about";
          case "status":
            w(CY + BD + "System Status" + RS + "\n");
            w(DM + "\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500" + RS + "\n");
            const cfg = globalThis.window?.__forgeConfig || {};
            w("  Provider:  " + GN + (cfg.provider || "unset") + RS + "\n");
            w("  Model:     " + GN + (cfg.model || "unset") + RS + "\n");
            w("  API Key:   " + (cfg.apiKey ? GN + "configured" + RS : RD + "MISSING" + RS) + "\n");
            w("  Agent:     " + YL + "FORGE LLM agent (tools: file+command)" + RS + "\n");
            w("  Uptime:    " + Math.floor(Date.now() / 1e3 % 1e6) + "s\n");
            w("  History:   " + cmdHistory.length + " commands\n\n");
            return "status";
          case "clear":
            w("\x1B[2J\x1B[H");
            return "clear";
          case "agent":
            w(CY + BD + "FORGE Agent" + RS + "\n");
            w(DM + "Any non-command input is sent to the LLM agent automatically." + RS + "\n");
            w(DM + "Describe a task (e.g. \"build an OSINT dashboard for Iran\") and FORGE will" + RS + "\n");
            w(DM + "create files and run commands in the sandbox." + RS + "\n\n");
            return "agent-help";
          case "":
            return "";
          default:
            // Not a local command → dispatch to the LLM agent
            return await runForgeAgent(trimmed, term, w);
        }
      },
      setIdentity(identity) { this.identity = identity; },
      getHistory() { return cmdHistory; },
      config: { identity: FORGE_IDENTITY_SHORT, stub: false, agent: "forge-llm" }
    };
  }
  var AGENT_SYSTEM_PROMPT = [
    "You are FORGE, an AI coding agent running on an iPhone inside a WKWebView.",
    "You have a file sandbox, a curated command runner, and on-device Python (Pyodide).",
    "LLM tokens come from on-device fetch/httpRequest. There is no host serve session.",
    "",
    "TOOLS:",
    "- read(path): read a file from the sandbox",
    "- write(path, content) [alias write_file]: create or overwrite a file",
    "- edit(path, old_string, new_string, replace_all?): replace the first exact match; fail if 0 or >1 match unless replace_all",
    "- bash(command) [alias run_command]: curated whitelist ls/cat/grep/find/mkdir/rm/cp/mv/wc/head/tail/pwd/echo/touch",
    "- grep(pattern, path?): search file contents (path optional, defaults to project root)",
    "- python(code) or python(path): run Python on-device via Pyodide; path reads the file then runs it",
    "- preview(path): open a built HTML page in the Preview tab so the user sees the render",
    "- Keep explanations to 1-2 SHORT sentences. Prefer tools over dumping code in chat.",
    "- Put new files in write/write_file. Patch existing files with edit. Inspect with read/grep.",
    "- NEVER quote or repeat tool results. They are already shown in the UI.",
    "- After each tool batch you will receive the results. Continue working until done.",
    "- When complete, summarize what you built in 2-3 lines.",
    "- If the task asks for a website/dashboard, build static HTML+CSS+JS (index.html, style.css, app.js), then call preview({path}) on the page so it renders.",
    "- If the task asks for Python, write a .py then python({path}) or python({code}).",
    "- Never claim files exist unless you created them with write/write_file or confirmed with read."
  ].join("\n");
  var AGENT_TOOLS = [
    { type: "function", function: { name: "read", description: "Read a file from the project sandbox",
      parameters: { type: "object", properties: { path: { type: "string", description: "relative file path" } }, required: ["path"] } } },
    { type: "function", function: { name: "write", description: "Write a file to the project (create or overwrite)",
      parameters: { type: "object", properties: { path: { type: "string", description: "relative file path" }, content: { type: "string", description: "full file content" } }, required: ["path", "content"] } } },
    { type: "function", function: { name: "write_file", description: "Alias of write — create or overwrite a file",
      parameters: { type: "object", properties: { path: { type: "string", description: "relative file path" }, content: { type: "string", description: "full file content" } }, required: ["path", "content"] } } },
    { type: "function", function: { name: "edit", description: "Replace exact text in a file. Fails if 0 or >1 match unless replace_all",
      parameters: { type: "object", properties: { path: { type: "string" }, old_string: { type: "string" }, new_string: { type: "string" }, replace_all: { type: "boolean", description: "replace every exact match" } }, required: ["path", "old_string", "new_string"] } } },
    { type: "function", function: { name: "python", description: "Run Python on-device via Pyodide. Pass code, or path to a .py file to read then run.",
      parameters: { type: "object", properties: { code: { type: "string", description: "Python source" }, path: { type: "string", description: "sandbox .py path to read then run" } } } } },
    { type: "function", function: { name: "bash", description: "Run a curated sandbox command (ls/cat/grep/find/mkdir/rm/cp/mv/wc/head/tail/pwd/echo/touch)",
      parameters: { type: "object", properties: { command: { type: "string", description: "the command to run" } }, required: ["command"] } } },
    { type: "function", function: { name: "run_command", description: "Alias of bash — run a curated sandbox command",
      parameters: { type: "object", properties: { command: { type: "string", description: "the command to run" } }, required: ["command"] } } },
    { type: "function", function: { name: "grep", description: "Search file contents for a pattern",
      parameters: { type: "object", properties: { pattern: { type: "string" }, path: { type: "string", description: "optional file or directory" } }, required: ["pattern"] } } },
    { type: "function", function: { name: "preview", description: "Open a sandbox HTML/file in the Preview tab (isolated WKWebView)",
      parameters: { type: "object", properties: { path: { type: "string", description: "relative file path, usually index.html" } }, required: ["path"] } } }
  ];
  var writeStartedNarration = {};
  var turnProseOut = false;
  function emitChat(kind, payload) {
    if (kind === "assistant") { try { turnProseOut = true; } catch (e) {} }
    try {
      var native = globalThis.window?.__forgeNative;
      if (native && native.call) {
        var args = { kind: kind };
        for (var k in payload) { args[k] = payload[k]; }
        native.call("session:chat", args).catch(function () {});
      }
    } catch (e) { /* best-effort */ }
  }
  function capToolOut(s) {
    s = String(s == null ? "" : s);
    return s.length > 4000 ? s.slice(0, 4000) + "\n…[truncated]" : s;
  }
  function toolErrMsg(e) {
    if (e == null) return "unknown error";
    if (typeof e === "string") return e;
    return e.message || String(e);
  }
  function parseToolArgs(raw) {
    var s = String(raw || "");
    try { return JSON.parse(s || "{}"); } catch (e) {}
    var objs = [];
    var depth = 0, start = -1;
    for (var i = 0; i < s.length; i++) {
      var ch = s.charAt(i);
      if (ch === "{") { if (depth === 0) start = i; depth++; }
      else if (ch === "}") {
        depth--;
        if (depth === 0 && start >= 0) {
          try { objs.push(JSON.parse(s.slice(start, i + 1))); } catch (e2) {}
          start = -1;
        }
      }
    }
    if (objs.length === 1) return objs[0];
    if (objs.length > 1) return { __multi: objs };
    return {};
  }
  // t1/t4 mash: streaming leftover `","path":"hello.py"}` concatenated into contents.
  // t7 path-first leftover is `"}` / stray `"` after a complete python/html line.
  function sanitizeWriteContents(s) {
    s = String(s == null ? "" : s);
    var cut = s.indexOf('","path":');
    if (cut >= 0) s = s.slice(0, cut);
    cut = s.indexOf('\n","path"');
    if (cut >= 0) s = s.slice(0, cut);
    var trimmedStart = s.replace(/^\s+/, "");
    var jsonDoc = trimmedStart.charAt(0) === "{" || trimmedStart.charAt(0) === "[";
    if (!jsonDoc) {
      s = s.replace(/(\)|>)\s*"\}\s*$/, "$1");
      s = s.replace(/(\)|>)\s*"\s*$/, "$1");
      if (/\n"\s*\}?\s*$/.test(s)) s = s.replace(/\n"\s*\}?\s*$/, "\n");
    }
    return s;
  }
  // Decode the JSON "content" string only — stop at the first unescaped `"`.
  // Do NOT unescape the rest of args (that paints leftover `"}` / stray quotes).
  function extractStreamingWriteContent(argsStr) {
    argsStr = String(argsStr == null ? "" : argsStr);
    var m1 = '"content":"';
    var m2 = '"content": "';
    var i1 = argsStr.indexOf(m1);
    var i2 = argsStr.indexOf(m2);
    var cIdx = -1;
    var marker = "";
    if (i1 >= 0 && (i2 < 0 || i1 <= i2)) { cIdx = i1; marker = m1; }
    else if (i2 >= 0) { cIdx = i2; marker = m2; }
    if (cIdx < 0) return "";
    var i = cIdx + marker.length;
    var out = "";
    while (i < argsStr.length) {
      var ch = argsStr.charAt(i);
      if (ch === "\\") {
        if (i + 1 >= argsStr.length) break;
        var next = argsStr.charAt(i + 1);
        if (next === "n") { out += "\n"; i += 2; continue; }
        if (next === "t") { out += "\t"; i += 2; continue; }
        if (next === "r") { out += "\r"; i += 2; continue; }
        if (next === '"') { out += '"'; i += 2; continue; }
        if (next === "\\") { out += "\\"; i += 2; continue; }
        if (next === "/") { out += "/"; i += 2; continue; }
        if (next === "b") { out += "\b"; i += 2; continue; }
        if (next === "f") { out += "\f"; i += 2; continue; }
        if (next === "u") {
          var hex = argsStr.slice(i + 2, i + 6);
          if (hex.length < 4) break;
          var code = parseInt(hex, 16);
          if (isNaN(code)) { out += next; i += 2; continue; }
          out += String.fromCharCode(code);
          i += 6;
          continue;
        }
        out += next;
        i += 2;
        continue;
      }
      if (ch === '"') break;
      out += ch;
      i++;
    }
    return sanitizeWriteContents(out);
  }
  function ensureTrailingNewline(s) {
    s = String(s == null ? "" : s);
    if (s.length && s.charAt(s.length - 1) !== "\n") s += "\n";
    return s;
  }
  function aliasToolName(name) {
    var n = String(name || "");
    if (n === "write_file") return "write";
    if (n === "run_command") return "bash";
    return n;
  }
  async function grepFallbackSearch(native, pattern, gpath) {
    var hits = [];
    async function scanFile(fp) {
      var ft = await native.call("readFile", { path: fp });
      ft = typeof ft === "string" ? ft : String(ft);
      var lns = ft.split("\n");
      for (var i = 0; i < lns.length; i++) {
        if (lns[i].indexOf(pattern) >= 0) {
          hits.push(fp + ":" + (i + 1) + ":" + lns[i]);
          if (hits.length >= 200) return;
        }
      }
    }
    if (gpath) {
      try {
        await scanFile(gpath);
        return hits;
      } catch (e) { /* directory or missing — list + scan */ }
    }
    var items = await native.call("listFiles", { path: gpath || "" });
    var arr = Array.isArray(items) ? items : [];
    for (var li = 0; li < arr.length && hits.length < 200; li++) {
      var it = arr[li];
      if (it && it.isDirectory) continue;
      var nm = it && (it.name != null ? it.name : it);
      var fp = gpath ? (String(gpath).replace(/\/$/, "") + "/" + nm) : String(nm);
      try { await scanFile(fp); } catch (e2) {}
    }
    return hits;
  }
  async function executeAgentTool(native, name, args, w) {
    args = args || {};
    var n = aliasToolName(name);
    var line = function (s) { if (w) try { w(s); } catch (e) {} };
    try {
      if (n === "read") {
        if (!args.path) return { name: n, ok: false, result: "ERROR: read missing path", files: 0, cmds: 0 };
        emitChat("phase", { text: "Reading " + args.path + "..." });
        var content = await native.call("readFile", { path: args.path });
        var text = typeof content === "string" ? content : JSON.stringify(content);
        emitChat("tool", { name: "read", arg: args.path, status: "✓" });
        emitChat("assistant", { text: ensureTrailingNewline("read " + args.path + " (" + text.length + " bytes)") });
        line(CY + "│ " + RS + GN + "read " + RS + YL + args.path + RS + CY + " │ " + RS + text.length + " bytes\n");
        return { name: n, ok: true, result: "Read " + args.path + " (" + text.length + " bytes)\n" + capToolOut(text), files: 0, cmds: 0 };
      }
      if (n === "write") {
        if (!args.path) return { name: n, ok: false, result: "ERROR: write missing path", files: 0, cmds: 0 };
        if (args.content == null) return { name: n, ok: false, result: "ERROR: write missing content", files: 0, cmds: 0 };
        var wcontent = ensureTrailingNewline(sanitizeWriteContents(args.content));
        if (typeof flushPendingAssistant === "function") flushPendingAssistant();
        else if (typeof flushPending === "function") flushPending();
        var __spoken = false;
        try { __spoken = !!turnProseOut; } catch (e) {}
        if (!__spoken && typeof writeStartedNarration !== "undefined" && !writeStartedNarration[args.path]) {
          emitChat("assistant", { text: ensureTrailingNewline("Starting with " + String(args.path).split("/").pop() + ".") });
        }
        if (typeof writeStartedNarration !== "undefined") writeStartedNarration[args.path] = true;
        emitChat("phase", { text: "Preparing write " + args.path + "..." });
        await native.call("writeFile", { path: args.path, content: wcontent });
        emitChat("write", { path: args.path, content: wcontent, bytes: wcontent.length });
        emitChat("tool", { name: "write", arg: args.path, status: "✓" });
        line(CY + "│ " + RS + GN + "write " + RS + YL + args.path + RS + CY + " │ " + RS + wcontent.length + " bytes\n");
        var lowerWrite = String(args.path).toLowerCase();
        if (lowerWrite.endsWith(".html") || lowerWrite.endsWith(".htm")) {
          try { await native.call("renderPreview", { path: args.path }); } catch (pre) {}
        }
        return { name: n, ok: true, result: "Wrote " + args.path + " (" + wcontent.length + " bytes)", files: 1, cmds: 0 };
      }
      if (n === "edit") {
        if (!args.path) return { name: n, ok: false, result: "ERROR: edit missing path", files: 0, cmds: 0 };
        if (args.old_string == null || String(args.old_string) === "") {
          return { name: n, ok: false, result: "ERROR: edit missing old_string", files: 0, cmds: 0 };
        }
        if (args.new_string == null) return { name: n, ok: false, result: "ERROR: edit missing new_string", files: 0, cmds: 0 };
        emitChat("phase", { text: "Editing " + args.path + "..." });
        var existing;
        try {
          existing = await native.call("readFile", { path: args.path });
        } catch (re) {
          var rem = toolErrMsg(re);
          emitChat("tool", { name: "edit", arg: args.path, status: "✗" });
          emitChat("assistant", { text: ensureTrailingNewline("edit failed: " + rem) });
          return { name: n, ok: false, result: "ERROR: edit read failed: " + rem, files: 0, cmds: 0 };
        }
        existing = typeof existing === "string" ? existing : String(existing);
        var oldS = String(args.old_string);
        var newS = String(args.new_string);
        var replaceAll = !!args.replace_all;
        var parts = existing.split(oldS);
        var count = parts.length - 1;
        if (count === 0) {
          emitChat("tool", { name: "edit", arg: args.path, status: "✗" });
          emitChat("assistant", { text: ensureTrailingNewline("edit no-match in " + args.path) });
          return { name: n, ok: false, result: "ERROR: edit no-match: old_string not found in " + args.path, files: 0, cmds: 0 };
        }
        if (count > 1 && !replaceAll) {
          emitChat("tool", { name: "edit", arg: args.path, status: "✗" });
          emitChat("assistant", { text: ensureTrailingNewline("edit ambiguous (" + count + " matches) in " + args.path) });
          return { name: n, ok: false, result: "ERROR: edit ambiguous: old_string matched " + count + " times in " + args.path + " (set replace_all to replace all)", files: 0, cmds: 0 };
        }
        var first = existing.indexOf(oldS);
        var updated = replaceAll ? parts.join(newS) : (existing.slice(0, first) + newS + existing.slice(first + oldS.length));
        await native.call("writeFile", { path: args.path, content: updated });
        emitChat("write", { path: args.path, content: updated, bytes: updated.length });
        emitChat("tool", { name: "edit", arg: args.path, status: "✓" });
        emitChat("assistant", { text: ensureTrailingNewline("edited " + args.path + " (" + (replaceAll ? count : 1) + " replacement(s))") });
        line(CY + "│ " + RS + GN + "edit " + RS + YL + args.path + RS + CY + " │ " + RS + (replaceAll ? count : 1) + " replacement(s)\n");
        return { name: n, ok: true, result: "Edited " + args.path + " (" + (replaceAll ? count : 1) + " replacement(s), " + updated.length + " bytes)", files: 1, cmds: 0 };
      }
      if (n === "bash") {
        if (!args.command) return { name: n, ok: false, result: "ERROR: bash missing command", files: 0, cmds: 0 };
        emitChat("phase", { text: "Running " + args.command + "..." });
        var r = await native.call("runCommand", { command: args.command });
        var out = (r && r.stdout || "") + (r && r.stderr ? "\n" + r.stderr : "");
        emitChat("tool", { name: "bash", arg: args.command, status: "✓" });
        line(YL + "$ " + args.command + RS + "\n");
        if (out) line(capToolOut(out) + "\n");
        return { name: n, ok: true, result: "Ran '" + args.command + "' exit=" + ((r && r.exitCode) != null ? r.exitCode : "?")
          + (out ? "\n" + capToolOut(out) : ""), files: 0, cmds: 1 };
      }
      if (n === "grep") {
        if (!args.pattern) return { name: n, ok: false, result: "ERROR: grep missing pattern", files: 0, cmds: 0 };
        var pattern = String(args.pattern);
        var gpath = args.path ? String(args.path) : "";
        emitChat("phase", { text: "grep " + pattern + (gpath ? " " + gpath : "") + "..." });
        var gout = "";
        var gexit = 0;
        var usedNative = false;
        var simple = pattern.indexOf(" ") < 0 && pattern.charAt(0) !== "-";
        if (simple) {
          try {
            var gcmd = "grep " + pattern + (gpath ? " " + gpath : "");
            var gr = await native.call("runCommand", { command: gcmd });
            gout = (gr && gr.stdout) || "";
            if (gr && gr.stderr) gout = gout ? (gout + "\n" + gr.stderr) : gr.stderr;
            gexit = (gr && gr.exitCode) != null ? gr.exitCode : 0;
            usedNative = true;
          } catch (ge) {
            usedNative = false;
          }
        }
        if (!usedNative) {
          var hits = await grepFallbackSearch(native, pattern, gpath);
          gout = hits.join("\n");
          gexit = hits.length ? 0 : 1;
        }
        emitChat("tool", { name: "grep", arg: pattern, status: "✓" });
        line(YL + "✱ grep " + pattern + RS + "\n");
        if (gout) line(capToolOut(gout) + "\n");
        return { name: n, ok: true, result: "grep " + JSON.stringify(pattern) + (gpath ? " path=" + gpath : "") + " exit=" + gexit
          + (gout ? "\n" + capToolOut(gout) : "\n(no matches)"), files: 0, cmds: 1 };
      }
      if (n === "python") {
        var pyCode = args.code != null && String(args.code) !== "" ? String(args.code) : "";
        var pyPath = args.path ? String(args.path) : "";
        if (!pyCode && !pyPath) return { name: n, ok: false, result: "ERROR: python missing code or path", files: 0, cmds: 0 };
        if (!pyCode && pyPath) {
          try {
            var pySrc = await native.call("readFile", { path: pyPath });
            pyCode = typeof pySrc === "string" ? pySrc : String(pySrc);
          } catch (pre) {
            var pem = toolErrMsg(pre);
            emitChat("tool", { name: "python", arg: pyPath, status: "✗" });
            emitChat("assistant", { text: ensureTrailingNewline("python read failed: " + pem) });
            return { name: n, ok: false, result: "ERROR: python read " + pyPath + ": " + pem, files: 0, cmds: 0 };
          }
        }
        emitChat("phase", { text: pyPath ? "Running python " + pyPath + "..." : "Running python..." });
        try {
          var py = await native.call("runPython", { code: pyCode });
          var pyOut = py == null ? "" : String(py);
          if (pyOut === "undefined" || pyOut === "None") pyOut = "";
          if (pyOut) pyOut = ensureTrailingNewline(pyOut);
          emitChat("tool", { name: "python", arg: pyPath || "code", status: "✓" });
          emitChat("assistant", { text: ensureTrailingNewline(capToolOut(pyOut || "(python completed, empty stdout)")) });
          line(YL + "python" + (pyPath ? " " + pyPath : "") + RS + "\n");
          line(DM + "python stdout bytes: " + String(pyOut.length) + RS + "\n");
          if (pyOut) line(capToolOut(pyOut) + "\n");
          return { name: n, ok: true, result: "python stdout:\n" + capToolOut(pyOut || "(empty)"), files: 0, cmds: 1 };
        } catch (pe) {
          var pye = toolErrMsg(pe);
          emitChat("tool", { name: "python", arg: pyPath || "code", status: "✗" });
          emitChat("assistant", { text: ensureTrailingNewline(pye) });
          line(RD + "✗ python — " + pye + RS + "\n");
          return { name: n, ok: false, result: "ERROR: python: " + pye, files: 0, cmds: 1 };
        }
      }
      if (n === "preview") {
        if (!args.path) return { name: n, ok: false, result: "ERROR: preview missing path", files: 0, cmds: 0 };
        emitChat("phase", { text: "Opening Preview " + args.path + "..." });
        try {
          await native.call("renderPreview", { path: args.path });
          emitChat("tool", { name: "preview", arg: args.path, status: "✓" });
          line(GN + "preview " + RS + YL + args.path + RS + "\n");
          return { name: n, ok: true, result: "Opened Preview " + args.path, files: 0, cmds: 1 };
        } catch (pve) {
          var pvm = toolErrMsg(pve);
          emitChat("tool", { name: "preview", arg: args.path, status: "✗" });
          return { name: n, ok: false, result: "ERROR: preview: " + pvm, files: 0, cmds: 1 };
        }
      }
      return { name: n, ok: false, result: "ERROR: unknown tool: " + n, files: 0, cmds: 0 };
    } catch (e) {
      var em = toolErrMsg(e);
      emitChat("tool", { name: n, arg: args.path || args.command || args.pattern || "", status: "✗" });
      line(RD + "✗ " + n + " — " + em + RS + "\n");
      return { name: n, ok: false, result: "ERROR: " + n + ": " + em, files: 0, cmds: 0 };
    }
  }
  // CONNECT (spec docs/CONNECT_SPEC.md). Pure, dependency-free: the repo
  // suite executes these via node. Secret values NEVER appear here — key
  // entry uses native secure entry only.
  function parseSlashCommand(input) {
    const t = (input || "").trim();
    if (!t.startsWith("/")) return { slash: false };
    const parts = t.slice(1).split(/\s+/).filter(function (p) { return p.length > 0; });
    if (parts.length === 0) return { slash: false };
    return { slash: true, cmd: parts[0].toLowerCase(), args: parts.slice(1) };
  }
  function normalizeConnectProvider(raw) {
    const v = (raw || "").toLowerCase();
    if (v === "anthropic") return "anthropic";
    if (v === "openai" || v === "zen" || v === "opencode zen") return "openai";
    return v;
  }
  function isRetiredConnectModel(id) {
    const v = (id || "").toLowerCase();
    return v === "deepseek-v4-flash-free" || v === "deepseek-v4-flash" ||
      v === "muse-spark-1.2-contributor-free" || v === "muse-spark-1.2" ||
      v.indexOf("deepseek-v4-flash") === 0;
  }
  function isSecretLike(v) {
    return /sk-[A-Za-z0-9]{8,}/.test(v || "");
  }
  function buildConnectUpdate(field, value, current) {
    const f = (field || "").toLowerCase();
    const v = (value || "").trim();
    if (f === "provider") {
      if (!v) return { ok: false, error: "usage: /connect provider <openai|anthropic|custom|local>" };
      return { ok: true, patch: { provider: normalizeConnectProvider(v) } };
    }
    if (f === "model") {
      if (!v) return { ok: false, error: "usage: /connect model <model-id>" };
      if (isSecretLike(v)) return { ok: false, error: "leak-risk: secret-like value refused as model; keys are set only through secure entry" };
      if (isRetiredConnectModel(v)) return { ok: false, error: "retired model: " + v };
      if (v.toLowerCase() !== "muse-spark-1.3-contributor") return { ok: false, error: "only model allowed: muse-spark-1.3-contributor" };
      return { ok: true, patch: { model: v } };
    }
    if (f === "url") {
      if (!/^https?:\/\/\S+$/.test(v)) return { ok: false, error: "bad url: must be http(s):// with no spaces" };
      if (isSecretLike(v)) return { ok: false, error: "leak-risk: secret-like value refused as url" };
      return { ok: true, patch: { baseUrl: v.replace(/\/+$/, "") } };
    }
    if (f === "key") {
      return { ok: false, error: "keys are set only through secure entry: run /connect key" };
    }
    return { ok: false, error: "unknown connect field: " + (field || "") };
  }
  // Dual-emit: terminal line for the live TUI plus a chat bubble so the
  // result is visible to accessibility clients (XCUITest) and chat history.
  // NEVER pass secret values here — presence words only.
  function connectSay(w, text) {
    w(text + "\n");
    try { emitChat("assistant", { text: text }); } catch (e) {}
  }
  async function handleSlashCommand(trimmed, ctx) {
    const w = ctx.w, native = ctx.native;
    const parsed = parseSlashCommand(trimmed);
    if (!parsed.slash) return await null;
    if (parsed.cmd === "help") {
      w("  /connect              Provider-auth status + usage\n");
      w("  /connect status       Show provider/model/url/key-presence\n");
      w("  /connect provider <id>  Set provider (openai|anthropic|custom|local)\n");
      w("  /connect model <id>   Set model id (retired ids refused)\n");
      w("  /connect url <base>   Set endpoint base URL\n");
      w("  /connect key          Set API key via secure entry (never typed)\n");
      w("  /connect test         Live minimal model call on saved config\n");
      return "slash-help";
    }
    if (parsed.cmd !== "connect") {
      w("[forge] unknown command: " + parsed.cmd + " (try /help)\n");
      return "unknown-command";
    }
    return await handleConnectCommand(parsed.args, ctx);
  }
  function connectStatusLine() {
    const cfg = globalThis.window?.__forgeConfig || {};
    return "  Provider:  " + (cfg.provider || "unset") + "\n" +
      "  Model:     " + (cfg.model || "unset") + "\n" +
      "  URL:       " + (cfg.baseUrl || "unset") + "\n" +
      "  API Key:   " + (cfg.apiKey && cfg.apiKey !== "public" ? "configured (" + cfg.apiKey.length + " chars)" : "MISSING") + "\n";
  }
  async function handleConnectCommand(args, ctx) {
    const w = ctx.w, native = ctx.native;
    const sub = (args[0] || "status").toLowerCase();
    if (sub === "status" || args.length === 0) {
      connectSay(w, "Provider auth\n" + connectStatusLine() +
        "Usage: /connect provider|model|url <value>  ·  /connect key  ·  /connect test");
      return "connect-status";
    }
    if (sub === "key") {
      if (!native?.call) { w("[forge] native bridge unavailable\n"); return "error: no native bridge"; }
      let secret = null;
      try {
        secret = await native.call("promptSecret", { title: "API Key" });
      } catch (e) { w("[forge] secure entry unavailable\n"); return "error: secure entry unavailable"; }
      if (!secret) { w("Key entry cancelled.\n"); return "connect-key-cancelled"; }
      try {
        await native.call("setSecret", { key: "forge.apiKey", value: String(secret) });
      } catch (e) {
        w("[forge] keychain save failed\n"); return "error: keychain save failed";
      }
      try {
        await native.call("saveProviderConfig", {});
      } catch (e) { /* older hosts re-inject on next launch */
      }
      w("API key saved to Keychain.\n");
      try { emitChat("assistant", { text: "API key saved to Keychain." }); } catch (e) {}
      return "connect-key-saved";
    }
    if (sub === "test") {
      w("Testing saved provider config with a live minimal call…\n");
      const probe = await connectTestCall(ctx);
      w(probe + "\n");
      try { emitChat("assistant", { text: probe }); } catch (e) {}
      return probe.indexOf("PASS") === 0 ? "connect-test-pass" : "connect-test-fail";
    }
    const upd = buildConnectUpdate(sub, args.slice(1).join(" "), {});
    if (!upd.ok) { w("[forge] " + upd.error + "\n"); return "error: " + upd.error; }
    if (!native?.call) { w("[forge] native bridge unavailable\n"); return "error: no native bridge"; }
    try {
      await native.call("saveProviderConfig", upd.patch);
    } catch (e) {
      w("[forge] provider save unavailable on this host\n"); return "error: provider save unavailable";
    }
    connectSay(w, "Saved " + sub + ".\n" + connectStatusLine());
    return "connect-saved-" + sub;
  }
  async function connectTestCall(ctx) {
    const w = ctx.w, native = ctx.native;
    const cfg = globalThis.window?.__forgeConfig || {};
    if (!cfg.apiKey || cfg.apiKey === "public") return "FAIL: no API key connected (run /connect key)";
    const base = String(cfg.baseUrl || "https://opencode.ai/zen/v1").replace(/\/+$/, "");
    const model = cfg.model || "muse-spark-1.3-contributor";
    const isMuse = model.indexOf("muse") === 0;
    const url = base.endsWith("/v1") ? base + (isMuse ? "/responses" : "/chat/completions")
      : base + (isMuse ? "/v1/responses" : "/v1/chat/completions");
    const payload = isMuse
      ? JSON.stringify({ model, input: [{ role: "user", content: "Reply with the single word OK." }], stream: false, max_output_tokens: 16 })
      : JSON.stringify({ model, messages: [{ role: "user", content: "Reply with the single word OK." }], stream: false, max_tokens: 16 });
    try {
      let resp = null;
      if (native?.call) {
        resp = await native.call("httpRequest", {
          url, method: "POST",
          headers: { "Content-Type": "application/json", "Authorization": "Bearer " + cfg.apiKey },
          body: payload
        });
      } else if (typeof fetch !== "undefined") {
        const r = await fetch(url, { method: "POST", headers: { "Content-Type": "application/json", "Authorization": "Bearer " + cfg.apiKey }, body: payload });
        resp = { status: r.status, body: await r.text() };
      } else {
        return "FAIL: no request channel";
      }
      const st = resp?.status ?? resp?.statusCode ?? 0;
      if (st >= 200 && st < 300) return "PASS: connected provider answered (" + st + ")";
      return "FAIL: provider answered " + st;
    } catch (e) {
      return "FAIL: unreachable endpoint";
    }
  }
  async function runForgeAgent(userInput, term, w) {
    const config = globalThis.window?.__forgeConfig || {};
    const apiKey = config.apiKey;
    const native = globalThis.window?.__forgeNative;
    if (!apiKey) {
      w(RD + "⚠ No API key configured." + RS + "\n");
      w(DM + "Open Settings (gear icon) → set provider + API key, then return here." + RS + "\n\n");
      return "no-api-key";
    }
    if (!native?.call) {
      w(RD + "⚠ Native bridge unavailable." + RS + "\n");
      return "no-bridge";
    }
    const provider = (config.provider || "anthropic").toLowerCase();
    const model = config.model || "muse-spark-1.3-contributor";
    const baseUrl = (config.baseUrl || "https://api.anthropic.com").replace(/\/$/, "");
    function zenIdentityHeaders(extra) {
      var h = extra || {};
      h["x-opencode-session"] = config.sessionID || h["x-opencode-session"] || "";
      h["x-opencode-request"] = config.requestID || ("msg_" + Date.now().toString(16));
      h["x-opencode-project"] = config.projectID || h["x-opencode-project"] || "";
      h["x-opencode-client"] = config.client || "cli";
      h["User-Agent"] = config.userAgent || "opencode/1.14.51";
      return h;
    }
    try {
      native.call("session:header", {
        title: "FORGE-Demo",
        model: model
      }).catch(function () { /* best-effort */ });
    } catch (e) { /* token/header reporting is best-effort */ }
    // opencode-style: user prompt in a box (orange border — fire theme), then
    // an agent status line (■ agent · model) before the tool loop.
    var boxW = 46;
    var lines = userInput.split("\n");
    w(BD + CY + "+" + Array(boxW + 1).join("-") + "+" + RS + "\n");
    for (var bi = 0; bi < lines.length; bi++) {
      var ln = lines[bi];
      if (ln.length > boxW - 4) ln = ln.slice(0, boxW - 7) + "...";
      w(CY + "| " + RS + ln + Array(Math.max(1, boxW - 2 - ln.length)).join(" ") + CY + " |" + RS + "\n");
    }
    w(BD + CY + "+" + Array(boxW + 1).join("-") + "+" + RS + "\n");
    w(CY + "■ " + RS + "trident" + CY + " · " + RS + model + "\n\n");
    try { turnProseOut = false; } catch (e) {}
    for (var wsp in writeStartedNarration) { try { delete writeStartedNarration[wsp]; } catch (e2) {} }
    emitChat("user", { text: userInput });
    emitChat("status", { text: "\u25a0 working \u00b7 " + model });
    const messages = [
      { role: "system", content: AGENT_SYSTEM_PROMPT },
      { role: "user", content: userInput }
    ];
    let totalFiles = 0;
    let totalCmds = 0;
    for (let iter = 0; iter < 12; iter++) {
      // WORKING INDICATOR: emit at the start of EVERY iteration so the
      // transcript shows "■ working · model" (with the animated spinner)
      // during each LLM round-trip — the screen is never dead while the
      // model generates (opencode TUI behavior).
      if (iter > 0) {
        emitChat("status", { text: "\u25a0 working \u00b7 " + model });
      }
      let llmText = null;
      let lastUsage = null;
      try {
        if (provider === "anthropic" || provider.includes("claude")) {
          const payload = JSON.stringify({ model, max_tokens: 4096, messages });
          // Prefer native bridge (URLSession — no CORS). Fall back to fetch().
          let resp, data;
          if (native?.call) {
            const r = await native.call("httpRequest", {
              url: baseUrl + "/v1/messages",
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01"
              },
              body: payload
            });
            if (r?.status && r.status >= 400) {
              w(RD + "LLM error " + r.status + ": " + String(r.body || "").slice(0, 200) + RS + "\n");
              if (r.status === 401) w(RD + "[hint] open Settings -> API Configuration -> Get a free key at opencode.ai/auth" + RS + "\n");
              emitChat("status", { text: "✗ llm-error:" + r.status });
              emitChat("assistant", { text: r.status === 429
                ? "⚠ LLM error 429 — free-tier rate limit hit. Wait ~60s and retry."
                : "⚠ LLM error " + r.status + (r.status === 401 ? " — get a free key at opencode.ai/auth (Settings → API Configuration)." : "") });
              return "llm-error:" + r.status;
            }
            data = JSON.parse(r?.body || "{}");
          } else {
            resp = await fetch(baseUrl + "/v1/messages", {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
                "anthropic-dangerous-direct-browser-access": "true"
              },
              body: payload
            });
            if (!resp.ok) {
              const t = await resp.text();
              w(RD + "LLM error " + resp.status + ": " + t.slice(0, 200) + RS + "\n");
              emitChat("status", { text: "✗ llm-error:" + resp.status });
              emitChat("assistant", { text: resp.status === 429
                ? "⚠ LLM error 429 — free-tier rate limit hit. Wait ~60s and retry."
                : "⚠ LLM error " + resp.status });
              return "llm-error:" + resp.status;
            }
            data = await resp.json();
          }
          lastUsage = data.usage || null;
          llmText = data.content?.[0]?.text || "";
        } else if (provider === "openai") {
          const apiBase = (config.baseUrl || "https://opencode.ai/zen/v1").replace(/\/+$/, "");
          var museMode = (model || "").indexOf("muse") === 0;
          var url, payload;
          if (museMode) {
            url = apiBase.endsWith("/v1") ? apiBase + "/responses" : apiBase + "/v1/responses";
            var museIn = [];
            for (var mi = 0; mi < messages.length; mi++) {
              var mm = messages[mi];
              museIn.push({ role: mm.role, content: typeof mm.content === "string" ? mm.content : JSON.stringify(mm.content) });
            }
            var museTools = [];
            for (var ati = 0; ati < AGENT_TOOLS.length; ati++) { var af = AGENT_TOOLS[ati].function;
              museTools.push({ type: "function", name: af.name, description: af.description, parameters: af.parameters }); }
            payload = JSON.stringify({ model: model, input: museIn, stream: true, tools: museTools, max_output_tokens: 16384 });
          } else {
            url = apiBase.endsWith("/v1") ? apiBase + "/chat/completions" : apiBase + "/v1/chat/completions";
            payload = JSON.stringify({ model: model || "muse-spark-1.3-contributor", max_tokens: 4096, messages, stream: true, tools: AGENT_TOOLS });
          }
          let data;
          if (native?.call) {
            // STREAMING path: on-device LLM via native.httpRequestStream / fetch.
            // Mode 1 never streams a host opencode session. Tokens from the
            // model are allowed; host serve is not the live turn.
            var streamId = "llm" + Date.now();
            var streamText = "";
            var chatReasoningBuf = "";
            var chatReasoningFlushed = 0;
            var chatAssistantBuf = "";
            var chatAssistantFlushed = 0;
            // File-fence state: while inside a ```file: block, content is NOT
            // emitted as assistant prose (it reaches the UI via write events
            // after the stream completes). Prevents code-in-prose corruption.
            var inFileBlock = false;
            var fileBlockBuf = "";
            // THROTTLED EMIT: deltas accumulate here and flush every 66ms
            // (~15fps) so the Swift store receives smooth progressive updates
            // instead of a storm of per-token notifications (the static/burst
            // screen bug).
            var streamToolCalls = {};  // accumulated tool_call arguments by index
            var pendingReasoning = "";
            var pendingAssistant = "";
            var emitTimer = null;
            var streamDone = false;
            var streamFailed = false;
            var streamStatus = 0;
            var streamTimer = null;
            var streamBuffer = "";
            var streamFlushTimer = null;
            var museCallIds = {};
            var museNextIdx = 0;
            function museSseToChat(text) {
              var out = "";
              var rawLines = String(text).split("\n");
              for (var rli = 0; rli < rawLines.length; rli++) {
                var rline = rawLines[rli].trim();
                if (!rline) continue;
                if (rline.indexOf("data:") === 0) {
                  var d = rline.slice(5).trim();
                  if (!d || d === "[DONE]") continue;
                  try {
                    var jo = JSON.parse(d);
                    var t = jo.type || "";
                    if (t === "response.output_text.delta" && jo.delta) {
                      out += "data: " + JSON.stringify({choices:[{delta:{content: jo.delta}}]}) + "\n";
                    } else if ((t === "response.reasoning_summary_text.delta" || t === "response.reasoning_text.delta") && jo.delta) {
                      out += "data: " + JSON.stringify({choices:[{delta:{reasoning_content: jo.delta}}]}) + "\n";
                    } else if (t === "response.output_item.added" && jo.item && jo.item.type === "function_call") {
                      var cid = jo.item.call_id || jo.item.id || ("call_"+museNextIdx);
                      var idx = museNextIdx++;
                      museCallIds[cid] = idx;
                      if (jo.item.id) museCallIds[jo.item.id] = idx;
                      out += "data: " + JSON.stringify({choices:[{delta:{tool_calls:[{index: idx, id: cid, function:{name: jo.item.name || "", arguments:""}}]}}]}) + "\n";
                    } else if (t === "response.function_call_arguments.delta" && jo.delta) {
                      var iid = jo.item_id || jo.itemId || (jo.item && (jo.item.id || jo.item.call_id)) || "";
                      var fidx = iid !== "" ? museCallIds[iid] : undefined;
                      // NEVER default unknown item_id to 0 — that concatenates
                      // a second write into the first tool's JSON (t1 mashed blob).
                      if (fidx == null) {
                        fidx = museNextIdx++;
                        if (iid) museCallIds[iid] = fidx;
                      }
                      out += "data: " + JSON.stringify({choices:[{delta:{tool_calls:[{index: fidx, function:{arguments: jo.delta}}]}}]}) + "\n";
                    } else if (t === "response.completed" || t === "response.incomplete" || t === "response.failed") {
                      out += "data: [DONE]\n";
                    }
                  } catch(e) {}
                } else if (rline.indexOf("event:") === 0) {
                  continue;
                }
              }
              return out || text;
            }
            var spinnerLine = true;
            // Static working line (opencode's "■ Build · model" style — the
            // streamed tokens provide the motion; no 
            // corrupt SwiftTerm's line model).
            w(CY + "■ working \u00b7 " + RS + model + "\n");
            window.__forgeStreamChunk = function (id, text) {
              if (id !== streamId) return;
              if (typeof museMode !== 'undefined' && museMode) { try { text = museSseToChat(text); } catch(e) {} }

              if (spinnerLine) { spinnerLine = false; }
              var lines = String(text).split("\n");
              for (var li = 0; li < lines.length; li++) {
                var line = lines[li].trim();
                if (line.indexOf("data:") !== 0) continue;
                var payloadLine = line.slice(5).trim();
                if (payloadLine === "[DONE]") continue;
                try {
                  var obj = JSON.parse(payloadLine);
                  var ch = obj.choices && obj.choices[0];
                  if (!ch) continue;
                  var d = ch.delta || ch.message || {};
                  // TOOL CALLS: when the model returns function calls instead
                  // of text, accumulate the arguments per tool_call index.
                  // Arguments stream as fragments; assembled post-stream.
                  if (d.tool_calls) {
                    for (var tc = 0; tc < d.tool_calls.length; tc++) {
                      var call = d.tool_calls[tc];
                      var idx = call.index != null ? call.index : tc;
                      if (!streamToolCalls[idx]) streamToolCalls[idx] = { name: "", args: "", contentStarted: false, contentEmitted: 0 };
                      if (call.function && call.function.name) streamToolCalls[idx].name = call.function.name;
                      if (call.function && call.function.arguments) {
                        streamToolCalls[idx].args += call.function.arguments;
                        // PROGRESSIVE WRITE VISIBILITY: once the "content" field
                        // starts in the JSON args, extract the growing content
                        // and emit it as a streaming write event so the UI
                        // shows the file being written in real-time (not an
                        // empty gap while the model generates 400 lines).
                        var t = streamToolCalls[idx];
                        if (t.name === "write_file" || t.name === "write") {
                          // Wait for a real path — never default to "file" (t7 ghost panel).
                          var pathMatch = t.args.match(/"path":"([^"]*)"/);
                          if (pathMatch && pathMatch[1]) {
                            t.path = pathMatch[1];
                            var unescaped = extractStreamingWriteContent(t.args);
                            unescaped = sanitizeWriteContents(unescaped);
                            unescaped = ensureTrailingNewline(unescaped);
                            if (unescaped.length || t.contentStarted) {
                              if (!t.contentStarted) {
                                t.contentStarted = true;
                                if (typeof flushPendingAssistant === "function") flushPendingAssistant();
                                else if (typeof flushPending === "function") flushPending();
                                var __spoken = false;
                                try { __spoken = !!turnProseOut; } catch (e) {}
                                if (!__spoken && typeof writeStartedNarration !== "undefined" && !writeStartedNarration[t.path]) {
                                  emitChat("assistant", { text: ensureTrailingNewline("Starting with " + t.path.split("/").pop() + ".") });
                                }
                                if (typeof writeStartedNarration !== "undefined") writeStartedNarration[t.path] = true;
                              }
                              // Snapshot REPLACE (attachWrite), not append-only writeStream.
                              // Leftover JSON closer cannot stick after sanitize shrinks.
                              if (t.lastWriteSnap !== unescaped) {
                                t.lastWriteSnap = unescaped;
                                emitChat("write", { path: t.path, content: unescaped, bytes: unescaped.length });
                              }
                            }
                          }
                        }
                      }
                    }
                    continue; // tool_calls have no content — don't emit as prose
                  }
                  // deepseek streams reasoning_content FIRST, then content.
                  // Render reasoning dim (opencode "thinking" style) so the
                  // TUI shows motion immediately, then the answer bright.
                  var reasoning = d.reasoning_content || "";
                  var delta = d.content || "";
                  if (reasoning) {
                    streamText += reasoning;
                    streamBuffer += DM + reasoning + RS;
                    chatReasoningBuf += reasoning;
                    // ACCUMULATE — flush happens on the 66ms emit timer.
                    pendingReasoning += reasoning;
                  }
                  if (delta) {
                    // FENCE FILTER: the model's ```file: and ```command blocks
                    // contain code/commands. During streaming we DON'T emit
                    // them as prose — they'd appear as corrupted chat text.
                    // Only text OUTSIDE fences goes to assistant prose.
                    // File content reaches the UI via write events; commands
                    // via the bash/tool execution path after the stream.
                    if (!inFileBlock) {
                      // Detect BOTH fence types: ```file: and ```command
                      var fstart = delta.indexOf("```file:");
                      var cstart = delta.indexOf("```command");
                      var bstart = (fstart >= 0 && (cstart < 0 || fstart < cstart)) ? fstart
                                 : (cstart >= 0 ? cstart : -1);
                      if (bstart >= 0) {
                        var pre = delta.slice(0, bstart);
                        if (pre) {
                          streamText += pre;
                          streamBuffer += pre;
                          chatAssistantBuf += pre;
                          pendingAssistant += pre;
                        }
                        // NOTE: streamText gets the FULL fence (incl. content)
                        // so parseAgentBlocks can find it after the stream.
                        inFileBlock = true;
                        fileBlockBuf = delta.slice(bstart);
                      } else {
                        streamText += delta;
                        streamBuffer += delta;
                        chatAssistantBuf += delta;
                        pendingAssistant += delta;
                      }
                    } else {
                      // Inside a fence: accumulate; check for the CLOSING ```
                      // (3+ backticks on their own line or trailing).
                      fileBlockBuf += delta;
                      // streamText gets the fence content too — needed for
                      // parseAgentBlocks post-stream. NOT emitted as prose.
                      streamText += delta;
                      var closeIdx = fileBlockBuf.indexOf("\n```");
                      if (closeIdx >= 0) {
                        inFileBlock = false;
                        fileBlockBuf = "";
                      } else if (fileBlockBuf.indexOf("\n```") === -1 &&
                                 /```\s*$/.test(fileBlockBuf) &&
                                 fileBlockBuf.replace(/```\s*$/, "").trim().length > 0) {
                        inFileBlock = false;
                        fileBlockBuf = "";
                      }
                    }
                  }
                } catch (e) { /* partial SSE line */ }
              }
              // Throttled flush: the simulator's CoreGraphics renderer
              // (Metal off) cannot repaint partial lines at chunk rate —
              // batching every 250ms lets each render settle cleanly while
              // still streaming visibly.
              if (!streamFlushTimer) {
                streamFlushTimer = setTimeout(function () {
                  streamFlushTimer = null;
                  if (streamBuffer) { w(streamBuffer); streamBuffer = ""; }
                }, 250);
              }
            };
            window.__forgeStreamDone = function (id, ok, status) {
              if (id !== streamId) return;

              streamDone = true;
              streamFailed = !ok;
              if (typeof status === "number") streamStatus = status;
              // FINAL FLUSH: emit everything pending + the buffered tail
              // (below the old 200-char threshold).
              if (pendingReasoning) {
                emitChat("reasoning", { text: pendingReasoning });
                chatReasoningFlushed += pendingReasoning.length;
                pendingReasoning = "";
              }
              if (chatReasoningBuf.length > chatReasoningFlushed) {
                emitChat("reasoning", { text: chatReasoningBuf.slice(chatReasoningFlushed) });
                chatReasoningFlushed = chatReasoningBuf.length;
              }
              if (pendingAssistant && !inFileBlock) {
                emitChat("assistant", { text: pendingAssistant });
                chatAssistantFlushed += pendingAssistant.length;
                pendingAssistant = "";
              }
              if (chatAssistantBuf.length > chatAssistantFlushed && !inFileBlock) {
                emitChat("assistant", { text: chatAssistantBuf.slice(chatAssistantFlushed) });
                chatAssistantFlushed = chatAssistantBuf.length;
              }
              if (emitTimer) { clearInterval(emitTimer); emitTimer = null; }
              if (typeof spinnerTimer !== "undefined" && spinnerTimer) { clearInterval(spinnerTimer); spinnerTimer = null; }
              if (spinnerLine) { w("\r" + Array(50).join(" ") + "\r"); spinnerLine = false; }
              w("\n");
            };
            // 250ms throttled flush → ~4fps progressive streaming. Started
            // after the stream begins; cleared on done. 250ms (not 66ms) to
            // avoid the WebKit suspend/resume churn that SIGSEGVs the
            // WebContent process (each native.call wakes it; 15/sec = thrash).
            emitTimer = setInterval(function () {
              if (pendingReasoning) {
                emitChat("reasoning", { text: pendingReasoning });
                // DUP-FIX (2026-08-15): advance the tail cursor in lockstep
                // with every progressive emit — otherwise __forgeStreamDone's
                // final flush re-emits the whole buffer (duplicated text).
                chatReasoningFlushed += pendingReasoning.length;
                pendingReasoning = "";
              }
              if (pendingAssistant) {
                emitChat("assistant", { text: pendingAssistant });
                chatAssistantFlushed += pendingAssistant.length;
                pendingAssistant = "";
              }
            }, 250);
            // FIRE-AND-FORGET: the bridge never resolves this promise (chunks
            // stream via window.__forgeStreamChunk); completion arrives via
            // window.__forgeStreamDone. Do not await — poll streamDone.
            native.call("httpRequestStream", {
              url: url,
              method: "POST",
              headers: zenIdentityHeaders({
                "Content-Type": "application/json",
                "Authorization": "Bearer " + (apiKey && apiKey !== "public" ? apiKey : "public")
              }),
              body: payload,
              streamId: streamId
            }).catch(function () { /* best-effort */ });
            var waitStart = Date.now();
            while (!streamDone && Date.now() - waitStart < 180000) {
              await new Promise(function (res) { setTimeout(res, 50); });
            }
            if (streamStatus >= 400) {
              var errBody = String(streamBuffer || streamText || "").replace(/\s+/g, " ").slice(0, 240);
              w(RD + "LLM error " + streamStatus + (errBody ? ": " + errBody : "") + RS + "\n");
              if (streamStatus === 401) w(RD + "[hint] open Settings -> API Configuration -> Get a free key at opencode.ai/auth" + RS + "\n");
              // LOUD-FAIL (2026-08-15): error paths must update the chat — a
              // silent return leaves the status at "working" forever and the
              // user sees a hang instead of the real error.
              emitChat("status", { text: "✗ llm-error:" + streamStatus });
              emitChat("assistant", { text: streamStatus === 429
                ? "⚠ LLM error 429 — free-tier rate limit hit. Wait ~60s and retry."
                : "⚠ LLM error " + streamStatus + (streamStatus === 401 ? " — get a free key at opencode.ai/auth (Settings → API Configuration)." : "") });
              return "llm-error:" + streamStatus;
            }
            if (streamFailed) {
              w(RD + "LLM stream failed" + RS + "\n");
              emitChat("status", { text: "✗ llm-stream-failed" });
              emitChat("assistant", { text: "⚠ LLM stream failed — the connection dropped mid-stream. Retry." });
              return "llm-stream-failed";
            }
            if (streamText) {
              data = { choices: [{ message: { content: streamText } }],
                       usage: { prompt_tokens: Math.ceil(messages.reduce(function (a, m) { return a + (m.content || "").length; }, 0) / 4),
                                completion_tokens: Math.ceil(streamText.length / 4) } };
            } else {
              data = {};
            }
          } else {
            resp = await fetch(url, {
              method: "POST",
              headers: zenIdentityHeaders({
                "Content-Type": "application/json",
                "Authorization": "Bearer " + (apiKey && apiKey !== "public" ? apiKey : "public")
              }),
              body: payload
            });
            if (!resp.ok) {
              const t = await resp.text();
              w(RD + "LLM error " + resp.status + ": " + t.slice(0, 200) + RS + "\n");
              emitChat("status", { text: "✗ llm-error:" + resp.status });
              emitChat("assistant", { text: resp.status === 429
                ? "⚠ LLM error 429 — free-tier rate limit hit. Wait ~60s and retry."
                : "⚠ LLM error " + resp.status });
              return "llm-error:" + resp.status;
            }
            data = await resp.json();
          }
          lastUsage = data.usage || null;
          // If the model returned tool calls, execute them instead of parsing fences.
          if (typeof streamToolCalls !== "undefined" && Object.keys(streamToolCalls).length > 0) {
            const results = [];
            for (const idx of Object.keys(streamToolCalls).sort()) {
              const tc = streamToolCalls[idx];
              try {
                const parsed = parseToolArgs(tc.args || "{}");
                const argList = parsed && parsed.__multi ? parsed.__multi : [parsed];
                for (const args of argList) {
                  const ex = await executeAgentTool(native, tc.name, args, w);
                  results.push(ex.result);
                  totalFiles += ex.files;
                  totalCmds += ex.cmds;
                }
              } catch (e) {
                results.push("FAILED tool call: " + (e?.message ?? e));
              }
            }
            // Feed results back for the next iteration (loop continues)
            messages.push({ role: "assistant", content: llmText || "" });
            messages.push({ role: "user", content: "Tool results:\n" + results.join("\n") + "\n\nContinue the task. If it is complete, give a short final summary without any tool blocks." });
            streamToolCalls = {};
            continue; // next iteration — the model may do more work
          }
          llmText = data.choices?.[0]?.message?.content || data.choices?.[0]?.message?.reasoning_content || "";
        } else {
          w(RD + "Unsupported provider: " + provider + RS + "\n");
          return "unsupported-provider";
        }
      } catch (err) {
        w(RD + "LLM call failed: " + (err?.message ?? String(err)) + RS + "\n");
        emitChat("status", { text: "✗ llm-call-failed" });
        emitChat("assistant", { text: "⚠ LLM call failed: " + (err?.message ?? String(err)) });
        return "llm-call-failed";
      }
      if (lastUsage) {
        try {
          native.call("reportTokens", {
            input: lastUsage.prompt_tokens || lastUsage.input_tokens || 0,
            output: lastUsage.completion_tokens || lastUsage.output_tokens || 0,
            reasoning: lastUsage.completion_tokens_details?.reasoning_tokens || 0,
            cacheRead: lastUsage.prompt_tokens_details?.cached_tokens || lastUsage.cache_read_input_tokens || 0,
            cacheWrite: lastUsage.cache_creation_input_tokens || 0,
            cost: calculateCost(lastUsage)
          }).catch(function () { /* best-effort */ });
        } catch (e) { /* token reporting is best-effort */ }
      }
      if (!llmText || !llmText.trim()) {
        w(RD + "Empty LLM response." + RS + "\n");
        emitChat("status", { text: "✗ empty-response" });
        emitChat("assistant", { text: "⚠ The model returned an empty response. Retry." });
        return "empty-response";
      }
      // Strip <think> reasoning blocks (minimax-style) before parsing tools
      llmText = llmText.replace(/<think>[\s\S]*?<\/think>/g, "").trim();
      const blocks = parseAgentBlocks(llmText);
      // Heuristic fallback: LLM output code WITHOUT fenced blocks → auto-wrap.
      if (blocks.length === 0 && looksLikeCode(llmText)) {
        const guess = guessFileName(llmText);
        blocks.push({ type: "file", path: guess, content: stripMarkdownFences(llmText) });
        w(DM + "⚠ LLM output was not fenced — auto-saving as " + guess + RS + "\n");
      }
      if (blocks.length === 0) {
        // Final answer — display and stop
        (llmText || "").split("\n").forEach(function (tl) { w(CY + "│ " + RS + tl + "\n"); }); w("\n");
        w(CY + "└─ " + RS + GN + "done " + RS + totalFiles + " file(s), " + totalCmds + " command(s)" + RS + "\n\n");
            emitChat("status", { text: "done " + totalFiles + " file(s), " + totalCmds + " command(s)" });
        return "done";
      }
      const results = [];
      for (const b of blocks) {
        try {
          var ex;
          if (b.type === "file") {
            ex = await executeAgentTool(native, "write", { path: b.path, content: b.content }, w);
          } else if (b.type === "command") {
            ex = await executeAgentTool(native, "bash", { command: b.command }, w);
          } else if (b.type === "python") {
            ex = await executeAgentTool(native, "python", { code: b.code, path: b.path }, w);
          } else if (b.type === "read") {
            ex = await executeAgentTool(native, "read", { path: b.path }, w);
          } else if (b.type === "edit") {
            ex = await executeAgentTool(native, "edit", { path: b.path, old_string: b.old_string, new_string: b.new_string, replace_all: b.replace_all }, w);
          } else if (b.type === "grep") {
            ex = await executeAgentTool(native, "grep", { pattern: b.pattern, path: b.path }, w);
          } else {
            continue;
          }
          results.push(ex.result);
          totalFiles += ex.files;
          totalCmds += ex.cmds;
        } catch (e) {
          results.push("FAILED " + b.type + ": " + (e?.message ?? e));
          w(RD + "✗ " + (b.path || b.command || b.type) + " — " + (e?.message ?? e) + RS + "\n");
        }
      }
      messages.push({ role: "assistant", content: llmText });
      messages.push({ role: "user", content: "Tool results:\n" + results.join("\n") + "\n\nContinue the task. If it is complete, give a short final summary without any tool blocks." });
    }
    w(YL + "Max iterations reached (6). Task may be incomplete." + RS + "\n");
    return "max-iterations";
  }
  function parseAgentBlocks(text) {
    const blocks = [];
    const fileRe = /```file:([^\n`]+)\n([\s\S]*?)```/g;
    const cmdRe = /```command\n([\s\S]*?)```/g;
    const pyPathRe = /```python:([^\n`]+)\n([\s\S]*?)```/g;
    const pyRunRe = /```python-run\n([\s\S]*?)```/g;
    const readRe = /```read:([^\n`]+)\s*```/g;
    const editRe = /```edit:([^\n`]+)\n([\s\S]*?)```/g;
    const grepRe = /```grep(?::([^\n`]+))?\n([\s\S]*?)```/g;
    let m;
    while ((m = fileRe.exec(text)) !== null) {
      blocks.push({ type: "file", path: m[1].trim(), content: m[2] });
    }
    while ((m = cmdRe.exec(text)) !== null) {
      blocks.push({ type: "command", command: m[1].trim() });
    }
    while ((m = pyPathRe.exec(text)) !== null) {
      var pypath = m[1].trim();
      var pybody = m[2] || "";
      if (!String(pybody).trim()) {
        blocks.push({ type: "python", path: pypath });
      } else {
        blocks.push({ type: "python", code: pybody, path: pypath });
      }
    }
    while ((m = pyRunRe.exec(text)) !== null) {
      blocks.push({ type: "python", code: m[1] });
    }
    while ((m = readRe.exec(text)) !== null) {
      blocks.push({ type: "read", path: m[1].trim() });
    }
    while ((m = editRe.exec(text)) !== null) {
      var raw = m[2] || "";
      var splitAt = raw.indexOf("\n---\n");
      var sepLen = 5;
      if (splitAt < 0) { splitAt = raw.indexOf("\n===\n"); sepLen = 5; }
      var oldS = splitAt >= 0 ? raw.slice(0, splitAt) : raw;
      var newS = splitAt >= 0 ? raw.slice(splitAt + sepLen) : "";
      var replAll = false;
      if (/^replace_all\n/.test(oldS)) { replAll = true; oldS = oldS.replace(/^replace_all\n/, ""); }
      blocks.push({ type: "edit", path: m[1].trim(), old_string: oldS, new_string: newS, replace_all: replAll });
    }
    while ((m = grepRe.exec(text)) !== null) {
      var gp = m[1] ? m[1].trim() : "";
      var body = String(m[2] || "").trim();
      var linesG = body.split("\n");
      var pat = linesG[0] || "";
      var gpth = gp || (linesG[1] || "");
      blocks.push({ type: "grep", pattern: pat, path: gpth || undefined });
    }
    return blocks;
  }
  function calculateCost(usage) {
    if (!usage) return 0;
    var input = usage.prompt_tokens || usage.input_tokens || 0;
    var output = usage.completion_tokens || usage.output_tokens || 0;
    return ((input + output) / 1000) * 1e-3;
  }
  function looksLikeCode(text) {
    return /<(!DOCTYPE\s+)?html|<head|<body|<\/?[a-z][a-z0-9-]*(\s|>)/i.test(text) ||
      /^\s*(const|let|var|function|class|import\s|export\s|document\.|window\.|addEventListener)/m.test(text) ||
      /^\s*[a-z][a-z0-9-]*\s*\{[^}]*\}/mi.test(text) && text.length > 40;
  }
  function guessFileName(text) {
    if (/<(!DOCTYPE\s+)?html|<head|<body/i.test(text)) return "index.html";
    if (/^\s*[a-z][a-z0-9-]*\s*\{/mi.test(text) && /(--[a-z-]+:|#[0-9a-f]{3,6}|[a-z-]+:\s*[a-z0-9.#%]+;)/i.test(text)) return "style.css";
    return "app.js";
  }
  function stripMarkdownFences(text) {
    return text.replace(/^```[a-z]*\s*\n?/i, "").replace(/\n?```\s*$/i, "").trim();
  }
  async function initializeOpencodeCore(config, tridentPlugin) {
    const globalAny2 = globalThis;
    const loaded = [];
    const missing = [];
    const errors = [];
    {
      const slot = FORGE_VENDOR_MODULES.opencodeConfig;
      const { mod, error } = await tryImportVendor("opencodeConfig");
      if (mod) {
        const opencodeConfig = mod.default ?? mod;
        if (opencodeConfig?.load) {
          await opencodeConfig.load({
            agents: config.disableVanillaAgents ? { trident: { default: true } } : {},
            plugins: config.plugins
          });
        }
        loaded.push(slot.repoPath);
      } else {
        missing.push({ repoPath: slot.repoPath, role: slot.role });
        errors.push(formatMissingVendorError(slot.repoPath, slot.role, error).message);
      }
    }
    {
      const slot = FORGE_VENDOR_MODULES.opencodeSession;
      const { mod, error } = await tryImportVendor("opencodeSession");
      if (mod) {
        const Session = mod.default ?? mod;
        if (Session?.create) {
          const session = await Session.create({ agent: config.defaultAgent });
          globalAny2.__forgeSession = session;
        }
        loaded.push(slot.repoPath);
      } else {
        missing.push({ repoPath: slot.repoPath, role: slot.role });
        errors.push(formatMissingVendorError(slot.repoPath, slot.role, error).message);
      }
    }
    {
      const slot = FORGE_VENDOR_MODULES.opencodeAgent;
      const { mod, error } = await tryImportVendor("opencodeAgent");
      if (mod) {
        const Agent = mod.default ?? mod;
        if (Agent?.register && tridentPlugin && !tridentPlugin.isStub) {
          await Agent.register("trident", {
            identity: FORGE_IDENTITY_SHORT,
            process: tridentPlugin.process
          });
        }
        loaded.push(slot.repoPath);
      } else {
        missing.push({ repoPath: slot.repoPath, role: slot.role });
        errors.push(formatMissingVendorError(slot.repoPath, slot.role, error).message);
      }
    }
    {
      const slot = FORGE_VENDOR_MODULES.opencodePlugin;
      const { mod, error } = await tryImportVendor("opencodePlugin");
      if (mod) {
        const Plugin = mod.default ?? mod;
        if (Plugin?.load && tridentPlugin && !tridentPlugin.isStub) {
          await Plugin.load(tridentPlugin);
        }
        loaded.push(slot.repoPath);
      } else {
        missing.push({ repoPath: slot.repoPath, role: slot.role });
        errors.push(formatMissingVendorError(slot.repoPath, slot.role, error).message);
      }
    }
    const isFull = missing.length === 0;
    let message;
    if (isFull) {
      message = "All opencode vendor modules loaded: " + loaded.join(", ");
    } else if (loaded.length === 0) {
      message = "[FORGE] agent runtime loaded";
    } else {
      message = "[FORGE] opencode core: partial vendor.\n  Loaded: " + loaded.join(", ") + "\n  Missing:\n" + missing.map((m) => `  - ${m.repoPath} (${m.role})`).join("\n") + "\n" + FORGE_VENDOR_GAP_HINT;
    }
    if (errors.length > 0 && loaded.length === 0) {
    }
    return { loaded, missing, isFull, message };
  }
  var globalAny = globalThis;
  if (globalAny.window) {
    globalAny.window.__forgeBootstrap = bootstrap;
  }
  if (globalAny.window?.__forgeNative?.autoBootstrap) {
    bootstrap().catch((err) => {
      console.error("[FORGE] Bootstrap failed:", err);
      globalAny.window?.__forgeNative?.error?.(String(err?.message ?? err));
    });
  }
  var forge_entry_default = bootstrap;
})();
