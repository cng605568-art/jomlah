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
    ],
    Cue.keepRight: [
      'Boss, {d} lagi, ambil kanan. Relaks je.',
      'Boss, {d} lagi, ambil kanan ke arah {toward}.',
    ],
    Cue.exitLeft: [
      '{d} lagi, keluar kiri Boss. Jangan tersasar, nanti pusing jauh.',
      '{d} lagi, keluar kiri ke arah {toward}, Boss.',
    ],
    Cue.exitRight: [
      '{d} lagi, keluar kanan Boss. Jangan tersasar, nanti pusing jauh.',
      '{d} lagi, keluar kanan ke arah {toward}, Boss.',
    ],
    Cue.uTurn: [
      'Boss, {d} lagi, U-turn. Pusing balik, takpe, bukan salah Boss.',
    ],
    Cue.roundabout: [
      'Boss, bulatan dalam {d}. Ikut papan tanda, jangan pusing sampai pening.',
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
  },
  now: {
    Cue.turnLeft: ['Belok kiri sekarang, Boss!'],
    Cue.turnRight: ['Belok kanan sekarang, Boss!'],
    Cue.exitLeft: ['Keluar kiri sekarang!'],
    Cue.exitRight: ['Keluar kanan sekarang!'],
  },
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
    ],
    Cue.keepRight: [
      'Keep right in {d}. Lanes exist for a reason. Allegedly.',
      'Keep right in {d} for {toward}. The sign is big and green for a reason.',
    ],
    Cue.exitLeft: [
      'Exit on the left in {d}. No, not the next one. This one.',
      'Exit on the left in {d} towards {toward}. No, not the next one. This one.',
    ],
    Cue.exitRight: [
      'Exit on the right in {d}. No, not the next one. This one.',
      'Exit on the right in {d} towards {toward}. No, not the next one. This one.',
    ],
    Cue.uTurn: [
      'U-turn in {d}. We all make mistakes. Some of us make them more often.',
    ],
    Cue.roundabout: [
      'Roundabout in {d}. Pick a lane, any lane. Actually, not any lane.',
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
  },
  now: {
    Cue.turnLeft: ['Left. Now.'],
    Cue.turnRight: ['Right. Now. Please.'],
    Cue.exitLeft: ['Exit left. Now.'],
    Cue.exitRight: ['Exit right. Now.'],
  },
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
    Cue.keepLeft: ['In {d}, keep left.', 'In {d}, keep left towards {toward}.'],
    Cue.keepRight: ['In {d}, keep right.', 'In {d}, keep right towards {toward}.'],
    Cue.exitLeft: ['In {d}, take the exit on the left.', 'In {d}, take the exit on the left towards {toward}.'],
    Cue.exitRight: ['In {d}, take the exit on the right.', 'In {d}, take the exit on the right towards {toward}.'],
    Cue.uTurn: ['In {d}, make a U-turn.'],
    Cue.roundabout: ['In {d}, enter the roundabout.'],
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
  },
  now: {
    Cue.turnLeft: ['Turn left now.'],
    Cue.turnRight: ['Turn right now.'],
    Cue.exitLeft: ['Take the exit now.'],
    Cue.exitRight: ['Take the exit now.'],
  },
);

const kVoicePacks = <VoicePack>[kMamakBoss, kKlite, kSerious];
