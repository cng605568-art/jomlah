# Jomlah privacy

*Last updated: 31 October 2026. This is a beta, so this page will change as the app does.*

**Ringkasan (BM):** Tiada akaun, tiada iklan, tiada analitik. Perjalanan anda tidak disimpan.
Lokasi digunakan untuk laluan dan amaran. Laporan amaran (jenis, lokasi, masa) dikongsi tanpa nama
dan dipadam sehari selepas tamat tempoh. Perkhidmatan yang kami guna (peta, carian, laluan, pelayan
amaran) boleh nampak alamat IP dan koordinat yang anda minta. Butiran di bawah.

**摘要（中文）：** 不需要账号，没有广告，没有分析工具，也不保存你的行程。位置只用于路线和警报。
警报报告（类型、地点、时间）会匿名分享，并在过期一天后删除。我们使用的服务（地图、搜索、路线、
警报服务器）可以看到你的 IP 地址和你查询的坐标。详情见下文（英文）。

## The short version

- No account, no login, no phone number.
- No ads, no analytics, no tracking libraries, and we do not sell data.
- We do not store your trips or routes.
- Alerts you report are shared with other drivers without any name or phone ID attached.

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
| Routes | Public Valhalla demo server run by FOSSGIS | Your start and destination coordinates and your IP address when you plan or re-plan a route. After you press Jom! (and after a re-plan), the line of the chosen route is sent back twice: once to look up its speed limits and once for lane arrows |
| Place search | Komoot's public Photon service | The text you type, your approximate location (to rank results) and your IP address |
| Spoken directions | Your phone's own text-to-speech engine | Depends on your phone. Some engines process text online |
| Shared alerts | Jomlah's alerts server, run on Cloudflare Workers (database in Asia-Pacific) | See "Alerts" below. Cloudflare handles the connection, so it sees your IP address; Jomlah's code does not store it, and request logs are switched off |

## Trip summary

The summary shown when you arrive (distance, time, speeds) is worked out on your phone while you drive.
It is not saved and not sent anywhere.

## Alerts (police, flood, pothole and so on)

- **Seeing alerts:** while the app is open, it asks the alerts server about every 20 seconds for alerts
  near you. To do that it sends your **rough area, rounded to about 1 km**, never your exact position.
  These requests are not stored.
- **Reporting or answering "Masih ada?":** we send the alert
  type, its location and the time, plus a random ID made by the app that **changes every 7 days**.
  The server does not store that ID. It keeps one-way scrambled values: one that changes daily (to stop
  spam) and one per alert (so a device can only vote once on it). These cannot be used to follow a
  person from alert to alert. Alerts are deleted a day after they expire.
- **Simulasi (pretend drive):** nothing you do is shared. Reports and votes made during a simulation
  stay on your phone, and the practice alerts it shows are never shared. (The app still looks up real
  alerts near the pretend car, the same way as above.)
- **Builds without an alerts server** (for example a copy built by someone else without one) show
  sample alerts kept in the app's memory only.

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
