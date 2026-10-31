import '../../map/domain/report.dart';

// Voice reports: what the driver said -> which alert. Words from all three languages are checked
// whatever the app's language, because Malaysians mix them ("ada police kat depan", "前面有 polis").

const _words = <ReportType, List<String>>{
  ReportType.police: [
    'abang polis', 'polis', 'police', 'cop', 'cops', 'roadblock', 'road block', 'sekatan', 'sjr',
    'speed trap', 'perangkap laju', '警察', '路障', '警方', '查车',
  ],
  ReportType.camera: [
    'kamera', 'camera', 'aes', 'speed camera', 'kamera laju', 'awas', '测速', '相机', '摄像头', '摄像机', '照相',
  ],
  ReportType.flood: ['banjir', 'flood', 'flooded', 'flooding', 'air naik', '水灾', '淹水', '水患', '积水', '水浸'],
  ReportType.pothole: ['lubang', 'pothole', 'potholes', 'hole', 'jalan rosak', '路洞', '坑洞', '坑', '窟窿'],
  ReportType.brokenLorry: [
    'lori rosak', 'lori', 'lorry', 'truck', 'broken down', 'breakdown', 'kereta rosak', 'kenderaan rosak',
    'rosak', '罗里', '抛锚', '坏车', '车坏', '卡车',
  ],
  ReportType.jam: ['jem', 'jam', 'sesak', 'traffic', 'macet', 'slow', '塞车', '堵车', '堵', '塞'],
  ReportType.crash: [
    'kemalangan', 'accident', 'crash', 'langgar', 'eksiden', 'collision', '车祸', '意外', '撞车', '撞',
  ],
};

const _cancel = ['batal', 'cancel', 'tak jadi', 'tidak jadi', 'never mind', 'nevermind', '取消', '算了', '不用了'];

final _cjk = RegExp(r'[㐀-鿿]');

/// Lower case, no punctuation, single spaces, and a space wherever Chinese meets Latin letters
/// ("前面有polis" -> "前面有 polis"). Chinese characters stay as they are.
String _normal(String s) {
  var t = s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ');
  t = t.replaceAllMapped(RegExp(r'([\u3400-\u9fff])([a-z0-9])'), (m) => '${m[1]} ${m[2]}');
  t = t.replaceAllMapped(RegExp(r'([a-z0-9])([\u3400-\u9fff])'), (m) => '${m[1]} ${m[2]}');
  return ' ${t.trim().replaceAll(RegExp(r' +'), ' ')} ';
}

/// Where [word] first appears in [text] (normalised), or -1. Latin words must be whole words;
/// Chinese ones can be anywhere, since Chinese has no spaces.
int _find(String text, String word) {
  if (_cjk.hasMatch(word)) return text.indexOf(word);
  final i = text.indexOf(' $word ');
  return i < 0 ? -1 : i + 1;
}

/// The alert the driver asked for, from what the recogniser heard (its best guess first, then
/// alternatives). The earliest alert word wins; on a tie the longer phrase ("lori rosak" over
/// "rosak"). Null when nothing matches.
ReportType? reportFromSpeech(List<String> heard) {
  for (final h in heard) {
    final text = _normal(h);
    ReportType? best;
    var bestAt = 1 << 30;
    var bestLen = 0;
    _words.forEach((type, words) {
      for (final w in words) {
        final at = _find(text, w);
        if (at < 0) continue;
        if (at < bestAt || (at == bestAt && w.length > bestLen)) {
          best = type;
          bestAt = at;
          bestLen = w.length;
        }
      }
    });
    if (best != null) return best;
  }
  return null;
}

/// "batal", "cancel", "取消"...
bool isCancel(List<String> heard) => heard.any((h) {
      final text = _normal(h);
      return _cancel.any((w) => _find(text, w) >= 0);
    });
