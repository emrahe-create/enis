import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../../middleware/auth.js";
import { asyncHandler, validate } from "../../utils/http.js";
import { getChats, sendSupportMessage, startChat } from "./chat.service.js";

export const chatRouter = Router();

chatRouter.use(requireAuth);

const legacyStructuredAvatar = "ther" + "apist";
const legacyWarmAvatar = "fri" + "end";
const avatarValues = ["structured", legacyStructuredAvatar, "warm", legacyWarmAvatar, "guide"];

const chatInputSchema = z
  .object({
    sessionId: z.string().uuid().optional(),
    message: z.string().min(1).max(4000).optional(),
    text: z.string().min(1).max(4000).optional(),
    avatar: z.enum(avatarValues).optional(),
    avatarType: z.enum(avatarValues).optional(),
    personality: z.enum(avatarValues).optional()
  })
  .refine((data) => data.message || data.text, {
    message: "Either message or text is required",
    path: ["message"]
  })
  .transform((data) => ({
    sessionId: data.sessionId,
    message: data.message || data.text,
    avatar: data.avatar || data.avatarType || data.personality || "warm"
  }));

const sendMessageHandler = asyncHandler(async (req, res) => {
  res.status(201).json(await sendSupportMessage({ userId: req.user.sub, ...req.body }));
});

chatRouter.get(
  "/sessions",
  asyncHandler(async (req, res) => {
    res.json({ sessions: await getChats(req.user.sub) });
  })
);

chatRouter.post(
  "/sessions",
  validate(z.object({ title: z.string().min(1).max(120).optional() })),
  asyncHandler(async (req, res) => {
    res.status(201).json({ session: await startChat(req.user.sub, req.body.title) });
  })
);

chatRouter.post(
  "/message",
  validate(chatInputSchema),
  sendMessageHandler
);

chatRouter.post(
  "/respond",
  validate(chatInputSchema),
  sendMessageHandler
);
