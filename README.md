# Jomlah 🚗

**A free navigation app built in Malaysia, now in beta.** In Bahasa Melayu, English and 中文.
Turn-by-turn routes for cars and motorcycles, route options, five voices (Mamak Boss, Sarcastic
KL-ite, Serious, and two in Mandarin: 热心老友 and 华语 · 简洁), driver alerts for police, floods,
potholes and more, and saved Home and Work shortcuts. No account. No ads.

*Aplikasi navigasi percuma buatan Malaysia. Versi beta. Tiada akaun, tiada iklan.*
*马来西亚制造的免费导航应用。测试版。不需要账号，没有广告。*

## About

Jomlah is a student-built project made with Flutter and OpenStreetMap data. It aims to be a
navigation app that feels Malaysian (local place names, Manglish voices, alerts for the things we
actually meet on the road) and respects your privacy: no login, no ads, no analytics, and your
trips are not stored.

It is an early beta. Some parts are still rough, and the lists below are
honest about which is which.

## Download (Android only)

**[Open the Releases page](../../releases)**, pick the newest version, and under **Assets** download `app-release.apk`.

Or use the large-text install page: **https://cng605568-art.github.io/jomlah/**

1. Open the downloaded file on your phone.
2. If Android asks, allow **Install unknown apps** for the app you downloaded it with.
3. If Play Protect warns about an unrecognised app, tap **More details**, then **Install anyway**.
   (This is a test build that is not on Google Play.)
4. Open Jomlah, read the welcome screen, and allow location **while using the app**.

Only download from this page. Do not install copies from anywhere else.

### Helping a parent or grandparent install it

There is a large-text download page in Bahasa Melayu, English and Chinese:
**https://cng605568-art.github.io/jomlah/**. Open it on their phone, or print the address and
sit with them for the five steps. Only install apps from links you trust.

## What works

- Map, search for places in Malaysia, and up to 3 route options to choose from before you go
- Car or motorcycle routes, and an option to avoid tolls where possible
- Saved Home and Work shortcuts, plus your recent destinations
- An arrival summary (distance, time, average and top speed) with one-tap save as Home or Work
- After two minutes of crawling, a "Nampak macam jem" prompt so you can report traffic with one tap
- Turn-by-turn with next-turn card, automatic reroute, current speed, and night map
- A speed limit sign next to your speed where OpenStreetMap knows the limit; your speed turns red
  when you are 5 km/j or more over it, and the voice reminds you once per stretch of road
- Highway exit signs on the turn card (exit number and where it leads), and a "Tol" tag on route options that use toll roads, where OpenStreetMap has the data
- Lane arrows under the turn card at junctions where OpenStreetMap has lane markings (about half the
  highway exits and forks around KL in our tests): the lane to be in is highlighted
- The voice names the exit ("exit 2 0 9, UPM, ke arah Serdang"), says which roundabout exit to take,
  and warns about a second turn that comes right after the first ("lepas tu terus ambil kiri")
- A car that glides along the road itself between GPS readings, following bends and turning with
  the road, with brake lights when you slow down; a circle shows how sure the GPS is while you browse
- The map turns with your direction while you drive, with the road ahead in view (switch to north-up in Settings)
- The whole app in Bahasa Melayu, English or 中文 (Settings > Bahasa / Language / 语言, or on the
  first screen). A phone set to Chinese starts in Chinese; everyone else starts in Malay
- Spoken directions in five voices: three in Malay and English, two in Mandarin. Changing the app's
  language switches to a voice in that language (you can still pick any voice). Voices use your
  phone's text-to-speech: install the Malay or Chinese voice there if one stays silent
- Keeps navigating with the screen off or another app open (Android shows a "navigation active"
  notification; on Android 13 and newer, allow notifications so you can see it)
- **Shared alerts:** report police, speed cameras, floods, potholes, broken-down lorries, jams and
  accidents with the orange button, and everyone nearby sees them. Passing an alert asks "Masih ada?";
  your answer keeps it or removes it. No account, and no phone ID is stored (see PRIVACY.md)
- **Voice reports:** while driving, tap the microphone and say what you see ("ada polis", "banjir",
  "塞车", "accident"); the app reports it and says so out loud. Malay, English and Chinese words all
  work, mixed too
- Tells you when a new version is out (checks GitHub at most twice a day; "Download" opens the
  install page, and you install over the old version). Turn it off in Settings
- **Live traffic:** while you drive, phones share their speed anonymously, and slow parts of your
  route turn orange or red. It needs other Jomlah drivers on the same road, so it is mostly empty
  for now. Turn sharing off in Settings (see PRIVACY.md)

## What does not work yet

- No offline maps, no CarPlay or Android Auto. Live traffic only shows where other Jomlah drivers have been
- Lane arrows only appear where OpenStreetMap has lane markings; many town junctions have none yet
- Speed limits are missing on many roads, because OpenStreetMap does not have them everywhere yet.
  Where the limit is unknown, no sign is shown (the app never guesses). Road signs always win
- It can be wrong, especially at complex junctions. Road signs and the law come first
- If you swipe the app away from recent apps, navigation stops
- When the map turns, street names turn with it, because the map pictures are rotated as a whole

## Try it without a car

After you pick a destination, tap **Simulasi** next to **Jom!** and choose a speed. The app then
drives the route by itself, so you can see the map follow, hear the voice, and watch the arrival
summary from your sofa. Pick 8 km/j to see the "jem" prompt after two minutes. Pick 60 km/j on a
city route to see the speed limit sign and hear the "slow down" reminder in a 50 zone. On routes of
1.5 km or more, the simulation puts a practice speed camera and police alert on the road ahead, so you
can hear the alert voices (practice alerts stay on your phone and disappear when the simulation ends).
The menu remembers the speed you picked last time. The real GPS is ignored while a simulation runs. You can also test for real as a passenger on a bus or in a
friend's car.

## If the location stops updating

Some phones stop apps from running while the screen is off. In Android Settings, open Apps, then
Jomlah, then Battery, and choose **Unrestricted** (or "No restrictions"). Also allow notifications
for Jomlah, and press **Jom!** with the app open so the navigation service can start.

### If the car still jumps or drifts

GPS accuracy depends on your phone and the sky. Turn on high-accuracy location in Android's location
settings (it may be called "Google Location Accuracy"), turn off battery saver, and keep the phone
where it can see the sky, for example on a dashboard mount rather than in a bag. Tall buildings and
tunnels will still confuse any GPS app. Jomlah ignores obviously bad readings, gives little weight to readings
bounced off tall buildings, and snaps the car onto the road you are following, but it cannot invent a signal your phone does not have.

## Stay safe

Mount your phone. Never type while driving. Pull over if something is not safe.

## Privacy

Short version: no account, no ads, no analytics, and your trips are not stored.
Read the full plain-language page in [PRIVACY.md](PRIVACY.md).

## Found a bug? Got an idea?

Open an **[Issue](../../issues)**. Please do not include personal details. Include your phone model and
what you were doing. Screenshots help.

## For developers

See [DEVELOPING.md](DEVELOPING.md).
