import jwt from "jsonwebtoken";
import { env } from "../config/env.js";
import { ApiError } from "../utils/http.js";

export function signToken(user) {
  return jwt.sign(
    { sub: user.id, email: user.email, role: user.role || "user" },
    env.JWT_SECRET,
    { expiresIn: env.JWT_EXPIRES_IN }
  );
}

export function requireAuth(req, _res, next) {
  if (req.method === "OPTIONS") return next();

  const header = req.get("authorization");
  const token = header?.startsWith("Bearer ") ? header.slice(7) : null;

  if (!token) return next(new ApiError(401, "Authentication required"));

  try {
    req.user = jwt.verify(token, env.JWT_SECRET);
    return next();
  } catch {
    return next(new ApiError(401, "Invalid or expired token"));
  }
}
