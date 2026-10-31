# Jomlah alerts server (Cloudflare Workers + D1)

Shares road alerts (police, flood, pothole...) between drivers. Free Cloudflare plan.

- **Deploys itself:** every push to `main` that changes `worker/` runs
  `.github/workflows/alerts-server.yml`: tests, then deploy. It needs two repository secrets,
  `CLOUDFLARE_API_TOKEN` (template "Edit Cloudflare Workers" plus Account > D1 > Edit) and
  `CLOUDFLARE_ACCOUNT_ID`. The first run creates the workers.dev address, the D1 database
  `jomlah-alerts` (Asia-Pacific), its tables, and the secret used to scramble device ids.
- **Address:** `https://jomlah-alerts.<your-subdomain>.workers.dev` (printed by the workflow).
- **API:** see the top of `src/index.js`. Alerts are the same as the self-hosted `server/api`;
  live traffic (`POST /v1/speeds`, `GET /v1/traffic`) is only here.
- **Tests:** `node --test test/*.test.js` (Node 22+, no installs; uses Node's built-in SQLite).
- **Free limits:** 100,000 requests and 5 million database rows read per day. Over the limit, the
  server answers with errors until 08:00 Malaysia time; nothing is ever charged.

## Moderation

Cloudflare dashboard → Storage & databases → D1 → `jomlah-alerts` → Console:

```sql
-- newest alerts
SELECT id, type, lat, lng, datetime(created_at/1000, 'unixepoch') AS created, confirms, denies
FROM reports ORDER BY created_at DESC LIMIT 50;

-- remove one (it disappears from every phone within a minute)
UPDATE reports SET expires_at = 0 WHERE id = 'paste-the-id-here';
```

## Privacy

No device ids, IP addresses or accounts are stored. Traffic readings are never stored either: each
one is added to a 5-minute average per ~165 m stretch and direction, averages go after an hour, and
a stretch is only shown once two readings agree. Reports keep a daily-changing scrambled code
(for rate limits); votes keep a per-alert code (one vote per phone). Request logs are off
(`[observability] enabled = false`). Alerts are deleted a day after they expire.
