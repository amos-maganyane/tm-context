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
