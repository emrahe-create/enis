import test from "node:test";
import assert from "node:assert/strict";
import { allowedCorsOrigins, createApp, isCorsOriginAllowed } from "../src/app.js";

test("GET /health returns service status", async () => {
  const app = createApp();
  const layer = app._router.stack.find(
    (item) => item.route?.path === "/health" && item.route?.methods?.get
  );

  let body;
  layer.route.stack[0].handle({}, { json: (payload) => { body = payload; } });

  assert.equal(body.status, "ok");
  assert.equal(body.service, "ai-wellness-backend");
});

test("CORS allows Enis production domains", () => {
  assert.deepEqual(allowedCorsOrigins, [
    "https://enisapp.com",
    "https://www.enisapp.com",
    "https://api.enisapp.com"
  ]);

  for (const origin of allowedCorsOrigins) {
    assert.equal(isCorsOriginAllowed(origin, "production"), true);
  }

  assert.equal(isCorsOriginAllowed(undefined, "production"), true);
  assert.equal(isCorsOriginAllowed("https://example.com", "production"), false);
  assert.equal(isCorsOriginAllowed("http://localhost:3000", "development"), true);
  assert.equal(isCorsOriginAllowed("http://localhost:3000", "production"), false);
});
