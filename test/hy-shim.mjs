import assert from 'node:assert/strict';
export { describe, it, before, after, beforeEach, afterEach } from 'node:test';

export function expect(actual) {
  const self = {
    assertEqual: (e) => assert.strictEqual(actual, e),
    assertNotEqual: (e) => assert.notStrictEqual(actual, e),
    assertTrue: () => assert.ok(actual === true || Boolean(actual)),
    assertFalse: () => assert.ok(!actual),
    assertUndefined: () => assert.strictEqual(actual, undefined),
    assertContain: (s) => assert.ok(String(actual).includes(String(s))),
    assertLargerThan: (n) => assert.ok(actual > n),
  };
  const neg = {
    assertEqual: (e) => assert.notStrictEqual(actual, e),
    assertNotEqual: (e) => assert.strictEqual(actual, e),
    assertUndefined: () => assert.notStrictEqual(actual, undefined),
    assertTrue: () => assert.ok(!actual),
    assertFalse: () => assert.ok(!!actual),
    assertContain: (s) => assert.ok(!String(actual).includes(String(s))),
  };
  self.not = () => neg;
  return self;
}
