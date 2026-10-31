import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../prefs.dart';
import 'strings.dart';

/// The languages the app speaks. Adding one means adding a column to every line in strings.dart
/// (the code will not build until each text has it).
enum AppLanguage {
  ms('ms', 'Bahasa Melayu'),
  en('en', 'English'),
  zh('zh', '中文');

  const AppLanguage(this.code, this.nativeName);

  final String code; // ISO 639-1, also the start of a voice's TTS locale ("zh-CN")
  final String nativeName; // shown in the picker, always in its own language

  Locale get locale => Locale(code);

  static AppLanguage? fromCode(String? code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return null;
  }
}

/// The first time, the app follows the phone: a phone set to Chinese gets Chinese; everyone else
/// starts in Bahasa Melayu as before (English is one tap away in Settings).
AppLanguage defaultLanguage(Locale phone) => phone.languageCode == 'zh' ? AppLanguage.zh : AppLanguage.ms;

class LanguageNotifier extends Notifier<AppLanguage> {
  static const key = 'app.language';

  @override
  AppLanguage build() {
    final saved = AppLanguage.fromCode(ref.read(sharedPrefsProvider).getString(key));
    return saved ?? defaultLanguage(PlatformDispatcher.instance.locale);
  }

  void set(AppLanguage language) {
    state = language;
    ref.read(sharedPrefsProvider).setString(key, language.code);
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(LanguageNotifier.new);

/// The texts in the chosen language, for code that has a `ref` (notifiers, providers).
final stringsProvider = Provider<AppStrings>((ref) => AppStrings(ref.watch(languageProvider)));

/// Puts the texts in reach of every widget below it (the app wraps everything in one), so plain
/// widgets can say `context.s.searchHint`. Without one (some tests) the texts are in Malay.
class StringsScope extends InheritedWidget {
  const StringsScope({super.key, required this.strings, required super.child});

  final AppStrings strings;

  static AppStrings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StringsScope>()?.strings ?? const AppStrings(AppLanguage.ms);

  @override
  bool updateShouldNotify(StringsScope oldWidget) => oldWidget.strings.language != strings.language;
}

extension StringsOfContext on BuildContext {
  AppStrings get s => StringsScope.of(this);
}
