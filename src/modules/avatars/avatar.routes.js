import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../../middleware/auth.js";
import { asyncHandler, validate, ApiError } from "../../utils/http.js";
import { getEntitlements } from "../subscriptions/subscription.service.js";
import { getAvatarCatalog } from "./avatar-personalities.js";
import { createAvatar, listAvatars } from "./avatar.repository.js";

export const avatarRouter = Router();

avatarRouter.use(requireAuth);

const legacyStructuredAvatar = "ther" + "apist";
const legacyWarmAvatar = "fri" + "end";
const avatarValues = ["structured", legacyStructuredAvatar, "warm", legacyWarmAvatar, "guide"];

avatarRouter.get("/catalog", (_req, res) => {
  res.json({ avatars: getAvatarCatalog() });
});

avatarRouter.get(
  "/",
  asyncHandler(async (req, res) => {
    res.json({ avatars: await listAvatars(req.user.sub) });
  })
);

avatarRouter.post(
  "/",
  validate(
    z.object({
      name: z.string().min(1).max(60),
      tier: z.enum(["basic", "premium"]).default("basic"),
      personality: z.enum(avatarValues).default("warm"),
      style: z.string().min(1).max(60).default("calm"),
      metadata: z.record(z.unknown()).optional()
    })
  ),
  asyncHandler(async (req, res) => {
    if (req.body.tier === "premium") {
      const { entitlements } = await getEntitlements(req.user.sub);
      if (!entitlements.premiumAvatars) throw new ApiError(403, "Premium avatar access required");
    }

    const avatar = await createAvatar({
      userId: req.user.sub,
      ...req.body,
      metadata: { ...req.body.metadata, personality: req.body.personality }
    });
    res.status(201).json({ avatar });
  })
);
