import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../../middleware/auth.js";
import { asyncHandler, validate } from "../../utils/http.js";
import { dailyCheckInOptions, getTodayCheckInState, saveDailyCheckIn } from "./checkin.service.js";

export const checkInRouter = Router();

checkInRouter.use(requireAuth);

const checkInSchema = z.object({
  mood: z.enum(dailyCheckInOptions),
  note: z.string().trim().max(500).optional()
});

checkInRouter.post(
  "/",
  validate(checkInSchema),
  asyncHandler(async (req, res) => {
    res.status(201).json(await saveDailyCheckIn({ userId: req.user.sub, ...req.body }));
  })
);

checkInRouter.get(
  "/today",
  asyncHandler(async (req, res) => {
    res.json(await getTodayCheckInState(req.user.sub));
  })
);
