import { Router } from "express";
import { getLegalDocument, listLegalDocuments } from "./legal.service.js";

export const legalRouter = Router();

const legalSlugs = [
  "privacy-policy",
  "kvkk-clarification",
  "explicit-consent",
  "terms-of-use",
  "distance-sales-agreement",
  "cancellation-refund-policy",
  "disclaimer",
  "faq"
];

legalRouter.get("/", (_req, res) => {
  res.json({ documents: listLegalDocuments() });
});

for (const slug of legalSlugs) {
  legalRouter.get(`/${slug}`, (_req, res) => {
    res.json(getLegalDocument(slug));
  });
}

legalRouter.get("/:slug", (req, res) => {
  res.json(getLegalDocument(req.params.slug));
});
