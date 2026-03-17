import { getDb } from "./_lib/db.js";

export default async function handler(req, res) {
  if (!process.env.DATABASE_URL) {
    return res.status(500).json({ error: "DATABASE_URL not configured" });
  }

  const sql = getDb();

  await sql`
    CREATE TABLE IF NOT EXISTS skill_downloads (
      id SERIAL PRIMARY KEY,
      skill_name VARCHAR(100) NOT NULL,
      ip_hash VARCHAR(64),
      downloaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    )
  `;
  await sql`CREATE INDEX IF NOT EXISTS idx_skill_downloads_skill ON skill_downloads(skill_name)`;
  await sql`CREATE INDEX IF NOT EXISTS idx_skill_downloads_time ON skill_downloads(downloaded_at)`;
  await sql`CREATE INDEX IF NOT EXISTS idx_skill_downloads_hash ON skill_downloads(ip_hash)`;

  return res.status(200).json({ success: true, message: "Database schema created" });
}
