import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/prefs.dart';
import 'features/map/presentation/map_screen.dart';

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
        home: const MapScreen(),
      );
}
