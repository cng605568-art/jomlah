import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/language.dart';
import '../../voice/application/voice_providers.dart';

/// Switches the app to [language]. The voice follows, unless it already speaks that language:
/// someone who picks 中文 gets a Mandarin voice, and can still pick another one afterwards.
void chooseLanguage(WidgetRef ref, AppLanguage language) {
  ref.read(languageProvider.notifier).set(language);
  ref.read(voiceSettingsProvider.notifier).matchLanguage(language);
}
