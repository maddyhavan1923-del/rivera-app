// Rivera Group — Attendance v4 (main entry + shell + home dashboard)
// Cross-checked v4: location INSIDE company only, fingerprint inside, QR line,
// CRM inbox + email/share, Refers page, visitors daily QR, clean UI.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'services/attendance_service.dart';
import 'services/data_services.dart';
import 'services/excel_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.ensureDefaultAdmin();
  await AttendanceService.loadCompanyLocation();
  runApp(const RiveraApp());
}

// ---------- shared helpers ----------
mixin ToastMixin<T extends StatefulWidget> on State<T> {
  void msg(String s, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s), backgroundColor: bg ?? AppConfig.navy));
  }
}

Future<bool> askConfirm(BuildContext c, String title, String body) async {
  final r = await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(d, true),
                  child: const Text('Yes, continue')),
            ],
          ));
  return r == true;
}

// Fingerprint first (company kulla verify) — device fingerprint illa na password
Future<bool> biometricOrPassword(BuildContext ctx, AppUser u) async {
  try {
    final la = LocalAuthentication();
    final sup = await la.isDeviceSupported();
    if (sup) {
      final ok = await la.authenticate(
          localizedReason: 'Company premises kulla irukkaariyathu verify pannu (Fingerprint / Face)');
      if (ok) return true;
    }
  } catch (_) {}
  if (!ctx.mounted) return false;
  final ctrl = TextEditingController();
  final r = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
            title: const Text('Confirm your password'),
            content: TextField(
                controller: ctrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(d, true),
                  child: const Text('Verify')),
            ],
          ));
  if (r != true) return false;
  final ok = await AuthService.verifyPassword(u.username, ctrl.text.trim());
  if (!ok && ctx.mounted) {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('Password thappu!'), backgroundColor: AppConfig.red));
  }
  return ok;
}

// ---------- app ----------
class RiveraApp extends StatelessWidget {
  const RiveraApp({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            useMaterial3: true,
            colorScheme:
                ColorScheme.fromSeed(seedColor: AppConfig.navy, primary: AppConfig.navy),
            scaffoldBackgroundColor: AppConfig.bg),
        home: const Splash(),
      );
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _Splash();
}

class _Splash extends State<Splash> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    final s = await AuthService.session();
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    if (s == null) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginPage()));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => HomePage(user: s)));
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: AppConfig.navy,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('logo.png', height: 92),
              const SizedBox(height: 14),
              const Text('Rivera Attendance',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(AppConfig.version,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 22),
              const CircularProgressIndicator(color: AppConfig.orange),
            ],
          ),
        ),
      );
}

// ---------- login ----------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _Login();
}

class _Login extends State<LoginPage> with ToastMixin<LoginPage> {
  final u = TextEditingController();
  final p = TextEditingController();
  bool hide = true;
  bool busy = false;

  Future<void> _doLogin() async {
    if (u.text.trim().isEmpty || p.text.isEmpty) {
      msg('Username + password kudukka!', bg: AppConfig.red);
      return;
    }
    setState(() => busy = true);
    final res = await AuthService.login(u.text.trim(), p.text);
    if (!mounted) return;
    setState(() => busy = false);
    if (res == null) {
      msg('Login fail — username/password check pannu!', bg: AppConfig.red);
      return;
    }
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => HomePage(user: res)));
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: AppConfig.bg,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('logo.png', height: 72),
                    const SizedBox(height: 8),
                    const Text('Rivera Group',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    Text('Staff Login — ' + AppConfig.version,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 18),
                    TextField(
                        controller: u,
                        decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person))),
                    const SizedBox(height: 12),
                    TextField(
                        controller: p,
                        obscureText: hide,
                        onSubmitted: (_) => _doLogin(),
                        decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                                icon: Icon(
                                    hide ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => hide = !hide)))),
                    const SizedBox(height: 20),
                    SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton(
                            onPressed: busy ? null : _doLogin,
                            child: busy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('LOGIN'))),
                    const SizedBox(height: 10),
                    TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterPage())),
                        child: const Text('New staff? Create account →')),
                    const Divider(height: 24),
                    const Text(
                      'Admin login: admin / Rivera@123\n(first login-la password maathirunga)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _Reg();
}

class _Reg extends State<RegisterPage> with ToastMixin<RegisterPage> {
  final n = TextEditingController();
  final u = TextEditingController();
  final ph = TextEditingController();
  final d = TextEditingController();
  final p = TextEditingController();
  final p2 = TextEditingController();
  bool busy = false;

  Future<void> _do() async {
    if (n.text.trim().isEmpty || u.text.trim().isEmpty || p.text.length < 4) {
      msg('Name, username + password (4+ chars) venum!', bg: AppConfig.red);
      return;
    }
    if (p.text != p2.text) {
      msg('Renda password um match aagala!', bg: AppConfig.red);
      return;
    }
    setState(() => busy = true);
    final err = await AuthService.register(
        username: u.text.trim(),
        password: p.text,
        name: n.text.trim(),
        department: d.text.trim(),
        phone: ph.text.trim());
    if (!mounted) return;
    setState(() => busy = false);
    if (err != null) {
      msg(err, bg: AppConfig.red);
      return;
    }
    msg('Account created ✓ now login pannu', bg: AppConfig.green);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Create staff account')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                          controller: n,
                          decoration:
                              const InputDecoration(labelText: 'Full name *')),
                      const SizedBox(height: 10),
                      TextField(
                          controller: u,
                          decoration:
                              const InputDecoration(labelText: 'Username *')),
                      const SizedBox(height: 10),
                      TextField(
                          controller: ph,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Phone')),
                      const SizedBox(height: 10),
                      TextField(
                          controller: d,
                          decoration:
                              const InputDecoration(labelText: 'Department')),
                      const SizedBox(height: 10),
                      TextField(
                          controller: p,
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: 'Password * (min 4 chars)')),
                      const SizedBox(height: 10),
                      TextField(
                          controller: p2,
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: 'Confirm password *')),
                      const SizedBox(height: 18),
                      SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton(
                              onPressed: busy ? null : _do,
                              child: const Text('CREATE ACCOUNT'))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

// ---------- home shell (6 tabs, arrangement proper) ----------
class HomePage extends StatefulWidget {
  final AppUser user;
  const HomePage({super.key, required this.user});
  @override
  State<HomePage> createState() => _HomeShell();
}

class _HomeShell extends State<HomePage> with ToastMixin<HomePage> {
  int idx = 0;
  int pend = 0;
  late final List<Widget> pages;

  bool get isAdmin => widget.user.role == 'admin';

  @override
  void initState() {
    super.initState();
    pages = [
      HomeTab(user: widget.user, goTab: (i) => setState(() => idx = i)),
      CrmTab(user: widget.user),
      DiaryTab(user: widget.user),
      RefersTab(user: widget.user),
      VisitTab(),
      MoreTab(user: widget.user),
    ];
    _badge();
  }

  Future<void> _badge() async {
    if (!isAdmin) return;
    final all = await LeaveService.all();
    final c = all.where((e) => e.status == 'Applied').length;
    if (mounted) setState(() => pend = c);
  }

  Future<void> _logout() async {
    if (!await askConfirm(context, 'Logout', 'Login veetula irundhu logout?')) {
      return;
    }
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext c) {
    final name = widget.user.name;
    final destinations = <NavigationDestination>[
      const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Home'),
      NavigationDestination(
          icon: Badge(
              isLabelVisible: pend > 0,
              label: Text('$pend'),
              child: const Icon(Icons.inbox_outlined)),
          selectedIcon: Badge(
              isLabelVisible: pend > 0,
              label: Text('$pend'),
              child: const Icon(Icons.inbox)),
          label: 'CRM'),
      const NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: 'Diary'),
      const NavigationDestination(
          icon: Icon(Icons.star_outline),
          selectedIcon: Icon(Icons.star),
          label: 'Refers'),
      const NavigationDestination(
          icon: Icon(Icons.qr_code_2),
          selectedIcon: Icon(Icons.qr_code_2),
          label: 'Visit'),
      const NavigationDestination(
          icon: Icon(Icons.more_horiz),
          selectedIcon: Icon(Icons.more_horiz),
          label: 'More'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rivera Attendance',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            Text('Hi, ' + name,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        actions: [
          IconButton(
              tooltip: 'Logout',
              onPressed: _logout,
              icon: const Icon(Icons.logout)),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(index: idx, children: pages),
      bottomNavigationBar: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) {
            setState(() => idx = i);
            if (i == 1) _badge();
          },
          destinations: destinations),
    );
  }
}

// ---------- HOME TAB: one-glance dashboard ----------
class HomeTab extends StatefulWidget {
  final AppUser user;
  final void Function(int) goTab;
  const HomeTab({super.key, required this.user, required this.goTab});
  @override
  State<HomeTab> createState() => _HomeTab();
}

class _HomeTab extends State<HomeTab> with ToastMixin<HomeTab> {
  AttRecord? today;
  String lastV = 'Inniku re-verify pannala';
  double? dist;
  bool? inside;
  bool busy = false;
  Timer? autoT;
  List<AttRecord> recent = [];

  AppUser get u => widget.user;
  bool get isAdmin => u.role == 'admin';

  @override
  void initState() {
    super.initState();
    _load();
    autoT = Timer.periodic(
        Duration(minutes: AppConfig.autoReVerifyMinutes), (_) => _auto());
  }

  @override
  void dispose() {
    autoT?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final recs = await AttendanceService.all();
    final mine = recs
        .where((e) => e.username == u.username)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final lv = await AttendanceService.lastVerifyText(u.username);
    if (!mounted) return;
    setState(() {
      today = AttendanceService.todayOf(u.username, recs);
      recent = mine.take(7).toList();
      lastV = lv;
    });
    try {
      final pos = await AttendanceService.getPosition();
      final r = AttendanceService.insideCheck(pos);
      if (!mounted) return;
      setState(() {
        inside = r.$1;
        dist = r.$2;
      });
    } catch (_) {
      if (mounted) setState(() => inside = null);
    }
  }

  Future<void> _auto() async {
    if (today == null) return;
    final res = await AttendanceService.reVerify(u.username);
    if (!mounted) return;
    if (res.startsWith('SUSPICIOUS')) {
      msg(res, bg: AppConfig.red);
    } else {
      setState(() {});
    }
  }

  Future<void> _checkIn() async {
    if (today != null) {
      msg('Inniku check-in already pottachu ✓');
      return;
    }
    setState(() => busy = true);
    Position pos;
    try {
      pos = await AttendanceService.getPosition();
    } catch (e) {
      if (mounted) setState(() => busy = false);
      msg(e.toString(), bg: AppConfig.red);
      return;
    }
    final r = AttendanceService.insideCheck(pos);
    if (!r.$1) {
      if (mounted) setState(() => busy = false);
      msg(AttendanceService.insideMessage(r.$2), bg: AppConfig.red);
      return;
    }
    if (!mounted) return;
    final ok = await biometricOrPassword(context, u);
    if (!ok) {
      if (mounted) setState(() => busy = false);
      msg('Verify cancel — check-in pannala.', bg: AppConfig.red);
      return;
    }
    try {
      await AttendanceService.checkIn(u.username, pos: pos);
      if (!mounted) return;
      setState(() => busy = false);
      msg('Check-in ✓ company premises kulla confirm!', bg: AppConfig.green);
      _load();
    } catch (e) {
      if (mounted) setState(() => busy = false);
      msg(e.toString(), bg: AppConfig.red);
    }
  }

  Future<void> _checkOut() async {
    if (today == null) {
      msg('Check-in pannala — checkout vendaam.');
      return;
    }
    if (today!.checkOut != null) {
      msg('Already checked-out ✓');
      return;
    }
    if (!await askConfirm(context, 'Check-out',
        'Office vitom-nu confirm pannureengala?')) return;
    try {
      await AttendanceService.checkOut(u.username);
      msg('Check-out ✓', bg: AppConfig.green);
      _load();
    } catch (e) {
      msg(e.toString(), bg: AppConfig.red);
    }
  }

  Future<void> _reVerify() async {
    msg('Re-verifying GPS...');
    final res = await AttendanceService.reVerify(u.username);
    if (!mounted) return;
    msg(res, bg: res.startsWith('SUSPICIOUS') ? AppConfig.red : AppConfig.green);
    _load();
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const ScannerPage()));
    if (code == null || !mounted) return;
    if (code.startsWith('RIVQR')) {
      final target = AttendanceService.validateEmployeeQR(code);
      if (target == null) {
        msg('QR invalid/expired — innikku mattum valid.', bg: AppConfig.red);
        return;
      }
      if (!isAdmin) {
        msg('QR valid ✓ (' + target + ')');
        return;
      }
      final mark = await askConfirm(context, 'Mark attendance?',
          target + ' — daily QR valid. Mark check-in pannuma?');
      if (!mark || !mounted) return;
      try {
        await AttendanceService.checkIn(target);
        msg('Marked ✓ ' + target, bg: AppConfig.green);
        _load();
      } catch (e) {
        msg(e.toString(), bg: AppConfig.red);
      }
    } else if (VisitorService.isQRValidToday(code)) {
      msg('Visitor daily QR ✓ valid', bg: AppConfig.green);
      widget.goTab(4);
    } else {
      msg('Unknown QR.', bg: AppConfig.red);
    }
  }

  void _showMyQR() {
    final payload = AttendanceService.employeeQRPayload(u.username);
    final tk = AttendanceService.todayKey();
    showDialog(
        context: context,
        builder: (d) => AlertDialog(
              title: const Text('My Daily QR'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(
                      data: payload,
                      size: 220,
                      backgroundColor: Colors.white),
                  const SizedBox(height: 8),
                  Text('Valid only for ' + tk,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(d),
                    child: const Text('Close')),
              ],
            ));
  }

  @override
  Widget build(BuildContext c) {
    final uname = u.name;
    final tk = AttendanceService.todayKey();
    final rcount = recent.length;
    String statusLine = 'Not marked yet';
    if (today != null) {
      final tin = DateTime.tryParse(today!.checkIn);
      final hin =
          tin == null ? '' : DateFormat('hh:mm a').format(tin);
      if (today!.checkOut != null) {
        statusLine = 'Checked-out ' + _hm(today!.checkOut);
      } else {
        statusLine = 'Checked-in ' + hin;
      }
    }
    String gpsLine = 'GPS loading...';
    if (dist != null) {
      final dm = dist!.toStringAsFixed(0);
      gpsLine = dm + ' m from company point';
    }
    Widget statusChip;
    if (inside == null) {
      statusChip = _chip('GPS...', Colors.white24);
    } else if (inside!) {
      statusChip = _chip('INSIDE ✓', AppConfig.green);
    } else {
      statusChip = _chip('OUTSIDE', AppConfig.red);
    }

    final quick = <_Quick>[
      _Quick(Icons.note_add_outlined, 'Apply Leave',
          () => widget.goTab(1)),
      _Quick(Icons.menu_book_outlined, 'Daily Diary',
          () => widget.goTab(2)),
      _Quick(Icons.star_outline, 'Refers', () => widget.goTab(3)),
      _Quick(Icons.groups_outlined, 'Visitors', () => widget.goTab(4)),
      _Quick(Icons.qr_code_scanner, 'Scan QR', _scan),
      if (isAdmin)
        _Quick(Icons.admin_panel_settings_outlined, 'Admin', () =>
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminPage()))),
      if (isAdmin)
        _Quick(Icons.table_view_outlined, 'Excel', _excel),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ---- status card ----
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppConfig.navy, AppConfig.blue]),
                borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Good to see, ' + uname + '!',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                    statusChip,
                  ],
                ),
                const SizedBox(height: 8),
                Text(statusLine,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(gpsLine,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.shield, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(lastV,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ),
                    IconButton(
                        tooltip: 'Refresh GPS',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 28, minHeight: 28),
                        onPressed: _load,
                        icon: const Icon(Icons.refresh,
                            size: 16, color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ---- QR LINE card (horizontal) ----
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _showMyQR,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    QrImageView(
                        data: AttendanceService.employeeQRPayload(u.username),
                        size: 54,
                        backgroundColor: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('My Daily QR',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Tap → full size · valid only ' + tk,
                              style: const TextStyle(
                                  fontSize: 11.5, color: Colors.black54)),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                        onPressed: _scan,
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: const Text('Scan')),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ---- action row: fingerprint inside company ----
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppConfig.green,
                        minimumSize: const Size.fromHeight(46)),
                    onPressed: busy ? null : _checkIn,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('CHECK-IN')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppConfig.orange,
                        minimumSize: const Size.fromHeight(46)),
                    onPressed: _checkOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('CHECK-OUT')),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46)),
                  onPressed: _reVerify,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('VERIFY')),
            ],
          ),
          const SizedBox(height: 16),

          // ---- quick grid: everything at ONE GLANCE ----
          const Text('All features — one glance',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.25,
            children: [
              for (final q in quick)
                Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: q.tap,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(q.icon, size: 26, color: AppConfig.navy),
                        const SizedBox(height: 6),
                        Text(q.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ---- recent history ----
          Row(
            children: [
              const Text('My recent attendance',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('last $rcount',
                  style: const TextStyle(
                      fontSize: 11.5, color: Colors.black45)),
            ],
          ),
          const SizedBox(height: 6),
          if (recent.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Inniku start pannu — GPS + fingerprint ✓',
                        style: TextStyle(color: Colors.black54)))),
          for (final r in recent) _histTile(r),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _hm(String? iso) {
    final t = iso == null ? null : DateTime.tryParse(iso);
    if (t == null) return '';
    return DateFormat('hh:mm a').format(t);
  }

  Widget _chip(String t, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(t,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );

  Widget _histTile(AttRecord r) {
    final d = r.date;
    final io = _hm(r.checkIn) +
        (r.checkOut == null ? ' → open' : ' → ' + _hm(r.checkOut));
    final dm = r.distanceM.toStringAsFixed(0);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 15, color: Colors.black45),
            const SizedBox(width: 8),
            Text(d, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(io,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black54)),
            ),
            Text(dm + 'm',
                style:
                    const TextStyle(fontSize: 11, color: Colors.black45)),
            if (r.suspicious)
              const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.warning_amber,
                      size: 17, color: AppConfig.red)),
          ],
        ),
      ),
    );
  }

  Future<void> _excel() async {
    try {
      final path = await ExcelService.exportAll();
      msg('Excel saved: ' + path, bg: AppConfig.green);
    } catch (e) {
      msg('Export failed: ' + e.toString(), bg: AppConfig.red);
    }
  }
}

class _Quick {
  final IconData icon;
  final String label;
  final VoidCallback tap;
  _Quick(this.icon, this.label, this.tap);
}
// ---------- CRM TAB: leave applied -> CRM inbox (+ email share) ----------
class CrmTab extends StatefulWidget {
  final AppUser user;
  const CrmTab({super.key, required this.user});
  @override
  State<CrmTab> createState() => _Crm();
}

class _Crm extends State<CrmTab> with ToastMixin<CrmTab> {
  List<LeaveReq> leaves = [];
  bool showForm = false;
  bool busy = false;
  String type = 'Casual Leave';
  DateTime? from;
  DateTime? to;
  final reason = TextEditingController();

  bool get isAdmin => widget.user.role == 'admin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await LeaveService.all();
    if (!mounted) return;
    setState(() {
      leaves = isAdmin ? all : all.where((e) => e.username == widget.user.username).toList();
      leaves.sort((a, b) => b.appliedOn.compareTo(a.appliedOn));
    });
  }

  void shareCrm(String body) {
    Share.share('To: ' + AppConfig.crmEmail + '\n\n' + body,
        subject: 'Rivera CRM — Leave Application');
  }

  Future<void> _apply() async {
    if (from == null || to == null) {
      msg('From / To date select pannu!', bg: AppConfig.red);
      return;
    }
    if (reason.text.trim().isEmpty) {
      msg('Reason venum!', bg: AppConfig.red);
      return;
    }
    if (to!.isBefore(from!)) {
      msg('To date From-ku pinna irukka koodathu!', bg: AppConfig.red);
      return;
    }
    setState(() => busy = true);
    final fS = AttendanceService.todayKey(from!);
    final tS = AttendanceService.todayKey(to!);
    final rs = reason.text.trim();
    final uname = widget.user.name;
    await LeaveService.apply(
        widget.user.username, type, fS, tS, rs);
    if (!mounted) return;
    setState(() {
      busy = false;
      showForm = false;
    });
    reason.clear();
    from = null;
    to = null;
    _load();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppConfig.green,
        content: const Text('Applied ✓ — Admin CRM inbox update aayiruchu'),
        action: SnackBarAction(
            label: 'EMAIL CRM',
            textColor: Colors.white,
            onPressed: () {
              final tt = type;
              shareCrm('Leave application\nStaff: ' +
                  uname +
                  '\nType: ' +
                  tt +
                  '\nFrom: ' +
                  fS +
                  '\nTo: ' +
                  tS +
                  '\nReason: ' +
                  rs);
            })));
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context,
        initialDate: (isFrom ? from : to) ?? now,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 2));
    if (d == null) return;
    setState(() {
      if (isFrom) {
        from = d;
      } else {
        to = d;
      }
    });
  }

  @override
  Widget build(BuildContext c) {
    final applied = leaves.where((e) => e.status == 'Applied').length;
    final approved = leaves.where((e) => e.status == 'Approved').length;
    final rejected = leaves.where((e) => e.status == 'Rejected').length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Leave → CRM Inbox',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      'Apply pannunga → Admin CRM inbox (info@rivera.co.in) instant-a update aagum — email/share pannalaam',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                  if (isAdmin) const SizedBox(height: 10),
                  if (isAdmin)
                    Row(
                      children: [
                        _count('Applied', applied, AppConfig.orange),
                        const SizedBox(width: 8),
                        _count('Approved', approved, AppConfig.green),
                        const SizedBox(width: 8),
                        _count('Rejected', rejected, AppConfig.red),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (!isAdmin)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                      onPressed: () => setState(() => showForm = !showForm),
                      icon: const Icon(Icons.add),
                      label: Text(showForm ? 'Close form' : 'Apply Leave')),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                    onPressed: () => shareCrm('Leave request details: app CRM inbox-la paarunga'),
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: const Text('Email')),
              ],
            ),
          if (!isAdmin && showForm) ...[
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                        value: type,
                        decoration:
                            const InputDecoration(labelText: 'Leave type'),
                        items: const [
                          'Casual Leave',
                          'Sick Leave',
                          'Earned Leave',
                          'Half Day',
                          'Unpaid Leave',
                          'Other'
                        ]
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => type = v ?? type)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                              onPressed: () => _pickDate(true),
                              icon: const Icon(Icons.date_range, size: 16),
                              label: Text(from == null
                                  ? 'From date'
                                  : AttendanceService.todayKey(from!))),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                              onPressed: () => _pickDate(false),
                              icon: const Icon(Icons.date_range, size: 16),
                              label: Text(to == null
                                  ? 'To date'
                                  : AttendanceService.todayKey(to!))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                        controller: reason,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'Reason *',
                            hintText: 'Enna reason-nu short-a explain pannu')),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: busy ? null : _apply,
                          child: const Text('SUBMIT TO CRM')),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text('Leave requests',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (leaves.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Inniku leave requests illa ✓',
                        style: TextStyle(color: Colors.black54)))),
          for (final l in leaves) _reqCard(l),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _count(String t, int n, Color col) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: col.withOpacity(0.15),
            border: Border.all(color: col),
            borderRadius: BorderRadius.circular(20)),
        child: Text('$t: $n',
            style: TextStyle(
                fontSize: 12, color: col, fontWeight: FontWeight.bold)),
      );

  Widget _reqCard(LeaveReq l) {
    final who = l.username;
    final range = l.from + ' → ' + l.to;
    Color sc;
    switch (l.status) {
      case 'Approved':
        sc = AppConfig.green;
        break;
      case 'Rejected':
        sc = AppConfig.red;
        break;
      default:
        sc = AppConfig.orange;
    }
    final showActions = isAdmin && l.status == 'Applied';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(l.type,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: sc, borderRadius: BorderRadius.circular(20)),
                  child: Text(l.status,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (isAdmin) Text('By: ' + who,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppConfig.navy,
                    fontWeight: FontWeight.w600)),
            Text(range,
                style: const TextStyle(fontSize: 12.5, color: Colors.black87)),
            const SizedBox(height: 3),
            Text(l.reason,
                style:
                    const TextStyle(fontSize: 12, color: Colors.black54)),
            if (showActions) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppConfig.green),
                        onPressed: () async {
                          await LeaveService.setStatus(l.id, 'Approved');
                          msg('Approved ✓', bg: AppConfig.green);
                          _load();
                        },
                        child: const Text('APPROVE')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppConfig.red),
                        onPressed: () async {
                          await LeaveService.setStatus(l.id, 'Rejected');
                          msg('Rejected ✓', bg: AppConfig.red);
                          _load();
                        },
                        child: const Text('REJECT')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------- DIARY TAB ----------
class DiaryTab extends StatefulWidget {
  final AppUser user;
  const DiaryTab({super.key, required this.user});
  @override
  State<DiaryTab> createState() => _Diary();
}

class _Diary extends State<DiaryTab> with ToastMixin<DiaryTab> {
  DateTime day = DateTime.now();
  final work = TextEditingController();
  List<DiaryEntry> entries = [];

  bool get isAdmin => widget.user.role == 'admin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await DiaryService.all();
    final key = AttendanceService.todayKey(day);
    final f = all.where((e) => e.date == key).toList()
      ..sort((a, b) => b.createdOn.compareTo(a.createdOn));
    if (!mounted) return;
    setState(() {
      entries =
          isAdmin ? f : f.where((e) => e.username == widget.user.username).toList();
    });
  }

  Future<void> _save() async {
    if (work.text.trim().isEmpty) {
      msg('Work note enna-nu ezhudhu!', bg: AppConfig.red);
      return;
    }
    await DiaryService.add(
        widget.user.username, AttendanceService.todayKey(day), work.text.trim());
    work.clear();
    msg('Diary saved ✓', bg: AppConfig.green);
    _load();
  }

  @override
  Widget build(BuildContext c) {
    final now = DateTime.now();
    final days = List.generate(
        10, (i) => DateTime(now.year, now.month, now.day - i));
    final ecount = entries.length;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily Work Diary',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                const Text('Ella staff-um daily enna work pannom-nu update pannunga',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: days.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (ctx, i) {
                        final d = days[i];
                        final sel = AttendanceService.todayKey(d) ==
                            AttendanceService.todayKey(day);
                        final lbl = DateFormat('dd MMM').format(d);
                        return ChoiceChip(
                            selected: sel,
                            label: Text(lbl),
                            onSelected: (_) {
                              setState(() => day = d);
                              _load();
                            });
                      }),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: work,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Today work / output',
                        hintText:
                            'Eg: Order 2301 packing complete, site visit 3pm...')),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: _save, child: const Text('SAVE DIARY')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Entries ($ecount)',
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (entries.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Inniku entries illa — munnadi ezhudhu!',
                      style: TextStyle(color: Colors.black54)))),
        for (final e in entries)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(e.username,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13))),
                      Text(_t(e.createdOn),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black45)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(e.work,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black87)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  String _t(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return DateFormat('hh:mm a').format(d);
  }
}

// ---------- REFERS PAGE (new design) ----------
class RefersTab extends StatefulWidget {
  final AppUser user;
  const RefersTab({super.key, required this.user});
  @override
  State<RefersTab> createState() => _Refers();
}

class _Refers extends State<RefersTab> with ToastMixin<RefersTab> {
  List<Map<String, String>> items = [];
  bool showForm = false;
  final search = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final note = TextEditingController();
  String type = 'Customer';

  bool get isAdmin => widget.user.role == 'admin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await ReferenceService.all();
    if (!mounted) return;
    setState(() => items = l.reversed.toList());
  }

  List<Map<String, String>> get filtered {
    final q = search.text.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((m) {
      final n = (m['name'] ?? '').toLowerCase();
      final ph = (m['phone'] ?? '').toLowerCase();
      final nt = (m['note'] ?? '').toLowerCase();
      return n.contains(q) || ph.contains(q) || nt.contains(q);
    }).toList();
  }

  Future<void> _add() async {
    if (name.text.trim().isEmpty) {
      msg('Name venum!', bg: AppConfig.red);
      return;
    }
    await ReferenceService.add({
      'name': name.text.trim(),
      'phone': phone.text.trim(),
      'type': type,
      'note': note.text.trim(),
      'by': widget.user.username,
    });
    name.clear();
    phone.clear();
    note.clear();
    setState(() => showForm = false);
    msg('Refers added ✓', bg: AppConfig.green);
    _load();
  }

  Future<void> _del(Map<String, String> m) async {
    final id = m['id'] ?? '';
    if (id.isEmpty) return;
    if (!await askConfirm(context, 'Delete refers?',
        'Remove ' + (m['name'] ?? '') + '?')) return;
    await ReferenceService.delete(id);
    msg('Deleted ✓');
    _load();
  }

  @override
  Widget build(BuildContext c) {
    final list = filtered;
    final fcount = list.length;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Refers / References',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                    FilledButton.icon(
                        onPressed: () =>
                            setState(() => showForm = !showForm),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add')),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Customers, vendors, employee referrals — oru page-la',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 10),
                TextField(
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search name / phone / note',
                        isDense: true)),
                if (showForm) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 4),
                  const SizedBox(height: 10),
                  TextField(
                      controller: name,
                      decoration:
                          const InputDecoration(labelText: 'Name *', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: 'Phone', isDense: true)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                      value: type,
                      isDense: true,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        'Customer',
                        'Vendor',
                        'Employee Referral',
                        'Contractor',
                        'Other'
                      ]
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) => setState(() => type = v ?? type)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: note,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Note', isDense: true)),
                  const SizedBox(height: 10),
                  SizedBox(
                      width: double.infinity,
                      child:
                          FilledButton(onPressed: _add, child: const Text('SAVE REFERS'))),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('List ($fcount)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (list.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Refers illa — add pannu!',
                      style: TextStyle(color: Colors.black54)))),
        for (final m in list) _tile(m),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _tile(Map<String, String> m) {
    final t = m['type'] ?? '';
    IconData ic;
    switch (t) {
      case 'Vendor':
        ic = Icons.local_shipping_outlined;
        break;
      case 'Employee Referral':
        ic = Icons.person_add_alt;
        break;
      case 'Contractor':
        ic = Icons.build_outlined;
        break;
      case 'Customer':
        ic = Icons.shopping_bag_outlined;
        break;
      default:
        ic = Icons.link;
    }
    final nm = m['name'] ?? '';
    final ph = m['phone'] ?? '';
    final nt = m['note'] ?? '';
    final by = m['by'] ?? '';
    final canDel = isAdmin || by == widget.user.username;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
                radius: 18,
                backgroundColor: AppConfig.navy.withOpacity(0.1),
                child: Icon(ic, size: 18, color: AppConfig.navy)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(nm,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppConfig.blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(t,
                          style: const TextStyle(
                              fontSize: 10.5, color: AppConfig.blue)),
                    ),
                  ]),
                  if (ph.isNotEmpty)
                    Text(ph,
                        style: const TextStyle(
                            fontSize: 12.5, color: Colors.black87)),
                  if (nt.isNotEmpty)
                    Text(nt,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            if (canDel)
              IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _del(m),
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppConfig.red)),
          ],
        ),
      ),
    );
  }
}

// ---------- VISITORS TAB (daily live QR + entry + exit feedback) ----------
class VisitTab extends StatefulWidget {
  const VisitTab({super.key});
  @override
  State<VisitTab> createState() => _Visit();
}

class _Visit extends State<VisitTab> with ToastMixin<VisitTab> {
  List<Map<String, String>> allV = [];
  bool showForm = false;
  final name = TextEditingController();
  final phone = TextEditingController();
  final purpose = TextEditingController();
  final meet = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await VisitorService.all();
    if (!mounted) return;
    setState(() => allV = l);
  }

  List<int> get todayIdx {
    final key = AttendanceService.todayKey();
    final out = <int>[];
    for (var i = 0; i < allV.length; i++) {
      final tin = allV[i]['in'] ?? '';
      if (tin.startsWith(key)) out.add(i);
    }
    return out;
  }

  Future<void> _add() async {
    if (name.text.trim().isEmpty) {
      msg('Visitor name venum!', bg: AppConfig.red);
      return;
    }
    await VisitorService.entry({
      'name': name.text.trim(),
      'phone': phone.text.trim(),
      'purpose': purpose.text.trim(),
      'meet': meet.text.trim(),
      'by': 'gate',
    });
    name.clear();
    phone.clear();
    purpose.clear();
    meet.clear();
    setState(() => showForm = false);
    msg('Visitor entry registered ✓', bg: AppConfig.green);
    _load();
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const ScannerPage()));
    if (code == null || !mounted) return;
    if (VisitorService.isQRValidToday(code)) {
      setState(() => showForm = true);
      msg('Visitor QR ✓ valid — form open pannachu', bg: AppConfig.green);
    } else if (code.startsWith('RIVQR')) {
      msg('Employee QR — Home tab-la scan pannu.');
    } else {
      msg('QR invalid — inniku mattum valid QR use pannu.', bg: AppConfig.red);
    }
  }

  Future<void> _exitFeedback(int idx) async {
    String choice = 'Satisfied';
    final note = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (d) => StatefulBuilder(
            builder: (dc, setD) => AlertDialog(
                  title: const Text('Exit — feedback'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Visitor enna solraanga?',
                          style: TextStyle(fontSize: 12.5)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final s in [
                            'Satisfied',
                            'Average',
                            'Not satisfied'
                          ])
                            ChoiceChip(
                                label: Text(s),
                                selected: choice == s,
                                onSelected: (_) =>
                                    setD(() => choice = s)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                          controller: note,
                          decoration: const InputDecoration(
                              labelText: 'Note (optional)',
                              isDense: true)),
                    ],
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(d, true),
                        child: const Text('EXIT + SAVE')),
                  ],
                )));
    if (ok != true || !mounted) return;
    var fb = choice;
    if (note.text.trim().isNotEmpty) fb = fb + ' — ' + note.text.trim();
    await VisitorService.feedback(idx, fb);
    msg('Visitor exit saved ✓ thanks!', bg: AppConfig.green);
    _load();
  }

  @override
  Widget build(BuildContext c) {
    final qr = VisitorService.dailyQRPayload();
    final today = todayIdx;
    final tcount = today.length;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // ---- daily live QR (proper square, centered) ----
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Daily Visitor QR',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('Innikku mattum valid — rojum auto maathudhu',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 12),
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12)),
                    child: QrImageView(
                        data: qr, size: 168, backgroundColor: Colors.white)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                        onPressed: _scan,
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: const Text('Scan visitor QR')),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                        onPressed: () => setState(() => showForm = !showForm),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Visitor entry')),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (showForm) ...[
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                      controller: name,
                      decoration: const InputDecoration(
                          labelText: 'Visitor name *', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: 'Phone', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: purpose,
                      decoration: const InputDecoration(
                          labelText: 'Purpose', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: meet,
                      decoration: const InputDecoration(
                          labelText: 'Meet whom (dept/person)', isDense: true)),
                  const SizedBox(height: 12),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: _add, child: const Text('REGISTER ENTRY'))),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text('Today visitors ($tcount)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (today.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Inniku visitors illa ✓',
                      style: TextStyle(color: Colors.black54)))),
        for (final i in today) _vTile(i),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _vTile(int i) {
    final m = allV[i];
    final nm = m['name'] ?? '';
    final pu = m['purpose'] ?? '';
    final meet = m['meet'] ?? '';
    final tin = m['in'] ?? '';
    final out = m['out'] ?? '';
    final fb = m['feedback'] ?? '';
    final t = DateTime.tryParse(tin);
    final inTxt = t == null ? '' : DateFormat('hh:mm a').format(t);
    final done = out.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: done
            ? null
            : () => _exitFeedback(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const CircleAvatar(
                  radius: 18,
                  child: Icon(Icons.person, size: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nm,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(
                        (pu.isEmpty ? 'Visit' : pu) +
                            (meet.isEmpty ? '' : ' · meet: ' + meet),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                    if (done && fb.isNotEmpty)
                      Text('Feedback: ' + fb,
                          style: const TextStyle(
                              fontSize: 11.5, color: AppConfig.blue)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('IN ' + inTxt,
                      style: const TextStyle(
                          fontSize: 11.5, color: Colors.black54)),
                  if (done)
                    Text('OUT ✓',
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: AppConfig.green,
                            fontWeight: FontWeight.bold))
                  else
                    const Text('tap → exit',
                        style:
                            TextStyle(fontSize: 11, color: AppConfig.orange)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- MORE TAB ----------
class MoreTab extends StatefulWidget {
  final AppUser user;
  const MoreTab({super.key, required this.user});
  @override
  State<MoreTab> createState() => _More();
}

class _More extends State<MoreTab> with ToastMixin<MoreTab> {
  bool get isAdmin => widget.user.role == 'admin';

  Future<void> _excel() async {
    try {
      final path = await ExcelService.exportAll();
      msg('Excel saved: ' + path, bg: AppConfig.green);
    } catch (e) {
      msg('Export failed: ' + e.toString(), bg: AppConfig.red);
    }
  }

  @override
  Widget build(BuildContext c) {
    final u = widget.user;
    final nm = u.name;
    final initial = nm.isEmpty ? '?' : nm[0].toUpperCase();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                    radius: 28,
                    backgroundColor: AppConfig.navy,
                    child: Text(initial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nm,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('@' + u.username,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _pill(
                              u.role == 'admin' ? 'ADMIN' : 'STAFF',
                              u.role == 'admin'
                                  ? AppConfig.orange
                                  : AppConfig.blue),
                          const SizedBox(width: 6),
                          if (u.department.isNotEmpty)
                            _pill(u.department, Colors.black38),
                          if (u.phone.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _pill(u.phone, Colors.black26),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (isAdmin) ...[
          Card(
            child: Column(
              children: [
                ListTile(
                    leading:
                        const Icon(Icons.admin_panel_settings, color: AppConfig.navy),
                    title: const Text('Admin Panel',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Users · attendance · company GPS · flags',
                        style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AdminPage()))),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                    leading: const Icon(Icons.table_view, color: AppConfig.navy),
                    title: const Text('Excel export',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Attendance + leave + diary + visitors',
                        style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _excel),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Image.asset('logo.png', height: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rivera Group of Companies',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(AppConfig.companyAddress,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text('Rivera v4 · Offline · 1000-year safe',
                          style: const TextStyle(
                              fontSize: 10.5, color: Colors.black38)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppConfig.red,
                  side: const BorderSide(color: AppConfig.red)),
              onPressed: () async {
                if (!await askConfirm(
                    context, 'Logout', 'Ungal account-ah logout pannuma?')) {
                  return;
                }
                await AuthService.logout();
                if (!mounted) return;
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginPage()));
              },
              icon: const Icon(Icons.logout),
              label: const Text('LOGOUT')),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _pill(String t, Color col) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: col, borderRadius: BorderRadius.circular(12)),
        child: Text(t,
            style: const TextStyle(
                color: Colors.white, fontSize: 10.5)),
      );
}

// ---------- ADMIN PAGE (users · attendance · company GPS · suspicious) ----------
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _Admin();
}

class _Admin extends State<AdminPage> with ToastMixin<AdminPage> {
  final nu = TextEditingController();
  final np = TextEditingController();
  final nn = TextEditingController();
  final nd = TextEditingController();
  final nph = TextEditingController();
  final latC = TextEditingController();
  final lngC = TextEditingController();
  final radC = TextEditingController();
  bool showCreate = false;
  List<AppUser> users = [];
  List<AttRecord> recs = [];

  @override
  void initState() {
    super.initState();
    latC.text = AppConfig.companyLat.toStringAsFixed(6);
    lngC.text = AppConfig.companyLng.toStringAsFixed(6);
    radC.text = AppConfig.geofenceRadiusMeters.toStringAsFixed(0);
    _load();
  }

  Future<void> _load() async {
    final u = await AuthService.allUsers();
    final r = await AttendanceService.all();
    r.sort((a, b) => b.date.compareTo(a.date));
    if (!mounted) return;
    setState(() {
      users = u;
      recs = r;
    });
  }

  Future<void> _create() async {
    if (nu.text.trim().isEmpty || np.text.length < 4 || nn.text.trim().isEmpty) {
      msg('Username, password(4+) name venum!', bg: AppConfig.red);
      return;
    }
    final err = await AuthService.adminCreateUser(
        username: nu.text.trim(),
        password: np.text,
        name: nn.text.trim(),
        department: nd.text.trim(),
        phone: nph.text.trim());
    if (err != null) {
      msg(err, bg: AppConfig.red);
      return;
    }
    nu.clear();
    np.clear();
    nn.clear();
    nd.clear();
    nph.clear();
    setState(() => showCreate = false);
    msg('User created ✓', bg: AppConfig.green);
    _load();
  }

  Future<void> _resetPass(AppUser usr) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
              title: Text('Reset: ' + usr.username),
              content: TextField(
                  controller: c,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'New password (4+)')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(d, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(d, true),
                    child: const Text('SAVE')),
              ],
            ));
    if (ok == true && c.text.length >= 4) {
      await AuthService.adminResetPassword(usr.username, c.text);
      msg('Password reset ✓', bg: AppConfig.green);
    }
  }

  Future<void> _delUser(AppUser usr) async {
    if (usr.username == AppConfig.defaultAdminUser) {
      msg('Default admin delete panna koodathu!', bg: AppConfig.red);
      return;
    }
    if (!await askConfirm(
        context, 'Delete user?', usr.username + ' — delete pannuma?')) {
      return;
    }
    await AuthService.adminDeleteUser(usr.username);
    msg('User deleted ✓');
    _load();
  }

  Future<void> _useCurrentGps() async {
    try {
      final pos = await AttendanceService.getPosition();
      setState(() {
        latC.text = pos.latitude.toStringAsFixed(6);
        lngC.text = pos.longitude.toStringAsFixed(6);
      });
      msg('Current GPS filled ✓ — Save pannu', bg: AppConfig.green);
    } catch (e) {
      msg(e.toString(), bg: AppConfig.red);
    }
  }

  Future<void> _saveGps() async {
    final la = double.tryParse(latC.text.trim());
    final ln = double.tryParse(lngC.text.trim());
    final ra = double.tryParse(radC.text.trim());
    if (la == null || ln == null || ra == null || ra <= 0) {
      msg('Valid lat/lng/radius venum!', bg: AppConfig.red);
      return;
    }
    if (la < -90 || la > 90 || ln < -180 || ln > 180) {
      msg('Lat/lng range thappu!', bg: AppConfig.red);
      return;
    }
    await AttendanceService.setCompanyLocation(la, ln, ra);
    msg('Company GPS saved ✓ — check-in only INDA point kulla',
        bg: AppConfig.green);
  }

  @override
  Widget build(BuildContext c) => DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Admin Panel'),
            bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Users'),
                  Tab(text: 'Attendance'),
                  Tab(text: 'Company GPS'),
                  Tab(text: 'Flags'),
                ]),
          ),
          body: TabBarView(
            children: [
              // ---- users ----
              ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  FilledButton.icon(
                      onPressed: () =>
                          setState(() => showCreate = !showCreate),
                      icon: const Icon(Icons.person_add),
                      label: Text(showCreate ? 'Close' : 'Create staff user')),
                  if (showCreate) ...[
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            TextField(
                                controller: nn,
                                decoration: const InputDecoration(
                                    labelText: 'Full name *', isDense: true)),
                            const SizedBox(height: 8),
                            TextField(
                                controller: nu,
                                decoration: const InputDecoration(
                                    labelText: 'Username *', isDense: true)),
                            const SizedBox(height: 8),
                            TextField(
                                controller: np,
                                obscureText: true,
                                decoration: const InputDecoration(
                                    labelText: 'Password * (4+)',
                                    isDense: true)),
                            const SizedBox(height: 8),
                            TextField(
                                controller: nd,
                                decoration: const InputDecoration(
                                    labelText: 'Department', isDense: true)),
                            const SizedBox(height: 8),
                            TextField(
                                controller: nph,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                    labelText: 'Phone', isDense: true)),
                            const SizedBox(height: 12),
                            SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                    onPressed: _create,
                                    child: const Text('CREATE USER'))),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Users (' + users.length.toString() + ')',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  for (final usr in users)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: (usr.role == 'admin'
                                    ? AppConfig.orange
                                    : AppConfig.navy)
                                .withOpacity(0.15),
                            child: Text(
                                usr.name.isEmpty
                                    ? '?'
                                    : usr.name[0].toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold))),
                        title: Text(usr.name + '  ·  @' + usr.username,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13.5)),
                        subtitle: Text(
                            (usr.department.isEmpty ? '-' : usr.department) +
                                ' · ' +
                                usr.role,
                            style: const TextStyle(fontSize: 11.5)),
                        trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'reset') _resetPass(usr);
                              if (v == 'del') _delUser(usr);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'reset',
                                  child: Text('Reset password')),
                              PopupMenuItem(
                                  value: 'del', child: Text('Delete user')),
                            ]),
                      ),
                    ),
                ],
              ),
              // ---- attendance ----
              ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Text('All records (' + recs.length.toString() + ')',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (recs.isEmpty)
                    const Card(
                        child: Padding(
                            padding: EdgeInsets.all(14),
                            child: Text('Records illa',
                                style: TextStyle(color: Colors.black54)))),
                  for (final r in recs.take(200))
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.date + '  ·  ' + r.username,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  Text('IN ' + _hm(r.checkIn) + _out(r),
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.black54)),
                                ],
                              ),
                            ),
                            Text(r.distanceM.toStringAsFixed(0) + 'm',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black45)),
                            if (r.suspicious)
                              const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(Icons.warning_amber,
                                      color: AppConfig.red, size: 17)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              // ---- company GPS ----
              ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Company location point',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text(
                              'Company BUILDING/GATE GPS eduthu save pannunga — app check-in INDHA point-oda radius kulla mattum work aagum. Gate kitta illa, company kulla andha point!',
                              style: TextStyle(
                                  fontSize: 12.5, color: Colors.black54)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                    controller: latC,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                        labelText: 'Latitude', isDense: true)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                    controller: lngC,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                        labelText: 'Longitude', isDense: true)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                    controller: radC,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'Radius (m)',
                                        isDense: true)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                    onPressed: _useCurrentGps,
                                    icon: const Icon(Icons.my_location,
                                        size: 16),
                                    label: const Text('Use current GPS')),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                    onPressed: _saveGps,
                                    child: const Text('SAVE')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                              'Tip: phone-ah company building kulla kondu poyi "Use current GPS" → SAVE pannunga.',
                              style: TextStyle(
                                  fontSize: 11.5, color: Colors.black45)),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Anti-bypass rules',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          _rule(Icons.location_off,
                              'Mock/fake GPS block: ON'),
                          _rule(Icons.timer,
                              'Auto re-verify: every ' +
                                  AppConfig.autoReVerifyMinutes.toString() +
                                  ' min'),
                          _rule(Icons.shield,
                              'Premises veliya irundha SUSPICIOUS flag'),
                          _rule(Icons.fingerprint,
                              'Check-in = GPS inside + fingerprint confirm'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // ---- suspicious flags ----
              Builder(builder: (c2) {
                final s = recs
                    .where((r) => r.suspicious || r.note.contains('FAILED'))
                    .toList();
                return ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    const Text('Gate-bypass / suspicious flags',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (s.isEmpty)
                      const Card(
                          child: Padding(
                              padding: EdgeInsets.all(14),
                              child: Text('Flags illa — clean ✓',
                                  style: TextStyle(color: AppConfig.green)))),
                    for (final r in s)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.date + '  ·  ' + r.username,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(r.note,
                                  style: const TextStyle(
                                      fontSize: 12.5, color: AppConfig.red)),
                              Text('Last known: ' +
                                  r.lat.toStringAsFixed(5) +
                                  ', ' +
                                  r.lng.toStringAsFixed(5),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black45)),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      );

  String _hm(String? iso) {
    final t = iso == null ? null : DateTime.tryParse(iso);
    if (t == null) return '--';
    return DateFormat('hh:mm a').format(t);
  }

  String _out(AttRecord r) =>
      r.checkOut == null ? ' → open' : ' → ' + _hm(r.checkOut);

  Widget _rule(IconData i, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(i, size: 15, color: AppConfig.navy),
          const SizedBox(width: 8),
          Expanded(
              child: Text(t,
                  style: const TextStyle(fontSize: 12.5))),
        ]),
      );
}

// ---------- SCANNER ----------
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});
  @override
  State<ScannerPage> createState() => _Scan();
}

class _Scan extends State<ScannerPage> {
  final ctrl = MobileScannerController();
  bool done = false;

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (done) return;
    if (cap.barcodes.isEmpty) return;
    final v = cap.barcodes.first.rawValue;
    if (v == null || v.isEmpty) return;
    done = true;
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Scan QR'),
            actions: [
              IconButton(
                  onPressed: () async {
                    try {
                      await ctrl.toggleTorch();
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.flash_on)),
            ]),
        body: MobileScanner(controller: ctrl, onDetect: _onDetect),
      );
}

