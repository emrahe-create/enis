import bcrypt from "bcryptjs";
import crypto from "node:crypto";
import { ApiError } from "../../utils/http.js";
import { signToken } from "../../middleware/auth.js";
import {
  createUser,
  findUserByEmail,
  findUserByEmailVerificationTokenHash,
  markEmailVerifiedByTokenHash,
  saveEmailVerificationToken
} from "../users/user.repository.js";
import { ensureFreeSubscription } from "../subscriptions/subscription.service.js";
import {
  buildSignupConsentRecords,
  storeConsentRecords
} from "../legal/consent.service.js";
import {
  emailNotConfiguredMessage,
  sendVerificationEmail
} from "./email.service.js";

// TODO: Re-enable email verification before public production launch.
export const mvpEmailVerificationDisabled = true;
export const mvpEmailVerificationSkippedMessage =
  "MVP aşamasında e-posta doğrulaması geçici olarak devre dışı.";

export function buildMvpEmailVerificationSkippedResponse(email) {
  return {
    sent: false,
    skipped: true,
    email,
    message: mvpEmailVerificationSkippedMessage
  };
}

export function generateVerificationToken() {
  return crypto.randomBytes(32).toString("hex");
}

export function hashVerificationToken(token) {
  return crypto.createHash("sha256").update(String(token || "")).digest("hex");
}

export async function createEmailVerificationForUser(
  user,
  {
    token = generateVerificationToken(),
    saveToken = saveEmailVerificationToken,
    sendEmail = sendVerificationEmail
  } = {}
) {
  const tokenHash = hashVerificationToken(token);
  await saveToken({ userId: user.id, tokenHash });
  let emailResult;
  try {
    emailResult = await sendEmail({ to: user.email, token });
  } catch (error) {
    console.error("EMAIL_SEND_FAILED", error);
    emailResult = {
      sent: false,
      message: emailNotConfiguredMessage
    };
  }

  return {
    ...emailResult,
    email: user.email
  };
}

export async function registerUser(
  {
    email,
    password,
    displayName,
    fullName,
    birthYear,
    gender,
    city,
    occupation,
    relationshipStatus,
    sleepQuality,
    mainGoal,
    preferredAvatar,
    avatarName,
    avatarCharacterId,
    avatarCharacterName,
    avatarVoiceStyle,
    avatarVisualStyle,
    avatarPersonalityStyle,
    notificationConsent,
    marketingConsent,
    consents
  },
  {
    ipAddress = null,
    userAgent = null,
    findByEmailFn = findUserByEmail,
    createUserFn = createUser,
    ensureFreeSubscriptionFn = ensureFreeSubscription,
    storeConsentRecordsFn = storeConsentRecords,
    createVerification = createEmailVerificationForUser
  } = {}
) {
  const consentRecords = buildSignupConsentRecords(consents);
  const existing = await findByEmailFn(email);
  if (existing) throw new ApiError(409, "Email is already registered");

  const passwordHash = await bcrypt.hash(password, 12);
  const marketingPermission = consentRecords.some((record) => record.consentType === "marketing_permission");
  const user = await createUserFn({
    email,
    passwordHash,
    displayName,
    fullName,
    birthYear,
    gender,
    city,
    occupation,
    relationshipStatus,
    sleepQuality,
    mainGoal,
    preferredAvatar,
    avatarName,
    avatarCharacterId,
    avatarCharacterName,
    avatarVoiceStyle,
    avatarVisualStyle,
    avatarPersonalityStyle,
    notificationConsent,
    marketingConsent: Boolean(marketingConsent || marketingPermission),
    emailVerified: true
  });
  await ensureFreeSubscriptionFn(user.id);
  await storeConsentRecordsFn({ userId: user.id, records: consentRecords, ipAddress, userAgent });
  // TODO: Re-enable email verification before public production launch.
  const emailVerification = mvpEmailVerificationDisabled
    ? buildMvpEmailVerificationSkippedResponse(user.email)
    : await createVerification(user);

  return { user, token: signToken(user), emailVerification };
}

export async function loginUser(
  { email, password },
  {
    findByEmailFn = findUserByEmail,
    comparePassword = bcrypt.compare
  } = {}
) {
  const user = await findByEmailFn(email);
  if (!user) throw new ApiError(401, "Invalid email or password");

  const matches = await comparePassword(password, user.password_hash);
  if (!matches) throw new ApiError(401, "Invalid email or password");

  return {
    user: {
      id: user.id,
      email: user.email,
      email_verified: user.email_verified,
      emailVerified: user.email_verified,
      email_verified_at: user.email_verified_at,
      emailVerifiedAt: user.email_verified_at,
      display_name: user.display_name,
      displayName: user.display_name,
      full_name: user.full_name,
      fullName: user.full_name,
      birth_year: user.birth_year,
      birthYear: user.birth_year,
      gender: user.gender,
      city: user.city,
      occupation: user.occupation,
      relationship_status: user.relationship_status,
      relationshipStatus: user.relationship_status,
      sleep_quality: user.sleep_quality,
      sleepQuality: user.sleep_quality,
      main_goal: user.main_goal,
      mainGoal: user.main_goal,
      preferred_avatar: user.preferred_avatar,
      preferredAvatar: user.preferred_avatar,
      avatar_name: user.avatar_name,
      avatarName: user.avatar_name,
      avatar_character_id: user.avatar_character_id,
      avatarCharacterId: user.avatar_character_id,
      avatar_character_name: user.avatar_character_name,
      avatarCharacterName: user.avatar_character_name,
      avatar_voice_style: user.avatar_voice_style,
      avatarVoiceStyle: user.avatar_voice_style,
      avatar_visual_style: user.avatar_visual_style,
      avatarVisualStyle: user.avatar_visual_style,
      avatar_personality_style: user.avatar_personality_style,
      avatarPersonalityStyle: user.avatar_personality_style,
      notification_consent: user.notification_consent,
      notificationConsent: user.notification_consent,
      marketing_consent: user.marketing_consent,
      marketingConsent: user.marketing_consent,
      role: user.role,
      created_at: user.created_at,
      updated_at: user.updated_at
    },
    token: signToken(user)
  };
}

export async function resendVerificationEmail(
  { email },
  {
    findByEmail = findUserByEmail,
    createVerification = createEmailVerificationForUser
  } = {}
) {
  const user = await findByEmail(email);
  // TODO: Re-enable email verification before public production launch.
  if (mvpEmailVerificationDisabled) {
    return buildMvpEmailVerificationSkippedResponse(user?.email || email);
  }

  if (!user) {
    return {
      sent: false,
      email,
      message: "Doğrulama e-postası şu anda gönderilemedi."
    };
  }

  if (user.email_verified) {
    return {
      sent: true,
      email: user.email,
      message: "E-posta adresin zaten doğrulanmış."
    };
  }

  return createVerification(user);
}

export async function verifyEmailToken(
  { token },
  {
    findByTokenHash = findUserByEmailVerificationTokenHash,
    markVerified = markEmailVerifiedByTokenHash
  } = {}
) {
  if (!token) {
    throw new ApiError(400, "Doğrulama bağlantısı geçersiz veya eksik.");
  }

  const tokenHash = hashVerificationToken(token);
  const existing = await findByTokenHash(tokenHash);
  if (!existing) throw new ApiError(400, "Doğrulama bağlantısı geçersiz veya süresi dolmuş.");

  const user = await markVerified(tokenHash);
  return {
    verified: true,
    user,
    message: "E-posta adresin doğrulandı."
  };
}
