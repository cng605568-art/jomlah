# Jomlah (working name)

Flutter navigation app starter. GitHub Actions builds the Android APK for you.

## Build the APK
1. Push this folder to a GitHub repo (branch `main`).
2. Open the **Actions** tab, choose **Build Android APK**, press **Run workflow**.
3. When it turns green, open the run and download **jomlah-apk** (a zip holding `app-release.apk`).
4. On your Android phone: unzip, allow installs from this source, tap the APK.

Want a direct download link? Push a tag: `git tag v0.1.0 && git push origin v0.1.0`.
The APK then appears under **Releases**.

## Notes
- The workflow generates the `android/` folder on first run, then patches in INTERNET and
  location permissions. Commit `android/` later if you need to customise it.
- Release builds here are debug-signed. Fine for sideloading testers, not for Google Play.
- Map tiles come from OSM's public server for dev only. Self-host before real traffic.

## Routing (step 2)
- In the app: **long-press the map** to pick a destination. The route is drawn in lime, the top
  card shows the next turn, and **Jom!** starts following your position.
- If you drift more than 60 m off the route, the app asks for a new one (max once per 10 s).
- Dev default is the public FOSSGIS Valhalla demo server (fair use, rate limited). Do not ship on it.

### Run your own Valhalla for Malaysia
```
cd server/valhalla
docker compose up -d        # first start builds the graph; watch with: docker compose logs -f
./smoke-test.sh             # KLCC -> Putrajaya
```
Then put HTTPS in front of port 8002 (Android blocks plain http in release builds) and set the
repo variable `VALHALLA_URL` to that address. If the image fails to pull, try
`ghcr.io/nilsnolde/docker-valhalla/valhalla:latest`.

## Voice (step 3)
- Tap the voice button (bottom left) to pick **Mamak Boss**, **Sarcastic KL-ite** or **Serious**,
  or to mute. Picking one plays a sample.
- While navigating: "route ready", turn warnings (early on highways, a short "now" call just
  before the turn), "recalculating" when you go off route, "arrived", and heads-up for police,
  cameras, floods, potholes, broken-down lorries, jams and crashes that are ahead of you and on
  your route.
- Voices use the phone's text-to-speech for now. For Mamak Boss, install the Malay voice:
  Android Settings > System > Languages > Text-to-speech > Google > install voice data. Without it,
  the Malay lines are read in an English voice, which is funny but not the goal.
- Recorded clips later: implement `Speaker` (see `voice/data/speaker.dart`) as a clip player.
  The engine and packs stay as they are.
- Your voice choice and mute setting are saved between launches.

## Destination search (step 4)
- Type a place in the bar at the top (3+ letters). Results are Malaysia only and lean towards
  where you are. Tap one to plan the route. Long-press on the map still works.
- Search uses Komoot's public Photon API: free but fair use, so fine for beta, not for launch.
  Self-host Photon before real traffic (it needs a prebuilt Malaysia search index, see the Photon
  README) and set the repo variable `PHOTON_URL`.
- Address quality is whatever OpenStreetMap knows. Expect gaps for kampung and new-development
  addresses; that is another job for the Lorong Squad.

## Reports backend (step 5)
Real, shared alerts instead of the in-memory demo. Without it the app still runs in demo mode.

```
cd server
cp .env.example .env            # set DB_PASSWORD and HMAC_SECRET to long random strings
docker compose up -d db api
api/smoke.sh                    # create, list, and merge a police alert
```
Go public: point a DNS name at the server, set `DOMAIN` in `.env`, run
`docker compose --profile https up -d`, then set the repo variable `API_URL`
(for example `https://api.yourdomain.my`) and rebuild the APK. Host it in Malaysia to keep
the data-residency promise.

**What the API does**
- `POST /v1/reports`, `GET /v1/reports?lat&lng&r`, `POST /v1/reports/:id/vote`.
- Same alert type within 100 m counts as a confirmation of the existing alert, not a duplicate.
- "Masih ada?" in the app: a card appears when you pass an alert (or tap a pin). Confirm keeps it
  alive longer (capped at 3x its normal life). Two net denies remove it.
- Each alert type has a lifetime set by the server (police 45 min, flood 3 h, and so on).
- Limits: 10 reports per device per 10 minutes, Malaysia only, GPS accuracy 100 m or better.

**Privacy by design**
- No login. The app sends a random device id that changes every 7 days.
- The server never stores that id. It keeps a daily-rotating hash (rate limits) and a per-alert
  hash (one vote each), so a person cannot be followed across alerts.
- Only alert points are stored, not trips. Alerts are deleted a day after they expire.

**Known limits**
- Anyone can still spam within the limits. Add a moderation view and per-area limits before launch.
- One API instance only (the limiter is in memory). Use Redis when you scale out.
- The app polls every 20 s. Server push (SSE) is the upgrade.
