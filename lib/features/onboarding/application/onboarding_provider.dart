import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/prefs.dart';

class OnboardedNotifier extends Notifier<bool> {
  static const _key = 'onboarded.v1';

  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(_key) ?? false;

  void complete() {
    ref.read(sharedPrefsProvider).setBool(_key, true);
    state = true;
  }
}

final onboardedProvider =
    NotifierProvider<OnboardedNotifier, bool>(OnboardedNotifier.new);
