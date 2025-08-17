import { Router } from "express";
import { importSquare } from "../services/square";
import prisma from "../db";

const r = Router();

r.get("/import", async (_req, res) => {
  const { rows } = await importSquare();
  // upsert into DB so UI can show checkboxes & per-item markup
  for (const it of rows) {
    await prisma.item.upsert({
      where: { squareVariationId: it.square_variation_id },
      update: { ...it, updatedAt: new Date() },
      create: { ...it, syncToUber: false, markupPct: null, updatedAt: new Date() }
    });
  }
  res.json({ count: rows.length });
});

r.get("/list", async (_req, res) => {
  const items = await prisma.item.findMany({ orderBy: [{ categoryName: "asc" }, { name: "asc" }] });
  res.json(items);
});

r.post("/toggle", async (req, res) => {
  const { variationId, sync } = req.body;
  await prisma.item.update({ where: { squareVariationId: variationId }, data: { syncToUber: !!sync } });
  res.json({ ok: true });
});

r.post("/markup", async (req, res) => {
  const { variationId, pct } = req.body;
  await prisma.item.update({ where: { squareVariationId: variationId }, data: { markupPct: pct } });
  res.json({ ok: true });
});

export default r;
