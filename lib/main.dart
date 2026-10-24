import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class JomlahApp extends StatelessWidget {
  const JomlahApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Jomlah',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFFFF4F8B),
          brightness: Brightness.dark,
        ),
        home: const _Gate(),
      );
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
