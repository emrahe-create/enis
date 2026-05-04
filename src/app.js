import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import rateLimit from "express-rate-limit";
import { randomUUID } from "node:crypto";
import { errorHandler, notFound } from "./middleware/errorHandler.js";
import { authRouter } from "./modules/auth/auth.routes.js";
import { userRouter } from "./modules/users/user.routes.js";
import { subscriptionRouter } from "./modules/subscriptions/subscription.routes.js";
import { chatRouter } from "./modules/chat/chat.routes.js";
import { getLastResponseDebug } from "./modules/chat/chat.service.js";
import { avatarRouter } from "./modules/avatars/avatar.routes.js";
import { analyticsRouter } from "./modules/analytics/analytics.routes.js";
import { wellnessRouter } from "./modules/wellness/wellness.routes.js";
import { expertRouter } from "./modules/experts/expert.routes.js";
import { legalRouter } from "./modules/legal/legal.routes.js";
import { memoryRouter } from "./modules/memory/memory.routes.js";
import { checkInRouter } from "./modules/checkins/checkin.routes.js";
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
  return localDevelopmentOriginPattern.test(origin);
}

export const corsOptions = {
  origin(origin, callback) {
    if (isCorsOriginAllowed(origin)) {
      return callback(null, true);
    }

    console.warn(`CORS_BLOCKED_ORIGIN=${origin}`);
    const error = new Error(`CORS blocked origin: ${origin}`);
    error.status = 403;
    return callback(error);
  },
  credentials: true,
  methods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"],
  optionsSuccessStatus: 204
};

export function applyCorsMiddleware(app, options = corsOptions) {
  app.use(cors(options));
  app.options("*", cors(options));
}

function requestIdMiddleware(req, res, next) {
  const requestId = req.get("x-request-id") || randomUUID();
  req.requestId = requestId;
  res.setHeader("x-request-id", requestId);
  next();
}

export function createApp({ configureBeforeRoutes } = {}) {
  const app = express();
  const nodeEnv = process.env.NODE_ENV || "development";

  if (nodeEnv === "production") {
    app.set("trust proxy", 1);
  }

  app.use(requestIdMiddleware);
  app.use(helmet());
  if (configureBeforeRoutes) {
    configureBeforeRoutes(app);
  } else {
    applyCorsMiddleware(app);
  }
  app.use(morgan(nodeEnv === "production" ? "combined" : "dev"));
  app.use(rateLimit({ windowMs: 60_000, limit: 120, standardHeaders: true, legacyHeaders: false }));

  app.get("/health", (_req, res) => {
    res.json({ status: "ok", service: "ai-wellness-backend" });
  });

  app.get("/api/health", (_req, res) => {
    res.json({ status: "ok", service: "ai-wellness-backend" });
  });

  app.get("/api/debug/last-response", (_req, res) => {
    if (nodeEnv === "production") {
      return res.status(404).json({ error: { message: "Route not found" } });
    }
    return res.json({ response: getLastResponseDebug() });
  });

  app.use("/api/payments/webhook", stripeWebhookRouter);
  app.use(express.json({ limit: "1mb" }));

  app.use("/api/auth", authRouter);
  app.use("/api/users", userRouter);
  app.use("/api/subscriptions", subscriptionRouter);
  app.use("/api/chat", chatRouter);
  app.use("/api/checkins", checkInRouter);
  app.use("/api/avatars", avatarRouter);
  app.use("/api/analytics", analyticsRouter);
  app.use("/api/wellness", wellnessRouter);
  app.use("/api/experts", expertRouter);
  app.use("/api/legal", legalRouter);
  app.use("/api/memory", memoryRouter);
  app.use("/api/payments", paymentRouter);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}
