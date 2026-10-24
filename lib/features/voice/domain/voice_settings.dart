import 'voice_pack.dart';

class VoiceSettings {
  const VoiceSettings({required this.pack, this.muted = false});
  final VoicePack pack;
  final bool muted;

  VoiceSettings copyWith({VoicePack? pack, bool? muted}) =>
      VoiceSettings(pack: pack ?? this.pack, muted: muted ?? this.muted);
}
