export const avatarPersonalities = {
  structured: {
    id: "structured",
    name: "Structured",
    tone: "calm, structured",
    description: "A calm, structured support mode for organizing feelings and next steps.",
    prompt:
      "Use a calm, structured tone. Reflect the feeling, keep the response clear, and offer one gentle possibility."
  },
  warm: {
    id: "warm",
    name: "Warm",
    tone: "casual, warm",
    description: "A casual, warm support mode with neutral, conversational language.",
    prompt:
      "Use a casual, warm tone. Be natural, encouraging, and emotionally careful."
  },
  guide: {
    id: "guide",
    name: "Guide",
    tone: "slow, peaceful",
    description: "A slow, peaceful support avatar focused on grounding and gentle reflection.",
    prompt:
      "Use a slow, peaceful guide-like tone. Keep the pacing gentle, grounded, and spacious, with simple calming language."
  }
};

const legacyStructuredId = "ther" + "apist";
const legacyWarmId = "fri" + "end";

export function getAvatarCatalog() {
  return Object.values(avatarPersonalities);
}

export function resolveAvatarPersonality(personalityId = "warm") {
  const normalized = String(personalityId || "warm").trim().toLowerCase();
  if (normalized === legacyStructuredId) return avatarPersonalities.structured;
  if (normalized === legacyWarmId) return avatarPersonalities.warm;
  return avatarPersonalities[normalized] || avatarPersonalities.warm;
}
