// preview-bootstrap.js
// Injected into the Preview WKWebView BEFORE any page script executes.
// Captures console output and uncaught errors, routes them to the Swift bridge
// via window.webkit.messageHandlers.previewConsole / previewError.
// FORGE-PREVIEW-SPEC-V1.0 §5.

(function() {
    'use strict';

    // Default readable occupancy for unstyled agent HTML (WAVE 3 t2/t3/t4
    // tiny dark-on-dark ANSWER 42). Page CSS still wins if it loads later.
    try {
        var forgePreviewDefaults = document.createElement('style');
        forgePreviewDefaults.setAttribute('data-forge-preview-defaults', '1');
        forgePreviewDefaults.textContent =
            'html,body{background:#111;color:#f5f5f5;font:22px/1.45 -apple-system,BlinkMacSystemFont,sans-serif;margin:0;padding:16px;}' +
            'p,.ans{font-size:28px;color:#7CFF9A;font-weight:600;}';
        (document.head || document.documentElement).appendChild(forgePreviewDefaults);
    } catch (e) {}

    // ---- Console capture ----
    var originalConsole = {
        log:   console.log.bind(console),
        warn:  console.warn.bind(console),
        error: console.error.bind(console),
        info:  console.info.bind(console),
        debug: console.debug.bind(console)
    };

    function sendConsole(level, args) {
        var message = Array.prototype.slice.call(args).map(function(a) {
            if (typeof a === 'object') {
                try { return JSON.stringify(a); } catch(e) { return String(a); }
            }
            return String(a);
        }).join(' ');

        // Extract source from Error stack if available
        var source = null;
        var line = null;
        for (var i = 0; i < args.length; i++) {
            if (args[i] instanceof Error && args[i].stack) {
                var match = args[i].stack.match(/at\s+.*?\(?(.*?):(\d+):(\d+)\)?/);
                if (match) {
                    source = match[1].split('/').pop();
                    line = parseInt(match[2], 10);
                }
                break;
            }
        }

        try {
            window.webkit.messageHandlers.previewConsole.postMessage({
                level: level,
                message: message,
                source: source,
                line: line
            });
        } catch(e) {
            // Bridge not available — fall through to original console
        }

        // Still call original console so DevTools (if attached) shows it
        originalConsole[level].apply(console, args);
    }

    console.log   = function() { sendConsole('log',   arguments); };
    console.warn  = function() { sendConsole('warn',  arguments); };
    console.error = function() { sendConsole('error', arguments); };
    console.info  = function() { sendConsole('info',  arguments); };
    console.debug = function() { sendConsole('debug', arguments); };

    // ---- Uncaught error capture ----
    window.addEventListener('error', function(event) {
        try {
            window.webkit.messageHandlers.previewError.postMessage({
                message: event.message || 'Unknown error',
                source: event.filename ? event.filename.split('/').pop() : null,
                line: event.lineno || null,
                stack: event.error ? event.error.stack : null
            });
        } catch(e) {}
    });

    // ---- Unhandled promise rejection capture ----
    window.addEventListener('unhandledrejection', function(event) {
        try {
            window.webkit.messageHandlers.previewError.postMessage({
                message: 'Unhandled rejection: ' + (event.reason ? event.reason.message || String(event.reason) : 'unknown'),
                source: null,
                line: null,
                stack: event.reason && event.reason.stack ? event.reason.stack : null
            });
        } catch(e) {}
    });

    // ---- FORGE Preview API (available to rendered content) ----
    window.__forgePreview = {
        // Request a file from the project sandbox (async)
        readFile: function(path) {
            return new Promise(function(resolve, reject) {
                var id = 'pvr_' + (++window.__forgePreview._cbId);
                window.__forgePreview._pending[id] = { resolve: resolve, reject: reject };
                window.webkit.messageHandlers.previewConsole.postMessage({
                    level: 'debug',
                    message: '__forgePreview.readFile(' + path + ')'
                });
                // Route through the main bridge
                window.webkit.messageHandlers.native.postMessage({
                    method: 'readFile',
                    args: { path: path },
                    callbackId: id
                });
            });
        },
        // Signal that the preview content has loaded and is interactive
        ready: function() {
            try {
                window.webkit.messageHandlers.previewConsole.postMessage({
                    level: 'info',
                    message: 'Preview content loaded'
                });
            } catch(e) {}
        },
        _cbId: 0,
        _pending: {}
    };

})();
