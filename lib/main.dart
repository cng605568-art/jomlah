import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_theme.dart';
import 'core/l10n/language.dart';
import 'core/prefs.dart';
import 'features/map/presentation/map_screen.dart';
import 'features/onboarding/application/onboarding_provider.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const JomlahApp(),
    ),
  );
}

class JomlahApp extends ConsumerWidget {
  const JomlahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final strings = ref.watch(stringsProvider);
    return MaterialApp(
      title: 'Jomlah',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // The chosen language, also for Flutter's own texts (copy/paste menu and the like) and for
      // picking Chinese rather than Japanese character shapes.
      locale: language.locale,
      supportedLocales: [for (final l in AppLanguage.values) l.locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Every screen and pop-up sits under this, so any widget can use context.s.
      builder: (context, child) => StringsScope(strings: strings, child: child ?? const SizedBox()),
      home: const _Gate(),
    );
  }
}

/// First launch: safety + privacy screen. After that: the map. The location
/// permission prompt only appears once the map opens, so people read first.
class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(onboardedProvider);
    return onboarded
        ? const MapScreen()
        : OnboardingScreen(onDone: ref.read(onboardedProvider.notifier).complete);
  }
}
