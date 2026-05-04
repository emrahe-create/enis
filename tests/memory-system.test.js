import test from "node:test";
import assert from "node:assert/strict";
import { resolveAvatarPersonality } from "../src/modules/avatars/avatar-personalities.js";
import {
  buildOpenAiMessages,
  resolveAvatarMode
} from "../src/modules/chat/chat.service.js";
import {
  extractMemoryCandidates,
  formatMemoryPromptBlock,
  freeMemoryLimit,
  memoryLimitFor,
  mergeMemoryValue,
  premiumMemoryLimit,
  selectRelevantMemoriesForMessage
} from "../src/modules/memory/memory.service.js";

const emotion = {
  stress: "some",
  anxietySignals: "some",
  moodLevel: "mixed"
};

test("memory candidate is created for a repeated companion topic", () => {
  const candidates = extractMemoryCandidates(
    "İş yine çok yoğun, patronumla toplantılar beni bugün de bayağı yordu."
  );

  assert.equal(candidates[0].key, "work_stress");
  assert.match(candidates[0].value, /İş tarafında/);
  assert.equal(candidates.length <= 2, true);
});

test("memory value is updated by key instead of duplicated", () => {
  const first = extractMemoryCandidates("İş tarafı bu hafta çok baskılı hissettiriyor.");
  const second = extractMemoryCandidates("İş toplantıları yine üst üste geldi.");
  const keys = new Set([...first, ...second].map((candidate) => candidate.key));
  const merged = mergeMemoryValue(first[0].value, "İş toplantıları özellikle yorucu geliyor.", {
    premium: true
  });

  assert.equal(keys.size, 1);
  assert.equal(keys.has("work_stress"), true);
  assert.match(merged, /İş tarafında/);
  assert.match(merged, /toplantıları/);
});

test("unsafe or diagnostic text is not stored as memory", () => {
  assert.deepEqual(
    extractMemoryCandidates("Bana depresyon teşhisi kondu ve ilaç kullanıyorum."),
    []
  );
  assert.deepEqual(
    extractMemoryCandidates("Kendime zarar vermek istiyorum ve yalnızım."),
    []
  );
});

test("memory limits differ for free and premium users", () => {
  assert.equal(memoryLimitFor({ premium: false }), freeMemoryLimit);
  assert.equal(memoryLimitFor({ premium: true }), premiumMemoryLimit);
});

test("memory is retrieved and injected into the chat prompt", () => {
  const memories = [
    {
      id: "00000000-0000-0000-0000-000000000001",
      key: "work_stress",
      value: "İşinde yoğunluk ve baskı hissettiğini sık sık söylüyor.",
      importance: 4
    }
  ];
  const relevant = selectRelevantMemoriesForMessage(memories, "İş bugün yine çok ağır geldi.");
  const block = formatMemoryPromptBlock({
    memories: relevant,
    recentMessages: [{ role: "user", text: "Dün de toplantılardan bahsetmiştim." }],
    message: "İş bugün yine çok ağır geldi."
  });
  const messages = buildOpenAiMessages({
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarPersonality: resolveAvatarPersonality("warm"),
    message: "İş bugün yine çok ağır geldi.",
    emotion,
    persistentMemories: relevant,
    recentConversationMessages: [{ role: "user", text: "Dün de toplantılardan bahsetmiştim." }]
  });

  assert.equal(relevant.length, 1);
  assert.match(block, /Use the following memories only if relevant/);
  assert.match(block, /work_stress/);
  assert.ok(messages.some((item) => item.content.includes("MEMORIES:")));
  assert.ok(messages.some((item) => item.content.includes("Daha önce iş tarafının")));
});

test("memory is only injected when relevant to the current message", () => {
  const memories = [
    {
      id: "00000000-0000-0000-0000-000000000001",
      key: "sleep",
      value: "Uyku düzeninin zaman zaman bozulduğunu söylüyor.",
      importance: 4
    }
  ];
  const relevant = selectRelevantMemoriesForMessage(memories, "Bugün arkadaşlarımla film izledim.");
  const messages = buildOpenAiMessages({
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarPersonality: resolveAvatarPersonality("warm"),
    message: "Bugün arkadaşlarımla film izledim.",
    emotion,
    persistentMemories: relevant
  });

  assert.deepEqual(relevant, []);
  assert.equal(messages.some((item) => item.content.includes("Uyku düzeni")), false);
});
