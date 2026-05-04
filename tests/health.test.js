import test from "node:test";
import assert from "node:assert/strict";
import { allowedCorsOrigins, corsOptions, createApp, isCorsOriginAllowed, optionsPreflightBypass } from "../src/app.js";

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

test("GET /api/health and dev debug route are registered", async () => {
  const app = createApp();
  const health = app._router.stack.find(
    (item) => item.route?.path === "/api/health" && item.route?.methods?.get
  );
  const debug = app._router.stack.find(
    (item) => item.route?.path === "/api/debug/last-response" && item.route?.methods?.get
  );

  assert.ok(health);
  assert.ok(debug);
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
  assert.equal(isCorsOriginAllowed("http://localhost:3000", "production"), true);
  assert.equal(isCorsOriginAllowed("http://127.0.0.1:5173", "production"), true);
  assert.deepEqual(corsOptions.methods, ["GET", "POST", "PATCH", "DELETE", "OPTIONS"]);
  assert.deepEqual(corsOptions.allowedHeaders, ["Content-Type", "Authorization"]);
});

test("CORS callback allows Flutter web localhost and logs blocked origins", async () => {
  const allowed = await new Promise((resolve, reject) => {
    corsOptions.origin("http://localhost:54321", (error, result) => {
      if (error) return reject(error);
      return resolve(result);
    });
  });

  assert.equal(allowed, true);

  const originalWarn = console.warn;
  const logs = [];
  console.warn = (message) => logs.push(message);
  try {
    const blocked = await new Promise((resolve) => {
      corsOptions.origin("https://blocked.example", (error, result) => {
        resolve({ error, result });
      });
    });

    assert.equal(blocked.result, undefined);
    assert.equal(blocked.error.status, 403);
    assert.equal(blocked.error.message, "CORS blocked origin: https://blocked.example");
    assert.deepEqual(logs, ["CORS_BLOCKED_ORIGIN=https://blocked.example"]);
  } finally {
    console.warn = originalWarn;
  }
});

test("global OPTIONS route is registered before API routers", () => {
  const app = createApp();
  const optionsMiddlewareIndex = app._router.stack.findIndex(
    (item) => item.handle?.name === "optionsPreflightBypass"
  );
  const optionsRouteIndex = app._router.stack.findIndex(
    (item) => item.route?.path === "*" && item.route?.methods?.options
  );
  const authRouterIndex = app._router.stack.findIndex(
    (item) => String(item.regexp).includes("\\/api\\/auth")
  );

  assert.ok(optionsMiddlewareIndex > -1);
  assert.ok(optionsRouteIndex > -1);
  assert.ok(authRouterIndex > -1);
  assert.ok(optionsRouteIndex < optionsMiddlewareIndex);
  assert.ok(optionsMiddlewareIndex < authRouterIndex);
  assert.ok(optionsRouteIndex < authRouterIndex);
});

test("OPTIONS /api/chat/message returns 204 before auth middleware", () => {
  const req = {
    method: "OPTIONS",
    url: "/api/chat/message",
    headers: { origin: "http://localhost:5173" }
  };
  const res = {
    statusCode: null,
    ended: false,
    status(status) {
      this.statusCode = status;
      return this;
    },
    end() {
      this.ended = true;
      return this;
    }
  };
  let nextCalled = false;

  optionsPreflightBypass(req, res, () => {
    nextCalled = true;
  });

  assert.equal(res.statusCode, 204);
  assert.equal(res.ended, true);
  assert.equal(nextCalled, false);
});
