-- Shared road alerts. Times are milliseconds since 1970 (UTC).
-- Nothing here identifies a person: no device id, no IP address, no account.

CREATE TABLE IF NOT EXISTS reports (
  id            TEXT PRIMARY KEY,
  type          TEXT NOT NULL CHECK (type IN
                  ('police','camera','flood','pothole','brokenLorry','jam','crash')),
  lat           REAL NOT NULL,
  lng           REAL NOT NULL,
  cell          INTEGER NOT NULL,          -- 0.1 degree square (about 11 km), for fast "near me"
  created_at    INTEGER NOT NULL,
  expires_at    INTEGER NOT NULL,
  confirms      INTEGER NOT NULL DEFAULT 0,
  denies        INTEGER NOT NULL DEFAULT 0,
  reporter_hash TEXT NOT NULL              -- daily-changing HMAC of the device id, for rate limits only
);
-- "Alerts near me" reads only live alerts in the nine squares around the driver.
CREATE INDEX IF NOT EXISTS reports_cell_expires_idx ON reports (cell, expires_at);
CREATE INDEX IF NOT EXISTS reports_expires_idx ON reports (expires_at);

CREATE TABLE IF NOT EXISTS votes (
  report_id  TEXT NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  voter_hash TEXT NOT NULL,                -- HMAC per report: votes cannot be linked across reports
  vote       TEXT NOT NULL CHECK (vote IN ('confirm','deny')),
  created_at INTEGER NOT NULL,
  PRIMARY KEY (report_id, voter_hash)
);

-- Rate limits. One row per counted action, deleted after an hour.
CREATE TABLE IF NOT EXISTS hits (
  key TEXT NOT NULL,                       -- "r:<reporter hash>", "v:<reporter hash>" or "a:<cell>"
  at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS hits_key_at_idx ON hits (key, at);
