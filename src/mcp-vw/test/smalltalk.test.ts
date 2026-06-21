import { describe, it, expect } from 'vitest';
import {
  unquoteSmalltalkString,
  splitLines,
  quoteSmalltalkStringBody,
  quoteSmalltalkString,
  isValidClassIdentifier,
  isValidNamespaceIdentifier,
  isValidSelector,
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
