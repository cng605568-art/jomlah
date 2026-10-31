import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_info.dart';
import '../../../core/prefs.dart';
import '../domain/app_version.dart';

/// Reads the repository's releases from GitHub. A seam, so tests can pretend.
abstract class ReleaseFeed {
  Future<List<Object?>> releases();
}

class GitHubReleaseFeed implements ReleaseFeed {
  GitHubReleaseFeed(this.repo, {http.Client? client}) : _client = client ?? http.Client();
  final String repo;
  final http.Client _client;

  @override
  Future<List<Object?>> releases() async {
    final res = await _client.get(
      Uri.parse('https://api.github.com/repos/$repo/releases?per_page=20'),
      headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'Jomlah-app'},
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('GitHub said ${res.statusCode}');
    final body = jsonDecode(res.body);
    return body is List ? body : const [];
  }
}

final releaseFeedProvider = Provider<ReleaseFeed?>((ref) => kRepo.isEmpty ? null : GitHubReleaseFeed(kRepo));

/// This app's own version tag ("v1.0.10(BETA)"), from the build.
final currentVersionProvider = Provider<String>((ref) => kAppVersion);

/// Settings > "Check for new versions". On by default.
class UpdateCheckNotifier extends Notifier<bool> {
  static const key = 'update.check';

  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(key) ?? true;

  void set(bool on) {
    state = on;
    ref.read(sharedPrefsProvider).setBool(key, on);
  }
}

final updateCheckProvider = NotifierProvider<UpdateCheckNotifier, bool>(UpdateCheckNotifier.new);

const kUpdateCheckedAtKey = 'update.checkedAt';
const kUpdateLatestKey = 'update.latest';
const kUpdateToldKey = 'update.told';
const kUpdateEvery = Duration(hours: 12);

/// A newer version on GitHub, or null. Asks GitHub at most every 12 hours and remembers the answer
/// in between, so most app starts make no request at all. Never throws: no internet just means no
/// notice this time.
final updateProvider = FutureProvider<AvailableUpdate?>((ref) async {
  final feed = ref.watch(releaseFeedProvider);
  final current = ref.watch(currentVersionProvider);
  if (feed == null || !ref.watch(updateCheckProvider) || parseVersion(current) == null) return null;
  final prefs = ref.read(sharedPrefsProvider);

  final checkedAt = DateTime.fromMillisecondsSinceEpoch(prefs.getInt(kUpdateCheckedAtKey) ?? 0);
  if (DateTime.now().difference(checkedAt) < kUpdateEvery) {
    final latest = prefs.getString(kUpdateLatestKey);
    if (latest == null) return null;
    final v = parseVersion(latest);
    return v != null && compareVersions(v, parseVersion(current)!) > 0 ? AvailableUpdate(latest) : null;
  }

  try {
    final found = newestRelease(await feed.releases(), current);
    await prefs.setInt(kUpdateCheckedAtKey, DateTime.now().millisecondsSinceEpoch);
    if (found == null) {
      await prefs.remove(kUpdateLatestKey);
    } else {
      await prefs.setString(kUpdateLatestKey, found.tag);
    }
    return found;
  } catch (_) {
    return null;
  }
});

/// "Download": opens the large-text install page in the browser. It picks the newest APK, and the
/// phone installs it over this version. The app itself never downloads or installs anything.
Future<void> openDownloadPage() =>
    launchUrl(Uri.parse(downloadPageFor(kRepo)), mode: LaunchMode.externalApplication);
