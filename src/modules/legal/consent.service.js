import { ApiError } from "../../utils/http.js";
import { getLegalDocument } from "./legal.service.js";
import { recordUserConsent } from "./consent.repository.js";

export const mandatorySignupConsents = [
  "kvkk_clarification_seen",
  "privacy_policy",
  "terms_of_use",
  "wellness_disclaimer"
];

export const optionalConsentTypes = [
  "explicit_consent",
  "marketing_permission",
  "distance_sales",
  "distance_sales_agreement",
  "cancellation_refund_policy"
];

export const premiumPurchaseConsentTypes = ["distance_sales", "cancellation_refund_policy"];

const consentLegalSlugMap = {
  kvkk_clarification_seen: "kvkk-clarification",
  privacy_policy: "privacy-policy",
  terms_of_use: "terms-of-use",
  wellness_disclaimer: "disclaimer",
  explicit_consent: "explicit-consent",
  marketing_permission: "privacy-policy",
  distance_sales: "distance-sales-agreement",
  distance_sales_agreement: "distance-sales-agreement",
  cancellation_refund_policy: "cancellation-refund-policy"
};

const allowedConsentTypes = [...mandatorySignupConsents, ...optionalConsentTypes];

export function normalizeConsentInput(consents = {}) {
  return Object.entries(consents || {}).reduce((normalized, [type, accepted]) => {
    normalized[type] = Boolean(accepted);
    return normalized;
  }, {});
}

function versionForConsent(consentType) {
  const slug = consentLegalSlugMap[consentType];
  if (!slug) throw new ApiError(400, `Unsupported consent type: ${consentType}`);
  return getLegalDocument(slug).version;
}

export function buildConsentRecords(consents = {}, { requiredTypes = [] } = {}) {
  const normalized = normalizeConsentInput(consents);
  const missing = requiredTypes.filter((type) => normalized[type] !== true);

  if (missing.length > 0) {
    throw new ApiError(400, "Missing required consent", { missing });
  }

  return allowedConsentTypes
    .filter((type) => normalized[type] === true)
    .map((consentType) => ({
      consentType,
      version: versionForConsent(consentType)
    }));
}

export function buildSignupConsentRecords(consents = {}) {
  return buildConsentRecords(consents, { requiredTypes: mandatorySignupConsents });
}

export function buildPremiumPurchaseConsentRecords(consents = {}) {
  const normalized = normalizeConsentInput(consents);
  if (normalized.distance_sales_agreement === true) {
    normalized.distance_sales = true;
  }

  return buildConsentRecords(normalized, { requiredTypes: premiumPurchaseConsentTypes }).filter((record) =>
    premiumPurchaseConsentTypes.includes(record.consentType)
  );
}

export async function storeConsentRecords({
  userId,
  records,
  ipAddress = null,
  userAgent = null
}) {
  return Promise.all(
    records.map((record) =>
      recordUserConsent({
        userId,
        consentType: record.consentType,
        version: record.version,
        ipAddress,
        userAgent
      })
    )
  );
}

export async function acceptSignupConsents({ userId, consents, ipAddress, userAgent }) {
  const records = buildSignupConsentRecords(consents);
  return storeConsentRecords({ userId, records, ipAddress, userAgent });
}

export async function acceptPremiumPurchaseConsents({ userId, consents, ipAddress, userAgent }) {
  const records = buildPremiumPurchaseConsentRecords(consents);
  return storeConsentRecords({ userId, records, ipAddress, userAgent });
}
