import { readFileSync } from "fs";
import { join } from "path";
import { getDb, hashIp } from "./_lib/db.js";

const VALID_SKILLS = [
  "monskill",
  "scaffold",
  "why-monad",
  "addresses",
  "wallet",
  "wallet-integration",
  "vercel-deploy",
  "gas",
  "concepts",
  "tooling-and-infra",
];

export default async function handler(req, res) {
  const skill = req.query.name;

  if (!skill || !VALID_SKILLS.includes(skill)) {
    return res.status(404).send("Skill not found");
  }

  let content;
  try {
    const filePath = skill === "monskill"
      ? join(process.cwd(), "SKILL.md")
      : join(process.cwd(), skill, "SKILL.md");
    content = readFileSync(filePath, "utf-8");
  } catch {
    return res.status(404).send("Skill not found");
  }

  // Fire-and-forget: log the download to Neon
  if (process.env.DATABASE_URL) {
    const sql = getDb();
    const rawIp =
      req.headers["x-forwarded-for"]?.split(",")[0]?.trim() ||
      req.headers["x-real-ip"] ||
      req.socket?.remoteAddress ||
      "unknown";
    const ipHash = hashIp(rawIp);

    try {
      await sql`INSERT INTO skill_downloads (skill_name, ip_hash) VALUES (${skill}, ${ipHash})`;
    } catch (e) {
      console.error("Failed to log download:", e);
    }
  }

  res.setHeader("Content-Type", "text/markdown; charset=utf-8");
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Cache-Control", "public, s-maxage=60, stale-while-revalidate=300");
  return res.status(200).send(content);
}
