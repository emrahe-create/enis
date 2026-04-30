import { query } from "../../db/pool.js";

export async function createAvatar({ userId, name, tier, style, metadata = {} }) {
  const result = await query(
    `INSERT INTO avatars (user_id, name, tier, style, metadata)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [userId, name, tier, style, JSON.stringify(metadata)]
  );
  return result.rows[0];
}

export async function listAvatars(userId) {
  const result = await query("SELECT * FROM avatars WHERE user_id = $1 ORDER BY created_at DESC", [
    userId
  ]);
  return result.rows;
}
