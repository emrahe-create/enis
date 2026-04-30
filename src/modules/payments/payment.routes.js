import express, { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../../middleware/auth.js";
import { asyncHandler, ApiError, validate } from "../../utils/http.js";
import { acceptPremiumPurchaseConsents } from "../legal/consent.service.js";
import { findUserById } from "../users/user.repository.js";
import { createCheckoutSession, constructStripeEvent, handleStripeEvent } from "./payment.service.js";

export const paymentRouter = Router();
export const stripeWebhookRouter = Router();

paymentRouter.use(requireAuth);

paymentRouter.post(
  "/checkout-session",
  validate(z.object({ consents: z.record(z.unknown()).optional() })),
  asyncHandler(async (req, res) => {
    const user = await findUserById(req.user.sub);
    if (!user) throw new ApiError(404, "User not found");

    await acceptPremiumPurchaseConsents({
      userId: user.id,
      consents: req.body.consents,
      ipAddress: req.ip,
      userAgent: req.get("user-agent")
    });

    const session = await createCheckoutSession({ userId: user.id, email: user.email });
    res.status(201).json({ id: session.id, url: session.url });
  })
);

stripeWebhookRouter.post(
  "/stripe",
  express.raw({ type: "application/json" }),
  asyncHandler(async (req, res) => {
    const signature = req.get("stripe-signature");
    if (!signature) throw new ApiError(400, "Missing Stripe signature");

    const event = constructStripeEvent(req.body, signature);
    const result = await handleStripeEvent(event);
    res.json({ received: true, ...result });
  })
);
