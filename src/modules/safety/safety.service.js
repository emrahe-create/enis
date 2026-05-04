const safetyPatterns = [
  {
    category: "self_harm",
    patterns: [
      /\b(kill myself|end my life|take my life)\b/i,
      /\b(suicide|suicidal)\b/i,
      /\b(i want to die|want to die|do not want to live|don't want to live|dont want to live)\b/i,
      /\b(harm myself|hurt myself|cut myself|overdose)\b/i,
      /\b(hang myself|jump off|goodbye forever)\b/i,
      /\b(kendime zarar|intihar|ölmek istiyorum|yasamak istemiyorum|yaşamak istemiyorum)\b/i
    ]
  },
  {
    category: "crisis",
    patterns: [
      /\b(i am in crisis|i'm in crisis|crisis right now)\b/i,
      /\b(cannot stay safe|can't stay safe|cant stay safe|not safe with myself)\b/i,
      /\b(no reason to live|tonight is the night)\b/i,
      /\b(immediate danger|emergency)\b/i,
      /\b(güvende değilim|guvende degilim|dayanamıyorum|dayanamiyorum)\b/i
    ]
  },
  {
    category: "abuse",
    patterns: [
      /\b(abuse|abused|abusing me|hit me|beats me|beating me|violent at home)\b/i,
      /(istismar|şiddet|siddet|bana vuruyor|evde güvende değilim|evde guvende degilim)/i
    ]
  },
  {
    category: "severe_distress",
    patterns: [
      /\b(severe distress|panic attack|cannot breathe|can't breathe|cant breathe|losing control)\b/i,
      /(çok kötüyüm|cok kotuyum|nefes alamıyorum|nefes alamiyorum|kontrolümü kaybediyorum|kontrolumu kaybediyorum)/i
    ]
  }
];

const immediateDangerPatterns = [
  /\b(right now|tonight|immediate danger|emergency|cannot stay safe|can't stay safe|cant stay safe)\b/i,
  /\b(şu an|su an|bu gece|acil|güvende değilim|guvende degilim)\b/i
];

export function detectSafetyRisk(text) {
  const matchedCategories = safetyPatterns
    .filter((group) => group.patterns.some((pattern) => pattern.test(text)))
    .map((group) => group.category);

  return {
    triggered: matchedCategories.length > 0,
    level: matchedCategories.length > 0 ? "crisis" : "none",
    categories: matchedCategories,
    immediateDanger: matchedCategories.length > 0 && immediateDangerPatterns.some((pattern) => pattern.test(text))
  };
}

export function buildSafetyResponse(safetyRisk) {
  return {
    triggered: true,
    level: safetyRisk.level,
    categories: safetyRisk.categories,
    immediateDanger: Boolean(safetyRisk.immediateDanger),
    message:
      "Bu biraz ağır görünüyor… bunu tek başına taşımak zorunda değilsin. Güvendiğin biriyle konuşman iyi gelebilir. İstersen bulunduğun yerde destek hatlarını birlikte bulabiliriz.",
    resources: [
      {
        label: "Acil tehlike",
        action: "Türkiye'deysen 112 Acil Çağrı Merkezi'ni arayabilirsin."
      },
      {
        label: "Yerel destek",
        action: "Bulunduğun yerdeki acil destek hatlarını birlikte bulabiliriz."
      },
      {
        label: "Güvendiğin kişi",
        action: "Yakınındaki güvendiğin biriyle konuşmak iyi gelebilir."
      }
    ],
    canContinueAiChat: false
  };
}
