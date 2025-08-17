import { Router } from "express";
import prisma from "../db";
import { buildUberPayload, uploadUberMenu } from "../services/uber";

const r = Router();

r.post("/preview", async (_req, res) => {
  const settings = await prisma.settings.findFirst();
  const rows = await prisma.item.findMany({ where: { syncToUber: true } });
  const payload = buildUberPayload(rows, settings?.globalMarkupPct || 0);
  res.json(payload);
});

r.post("/upload", async (_req, res) => {
  const settings = await prisma.settings.findFirst();
  const rows = await prisma.item.findMany({ where: { syncToUber: true } });
  const payload = buildUberPayload(rows, settings?.globalMarkupPct || 0);
  const result = await uploadUberMenu(payload, settings!);
  res.json({ ok: true, result });
});

export default r;
