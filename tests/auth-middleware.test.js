import test from "node:test";
import assert from "node:assert/strict";
import { requireAuth } from "../src/middleware/auth.js";

test("auth middleware skips OPTIONS preflight", () => {
  let nextCalled = false;
  requireAuth(
    {
      method: "OPTIONS",
      get() {
        throw new Error("authorization header should not be read for OPTIONS");
      }
    },
    {},
    (error) => {
      assert.equal(error, undefined);
      nextCalled = true;
    }
  );

  assert.equal(nextCalled, true);
});
