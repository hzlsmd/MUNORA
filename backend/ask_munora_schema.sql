-- Additive migration; apply separately after review. No chat or raw IP storage.
CREATE TABLE IF NOT EXISTS ask_munora_usage (
 bucket TEXT PRIMARY KEY,
 attempts INTEGER NOT NULL CHECK(attempts > 0),
 expires_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS ask_munora_usage_expiry ON ask_munora_usage(expires_at);
