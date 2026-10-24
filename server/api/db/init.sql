CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS reports (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type          text NOT NULL CHECK (type IN
                  ('police','camera','flood','pothole','brokenLorry','jam','crash')),
  geom          geography(Point, 4326) NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  expires_at    timestamptz NOT NULL,
  confirms      int NOT NULL DEFAULT 0,
  denies        int NOT NULL DEFAULT 0,
  reporter_hash text NOT NULL            -- daily-rotating HMAC, never the device id
);
CREATE INDEX IF NOT EXISTS reports_geom_idx    ON reports USING GIST (geom);
CREATE INDEX IF NOT EXISTS reports_expires_idx ON reports (expires_at);

CREATE TABLE IF NOT EXISTS votes (
  report_id  uuid NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  voter_hash text NOT NULL,              -- HMAC per report, cannot be linked across reports
  vote       text NOT NULL CHECK (vote IN ('confirm','deny')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (report_id, voter_hash)
);
