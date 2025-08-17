import express from "express";
import cors from "cors";
import { json } from "body-parser";
import configRouter from "./routes/config";
import catalogRouter from "./routes/catalog";
import publishRouter from "./routes/publish";

const app = express();
app.use(cors());
app.use(json({ limit: "5mb" }));

app.use("/api/config", configRouter);
app.use("/api/catalog", catalogRouter);
app.use("/api/publish", publishRouter);

// static web build (if you build vite to /web/dist)
app.use(express.static("web/dist"));

const PORT = Number(process.env.PORT || process.env.APP_PORT || 8080);
app.listen(PORT, () => console.log(`Server running on :${PORT}`));
