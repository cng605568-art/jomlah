import '../../features/map/domain/report.dart';
import 'language.dart';

/// Every text the app shows, in (Bahasa Melayu, English, 中文) order.
///
/// To change a text, edit it here. To add a text, add a getter with all three languages: the app
/// will not build if one is missing. Words in {braces} are filled in by the app; keep them.
/// Tone: Malay is friendly Malaysian (a bit of Manglish is fine), Chinese is simplified Chinese as
/// used in Malaysia (油站, 罗里, 塞车).
class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  String _t((String, String, String) text) => switch (language) {
        AppLanguage.ms => text.$1,
        AppLanguage.en => text.$2,
        AppLanguage.zh => text.$3,
      };

  /// Fills in {name} placeholders.
  static String fill(String template, Map<String, Object> values) {
    var out = template;
    values.forEach((k, v) => out = out.replaceAll('{$k}', '$v'));
    return out;
  }

  // ---- Language ----
  String get languageTitle => _t(('Bahasa', 'Language', '语言'));

  // ---- Search ----
  String get searchHint => _t(('Nak ke mana?', 'Where to?', '要去哪里？'));
  String get home => _t(('Rumah', 'Home', '家'));
  String get work => _t(('Pejabat', 'Work', '公司'));
  String get notSetYet => _t(('Belum ditetapkan', 'Not set yet', '还没设定'));
  String get setAsHome => _t(('Jadikan Rumah', 'Set as Home', '设为家'));
  String get setAsWork => _t(('Jadikan Pejabat', 'Set as Work', '设为公司'));
  String get more => _t(('Lagi', 'More', '更多'));
  String shortcutHowTo(String setAs) => fill(
        _t((
          'Cari tempat, tekan ⋮ di sebelahnya, pilih "{setAs}".',
          'Search for a place, tap ⋮ next to it, then choose "{setAs}".',
          '先搜索地点，点旁边的 ⋮，再选“{setAs}”。',
        )),
        {'setAs': setAs},
      );
  String placeSaved(String what) => fill(_t(('{what} disimpan.', '{what} saved.', '{what}已保存。')), {'what': what});
  String get noResults => _t(('Tiada hasil. Cuba nama lain.', 'No results. Try another name.', '找不到结果，换个名字试试。'));
  String get searchFailed => _t(('Carian gagal. Cuba lagi.', 'Search failed. Try again.', '搜索失败，请再试一次。'));

  // ---- Map screen ----
  String get waitForGps => _t(('Tunggu GPS dapat lokasi dulu.', 'Waiting for GPS to find you.', '请等 GPS 先找到你的位置。'));
  String get myLocation => _t(('Lokasi saya', 'My location', '我的位置'));
  String jamQuestion(String jam) => fill(
        _t(('Nampak macam jem. Lapor {jam}?', 'Looks like a jam. Report {jam}?', '看起来塞车了。要报告{jam}吗？')),
        {'jam': jam},
      );
  String get report => _t(('Lapor', 'Report', '报告'));
  String get no => _t(('Tak', 'No', '不用'));
  String get simulate => _t(('Simulasi', 'Simulate', '模拟'));
  String get simulatedDrive => _t(('Simulasi pemanduan', 'Simulated drive', '模拟驾驶'));
  String get backToCar => _t(('Kembali', 'Back to car', '回到车'));
  String get settings => _t(('Tetapan', 'Settings', '设置'));

  // ---- Floating cards and panels ----
  String get whatDoYouSee => _t(('Apa yang anda nampak?', 'What do you see?', '你看到什么？'));
  String get kmh => _t(('km/j', 'km/h', 'km/h'));
  String speedLimit(int kph) => fill(_t(('Had laju {kph} km/j', 'Speed limit {kph} km/h', '限速 {kph} km/h')), {'kph': kph});
  String get cancel => _t(('Batal', 'Cancel', '取消'));
  String get chooseRoute => _t(('Pilih laluan', 'Choose a route', '选择路线'));
  String get fastest => _t(('Terpantas', 'Fastest', '最快'));
  String get toll => _t(('Tol', 'Toll', '收费'));
  String get go => _t(('Jom!', 'Jom!', '出发！'));
  String minutes(int n) => fill(_t(('{n} min', '{n} min', '{n} 分钟')), {'n': n});
  String get endTrip => _t(('Tamat perjalanan', 'End trip', '结束行程'));
  String arriveAt(String time) => fill(_t(('tiba {time}', 'arrive {time}', '{time} 抵达')), {'time': time});
  String get city => _t(('bandar', 'city', '市区'));
  String get highway => _t(('lebuh raya', 'highway', '高速公路'));
  String get jam => _t(('jem', 'jam', '塞车'));

  // ---- Trip ----
  String get findingRoute => _t(('Mencari laluan…', 'Finding a route…', '正在找路线…'));
  String get arrivedThanks =>
      _t(('Sampai! 🎉 Terima kasih sebab Jomlah.', "You're here! 🎉 Thanks for using Jomlah.", '到了！🎉 谢谢使用 Jomlah。'));
  String get chosenDestination => _t(('Destinasi pilihan', 'Chosen destination', '已选目的地'));
  String get recalculating => _t(('Mengira semula…', 'Recalculating…', '重新计算路线…'));
  String exitNumber(String n) => fill(_t(('Keluar {n}', 'Exit {n}', '{n} 号出口')), {'n': n});
  String towards(String places) => fill(_t(('ke {places}', 'to {places}', '往 {places}')), {'places': places});
  String get routeNoConnection =>
      _t(('Alamak, tak dapat hubungi server laluan.', "Can't reach the route server.", '无法连接路线服务器。'));
  String get routeNotFound => _t(('Tak jumpa laluan.', 'No route found.', '找不到路线。'));
  String get routeProblem => _t(('Alamak, ada masalah. Cuba lagi.', 'Something went wrong. Try again.', '出了点问题，请再试一次。'));

  /// The turn card's title when the road has no name, from Valhalla's maneuver type.
  String maneuver(int type) => switch (type) {
        1 || 2 || 3 => _t(('Mula', 'Start', '出发')),
        4 || 5 || 6 => _t(('Sampai ke destinasi', 'Arrive at your destination', '抵达目的地')),
        9 => _t(('Belok sedikit ke kanan', 'Bear right', '稍向右转')),
        10 => _t(('Belok kanan', 'Turn right', '右转')),
        11 => _t(('Belok tajam ke kanan', 'Sharp right', '向右急转')),
        12 || 13 => _t(('Buat U-turn', 'Make a U-turn', '掉头')),
        14 => _t(('Belok tajam ke kiri', 'Sharp left', '向左急转')),
        15 => _t(('Belok kiri', 'Turn left', '左转')),
        16 => _t(('Belok sedikit ke kiri', 'Bear left', '稍向左转')),
        18 || 20 => _t(('Keluar di kanan', 'Exit right', '从右边出口出去')),
        19 || 21 => _t(('Keluar di kiri', 'Exit left', '从左边出口出去')),
        23 || 37 => _t(('Ambil kanan', 'Keep right', '靠右')),
        24 || 38 => _t(('Ambil kiri', 'Keep left', '靠左')),
        25 => _t(('Masuk lorong', 'Merge', '并线')),
        26 => _t(('Masuk bulatan', 'Enter the roundabout', '进入圆环')),
        27 => _t(('Keluar dari bulatan', 'Leave the roundabout', '驶出圆环')),
        _ => _t(('Terus', 'Continue straight', '直走')),
      };

  // ---- Reports ----
  String reportLabel(ReportType type) => switch (type) {
        ReportType.police => _t(('Abang Polis', 'Police', '警察')),
        ReportType.camera => _t(('Kamera AES', 'Speed camera', '测速相机')),
        ReportType.flood => _t(('Banjir', 'Flood', '水灾')),
        ReportType.pothole => _t(('Lubang', 'Pothole', '路洞')),
        ReportType.brokenLorry => _t(('Lori Rosak', 'Broken-down lorry', '罗里抛锚')),
        ReportType.jam => _t(('Jem Teruk', 'Bad jam', '严重塞车')),
        ReportType.crash => _t(('Kemalangan', 'Accident', '车祸')),
      };
  String reported(String what) =>
      fill(_t(('Terima kasih! {what} dilaporkan.', 'Thanks! {what} reported.', '谢谢！已报告{what}。')), {'what': what});
  String get reportFailed => _t(('Alamak, tak jadi hantar. Cuba lagi.', "Couldn't send. Try again.", '发送失败，请再试一次。'));
  String get reportTooMany =>
      _t(('Banyak sangat laporan. Tunggu sekejap ya.', 'Too many reports. Please wait a moment.', '报告太多了，请稍等一下。'));
  String get voteConfirmed => _t(('Terima kasih! Laporan disahkan.', 'Thanks! Report confirmed.', '谢谢！已确认。'));
  String get voteGone => _t(('Terima kasih! Kami tandakan dah tak ada.', "Thanks! We'll mark it as gone.", '谢谢！已标记为没有了。'));
  String get voteFailed => _t(('Undi tak masuk. Cuba lagi.', "Vote didn't go through. Try again.", '投票失败，请再试一次。'));
  String practiceReported(String what) => fill(
        _t((
          'Simulasi: {what} dilaporkan di telefon ini sahaja.',
          'Simulation: {what} reported on this phone only.',
          '模拟：{what}只在这台手机上报告。',
        )),
        {'what': what},
      );
  String get practiceVote => _t(('Simulasi: undi tidak dihantar.', 'Simulation: vote not sent.', '模拟：投票没有发送。'));
  String get sharedAlertsTitle => _t(('Amaran dikongsi', 'Shared alerts', '共享警报'));
  String get sharedAlertsBody => _t((
        'Laporan anda (jenis, lokasi dan masa) dikongsi dengan pemandu lain tanpa nama, dan dipadam sehari '
            'selepas tamat tempoh. Semasa navigasi, kelajuan anda juga dikongsi tanpa nama untuk tunjuk jem '
            '(boleh tutup di Tetapan). Jomlah tidak simpan ID telefon atau alamat IP anda.',
        'Your reports (type, place and time) are shared with other drivers without your name, and deleted '
            'a day after they expire. While navigating, your speed is also shared anonymously to show jams '
            "(you can turn this off in Settings). Jomlah does not store your phone's ID or your IP address.",
        '你的报告（类型、地点和时间）会匿名分享给其他司机，并在过期一天后删除。导航时，你的车速也会匿名分享来显示塞车'
            '（可以在设置里关闭）。Jomlah 不保存你的手机 ID 或 IP 地址。',
      ));
  String stillThere(String what) => fill(_t(('Masih ada {what}?', '{what} still there?', '{what}还在吗？')), {'what': what});
  String get yesStillThere => _t(('Ada', 'Yes', '还在'));
  String get gone => _t(('Tak ada', 'Gone', '没了'));

  // ---- Live traffic ----
  String get liveTraffic => _t(('Trafik langsung', 'Live traffic', '实时路况'));
  String get shareTraffic => _t(('Kongsi kelajuan tanpa nama', 'Share my speed anonymously', '匿名分享车速'));
  String get shareTrafficHint => _t((
        'Semasa navigasi, kelajuan anda di jalan bantu tunjuk jem kepada semua. Tiada ID, dan 500 m '
            'pertama dan terakhir setiap perjalanan tidak dikongsi.',
        'While navigating, your speed on the road helps show jams to everyone. No ID, and the first and '
            'last 500 m of every trip are never shared.',
        '导航时，你在路上的车速会帮助大家看到塞车。不带任何 ID，每次行程开头和结尾的 500 米不会分享。',
      ));
  String get trafficNotice => _t((
        'Jomlah kini kongsi kelajuan tanpa nama untuk tunjuk jem. Boleh tutup di Tetapan.',
        'Jomlah now shares your speed anonymously to show jams. You can turn it off in Settings.',
        'Jomlah 现在会匿名分享车速来显示塞车。可以在设置里关闭。',
      ));
  String get ok => _t(('OK', 'OK', '好'));

  // ---- Notification while navigating ----
  String get notificationTitle => _t(('Jomlah sedang memandu anda', 'Jomlah is guiding you', 'Jomlah 正在为你导航'));
  String get notificationText =>
      _t(('Navigasi aktif. Ketik untuk kembali ke app.', 'Navigation is on. Tap to return to the app.', '导航进行中。点按返回应用。'));
  String get notificationChannel => _t(('Navigasi', 'Navigation', '导航'));

  // ---- Location problems ----
  String get gpsOff => _t((
        'GPS dimatikan. Hidupkan lokasi supaya Jomlah boleh tunjuk jalan.',
        'GPS is off. Turn on location so Jomlah can guide you.',
        'GPS 已关闭。请开启定位，Jomlah 才能为你导航。',
      ));
  String get needLocationPermission => _t((
        'Jomlah perlukan kebenaran lokasi untuk tunjuk jalan.',
        'Jomlah needs location permission to guide you.',
        'Jomlah 需要定位权限才能为你导航。',
      ));
  String get openSettings => _t(('Buka tetapan', 'Open settings', '打开设置'));
  String get tryAgain => _t(('Cuba lagi', 'Try again', '再试一次'));
  String get gpsStale => _t((
        'Lokasi tak dikemas kini. Cari tempat terbuka. Kalau berterusan: '
            'Tetapan > Bateri > Jomlah > Tiada had, dan benarkan notifikasi.',
        'Location is not updating. Find an open area. If it keeps happening: '
            'Settings > Battery > Jomlah > Unrestricted, and allow notifications.',
        '位置没有更新。请到空旷的地方。如果一直这样：设置 > 电池 > Jomlah > 不受限制，并允许通知。',
      ));
  String get openAppSettings => _t(('Buka tetapan app', 'Open app settings', '打开应用设置'));

  // ---- Arrival ----
  String get arrived => _t(('Sampai! 🎉', "You're here! 🎉", '到了！🎉'));
  String get distance => _t(('Jarak', 'Distance', '距离'));
  String get time => _t(('Masa', 'Time', '时间'));
  String get average => _t(('Purata', 'Average', '平均速度'));
  String get topSpeed => _t(('Laju maksimum', 'Top speed', '最高速度'));
  String get saveAsHome => _t(('Simpan sebagai Rumah', 'Save as Home', '保存为家'));
  String get saveAsWork => _t(('Simpan sebagai Pejabat', 'Save as Work', '保存为公司'));
  String get done => _t(('Selesai', 'Done', '完成'));

  /// "45 s", "23 min", "1 j 05 min".
  String duration(Duration d) {
    final s = d.inSeconds;
    if (s < 60) return fill(_t(('{n} s', '{n} s', '{n} 秒')), {'n': s});
    final m = (s / 60).round();
    if (m < 60) return minutes(m);
    final mm = (m % 60).toString().padLeft(2, '0');
    return fill(_t(('{h} j {m} min', '{h} h {m} min', '{h} 小时 {m} 分钟')), {'h': m ~/ 60, 'm': mm});
  }

  // ---- Settings ----
  String get route => _t(('Laluan', 'Route', '路线'));
  String get car => _t(('Kereta', 'Car', '汽车'));
  String get motorcycle => _t(('Motosikal', 'Motorcycle', '摩托车'));
  String get avoidTolls => _t(('Kurangkan tol', 'Avoid tolls', '尽量避开收费路'));
  String get avoidTollsHint => _t((
        'Cuba elak jalan bertol. Tak dijamin kalau tiada pilihan lain.',
        'Tries to avoid toll roads. Not guaranteed when there is no other way.',
        '尽量避开收费公路。没有其他路时无法保证。',
      ));
  String get fromNextRoute =>
      _t(('Berkuat kuasa pada laluan seterusnya.', 'Applies from the next route you plan.', '从下一次规划路线开始生效。'));
  String get mapDirection => _t(('Arah peta semasa memandu', 'Map direction while driving', '驾驶时的地图方向'));
  String get headingUp => _t(('Ikut arah', 'Heading up', '跟随方向'));
  String get northUp => _t(('Utara ke atas', 'North up', '北方朝上'));
  String get nightMap => _t(('Peta malam', 'Night map', '夜间地图'));
  String get auto => _t(('Auto', 'Auto', '自动'));
  String get on => _t(('Hidup', 'On', '开'));
  String get off => _t(('Mati', 'Off', '关'));
  String get voice => _t(('Suara', 'Voice', '语音'));
  String get muteVoice => _t(('Senyapkan suara', 'Mute voice', '静音'));
  String get voiceNeedsTts => _t((
        'Suara guna text-to-speech telefon. Kalau senyap, pasang suara bahasa itu dalam tetapan telefon.',
        "Voices use your phone's text-to-speech. If one stays silent, install that language's voice in your phone's settings.",
        '语音使用手机的文字转语音。如果没有声音，请在手机设置里安装该语言的语音。',
      ));
  String get privacy => _t(('Privasi', 'Privacy', '隐私'));
  String get privacyHint => _t(('Apa yang kami simpan dan tidak simpan', 'What we keep, and what we do not', '我们保存什么、不保存什么'));
  String get feedback => _t(('Lapor masalah / cadangan', 'Report a problem / suggestion', '反馈问题或建议'));
  String get opensOnGithub => _t(('Dibuka di GitHub', 'Opens on GitHub', '在 GitHub 打开'));
  String get demoMode => _t(('Mod demo: amaran contoh sahaja', 'Demo mode: sample alerts only', '演示模式：只有示例警报'));
  String get connectedToAlerts => _t(('Disambung ke pelayan amaran', 'Connected to the alerts server', '已连接警报服务器'));

  // ---- First run ----
  String get onboardingTitle => 'Jom! 🚗';
  String get onboardingSubtitle =>
      _t(('Sebelum gerak, 3 perkara penting.', 'Before you go, 3 important things.', '出发前，有 3 件重要的事。'));
  String get safetyTitle => _t(('Selamat dulu', 'Safety first', '安全第一'));
  String get safetyBody => _t((
        'Letak telefon di pemegang. Jangan menaip semasa memandu. Kalau tak selamat, berhenti dulu.',
        'Mount your phone, never type while driving, and pull over if it is not safe.',
        '把手机放在支架上。开车时不要打字。不安全的话，先停车。',
      ));
  String get guidanceTitle => _t(('Panduan sahaja', 'Guidance only', '仅供参考'));
  String get guidanceBody => _t((
        'Ikut papan tanda dan undang-undang jalan raya. Aplikasi ini boleh tersilap, terutama di persimpangan rumit.',
        'Road signs and the law come first. This beta can be wrong, especially at complex junctions.',
        '路牌和交通法规优先。这个测试版可能会出错，特别是在复杂的路口。',
      ));
  String get privacyBody => _t((
        'Tiada akaun. Lokasi digunakan untuk laluan dan amaran sahaja. Semasa navigasi, lokasi dijejak '
            'di latar dengan notifikasi. Pelayan peta, carian dan laluan percuma boleh nampak alamat IP dan '
            'koordinat yang anda minta. Butiran penuh ada di Tetapan.',
        'No account. Location is used for routes and alerts only. During a trip, location is tracked in the '
            'background (with a notification). Free map, search and routing servers can see your IP address and '
            'the coordinates you ask for. Details are in Settings.',
        '不需要账号。位置只用于路线和警报。导航时，应用会在后台追踪位置（会显示通知）。'
            '免费的地图、搜索和路线服务器可以看到你的 IP 地址和你查询的坐标。详情在设置里。',
      ));
  String get demoTitle => _t(('Versi demo', 'Demo version', '演示版'));
  String get demoBody => _t((
        'Amaran (polis, banjir dll.) dalam versi ini hanyalah contoh dan belum dikongsi antara pengguna.',
        'Alerts (police, floods and so on) in this build are samples and are not shared between users yet.',
        '这个版本的警报（警察、水灾等）只是示例，还没有在用户之间共享。',
      ));
  String get gotIt => _t(('Faham. Jom!', "Got it. Let's go!", '明白了，出发！'));
}
