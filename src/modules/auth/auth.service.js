import bcrypt from "bcryptjs";
import { ApiError } from "../../utils/http.js";
import { signToken } from "../../middleware/auth.js";
import { createUser, findUserByEmail } from "../users/user.repository.js";
import { ensureFreeSubscription } from "../subscriptions/subscription.service.js";
import {
  buildSignupConsentRecords,
  storeConsentRecords
} from "../legal/consent.service.js";

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
    notificationConsent,
    marketingConsent,
    consents
  },
  { ipAddress = null, userAgent = null } = {}
) {
  const consentRecords = buildSignupConsentRecords(consents);
  const existing = await findUserByEmail(email);
  if (existing) throw new ApiError(409, "Email is already registered");

  const passwordHash = await bcrypt.hash(password, 12);
  const marketingPermission = consentRecords.some((record) => record.consentType === "marketing_permission");
  const user = await createUser({
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
    notificationConsent,
    marketingConsent: Boolean(marketingConsent || marketingPermission)
  });
  await ensureFreeSubscription(user.id);
  await storeConsentRecords({ userId: user.id, records: consentRecords, ipAddress, userAgent });

  return { user, token: signToken(user) };
}

export async function loginUser({ email, password }) {
  const user = await findUserByEmail(email);
  if (!user) throw new ApiError(401, "Invalid email or password");

  const matches = await bcrypt.compare(password, user.password_hash);
  if (!matches) throw new ApiError(401, "Invalid email or password");

  return {
    user: {
      id: user.id,
      email: user.email,
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
