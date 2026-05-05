import test from "node:test";
import assert from "node:assert/strict";
import {
  buildMvpEmailVerificationSkippedResponse,
  createEmailVerificationForUser,
  hashVerificationToken,
  loginUser,
  mvpEmailVerificationSkippedMessage,
  registerUser,
  resendVerificationEmail,
  verifyEmailToken
} from "../src/modules/auth/auth.service.js";
import { mandatorySignupConsents } from "../src/modules/legal/consent.service.js";
import {
  buildVerificationEmail,
  buildVerificationUrl,
  emailNotConfiguredMessage,
  sendVerificationEmail
} from "../src/modules/auth/email.service.js";

const smtpConfig = {
  EMAIL_PROVIDER: "smtp",
  SMTP_HOST: "smtp.example.com",
  SMTP_PORT: 465,
  SMTP_USER: "user",
  SMTP_PASS: "pass",
  EMAIL_FROM: "Enis <noreply@enisapp.com>",
  APP_BASE_URL: "https://enisapp.com"
};

const acceptedMandatoryConsents = Object.fromEntries(
  mandatorySignupConsents.map((consentType) => [consentType, true])
);

test("verification email builds the Enis app link", () => {
  const link = buildVerificationUrl("abc123", "https://enisapp.com");
  const email = buildVerificationEmail({
    token: "abc123",
    appBaseUrl: "https://enisapp.com"
  });

  assert.equal(link, "https://enisapp.com/verify-email?token=abc123");
  assert.match(email.text, /verify-email\?token=abc123/);
  assert.match(email.subject, /Enis/);
});

test("email provider not configured returns Turkish failure", async () => {
  const result = await sendVerificationEmail({
    to: "demo@enis.app",
    token: "token",
    config: { EMAIL_PROVIDER: "smtp", APP_BASE_URL: "https://enisapp.com" }
  });

  assert.equal(result.sent, false);
  assert.equal(result.message, emailNotConfiguredMessage);
});

test("register email verification sends email when SMTP configured", async () => {
  let savedHash;
  let sentTo;
  let sentSubject;
  const user = { id: "user-1", email: "demo@enis.app" };

  const result = await createEmailVerificationForUser(user, {
    token: "fixed-token",
    saveToken: async ({ tokenHash }) => {
      savedHash = tokenHash;
    },
    sendEmail: ({ to, token }) =>
      sendVerificationEmail({
        to,
        token,
        config: smtpConfig,
        transport: async (email) => {
          sentTo = email.to;
          sentSubject = email.subject;
        }
      })
  });

  assert.equal(savedHash, hashVerificationToken("fixed-token"));
  assert.equal(sentTo, "demo@enis.app");
  assert.match(sentSubject, /doğrulama/i);
  assert.equal(result.sent, true);
});

test("register returns a JWT and marks email verified for MVP", async () => {
  let createdInput;
  const result = await registerUser(
    {
      email: "demo@enis.app",
      password: "password123",
      consents: acceptedMandatoryConsents
    },
    {
      findByEmailFn: async () => null,
      createUserFn: async (input) => {
        createdInput = input;
        return {
          id: "user-1",
          email: input.email.toLowerCase(),
          email_verified: true,
          emailVerified: true,
          role: "user"
        };
      },
      ensureFreeSubscriptionFn: async () => {},
      storeConsentRecordsFn: async () => {},
      createVerification: async () => {
        throw new Error("verification should be bypassed for MVP");
      }
    }
  );

  assert.equal(createdInput.emailVerified, true);
  assert.equal(result.user.email_verified, true);
  assert.equal(typeof result.token, "string");
  assert.ok(result.token.length > 20);
  assert.deepEqual(result.emailVerification, {
    sent: false,
    skipped: true,
    email: "demo@enis.app",
    message: mvpEmailVerificationSkippedMessage
  });
});

test("login works immediately for an MVP registered user", async () => {
  const result = await loginUser(
    { email: "demo@enis.app", password: "password123" },
    {
      findByEmailFn: async () => ({
        id: "user-1",
        email: "demo@enis.app",
        password_hash: "hash",
        email_verified: true,
        email_verified_at: new Date(),
        role: "user"
      }),
      comparePassword: async () => true
    }
  );

  assert.equal(result.user.emailVerified, true);
  assert.equal(typeof result.token, "string");
  assert.ok(result.token.length > 20);
});

test("resend verification is skipped during MVP", async () => {
  const result = await resendVerificationEmail(
    { email: "demo@enis.app" },
    {
      findByEmail: async () => ({
        id: "user-1",
        email: "demo@enis.app",
        email_verified: false
      }),
      createVerification: async (user) => ({
        sent: true,
        email: user.email,
        message: "Doğrulama e-postası gönderildi."
      })
    }
  );

  assert.deepEqual(result, buildMvpEmailVerificationSkippedResponse("demo@enis.app"));
  assert.equal(result.sent, false);
  assert.equal(result.skipped, true);
  assert.equal(result.email, "demo@enis.app");
});

test("resend verification does not crash when email provider is missing", async () => {
  const result = await resendVerificationEmail(
    { email: "missing@enis.app" },
    {
      findByEmail: async () => null,
      createVerification: async () => {
        throw new Error("email provider should not be called during MVP");
      }
    }
  );

  assert.equal(result.sent, false);
  assert.equal(result.skipped, true);
  assert.equal(result.message, mvpEmailVerificationSkippedMessage);
});

test("verify email route service returns a clean Turkish message for missing token", async () => {
  await assert.rejects(
    () => verifyEmailToken({}),
    (error) => {
      assert.equal(error.status, 400);
      assert.equal(error.message, "Doğrulama bağlantısı geçersiz veya eksik.");
      return true;
    }
  );
});

test("verify token marks user email_verified true", async () => {
  const token = "fixed-token";
  const expectedHash = hashVerificationToken(token);
  let markedHash;

  const result = await verifyEmailToken(
    { token },
    {
      findByTokenHash: async (tokenHash) => {
        assert.equal(tokenHash, expectedHash);
        return { id: "user-1", email: "demo@enis.app" };
      },
      markVerified: async (tokenHash) => {
        markedHash = tokenHash;
        return {
          id: "user-1",
          email: "demo@enis.app",
          email_verified: true,
          emailVerified: true
        };
      }
    }
  );

  assert.equal(markedHash, expectedHash);
  assert.equal(result.verified, true);
  assert.equal(result.user.email_verified, true);
});
