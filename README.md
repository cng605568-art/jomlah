# Jomlah 🚗

**A free navigation app built in Malaysia, now in beta.** Turn-by-turn routes for cars and
motorcycles, route options, three voice packs (Mamak Boss, Sarcastic KL-ite, or Serious), driver
alerts for police, floods, potholes and more, and saved Home and Work shortcuts.
No account. No ads.

*Aplikasi navigasi percuma buatan Malaysia. Versi beta. Tiada akaun, tiada iklan.*

## About

Jomlah is a student-built project made with Flutter and OpenStreetMap data. It aims to be a
navigation app that feels Malaysian (local place names, Manglish voices, alerts for the things we
actually meet on the road) and respects your privacy: no login, no ads, no analytics, and your
trips are not stored.

It is an early beta. Some parts are real and some are still samples, and the lists below are
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
- Turn-by-turn with next-turn card, automatic reroute, current speed, and night map
- A car that glides smoothly along the road instead of jumping between GPS readings
- The map turns with your direction while you drive, with the road ahead in view (switch to north-up in Settings)
- Spoken directions in three voices (install your phone's Malay text-to-speech voice for Mamak Boss)
- Keeps navigating with the screen off or another app open (Android shows a "navigation active"
  notification; on Android 13 and newer, allow notifications so you can see it)
- Report buttons and a "Masih ada?" prompt when you pass an alert

## What does not work yet

- Alerts in this beta are **samples** and are not shared between users yet
- No live traffic, no lane guidance, no offline maps, no CarPlay or Android Auto
- It can be wrong, especially at complex junctions. Road signs and the law come first
- If you swipe the app away from recent apps, navigation stops
- When the map turns, street names turn with it, because the map pictures are rotated as a whole

## If the location stops updating

Some phones stop apps from running while the screen is off. In Android Settings, open Apps, then
Jomlah, then Battery, and choose **Unrestricted** (or "No restrictions"). Also allow notifications
for Jomlah, and press **Jom!** with the app open so the navigation service can start.

### If the car still jumps or drifts

GPS accuracy depends on your phone and the sky. Turn on high-accuracy location in Android's location
settings (it may be called "Google Location Accuracy"), turn off battery saver, and keep the phone
where it can see the sky, for example on a dashboard mount rather than in a bag. Tall buildings and
tunnels will still confuse any GPS app. Jomlah ignores obviously bad readings and snaps the car onto
the road you are following, but it cannot invent a signal your phone does not have.

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
