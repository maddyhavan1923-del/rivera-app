// Leave + CRM inbox + Daily Diary + Reference + Visitor + Excel export
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// ---------- LEAVE (applied -> CRM/Admin inbox ku pogum) ----------
class LeaveReq {
  final String id, username, type, from, to, reason, status, appliedOn;
  LeaveReq({required this.id, required this.username, required this.type, required this.from,
    required this.to, required this.reason, this.status = 'Applied', required this.appliedOn});
  Map<String, dynamic> toMap() => {'id': id, 'username': username, 'type': type, 'from': from, 'to': to, 'reason': reason, 'status': status, 'appliedOn': appliedOn};
  static LeaveReq fromMap(Map<String, dynamic> m) => LeaveReq(id: m['id'] ?? '', username: m['username'] ?? '',
    type: m['type'] ?? '', from: m['from'] ?? '', to: m['to'] ?? '', reason: m['reason'] ?? '',
    status: m['status'] ?? 'Applied', appliedOn: m['appliedOn'] ?? '');
}

class LeaveService {
  static const _k = 'riv_leave_v3';
  static Future<List<LeaveReq>> all() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => LeaveReq.fromMap(Map<String, dynamic>.from(e))).toList();
  }
  static Future<void> apply(String username, String type, String from, String to, String reason) async {
    final p = await SharedPreferences.getInstance();
    final list = await all();
    list.add(LeaveReq(id: const Uuid().v4(), username: username, type: type, from: from, to: to, reason: reason, appliedOn: DateTime.now().toIso8601String()));
    final t = list.length > 20000 ? list.sublist(list.length - 20000) : list;
    await p.setString(_k, jsonEncode(t.map((e) => e.toMap()).toList()));
  }
  static Future<void> setStatus(String id, String status) async {
    final p = await SharedPreferences.getInstance();
    final list = await all();
    final i = list.indexWhere((e) => e.id == id);
    if (i != -1) {
      final l = list[i];
      list[i] = LeaveReq(id: l.id, username: l.username, type: l.type, from: l.from, to: l.to, reason: l.reason, status: status, appliedOn: l.appliedOn);
      await p.setString(_k, jsonEncode(list.map((e) => e.toMap()).toList()));
    }
  }
}

// ---------- DAILY DIARY (ellraum daily work update) ----------
class DiaryEntry {
  final String id, username, date, work, createdOn;
  DiaryEntry({required this.id, required this.username, required this.date, required this.work, required this.createdOn});
  Map<String, dynamic> toMap() => {'id': id, 'username': username, 'date': date, 'work': work, 'createdOn': createdOn};
  static DiaryEntry fromMap(Map<String, dynamic> m) => DiaryEntry(id: m['id'] ?? '', username: m['username'] ?? '',
    date: m['date'] ?? '', work: m['work'] ?? '', createdOn: m['createdOn'] ?? '');
}

class DiaryService {
  static const _k = 'riv_diary_v3';
  static Future<List<DiaryEntry>> all() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => DiaryEntry.fromMap(Map<String, dynamic>.from(e))).toList();
  }
  static Future<void> add(String username, String date, String work) async {
    final p = await SharedPreferences.getInstance();
    final list = await all();
    list.add(DiaryEntry(id: const Uuid().v4(), username: username, date: date, work: work, createdOn: DateTime.now().toIso8601String()));
    final t = list.length > 30000 ? list.sublist(list.length - 30000) : list;
    await p.setString(_k, jsonEncode(t.map((e) => {'id': e.id, 'username': e.username, 'date': e.date, 'work': e.work, 'createdOn': e.createdOn}).toList()));
  }
}

// ---------- REFERENCE TAB (employee referrals / company refs) ----------
class ReferenceService {
  static const _k = 'riv_ref_v3';
  static Future<List<Map<String, String>>> all() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Map<String, String>.from(e.map((k, v) => MapEntry(k.toString(), v.toString())))).toList();
  }
  static Future<void> add(Map<String, String> m) async {
    final p = await SharedPreferences.getInstance();
    final list = await all();
    list.add({...m, 'on': DateTime.now().toIso8601String()});
    await p.setString(_k, jsonEncode(list));
  }
}

// ---------- VISITORS (daily live QR + entry + exit feedback) ----------
class VisitorService {
  static const _k = 'riv_visit_v3';

  // Everyday live QR payload — date changes daily, so old QR reuse panna mudiyathu
  static String dailyQRPayload([DateTime? d]) {
    d ??= DateTime.now();
    final ds = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return 'RIVERA-VISIT-$ds-QRQ3'; // scanner validates today's date inside
  }
  static bool isQRValidToday(String scanned) {
    final today = dailyQRPayload();
    return scanned.trim() == today;
  }

  static Future<List<Map<String, String>>> all() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Map<String, String>.from(e.map((k, v) => MapEntry(k.toString(), v.toString())))).toList();
  }
  static Future<void> entry(Map<String, String> m) async {
    final p = await SharedPreferences.getInstance();
    final list = await all();
    list.add({...m, 'in': DateTime.now().toIso8601String(), 'feedback': '', 'out': ''});
    await p.setString(_k, jsonEncode(list.length > 20000 ? list.sublist(list.length - 20000) : list));
  }
  static Future<void> feedback(int index, String feedback) async {
    final p = await SharedPreferences.getInstance();
    final list = await all();
    if (index < 0 || index >= list.length) return;
    list[index]['feedback'] = feedback;
    list[index]['out'] = DateTime.now().toIso8601String();
    await p.setString(_k, jsonEncode(list));
  }
}
