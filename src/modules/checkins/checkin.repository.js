import { query } from "../../db/pool.js";

export async function upsertDailyCheckIn({ userId, mood, note = null }) {
  const result = await query(
    `INSERT INTO daily_checkins (user_id, mood, note)
     VALUES ($1, $2, $3)
     ON CONFLICT (user_id, created_on)
     DO UPDATE SET mood = EXCLUDED.mood,
                   note = EXCLUDED.note,
                   created_at = NOW()
     RETURNING id, user_id, mood, note, created_at`,
    [userId, mood, note]
  );
  return result.rows[0];
}

export async function getTodayCheckIn(userId) {
  const result = await query(
    `SELECT id, user_id, mood, note, created_at
     FROM daily_checkins
     WHERE user_id = $1
       AND created_on = CURRENT_DATE
     ORDER BY created_at DESC
     LIMIT 1`,
    [userId]
  );
  return result.rows[0] || null;
}

export async function countCheckInDays(userId) {
  const result = await query(
    `SELECT COUNT(DISTINCT created_on)::int AS count
     FROM daily_checkins
     WHERE user_id = $1`,
    [userId]
  );
  return result.rows[0]?.count || 0;
}
