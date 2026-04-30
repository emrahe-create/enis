import { ApiError } from "../../utils/http.js";

export const enisCompany = {
  brand: "Enis",
  owner: "EQ Bilişim",
  legalName: "EQ Bilişim Teknolojileri Ltd. Şti.",
  address:
    "Fatih Sultan Mehmet Mah. Poligon Cad. Buyaka 2 Sitesi No:8C/1 P.K. 34771 Ümraniye / İstanbul / Türkiye",
  taxOffice: "Alemdağ V.D.",
  taxNumber: "3290486809",
  email: "info@eqbilisim.com.tr",
  phone: "+90 216 225 66 19",
  mobile: "+90 532 384 82 64"
};

export const enisIdentityCopy =
  "Enis is an AI wellness companion for supportive reflection.";

const legalVersion = "2026-04-29";
const updatedAt = "2026-04-29";

const wellnessDisclaimer = [
  enisIdentityCopy,
  "Enis is not psychotherapy.",
  "Enis does not diagnose or treat.",
  "AI responses are for wellness and emotional support only.",
  "In crisis situations, users must contact emergency services or qualified professionals."
].join(" ");

function documentContent(...sections) {
  return [wellnessDisclaimer, ...sections].join("\n\n");
}

export const legalDocuments = {
  "privacy-policy": {
    slug: "privacy-policy",
    title: "Privacy Policy",
    version: legalVersion,
    updatedAt,
    company: enisCompany,
    content: documentContent(
      "EQ Bilişim processes account, profile, subscription, chat, consent, and usage data to provide the Enis app experience.",
      "Users may request access, export, correction, or deletion of their data through the account endpoints or by contacting EQ Bilişim.",
      "Marketing communication is optional and can be refused without blocking core account access."
    )
  },
  "kvkk-clarification": {
    slug: "kvkk-clarification",
    title: "KVKK Clarification Text",
    version: legalVersion,
    updatedAt,
    company: enisCompany,
    content: documentContent(
      "Personal data is processed under applicable Turkish data protection rules for account creation, app security, subscription tracking, user support, and consent records.",
      "The data controller is EQ Bilişim Teknolojileri Ltd. Şti. Users may contact EQ Bilişim for KVKK-related requests.",
      "Consent records may include consent type, version, acceptance time, IP address, and user agent."
    )
  },
  "explicit-consent": {
    slug: "explicit-consent",
    title: "Explicit Consent Text",
    version: legalVersion,
    updatedAt,
    company: enisCompany,
    content: documentContent(
      "Optional explicit consent may be requested for product improvement, personalization, and optional communication preferences.",
      "Explicit consent is separate from mandatory signup notices and can be refused where it is optional.",
      "Users may update optional consent preferences through account settings or by contacting EQ Bilişim."
    )
  },
  "terms-of-use": {
    slug: "terms-of-use",
    title: "Terms of Use",
    version: legalVersion,
    updatedAt,
    company: enisCompany,
    content: documentContent(
      "Users agree to use Enis as a wellness and emotional support companion only.",
      "Users should not rely on Enis for emergency decisions, professional evaluation, or regulated professional services.",
      "EQ Bilişim may update app features, subscription rules, safety flows, and legal documents as the product evolves."
    )
  },
  "distance-sales-agreement": {
    slug: "distance-sales-agreement",
    title: "Distance Sales Agreement",
    version: legalVersion,
    updatedAt,
    company: enisCompany,
    content: documentContent(
      "Premium subscription purchases are provided digitally by EQ Bilişim for the Enis app.",
      "Before starting a premium purchase, users must accept the active distance sales agreement version.",
      "Subscription price, billing period, renewal details, and cancellation options are shown in the payment flow before checkout."
    )
  },
  "cancellation-refund-policy": {
    slug: "cancellation-refund-policy",
    title: "Cancellation and Refund Policy",
    version: legalVersion,
    updatedAt,
    company: enisCompany,
    content: documentContent(
      "Users can cancel premium renewal according to the app store, Stripe, or payment provider flow used for purchase.",
      "Refund requests are reviewed according to applicable law, payment provider rules, and the digital subscription details shown before checkout.",
      "Before starting a premium purchase, users must accept the active cancellation and refund policy version."
    )
  },
  disclaimer: {
    slug: "disclaimer",
    title: "Wellness Disclaimer",
    version: legalVersion,
    updatedAt,
    company: enisCompany,
    content: documentContent(
      "Enis offers reflective, supportive language for everyday emotional wellness.",
      "Enis may misunderstand context, tone, urgency, or personal circumstances.",
      "Users remain responsible for seeking appropriate external help when a situation feels unsafe, urgent, or beyond app-based support."
    )
  },
  faq: {
    slug: "faq",
    title: "FAQ",
    version: legalVersion,
    updatedAt,
    company: enisCompany,
    content: documentContent(
      "What is Enis? Enis is an AI wellness companion owned by EQ Bilişim.",
      "Can Enis replace professional help? No. Enis is for wellness and emotional support only.",
      "Does Enis replace human connection? No. Enis is a digital wellness tool and should not replace support from trusted people or qualified professionals.",
      "What happens in crisis messages? Enis stops normal chat and encourages external help."
    )
  }
};

export function getLegalDocument(slug) {
  const document = legalDocuments[slug];
  if (!document) throw new ApiError(404, "Legal document not found");
  return document;
}

export function listLegalDocuments() {
  return Object.values(legalDocuments);
}
