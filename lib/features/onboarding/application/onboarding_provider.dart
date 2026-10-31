import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/prefs.dart';

class OnboardedNotifier extends Notifier<bool> {
  // v2 (v1.0.7): shown once more to everyone, because alerts are now shared (see the new point).
  static const _key = 'onboarded.v2';

  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(_key) ?? false;

  void complete() {
    ref.read(sharedPrefsProvider).setBool(_key, true);
    state = true;
  }
}

final onboardedProvider =
    NotifierProvider<OnboardedNotifier, bool>(OnboardedNotifier.new);
