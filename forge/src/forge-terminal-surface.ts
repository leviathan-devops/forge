/**
 * forge-terminal-surface.ts — Captures OpenTUI output for FORGE/iOS.
 * Per spec section 4.2.
 *
 * Routes all terminal writes to window.__forgeNative.output()
 * so the iOS native layer can render them in a UIView.
 */

import { EventEmitter } from '../shims/forge-events.js';

export interface TerminalSize {
  cols: number;
  rows: number;
}

export interface TerminalCell {
  char: string;
  fg: string | null;
  bg: string | null;
  bold: boolean;
  italic: boolean;
  underline: boolean;
  dim: boolean;
  inverse: boolean;
}

export interface WriteOptions {
  flush?: boolean;
}

export class ForgeTerminalSurface extends EventEmitter {
  private _output: string[] = [];
  private _buffer: string = '';
  private _size: TerminalSize;
  private _cursor: { x: number; y: number } = { x: 0, y: 0 };
  private _flushTimer: ReturnType<typeof setTimeout> | null = null;
  private _flushInterval: number = 16; // ~60fps
  private _cellGrid: TerminalCell[][] = [];
  private _pendingFlush: boolean = false;

  constructor(cols: number = 80, rows: number = 24) {
    super();
    this._size = { cols, rows };
    this._initCellGrid();
  }

  private _initCellGrid(): void {
    this._cellGrid = [];
    for (let y = 0; y < this._size.rows; y++) {
      const row: TerminalCell[] = [];
      for (let x = 0; x < this._size.cols; x++) {
        row.push({
          char: ' ',
          fg: null,
          bg: null,
          bold: false,
          italic: false,
          underline: false,
          dim: false,
          inverse: false,
        });
      }
      this._cellGrid.push(row);
    }
  }

  // --- Core write method ---

  write(data: string | Uint8Array, options?: WriteOptions): boolean {
    const str = typeof data === 'string' ? data : new TextDecoder().decode(data);
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

  private _scheduleFlush(): void {
    if (this._flushTimer || this._pendingFlush) return;
    this._pendingFlush = true;
    this._flushTimer = setTimeout(() => {
      this._flush();
    }, this._flushInterval);
  }

  private _flush(): void {
    if (this._flushTimer) {
      clearTimeout(this._flushTimer);
      this._flushTimer = null;
    }
    this._pendingFlush = false;

    if (this._buffer.length === 0) return;

    const native = (globalThis as any).window?.__forgeNative;
    if (native?.output) {
      native.output(this._buffer);
    }
    if (native?.renderFrame) {
      // Alternative: render the cell grid for pixel-perfect TUI
      native.renderFrame(this.getCellSnapshot());
    }

    this._buffer = '';
  }

  // --- ANSI escape processing ---

  private _processAnsi(str: string): void {
    // Track cursor position based on escape sequences
    let i = 0;
    while (i < str.length) {
      const char = str[i];

      if (char === '\x1b') {
        // ANSI escape sequence
        const next = str[i + 1];
        if (next === '[') {
          // CSI sequence
          const match = str.slice(i).match(/^\x1b\[([\d;]*)([a-zA-Z])/);
          if (match) {
            this._handleCsi(match[1], match[2]);
            i += match[0].length;
            continue;
          }
        } else if (next === ']') {
          // OSC sequence — skip
          const oscEnd = str.indexOf('\x07', i);
          const belEnd = str.indexOf('\x1b\\', i);
          const end = oscEnd !== -1 && (belEnd === -1 || oscEnd < belEnd) ? oscEnd + 1 : belEnd + 2;
          i = end > i ? end : i + 2;
          continue;
        }
        i += 2;
        continue;
      }

      if (char === '\n') {
        this._cursor.y++;
        this._cursor.x = 0;
        if (this._cursor.y >= this._size.rows) {
          this._scrollUp();
          this._cursor.y = this._size.rows - 1;
        }
      } else if (char === '\r') {
        this._cursor.x = 0;
      } else if (char === '\t') {
        this._cursor.x = Math.min(this._cursor.x + 4, this._size.cols - 1);
      } else if (char >= ' ' && char !== '\x7f') {
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

  private _handleCsi(params: string, command: string): void {
    const nums = params ? params.split(';').map((n) => parseInt(n, 10) || 0) : [];

    switch (command) {
      case 'H': // Cursor position
      case 'f':
        this._cursor.y = (nums[0] || 1) - 1;
        this._cursor.x = (nums[1] || 1) - 1;
        break;
      case 'A': // Cursor up
        this._cursor.y = Math.max(0, this._cursor.y - (nums[0] || 1));
        break;
      case 'B': // Cursor down
        this._cursor.y = Math.min(this._size.rows - 1, this._cursor.y + (nums[0] || 1));
        break;
      case 'C': // Cursor right
        this._cursor.x = Math.min(this._size.cols - 1, this._cursor.x + (nums[0] || 1));
        break;
      case 'D': // Cursor left
        this._cursor.x = Math.max(0, this._cursor.x - (nums[0] || 1));
        break;
      case 'J': // Erase display
        this._eraseDisplay(nums[0] || 0);
        break;
      case 'K': // Erase line
        this._eraseLine(nums[0] || 0);
        break;
      case 'm': // SGR (colors)
        this._handleSgr(nums);
        break;
      default:
        // Ignore unsupported sequences
        break;
    }
  }

  private _currentAttrs: TerminalCell = {
    char: ' ', fg: null, bg: null,
    bold: false, italic: false, underline: false, dim: false, inverse: false,
  };

  private _handleSgr(nums: number[]): void {
    for (let i = 0; i < nums.length; i++) {
      const n = nums[i];
      if (n === 0) {
        this._currentAttrs = { char: ' ', fg: null, bg: null, bold: false, italic: false, underline: false, dim: false, inverse: false };
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

  private _eraseDisplay(mode: number): void {
    if (mode === 2 || mode === 3) {
      this._initCellGrid();
      this._cursor = { x: 0, y: 0 };
    } else if (mode === 1) {
      for (let y = 0; y <= this._cursor.y; y++) {
        const maxX = y === this._cursor.y ? this._cursor.x : this._size.cols;
        for (let x = 0; x < maxX; x++) {
          const cell = this._cellGrid[y]?.[x];
          if (cell) { cell.char = ' '; cell.fg = null; cell.bg = null; }
        }
      }
    } else {
      for (let y = this._cursor.y; y < this._size.rows; y++) {
        const startX = y === this._cursor.y ? this._cursor.x : 0;
        for (let x = startX; x < this._size.cols; x++) {
          const cell = this._cellGrid[y]?.[x];
          if (cell) { cell.char = ' '; cell.fg = null; cell.bg = null; }
        }
      }
    }
  }

  private _eraseLine(mode: number): void {
    const row = this._cellGrid[this._cursor.y];
    if (!row) return;
    if (mode === 2) {
      for (const cell of row) { cell.char = ' '; cell.fg = null; cell.bg = null; }
    } else if (mode === 1) {
      for (let x = 0; x <= this._cursor.x && x < row.length; x++) {
        row[x].char = ' '; row[x].fg = null; row[x].bg = null;
      }
    } else {
      for (let x = this._cursor.x; x < row.length; x++) {
        row[x].char = ' '; row[x].fg = null; row[x].bg = null;
      }
    }
  }

  private _scrollUp(): void {
    this._cellGrid.shift();
    const newRow: TerminalCell[] = [];
    for (let x = 0; x < this._size.cols; x++) {
      newRow.push({
        char: ' ', fg: null, bg: null,
        bold: false, italic: false, underline: false, dim: false, inverse: false,
      });
    }
    this._cellGrid.push(newRow);
  }

  // --- Public API ---

  getCellSnapshot(): TerminalCell[][] {
    return this._cellGrid.map((row) => row.map((cell) => ({ ...cell })));
  }

  getSize(): TerminalSize {
    return { ...this._size };
  }

  getCols(): number {
    return this._size.cols;
  }

  getRows(): number {
    return this._size.rows;
  }

  resize(cols: number, rows: number): void {
    const oldGrid = this._cellGrid;
    this._size = { cols, rows };
    this._initCellGrid();

    // Copy existing content
    for (let y = 0; y < Math.min(oldGrid.length, rows); y++) {
      for (let x = 0; x < Math.min(oldGrid[y]?.length ?? 0, cols); x++) {
        const oldCell = oldGrid[y]?.[x];
        const newCell = this._cellGrid[y]?.[x];
        if (oldCell && newCell) {
          Object.assign(newCell, oldCell);
        }
      }
    }

    this.emit('resize', this._size);
    this._flush();
  }

  onResize(callback: (size: TerminalSize) => void): void {
    this.on('resize', callback);
  }

  clear(): void {
    this._initCellGrid();
    this._cursor = { x: 0, y: 0 };
    this._buffer = '';
    this._flush();
    this.emit('clear');
  }

  flush(): void {
    this._flush();
  }

  // --- Cursor position ---

  getCursorPosition(): { x: number; y: number } {
    return { ...this._cursor };
  }

  setCursorPosition(x: number, y: number): void {
    this._cursor.x = Math.max(0, Math.min(x, this._size.cols - 1));
    this._cursor.y = Math.max(0, Math.min(y, this._size.rows - 1));
  }

  // --- Input handling ---

  sendInput(input: string | Uint8Array): void {
    this.emit('input', input);
  }

  // --- Cleanup ---

  destroy(): void {
    if (this._flushTimer) {
      clearTimeout(this._flushTimer);
      this._flushTimer = null;
    }
    this._buffer = '';
    this._cellGrid = [];
    this.removeAllListeners();
  }
}

const ANSI_COLOR_MAP: string[] = [
  '#000000', '#cc0000', '#4e9a06', '#c4a000',
  '#3465a4', '#75507b', '#06989a', '#d3d7cf',
  '#555753', '#ef2929', '#8ae234', '#fce94f',
  '#729fcf', '#ad7fa8', '#34e2e2', '#eeeeec',
];

// --- Factory function ---

export function createForgeTerminalSurface(cols?: number, rows?: number): ForgeTerminalSurface {
  const native = (globalThis as any).window?.__forgeNative;
  const size = native?.getTerminalSize?.() ?? { cols: cols ?? 80, rows: rows ?? 24 };
  return new ForgeTerminalSurface(size.cols, size.rows);
}

export default ForgeTerminalSurface;
