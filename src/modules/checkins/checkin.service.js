import { countCheckInDays, getTodayCheckIn, upsertDailyCheckIn } from "./checkin.repository.js";

export const dailyCheckInOptions = [
  "Hafifim",
  "Karışığım",
  "Yoruldum",
  "Kaygılıyım",
  "Anlatmak istiyorum"
];

export const checkInNotificationCopy = {
  morning: "Güne nasıl başladığını merak ettim.",
  evening: "Bugünü burada bırakmak ister misin?",
  returning: "Buradayım. Kaldığımız yerden devam edebiliriz."
};

export const pushNotificationBlueprints = {
  enabled: false,
  morning: checkInNotificationCopy.morning,
  evening: checkInNotificationCopy.evening,
  returning: checkInNotificationCopy.returning
};

export const dailyPresenceCopy = "Buradayım. İstersen devam edebiliriz.";
export const silenceNudgeCopy =
  "İstersen burada kalabiliriz… ya da biraz daha anlatabilirsin.";
export const microEmotionalHooks = [
  "Bugün seni en çok ne yordu?",
  "İçinde kalan bir şey var mı?",
  "Bugün biraz daha hafif mi yoksa benzer mi?"
];

const memoryGreetingLabels = {
  work_stress: "iş tarafı",
  relationship: "ilişki tarafı",
  sleep: "uyku düzenin",
  family: "aile tarafı",
  loneliness: "yalnızlık hissi",
  worry: "kaygı tarafı"
};

const guiltFragments = [
  "kaçırdın",
  "kaybettin",
  "bozdun",
  "geri kaldın",
  "streak lost",
  "neredesin",
  "neden yazmadın",
  "niye yazmadın"
];

export function validateCheckInMood(mood) {
  const cleanMood = String(mood || "").trim();
  if (!dailyCheckInOptions.includes(cleanMood)) {
    const error = new Error("Invalid check-in mood");
    error.status = 400;
    error.details = { allowed: dailyCheckInOptions };
    throw error;
  }
  return cleanMood;
}

export function buildCheckInChatContext({ mood, note }) {
  const cleanMood = validateCheckInMood(mood);
  const cleanNote = String(note || "").trim();
  return cleanNote
    ? `Bugünkü kısa check-in: ${cleanMood}. Notum: ${cleanNote}`
    : `Bugünkü kısa check-in: ${cleanMood}. Buna göre yumuşak ve kısa bir yerden cevap ver.`;
}

export function shouldShowDailyCheckIn(todayCheckIn) {
  return !todayCheckIn;
}

export function shouldShowReturningGreeting(lastOpenedAt, now = new Date()) {
  if (!lastOpenedAt) return false;
  const last = new Date(lastOpenedAt);
  if (Number.isNaN(last.getTime())) return false;
  return now.getTime() - last.getTime() >= 24 * 60 * 60 * 1000;
}

export function isSameLocalDay(first, second) {
  const a = new Date(first);
  const b = new Date(second);
  if (Number.isNaN(a.getTime()) || Number.isNaN(b.getTime())) return false;
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

export function shouldShowDailyPresence({
  lastOpenedAt,
  lastInteractionAt,
  now = new Date(),
  returning = false
} = {}) {
  if (returning) return false;
  const reference = lastInteractionAt || lastOpenedAt;
  if (!reference) return false;
  return isSameLocalDay(reference, now);
}

export function microEmotionalHook({ now = new Date(), seed = 0 } = {}) {
  const date = new Date(now);
  const safeSeed = Number(seed || 0);
  const index = Math.abs(date.getFullYear() + date.getMonth() + date.getDate() + safeSeed) %
    microEmotionalHooks.length;
  return microEmotionalHooks[index];
}

export function latestMemoryTheme(memories = []) {
  return [...memories]
    .filter((memory) => memory?.key && memory?.value)
    .sort((a, b) => {
      const aTime = new Date(a.last_used_at || a.updated_at || a.created_at || 0).getTime();
      const bTime = new Date(b.last_used_at || b.updated_at || b.created_at || 0).getTime();
      if ((b.importance || 0) !== (a.importance || 0)) return (b.importance || 0) - (a.importance || 0);
      return bTime - aTime;
    })[0] || null;
}

export function buildReturningGreeting({ memories = [], lastOpenedAt, now = new Date(), premium = false } = {}) {
  if (!shouldShowReturningGreeting(lastOpenedAt, now)) return null;
  const memory = premium ? latestMemoryTheme(memories) : null;

  if (memory) {
    const label = memoryGreetingLabels[memory.key] || "konuştuğumuz konu";
    return `Bir süredir yoktun… son konuşmamızda ${label} seni yormuştu. Bugün nasıl hissediyorsun?`;
  }

  return "Bir süredir konuşamadık… bugün nasıl gidiyor?";
}

export function shouldShowSilenceNudge({
  userMessageCount = 0,
  assistantMessageCount = 0,
  alreadyShown = false
} = {}) {
  if (alreadyShown) return false;
  return Number(userMessageCount) >= 2 && Number(assistantMessageCount) >= 2;
}

export function shouldShowNightReflection(now = new Date()) {
  return now.getHours() >= 20;
}

export function nightReflectionPrompt(now = new Date()) {
  return shouldShowNightReflection(now)
    ? "Bugünü kapatmadan önce içinden geçen bir şey var mı?"
    : null;
}

export function buildContinuityLine(days) {
  const count = Number(days || 0);
  if (count < 2) return null;
  return `${count} gündür kendine küçük bir alan açıyorsun.`;
}

export function hasGuiltLanguage(text = "") {
  const normalized = String(text || "").toLocaleLowerCase("tr-TR");
  return guiltFragments.some((fragment) => normalized.includes(fragment));
}

export async function saveDailyCheckIn({ userId, mood, note }) {
  const checkIn = await upsertDailyCheckIn({
    userId,
    mood: validateCheckInMood(mood),
    note: note?.trim() || null
  });
  const continuityDays = await countCheckInDays(userId);

  return {
    checkIn,
    checkedInToday: true,
    continuityLine: buildContinuityLine(continuityDays),
    chatContext: buildCheckInChatContext({ mood: checkIn.mood, note: checkIn.note })
  };
}

export async function getTodayCheckInState(userId) {
  const [checkIn, continuityDays] = await Promise.all([
    getTodayCheckIn(userId),
    countCheckInDays(userId)
  ]);

  return {
    checkIn,
    checkedInToday: Boolean(checkIn),
    showCard: shouldShowDailyCheckIn(checkIn),
    continuityLine: buildContinuityLine(continuityDays)
  };
}
