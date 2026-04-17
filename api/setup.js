import { getDb } from "./_lib/db.js";

export default async function handler(req, res) {
  if (!process.env.STATS_SECRET || req.query.key !== process.env.STATS_SECRET) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  if (!process.env.DATABASE_URL) {
    return res.status(500).json({ error: "DATABASE_URL not configured" });
  }

  const sql = getDb();

  try {
    await sql`
      CREATE TABLE IF NOT EXISTS feedback (
        id BIGSERIAL PRIMARY KEY,
        source TEXT,
        skill_name TEXT,
        category TEXT,
        severity TEXT,
        message TEXT NOT NULL,
        context TEXT,
        agent_name TEXT,
        ip_hash TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `;
    await sql`
      CREATE INDEX IF NOT EXISTS feedback_ip_hash_created_idx
        ON feedback (ip_hash, created_at DESC)
    `;
    await sql`
      CREATE INDEX IF NOT EXISTS feedback_created_idx
        ON feedback (created_at DESC)
    `;

    return res.status(200).json({ ok: true, applied: ["feedback"] });
  } catch (e) {
    console.error("Setup failed:", e);
    return res.status(500).json({ ok: false, error: String(e?.message || e) });
  }
}
