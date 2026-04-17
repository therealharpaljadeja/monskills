import { getDb, hashIp } from "./_lib/db.js";

const MAX_MESSAGE_LEN = 5000;
const MAX_CONTEXT_LEN = 4000;
const MAX_FIELD_LEN = 128;

const ALLOWED_SOURCES = new Set(["agent", "user"]);
const ALLOWED_SEVERITY = new Set(["low", "medium", "high"]);
const ALLOWED_CATEGORIES = new Set([
  "stuck",
  "error-loop",
  "user-complaint",
  "bug",
  "incorrect-info",
  "suggestion",
  "other",
]);

const WINDOW_SECONDS = 60 * 60;
const MAX_PER_WINDOW = 10;

function clampString(value, max) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.length > max ? trimmed.slice(0, max) : trimmed;
}

function looksLikeSpam(message) {
  const urlMatches = message.match(/https?:\/\//gi);
  if (urlMatches && urlMatches.length > 5) return true;
  if (/<script[\s>]/i.test(message)) return true;
  return false;
}

export default async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    return res.status(204).end();
  }

  if (req.method !== "POST") {
    return res.status(405).json({ ok: false, error: "Method not allowed" });
  }

  if (!process.env.DATABASE_URL) {
    return res.status(500).json({ ok: false, error: "Database not configured" });
  }

  let body = req.body;
  if (typeof body === "string") {
    try {
      body = JSON.parse(body);
    } catch {
      return res.status(400).json({ ok: false, error: "Invalid JSON body" });
    }
  }
  if (!body || typeof body !== "object") {
    return res.status(400).json({ ok: false, error: "Missing JSON body" });
  }

  // Honeypot: legitimate clients never fill this; bots usually do.
  // Silently accept to avoid signalling that filtering exists.
  if (typeof body.website === "string" && body.website.trim() !== "") {
    return res.status(200).json({ ok: true });
  }

  const message = clampString(body.message, MAX_MESSAGE_LEN);
  if (!message) {
    return res.status(400).json({ ok: false, error: "message is required" });
  }
  if (message.length < 3) {
    return res.status(400).json({ ok: false, error: "message is too short" });
  }
  if (looksLikeSpam(message)) {
    return res.status(200).json({ ok: true });
  }

  const source = clampString(body.source, MAX_FIELD_LEN);
  if (source && !ALLOWED_SOURCES.has(source)) {
    return res.status(400).json({ ok: false, error: "invalid source" });
  }

  const severity = clampString(body.severity, MAX_FIELD_LEN);
  if (severity && !ALLOWED_SEVERITY.has(severity)) {
    return res.status(400).json({ ok: false, error: "invalid severity" });
  }

  const category = clampString(body.category, MAX_FIELD_LEN);
  if (category && !ALLOWED_CATEGORIES.has(category)) {
    return res.status(400).json({ ok: false, error: "invalid category" });
  }

  const skillName = clampString(body.skill || body.skill_name, MAX_FIELD_LEN);
  const agentName = clampString(body.agent || body.agent_name, MAX_FIELD_LEN);
  const context = clampString(body.context, MAX_CONTEXT_LEN);

  const rawIp =
    req.headers["x-forwarded-for"]?.split(",")[0]?.trim() ||
    req.headers["x-real-ip"] ||
    req.socket?.remoteAddress ||
    "unknown";
  const ipHash = hashIp(rawIp);

  const sql = getDb();

  try {
    const recent = await sql`
      SELECT COUNT(*)::int AS count
      FROM feedback
      WHERE ip_hash = ${ipHash}
        AND created_at > NOW() - (${WINDOW_SECONDS} || ' seconds')::interval
    `;
    if (recent[0]?.count >= MAX_PER_WINDOW) {
      return res.status(429).json({ ok: false, error: "Too many submissions, try again later" });
    }

    const inserted = await sql`
      INSERT INTO feedback
        (source, skill_name, category, severity, message, context, agent_name, ip_hash)
      VALUES
        (${source || null}, ${skillName || null}, ${category || null},
         ${severity || null}, ${message}, ${context || null},
         ${agentName || null}, ${ipHash})
      RETURNING id
    `;
    return res.status(200).json({ ok: true, id: inserted[0].id });
  } catch (e) {
    console.error("Failed to record feedback:", e);
    return res.status(500).json({ ok: false, error: "Failed to record feedback" });
  }
}
