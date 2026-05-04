import net from "node:net";
import tls from "node:tls";
import { env } from "../../config/env.js";

export const emailNotConfiguredMessage =
  "Doğrulama e-postası şu anda gönderilemedi.";

function smtpConfigured(config = env) {
  return Boolean(
    config.SMTP_HOST &&
      config.SMTP_PORT &&
      config.SMTP_USER &&
      config.SMTP_PASS &&
      config.EMAIL_FROM
  );
}

function resendConfigured(config = env) {
  return Boolean(config.RESEND_API_KEY && config.EMAIL_FROM);
}

export function isEmailProviderConfigured(config = env) {
  return config.EMAIL_PROVIDER === "resend"
    ? resendConfigured(config)
    : smtpConfigured(config);
}

export function buildVerificationUrl(token, appBaseUrl = env.APP_BASE_URL) {
  const base = String(appBaseUrl || "https://enisapp.com").replace(/\/$/, "");
  return `${base}/verify-email?token=${encodeURIComponent(token)}`;
}

export function buildVerificationEmail({ token, appBaseUrl = env.APP_BASE_URL }) {
  const link = buildVerificationUrl(token, appBaseUrl);
  return {
    subject: "Enis e-posta doğrulama",
    text: [
      "Merhaba,",
      "",
      "Enis hesabını doğrulamak için bu bağlantıyı açabilirsin:",
      link,
      "",
      "Bu isteği sen başlatmadıysan bu e-postayı yok sayabilirsin."
    ].join("\n"),
    html: [
      "<p>Merhaba,</p>",
      "<p>Enis hesabını doğrulamak için aşağıdaki bağlantıyı açabilirsin:</p>",
      `<p><a href="${link}">${link}</a></p>`,
      "<p>Bu isteği sen başlatmadıysan bu e-postayı yok sayabilirsin.</p>"
    ].join("")
  };
}

function smtpCommand(socket, command, expected = /^2|^3/) {
  return new Promise((resolve, reject) => {
    const onData = (chunk) => {
      const response = chunk.toString("utf8");
      if (!expected.test(response)) {
        cleanup();
        reject(new Error(`SMTP command failed: ${response.trim()}`));
        return;
      }
      cleanup();
      resolve(response);
    };
    const onError = (error) => {
      cleanup();
      reject(error);
    };
    const cleanup = () => {
      socket.off("data", onData);
      socket.off("error", onError);
    };
    socket.once("data", onData);
    socket.once("error", onError);
    if (command) socket.write(`${command}\r\n`);
  });
}

async function sendSmtpEmail({ to, subject, text, html }, config = env) {
  const secure = Number(config.SMTP_PORT) === 465;
  const socket = secure
    ? tls.connect(Number(config.SMTP_PORT), config.SMTP_HOST)
    : net.connect(Number(config.SMTP_PORT), config.SMTP_HOST);

  try {
    await smtpCommand(socket, null);
    await smtpCommand(socket, `EHLO ${config.SMTP_HOST}`);
    await smtpCommand(socket, "AUTH LOGIN", /^3/);
    await smtpCommand(socket, Buffer.from(config.SMTP_USER).toString("base64"), /^3/);
    await smtpCommand(socket, Buffer.from(config.SMTP_PASS).toString("base64"));
    await smtpCommand(socket, `MAIL FROM:<${config.EMAIL_FROM}>`);
    await smtpCommand(socket, `RCPT TO:<${to}>`);
    await smtpCommand(socket, "DATA", /^3/);
    const boundary = `enis-${Date.now()}`;
    socket.write(
      [
        `From: ${config.EMAIL_FROM}`,
        `To: ${to}`,
        `Subject: ${subject}`,
        "MIME-Version: 1.0",
        `Content-Type: multipart/alternative; boundary="${boundary}"`,
        "",
        `--${boundary}`,
        'Content-Type: text/plain; charset="UTF-8"',
        "",
        text,
        "",
        `--${boundary}`,
        'Content-Type: text/html; charset="UTF-8"',
        "",
        html,
        "",
        `--${boundary}--`,
        "."
      ].join("\r\n") + "\r\n"
    );
    await smtpCommand(socket, null);
    await smtpCommand(socket, "QUIT");
  } finally {
    socket.end();
  }
}

async function sendResendEmail({ to, subject, text, html }, config = env) {
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${config.RESEND_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      from: config.EMAIL_FROM,
      to,
      subject,
      text,
      html
    })
  });

  if (!response.ok) {
    throw new Error(`Resend email failed: ${response.status} ${await response.text()}`);
  }
}

export async function sendVerificationEmail({
  to,
  token,
  config = env,
  transport = null
}) {
  if (!isEmailProviderConfigured(config) && !transport) {
    console.error("EMAIL_NOT_CONFIGURED");
    return {
      sent: false,
      message: emailNotConfiguredMessage
    };
  }

  const email = buildVerificationEmail({ token, appBaseUrl: config.APP_BASE_URL });
  if (transport) {
    await transport({ to, ...email });
  } else if (config.EMAIL_PROVIDER === "resend") {
    await sendResendEmail({ to, ...email }, config);
  } else {
    await sendSmtpEmail({ to, ...email }, config);
  }

  return {
    sent: true,
    message: "Doğrulama e-postası gönderildi."
  };
}
