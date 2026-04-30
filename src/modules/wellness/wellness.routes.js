import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../../middleware/auth.js";
import { asyncHandler, validate } from "../../utils/http.js";
import { createWellnessEntry, listWellnessEntries } from "./wellness.repository.js";

export const wellnessRouter = Router();

wellnessRouter.use(requireAuth);

wellnessRouter.get("/tools", (_req, res) => {
  res.json({
    tools: [
      {
        id: "breathing_box",
        type: "breathing",
        name: "Box Breathing",
        config: { inhaleSeconds: 4, holdSeconds: 4, exhaleSeconds: 4, rounds: 4 }
      },
      {
        id: "meditation_body_scan",
        type: "meditation",
        name: "Body Scan",
        config: { durationMinutes: 8, guidance: "gentle" }
      },
      {
        id: "cbt_journal",
        type: "cbt_journal",
        name: "CBT Thought Journal",
        prompts: ["Situation", "Automatic thought", "Emotion", "Evidence", "Balanced thought"]
      }
    ]
  });
});

wellnessRouter.get(
  "/entries",
  asyncHandler(async (req, res) => {
    res.json({ entries: await listWellnessEntries(req.user.sub) });
  })
);

wellnessRouter.post(
  "/entries",
  validate(
    z.object({
      toolType: z.enum(["breathing", "meditation", "cbt_journal"]),
      payload: z.record(z.unknown()).optional(),
      completedAt: z.string().datetime().optional()
    })
  ),
  asyncHandler(async (req, res) => {
    const entry = await createWellnessEntry({ userId: req.user.sub, ...req.body });
    res.status(201).json({ entry });
  })
);
