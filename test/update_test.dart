import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jomlah/core/prefs.dart';
import 'package:jomlah/features/update/application/update_providers.dart';
import 'package:jomlah/features/update/domain/app_version.dart';

// "New version is out": without Google Play, the app compares its tag with the releases on GitHub.

Map<String, Object?> _release(String tag, {bool apk = true, bool draft = false}) => {
      'tag_name': tag,
      'draft': draft,
      'prerelease': true,
      'assets': [
        if (apk) {'name': 'app-release.apk'},
      ],
    };

final _releases = [
  _release('v2.0.0(BETA)', draft: true), // not published yet
  _release('v1.0.11(BETA)', apk: false), // the APK is still building
  _release('v1.0.10(BETA)'),
  _release('v1.0.9(BETA)'),
  _release('V1.0.4(BETA)'),
];

class _FakeFeed implements ReleaseFeed {
  _FakeFeed(this.answer);
  final List<Object?> answer;
  int calls = 0;
  bool fail = false;

  @override
  Future<List<Object?>> releases() async {
    calls++;
    if (fail) throw Exception('no internet');
    return answer;
  }
}

void main() {
  test('reads version tags, including the capital V and builds without one', () {
    expect(parseVersion('v1.0.10(BETA)'), [1, 0, 10]);
    expect(parseVersion('V1.0.4(BETA)'), [1, 0, 4]);
    expect(parseVersion('dev build 40'), isNull);
    expect(parseVersion('dev'), isNull);
    expect(compareVersions([1, 0, 10], [1, 0, 9]), greaterThan(0)); // 10 is newer than 9
    expect(compareVersions([1, 0, 9], [1, 1, 0]), lessThan(0));
  });

  test('picks the newest published release with an APK', () {
    expect(newestRelease(_releases, 'v1.0.9(BETA)')?.tag, 'v1.0.10(BETA)');
    expect(newestRelease(_releases, 'V1.0.4(BETA)')?.tag, 'v1.0.10(BETA)');
    expect(newestRelease(_releases, 'v1.0.10(BETA)'), isNull); // up to date
    expect(newestRelease(_releases, 'dev build 40'), isNull); // test builds are never nagged
  });

  test('Download goes to the install page', () {
    expect(downloadPageFor('cng605568-art/jomlah'), 'https://cng605568-art.github.io/jomlah/');
  });

  group('checking', () {
    late SharedPreferences prefs;
    late _FakeFeed feed;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      feed = _FakeFeed(_releases);
    });

    ProviderContainer open(String version) {
      final c = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        releaseFeedProvider.overrideWithValue(feed),
        currentVersionProvider.overrideWithValue(version),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('asks GitHub once, then remembers the answer for 12 hours', () async {
      expect((await open('v1.0.9(BETA)').read(updateProvider.future))?.tag, 'v1.0.10(BETA)');
      expect(feed.calls, 1);
      // The next start: no request, same answer.
      expect((await open('v1.0.9(BETA)').read(updateProvider.future))?.tag, 'v1.0.10(BETA)');
      expect(feed.calls, 1);
      // After installing it, the remembered release is no longer newer.
      expect(await open('v1.0.10(BETA)').read(updateProvider.future), isNull);
      expect(feed.calls, 1);
      // Half a day later it asks again.
      await prefs.setInt(kUpdateCheckedAtKey, DateTime.now().subtract(const Duration(hours: 13)).millisecondsSinceEpoch);
      await open('v1.0.10(BETA)').read(updateProvider.future);
      expect(feed.calls, 2);
    });

    test('no internet means no notice, and it tries again next time', () async {
      feed.fail = true;
      expect(await open('v1.0.9(BETA)').read(updateProvider.future), isNull);
      feed.fail = false;
      expect((await open('v1.0.9(BETA)').read(updateProvider.future))?.tag, 'v1.0.10(BETA)');
      expect(feed.calls, 2);
    });

    test('turned off in Settings: no request at all', () async {
      final c = open('v1.0.9(BETA)');
      c.read(updateCheckProvider.notifier).set(false);
      expect(await c.read(updateProvider.future), isNull);
      expect(feed.calls, 0);
      expect(prefs.getBool(UpdateCheckNotifier.key), isFalse);
    });

    test('test builds never ask', () async {
      expect(await open('dev build 40').read(updateProvider.future), isNull);
      expect(feed.calls, 0);
    });
  });
}
