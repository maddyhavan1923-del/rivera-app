// Auth: register (office staff only), login, logout, admin creates user/password in-app.
// Storage: SharedPreferences (offline-first, no expiry, works every year).
// Passwords stored as SHA-256 hash. 1000-year safe: no date limits on accounts.
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class AppUser {
  final String username;
  final String name;
  final String role; // admin | staff
  final String department;
  final String phone;
  final String createdOn; // ISO date
  AppUser({required this.username, required this.name, required this.role, this.department = '', this.phone = '', required this.createdOn});
  Map<String, dynamic> toMap() => {'username': username, 'name': name, 'role': role, 'department': department, 'phone': phone, 'createdOn': createdOn};
  static AppUser fromMap(Map<String, dynamic> m) => AppUser(
    username: m['username'] ?? '', name: m['name'] ?? '', role: m['role'] ?? 'staff',
    department: m['department'] ?? '', phone: m['phone'] ?? '', createdOn: m['createdOn'] ?? '');
}

class AuthService {
  static const _kUsers = 'riv_users_v3';
  static const _kPass = 'riv_pass_v3';
  static const _kSession = 'riv_session_v3';

  static String hash(String s) => sha256.convert(utf8.encode(s)).toString();

  static Future<void> ensureDefaultAdmin() async {
    final p = await SharedPreferences.getInstance();
    final usersRaw = p.getString(_kUsers);
    if (usersRaw == null) {
      final admin = AppUser(username: AppConfig.defaultAdminUser, name: 'Administrator',
        role: 'admin', department: 'Management', createdOn: DateTime.now().toIso8601String());
      await p.setString(_kUsers, jsonEncode([admin.toMap()]));
      final pass = {AppConfig.defaultAdminUser: hash(AppConfig.defaultAdminPass)};
      await p.setString(_kPass, jsonEncode(pass));
    }
  }

  static Future<List<AppUser>> allUsers() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kUsers);
    if (raw == null) return [];
    final List list = jsonDecode(raw);
    return list.map((e) => AppUser.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  static Future<bool> userExists(String username) async {
    final users = await allUsers();
    return users.any((u) => u.username.toLowerCase() == username.toLowerCase());
  }

  // Admin creates login for staff in-app
  static Future<String?> adminCreateUser({required String username, required String password, required String name, String department = '', String phone = '', String role = 'staff'}) async {
    username = username.trim();
    if (username.isEmpty || password.length < 4 || name.trim().isEmpty) return 'Username/Name/Password (min 4 chars) correct-ah kudu.';
    if (await userExists(username)) return 'Indha username already irukku.';
    final p = await SharedPreferences.getInstance();
    final users = await allUsers();
    users.add(AppUser(username: username, name: name.trim(), role: role, department: department, phone: phone, createdOn: DateTime.now().toIso8601String()));
    await p.setString(_kUsers, jsonEncode(users.map((u) => u.toMap()).toList()));
    final passRaw = p.getString(_kPass) ?? '{}';
    final Map<String, dynamic> pass = jsonDecode(passRaw);
    pass[username] = hash(password);
    await p.setString(_kPass, jsonEncode(pass));
    return null;
  }

  static Future<bool> adminResetPassword(String username, String newPass) async {
    if (newPass.length < 4) return false;
    final p = await SharedPreferences.getInstance();
    final passRaw = p.getString(_kPass) ?? '{}';
    final Map<String, dynamic> pass = jsonDecode(passRaw);
    pass[username] = hash(newPass);
    await p.setString(_kPass, jsonEncode(pass));
    return true;
  }

  static Future<bool> adminDeleteUser(String username) async {
    if (username == AppConfig.defaultAdminUser) return false;
    final p = await SharedPreferences.getInstance();
    final users = await allUsers();
    users.removeWhere((u) => u.username == username);
    await p.setString(_kUsers, jsonEncode(users.map((u) => u.toMap()).toList()));
    final passRaw = p.getString(_kPass) ?? '{}';
    final Map<String, dynamic> pass = jsonDecode(passRaw);
    pass.remove(username);
    await p.setString(_kPass, jsonEncode(pass));
    return true;
  }

  // Staff self-register (office staff only) — needs username+password, admin can disable via flag if needed
  static Future<String?> register({required String username, required String password, required String name, String department = '', String phone = ''}) async {
    return adminCreateUser(username: username, password: password, name: name, department: department, phone: phone, role: 'staff');
  }

  static Future<AppUser?> login(String username, String password) async {
    final p = await SharedPreferences.getInstance();
    final passRaw = p.getString(_kPass) ?? '{}';
    final Map<String, dynamic> pass = jsonDecode(passRaw);
    final stored = pass[username.trim()];
    if (stored == null) return null;
    if (stored != hash(password)) return null;
    final users = await allUsers();
    final u = users.firstWhere((e) => e.username == username.trim(), orElse: () => AppUser(username: '', name: '', role: '', createdOn: ''));
    if (u.username.isEmpty) return null;
    await p.setString(_kSession, jsonEncode(u.toMap()));
    await p.setString('riv_last_login_${u.username}', DateTime.now().toIso8601String());
    return u;
  }

  static Future<AppUser?> session() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kSession);
    if (raw == null) return null;
    return AppUser.fromMap(Map<String, dynamic>.from(jsonDecode(raw)));
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    final s = await session();
    if (s != null) {
      await p.setString('riv_last_logout_${s.username}', DateTime.now().toIso8601String());
    }
    await p.remove(_kSession);
  }
}
