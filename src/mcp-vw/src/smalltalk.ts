/**
 * smalltalk.ts — helpers for emitting Smalltalk + parsing /eval result strings.
 *
 * The bridge /eval endpoint returns {ok, result, error} where `result` is the
 * Smalltalk printString of the evaluated expression. For a String result,
 * printString is the SINGLE-QUOTED form with embedded apostrophes doubled.
 * These helpers wrap that round-trip cleanly.
 *
 * **Carry-forward #43 (session-22 discovery)**: the bridge JSON-encoder
 * COLLAPSES every ASCII whitespace control char (LF=0x0A, CR=0x0D, TAB=0x09)
 * to a single SPACE (0x20) in the response body. Verified byte-by-byte against
 * the live bridge. **Implication for probes**: do NOT use LF/CR/TAB as
 * record separators in any String we build via WriteStream + `s contents`.
 * Use non-whitespace separators like `;` or `|` instead.
 */

/**
 * Carry-forward #43 separators used by all list-returning tools.
 * - `RECORD_SEP` = ';' separates records (rows of a tabular result)
 * - `FIELD_SEP`  = '|' separates fields within a record (column delimiter)
 *
 * Both are safe inside Smalltalk class names, namespaces, and selectors
 * (which never contain `;` or `|`).
 */
export const RECORD_SEP = ';';
export const FIELD_SEP = '|';

/**
 * Strip Smalltalk-style single-quote string wrapper if present + unescape
 * doubled apostrophes (`''` → `'`).
 *
 * Examples:
 *   `'foo'`            → `foo`
 *   `'don''t panic'`   → `don't panic`
 *   `not a string`     → `not a string` (returned as-is)
 *   `''`               → `` (empty string)
 *
 * Use to convert the `result` field from POST /eval back into the raw
 * String content that the Smalltalk probe constructed via WriteStream.
 */
export function unquoteSmalltalkString(s: string): string {
  if (s.length < 2) return s;
  if (s.startsWith("'") && s.endsWith("'")) {
    return s.slice(1, -1).replaceAll("''", "'");
  }
  return s;
}

/**
 * Split a string on a chosen separator + drop trailing empty entries
 * (Smalltalk probes always end with a final separator).
 *
 * Use with `RECORD_SEP` (= ';') for records emitted by WriteStream-based probes.
 */
export function splitOn(s: string, sep: string): string[] {
  const parts = s.split(sep);
  while (parts.length > 0 && parts[parts.length - 1] === '') {
    parts.pop();
  }
  return parts;
}

/**
 * Legacy line-splitter (kept for any future probe that genuinely sends LF-delimited
 * content — currently UNUSED in MVP because of carry-forward #43).
 */
export function splitLines(s: string): string[] {
  const lines = s.split(/\r?\n/);
  while (lines.length > 0 && lines[lines.length - 1] === '') {
    lines.pop();
  }
  return lines;
}

/**
 * Escape a JavaScript string for inclusion as a Smalltalk string literal body.
 * Doubles every single-quote and returns the inner content (no wrapping quotes).
 *
 * Use:
 *   const src = `Smalltalk at: #'${quoteSmalltalkStringBody(name)}'`;
 */
export function quoteSmalltalkStringBody(s: string): string {
  return s.replaceAll("'", "''");
}

/**
 * Wrap a JavaScript string as a complete Smalltalk string literal.
 * Includes the wrapping single quotes.
 */
export function quoteSmalltalkString(s: string): string {
  return `'${quoteSmalltalkStringBody(s)}'`;
}

/**
 * Validate a Smalltalk class identifier. Accepts:
 *   - "Customer"             (single segment, starts uppercase)
 *   - "MyApp.Customer"       (namespace-qualified, dot-separated)
 *   - "VWB.VWBridge"         (any number of segments)
 *
 * Each segment must start with an uppercase ASCII letter, followed by
 * [A-Za-z0-9_]+. This keeps generated Smalltalk safe — no injection of
 * apostrophes, semicolons, or other syntactic surprises.
 */
const CLASS_ID_RE = /^[A-Z][A-Za-z0-9_]*(?:\.[A-Z][A-Za-z0-9_]*)*$/;

export function isValidClassIdentifier(s: string): boolean {
  return CLASS_ID_RE.test(s);
}

/**
 * Validate a Smalltalk namespace identifier. Single-segment uppercase identifier.
 * (Multi-segment namespaces exist in stock VW but not in this MAS image — flat namespaces only.)
 */
const NAMESPACE_ID_RE = /^[A-Z][A-Za-z0-9_]*$/;

export function isValidNamespaceIdentifier(s: string): boolean {
  return NAMESPACE_ID_RE.test(s);
}

/**
 * Validate a Smalltalk selector. Supports:
 *   - Unary:    "foo"
 *   - Binary:   "+", "-", "=", "<="  (max 2 chars, special chars only)
 *   - Keyword:  "at:", "at:put:", "ensure:"
 *
 * Reject anything else to keep emitted Smalltalk safe.
 */
const UNARY_SELECTOR_RE = /^[a-z_][A-Za-z0-9_]*$/;
const BINARY_SELECTOR_RE = /^[+\-*/~<>=@%|&?,!]{1,4}$/;
const KEYWORD_SELECTOR_RE = /^(?:[a-z_][A-Za-z0-9_]*:)+$/;

export function isValidSelector(s: string): boolean {
  return (
    UNARY_SELECTOR_RE.test(s) ||
    BINARY_SELECTOR_RE.test(s) ||
    KEYWORD_SELECTOR_RE.test(s)
  );
}

// -----------------------------------------------------------------------------
// validateParenBalance — pre-flight paren-balance check (s23 Bug 7 fix)
// -----------------------------------------------------------------------------

/**
 * Result of a paren-balance walk over Smalltalk source.
 *
 * - `balanced` — true when every `(` has a matching `)` AND no `)` ever
 *   closed before its matching `(`.
 * - `opens` / `closes` — total counts (informational; useful for the agent
 *   to verify the helper actually walked the source).
 * - `firstUnmatchedCloseLine` / `Column` — only set when a `)` was found
 *   outside any open group. 1-based.
 * - `hint` — human-readable summary suitable for embedding in an MCP error
 *   message. Already formatted for KEY: VALUE display.
 */
export interface ParenBalanceResult {
  balanced: boolean;
  opens: number;
  closes: number;
  firstUnmatchedCloseLine?: number;
  firstUnmatchedCloseColumn?: number;
  hint?: string;
}

/**
 * Walk a Smalltalk source string and report paren balance. Skips:
 *   - String literals `'...'` (with `''` escape for inner apostrophe)
 *   - Character literals `$X` (the char after `$` is always literal)
 *   - Multi-line comments `"..."`
 *
 * Rationale (s23 Bug 7): VW's compiler returns
 * `'Syntax error: array element or right parenthesis expected -> '` on an
 * unbalanced literal array with NO line/column info — debugging requires
 * manual bisection. This helper runs in JS BEFORE the bridge round-trip,
 * so when the AI hand-crafts a windowSpec literal and miscounts a paren,
 * the rejection comes back with `delta=N missing ')'` and a line/column
 * hint at the offending close (when applicable). Cheap (~µs), high
 * diagnostic value.
 *
 * Limitations:
 *   - Does NOT validate that the source IS a complete Smalltalk expression
 *     (a half-written method body can still be paren-balanced and pass).
 *   - Does NOT validate other syntax (missing periods, unbalanced `[]`,
 *     etc.). Bridge still does final compile-check.
 */
export function validateParenBalance(source: string): ParenBalanceResult {
  let opens = 0;
  let closes = 0;
  let depth = 0;
  let firstUnmatchedClosePos = -1;
  let inString = false;
  let inComment = false;
  let line = 1;
  let column = 1;
  let unmatchedLine = 0;
  let unmatchedColumn = 0;

  const len = source.length;
  let i = 0;
  while (i < len) {
    const c = source[i] as string;

    // Track line/col for the slice we're about to consume.
    const isNewline = c === '\n';

    if (inString) {
      if (c === "'") {
        // Check for '' (escaped apostrophe inside string)
        if (i + 1 < len && source[i + 1] === "'") {
          i += 2;
          column += 2;
          continue;
        }
        inString = false;
      }
      i++;
      if (isNewline) { line++; column = 1; } else { column++; }
      continue;
    }

    if (inComment) {
      if (c === '"') {
        inComment = false;
      }
      i++;
      if (isNewline) { line++; column = 1; } else { column++; }
      continue;
    }

    // Outside string/comment context.
    if (c === "'") {
      inString = true;
      i++;
      column++;
      continue;
    }
    if (c === '"') {
      inComment = true;
      i++;
      column++;
      continue;
    }
    if (c === '$') {
      // Character literal — the NEXT char is the literal value regardless
      // of what it is (including `(`, `)`, `'`, `"`, etc.). Skip 2 chars.
      i += 2;
      column += 2;
      continue;
    }
    if (c === '(') {
      opens++;
      depth++;
      i++;
      column++;
      continue;
    }
    if (c === ')') {
      closes++;
      depth--;
      if (depth < 0 && firstUnmatchedClosePos === -1) {
        firstUnmatchedClosePos = i;
        unmatchedLine = line;
        unmatchedColumn = column;
      }
      i++;
      column++;
      continue;
    }

    // Plain char — advance position tracking.
    i++;
    if (isNewline) { line++; column = 1; } else { column++; }
  }

  const balanced = opens === closes && firstUnmatchedClosePos === -1;
  if (balanced) {
    return { balanced: true, opens, closes };
  }

  // Build hint.
  const delta = opens - closes;
  let hint: string;
  if (delta > 0 && firstUnmatchedClosePos === -1) {
    const word = delta === 1 ? 'paren' : 'parens';
    hint = `${delta} missing close ${word} — likely at end of source`;
  } else if (delta < 0) {
    hint = `${-delta} extra close paren(s) — first unmatched ')' at line ${unmatchedLine} column ${unmatchedColumn}`;
  } else {
    // delta === 0 but a close went negative earlier → mis-nested.
    hint = `parens count matches but mis-nested — first ')' that closed too early at line ${unmatchedLine} column ${unmatchedColumn}`;
  }

  const result: ParenBalanceResult = { balanced: false, opens, closes, hint };
  if (firstUnmatchedClosePos !== -1) {
    result.firstUnmatchedCloseLine = unmatchedLine;
    result.firstUnmatchedCloseColumn = unmatchedColumn;
  }
  return result;
}

/**
 * Convenience: format a `ParenBalanceResult` (when imbalanced) as a
 * KEY: VALUE block suitable for embedding in an MCP error message. Format
 * matches the s23 cookbook style — agent-readable, no JSON parse needed.
 */
export function formatParenBalanceError(toolName: string, source: string, r: ParenBalanceResult): string {
  if (r.balanced) {
    // Should never be called for the balanced case — but be defensive.
    return `${toolName}: paren-balance check passed (opens=${r.opens}, closes=${r.closes}).`;
  }
  const lines: string[] = [];
  lines.push(`${toolName}: source has unbalanced parentheses — refused before sending to bridge.`);
  lines.push(`opens-count: ${r.opens}`);
  lines.push(`closes-count: ${r.closes}`);
  lines.push(`delta: ${r.opens - r.closes}`);
  if (r.firstUnmatchedCloseLine !== undefined && r.firstUnmatchedCloseColumn !== undefined) {
    lines.push(`first-unmatched-close: line ${r.firstUnmatchedCloseLine} column ${r.firstUnmatchedCloseColumn}`);
  }
  if (r.hint) {
    lines.push(`hint: ${r.hint}`);
  }
  // Source preview — last ~80 chars to show the trailing context where most
  // miscounts surface in hand-crafted windowSpec literals.
  const preview = source.length > 80 ? '...' + source.slice(-80) : source;
  lines.push(`source-tail: ${preview.replace(/\r?\n/g, ' \\n ')}`);
  lines.push(`rationale: VW's bridge syntax-error message lacks line/column — pre-parse check prevents the bisection-only debug loop (s23 Bug 7).`);
  return lines.join('\n');
}
