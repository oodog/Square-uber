import { Router } from "express";
import prisma from "../db";

const r = Router();

r.get("/", async (_req, res) => {
  const s = await prisma.settings.findFirst();
  res.json(s || {});
});

r.post("/", async (req, res) => {
  const { squareLocationId, squareAccessToken, uberStoreId, uberClientId, uberClientSecret, globalMarkupPct } = req.body;
  const s = await prisma.settings.upsert({
    where: { id: 1 },
    update: { squareLocationId, squareAccessToken, uberStoreId, uberClientId, uberClientSecret, globalMarkupPct },
    create: { id: 1, squareLocationId, squareAccessToken, uberStoreId, uberClientId, uberClientSecret, globalMarkupPct }
  });
  res.json({ ok: true, settings: s });
});

export default r;
