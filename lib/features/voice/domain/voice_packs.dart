import 'voice_pack.dart';

/// Warm, chatty, a bit too friendly. Mostly Malay. Affectionate, never a mocking accent.
const kMamakBoss = VoicePack(
  id: 'mamak',
  name: 'Mamak Boss',
  tagline: 'Mesra, bising, sikit terlebih friendly',
  locale: 'ms-MY',
  meter: 'meter',
  km: 'kilometer',
  advance: {
    Cue.start: [
      'Jom Boss! Laluan dah siap. Pandu elok-elok tau.',
      'Okey Boss, jom gerak. Teh tarik kita minum kemudian.',
    ],
    Cue.turnLeft: [
      'Boss, {d} lagi, belok kiri. Signal dulu tau.',
      'Dalam {d}, belok kiri. Jangan buat muka selamba.',
      'Boss, {d} lagi, belok kiri masuk {street}.',
    ],
    Cue.turnRight: [
      'Boss, {d} lagi, belok kanan. Signal dulu tau.',
      'Dalam {d}, belok kanan. Jangan lupa tengok cermin.',
      'Boss, {d} lagi, belok kanan masuk {street}.',
    ],
    Cue.keepLeft: [
      'Boss, {d} lagi, ambil kiri. Relaks je.',
      'Boss, {d} lagi, ambil kiri ke arah {toward}.',
      'Boss, {d} lagi, ambil kiri masuk {exit}.',
      'Boss, {d} lagi, ambil kiri masuk {exit}, ke arah {toward}.',
    ],
    Cue.keepRight: [
      'Boss, {d} lagi, ambil kanan. Relaks je.',
      'Boss, {d} lagi, ambil kanan ke arah {toward}.',
      'Boss, {d} lagi, ambil kanan masuk {exit}.',
      'Boss, {d} lagi, ambil kanan masuk {exit}, ke arah {toward}.',
    ],
    Cue.exitLeft: [
      '{d} lagi, keluar kiri Boss. Jangan tersasar, nanti pusing jauh.',
      '{d} lagi, keluar kiri ke arah {toward}, Boss.',
      'Boss, {d} lagi, keluar kiri di {exit}.',
      'Boss, {d} lagi, keluar kiri di {exit}, ke arah {toward}.',
    ],
    Cue.exitRight: [
      '{d} lagi, keluar kanan Boss. Jangan tersasar, nanti pusing jauh.',
      '{d} lagi, keluar kanan ke arah {toward}, Boss.',
      'Boss, {d} lagi, keluar kanan di {exit}.',
      'Boss, {d} lagi, keluar kanan di {exit}, ke arah {toward}.',
    ],
    Cue.uTurn: [
      'Boss, {d} lagi, U-turn. Pusing balik, takpe, bukan salah Boss.',
    ],
    Cue.roundabout: [
      'Boss, bulatan dalam {d}. Ikut papan tanda, jangan pusing sampai pening.',
      'Boss, bulatan dalam {d}. Ambil jalan keluar yang {nth} ya.',
    ],
    Cue.merge: [
      'Boss, {d} lagi, masuk lorong. Bagi can kat orang.',
    ],
    Cue.arrive: [
      'Dah sampai Boss! Cari parking pulak ya. Semoga ada.',
    ],
    Cue.recalculating: [
      'Alamak, tersasar sikit. Takpe Boss, relaks. Kita cari jalan lain.',
      'Eh takpe Boss. Saya kira balik, jangan stress.',
    ],
    Cue.police: [
      'Boss, depan ada Abang Polis, {d} lagi. Perlahan sikit. Saman tu boleh beli teh tarik sepuluh gelas.',
    ],
    Cue.camera: [
      'Boss, ada kamera depan, {d} lagi. Senyum sikit, tapi jangan laju.',
    ],
    Cue.flood: [
      'Boss, depan banjir, {d} lagi. Jangan degil, perlahan atau cari jalan lain.',
    ],
    Cue.pothole: [
      'Awas Boss, lubang depan, {d} lagi. Tayar tu mahal.',
    ],
    Cue.lorry: [
      'Boss, ada lori rosak depan, {d} lagi. Bagi signal, elak elok-elok.',
    ],
    Cue.jam: [
      'Boss, depan jem teruk, {d} lagi. Sabar, buka radio.',
    ],
    Cue.crash: [
      'Boss, ada kemalangan depan, {d} lagi. Perlahan, bagi laluan kat ambulans.',
    ],
    Cue.speeding: [
      'Boss, perlahan sikit. Had laju sini {limit} je.',
      'Eh Boss, laju sangat ni. Had laju {limit}. Saman mahal tau.',
    ],
  },
  now: {
    Cue.turnLeft: ['Belok kiri sekarang, Boss!'],
    Cue.turnRight: ['Belok kanan sekarang, Boss!'],
    Cue.exitLeft: ['Keluar kiri sekarang!'],
    Cue.exitRight: ['Keluar kanan sekarang!'],
  },
  then: 'Lepas tu terus {next}.',
  short: {
    Cue.turnLeft: 'belok kiri',
    Cue.turnRight: 'belok kanan',
    Cue.keepLeft: 'ambil kiri',
    Cue.keepRight: 'ambil kanan',
    Cue.exitLeft: 'keluar kiri',
    Cue.exitRight: 'keluar kanan',
    Cue.uTurn: 'buat U-turn',
    Cue.roundabout: 'masuk bulatan',
    Cue.merge: 'masuk lorong',
  },
  ordinals: ['pertama', 'kedua', 'ketiga', 'keempat', 'kelima', 'keenam'],
);

/// Dry, tired, secretly caring.
const kKlite = VoicePack(
  id: 'klite',
  name: 'Sarcastic KL-ite',
  tagline: 'Penat, sinis, tapi sebenarnya sayang kau',
  locale: 'en-GB',
  meter: 'metres',
  km: 'kilometres',
  advance: {
    Cue.start: [
      'Right. Route ready. Try not to get lost this time.',
    ],
    Cue.turnLeft: [
      'Turn left in {d}. Left. The one that is not right. Take your time, it is not like anyone is behind you. Oh wait, everyone is.',
      'In {d}, turn left onto {street}. Signal is the stick next to the steering wheel. Just saying.',
    ],
    Cue.turnRight: [
      'In {d}, turn right. Yes, the other one.',
      'Turn right in {d}. I believe in you. Slightly.',
    ],
    Cue.keepLeft: [
      'Keep left in {d}. Lanes exist for a reason. Allegedly.',
      'Keep left in {d} for {toward}. The sign is big and green for a reason.',
      'Keep left in {d} for {exit}. The sign is big and green for a reason.',
      'Keep left in {d} for {exit}, towards {toward}. The sign is big and green for a reason.',
    ],
    Cue.keepRight: [
      'Keep right in {d}. Lanes exist for a reason. Allegedly.',
      'Keep right in {d} for {toward}. The sign is big and green for a reason.',
      'Keep right in {d} for {exit}. The sign is big and green for a reason.',
      'Keep right in {d} for {exit}, towards {toward}. The sign is big and green for a reason.',
    ],
    Cue.exitLeft: [
      'Exit on the left in {d}. No, not the next one. This one.',
      'Exit on the left in {d} towards {toward}. No, not the next one. This one.',
      'Exit on the left in {d}: {exit}. No, not the next one. This one.',
      'Exit on the left in {d}: {exit}, towards {toward}. No, not the next one. This one.',
    ],
    Cue.exitRight: [
      'Exit on the right in {d}. No, not the next one. This one.',
      'Exit on the right in {d} towards {toward}. No, not the next one. This one.',
      'Exit on the right in {d}: {exit}. No, not the next one. This one.',
      'Exit on the right in {d}: {exit}, towards {toward}. No, not the next one. This one.',
    ],
    Cue.uTurn: [
      'U-turn in {d}. We all make mistakes. Some of us make them more often.',
    ],
    Cue.roundabout: [
      'Roundabout in {d}. Pick a lane, any lane. Actually, not any lane.',
      'Roundabout in {d}. Take the {nth} exit. Counting is easy, I promise.',
    ],
    Cue.merge: [
      'Merge in {d}. Take turns. It is a concept.',
    ],
    Cue.arrive: [
      'You have arrived. Now the real adventure begins: finding parking.',
    ],
    Cue.recalculating: [
      'You missed the turn. It is fine. I am not angry, just disappointed. Recalculating.',
      'Recalculating. Again. I have trust issues now.',
    ],
    Cue.police: [
      'Police ahead in {d}. Suddenly everyone remembers the speed limit. Miracles do happen.',
    ],
    Cue.camera: [
      'Camera ahead in {d}. Smile. And maybe slow down.',
    ],
    Cue.flood: [
      'Flood ahead in {d}. Your car is not a boat, however confident you feel.',
    ],
    Cue.pothole: [
      'Pothole ahead in {d}. Say hello to your suspension.',
    ],
    Cue.lorry: [
      'Broken down lorry ahead in {d}. It is resting. Please do not disturb. Go around.',
    ],
    Cue.jam: [
      'Heavy traffic ahead in {d}. Congratulations, you have reached peak KL.',
    ],
    Cue.crash: [
      'Accident ahead in {d}. Slow down and be human about it.',
    ],
    Cue.speeding: [
      'The limit here is {limit}. I know, I know. Slow down anyway.',
      'Speed limit {limit}. This is not Sepang. Ease off.',
    ],
  },
  now: {
    Cue.turnLeft: ['Left. Now.'],
    Cue.turnRight: ['Right. Now. Please.'],
    Cue.exitLeft: ['Exit left. Now.'],
    Cue.exitRight: ['Exit right. Now.'],
  },
  then: 'Then {next}. Keep up.',
  short: _englishShort,
  ordinals: _englishOrdinals,
);

/// Plain and clear. The safe choice, and what to use when you really need to concentrate.
const kSerious = VoicePack(
  id: 'serious',
  name: 'Serious',
  tagline: 'Jelas, ringkas, tiada gurauan',
  locale: 'en-GB',
  meter: 'metres',
  km: 'kilometres',
  advance: {
    Cue.start: ['Route ready. Drive safely.'],
    Cue.turnLeft: [
      'In {d}, turn left.',
      'In {d}, turn left onto {street}.',
    ],
    Cue.turnRight: [
      'In {d}, turn right.',
      'In {d}, turn right onto {street}.',
    ],
    Cue.keepLeft: [
      'In {d}, keep left.',
      'In {d}, keep left towards {toward}.',
      'In {d}, keep left for {exit}.',
      'In {d}, keep left for {exit}, towards {toward}.',
    ],
    Cue.keepRight: [
      'In {d}, keep right.',
      'In {d}, keep right towards {toward}.',
      'In {d}, keep right for {exit}.',
      'In {d}, keep right for {exit}, towards {toward}.',
    ],
    Cue.exitLeft: [
      'In {d}, take the exit on the left.',
      'In {d}, take the exit on the left towards {toward}.',
      'In {d}, take {exit} on the left.',
      'In {d}, take {exit} on the left, towards {toward}.',
    ],
    Cue.exitRight: [
      'In {d}, take the exit on the right.',
      'In {d}, take the exit on the right towards {toward}.',
      'In {d}, take {exit} on the right.',
      'In {d}, take {exit} on the right, towards {toward}.',
    ],
    Cue.uTurn: ['In {d}, make a U-turn.'],
    Cue.roundabout: ['In {d}, enter the roundabout.', 'In {d}, at the roundabout, take the {nth} exit.'],
    Cue.merge: ['In {d}, merge.'],
    Cue.arrive: ['You have arrived.'],
    Cue.recalculating: ['Recalculating route.'],
    Cue.police: ['Police reported ahead, in {d}.'],
    Cue.camera: ['Camera ahead in {d}.'],
    Cue.flood: ['Flooded road ahead in {d}. Slow down.'],
    Cue.pothole: ['Pothole ahead in {d}.'],
    Cue.lorry: ['Broken down lorry ahead in {d}.'],
    Cue.jam: ['Heavy traffic ahead in {d}.'],
    Cue.crash: ['Crash reported ahead, in {d}.'],
    Cue.speeding: ['Speed limit {limit}. Please slow down.'],
  },
  now: {
    Cue.turnLeft: ['Turn left now.'],
    Cue.turnRight: ['Turn right now.'],
    Cue.exitLeft: ['Take the exit now.'],
    Cue.exitRight: ['Take the exit now.'],
  },
  then: 'Then {next}.',
  short: _englishShort,
  ordinals: _englishOrdinals,
);

const _englishShort = {
  Cue.turnLeft: 'turn left',
  Cue.turnRight: 'turn right',
  Cue.keepLeft: 'keep left',
  Cue.keepRight: 'keep right',
  Cue.exitLeft: 'exit left',
  Cue.exitRight: 'exit right',
  Cue.uTurn: 'make a U-turn',
  Cue.roundabout: 'take the roundabout',
  Cue.merge: 'merge',
};

const _englishOrdinals = ['first', 'second', 'third', 'fourth', 'fifth', 'sixth'];

/// 热心老友: warm and a bit chatty, like a friend in the passenger seat. Malaysian Mandarin words
/// (罗里, 路洞, 水灾, 塞车). Uses the phone's Chinese (Mandarin) text-to-speech voice.
const kZhFriend = VoicePack(
  id: 'zh-friend',
  name: '热心老友',
  tagline: '亲切、话多一点，像朋友坐在旁边',
  locale: 'zh-CN',
  meter: '米',
  km: '公里',
  exitWord: '出口',
  advance: {
    Cue.start: [
      '好咯，路线准备好了。我们出发啦，开车小心哦！',
      '坐稳了老友，我们走咯。',
    ],
    Cue.turnLeft: [
      '{d}后左转哦，记得打灯。',
      '前面{d}左转，慢慢来，不用急。',
      '{d}后左转，进入{street}。',
    ],
    Cue.turnRight: [
      '{d}后右转哦，记得看镜子。',
      '前面{d}右转，先打个灯。',
      '{d}后右转，进入{street}。',
    ],
    Cue.keepLeft: [
      '{d}后靠左走，放轻松。',
      '{d}后靠左，往{toward}方向。',
      '{d}后靠左，进{exit}。',
      '{d}后靠左，进{exit}，往{toward}方向。',
    ],
    Cue.keepRight: [
      '{d}后靠右走，放轻松。',
      '{d}后靠右，往{toward}方向。',
      '{d}后靠右，进{exit}。',
      '{d}后靠右，进{exit}，往{toward}方向。',
    ],
    Cue.exitLeft: [
      '{d}后从左边出口出去，不要错过哦，不然要绕很远。',
      '{d}后从左边出口出去，往{toward}方向。',
      '{d}后走左边的{exit}。',
      '{d}后走左边的{exit}，往{toward}方向。',
    ],
    Cue.exitRight: [
      '{d}后从右边出口出去，不要错过哦，不然要绕很远。',
      '{d}后从右边出口出去，往{toward}方向。',
      '{d}后走右边的{exit}。',
      '{d}后走右边的{exit}，往{toward}方向。',
    ],
    Cue.uTurn: [
      '{d}后掉头。没关系，绕回去就好。',
    ],
    Cue.roundabout: [
      '{d}后进入圆环，跟着路牌走，不要转到头晕哦。',
      '{d}后进入圆环，从{nth}个出口出去。',
    ],
    Cue.merge: [
      '{d}后并线，让一让别人哦。',
    ],
    Cue.arrive: [
      '到咯！希望你很快找到停车位。',
    ],
    Cue.recalculating: [
      '哎呀，走错了没关系，我帮你重新找路。',
      '不要紧，我重新算一下路线。',
    ],
    Cue.police: [
      '前面{d}有警察哦，开慢一点，不要赶。',
    ],
    Cue.camera: [
      '前面{d}有测速相机，笑一个，但是不要开快。',
    ],
    Cue.flood: [
      '前面{d}有水灾，不要硬冲，慢慢开或者换条路。',
    ],
    Cue.pothole: [
      '小心，前面{d}有路洞，轮胎很贵的。',
    ],
    Cue.lorry: [
      '前面{d}有罗里抛锚，打灯，小心绕过去。',
    ],
    Cue.jam: [
      '前面{d}塞车很严重，放首歌，慢慢来。',
    ],
    Cue.crash: [
      '前面{d}有车祸，开慢一点，让救护车先过。',
    ],
    Cue.speeding: [
      '老友，开慢一点啦，这里限速{limit}。',
      '有点快咯，这里限速{limit}，罚单很贵的。',
    ],
  },
  now: {
    Cue.turnLeft: ['现在左转！'],
    Cue.turnRight: ['现在右转！'],
    Cue.exitLeft: ['现在从左边出去！'],
    Cue.exitRight: ['现在从右边出去！'],
  },
  then: '然后{next}。',
  short: _chineseShort,
  ordinals: _chineseOrdinals,
);

/// 华语 · 简洁: plain and short, for when you need to concentrate.
const kZhPlain = VoicePack(
  id: 'zh-plain',
  name: '华语 · 简洁',
  tagline: '清楚、简短，专心开车时用',
  locale: 'zh-CN',
  meter: '米',
  km: '公里',
  exitWord: '出口',
  advance: {
    Cue.start: ['路线已准备好，请安全驾驶。'],
    Cue.turnLeft: ['{d}后左转。', '{d}后左转，进入{street}。'],
    Cue.turnRight: ['{d}后右转。', '{d}后右转，进入{street}。'],
    Cue.keepLeft: [
      '{d}后靠左行驶。',
      '{d}后靠左行驶，往{toward}方向。',
      '{d}后靠左，进入{exit}。',
      '{d}后靠左，进入{exit}，往{toward}方向。',
    ],
    Cue.keepRight: [
      '{d}后靠右行驶。',
      '{d}后靠右行驶，往{toward}方向。',
      '{d}后靠右，进入{exit}。',
      '{d}后靠右，进入{exit}，往{toward}方向。',
    ],
    Cue.exitLeft: [
      '{d}后从左侧出口驶出。',
      '{d}后从左侧出口驶出，往{toward}方向。',
      '{d}后从左侧{exit}驶出。',
      '{d}后从左侧{exit}驶出，往{toward}方向。',
    ],
    Cue.exitRight: [
      '{d}后从右侧出口驶出。',
      '{d}后从右侧出口驶出，往{toward}方向。',
      '{d}后从右侧{exit}驶出。',
      '{d}后从右侧{exit}驶出，往{toward}方向。',
    ],
    Cue.uTurn: ['{d}后掉头。'],
    Cue.roundabout: ['{d}后进入圆环。', '{d}后进入圆环，从{nth}个出口驶出。'],
    Cue.merge: ['{d}后并线。'],
    Cue.arrive: ['已到达目的地。'],
    Cue.recalculating: ['正在重新计算路线。'],
    Cue.police: ['前方{d}有警察。'],
    Cue.camera: ['前方{d}有测速相机。'],
    Cue.flood: ['前方{d}有水灾，请减速。'],
    Cue.pothole: ['前方{d}有路洞。'],
    Cue.lorry: ['前方{d}有罗里抛锚。'],
    Cue.jam: ['前方{d}严重塞车。'],
    Cue.crash: ['前方{d}有车祸。'],
    Cue.speeding: ['限速{limit}，请减速。'],
  },
  now: {
    Cue.turnLeft: ['现在左转。'],
    Cue.turnRight: ['现在右转。'],
    Cue.exitLeft: ['现在驶出。'],
    Cue.exitRight: ['现在驶出。'],
  },
  then: '然后{next}。',
  short: _chineseShort,
  ordinals: _chineseOrdinals,
);

const _chineseShort = {
  Cue.turnLeft: '左转',
  Cue.turnRight: '右转',
  Cue.keepLeft: '靠左',
  Cue.keepRight: '靠右',
  Cue.exitLeft: '从左边出口出去',
  Cue.exitRight: '从右边出口出去',
  Cue.uTurn: '掉头',
  Cue.roundabout: '进入圆环',
  Cue.merge: '并线',
};

const _chineseOrdinals = ['第一', '第二', '第三', '第四', '第五', '第六'];

const kVoicePacks = <VoicePack>[kMamakBoss, kKlite, kSerious, kZhFriend, kZhPlain];
