import { getDb } from "./_lib/db.js";

export default async function handler(req, res) {
  if (!process.env.STATS_SECRET || req.query.key !== process.env.STATS_SECRET) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  if (!process.env.DATABASE_URL) {
    return res.status(500).json({ error: "DATABASE_URL not configured" });
  }

  const sql = getDb();

  const [totals, daily, uniqueVisitors] = await Promise.all([
    sql`SELECT skill_name, COUNT(*)::int AS downloads
        FROM skill_downloads
        GROUP BY skill_name
        ORDER BY downloads DESC`,
    sql`SELECT skill_name, DATE(downloaded_at) AS date, COUNT(*)::int AS downloads
        FROM skill_downloads
        WHERE downloaded_at > NOW() - INTERVAL '30 days'
        GROUP BY skill_name, DATE(downloaded_at)
        ORDER BY date DESC, downloads DESC`,
    sql`SELECT skill_name, COUNT(DISTINCT ip_hash)::int AS unique_visitors
        FROM skill_downloads
        GROUP BY skill_name
        ORDER BY unique_visitors DESC`,
  ]);

  res.setHeader("Cache-Control", "public, s-maxage=60, stale-while-revalidate=300");
  return res.status(200).json({
    totals,
    unique_visitors: uniqueVisitors,
    daily_last_30_days: daily,
  });
}
