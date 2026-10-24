import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Random and anonymous: no phone number, no account. Replaced every 7 days.
String currentDeviceId(SharedPreferences prefs) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final created = prefs.getInt('device.created') ?? 0;
  var id = prefs.getString('device.id');
  if (id == null || now - created > const Duration(days: 7).inMilliseconds) {
    id = const Uuid().v4();
    prefs.setString('device.id', id);
    prefs.setInt('device.created', now);
  }
  return id;
}
