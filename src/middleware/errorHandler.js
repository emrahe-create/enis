import { ApiError } from "../utils/http.js";

export function notFound(_req, _res, next) {
  next(new ApiError(404, "Route not found"));
}

export function errorHandler(error, _req, res, _next) {
  const status = error.status || 500;
  const payload = {
    error: {
      message: status === 500 ? "Internal server error" : error.message
    }
  };

  if (error.details) payload.error.details = error.details;
  if (process.env.NODE_ENV !== "production" && status === 500) {
    payload.error.debug = error.message;
  }

  res.status(status).json(payload);
}
