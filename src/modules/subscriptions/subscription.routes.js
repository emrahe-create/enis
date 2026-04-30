import { Router } from "express";
import { requireAuth } from "../../middleware/auth.js";
import { asyncHandler } from "../../utils/http.js";
import { beginPremiumTrial, getEntitlements } from "./subscription.service.js";

export const subscriptionRouter = Router();

subscriptionRouter.use(requireAuth);

subscriptionRouter.get(
  "/me",
  asyncHandler(async (req, res) => {
    res.json(await getEntitlements(req.user.sub));
  })
);

subscriptionRouter.post(
  "/trial",
  asyncHandler(async (req, res) => {
    await beginPremiumTrial(req.user.sub);
    res.status(201).json(await getEntitlements(req.user.sub));
  })
);
