// Attendance v4: company-kulla (inside) verify + mock block + gate-bypass detect
// + company GPS set from device + employee daily QR + auto re-verify support.
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class AttRecord {
  final String date, username, checkIn;
  final String? checkOut;
  final double lat, lng, distanceM;
  final bool verified, suspicious;
  final String note;
  AttRecord({required this.date, required this.username, required this.checkIn, this.checkOut,
    required this.lat, required this.lng, required this.distanceM, required this.verified,
    this.suspicious = false, this.note = ''});
  Map<String, dynamic> toMap() => {'date': date, 'username': username, 'checkIn': checkIn, 'checkOut': checkOut,
    'lat': lat, 'lng': lng, 'distanceM': distanceM, 'verified': verified, 'suspicious': suspicious, 'note': note};
  static AttRecord fromMap(Map<String, dynamic> m) => AttRecord(
    date: m['date'] ?? '', username: m['username'] ?? '', checkIn: m['checkIn'] ?? '',
    checkOut: m['checkOut'], lat: (m['lat'] ?? 0).toDouble(), lng: (m['lng'] ?? 0).toDouble(),
    distanceM: (m['distanceM'] ?? 0).toDouble(), verified: m['verified'] ?? false,
    suspicious: m['suspicious'] ?? false, note: m['note'] ?? '');
}

class AttendanceService {
  static const _k = 'riv_att_v4';
  static const _kLastVerify = 'riv_last_verify_';

  static String todayKey([DateTime? d]) {
    d ??= DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180, dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * R * asin(sqrt(a));
  }

  static Future<Position> getPosition() async {
    bool on = await Geolocator.isLocationServiceEnabled();
    if (!on) throw 'Location OFF irukku — phone-la ON pannu.';
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw 'Location permission vendaam-nu theriyuthu — App Settings-la Allow pannu.';
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 20));
  }

  // Is current position INSIDE company premises?
  static (bool inside, double dist) insideCheck(Position pos) {
    final d = distanceMeters(pos.latitude, pos.longitude, AppConfig.companyLat, AppConfig.companyLng);
    return (d <= AppConfig.geofenceRadiusMeters, d);
  }

  static String insideMessage(double dist) {
    final allowed = AppConfig.geofenceRadiusMeters.toStringAsFixed(0);
    if (dist <= AppConfig.geofenceRadiusMeters) return 'Company premises KULLA irukkeengal ✓ (${dist.toStringAsFixed(0)}m)';
    return 'Company kulla illa — ${dist.toStringAsFixed(0)}m thooram (allowed: ${allowed}m). Building/compound kulla vandhu mark pannu.';
  }

  // ---- Company GPS persistence (admin sets exact gate/building point) ----
  static Future<void> loadCompanyLocation() async {
    final p = await SharedPreferences.getInstance();
    AppConfig.companyLat = p.getDouble('riv_comp_lat') ?? AppConfig.companyLat;
    AppConfig.companyLng = p.getDouble('riv_comp_lng') ?? AppConfig.companyLng;
    AppConfig.geofenceRadiusMeters = p.getDouble('riv_comp_rad') ?? AppConfig.geofenceRadiusMeters;
  }

  static Future<void> setCompanyLocation(double lat, double lng, double radius) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('riv_comp_lat', lat);
    await p.setDouble('riv_comp_lng', lng);
    await p.setDouble('riv_comp_rad', radius);
    AppConfig.companyLat = lat;
    AppConfig.companyLng = lng;
    AppConfig.geofenceRadiusMeters = radius;
  }

  // ---- Storage ----
  static Future<List<AttRecord>> all() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null) return [];
    final List list = jsonDecode(raw);
    return list.map((e) => AttRecord.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> _saveAll(List<AttRecord> r) async {
    final p = await SharedPreferences.getInstance();
    final trimmed = r.length > 50000 ? r.sublist(r.length - 50000) : r;
    await p.setString(_k, jsonEncode(trimmed.map((e) => e.toMap()).toList()));
  }

  // ---- Check-in: ONLY inside company premises ----
  // pos passed by UI (UI does GPS + inside + biometric first)
  static Future<AttRecord> checkIn(String username, {Position? pos}) async {
    final position = pos ?? await getPosition();
    if (AppConfig.blockMockLocation && position.isMocked) {
      throw 'Fake GPS / Mock location aana oru time-la work aagathu — real location use pannu.';
    }
    final (inside, dist) = insideCheck(position);
    if (!inside) throw insideMessage(dist);
    final recs = await all();
    final key = todayKey();
    if (recs.any((e) => e.username == username && e.date == key)) {
      throw 'Inniku already check-in pottachu — duplicate vendaam.';
    }
    final rec = AttRecord(date: key, username: username, checkIn: DateTime.now().toIso8601String(),
      lat: position.latitude, lng: position.longitude, distanceM: dist, verified: true,
      note: 'Inside premises, biometric/QR verified');
    recs.add(rec);
    await _saveAll(recs);
    await _stampVerify(username);
    return rec;
  }

  static Future<void> _stampVerify(String username) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('$_kLastVerify$username', DateTime.now().toIso8601String());
  }

  static Future<String> lastVerifyText(String username) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('$_kLastVerify$username');
    if (s == null) return 'Inniku re-verify pannala';
    final t = DateTime.tryParse(s);
    if (t == null) return 'Inniku re-verify pannala';
    final mins = DateTime.now().difference(t).inMinutes;
    return mins < 1 ? 'Just now verified' : '$mins min munnadi verified';
  }

  // ---- Re-verify: gate-la mark pottutu veliya ponaal SUSPICIOUS ----
  static Future<String> reVerify(String username) async {
    try {
      final pos = await getPosition();
      final (inside, dist) = insideCheck(pos);
      await _stampVerify(username);
      final recs = await all();
      final key = todayKey();
      final idx = recs.indexWhere((e) => e.username == username && e.date == key);
      if (idx == -1) return 'Inniku check-in illa.';
      final r = recs[idx];
      if (!inside) {
        recs[idx] = AttRecord(date: r.date, username: r.username, checkIn: r.checkIn, checkOut: r.checkOut,
          lat: r.lat, lng: r.lng, distanceM: r.distanceM, verified: true, suspicious: true,
          note: 'Re-verify FAILED: premises veliya (${dist.toStringAsFixed(0)}m). Gate-la mark pottutu poyirukkalam.');
        await _saveAll(recs);
        return 'SUSPICIOUS: Company premises veliya irukkeengal (${dist.toStringAsFixed(0)}m) — Admin-ku flag poyiruchu.';
      }
      if (r.suspicious) {
        recs[idx] = AttRecord(date: r.date, username: r.username, checkIn: r.checkIn, checkOut: r.checkOut,
          lat: r.lat, lng: r.lng, distanceM: r.distanceM, verified: true, suspicious: false,
          note: 'Back inside premises (re-verified)');
        await _saveAll(recs);
      }
      return 'Verified — premises KULLA irukkeengal ✓ (${dist.toStringAsFixed(0)}m)';
    } catch (e) {
      return 'Re-verify fail: $e';
    }
  }

  static Future<void> checkOut(String username) async {
    final pos = await getPosition();
    final recs = await all();
    final key = todayKey();
    final idx = recs.indexWhere((e) => e.username == username && e.date == key);
    if (idx == -1) throw 'Check-in illa — checkout panna mudiyathu.';
    if (recs[idx].checkOut != null) throw 'Already checked-out.';
    final r = recs[idx];
    final (_, dist) = insideCheck(pos);
    recs[idx] = AttRecord(date: r.date, username: r.username, checkIn: r.checkIn,
      checkOut: DateTime.now().toIso8601String(), lat: r.lat, lng: r.lng, distanceM: r.distanceM,
      verified: r.verified, suspicious: r.suspicious, note: r.note);
    await _saveAll(recs);
    if (dist > AppConfig.geofenceRadiusMeters) {
      // outside while checkout: note it (going home path normal, keep info only)
      final rr = await all();
      final i2 = rr.indexWhere((e) => e.username == username && e.date == key);
      if (i2 != -1 && rr[i2].note.isEmpty) {
        rr[i2] = AttRecord(date: rr[i2].date, username: rr[i2].username, checkIn: rr[i2].checkIn,
          checkOut: rr[i2].checkOut, lat: rr[i2].lat, lng: rr[i2].lng, distanceM: rr[i2].distanceM,
          verified: rr[i2].verified, suspicious: rr[i2].suspicious, note: 'Checkout outside premises');
        await _saveAll(rr);
      }
    }
  }

  static Future<List<AttRecord>> forUser(String username) async {
    final r = await all();
    final f = r.where((e) => e.username == username).toList();
    f.sort((a, b) => b.date.compareTo(a.date));
    return f;
  }

  static AttRecord? todayOf(String username, List<AttRecord> allRecs) {
    final k = todayKey();
    for (final r in allRecs) { if (r.username == username && r.date == k) return r; }
    return null;
  }

  // ---- Employee daily QR (valid ONE day only) ----
  static String _sig(String u, String d) =>
      sha256.convert(utf8.encode('$u|$d|${AppConfig.qrSecret}')).toString().substring(0, 16);

  static String employeeQRPayload(String username) {
    final d = todayKey();
    return 'RIVQR|$username|$d|${_sig(username, d)}';
  }

  /// returns username if QR valid for TODAY, else null
  static String? validateEmployeeQR(String code) {
    final p = code.split('|');
    if (p.length != 4 || p[0] != 'RIVQR') return null;
    if (p[2] != todayKey()) return null; // yesterday QR invalid
    if (sigOf(p[1], p[2]) != p[3]) return null;
    return p[1];
  }

  static String sigOf(String u, String d) => _sig(u, d);
}
