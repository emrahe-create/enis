import { ApiError } from "../utils/http.js";

export function notFound(_req, _res, next) {
  next(new ApiError(404, "Route not found"));
}

export function errorHandler(error, req, res, _next) {
  const status = error.status || 500;
  const requestId = req.requestId;
  const route = `${req.method} ${req.originalUrl || req.url}`;
  console.error(
    "BACKEND_REQUEST_ERROR",
    JSON.stringify({
      route,
      status,
      requestId,
      message: error.message,
      details: error.details || null
    })
  );

  const payload = {
    error: {
      message: process.env.NODE_ENV === "production" && status === 500
        ? "Internal server error"
        : error.message
    }
  };

  if (requestId) payload.error.requestId = requestId;
  if (error.details) payload.error.details = error.details;
  if (process.env.NODE_ENV !== "production" && status === 500) {
    payload.error.debug = error.message;
  }

  res.status(status).json(payload);
}
