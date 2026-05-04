import test from "node:test";
import assert from "node:assert/strict";
import { authRouter, verificationStatus } from "../src/modules/auth/auth.routes.js";
import { registerUser } from "../src/modules/auth/auth.service.js";
import { checkInRouter } from "../src/modules/checkins/checkin.routes.js";
import { chatRouter } from "../src/modules/chat/chat.routes.js";
import {
  applyAvatarNameToResponse,
  companionIdentity,
  resolveAvatarMode
} from "../src/modules/chat/chat.service.js";
import {
  buildPremiumPurchaseConsentRecords,
  buildSignupConsentRecords,
  mandatorySignupConsents
} from "../src/modules/legal/consent.service.js";
import { legalRouter } from "../src/modules/legal/legal.routes.js";
import { memoryRouter } from "../src/modules/memory/memory.routes.js";
import { getLegalDocument, listLegalDocuments } from "../src/modules/legal/legal.service.js";
import { userRouter } from "../src/modules/users/user.routes.js";

const acceptedMandatoryConsents = Object.fromEntries(
  mandatorySignupConsents.map((consentType) => [consentType, true])
);

function routeExists(router, method, path) {
  return router.stack.some((layer) => layer.route?.path === path && layer.route.methods?.[method]);
}

function handleRoute(router, method, path, { params = {} } = {}) {
  const layer = router.stack.find((item) => item.route?.path === path && item.route.methods?.[method]);
  assert.ok(layer, `Missing ${method.toUpperCase()} ${path}`);

  let body;
  layer.route.stack[0].handle({ params }, { json: (payload) => { body = payload; } });
  return body;
}

test("signup fails without mandatory consents", () => {
  assert.throws(
    () => buildSignupConsentRecords({ privacy_policy: true }),
    (error) => {
      assert.equal(error.status, 400);
      assert.ok(error.details.missing.includes("kvkk_clarification_seen"));
      assert.ok(error.details.missing.includes("terms_of_use"));
      assert.ok(error.details.missing.includes("wellness_disclaimer"));
      return true;
    }
  );
});

test("register rejects missing mandatory consents with 400 before signup", async () => {
  await assert.rejects(
    () =>
      registerUser({
        email: "missing-consents@example.com",
        password: "password123",
        consents: {
          privacy_policy: true
        }
      }),
    (error) => {
      assert.equal(error.status, 400);
      assert.equal(error.message, "Missing required consent");
      assert.ok(error.details.missing.includes("kvkk_clarification_seen"));
      assert.ok(error.details.missing.includes("terms_of_use"));
      assert.ok(error.details.missing.includes("wellness_disclaimer"));
      return true;
    }
  );
});

test("marketing consent is optional during signup", () => {
  const records = buildSignupConsentRecords(acceptedMandatoryConsents);

  assert.equal(records.some((record) => record.consentType === "marketing_permission"), false);

  const recordsWithMarketing = buildSignupConsentRecords({
    ...acceptedMandatoryConsents,
    marketing_permission: true
  });

  assert.equal(recordsWithMarketing.some((record) => record.consentType === "marketing_permission"), true);
});

test("legal endpoints return the active document version", () => {
  const expectedTitles = {
    "privacy-policy": "Gizlilik Politikası",
    "kvkk-clarification": "KVKK Aydınlatma Metni",
    "explicit-consent": "Açık Rıza Metni",
    "terms-of-use": "Kullanım Şartları",
    "distance-sales-agreement": "Mesafeli Satış Sözleşmesi",
    "cancellation-refund-policy": "İptal ve İade Politikası",
    disclaimer: "Sorumluluk Reddi",
    faq: "Sıkça Sorulan Sorular"
  };

  for (const [slug, title] of Object.entries(expectedTitles)) {
    assert.equal(routeExists(legalRouter, "get", `/${slug}`), true);
    const document = getLegalDocument(slug);
    assert.equal(document.slug, slug);
    assert.equal(document.title, title);
    assert.equal(document.version, "2026-04-29");
    assert.equal(document.company.legalName, "EQ Bilişim Teknolojileri Ltd. Şti.");
  }
});

test("legal index route returns active documents", () => {
  const body = handleRoute(legalRouter, "get", "/");

  assert.ok(Array.isArray(body.documents));
  assert.ok(body.documents.length >= 8);
  assert.ok(body.documents.some((document) => document.slug === "privacy-policy"));
});

test("generic legal slug route returns a document", () => {
  const body = handleRoute(legalRouter, "get", "/:slug", {
    params: { slug: "privacy-policy" }
  });

  assert.equal(body.slug, "privacy-policy");
  assert.equal(body.version, "2026-04-29");
  assert.equal(body.company.brand, "Enis");
});

test("legal texts contain the required wellness disclaimer", () => {
  for (const document of listLegalDocuments()) {
    assert.match(document.content, /Enis psikoterapi hizmeti değildir/i);
    assert.match(document.content, /Enis tanı, tedavi veya tıbbi yönlendirme yapmaz/i);
    assert.match(document.content, /duygusal destek ve farkındalık amaçlıdır/i);
    assert.match(document.content, /Acil durumlarda 112/i);
    assert.match(document.content, /EQ Bilişim Teknolojileri Ltd\. Şti\./i);
    assert.match(document.content, /Ümraniye \/ İstanbul \/ Türkiye/i);
  }
});

test("premium purchase requires distance sales and refund policy consent", () => {
  assert.throws(
    () => buildPremiumPurchaseConsentRecords({ distance_sales: true }),
    (error) => {
      assert.equal(error.status, 400);
      assert.deepEqual(error.details.missing, ["cancellation_refund_policy"]);
      return true;
    }
  );

  const records = buildPremiumPurchaseConsentRecords({
    distance_sales: true,
    cancellation_refund_policy: true
  });

  assert.deepEqual(
    records.map((record) => record.consentType),
    ["distance_sales", "cancellation_refund_policy"]
  );
  assert.ok(records.every((record) => record.version === "2026-04-29"));
});

test("delete account endpoint exists", () => {
  assert.equal(routeExists(userRouter, "delete", "/me"), true);
});

test("export my data endpoint exists", () => {
  assert.equal(routeExists(userRouter, "get", "/me/export"), true);
});

test("memory privacy endpoints exist", () => {
  assert.equal(routeExists(memoryRouter, "get", "/"), true);
  assert.equal(routeExists(memoryRouter, "delete", "/"), true);
});

test("daily check-in endpoints exist", () => {
  assert.equal(routeExists(checkInRouter, "post", "/"), true);
  assert.equal(routeExists(checkInRouter, "get", "/today"), true);
});

test("chat sessions endpoint exists", () => {
  assert.equal(routeExists(chatRouter, "get", "/sessions"), true);
});

test("account placeholder endpoints exist", () => {
  assert.equal(routeExists(authRouter, "post", "/forgot-password"), true);
  assert.equal(routeExists(authRouter, "post", "/email-verification"), true);
  assert.equal(routeExists(authRouter, "post", "/resend-verification"), true);
  assert.equal(routeExists(authRouter, "get", "/verify-email"), true);
  assert.equal(verificationStatus({ sent: false }), 503);
  assert.equal(verificationStatus({ sent: true }), 202);
});

test("avatarName is only used for premium or trial chat mode", () => {
  const freeResponse = applyAvatarNameToResponse({
    response: "It seems like this has been heavy. What feels most present?",
    avatarMode: resolveAvatarMode({ premium: false }),
    avatarName: "Mira"
  });
  const trialResponse = applyAvatarNameToResponse({
    response: "It seems like this has been heavy. What feels most present?",
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarName: "Mira"
  });

  assert.equal(freeResponse.avatarNameUsed, false);
  assert.equal(freeResponse.response.includes("Mira"), false);
  assert.equal(trialResponse.avatarNameUsed, true);
  assert.equal(trialResponse.response.includes("Mira"), true);
});

test("Enis identity copy is legal-safe and brand-specific", () => {
  assert.equal(
    companionIdentity.copy,
    "You are Enis, a close digital companion, not an assistant. You are not a therapist. Listen first, reflect the feeling, remember gently, and stay warm, short, human-like, and present. Do not diagnose, lecture, rush into advice, or sound like a generic wellness coach."
  );
});
