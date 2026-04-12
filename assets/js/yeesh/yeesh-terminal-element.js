/**
 * YeeshTerminal - LiveView hook wrapping xterm.js
 *
 * Provides a full terminal experience in the browser with:
 * - Local line editing (cursor, backspace, delete, home/end)
 * - Command submission on Enter
 * - Tab completion
 * - History navigation (up/down arrows, Ctrl+P/N, Shift+Ctrl+P/N)
 * - Reverse incremental search (Ctrl+R)
 * - Clipboard: Shift+Ctrl+C (copy), Shift+Ctrl+V (paste), Shift+Ctrl+X (cut)
 * - Ctrl+C (interrupt), Ctrl+L (clear)
 *
 * Communicates with Yeesh.Live.TerminalComponent via pushEvent/handleEvent.
 */

import { LitElement, html} from 'lit';
import { customElement, property} from 'lit/decorators.js';

import { Terminal } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";
import { WebLinksAddon } from "@xterm/addon-web-links";
import { createHook } from "phoenix_live_view";

const THEMES = {
  default: {
    background: "#1e1e2e",
    foreground: "#cdd6f4",
    cursor: "#f5e0dc",
    selectionBackground: "#585b70",
    black: "#45475a",
    red: "#f38ba8",
    green: "#a6e3a1",
    yellow: "#f9e2af",
    blue: "#89b4fa",
    magenta: "#f5c2e7",
    cyan: "#94e2d5",
    white: "#bac2de",
    brightBlack: "#585b70",
    brightRed: "#f38ba8",
    brightGreen: "#a6e3a1",
    brightYellow: "#f9e2af",
    brightBlue: "#89b4fa",
    brightMagenta: "#f5c2e7",
    brightCyan: "#94e2d5",
    brightWhite: "#a6adc8",
  },
  light: {
    background: "#eff1f5",
    foreground: "#4c4f69",
    cursor: "#dc8a78",
    selectionBackground: "#acb0be",
    black: "#5c5f77",
    red: "#d20f39",
    green: "#40a02b",
    yellow: "#df8e1d",
    blue: "#1e66f5",
    magenta: "#ea76cb",
    cyan: "#179299",
    white: "#bcc0cc",
  },
};

@customElement( 'yeesh-terminal')
export default class YeeshTerminalElement extends LitElement {
  @property({ type: String}) accessor welcome = "Welcome";
  @property({ type: String}) accessor prompt = "$ ";
  @property({ type: Array}) accessor commands = [];
  @property({ type: String, attribute: 'theme'}) accessor themeName = "default";
  @property({ type: String, attribute: 'resize-event'}) accessor resizeEvent = null;

  inputBuffer = "";
  cursorPos = 0;

  // Reverse-i-search state
  searchMode = false;
  searchQuery = "";
  searchSkip = 0;
  searchMatch = "";
  savedInputBuffer = "";
  savedCursorPos = 0;

  // Prefix-filtered history navigation (fish-style)
  historyPrefix = null;

  #theme = null;

  // Callbacks

  // light DOM
  createRenderRoot() {
    return this;
  }

  connectedCallback() {
    super.connectedCallback();
    this.#initTheme();
    this.#initHook();
  }

  firstUpdated( changed) {
    super.firstUpdated( changed);
    this.#initTerm();
    this.#initStyle();
  }

  disconnectedCallback() {
    super.disconnectedCallback();
    this.#deinitTerm();
  }

  // Initializers, deinitialziers

  #initTheme() {
    this.#theme = THEMES[ this.themeName] || THEMES.default;
  }

  #initHook() {
    const mounted = () => {
      this.hook.js().ignoreAttributes( this, [ 'style']);
      listenServerEvents( this);
    };

    this.hook = createHook( this, { mounted });
  }

  #initStyle() {
    Object.assign( this.style, {
      display: 'block',
      width: '100%',
      height: '100%',
      background: this.#theme.background
    });
  }

  #initTerm() {
    this.term = new Terminal({
      theme: this.#theme,
      fontFamily: "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
      fontSize: 14,
      lineHeight: 1.2,
      cursorBlink: true,
      cursorStyle: "bar",
      scrollback: 5000,
      allowProposedApi: true,
    });

    this.fitAddon = new FitAddon();
    this.term.loadAddon( this.fitAddon);
    this.term.loadAddon( new WebLinksAddon());
    this.term.open( this);
    this.fitAddon.fit();

    this.term.writeln( this.welcome);
    this.writePrompt();

    this.term.attachCustomKeyEventHandler( this.#interceptKeys);
    this.term.onKey( this.#handleKey);

    // Fit terminal on resize
    this.resizeObserver = new ResizeObserver(() => {
      this.fitAddon.fit();
      this.#maybeNotifyResize();
    });
    this.resizeObserver.observe( this);
  }

  #deinitTerm() {
    this.resizeObserver?.disconnect();
    this.term?.dispose();
  }

  #interceptKeys = e => interceptKeys( e, this);

  #handleKey = opts => handleKey( opts, this);

  #maybeNotifyResize() {
    const { resizeEvent} = this;
    if( !resizeEvent) return;

    const xterm = this.querySelector( '.xterm-screen');
    if( !xterm) return;

    this.dispatchEvent( new CustomEvent( resizeEvent, {
      detail: {
        width: xterm.offsetWidth,
        height: xterm.offsetHeight
      },
      bubbles: true,
      cancelable: true
    }));
  }

  // Utility methods

  writePrompt() {
    this.term.write(this.prompt);
  }

  clearInput() {
    // Move to start of input, then clear to end of line
    if (this.cursorPos > 0) {
      this.term.write("\b".repeat(this.cursorPos));
    }
    this.term.write("\x1b[K");
    this.inputBuffer = "";
    this.cursorPos = 0;
  }

  enterSearchMode() {
    this.searchMode = true;
    this.searchQuery = "";
    this.searchSkip = 0;
    this.searchMatch = "";
    this.savedInputBuffer = this.inputBuffer;
    this.savedCursorPos = this.cursorPos;
    this.renderSearchLine();
  }

  exitSearchMode(accept) {
    this.searchMode = false;
    // Clear entire line
    this.term.write("\r\x1b[K");

    if (accept && this.searchMatch) {
      this.inputBuffer = this.searchMatch;
      this.cursorPos = this.searchMatch.length;
    } else {
      this.inputBuffer = this.savedInputBuffer;
      this.cursorPos = this.savedCursorPos;
    }

    this.writePrompt();
    this.term.write(this.inputBuffer);
    // Reposition cursor if not at end
    const trail = this.inputBuffer.length - this.cursorPos;
    if (trail > 0) {
      this.term.write("\x1b[" + trail + "D");
    }
  }

  renderSearchLine() {
    this.term.write("\r\x1b[K");
    const label = "(reverse-i-search)'" + this.searchQuery + "': ";
    this.term.write(label + this.searchMatch);

    // Keep inputBuffer in sync so Enter can submit immediately
    if (this.searchMatch) {
      this.inputBuffer = this.searchMatch;
      this.cursorPos = this.searchMatch.length;
    }
  }

  /**
   * Insert text at the current cursor position (used by paste).
   * Newlines are collapsed to spaces; control characters are stripped.
   */
  pasteText(text) {
    if (!text) return;

    if (this.searchMode) {
      this.searchQuery += text.replace(/[\r\n]+/g, " ").replace(/[\x00-\x1f\x7f]/g, "");
      this.searchSkip = 0;
      if (this.searchQuery.length > 0) {
        this.hook.pushEventTo(this, "yeesh:history_search", {
          query: this.searchQuery,
          skip: 0,
        });
      } else {
        this.searchMatch = "";
        this.renderSearchLine();
      }
      return;
    }

    const sanitized = text
      .replace(/[\r\n]+/g, " ")
      .replace(/[\x00-\x1f\x7f]/g, "");
    if (!sanitized) return;

    const before = this.inputBuffer.slice(0, this.cursorPos);
    const after = this.inputBuffer.slice(this.cursorPos);
    this.inputBuffer = before + sanitized + after;
    this.cursorPos += sanitized.length;
    this.historyPrefix = null;

    if (after.length > 0) {
      this.term.write(sanitized + after + "\b".repeat(after.length));
    } else {
      this.term.write(sanitized);
    }
  }
}

function listenServerEvents( host) {
  const { hook} = host;

  hook.handleEvent("yeesh:output", ({ output }) => {
    if (output && output.length > 0) {
      // Convert \n to \r\n for xterm
      const formatted = output.replace(/(?<!\r)\n/g, "\r\n");
      host.term.writeln(formatted);
    }
    host.writePrompt();
  });

  hook.handleEvent("yeesh:prompt", ({ prompt }) => {
    host.prompt = prompt;
  });

  hook.handleEvent("yeesh:completion", ({ matches, replacement }) => {
    if (matches.length > 1) {
      // Show all matches
      host.term.writeln("");
      host.term.writeln(matches.join("  "));
      host.writePrompt();
      host.inputBuffer = replacement;
      host.cursorPos = replacement.length;
      host.term.write(replacement);
    } else {
      // Single match or common prefix - replace input
      host.clearInput();
      host.inputBuffer = replacement;
      host.cursorPos = replacement.length;
      host.term.write(replacement);
    }
  });

  hook.handleEvent("yeesh:history", ({ entry }) => {
    host.clearInput();
    if (entry === "" && host.historyPrefix !== null) {
      // Navigated past newest match: restore original typed input
      const restored = host.historyPrefix;
      host.historyPrefix = null;
      host.inputBuffer = restored;
      host.cursorPos = restored.length;
      host.term.write(restored);
    } else {
      host.inputBuffer = entry;
      host.cursorPos = entry.length;
      host.term.write(entry);
    }
  });

  hook.handleEvent("yeesh:search_result", ({ entry, found }) => {
    if (host.searchMode) {
      host.searchMatch = found ? entry : "";
      host.renderSearchLine();
    }
  });
}

// Intercept keys before xterm processes them.
// Handles arrow history navigation, Ctrl+R search, and Ctrl+P/N.
function interceptKeys( event, host) {
  if (event.type !== "keydown") return true;

  // --- Shift+Ctrl+C / V / X: clipboard operations ---
  if (event.ctrlKey && event.shiftKey) {
    if (event.key === "C") {
      event.preventDefault();
      const sel = host.term.getSelection();
      if (sel) {
        navigator.clipboard.writeText(sel);
        host.term.clearSelection();
      }
      return false;
    }
    if (event.key === "V") {
      event.preventDefault();
      navigator.clipboard.readText().then((text) => host.pasteText(text));
      return false;
    }
    if (event.key === "X") {
      event.preventDefault();
      const sel = host.term.getSelection();
      if (sel) {
        navigator.clipboard.writeText(sel);
        host.term.clearSelection();
      }
      return false;
    }
    // Shift+Ctrl+P / N: history prev/next (browser-safe alternative)
    if (event.key === "P") {
      event.preventDefault();
      if (host.searchMode) host.exitSearchMode(true);
      if (host.historyPrefix === null)
        host.historyPrefix = host.inputBuffer;
      host.hook.pushEventTo(host, "yeesh:history_prev", {
        prefix: host.historyPrefix,
      });
      return false;
    }
    if (event.key === "N") {
      event.preventDefault();
      if (host.searchMode) host.exitSearchMode(true);
      if (host.historyPrefix === null)
        host.historyPrefix = host.inputBuffer;
      host.hook.pushEventTo(host, "yeesh:history_next", {
        prefix: host.historyPrefix,
      });
      return false;
    }
  }

  // --- Ctrl+R: enter or cycle reverse-i-search ---
  if (event.ctrlKey && event.key === "r") {
    event.preventDefault();
    if (!host.searchMode) {
      host.enterSearchMode();
    } else {
      host.searchSkip++;
      host.hook.pushEventTo(host, "yeesh:history_search", {
        query: host.searchQuery,
        skip: host.searchSkip,
      });
    }
    return false;
  }

  // --- Ctrl+P / Ctrl+N: history prev/next (also exits search) ---
  if (event.ctrlKey && event.key === "p") {
    event.preventDefault();
    if (host.searchMode) host.exitSearchMode(true);
    if (host.historyPrefix === null) host.historyPrefix = host.inputBuffer;
    host.hook.pushEventTo(host, "yeesh:history_prev", {
      prefix: host.historyPrefix,
    });
    return false;
  }
  if (event.ctrlKey && event.key === "n") {
    event.preventDefault();
    if (host.searchMode) host.exitSearchMode(true);
    if (host.historyPrefix === null) host.historyPrefix = host.inputBuffer;
    host.hook.pushEventTo(host, "yeesh:history_next", {
      prefix: host.historyPrefix,
    });
    return false;
  }

  // --- When in search mode, consume all keys here ---
  if (host.searchMode) {
    event.preventDefault();

    // Escape / Ctrl+G: cancel search, restore original input
    if (event.key === "Escape" || (event.ctrlKey && event.key === "g")) {
      host.exitSearchMode(false);
      return false;
    }

    // Enter: accept match and execute
    if (event.key === "Enter") {
      host.exitSearchMode(true);
      host.term.writeln("");
      const input = host.inputBuffer;
      host.inputBuffer = "";
      host.cursorPos = 0;
      host.historyPrefix = null;
      if (input.trim().length > 0) {
        host.hook.pushEventTo(host, "yeesh:input", { input });
      } else {
        host.writePrompt();
      }
      return false;
    }

    // Tab / ArrowRight / ArrowLeft: accept match, stay on line
    if (
      event.key === "Tab" ||
      event.key === "ArrowRight" ||
      event.key === "ArrowLeft"
    ) {
      host.exitSearchMode(true);
      return false;
    }

    // Ctrl+C: cancel search + interrupt
    if (event.ctrlKey && event.key === "c") {
      host.exitSearchMode(false);
      host.term.write("^C\r\n");
      host.inputBuffer = "";
      host.cursorPos = 0;
      host.historyPrefix = null;
      host.hook.pushEventTo(host, "yeesh:interrupt", {});
      host.writePrompt();
      return false;
    }

    // Backspace: shorten query
    if (event.key === "Backspace") {
      if (host.searchQuery.length > 0) {
        host.searchQuery = host.searchQuery.slice(0, -1);
        host.searchSkip = 0;
        if (host.searchQuery.length > 0) {
          host.hook.pushEventTo(host, "yeesh:history_search", {
            query: host.searchQuery,
            skip: 0,
          });
        } else {
          host.searchMatch = "";
          host.renderSearchLine();
        }
      } else {
        // Empty query + backspace exits search
        host.exitSearchMode(false);
      }
      return false;
    }

    // Printable character: append to search query
    if (
      !event.ctrlKey &&
      !event.altKey &&
      !event.metaKey &&
      event.key.length === 1
    ) {
      host.searchQuery += event.key;
      host.searchSkip = 0;
      host.hook.pushEventTo(host, "yeesh:history_search", {
        query: host.searchQuery,
        skip: 0,
      });
      return false;
    }

    // Consume everything else while in search mode
    return false;
  }

  // --- Normal mode: arrow key history navigation ---
  if (event.key === "ArrowUp") {
    if (host.historyPrefix === null) host.historyPrefix = host.inputBuffer;
    host.hook.pushEventTo(host, "yeesh:history_prev", {
      prefix: host.historyPrefix,
    });
    return false;
  }
  if (event.key === "ArrowDown") {
    if (host.historyPrefix === null) host.historyPrefix = host.inputBuffer;
    host.hook.pushEventTo(host, "yeesh:history_next", {
      prefix: host.historyPrefix,
    });
    return false;
  }

  return true;
}

function handleKey({ key, domEvent}, host) {
  const ev = domEvent;
  const printable =
    !ev.altKey && !ev.ctrlKey && !ev.metaKey && ev.key.length === 1;

  // Any input-modifying key resets prefix-filtered history navigation
  const resetsPrefix =
    printable ||
    ev.key === "Enter" ||
    ev.key === "Backspace" ||
    ev.key === "Delete" ||
    (ev.ctrlKey && ev.key === "c");
  if (resetsPrefix) {
    host.historyPrefix = null;
  }

  // Ctrl+C - interrupt
  if (ev.ctrlKey && ev.key === "c") {
    host.term.write("^C\r\n");
    host.inputBuffer = "";
    host.cursorPos = 0;
    host.hook.pushEventTo(host, "yeesh:interrupt", {});
    host.writePrompt();
    return;
  }

  // Ctrl+L - clear screen (preserves current line)
  if (ev.ctrlKey && ev.key === "l") {
    host.term.clear();
    return;
  }

  // Enter - submit
  if (ev.key === "Enter") {
    host.term.writeln("");
    const input = host.inputBuffer;
    host.inputBuffer = "";
    host.cursorPos = 0;

    if (input.trim().length > 0) {
      host.hook.pushEventTo(host, "yeesh:input", { input });
    } else {
      host.writePrompt();
    }
    return;
  }

  // Tab - completion
  if (ev.key === "Tab") {
    ev.preventDefault();
    host.hook.pushEventTo(host, "yeesh:complete", {
      input: host.inputBuffer,
      cursor: host.cursorPos,
    });
    return;
  }

  // Backspace
  if (ev.key === "Backspace") {
    if (host.cursorPos > 0) {
      const before = host.inputBuffer.slice(0, host.cursorPos - 1);
      const after = host.inputBuffer.slice(host.cursorPos);
      host.inputBuffer = before + after;
      host.cursorPos--;
      // Move cursor back, rewrite rest, clear trailing char
      host.term.write(
        "\b" + after + " " + "\b".repeat(after.length + 1)
      );
    }
    return;
  }

  // Delete
  if (ev.key === "Delete") {
    if (host.cursorPos < host.inputBuffer.length) {
      const before = host.inputBuffer.slice(0, host.cursorPos);
      const after = host.inputBuffer.slice(host.cursorPos + 1);
      host.inputBuffer = before + after;
      host.term.write(after + " " + "\b".repeat(after.length + 1));
    }
    return;
  }

  // Arrow Up/Down are handled by attachCustomKeyEventHandler above
  // to ensure reliable interception across xterm.js versions.

  // Arrow Left
  if (ev.key === "ArrowLeft") {
    if (host.cursorPos > 0) {
      host.cursorPos--;
      host.term.write(key);
    }
    return;
  }

  // Arrow Right
  if (ev.key === "ArrowRight") {
    if (host.cursorPos < host.inputBuffer.length) {
      host.cursorPos++;
      host.term.write(key);
    }
    return;
  }

  // Home
  if (ev.key === "Home") {
    if (host.cursorPos > 0) {
      host.term.write("\x1b[" + host.cursorPos + "D");
      host.cursorPos = 0;
    }
    return;
  }

  // End
  if (ev.key === "End") {
    const remaining = host.inputBuffer.length - host.cursorPos;
    if (remaining > 0) {
      host.term.write("\x1b[" + remaining + "C");
      host.cursorPos = host.inputBuffer.length;
    }
    return;
  }

  // Printable character
  if (printable) {
    const before = host.inputBuffer.slice(0, host.cursorPos);
    const after = host.inputBuffer.slice(host.cursorPos);
    host.inputBuffer = before + ev.key + after;
    host.cursorPos++;

    if (after.length > 0) {
      // Insert mode: write char + rest, then move cursor back
      host.term.write(ev.key + after + "\b".repeat(after.length));
    } else {
      host.term.write(ev.key);
    }
  }
}
