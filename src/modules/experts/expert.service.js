import {
  countWaitlistEntries,
  getWaitlistEntryByUserId,
  listActiveExpertSpecialties,
  upsertWaitlistEntry
} from "./expert.repository.js";

export const defaultExpertFocusAreas = ["stress", "sleep", "relationships", "mindfulness", "cbt"];

export function buildExpertComingSoon({ waitlistCount = 0, specialties = defaultExpertFocusAreas } = {}) {
  return {
    status: "coming_soon",
    message:
      "Uzman eşleştirme sistemimiz çok yakında aktif olacak. Öncelikli erişim listesine katılarak ilk bilgilendirilenlerden biri olabilirsin.",
    waitlist: {
      enabled: true,
      signupEndpoint: "/api/experts/waitlist",
      count: waitlistCount
    },
    matching: {
      available: false,
      supportedNeeds: specialties.length > 0 ? specialties : defaultExpertFocusAreas,
      expectedLaunchPhase: "post-mvp"
    }
  };
}

export function formatWaitlistEntry(entry) {
  if (!entry) {
    return {
      joined: false,
      status: "not_joined"
    };
  }

  return {
    joined: true,
    id: entry.id,
    status: entry.status,
    email: entry.email,
    preferredFocus: entry.preferred_focus,
    note: entry.note,
    createdAt: entry.created_at,
    updatedAt: entry.updated_at
  };
}

export async function getExpertPlaceholder() {
  const [waitlistCount, specialties] = await Promise.all([
    countWaitlistEntries(),
    listActiveExpertSpecialties()
  ]);

  return buildExpertComingSoon({ waitlistCount, specialties });
}

export async function joinExpertWaitlist({ userId, email, preferredFocus = [], note }) {
  const entry = await upsertWaitlistEntry({ userId, email, preferredFocus, note });
  return {
    message: "You are on the expert matching waitlist.",
    waitlist: formatWaitlistEntry(entry)
  };
}

export async function getExpertWaitlistStatus(userId) {
  return {
    waitlist: formatWaitlistEntry(await getWaitlistEntryByUserId(userId))
  };
}
