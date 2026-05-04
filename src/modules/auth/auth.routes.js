import { Router } from "express";
import { z } from "zod";
import { asyncHandler, validate } from "../../utils/http.js";
import {
  loginUser,
  registerUser,
  resendVerificationEmail,
  verifyEmailToken
} from "./auth.service.js";

export const authRouter = Router();

const credentialsSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(128)
});

const registerProfileSchema = {
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
  marketingConsent: z.boolean().optional(),
  consents: z.record(z.unknown()).optional()
};

export function verificationStatus(result) {
  return result?.sent === false ? 503 : 202;
}

authRouter.post(
  "/register",
  validate(credentialsSchema.extend(registerProfileSchema)),
  asyncHandler(async (req, res) => {
    const result = await registerUser(req.body, {
      ipAddress: req.ip,
      userAgent: req.get("user-agent")
    });
    res.status(201).json(result);
  })
);

authRouter.post(
  "/login",
  validate(credentialsSchema),
  asyncHandler(async (req, res) => {
    res.json(await loginUser(req.body));
  })
);

authRouter.post(
  "/forgot-password",
  validate(z.object({ email: z.string().email() })),
  asyncHandler(async (_req, res) => {
    res.status(202).json({
      status: "placeholder",
      message: "Password reset flow will be enabled soon."
    });
  })
);

authRouter.post(
  "/email-verification",
  validate(z.object({ email: z.string().email() })),
  asyncHandler(async (req, res) => {
    const result = await resendVerificationEmail(req.body);
    res.status(verificationStatus(result)).json(result);
  })
);

authRouter.post(
  "/resend-verification",
  validate(z.object({ email: z.string().email() })),
  asyncHandler(async (req, res) => {
    const result = await resendVerificationEmail(req.body);
    res.status(verificationStatus(result)).json(result);
  })
);

authRouter.get(
  "/verify-email",
  validate(z.object({ token: z.string().min(20).max(256) }), "query"),
  asyncHandler(async (req, res) => {
    res.json(await verifyEmailToken(req.query));
  })
);
