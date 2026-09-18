import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { applyUpdate } from "./updates.ts";

describe("applyUpdate", () => {
  describe("through a list element", () => {
    const state = { items: [{ a: 1 }, { a: 2 }, { a: 3 }] };

    it("sets a field on any element, first and last included", () => {
      assert.deepEqual(applyUpdate(state, [0, ["items", 0, "a"], 10]), {
        items: [{ a: 10 }, { a: 2 }, { a: 3 }],
      });
      assert.deepEqual(applyUpdate(state, [0, ["items", 1, "a"], 20]), {
        items: [{ a: 1 }, { a: 20 }, { a: 3 }],
      });
      assert.deepEqual(applyUpdate(state, [0, ["items", 2, "a"], 30]), {
        items: [{ a: 1 }, { a: 2 }, { a: 30 }],
      });
    });

    it("unsets a key and merges into an element", () => {
      assert.deepEqual(applyUpdate(state, [1, ["items", 1], "a"]), {
        items: [{ a: 1 }, {}, { a: 3 }],
      });
      assert.deepEqual(applyUpdate(state, [4, ["items", 1], { b: 2 }]), {
        items: [{ a: 1 }, { a: 2, b: 2 }, { a: 3 }],
      });
    });

    it("leaves the other elements and the original untouched", () => {
      const updated = applyUpdate(state, [0, ["items", 1, "a"], 20]);
      assert.equal(updated.items[0], state.items[0]);
      assert.equal(updated.items[2], state.items[2]);
      assert.deepEqual(state.items[1], { a: 2 });
    });

    it("rejects an index past the end, or before the start", () => {
      assert.throws(
        () => applyUpdate(state, [0, ["items", 3, "a"], 40]),
        /index out of range/,
      );
      assert.throws(
        () => applyUpdate(state, [0, ["items", -1, "a"], 40]),
        /index out of range/,
      );
    });

    it("expects a list at a numeric key", () => {
      assert.throws(
        () => applyUpdate({ items: { a: 1 } }, [0, ["items", 0, "a"], 1]),
        /expected array/,
      );
    });
  });

  describe("on a list", () => {
    const state = { items: [1, 2, 4] };

    it("inserts at an index, or appends", () => {
      assert.deepEqual(applyUpdate(state, [2, ["items"], 2, [3]]), {
        items: [1, 2, 3, 4],
      });
      assert.deepEqual(applyUpdate(state, [2, ["items"], null, [5, 6]]), {
        items: [1, 2, 4, 5, 6],
      });
    });

    it("deletes a range", () => {
      assert.deepEqual(applyUpdate(state, [3, ["items"], 0, 2]), {
        items: [4],
      });
    });
  });

  describe("on an object", () => {
    it("sets, unsets and merges, creating missing objects on the way", () => {
      assert.deepEqual(applyUpdate({}, [0, ["a", "b"], 1]), { a: { b: 1 } });
      assert.deepEqual(applyUpdate({ a: { b: 1, c: 2 } }, [1, ["a"], "b"]), {
        a: { c: 2 },
      });
      assert.deepEqual(applyUpdate({ a: { b: 1 } }, [4, ["a"], { c: 2 }]), {
        a: { b: 1, c: 2 },
      });
    });
  });
});
