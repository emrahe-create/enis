import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../../middleware/auth.js";
import { asyncHandler, validate, ApiError } from "../../utils/http.js";
import { deleteUserById, exportUserData, findUserById, updateUserProfile } from "./user.repository.js";

export const userRouter = Router();

userRouter.use(requireAuth);

const userProfileSchema = z.object({
  displayName: z.string().trim().min(1).max(80).optional(),
  fullName: z.string().trim().min(1).max(120).optional(),
  birthYear: z.number().int().min(1900).max(2026).optional(),
  gender: z.string().trim().min(1).max(40).optional(),
  city: z.string().trim().min(1).max(80).optional(),
  occupation: z.string().trim().min(1).max(120).optional(),
  relationshipStatus: z.string().trim().min(1).max(80).optional(),
  sleepQuality: z.string().trim().min(1).max(80).optional(),
  mainGoal: z.string().trim().min(1).max(240).optional(),
  preferredAvatar: z.string().trim().min(1).max(40).optional(),
  avatarName: z.string().trim().min(1).max(40).optional(),
  avatarCharacterId: z.string().trim().min(1).max(40).optional(),
  avatarCharacterName: z.string().trim().min(1).max(40).optional(),
  avatarVoiceStyle: z.string().trim().min(1).max(40).optional(),
  avatarVisualStyle: z.string().trim().min(1).max(160).optional(),
  avatarPersonalityStyle: z.string().trim().min(1).max(160).optional(),
  notificationConsent: z.boolean().optional(),
  marketingConsent: z.boolean().optional()
});

userRouter.get(
  "/me",
  asyncHandler(async (req, res) => {
    const user = await findUserById(req.user.sub);
    if (!user) throw new ApiError(404, "User not found");
    res.json({ user });
  })
);

userRouter.patch(
  "/me",
  validate(userProfileSchema),
  asyncHandler(async (req, res) => {
    const user = await updateUserProfile(req.user.sub, req.body);
    if (!user) throw new ApiError(404, "User not found");
    res.json({ user });
  })
);

userRouter.get(
  "/me/export",
  asyncHandler(async (req, res) => {
    const data = await exportUserData(req.user.sub);
    if (!data.user) throw new ApiError(404, "User not found");
    res.json({ exportedAt: new Date().toISOString(), data });
  })
);

userRouter.delete(
  "/me",
  asyncHandler(async (req, res) => {
    const deleted = await deleteUserById(req.user.sub);
    if (!deleted) throw new ApiError(404, "User not found");
    res.json({ deleted: true });
  })
);
