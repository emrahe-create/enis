import test from "node:test";
import assert from "node:assert/strict";
import { buildExpertComingSoon, formatWaitlistEntry } from "../src/modules/experts/expert.service.js";

test("expert matching placeholder advertises coming soon and waitlist signup", () => {
  const response = buildExpertComingSoon({ waitlistCount: 12, specialties: ["stress", "sleep"] });

  assert.equal(response.status, "coming_soon");
  assert.equal(
    response.message,
    "Uzman eşleştirme sistemimiz çok yakında aktif olacak. Öncelikli erişim listesine katılarak ilk bilgilendirilenlerden biri olabilirsin."
  );
  assert.equal(response.matching.available, false);
  assert.equal(response.waitlist.enabled, true);
  assert.equal(response.waitlist.signupEndpoint, "/api/experts/waitlist");
  assert.deepEqual(response.matching.supportedNeeds, ["stress", "sleep"]);
});

test("waitlist formatter returns a joined status for existing entries", () => {
  const formatted = formatWaitlistEntry({
    id: "waitlist-id",
    status: "waiting",
    email: "user@example.com",
    preferred_focus: ["stress", "cbt"],
    note: "I prefer evenings.",
    created_at: "2026-05-01T00:00:00.000Z",
    updated_at: "2026-05-01T00:00:00.000Z"
  });

  assert.equal(formatted.joined, true);
  assert.equal(formatted.status, "waiting");
  assert.deepEqual(formatted.preferredFocus, ["stress", "cbt"]);
});

test("waitlist formatter returns not joined when no entry exists", () => {
  assert.deepEqual(formatWaitlistEntry(null), {
    joined: false,
    status: "not_joined"
  });
});
