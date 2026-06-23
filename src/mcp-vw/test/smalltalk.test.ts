import { describe, it, expect } from 'vitest';
import {
  unquoteSmalltalkString,
  splitLines,
  quoteSmalltalkStringBody,
  quoteSmalltalkString,
  isValidClassIdentifier,
  isValidNamespaceIdentifier,
  isValidSelector,
  validateParenBalance,
  formatParenBalanceError,
} from '../src/smalltalk.js';

describe('unquoteSmalltalkString', () => {
  it("strips wrapping quotes: 'foo' → foo", () => {
    expect(unquoteSmalltalkString("'foo'")).toBe('foo');
  });

  it("unescapes doubled apostrophes: 'don''t' → don't", () => {
    expect(unquoteSmalltalkString("'don''t'")).toBe("don't");
  });

  it('returns empty string for empty quoted', () => {
    expect(unquoteSmalltalkString("''")).toBe('');
  });

  it('returns input unchanged if not quoted', () => {
    expect(unquoteSmalltalkString('not quoted')).toBe('not quoted');
    expect(unquoteSmalltalkString('#aSymbol')).toBe('#aSymbol');
    expect(unquoteSmalltalkString('42')).toBe('42');
  });

  it('handles strings under 2 chars', () => {
    expect(unquoteSmalltalkString('')).toBe('');
    expect(unquoteSmalltalkString("'")).toBe("'");
  });

  it('preserves embedded newlines', () => {
    expect(unquoteSmalltalkString("'a\nb\nc'")).toBe('a\nb\nc');
  });
});

describe('splitLines', () => {
  it('splits on \\n', () => {
    expect(splitLines('a\nb\nc')).toEqual(['a', 'b', 'c']);
  });

  it('drops trailing empty (final newline)', () => {
    expect(splitLines('a\nb\n')).toEqual(['a', 'b']);
  });

  it('drops multiple trailing empties', () => {
    expect(splitLines('a\n\n\n')).toEqual(['a']);
  });

  it('handles \\r\\n line endings', () => {
    expect(splitLines('a\r\nb\r\nc')).toEqual(['a', 'b', 'c']);
  });

  it('returns empty array for empty input', () => {
    expect(splitLines('')).toEqual([]);
  });

  it('preserves interior empties', () => {
    expect(splitLines('a\n\nb')).toEqual(['a', '', 'b']);
  });
});

describe('quoteSmalltalkStringBody / quoteSmalltalkString', () => {
  it('doubles apostrophes in body', () => {
    expect(quoteSmalltalkStringBody("don't")).toBe("don''t");
  });

  it('wraps with single quotes for full literal', () => {
    expect(quoteSmalltalkString('foo')).toBe("'foo'");
    expect(quoteSmalltalkString("don't")).toBe("'don''t'");
  });

  it('handles empty', () => {
    expect(quoteSmalltalkString('')).toBe("''");
  });
});

describe('isValidClassIdentifier', () => {
  it('accepts single-segment uppercase identifiers', () => {
    expect(isValidClassIdentifier('Customer')).toBe(true);
    expect(isValidClassIdentifier('MyClass')).toBe(true);
    expect(isValidClassIdentifier('Foo_Bar123')).toBe(true);
  });

  it('accepts namespace-qualified identifiers', () => {
    expect(isValidClassIdentifier('VWB.VWBridge')).toBe(true);
    expect(isValidClassIdentifier('Tools.UIPainter')).toBe(true);
    expect(isValidClassIdentifier('Smalltalk.Core.WriteStream')).toBe(true);
  });

  it('rejects lowercase start', () => {
    expect(isValidClassIdentifier('customer')).toBe(false);
  });

  it('rejects special chars', () => {
    expect(isValidClassIdentifier("Cls'injection")).toBe(false);
    expect(isValidClassIdentifier('Cls;injection')).toBe(false);
    expect(isValidClassIdentifier('Cls injection')).toBe(false);
    expect(isValidClassIdentifier('Cls!')).toBe(false);
  });

  it('rejects empty', () => {
    expect(isValidClassIdentifier('')).toBe(false);
  });

  it('rejects dotted segment starting lowercase', () => {
    expect(isValidClassIdentifier('Tools.customer')).toBe(false);
  });
});

describe('isValidNamespaceIdentifier', () => {
  it('accepts single-segment uppercase', () => {
    expect(isValidNamespaceIdentifier('Tools')).toBe(true);
    expect(isValidNamespaceIdentifier('UI')).toBe(true);
    expect(isValidNamespaceIdentifier('VWB')).toBe(true);
  });

  it('rejects dotted (namespaces are flat in this image)', () => {
    expect(isValidNamespaceIdentifier('Smalltalk.Core')).toBe(false);
  });

  it('rejects lowercase start', () => {
    expect(isValidNamespaceIdentifier('tools')).toBe(false);
  });
});

describe('isValidSelector', () => {
  it('accepts unary selectors', () => {
    expect(isValidSelector('foo')).toBe(true);
    expect(isValidSelector('size')).toBe(true);
    expect(isValidSelector('isEmpty')).toBe(true);
  });

  it('accepts binary selectors', () => {
    expect(isValidSelector('+')).toBe(true);
    expect(isValidSelector('==')).toBe(true);
    expect(isValidSelector('<=')).toBe(true);
    expect(isValidSelector('->')).toBe(true);
  });

  it('accepts keyword selectors', () => {
    expect(isValidSelector('at:')).toBe(true);
    expect(isValidSelector('at:put:')).toBe(true);
    expect(isValidSelector('ifTrue:ifFalse:')).toBe(true);
  });

  it('rejects malformed', () => {
    expect(isValidSelector('')).toBe(false);
    expect(isValidSelector('Foo')).toBe(false); // capital start
    expect(isValidSelector('foo bar')).toBe(false);
    expect(isValidSelector("foo'injection")).toBe(false);
    expect(isValidSelector('foo:bar')).toBe(false); // colon mid-selector
  });
});

// -----------------------------------------------------------------------------
// validateParenBalance — s23 Bug 7 pre-flight check
// -----------------------------------------------------------------------------

describe('validateParenBalance — balanced cases', () => {
  it('empty source is balanced (no parens)', () => {
    const r = validateParenBalance('');
    expect(r.balanced).toBe(true);
    expect(r.opens).toBe(0);
    expect(r.closes).toBe(0);
  });

  it('source with no parens is balanced', () => {
    const r = validateParenBalance('foo bar baz');
    expect(r.balanced).toBe(true);
  });

  it('balanced single pair', () => {
    const r = validateParenBalance('(1 + 2)');
    expect(r.balanced).toBe(true);
    expect(r.opens).toBe(1);
    expect(r.closes).toBe(1);
  });

  it('balanced nested', () => {
    const r = validateParenBalance('((1 + 2) * (3 + 4))');
    expect(r.balanced).toBe(true);
    expect(r.opens).toBe(3);
    expect(r.closes).toBe(3);
  });

  it('balanced windowSpec literal-array form', () => {
    const src = `windowSpec
    ^#(#{UI.FullSpec}
        #window: #(#{UI.WindowSpec}
            #label: 'My Window'
            #bounds: #(#{Graphics.Rectangle} 0 0 400 300))
        #component: #(#{UI.SpecCollection}
            #collection: #()))`;
    const r = validateParenBalance(src);
    expect(r.balanced).toBe(true);
  });
});

describe('validateParenBalance — under-closed cases (missing close)', () => {
  it('reports 1 missing close at end of source', () => {
    const r = validateParenBalance('(1 + 2');
    expect(r.balanced).toBe(false);
    expect(r.opens).toBe(1);
    expect(r.closes).toBe(0);
    expect(r.hint).toMatch(/1 missing close/i);
    expect(r.hint).toMatch(/end of source/i);
    expect(r.firstUnmatchedCloseLine).toBeUndefined();
  });

  it('reports N missing closes plural', () => {
    const r = validateParenBalance('((((');
    expect(r.balanced).toBe(false);
    expect(r.opens).toBe(4);
    expect(r.closes).toBe(0);
    expect(r.hint).toMatch(/4 missing close parens/i);
  });

  it('catches s23 Bug 7 repro: literal array 2 opens 1 close', () => {
    const src = `bug7ProbeUnbalanced
    ^#(#(#{Graphics.Rectangle} 0 0 100 100)`;
    const r = validateParenBalance(src);
    expect(r.balanced).toBe(false);
    expect(r.opens).toBe(2);
    expect(r.closes).toBe(1);
  });
});

describe('validateParenBalance — over-closed cases (extra close)', () => {
  it('reports first unmatched close with line + column', () => {
    const r = validateParenBalance('1 + 2)');
    expect(r.balanced).toBe(false);
    expect(r.opens).toBe(0);
    expect(r.closes).toBe(1);
    expect(r.hint).toMatch(/extra close/i);
    expect(r.firstUnmatchedCloseLine).toBe(1);
    expect(r.firstUnmatchedCloseColumn).toBe(6);
  });

  it('tracks line+col across multiline sources', () => {
    const src = 'line1\nline2\n) extra';
    const r = validateParenBalance(src);
    expect(r.balanced).toBe(false);
    expect(r.firstUnmatchedCloseLine).toBe(3);
    expect(r.firstUnmatchedCloseColumn).toBe(1);
  });
});

describe('validateParenBalance — mis-nested same count', () => {
  it('detects )( as imbalanced even though opens === closes', () => {
    const r = validateParenBalance(')(');
    expect(r.balanced).toBe(false);
    expect(r.opens).toBe(1);
    expect(r.closes).toBe(1);
    expect(r.hint).toMatch(/mis-nested/i);
  });
});

describe('validateParenBalance — lexical context skipping', () => {
  it('ignores parens inside string literals', () => {
    const r = validateParenBalance(`'foo (bar) baz'`);
    expect(r.balanced).toBe(true);
    expect(r.opens).toBe(0);
    expect(r.closes).toBe(0);
  });

  it("handles escaped quote ('''') inside string", () => {
    // 'don''t (panic)' — the doubled '' is the escape, so the string runs through.
    // No parens outside the string.
    const r = validateParenBalance(`'don''t (panic)'`);
    expect(r.balanced).toBe(true);
    expect(r.opens).toBe(0);
  });

  it('ignores parens inside multi-line comments', () => {
    const r = validateParenBalance(`"this is a (comment) with (parens)" (real)`);
    expect(r.balanced).toBe(true);
    expect(r.opens).toBe(1);
    expect(r.closes).toBe(1);
  });

  it('treats char-literal $( as a single character (not an open paren)', () => {
    // Source: $( $) ()
    // The $( and $) are character literals — skip 2 chars each.
    // The trailing () is real.
    const r = validateParenBalance(`$( $) ()`);
    expect(r.balanced).toBe(true);
    expect(r.opens).toBe(1);
    expect(r.closes).toBe(1);
  });

  it('handles char-literal $( without any real paren following', () => {
    const r = validateParenBalance(`$(`);
    expect(r.balanced).toBe(true);
    expect(r.opens).toBe(0);
    expect(r.closes).toBe(0);
  });

  it('handles mixed string + comment + char + real parens', () => {
    // String contains "(": skip. Comment contains ")": skip.
    // $( is char literal: skip. () is real: balanced.
    const r = validateParenBalance(`'left(' "right)" $( ()`);
    expect(r.balanced).toBe(true);
    expect(r.opens).toBe(1);
    expect(r.closes).toBe(1);
  });
});

describe('formatParenBalanceError', () => {
  it('emits KEY: VALUE structure for unbalanced source', () => {
    const r = validateParenBalance('(1 + 2');
    const out = formatParenBalanceError('vw_compile_method', '(1 + 2', r);
    expect(out).toMatch(/vw_compile_method/);
    expect(out).toMatch(/opens-count: 1/);
    expect(out).toMatch(/closes-count: 0/);
    expect(out).toMatch(/delta: 1/);
    expect(out).toMatch(/hint:/);
    expect(out).toMatch(/source-tail:/);
    expect(out).toMatch(/s23 Bug 7/i);
  });

  it('includes line+col for over-closed', () => {
    const r = validateParenBalance('foo)');
    const out = formatParenBalanceError('vw_eval', 'foo)', r);
    expect(out).toMatch(/first-unmatched-close: line 1 column 4/);
  });

  it('replaces newlines in source-tail with visible markers', () => {
    const src = 'abc\ndef\n(';
    const r = validateParenBalance(src);
    const out = formatParenBalanceError('vw_compile_method', src, r);
    expect(out).toMatch(/source-tail:.*\\n/);
  });
});
