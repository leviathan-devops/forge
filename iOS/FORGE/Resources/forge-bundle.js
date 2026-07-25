/**
 * forge-bundle.js — FORGE Terminal Engine (Phase 1: Minimal)
 *
 * =============================================================================
 * MINIMAL BUNDLE — Phase 1
 * =============================================================================
 * This is a minimal, self-contained JavaScript bundle that provides a working
 * FORGE terminal experience immediately. It runs inside a hidden WKWebView
 * (ForgeEngine.swift) and communicates with Swift via the native bridge API
 * injected at document start:
 *
 *   window.__forgeNative.output(ansi)   → feed ANSI text to SwiftTerm
 *   window.__forgeNative.ready()        → signal Swift that the engine is ready
 *   window.__forgeNative.call(method, …)→ async call to a native operation
 *
 *   window.__forgeOnInput(data)         ← SwiftTerm keystrokes arrive here
 *
 * The bootstrap function `window.__forgeBootstrap()` is invoked by an inline
 * <script> tag after this file loads (see ForgeEngine.loadBundle).
 *
 * -----------------------------------------------------------------------------
 * PHASE 2 — Full Bundle
 * -----------------------------------------------------------------------------
 * The full opencode + Trident T3 Audit Engine bundle will replace this file
 * when the vendoring + esbuild pipeline is ready. That bundle will include the
 * complete opencode runtime, agent tool implementations, and the Trident
 * audit/review system. This minimal bundle exists so that the terminal has
 * immediate functionality — prompt, echo, and basic commands — from the very
 * first build. The bridge contract is identical, so the swap is transparent.
 * =============================================================================
 *
 * Architecture:
 *
 *   SwiftTerm (user types) → ForgeTerminalView → ForgeEngine.sendInput()
 *   → window.__forgeInput(escaped) → window.__forgeOnInput(data)
 *   → FORGE Terminal (this file) processes keystroke
 *   → window.__forgeNative.output(ansi) → ForgeEngine output batching
 *   → SwiftTerm.feed(text) (rendered to screen)
 *
 * @author FORGE Engineering
 * @version 1.0.0
 */

(function () {
    'use strict';

    // =========================================================================
    // Section 1: ANSI Color Helpers
    // =========================================================================

    /** ANSI SGR (Select Graphic Rendition) escape codes. */
    var ANSI = {
        RESET:   '\u001b[0m',
        BOLD:    '\u001b[1m',
        DIM:     '\u001b[2m',
        // Foreground colors
        RED:     '\u001b[31m',
        GREEN:   '\u001b[32m',
        YELLOW:  '\u001b[33m',
        BLUE:    '\u001b[34m',
        MAGENTA: '\u001b[35m',
        CYAN:    '\u001b[36m',
        WHITE:   '\u001b[37m',
        // Bright foreground colors
        BRIGHT_CYAN:  '\u001b[96m',
        BRIGHT_WHITE: '\u001b[97m',
        BRIGHT_RED:   '\u001b[91m',
        BRIGHT_GREEN: '\u001b[92m',
        BRIGHT_YELLOW:'\u001b[93m',
        BRIGHT_BLUE:  '\u001b[94m',
        // Cursor / screen
        CLEAR_SCREEN: '\u001b[2J\u001b[H',
        HIDE_CURSOR:  '\u001b[?25l',
        SHOW_CURSOR:  '\u001b[?25h',
        // Line break — terminals require \r\n (CR+LF), not just \n
        NL: '\r\n'
    };

    /**
     * Wraps text in an ANSI color and resets afterward.
     * @param {string} text  The text to colorize.
     * @param {string} color The ANSI escape code (e.g. ANSI.CYAN).
     * @returns {string} The colorized string with a reset suffix.
     */
    function color(text, ansiColor) {
        return ansiColor + text + ANSI.RESET;
    }

    // =========================================================================
    // Section 2: Output Engine
    // =========================================================================

    /**
     * Sends ANSI-formatted text to SwiftTerm via the native bridge.
     * This is the ONLY function that writes to the terminal screen.
     * All output goes through here so we have a single audit point.
     */
    function write(ansi) {
        if (window.__forgeNative && typeof window.__forgeNative.output === 'function') {
            window.__forgeNative.output(ansi);
        }
    }

    /** Writes text followed by a newline (CRLF). */
    function writeln(ansi) {
        write(ansi + ANSI.NL);
    }

    // =========================================================================
    // Section 3: Line Editor & Input Buffer
    // =========================================================================

    /**
     * The current input line being typed by the user.
     * Characters are appended as keystrokes arrive, and removed on backspace.
     * On Enter, the full line is dispatched to the command processor.
     */
    var inputBuffer = '';

    /**
     * The prompt string displayed before user input.
     * Cyan ">" + space, matching the FORGE aesthetic.
     */
    var PROMPT = color('> ', ANSI.CYAN);

    /**
     * Renders the prompt to the terminal.
     */
    function showPrompt() {
        write(PROMPT);
    }

    /**
     * Echoes a printable character to the terminal and adds it to the buffer.
     * @param {string} ch The character to echo.
     */
    function echoChar(ch) {
        write(ch);
        inputBuffer += ch;
    }

    /**
     * Handles backspace: removes the last character from the buffer and
     * visually erases it using the standard "\b \b" sequence (move cursor
     * back, overwrite with space, move cursor back again).
     */
    function handleBackspace() {
        if (inputBuffer.length === 0) return;
        inputBuffer = inputBuffer.slice(0, -1);
        write('\b \b');
    }

    /**
     * Clears the entire current input line visually and from the buffer.
     * Used by Ctrl+U. Moves the cursor back N positions, erases, then
     * resets the buffer.
     */
    function clearLine() {
        var len = inputBuffer.length;
        // Move cursor back len positions, then overwrite with spaces, then
        // move back again to the start.
        var eraseSeq = '';
        for (var i = 0; i < len; i++) {
            eraseSeq += '\b \b';
        }
        write(eraseSeq);
        inputBuffer = '';
    }

    // -------------------------------------------------------------------------
    // Command History (up/down arrow navigation)
    // -------------------------------------------------------------------------

    /**
     * Stores previously executed commands. Most recent is at the end.
     * Capped at 50 entries (FIFO — oldest is removed when full).
     * @type {string[]}
     */
    var commandHistory = [];

    /** Maximum number of commands to retain. */
    var MAX_HISTORY = 50;

    /**
     * Current navigation index into commandHistory.
     * -1 means the user is editing a fresh line (not browsing history).
     * Any other value means the user pressed Up and is viewing that entry.
     */
    var historyIndex = -1;

    /**
     * Replaces the current input line on screen with `newText`.
     * Erases the existing buffer visually, then echoes the new text and
     * sets the buffer. Used by arrow-key history navigation.
     * @param {string} newText The replacement text.
     */
    function replaceInput(newText) {
        // Erase the current input line using \b \b for each character.
        var len = inputBuffer.length;
        var eraseSeq = '';
        for (var i = 0; i < len; i++) {
            eraseSeq += '\b \b';
        }
        write(eraseSeq);
        // Set buffer and echo the new text.
        inputBuffer = newText;
        write(newText);
    }

    /**
     * Handles the Up arrow key. Navigates backward through command history.
     * If the user is on a fresh line, jumps to the most recent command.
     * If already browsing, moves one step further back.
     */
    function handleHistoryUp() {
        if (commandHistory.length === 0) return;
        if (historyIndex === -1) {
            // Start browsing from the most recent command.
            historyIndex = commandHistory.length - 1;
            replaceInput(commandHistory[historyIndex]);
        } else if (historyIndex > 0) {
            historyIndex--;
            replaceInput(commandHistory[historyIndex]);
        }
        // If historyIndex === 0, we're at the oldest — stay there.
    }

    /**
     * Handles the Down arrow key. Navigates forward through command history.
     * If at the end, restores an empty input line (exits history mode).
     */
    function handleHistoryDown() {
        if (historyIndex === -1) return; // Not browsing history.
        if (historyIndex < commandHistory.length - 1) {
            historyIndex++;
            replaceInput(commandHistory[historyIndex]);
        } else {
            // Reached the end — clear to empty input (fresh line).
            historyIndex = -1;
            replaceInput('');
        }
    }

    /**
     * Processes a completed input line when the user presses Enter.
     * Dispatches to the command processor, then shows a fresh prompt.
     */
    function processLine() {
        writeln(''); // Move to next line (echo the Enter)
        var line = inputBuffer;
        inputBuffer = '';

        var trimmed = line.trim();
        if (trimmed.length > 0) {
            // Store in command history. Skip if identical to the most recent
            // entry to avoid consecutive duplicates.
            if (commandHistory.length === 0 ||
                commandHistory[commandHistory.length - 1] !== trimmed) {
                commandHistory.push(trimmed);
                // Cap history at MAX_HISTORY entries (FIFO).
                if (commandHistory.length > MAX_HISTORY) {
                    commandHistory.shift();
                }
            }
            executeCommand(trimmed);
        }
        // Reset history navigation index for the next line.
        historyIndex = -1;
        // Show a new prompt for the next command
        showPrompt();
    }

    // =========================================================================
    // Section 4: Command Processor
    // =========================================================================

    /**
     * The registry of available commands. Each entry maps a command name to
     * a handler function. Handlers receive no arguments (the raw command line
     * is available if needed for parsing args).
     *
     * @type {Object<string, function(string): void>}
     */
    var commands = {};

    /**
     * Parses and executes a command line.
     * @param {string} line The trimmed input line.
     */
    function executeCommand(line) {
        // Split on whitespace to get the command name and arguments.
        var parts = line.split(/\s+/);
        var name = parts[0].toLowerCase();
        var args = parts.slice(1).join(' ');

        if (commands.hasOwnProperty(name)) {
            commands[name](args, line);
        } else {
            writeln(
                color('Unknown command: ', ANSI.RED) +
                color(line, ANSI.WHITE) +
                color('. Type ', ANSI.DIM) +
                color('help', ANSI.CYAN) +
                color(' for available commands.', ANSI.DIM)
            );
        }
    }

    // -------------------------------------------------------------------------
    // Command: help
    // -------------------------------------------------------------------------

    commands['help'] = function () {
        writeln('');
        writeln(color('═══════════════════════════════════════════', ANSI.CYAN));
        writeln(color('  FORGE — Available Commands', ANSI.BRIGHT_CYAN + ANSI.BOLD));
        writeln(color('═══════════════════════════════════════════', ANSI.CYAN));
        writeln('');

        // Pad the command name to a fixed column width for alignment.
        // We pad the PLAIN text first, then color it, so the escape codes
        // don't skew the visible alignment.
        var cmds = [
            ['help',    'Show this help message'],
            ['status',  'Show system status'],
            ['version', 'Show FORGE version info'],
            ['clear',   'Clear the terminal screen']
        ];
        for (var i = 0; i < cmds.length; i++) {
            writeln('  ' + color(pad(cmds[i][0], 12), ANSI.CYAN) + cmds[i][1]);
        }

        writeln('');
        writeln(color('  Tip: ', ANSI.YELLOW) +
                color('↑/↓', ANSI.CYAN) +
                color(' arrows cycle through command history', ANSI.DIM));
        writeln(color('  More commands will be available when the', ANSI.DIM));
        writeln(color('  full Trident T3 engine bundle is loaded.', ANSI.DIM));
        writeln('');
    };

    // -------------------------------------------------------------------------
    // Command: status
    // -------------------------------------------------------------------------

    commands['status'] = function () {
        writeln('');
        writeln(color('─── FORGE System Status ───', ANSI.CYAN));
        writeln('');

        // Engine status
        writeln('  ' + pad_label('Engine')    + color('● ONLINE', ANSI.GREEN));

        // Display (terminal dimensions)
        var cols = window.__forgeCols || 80;
        var rows = window.__forgeRows || 24;
        writeln('  ' + pad_label('Display')   +
               cols + 'x' + rows + ' ' + color('(SwiftTerm)', ANSI.DIM));

        // API configuration
        var config = window.__forgeConfig || {};
        var provider = config.provider || 'anthropic';
        var model = config.model || 'claude-sonnet-4-20250514';
        var hasKey = config.apiKey && config.apiKey.length > 0;

        writeln('  ' + pad_label('Provider')  + provider);
        writeln('  ' + pad_label('Model')     + model);
        writeln('  ' + pad_label('API Key')   +
               (hasKey ? color('● Configured', ANSI.GREEN)
                       : color('○ Not set', ANSI.YELLOW)));

        // Audio / KVM (placeholders — not available in minimal bundle)
        writeln('  ' + pad_label('Audio')     + color('○ N/A', ANSI.DIM));
        writeln('  ' + pad_label('KVM')       + color('○ N/A', ANSI.DIM));

        // Bundle phase
        writeln('  ' + pad_label('Bundle')    +
               color('Phase 1 (Minimal)', ANSI.YELLOW));
        writeln('');
    };

    // -------------------------------------------------------------------------
    // Command: version
    // -------------------------------------------------------------------------

    commands['version'] = function () {
        writeln('');
        writeln(color('FORGE', ANSI.BRIGHT_CYAN + ANSI.BOLD) + ' v1.0.0');
        writeln(color('Trident T3 Audit Engine', ANSI.CYAN) + ' — Phase 1 Bundle');
        writeln('');
        writeln('  ' + color('Runtime: ',  ANSI.DIM) + 'WKWebView (WebKit)');
        writeln('  ' + color('Terminal: ', ANSI.DIM) + 'SwiftTerm (Metal GPU)');
        writeln('  ' + color('Bridge: ',   ANSI.DIM) + 'window.__forgeNative');
        writeln('  ' + color('Platform: ', ANSI.DIM) + 'iOS 17.0+');
        writeln('');
        writeln(color('Full opencode + Trident bundle pending esbuild pipeline.', ANSI.DIM));
        writeln('');
    };

    // -------------------------------------------------------------------------
    // Command: clear
    // -------------------------------------------------------------------------

    commands['clear'] = function () {
        // Clear the screen and reset cursor to home.
        write(ANSI.CLEAR_SCREEN);
        // Show a compact banner so the user still sees the FORGE identity.
        // NOTE: Do NOT call showPrompt() here — processLine() will show the
        // prompt after this handler returns. Calling it twice would produce
        // a double prompt.
        writeln(color('FORGE v1.0.0', ANSI.BRIGHT_CYAN + ANSI.BOLD) +
                ' — ' +
                color('Trident T3 Audit Engine', ANSI.CYAN));
        writeln('');
    };

    // =========================================================================
    // Section 5: Welcome Banner
    // =========================================================================

    /**
     * Outputs the FORGE welcome banner with ANSI colors.
     * @param {boolean} compact If true, shows a shorter banner (used after clear).
     */
    function showBanner(compact) {
        if (compact) {
            writeln(color('FORGE v1.0.0', ANSI.BRIGHT_CYAN + ANSI.BOLD) +
                    ' — ' +
                    color('Trident T3 Audit Engine', ANSI.CYAN));
            writeln('');
            return;
        }

        writeln('');
        writeln(color('  ███████╗ ██████╗  ██████╗██╗██╗', ANSI.BRIGHT_CYAN));
        writeln(color('  ██╔════╝██╔═══██╗██╔════╝██║██║', ANSI.CYAN));
        writeln(color('  █████╗  ██║   ██║██║     ██║██║', ANSI.CYAN));
        writeln(color('  ██╔══╝  ██║   ██║██║     ╚═╝╚═╝', ANSI.CYAN));
        writeln(color('  ██║     ╚██████╔╝╚██████╗██╗██╗', ANSI.BRIGHT_CYAN));
        writeln(color('  ╚═╝      ╚═════╝  ╚═════╝╚═╝╚═╝', ANSI.DIM));
        writeln('');
        writeln(color('  FORGE v1.0.0', ANSI.BRIGHT_CYAN + ANSI.BOLD) +
                ' — ' +
                color('Trident T3 Audit Engine', ANSI.WHITE));
        writeln(color('  Phase 1: Minimal Terminal Bundle', ANSI.YELLOW));
        writeln('');

        // Config status
        var config = window.__forgeConfig || {};
        var hasKey = config.apiKey && config.apiKey.length > 0;
        if (hasKey) {
            writeln('  ' + color('✓', ANSI.GREEN) +
                    ' API Key: ' + color('Configured', ANSI.GREEN) +
                    ' (' + (config.provider || 'anthropic') + ')');
        } else {
            writeln('  ' + color('⚠', ANSI.YELLOW) +
                    ' API Key: ' + color('Not configured', ANSI.YELLOW));
            writeln('  ' + color('  Open Settings (gear icon) to configure.', ANSI.DIM));
        }

        writeln('');
        writeln('  ' + color('Type ', ANSI.WHITE) +
                color('help', ANSI.CYAN) +
                color(' for available commands.', ANSI.WHITE));
        writeln('');
        writeln(color('  Ready.', ANSI.GREEN));
        writeln('');
    }

    // =========================================================================
    // Section 6: Input Handler
    // =========================================================================

    /**
     * The main input handler invoked by Swift when the user types in SwiftTerm.
     *
     * SwiftTerm keystrokes arrive as strings via:
     *   window.__forgeInput(data) → window.__forgeOnInput(data)
     *
     * The `data` string contains the raw character(s) typed:
     *   - '\r' (0x0D)        → Enter / Return
     *   - '\n' (0x0A)        → Line feed (treat as Enter)
     *   - '\x7f' (127)       → Delete key (backspace)
     *   - '\b' (0x08)        → Backspace (alternate)
     *   - '\x03' (3)         → Ctrl+C (cancel current line)
     *   - '\x15' (21)        → Ctrl+U (clear line)
     *   - '\u001b[A'         → Up arrow (previous command in history)
     *   - '\u001b[B'         → Down arrow (next command in history)
     *   - printable chars    → regular characters (echo and buffer)
     *   - escape sequences   → arrow keys handled; others ignored
     *
     * @param {string} data The raw keystroke data from SwiftTerm.
     */
    window.__forgeOnInput = function (data) {
        if (typeof data !== 'string' || data.length === 0) return;

        // Process each character in the data string (SwiftTerm may batch
        // multiple keystrokes in a single send, e.g. during paste).
        for (var i = 0; i < data.length; i++) {
            var ch = data[i];
            var code = data.charCodeAt(i);

            if (code === 0x1B) {
                // Escape sequence — check for arrow keys: ESC [ A/B/C/D.
                // Arrow keys arrive as 3-byte sequences: \u001b[A (up),
                // \u001b[B (down), \u001b[C (right), \u001b[D (left).
                if (i + 2 < data.length && data.charCodeAt(i + 1) === 0x5B) {
                    var arrowCode = data.charCodeAt(i + 2);
                    if (arrowCode === 0x41) {
                        // Up arrow → navigate backward through command history
                        handleHistoryUp();
                    } else if (arrowCode === 0x42) {
                        // Down arrow → navigate forward through command history
                        handleHistoryDown();
                    }
                    // C (right) and D (left) not handled in Phase 1.
                    // Skip the rest of the escape sequence (3 chars total).
                    i += 2;
                    continue;
                }
                // Lone ESC or unrecognized escape sequence — skip silently.
                continue;

            } else if (code === 0x0D || code === 0x0A) {
                // Enter / Return / Line feed → process the command line
                processLine();

            } else if (code === 0x7F || code === 0x08) {
                // Delete (0x7F) or Backspace (0x08) → erase last char
                handleBackspace();

            } else if (code === 0x03) {
                // Ctrl+C → cancel current line (SIGINT-style)
                writeln(color('^C', ANSI.RED));
                inputBuffer = '';
                showPrompt();

            } else if (code === 0x15) {
                // Ctrl+U → clear the entire line
                clearLine();

            } else if (code >= 0x20 && code !== 0x7F) {
                // Printable character (0x20–0x7E, plus any UTF-8 multibyte
                // which has code >= 0x80) → echo and buffer
                echoChar(ch);

            }
            // else: other control characters (0x00–0x1F) are silently ignored.
        }
    };

    // =========================================================================
    // Section 7: Terminal Dimensions & Resize
    // =========================================================================

    /** Default terminal dimensions (will be updated by Swift on first resize). */
    window.__forgeCols = window.__forgeCols || 80;
    window.__forgeRows = window.__forgeRows || 24;

    /**
     * Called by Swift (ForgeEngine.sendResize) when the terminal's visible
     * dimensions change. In the full bundle, this triggers a re-layout of
     * the TUI. In Phase 1, we just store the new dimensions.
     *
     * @param {number} cols New column count.
     * @param {number} rows New row count.
     */
    window.__forgeResizeCallback = function (cols, rows) {
        window.__forgeCols = cols;
        window.__forgeRows = rows;
    };

    // =========================================================================
    // Section 8: Lifecycle Hooks (Pause / Resume)
    // =========================================================================

    /**
     * Called by Swift when the app enters the background.
     * In the full bundle, this pauses the God Loop and saves state.
     * Phase 1: no-op (the engine has no background work).
     */
    window.__forgePause = function () {
        // No background work in Phase 1 — nothing to pause.
    };

    /**
     * Called by Swift when the app returns to the foreground.
     * In the full bundle, this resumes the God Loop.
     * Phase 1: no-op.
     */
    window.__forgeResume = function () {
        // No background work in Phase 1 — nothing to resume.
    };

    // =========================================================================
    // Section 9: Bootstrap
    // =========================================================================

    /**
     * The bootstrap entry point. Called by an inline <script> tag after this
     * file loads (see ForgeEngine.loadBundle):
     *
     *   <script src="forge-bundle.js"></script>
     *   <script>window.__forgeBootstrap();</script>
     *
     * This function:
     *   1. Clears the terminal (remove any placeholder content from Swift).
     *   2. Renders the welcome banner.
     *   3. Shows the initial prompt.
     *   4. Signals Swift that the engine is ready (__forgeNative.ready()).
     */
    window.__forgeBootstrap = function () {
        // Clear any placeholder text that Swift may have fed to SwiftTerm
        // before the bundle loaded (see BuildOnDeviceScreen.feedPlaceholder).
        write(ANSI.CLEAR_SCREEN);

        // Render the full welcome banner.
        showBanner(false);

        // Show the first interactive prompt.
        showPrompt();

        // Signal Swift that the JS engine has finished bootstrapping.
        // This triggers ForgeEngine.readyHandler, which hides the loading
        // spinner and injects API credentials.
        if (window.__forgeNative && typeof window.__forgeNative.ready === 'function') {
            window.__forgeNative.ready();
        }
    };

    // =========================================================================
    // Section 10: Utility Functions
    // =========================================================================

    /**
     * Pads a string to a fixed width with spaces (right-padded).
     * Used for aligning command help and status output.
     * @param {string} str The string to pad.
     * @param {number} len The target length.
     * @returns {string} The padded string.
     */
    function pad(str, len) {
        var result = str;
        while (result.length < len) result += ' ';
        return result;
    }

    /**
     * Convenience: pads a label and wraps it in cyan for status output.
     * @param {string} label The label text.
     * @returns {string} Cyan-colored, padded label.
     */
    function pad_label(label) {
        return color(pad(label + ':', 12), ANSI.CYAN);
    }

})();
