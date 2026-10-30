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
- Release builds are signed with the project's own key (alias `jomlah`), so a new APK installs over
  the old one. The key is stored in two repository secrets, `ANDROID_KEYSTORE_BASE64` and
  `ANDROID_KEYSTORE_PASSWORD`; the workflow step **Set up release signing** uses them. Without the
  secrets (for example in a fork) the APK falls back to a throwaway debug key and the run shows a
  warning. Each run's summary shows the signing certificate's SHA-256; it must never change.
  Keep the key file and password backed up somewhere private: if they are lost, every user has to
  uninstall once and reinstall. Never commit the key (`.gitignore` blocks `*.p12`).
  The same key can later serve as the Google Play upload key.
- Map tiles come from OSM's public server for dev only. Self-host before real traffic.
- `pubspec.lock` is committed, so every build uses the same plugin versions and a new plugin
  release cannot break the APK by surprise. To update plugins on purpose, run `flutter pub upgrade`
  somewhere with Flutter (or a CI job) and commit the new lockfile.
- GitHub's build machines don't include the exact Android NDK Flutter asks for, so the step
  **Install Android NDK (with retries)** (`.github/scripts/install-ndk.sh`) downloads it first, up to
  3 times, and otherwise builds with the closest NDK already on the machine. Without it, Gradle
  downloaded the NDK mid-build and one broken download (`sdkmanager ... non-zero exit value 1`)
  failed the whole build. If a download still breaks during the build, it is retried once.
  The build works on both Ubuntu 24.04 and 26.04 machines (tested Oct 2026).

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

## Lane guidance and exit signs
The Valhalla route documentation I could read lists no lane fields in the standard JSON, so the app cannot
draw lane arrows from it. What it does provide, and what the app now uses:
- `sign` on a maneuver: exit number, the road you join, and "toward" destinations (from OSM `ref`, `destination`
  and `exit_to` tags). The turn card shows them as a green sign chip and the voice can say them (`{toward}`).
- `summary.has_toll` per route, shown as "Tol" on the route options.
`server/valhalla/smoke-test.sh` counts signs, toll flags, alternates and (in OSRM format) lanes and banner
instructions for a sample route, so you can see what your server sends. Whether signs appear on a given road
depends on how well it is tagged in OpenStreetMap, which is a job for volunteer mapping.
Requests now put `units` and `language` at the top level, as the current docs describe.

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

## Step 8: smooth car movement and better GPS
Raw GPS arrives about once a second and is noisy, so drawing it directly makes the car jump. The map
screen now runs every fix through a pipeline:

1. **Junk filter and Kalman filter** (`map/domain/gps_filter.dart`). Ignores fixes with accuracy worse
   than 35 m (but gives up ignoring after 5 in a row, for tunnels) and "teleports" faster than 70 m/s.
   The Kalman filter tracks position and velocity and also uses the phone's own speed and heading, so it
   smooths jitter without trailing behind. Standing still is treated as a measurement too.
2. **Snap to road** (`RoutingNotifier.snap`). While navigating and within 30 m of the route, the position
   is pulled onto the route and the car faces along the road.
3. **Animation** (`map/domain/car_motion.dart`). A frame ticker moves the car along its velocity between
   fixes (up to 2.5 s) and eases towards each new fix (about 0.2 s), so there are no jumps. Heading turns
   the short way round. Only the car's own layer redraws each frame.

The camera follows the animated car and keeps the zoom you chose. Two-finger rotation is disabled so the
map stays north-up.

Tuning knobs: `maxAccuracyM`, `maxSpeedMps` and `accelNoise` in `GpsFilter`; the 30 m snap distance in
`RoutingNotifier.snap`; the 2.5 s, 0.2 s and 0.3 s constants in `CarMotion`.
The tests in `test/gps_filter_test.dart` and `test/snap_test.dart` cover each stage.

## Step 9: heading-up map
While a trip is running and the camera is following the car, `MapScreen._onFrame` calls
`moveAndRotate(lookAhead(car, heading, 22% of the screen height in metres), zoom, -heading)`. The map
turns so the direction of travel is up and the car sits in the lower part of the screen. Markers use
`rotate: true` so they stay upright, and the car icon is drawn with heading 0 because the map itself
is doing the turning. Dragging the map, or ending the trip, resets the rotation to north-up.
The sign of the rotation (`-heading`) follows flutter_map's "0 is north" convention; if the map ever
spins the wrong way on a device, flip it in one place (`_onFrame`).
Settings > "Arah peta semasa memandu" switches between Ikut arah (heading-up) and Utara ke atas.

## Step 10: arrival summary and jam prompt
- `TripStats` (map/domain/trip_stats.dart) starts when Jom! is pressed and adds up distance (ignoring GPS
  jumps over 200 m), average speed and top speed. When `arrived` turns true the map screen opens
  `showArrivalSheet`, which also offers to save the destination as Home or Work if it came from search.
  Closing the sheet resets the screen to the search bar.
- `JamDetector` (map/domain/jam_detector.dart) asks "Lapor Jem Teruk?" after 2 minutes below 3 m/s while
  navigating with more than 300 m to go, then rests for 15 minutes. It does not ask if a jam report
  already exists within 300 m. Tune `slowMps`, `minSlow` and `cooldown` there. Long red lights are
  usually shorter than two minutes, so they should not trigger it.

## Step 11: simulated drive (testing without a car)
`SimulatedDrive` (map/domain/simulated_drive.dart) walks along the chosen route at 30, 60, 90 or 8 km/h,
accelerating gently, slowing for turns, easing to a stop, and adding about 3 m of jitter. The map screen
feeds its fixes into `_processFix`, the same function real GPS uses, so the filter, snapping, animation,
heading-up camera, voice, jam prompt, arrival sheet and trip stats all run exactly as on a real drive.
Real GPS is ignored while it runs, and it stops when the trip ends or is cancelled. Road alerts ahead
(voice) still use the real GPS, so they will not trigger in a simulation.

## Step 12: speed limit sign and over-speed warning
- After **Jom!** (and after each reroute) the app asks the routing server once for the speed limits
  along the chosen route: `POST /trace_attributes` with the route's own `encoded_polyline`,
  `shape_match: edge_walk` and the attributes `edge.speed_limit` and `edge.length`
  (`ValhallaClient.speedLimits`). The public FOSSGIS server supports this (checked 30 Oct 2026).
- `SpeedLimits` (routing/domain/speed_limits.dart) turns the edges into distance ranges ("zones")
  along the route; `currentSpeedLimitProvider` looks up the zone at the car's distance driven
  (`plan.totalM - remainingM`). Edges without a limit leave a gap, and no sign is shown there.
- Coverage depends on OpenStreetMap `maxspeed` tags. In a test on 30 Oct 2026: Federal Highway
  PJ-KL 80% of the length had a limit, PLUS Nilai-Seremban 44%, a KL city route 46%.
- Your speed bubble turns red at 5 km/h or more over the limit. The voice ("Cue.speeding", lines use
  `{limit}`) speaks after 3 s over, once per stretch with the same limit, at most once a minute,
  and never over a turn instruction (`SpeedWarner`). It works in Simulasi too.
- If the request fails, the trip simply has no sign; nothing else changes.

## Checks on branches
`.github/workflows/checks.yml` runs `dart analyze` and `flutter test` on every push to a branch other
than `main` (and on pull requests). Problems show up as annotations on the run summary, with file
and line. It does not build an APK; `main` still runs the full build, tests included.

## Step 13: car follows the road, GPS bounce filter, U-turn fix, new car
- `CarMotion` now has a route mode. While navigating, `MapScreen` passes the route (`setRoute`) and
  each snapped fix's distance along it (`RouteSnap.alongM`). Between fixes the car moves along the
  route line at its speed, closing any gap over about 0.5 s, so it follows bends and turns with the
  road instead of shooting straight on and snapping back (the old animation went about 8 m off the
  road at a 90 degree corner at 54 km/h). While driving it never slides backwards. Off the route it
  still coasts along its last velocity. Any mismatch (joining the route, a new route) is blended away
  over about 0.35 s, so the car never jumps unless it is more than 150 m off (app resumed).
- `GpsFilter` gives less weight to a fix that lands far outside what the track allows (chi-square
  gate, 99%), which is what GPS does between tall buildings. Three such fixes in a row are believed.
  In a test with two fixes bounced 35 m sideways, the car moved 6.4 m instead of 13 m.
  `FilteredFix.accuracyM` is the filter's own uncertainty; the map shows it as a blue circle when
  not navigating.
- Snapping and route tracking skip route segments that point more than 100 degrees away from the
  car's heading (only used above 3 m/s). On Malaysian U-turn routes the way back runs right beside
  the way out; before, the car could be put on the way back and the U-turn instruction skipped.
- The car is drawn in code (`car_marker.dart`): blue and lime like the app icon, white outline,
  headlights, and brake lights that glow for 1.5 s after slowing by more than 1.2 m/s per second.
  `assets/avatar/hatch_top.png` is no longer used.

## Step 14: dark blue look, route line trimmed at the car
- All colours live in `lib/core/app_theme.dart` (`AppColors` plus the Material theme from
  `buildAppTheme()`): navy background, dark blue cards with a thin outline, blue buttons, cyan and lime
  as small accents. The route line is blue with a dark navy edge; other route options are grey-blue.
  Change a colour there and it changes everywhere.
- The route line while driving is redrawn every frame from the gliding car (`CarPose.alongM` and
  `remainingFromDistance`), so it always starts exactly at the car. Before, it was cut only once per
  GPS fix, which left up to a second of line behind the car (about 25 m at 90 km/h).

## Publishing a release
- Write `release-notes/<tag>.md` (first line `# Title`, then the notes) and commit it to `main`.
- Then on GitHub: Releases > Draft a new release > type the tag (e.g. `v1.0.4(BETA)`), "Create new tag
  on publish", target `main`, leave the title and notes empty, Publish. (Pushing the tag with git
  works too.) The tag build signs the APK and fills in the release: APK, title and notes from the
  file. Tags with "beta" in them become pre-releases.
- Releases made by hand on GitHub's website still work; without a notes file the workflow only
  attaches the APK and leaves the typed title and notes alone.
- Settings in the app shows the version: the tag on release builds, "dev build N" otherwise
  (N = the run number on the Actions page). Android's version code is the run number.
