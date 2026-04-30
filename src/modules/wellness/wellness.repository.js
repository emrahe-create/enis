import { query } from "../../db/pool.js";

export async function createWellnessEntry({ userId, toolType, payload, completedAt }) {
  const result = await query(
    `INSERT INTO wellness_entries (user_id, tool_type, payload, completed_at)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [userId, toolType, JSON.stringify(payload || {}), completedAt || null]
  );
  return result.rows[0];
}

export async function listWellnessEntries(userId) {
  const result = await query(
    `SELECT * FROM wellness_entries
     WHERE user_id = $1
     ORDER BY created_at DESC
     LIMIT 100`,
    [userId]
  );
  return result.rows;
}
