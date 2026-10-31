// Newer versions without Google Play: releases are published on GitHub, and the app compares its
// own tag with theirs.

/// "v1.0.10(BETA)" or "V1.0.4(BETA)" -> [1, 0, 10]. Null for builds without a version ("dev build 40").
List<int>? parseVersion(String tag) {
  final m = RegExp(r'^[vV]?(\d+)\.(\d+)\.(\d+)').firstMatch(tag.trim());
  if (m == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(m[i]!)];
}

/// Negative when [a] is older than [b], zero when equal, positive when newer.
int compareVersions(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] - b[i];
  }
  return 0;
}

/// A newer release someone can install.
class AvailableUpdate {
  const AvailableUpdate(this.tag);
  final String tag;
}

/// The newest release in GitHub's list (`GET /repos/{owner}/{repo}/releases`) that is newer than
/// [current] and has an APK attached, or null. Pre-releases count: every beta is one.
AvailableUpdate? newestRelease(List<Object?> releases, String current) {
  final mine = parseVersion(current);
  if (mine == null) return null; // a test build: nothing to compare with
  String? bestTag;
  List<int>? best;
  for (final r in releases) {
    if (r is! Map || r['draft'] == true) continue;
    final tag = r['tag_name'];
    final assets = r['assets'];
    if (tag is! String || assets is! List) continue;
    final hasApk = assets.any((a) => a is Map && '${a['name']}'.toLowerCase().endsWith('.apk'));
    final v = parseVersion(tag);
    if (!hasApk || v == null || compareVersions(v, mine) <= 0) continue;
    if (best == null || compareVersions(v, best) > 0) {
      best = v;
      bestTag = tag;
    }
  }
  return bestTag == null ? null : AvailableUpdate(bestTag);
}

/// The download page for [repo] ("owner/name"): GitHub Pages, which links the newest APK.
String downloadPageFor(String repo) {
  final parts = repo.split('/');
  return parts.length == 2 ? 'https://${parts[0]}.github.io/${parts[1]}/' : 'https://github.com/$repo/releases';
}
