import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../../middleware/auth.js";
import { asyncHandler, validate } from "../../utils/http.js";
import {
  getExpertPlaceholder,
  getExpertWaitlistStatus,
  joinExpertWaitlist
} from "./expert.service.js";

export const expertRouter = Router();

expertRouter.use(requireAuth);

const waitlistSchema = z.object({
  email: z.string().email().optional(),
  preferredFocus: z.array(z.string().min(1).max(80)).max(8).default([]),
  note: z.string().max(1000).optional()
});

expertRouter.get(
  "/matching",
  asyncHandler(async (_req, res) => {
    res.status(202).json(await getExpertPlaceholder());
  })
);

expertRouter.get(
  "/waitlist",
  asyncHandler(async (req, res) => {
    res.json(await getExpertWaitlistStatus(req.user.sub));
  })
);

expertRouter.post(
  "/waitlist",
  validate(waitlistSchema),
  asyncHandler(async (req, res) => {
    res.status(201).json(
      await joinExpertWaitlist({
        userId: req.user.sub,
        email: req.body.email || req.user.email,
        preferredFocus: req.body.preferredFocus,
        note: req.body.note
      })
    );
  })
);
