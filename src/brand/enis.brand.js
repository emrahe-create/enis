export const enisBrand = {
  appName: "enis",
  ownerCompany: "EQ Bilişim",
  product: "AI wellness companion app",
  tagline: {
    en: "Say what’s on your mind.",
    tr: "İçinden geçenleri söyle."
  },
  voice: {
    positioning: "supportive but neutral",
    avoid: [
      "claims of personal relationship roles",
      "claims of professional care roles",
      "claims of replacing human connection",
      "need-based attachment language"
    ]
  },
  colors: {
    primaryBlue: "#5D8CFF",
    softBlue: "#7CB7FF",
    lavender: "#A78BFA",
    softPurple: "#C084FC",
    deepNavy: "#21184A",
    background: "#F8F7FF",
    white: "#FFFFFF"
  },
  typography: {
    family: ["Inter", "SF Pro", "system-ui", "sans-serif"],
    style: "rounded modern sans-serif"
  },
  copy: {
    onboarding: [
      {
        en: "Say what’s on your mind.",
        tr: "İçinden geçenleri söyle."
      },
      {
        en: "There’s no pressure here.",
        tr: "Burada bir zorunluluk yok."
      },
      {
        en: "You can start anytime.",
        tr: "Ne zaman istersen başlayabilirsin."
      }
    ],
    cta: {
      start: {
        en: "Start",
        tr: "Başla"
      },
      login: {
        en: "I already have an account",
        tr: "Zaten hesabım var"
      }
    },
    disclaimer: {
      en: "Enis is an AI wellness companion, not therapy, diagnosis, or treatment.",
      tr: "Enis bir yapay zeka iyi oluş eşlikçisidir; terapi, tanı ya da tedavi değildir."
    }
  },
  assets: {
    logo: "/assets/brand/logo-enis.svg",
    appIcon: "/assets/brand/app-icon.svg"
  }
};
