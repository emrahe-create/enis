import { query } from "../../db/pool.js";

const publicUserColumns = `
  id,
  email,
  email_verified,
  email_verified AS "emailVerified",
  email_verified_at,
  email_verified_at AS "emailVerifiedAt",
  display_name,
  display_name AS "displayName",
  full_name,
  full_name AS "fullName",
  birth_year,
  birth_year AS "birthYear",
  gender,
  city,
  occupation,
  relationship_status,
  relationship_status AS "relationshipStatus",
  sleep_quality,
  sleep_quality AS "sleepQuality",
  main_goal,
  main_goal AS "mainGoal",
  preferred_avatar,
  preferred_avatar AS "preferredAvatar",
  avatar_name,
  avatar_name AS "avatarName",
  avatar_character_id,
  avatar_character_id AS "avatarCharacterId",
  avatar_character_name,
  avatar_character_name AS "avatarCharacterName",
  avatar_voice_style,
  avatar_voice_style AS "avatarVoiceStyle",
  avatar_visual_style,
  avatar_visual_style AS "avatarVisualStyle",
  avatar_personality_style,
  avatar_personality_style AS "avatarPersonalityStyle",
  notification_consent,
  notification_consent AS "notificationConsent",
  marketing_consent,
  marketing_consent AS "marketingConsent",
  role,
  created_at,
  updated_at
`;

export async function findUserByEmail(email) {
  const result = await query(
    `SELECT *,
        display_name AS "displayName",
        email_verified AS "emailVerified",
        email_verified_at AS "emailVerifiedAt",
        avatar_name AS "avatarName",
        avatar_character_id AS "avatarCharacterId",
        avatar_character_name AS "avatarCharacterName",
        avatar_voice_style AS "avatarVoiceStyle",
        avatar_visual_style AS "avatarVisualStyle",
        avatar_personality_style AS "avatarPersonalityStyle"
     FROM users
     WHERE email = $1`,
    [email.toLowerCase()]
  );
  return result.rows[0] || null;
}

export async function findUserById(id) {
  const result = await query(
    `SELECT ${publicUserColumns} FROM users WHERE id = $1`,
    [id]
  );
  return result.rows[0] || null;
}

export async function createUser({
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
  notificationConsent = false,
  marketingConsent = false,
  // TODO: Re-enable email verification before public production launch.
  emailVerified = true
}) {
  const result = await query(
    `INSERT INTO users (
       email,
       password_hash,
       display_name,
       full_name,
       birth_year,
       gender,
       city,
       occupation,
       relationship_status,
       sleep_quality,
       main_goal,
       preferred_avatar,
       avatar_name,
       avatar_character_id,
       avatar_character_name,
       avatar_voice_style,
       avatar_visual_style,
       avatar_personality_style,
       notification_consent,
       marketing_consent,
       email_verified,
       email_verified_at
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, CASE WHEN $21 THEN NOW() ELSE NULL END)
     RETURNING ${publicUserColumns}`,
    [
      email.toLowerCase(),
      passwordHash,
      displayName || fullName || null,
      fullName || null,
      birthYear ?? null,
      gender || null,
      city || null,
      occupation || null,
      relationshipStatus || null,
      sleepQuality || null,
      mainGoal || null,
      preferredAvatar || null,
      avatarName || null,
      avatarCharacterId || null,
      avatarCharacterName || null,
      avatarVoiceStyle || null,
      avatarVisualStyle || null,
      avatarPersonalityStyle || null,
      Boolean(notificationConsent),
      Boolean(marketingConsent),
      Boolean(emailVerified)
    ]
  );
  return result.rows[0];
}

export async function updateUserProfile(
  userId,
  {
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
    marketingConsent
  }
) {
  const result = await query(
    `UPDATE users
     SET display_name = COALESCE($2, display_name),
         full_name = COALESCE($3, full_name),
         birth_year = COALESCE($4, birth_year),
         gender = COALESCE($5, gender),
         city = COALESCE($6, city),
         occupation = COALESCE($7, occupation),
         relationship_status = COALESCE($8, relationship_status),
         sleep_quality = COALESCE($9, sleep_quality),
         main_goal = COALESCE($10, main_goal),
         preferred_avatar = COALESCE($11, preferred_avatar),
         avatar_name = COALESCE($12, avatar_name),
         avatar_character_id = COALESCE($13, avatar_character_id),
         avatar_character_name = COALESCE($14, avatar_character_name),
         avatar_voice_style = COALESCE($15, avatar_voice_style),
         avatar_visual_style = COALESCE($16, avatar_visual_style),
         avatar_personality_style = COALESCE($17, avatar_personality_style),
         notification_consent = COALESCE($18, notification_consent),
         marketing_consent = COALESCE($19, marketing_consent),
         updated_at = NOW()
     WHERE id = $1
     RETURNING ${publicUserColumns}`,
    [
      userId,
      displayName ?? null,
      fullName ?? null,
      birthYear ?? null,
      gender ?? null,
      city ?? null,
      occupation ?? null,
      relationshipStatus ?? null,
      sleepQuality ?? null,
      mainGoal ?? null,
      preferredAvatar ?? null,
      avatarName ?? null,
      avatarCharacterId ?? null,
      avatarCharacterName ?? null,
      avatarVoiceStyle ?? null,
      avatarVisualStyle ?? null,
      avatarPersonalityStyle ?? null,
      notificationConsent ?? null,
      marketingConsent ?? null
    ]
  );
  return result.rows[0] || null;
}

export async function deleteUserById(userId) {
  const result = await query("DELETE FROM users WHERE id = $1 RETURNING id", [userId]);
  return result.rows[0] || null;
}

export async function saveEmailVerificationToken({ userId, tokenHash }) {
  const result = await query(
    `UPDATE users
     SET email_verification_token_hash = $2,
         email_verification_sent_at = NOW(),
         updated_at = NOW()
     WHERE id = $1
     RETURNING ${publicUserColumns}`,
    [userId, tokenHash]
  );
  return result.rows[0] || null;
}

export async function findUserByEmailVerificationTokenHash(tokenHash) {
  const result = await query(
    `SELECT ${publicUserColumns}
     FROM users
     WHERE email_verification_token_hash = $1`,
    [tokenHash]
  );
  return result.rows[0] || null;
}

export async function markEmailVerifiedByTokenHash(tokenHash) {
  const result = await query(
    `UPDATE users
     SET email_verified = TRUE,
         email_verified_at = NOW(),
         email_verification_token_hash = NULL,
         updated_at = NOW()
     WHERE email_verification_token_hash = $1
     RETURNING ${publicUserColumns}`,
    [tokenHash]
  );
  return result.rows[0] || null;
}

export async function exportUserData(userId) {
  const [
    user,
    subscriptions,
    consents,
    chatSessions,
    chatMessages,
    memories,
    conversationMessages,
    checkIns,
    emotionAnalyses,
    wellnessEntries,
    expertWaitlist
  ] = await Promise.all([
    query(`SELECT ${publicUserColumns} FROM users WHERE id = $1`, [userId]),
    query("SELECT * FROM subscriptions WHERE user_id = $1", [userId]),
    query("SELECT * FROM user_consents WHERE user_id = $1 ORDER BY accepted_at DESC", [userId]),
    query("SELECT * FROM chat_sessions WHERE user_id = $1 ORDER BY created_at DESC", [userId]),
    query(
      `SELECT chat_messages.*
       FROM chat_messages
       JOIN chat_sessions ON chat_sessions.id = chat_messages.session_id
       WHERE chat_sessions.user_id = $1
       ORDER BY chat_messages.created_at ASC`,
      [userId]
    ),
    query("SELECT * FROM user_memories WHERE user_id = $1 ORDER BY importance DESC, updated_at DESC", [userId]),
    query("SELECT * FROM conversation_messages WHERE user_id = $1 ORDER BY created_at ASC", [userId]),
    query("SELECT * FROM daily_checkins WHERE user_id = $1 ORDER BY created_at DESC", [userId]),
    query("SELECT * FROM emotion_analyses WHERE user_id = $1 ORDER BY created_at DESC", [userId]),
    query("SELECT * FROM wellness_entries WHERE user_id = $1 ORDER BY created_at DESC", [userId]),
    query("SELECT * FROM expert_waitlist WHERE user_id = $1 ORDER BY created_at DESC", [userId])
  ]);

  return {
    user: user.rows[0] || null,
    subscriptions: subscriptions.rows,
    consents: consents.rows,
    chatSessions: chatSessions.rows,
    chatMessages: chatMessages.rows,
    memories: memories.rows,
    conversationMessages: conversationMessages.rows,
    checkIns: checkIns.rows,
    emotionAnalyses: emotionAnalyses.rows,
    wellnessEntries: wellnessEntries.rows,
    expertWaitlist: expertWaitlist.rows
  };
}
