import OpenAI from "openai";
import { env } from "../../config/env.js";
import { query } from "../../db/pool.js";

const openai = env.OPENAI_API_KEY ? new OpenAI({ apiKey: env.OPENAI_API_KEY }) : null;

const keywordGroups = {
  stress: ["stress", "stressed", "pressure", "overwhelmed", "too much", "burned out", "tense"],
  anxiety: ["anxious", "anxiety", "panic", "worried", "nervous", "scared", "racing thoughts", "on edge"],
  lowMood: ["sad", "down", "empty", "hopeless", "lonely", "numb", "cry", "tired", "exhausted"],
  brightMood: ["happy", "calm", "grateful", "hopeful", "relieved", "excited", "proud", "good"],
  anger: ["angry", "mad", "furious", "resentful", "irritated"]
};

const primaryEmotionMap = {
  stress: "stress",
  anxiety: "anxious",
  lowMood: "sad",
  brightMood: "joyful",
  anger: "anger"
};

function countKeywordMatches(text, keywords) {
  return keywords.reduce((total, keyword) => total + (text.includes(keyword) ? 1 : 0), 0);
}

function signalLevel(score) {
  if (score >= 3) return "high";
  if (score >= 1) return "some";
  return "low";
}

function anxietyLevel(score) {
  if (score >= 3) return "strong";
  if (score >= 1) return "some";
  return "not clear";
}

function moodLevel(lowMoodScore, brightMoodScore) {
  if (lowMoodScore >= 2 && brightMoodScore === 0) return "low";
  if (brightMoodScore >= 2 && lowMoodScore === 0) return "bright";
  if (lowMoodScore > 0 && brightMoodScore > 0) return "mixed";
  if (lowMoodScore > 0) return "mixed";
  return "steady";
}

function buildSummary({ stress, anxietySignals, moodLevel: mood }) {
  if (stress === "high" && anxietySignals === "strong") {
    return "You sound under a lot of pressure and on edge right now; a slow breath and one small next step may help.";
  }

  if (stress !== "low" && anxietySignals !== "not clear") {
    return "You seem stressed and uneasy, with your mood needing some gentle care today.";
  }

  if (mood === "low") {
    return "Your mood sounds low right now; it may help to be gentle with yourself and keep the next step small.";
  }

  if (mood === "bright") {
    return "Your message has a lighter, more hopeful tone; it may be worth noticing what is helping.";
  }

  if (stress !== "low") {
    return "You sound like you are carrying some stress, so a brief pause could give you a little room.";
  }

  if (anxietySignals !== "not clear") {
    return "There are signs of worry in your message; slowing down and naming the feeling may help.";
  }

  return "Your tone sounds fairly steady, with space to check in gently and keep moving at your own pace.";
}

function deriveInternalTone({ stress, anxietySignals, moodLevel: mood }) {
  const sentimentScore = mood === "bright" ? 0.55 : mood === "low" ? -0.55 : mood === "mixed" ? -0.15 : 0.1;
  const intensity =
    stress === "high" || anxietySignals === "strong"
      ? 0.8
      : stress === "some" || anxietySignals === "some" || mood === "low"
        ? 0.5
        : 0.25;

  return { sentimentScore, intensity };
}

function normalizeTextValue(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[_-]/g, " ");
}

function normalizeStress(value) {
  const normalized = normalizeTextValue(value);
  if (["high", "strong", "elevated"].includes(normalized)) return "high";
  if (["some", "mild", "moderate", "present"].includes(normalized)) return "some";
  return "low";
}

function normalizeAnxietySignals(value) {
  const normalized = normalizeTextValue(value);
  if (["strong", "high", "elevated"].includes(normalized)) return "strong";
  if (["some", "mild", "moderate", "present"].includes(normalized)) return "some";
  return "not clear";
}

function normalizeMood(value) {
  const normalized = normalizeTextValue(value);
  if (["low", "down"].includes(normalized)) return "low";
  if (["mixed", "uneven"].includes(normalized)) return "mixed";
  if (["bright", "positive", "hopeful"].includes(normalized)) return "bright";
  return "steady";
}

function safeSummary(summary, fallback) {
  const normalized = String(summary || "").trim();
  if (!normalized) return fallback;
  const lower = normalized.toLowerCase();
  const blockedFragments = [
    "%",
    "percent",
    "diagn" + "os",
    "dis" + "order",
    "treat" + "ment",
    "clin" + "ical",
    "cond" + "ition",
    "prob" + "ability"
  ];
  if (blockedFragments.some((fragment) => lower.includes(fragment))) return fallback;
  return normalized.length > 220 ? `${normalized.slice(0, 217).trim()}...` : normalized;
}

function normalizeAnalysis(analysis) {
  const stress = normalizeStress(analysis.stress);
  const anxietySignals = normalizeAnxietySignals(analysis.anxietySignals);
  const mood = normalizeMood(analysis.moodLevel);
  const { sentimentScore, intensity } = deriveInternalTone({ stress, anxietySignals, moodLevel: mood });
  const fallbackSummary = buildSummary({ stress, anxietySignals, moodLevel: mood });

  return {
    primaryEmotion: analysis.primaryEmotion || "neutral",
    sentimentScore,
    intensity,
    labels: Array.isArray(analysis.labels) ? analysis.labels : [],
    stress,
    anxietySignals,
    moodLevel: mood,
    summary: safeSummary(analysis.summary, fallbackSummary)
  };
}

export function analyzeEmotionLocally(text) {
  const normalized = text.toLowerCase();
  const scores = Object.fromEntries(
    Object.entries(keywordGroups).map(([name, keywords]) => [name, countKeywordMatches(normalized, keywords)])
  );
  const topSignal = Object.entries(scores).sort((a, b) => b[1] - a[1])[0];
  const stress = signalLevel(scores.stress);
  const anxietySignals = anxietyLevel(scores.anxiety);
  const mood = moodLevel(scores.lowMood, scores.brightMood);
  const labels = Object.entries(scores)
    .filter(([, score]) => score > 0)
    .map(([name]) => name);

  return normalizeAnalysis({
    primaryEmotion: topSignal?.[1] > 0 ? primaryEmotionMap[topSignal[0]] || "neutral" : "neutral",
    labels,
    stress,
    anxietySignals,
    moodLevel: mood,
    summary: buildSummary({ stress, anxietySignals, moodLevel: mood })
  });
}

export function formatEmotionAnalysis(analysis) {
  return {
    stress: analysis.stress,
    anxietySignals: analysis.anxietySignals,
    moodLevel: analysis.moodLevel,
    summary: analysis.summary
  };
}

export async function analyzeEmotion(text) {
  if (!openai) return analyzeEmotionLocally(text);

  const response = await openai.chat.completions.create({
    model: env.OPENAI_MODEL,
    temperature: 0.1,
    response_format: { type: "json_object" },
    messages: [
      {
        role: "system",
        content:
          "Analyze emotional tone for a wellness app. Return JSON only with stress low|some|high, anxietySignals 'not clear'|'some'|'strong', moodLevel low|mixed|steady|bright, primaryEmotion, labels array, and summary. The summary must be one short supportive sentence. Do not include percentages, scores, labels, certainty claims, or care instructions."
      },
      { role: "user", content: text }
    ]
  });

  const parsed = JSON.parse(response.choices[0].message.content);
  return normalizeAnalysis(parsed);
}

export async function saveEmotionAnalysis({ userId, source, sourceId, analysis }) {
  const result = await query(
    `INSERT INTO emotion_analyses (
       user_id, source, source_id, primary_emotion, sentiment_score, intensity, labels
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [
      userId,
      source,
      sourceId || null,
      analysis.primaryEmotion,
      analysis.sentimentScore,
      analysis.intensity,
      JSON.stringify(analysis.labels)
    ]
  );
  return result.rows[0];
}

export async function getEmotionSummary(userId) {
  const result = await query(
    `SELECT primary_emotion, COUNT(*)::int AS count
     FROM emotion_analyses
     WHERE user_id = $1 AND created_at > NOW() - INTERVAL '30 days'
     GROUP BY primary_emotion
     ORDER BY count DESC`,
    [userId]
  );

  return result.rows.map((row) => ({
    signal: row.primary_emotion,
    entries: row.count
  }));
}
