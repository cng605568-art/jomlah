# Jomlah privacy

*Last updated: 24 October 2026. This is a beta, so this page will change as the app does.*

**Ringkasan (BM):** Tiada akaun, tiada iklan, tiada analitik. Perjalanan anda tidak disimpan.
Lokasi digunakan untuk laluan dan amaran. Perkhidmatan percuma yang kami guna (peta, carian,
laluan) boleh nampak alamat IP dan koordinat yang anda minta. Butiran di bawah.

## The short version

- No account, no login, no phone number.
- No ads, no analytics, no tracking libraries, and we do not sell data.
- We do not store your trips or routes.
- You can use the app without alerts being shared at all (this is how the current beta works).

## What the app does with your location

Your location is used on your phone to show your position, plan routes and warn you about alerts ahead.
It only leaves your phone as part of the requests described below.

While a trip is running, the app keeps tracking your location in the background (Android shows a
"navigation active" notification) so directions and voice keep working with the screen off. Tracking
in the background stops when the trip ends or you cancel it.

## Free services this beta uses

We do not run these services, and they have their own policies.

| What for | Service | What it can see |
|---|---|---|
| Map pictures | OpenStreetMap public tile servers | Your IP address and the map area you view |
| Routes | Public Valhalla demo server run by FOSSGIS | Your start and destination coordinates and your IP address when you plan or re-plan a route |
| Place search | Komoot's public Photon service | The text you type, your approximate location (to rank results) and your IP address |
| Spoken directions | Your phone's own text-to-speech engine | Depends on your phone. Some engines process text online |

If a later version moves to our own servers, this page will say so.

## Alerts (police, flood, pothole and so on)

- **In the current beta**, alerts are samples kept in the app's memory. They are not sent anywhere
  and disappear when you close the app.
- **In builds connected to an alerts server**, when you report or confirm an alert we send the alert
  type, its location and the time, plus a random ID made by the app that **changes every 7 days**.
  The server does not store that ID. It keeps one-way scrambled values: one that changes daily (to stop
  spam) and one per alert (so a device can only vote once on it). These cannot be used to follow a
  person from alert to alert. Alerts are deleted a day after they expire.

## Kept on your phone only

Your saved Home and Work places and recent destinations, your voice choice, the mute setting, your vehicle type, the toll preference, the night-map setting, the random ID, and whether you have seen the welcome screen.
Uninstalling the app removes all of it.

## Your choices

- Deny or turn off location, and the app cannot navigate.
- Uninstall to remove everything stored on your phone.
- Questions about data? Open an Issue on this repository. Do not post personal details there.
  Because the alert data is scrambled, we may not be able to find "your" alerts.

## Changes

We update this page when the app changes. The date at the top shows the latest version.
