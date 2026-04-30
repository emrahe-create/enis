import { query } from "../../db/pool.js";

export async function recordUserConsent({
  userId,
  consentType,
  version,
  ipAddress = null,
  userAgent = null
}) {
  const result = await query(
    `INSERT INTO user_consents (user_id, consent_type, version, ip_address, user_agent)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [userId, consentType, version, ipAddress, userAgent]
  );
  return result.rows[0];
}

export async function listUserConsents(userId) {
  const result = await query(
    "SELECT * FROM user_consents WHERE user_id = $1 ORDER BY accepted_at DESC",
    [userId]
  );
  return result.rows;
}
