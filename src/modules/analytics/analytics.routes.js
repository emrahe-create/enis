import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../../middleware/auth.js";
import { asyncHandler, validate } from "../../utils/http.js";
import {
  analyzeEmotion,
  formatEmotionAnalysis,
  getEmotionSummary,
  saveEmotionAnalysis
} from "./emotion.service.js";

export const analyticsRouter = Router();

analyticsRouter.use(requireAuth);

analyticsRouter.post(
  "/emotion",
  validate(z.object({ text: z.string().min(1).max(5000), source: z.string().default("manual") })),
  asyncHandler(async (req, res) => {
    const analysis = await analyzeEmotion(req.body.text);
    await saveEmotionAnalysis({
      userId: req.user.sub,
      source: req.body.source,
      analysis
    });
    res.status(201).json({ analysis: formatEmotionAnalysis(analysis) });
  })
);

analyticsRouter.get(
  "/emotion/summary",
  asyncHandler(async (req, res) => {
    res.json({ summary: await getEmotionSummary(req.user.sub) });
  })
);
