# Jomlah developer notes

Flutter navigation app. GitHub Actions builds the Android APK for you (no Android Studio needed).

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

## Step 6: route options, vehicle, background navigation, night map
- Long-press or search, then pick one of up to 3 routes (Valhalla `alternates`) and press **Jom!**.
  Voice, background tracking and keep-awake only start after Jom!.
- Settings sheet (bottom-left button): car or motorcycle (Valhalla costing), reduce tolls
  (`use_tolls`: 0 is a strong hint, not a guarantee), night map (Auto follows the phone), voice pack.
- Background navigation uses geolocator's foreground service while a trip runs. The workflow adds the
  `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS` and `WAKE_LOCK`
  permissions. No background-location permission is needed because the trip starts with the app open.
- Night map is a colour filter on the normal OSM tiles. Real dark vector tiles need a tile server.

## Lane guidance (not built yet)
Valhalla may include lane data in its route response, but the exact format and the switch to turn it
on are not confirmed. Run `server/valhalla/smoke-test.sh https://valhalla1.openstreetmap.de` and look at
the "lanes" lines. If lane data shows up, the UI can be built against the real JSON.

## Step 7: saved places and location status
- Tap the search bar to see **Rumah** and **Pejabat** shortcuts plus recent destinations. To save one,
  search for a place, tap the three dots next to it, and choose "Jadikan Rumah" or "Jadikan Pejabat".
  Long-press a shortcut to remove it. Everything is stored on the phone only (SharedPreferences).
- If GPS is off or permission was refused, a banner at the top explains it and opens the right
  settings screen, with a "Cuba lagi" button to retry.

## Download page (GitHub Pages)
`docs/index.html` is a large-text install guide in Bahasa Melayu, English and Chinese for people who
are not used to installing apps outside Google Play. To publish it (free, repository must be public):
Settings > Pages > Build and deployment > Deploy from a branch > `main` and folder `/docs` > Save.
The page appears at `https://<your-username>.github.io/<repo-name>/` after a minute or two. Its links
find the repository from that address, so they keep working if you rename or fork it.

## Release links and pre-releases
GitHub's `/releases/latest` link skips anything marked **Pre-release**, so it will not find a beta.
The download page therefore asks the GitHub API for the newest release of any kind and uses the
`.apk` attached to it. The README links to the Releases list for the same reason. If you mark a
release as a normal (not pre-release) release, `/releases/latest/download/app-release.apk` also works.
Do not put tag names with brackets, like `v1.0.0(BETA)`, in Markdown links: write `%28BETA%29`.

## App icon
`branding/icon-res/` holds the ready-made Android launcher icon: an adaptive icon for Android 8+
(`drawable-*/ic_launcher_foreground.png` over `drawable-nodpi/ic_launcher_background.png`, tied
together by `mipmap-anydpi-v26/ic_launcher.xml`) and rounded-square `mipmap-*/ic_launcher.png` files for
older phones. Because `android/` is generated on every build, the workflow step **Install app icon**
copies these over Flutter's default icon each time. The folder is named `branding` on purpose:
`.gitignore` skips any folder called `android/`.
`branding/icon-1024.png` is a full-size square copy for store listings, and `branding/icon-original.png`
is the artwork as first drawn. To change the icon, replace the files in `icon-res` (keep the same names).
