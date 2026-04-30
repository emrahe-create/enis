import { query } from "../../db/pool.js";

export async function createSession(userId, title = "Support chat") {
  const result = await query(
    "INSERT INTO chat_sessions (user_id, title) VALUES ($1, $2) RETURNING *",
    [userId, title]
  );
  return result.rows[0];
}

export async function listSessions(userId) {
  const result = await query(
    "SELECT * FROM chat_sessions WHERE user_id = $1 ORDER BY updated_at DESC",
    [userId]
  );
  return result.rows;
}

export async function getSessionForUser(sessionId, userId) {
  const result = await query("SELECT * FROM chat_sessions WHERE id = $1 AND user_id = $2", [
    sessionId,
    userId
  ]);
  return result.rows[0] || null;
}

export async function addMessage({ sessionId, userId, role, content, metadata = {} }) {
  const result = await query(
    `INSERT INTO chat_messages (session_id, user_id, role, content, metadata)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [sessionId, userId || null, role, content, JSON.stringify(metadata)]
  );
  await query("UPDATE chat_sessions SET updated_at = NOW() WHERE id = $1", [sessionId]);
  return result.rows[0];
}

export async function getRecentMessages(sessionId, limit = 12) {
  const result = await query(
    `SELECT role, content, created_at
     FROM chat_messages
     WHERE session_id = $1
     ORDER BY created_at DESC
     LIMIT $2`,
    [sessionId, limit]
  );
  return result.rows.reverse();
}

export async function getRecentConversationMemory(userId, excludeMessageId, limit = 5) {
  const result = await query(
    `SELECT cm.role, cm.content, cm.created_at, cm.session_id
     FROM chat_messages cm
     JOIN chat_sessions cs ON cs.id = cm.session_id
     WHERE cs.user_id = $1
       AND cm.id <> $2
       AND cm.role IN ('user', 'assistant')
       AND COALESCE(cm.metadata->>'safetyTriggered', 'false') <> 'true'
     ORDER BY cm.created_at DESC
     LIMIT $3`,
    [userId, excludeMessageId, limit * 2]
  );
  return result.rows.reverse();
}

export async function countUserMessagesSince(userId, since) {
  const result = await query(
    `SELECT COUNT(*)::int AS count
     FROM chat_messages
     WHERE user_id = $1
       AND role = 'user'
       AND created_at >= $2`,
    [userId, since]
  );
  return result.rows[0]?.count || 0;
}
