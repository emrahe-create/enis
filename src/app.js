import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import rateLimit from "express-rate-limit";
import { errorHandler, notFound } from "./middleware/errorHandler.js";
import { authRouter } from "./modules/auth/auth.routes.js";
import { userRouter } from "./modules/users/user.routes.js";
import { subscriptionRouter } from "./modules/subscriptions/subscription.routes.js";
import { chatRouter } from "./modules/chat/chat.routes.js";
import { avatarRouter } from "./modules/avatars/avatar.routes.js";
import { analyticsRouter } from "./modules/analytics/analytics.routes.js";
import { wellnessRouter } from "./modules/wellness/wellness.routes.js";
import { expertRouter } from "./modules/experts/expert.routes.js";
import { legalRouter } from "./modules/legal/legal.routes.js";
import { paymentRouter, stripeWebhookRouter } from "./modules/payments/payment.routes.js";

export const allowedCorsOrigins = [
  "https://enisapp.com",
  "https://www.enisapp.com",
  "https://api.enisapp.com"
];

const localDevelopmentOriginPattern = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

export function isCorsOriginAllowed(origin, nodeEnv = process.env.NODE_ENV || "development") {
  if (!origin) return true;
  if (allowedCorsOrigins.includes(origin)) return true;
  return nodeEnv !== "production" && localDevelopmentOriginPattern.test(origin);
}

export function createApp() {
  const app = express();
  const nodeEnv = process.env.NODE_ENV || "development";

  if (nodeEnv === "production") {
    app.set("trust proxy", 1);
  }

  app.use(helmet());
  app.use(
    cors({
      origin(origin, callback) {
        callback(null, isCorsOriginAllowed(origin));
      },
      credentials: true
    })
  );
  app.use(morgan(nodeEnv === "production" ? "combined" : "dev"));
  app.use(rateLimit({ windowMs: 60_000, limit: 120, standardHeaders: true, legacyHeaders: false }));

  app.get("/health", (_req, res) => {
    res.json({ status: "ok", service: "ai-wellness-backend" });
  });

  app.use("/api/payments/webhook", stripeWebhookRouter);
  app.use(express.json({ limit: "1mb" }));

  app.use("/api/auth", authRouter);
  app.use("/api/users", userRouter);
  app.use("/api/subscriptions", subscriptionRouter);
  app.use("/api/chat", chatRouter);
  app.use("/api/avatars", avatarRouter);
  app.use("/api/analytics", analyticsRouter);
  app.use("/api/wellness", wellnessRouter);
  app.use("/api/experts", expertRouter);
  app.use("/api/legal", legalRouter);
  app.use("/api/payments", paymentRouter);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}
