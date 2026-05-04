import { query } from "../../db/pool.js";

export async function listUserMemories(userId) {
  const result = await query(
    `SELECT id, user_id, "key", value, importance, last_used_at, created_at, updated_at
     FROM user_memories
     WHERE user_id = $1
     ORDER BY importance DESC, last_used_at DESC NULLS LAST, updated_at DESC`,
    [userId]
  );
  return result.rows;
}

export async function getTopMemories(userId, limit = 5) {
  const result = await query(
    `SELECT id, user_id, "key", value, importance, last_used_at, created_at, updated_at
     FROM user_memories
     WHERE user_id = $1
     ORDER BY importance DESC, last_used_at DESC NULLS LAST, updated_at DESC
     LIMIT $2`,
    [userId, limit]
  );
  return result.rows;
}

export async function findMemoryByKey(userId, key) {
  const result = await query(
    `SELECT id, user_id, "key", value, importance, last_used_at, created_at, updated_at
     FROM user_memories
     WHERE user_id = $1 AND "key" = $2`,
    [userId, key]
  );
  return result.rows[0] || null;
}

export async function upsertUserMemory({
  userId,
  key,
  value,
  importance = 2,
  importanceIncrement = 1
}) {
  const result = await query(
    `INSERT INTO user_memories (user_id, "key", value, importance)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (user_id, "key")
     DO UPDATE SET
       value = EXCLUDED.value,
       importance = LEAST(5, user_memories.importance + $5),
       updated_at = NOW()
     RETURNING id, user_id, "key", value, importance, last_used_at, created_at, updated_at`,
    [userId, key, value, importance, importanceIncrement]
  );
  return result.rows[0];
}

export async function trimUserMemories(userId, maxMemories) {
  await query(
    `DELETE FROM user_memories
     WHERE id IN (
       SELECT id
       FROM user_memories
       WHERE user_id = $1
       ORDER BY importance ASC, last_used_at ASC NULLS FIRST, updated_at ASC
       OFFSET $2
     )`,
    [userId, maxMemories]
  );
}

export async function touchMemories(memoryIds = []) {
  if (!memoryIds.length) return [];
  const result = await query(
    `UPDATE user_memories
     SET last_used_at = NOW(), updated_at = NOW()
     WHERE id = ANY($1::uuid[])
     RETURNING id, user_id, "key", value, importance, last_used_at, created_at, updated_at`,
    [memoryIds]
  );
  return result.rows;
}

export async function deleteUserMemories(userId) {
  const result = await query("DELETE FROM user_memories WHERE user_id = $1 RETURNING id", [userId]);
  return result.rowCount;
}

export async function addConversationMessage({ userId, role, text }) {
  const result = await query(
    `INSERT INTO conversation_messages (user_id, role, text)
     VALUES ($1, $2, $3)
     RETURNING id, user_id, role, text, created_at`,
    [userId, role, text]
  );
  return result.rows[0];
}

export async function getRecentConversationMessages(userId, limit = 10) {
  const result = await query(
    `SELECT id, user_id, role, text, created_at
     FROM conversation_messages
     WHERE user_id = $1
     ORDER BY created_at DESC
     LIMIT $2`,
    [userId, limit]
  );
  return result.rows.reverse();
}
