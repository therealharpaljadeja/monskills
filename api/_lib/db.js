import { neon } from "@neondatabase/serverless";
import { createHash } from "crypto";

export function getDb() {
  return neon(process.env.DATABASE_URL);
}

/**
 * Hash IP with a daily rotating salt for anonymous unique tracking.
 * Same IP on the same day = same hash (deduplication).
 * Different day = different hash (can't track across days).
 */
export function hashIp(ip) {
  const daySalt = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  return createHash("sha256").update(`${ip}:${daySalt}`).digest("hex");
}
