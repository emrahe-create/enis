import test from "node:test";
import assert from "node:assert/strict";
import {
  createEmailVerificationForUser,
  hashVerificationToken,
  resendVerificationEmail,
  verifyEmailToken
} from "../src/modules/auth/auth.service.js";
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

test("resend verification works for an unverified user", async () => {
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

  assert.equal(result.sent, true);
  assert.equal(result.email, "demo@enis.app");
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
