const safetyPatterns = [
  {
    category: "self_harm",
    patterns: [
      /\b(kill myself|end my life|take my life)\b/i,
      /\b(suicide|suicidal)\b/i,
      /\b(i want to die|want to die|do not want to live|don't want to live|dont want to live)\b/i,
      /\b(harm myself|hurt myself|cut myself|overdose)\b/i,
      /\b(hang myself|jump off|goodbye forever)\b/i
    ]
  },
  {
    category: "crisis",
    patterns: [
      /\b(i am in crisis|i'm in crisis|crisis right now)\b/i,
      /\b(cannot stay safe|can't stay safe|cant stay safe|not safe with myself)\b/i,
      /\b(no reason to live|tonight is the night)\b/i,
      /\b(immediate danger|emergency)\b/i
    ]
  }
];

export function detectSafetyRisk(text) {
  const matchedCategories = safetyPatterns
    .filter((group) => group.patterns.some((pattern) => pattern.test(text)))
    .map((group) => group.category);

  return {
    triggered: matchedCategories.length > 0,
    level: matchedCategories.length > 0 ? "crisis" : "none",
    categories: matchedCategories
  };
}

export function buildSafetyResponse(safetyRisk) {
  return {
    triggered: true,
    level: safetyRisk.level,
    categories: safetyRisk.categories,
    message:
      "Safety warning: I am concerned about your immediate safety. I cannot provide live crisis support here. If you might hurt yourself or someone else, it may be safest to contact emergency services now. If you are in the U.S., you can call or text 988, or use the 988 Lifeline chat. If you are outside the U.S., consider contacting your local emergency number or a trusted crisis line. If you can, try to move away from anything you could use to hurt yourself and reach out to someone you trust right now.",
    resources: [
      {
        label: "Immediate danger",
        action: "Call your local emergency number now"
      },
      {
        label: "988 Suicide & Crisis Lifeline",
        action: "Call or text 988 in the U.S.",
        url: "https://988lifeline.org"
      },
      {
        label: "Trusted person",
        action: "Contact someone nearby who can stay with you or help you get support"
      }
    ],
    canContinueAiChat: false
  };
}
