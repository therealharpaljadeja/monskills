BEGIN;

DROP INDEX IF EXISTS feedback_ip_hash_created_idx;

ALTER TABLE IF EXISTS feedback
  DROP COLUMN IF EXISTS ip_hash;

COMMIT;
