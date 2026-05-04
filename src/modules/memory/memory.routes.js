import { Router } from "express";
import { requireAuth } from "../../middleware/auth.js";
import { asyncHandler } from "../../utils/http.js";
import { clearUserMemories, getUserMemories } from "./memory.service.js";

export const memoryRouter = Router();

memoryRouter.use(requireAuth);

memoryRouter.get(
  "/",
  asyncHandler(async (req, res) => {
    res.json({ memories: await getUserMemories(req.user.sub) });
  })
);

memoryRouter.delete(
  "/",
  asyncHandler(async (req, res) => {
    const deletedCount = await clearUserMemories(req.user.sub);
    res.json({ deleted: true, deletedCount });
  })
);
