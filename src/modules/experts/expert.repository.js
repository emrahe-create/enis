import { query } from "../../db/pool.js";

export async function upsertWaitlistEntry({ userId, email, preferredFocus = [], note }) {
  const result = await query(
    `INSERT INTO expert_waitlist (user_id, email, preferred_focus, note)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (user_id) DO UPDATE SET
       email = EXCLUDED.email,
       preferred_focus = EXCLUDED.preferred_focus,
       note = EXCLUDED.note,
       updated_at = NOW()
     RETURNING *`,
    [userId, email, JSON.stringify(preferredFocus), note || null]
  );
  return result.rows[0];
}

export async function getWaitlistEntryByUserId(userId) {
  const result = await query("SELECT * FROM expert_waitlist WHERE user_id = $1", [userId]);
  return result.rows[0] || null;
}

export async function countWaitlistEntries() {
  const result = await query("SELECT COUNT(*)::int AS count FROM expert_waitlist");
  return result.rows[0]?.count || 0;
}

export async function listActiveExpertSpecialties() {
  const result = await query(
    `SELECT DISTINCT es.specialty
     FROM expert_specialties es
     JOIN experts e ON e.id = es.expert_id
     WHERE e.status = 'active'
     ORDER BY es.specialty`
  );
  return result.rows.map((row) => row.specialty);
}
