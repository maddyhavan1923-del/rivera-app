// Attendance: geofence verify + mock-location block + gate-bypass detection.
// - Inside geofence = Verified Present
// - Gate-la mark pottutu veliya pona: re-verify timer + auto 'Suspicious/Left-early' flag
// - Offline-first, works 365 days any year (key = yyyy-MM-dd, no year limit).
import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class AttRecord {
  final String date; // yyyy-MM-dd
  final String username;
  final String checkIn; // ISO
  final String? checkOut;
  final double lat; final double lng; final double distanceM;
  final bool verified; final bool suspicious; final String note;
  AttRecord({required this.date, required this.username, required this.checkIn, this.checkOut,
    required this.lat, required this.lng, required this.distanceM, required this.verified, this.suspicious = false, this.note = ''});
  Map<String, dynamic> toMap() => {'date': date, 'username': username, 'checkIn': checkIn, 'checkOut': checkOut,
    'lat': lat, 'lng': lng, 'distanceM': distanceM, 'verified': verified, 'suspicious': suspicious, 'note': note};
  static AttRecord fromMap(Map<String, dynamic> m) => AttRecord(
    date: m['date'] ?? '', username: m['username'] ?? '', checkIn: m['checkIn'] ?? '',
    checkOut: m['checkOut'], lat: (m['lat'] ?? 0).toDouble(), lng: (m['lng'] ?? 0).toDouble(),
    distanceM: (m['distanceM'] ?? 0).toDouble(), verified: m['verified'] ?? false,
    suspicious: m['suspicious'] ?? false, note: m['note'] ?? '');
}

class AttendanceService {
  static const _k = 'riv_att_v3';

  static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180, dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * R * asin(sqrt(a));
  }

  static String todayKey([DateTime? d]) {
    d ??= DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static Future<Position> getPosition() async {
    bool on = await Geolocator.isLocationServiceEnabled();
    if (!on) throw 'Location OFF irukku — ON pannu.';
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw 'Location permission kudu (App settings la Allow).';
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 20));
  }

  static Future<List<AttRecord>> all() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null) return [];
    final List list = jsonDecode(raw);
    return list.map((e) => AttRecord.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> _saveAll(List<AttRecord> r) async {
    final p = await SharedPreferences.getInstance();
    // cap at 50,000 records (~137 years of 1 user/day) — oldest trimmed, never crashes
    final trimmed = r.length > 50000 ? r.sublist(r.length - 50000) : r;
    await p.setString(_k, jsonEncode(trimmed.map((e) => e.toMap()).toList()));
  }

  // Check-in with full verification
  static Future<AttRecord> checkIn(String username) async {
    final pos = await getPosition();
    if (AppConfig.blockMockLocation && pos.isMocked) {
      throw 'Fake GPS / Mock location detected! Original location-mattum use pannu.';
    }
    final dist = distanceMeters(pos.latitude, pos.longitude, AppConfig.companyLat, AppConfig.companyLng);
    final inside = dist <= AppConfig.geofenceRadiusMeters;
    if (!inside) {
      throw 'Company premises-kulla illa (distance: ${dist.toStringAsFixed(0)}m, allowed: ${AppConfig.geofenceRadiusMeters.toStringAsFixed(0)}m). Gate-kitda vandhu mark pannu.';
    }
    final recs = await all();
    final key = todayKey();
    final existing = recs.where((e) => e.username == username && e.date == key);
    if (existing.isNotEmpty) throw 'Inniku already check-in pottacha — duplicate vendaam.';
    final rec = AttRecord(date: key, username: username, checkIn: DateTime.now().toIso8601String(),
      lat: pos.latitude, lng: pos.longitude, distanceM: dist, verified: true);
    recs.add(rec);
    await _saveAll(recs);
    final p = await SharedPreferences.getInstance();
    await p.setString('riv_last_verify_$username', DateTime.now().toIso8601String());
    return rec;
  }

  // Re-verify (anti-bypass): gate-la pottutu veliya ponaal kandupudikkum
  static Future<String> reVerify(String username) async {
    try {
      final pos = await getPosition();
      final dist = distanceMeters(pos.latitude, pos.longitude, AppConfig.companyLat, AppConfig.companyLng);
      final p = await SharedPreferences.getInstance();
      await p.setString('riv_last_verify_$username', DateTime.now().toIso8601String());
      final recs = await all();
      final key = todayKey();
      final idx = recs.indexWhere((e) => e.username == username && e.date == key);
      if (idx == -1) return 'Inniku check-in illa.';
      if (dist > AppConfig.geofenceRadiusMeters) {
        recs[idx] = AttRecord(date: recs[idx].date, username: recs[idx].username, checkIn: recs[idx].checkIn,
          checkOut: recs[idx].checkOut, lat: recs[idx].lat, lng: recs[idx].lng, distanceM: recs[idx].distanceM,
          verified: true, suspicious: true,
          note: 'Re-verify: premises veliya (${dist.toStringAsFixed(0)}m). Gate-la mark pottutu poyirukkalam.');
        await _saveAll(recs);
        return 'WARNING: Company veliya irukka (${dist.toStringAsFixed(0)}m). Admin-ku "Suspicious" flag poyiruchu.';
      }
      // clear suspicious if back inside
      if (recs[idx].suspicious) {
        recs[idx] = AttRecord(date: recs[idx].date, username: recs[idx].username, checkIn: recs[idx].checkIn,
          checkOut: recs[idx].checkOut, lat: recs[idx].lat, lng: recs[idx].lng, distanceM: recs[idx].distanceM,
          verified: true, suspicious: false, note: 'Back inside premises (re-verified).');
        await _saveAll(recs);
      }
      return 'Verified — company-kulla irukka (${dist.toStringAsFixed(0)}m).';
    } catch (e) {
      return 'Re-verify failed: $e';
    }
  }

  static Future<void> checkOut(String username) async {
    final pos = await getPosition();
    final recs = await all();
    final key = todayKey();
    final idx = recs.indexWhere((e) => e.username == username && e.date == key);
    if (idx == -1) throw 'Check-in illa — checkout panna mudiyathu.';
    if (recs[idx].checkOut != null) throw 'Already checked-out.';
    final dist = distanceMeters(pos.latitude, pos.longitude, AppConfig.companyLat, AppConfig.companyLng);
    recs[idx] = AttRecord(date: recs[idx].date, username: recs[idx].username, checkIn: recs[idx].checkIn,
      checkOut: DateTime.now().toIso8601String(), lat: recs[idx].lat, lng: recs[idx].lng,
      distanceM: recs[idx].distanceM, verified: recs[idx].verified,
      suspicious: recs[idx].suspicious, note: recs[idx].note);
    await _saveAll(recs);
  }

  static Future<List<AttRecord>> forUser(String username) async {
    final r = await all();
    final f = r.where((e) => e.username == username).toList();
    f.sort((a, b) => b.date.compareTo(a.date));
    return f;
  }
}
