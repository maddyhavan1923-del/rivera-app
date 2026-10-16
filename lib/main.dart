import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'services/attendance_service.dart';
import 'services/data_services.dart';
import 'services/excel_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.ensureDefaultAdmin();
  runApp(const RiveraApp());
}

class RiveraApp extends StatelessWidget {
  const RiveraApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rivera Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: AppConfig.blue, scaffoldBackgroundColor: AppConfig.bg),
      home: const Splash(),
    );
  }
}

class Splash extends StatefulWidget { const Splash({super.key}); @override State<Splash> createState() => _Splash(); }
class _Splash extends State<Splash> {
  @override
  void initState() { super.initState(); _go(); }
  void _go() async {
    await Future.delayed(const Duration(milliseconds: 800));
    final s = await AuthService.session();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => s == null ? const LoginPage() : HomePage(user: s)));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppConfig.navy,
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/logo.png', width: 110, errorBuilder: (_, __, ___) =>
          Container(width: 90, height: 90, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: const Center(child: Text('R', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppConfig.navy))))),
        const SizedBox(height: 14),
        const Text('RIVERA', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4)),
        const Text('GROUP OF COMPANIES', style: TextStyle(color: Colors.white70, letterSpacing: 2, fontSize: 12)),
        const SizedBox(height: 8),
        const Text('Attendance • Leave • Diary • Visitors', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ])));
  }
}

// ---------------- LOGIN / REGISTER ----------------
class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState() => _Login(); }
class _Login extends State<LoginPage> {
  final u = TextEditingController(), p = TextEditingController();
  String err = '';
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Card(
      elevation: 4, child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('RIVERA LOGIN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConfig.navy)),
        const SizedBox(height: 4), const Text('Office staff — register panni login pannu', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        TextField(controller: u, decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
        const SizedBox(height: 12),
        TextField(controller: p, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
          final user = await AuthService.login(u.text.trim(), p.text);
          if (user == null) { setState(() => err = 'Username/Password thappu.'); return; }
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(user: user)));
        }, child: const Text('LOGIN'))),
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())), child: const Text('New staff? Register here')),
        const Divider(),
        const Text('Default Admin → admin / Rivera@123\n(First login-la password-ah maathirunga)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
      ]))))));
  }
}

class RegisterPage extends StatefulWidget { const RegisterPage({super.key}); @override State<RegisterPage> createState() => _Reg(); }
class _Reg extends State<RegisterPage> {
  final u = TextEditingController(), p = TextEditingController(), n = TextEditingController(), d = TextEditingController(), ph = TextEditingController();
  String msg = '';
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Staff Register')) , body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      TextField(controller: n, decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      TextField(controller: u, decoration: const InputDecoration(labelText: 'Username *', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      TextField(controller: p, obscureText: true, decoration: const InputDecoration(labelText: 'Password (min 4) *', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      TextField(controller: d, decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      TextField(controller: ph, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
        final e = await AuthService.register(username: u.text, password: p.text, name: n.text, department: d.text, phone: ph.text);
        setState(() => msg = e ?? 'Registered! Login pannu.');
        if (e == null && mounted) { await Future.delayed(const Duration(milliseconds: 600)); if (mounted) Navigator.pop(context); }
      }, child: const Text('REGISTER'))),
      if (msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(msg)),
    ])));
  }
}

// ---------------- HOME ----------------
class HomePage extends StatefulWidget {
  final AppUser user;
  const HomePage({super.key, required this.user});
  @override State<HomePage> createState() => _Home();
}
class _Home extends State<HomePage> {
  int idx = 0;
  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user.role == 'admin';
    final tabs = [
      const AttTab(), const LeaveTab(), const DiaryTab(), const RefTab(), const VisitTab(),
      if (isAdmin) const AdminTab(), const SettingsTab(),
    ];
    final labels = ['Attendance', 'Leave/CRM', 'Diary', 'Reference', 'Visitors', if (isAdmin) 'Admin', 'More'];
    final icons = [Icons.fingerprint, Icons.inbox, Icons.book, Icons.star, Icons.qr_code_2, if (isAdmin) Icons.admin_panel_settings, Icons.menu];
    return Scaffold(
      appBar: AppBar(backgroundColor: AppConfig.navy, foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hi, ${widget.user.name}', style: const TextStyle(fontSize: 15)),
          Text('${widget.user.username} • ${widget.user.role}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.table_chart), tooltip: 'Excel Export',
            onPressed: () async { try { await ExcelService.exportAll(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'))); } }),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: () async {
            // checkout reminder: checkout pannama logout panna koodathu nu warning
            await AuthService.logout();
            if (!mounted) return;
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
          }),
        ]),
      body: tabs[idx],
      bottomNavigationBar: NavigationBar(selectedIndex: idx, onDestinationSelected: (i) => setState(() => idx = i),
        destinations: List.generate(labels.length, (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]))),
    );
  }
}

// ---------------- ATTENDANCE TAB ----------------
class AttTab extends StatefulWidget { const AttTab({super.key}); @override State<AttTab> createState() => _Att(); }
class _Att extends State<AttTab> {
  String msg = '';
  List<AttRecord> mine = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final s = await AuthService.session();
    if (s == null) return;
    mine = await AttendanceService.forUser(s.username);
    if (mounted) setState(() {});
  }
  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, dd MMM yyyy').format(DateTime.now());
    final hasToday = mine.any((e) => e.date == AttendanceService.todayKey());
    final todayRec = hasToday ? mine.firstWhere((e) => e.date == AttendanceService.todayKey()) : null;
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(color: AppConfig.navy, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Text(today, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        Text(hasToday ? (todayRec!.checkOut != null ? 'Checked OUT ✓' : (todayRec.suspicious ? 'SUSPICIOUS ⚠' : 'Checked IN ✓ Verified')) : 'Not marked yet',
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        if (todayRec != null) Text('In: ${todayRec.checkIn}\n${todayRec.suspicious ? todayRec.note : 'Distance: ${todayRec.distanceM.toStringAsFixed(0)}m (inside premises)'}',
          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: FilledButton.icon(icon: const Icon(Icons.fingerprint), label: const Text('CHECK-IN\n(GPS verify)'),
          onPressed: () async {
            try {
              final s = await AuthService.session();
              setState(() => msg = 'GPS check pannrom...');
              final r = await AttendanceService.checkIn(s!.username);
              setState(() => msg = 'Present ✓ — ${r.distanceM.toStringAsFixed(0)}m, verified.');
              _load();
            } catch (e) { setState(() => msg = '$e'); }
          })),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.logout), label: const Text('CHECK-OUT'),
          onPressed: () async {
            try {
              final s = await AuthService.session();
              await AttendanceService.checkOut(s!.username);
              setState(() => msg = 'Checked-out. Nalaiku paakalaam!');
              _load();
            } catch (e) { setState(() => msg = '$e'); }
          })),
      ]),
      const SizedBox(height: 8),
      FilledButton.tonalIcon(icon: const Icon(Icons.radar), label: const Text('RE-VERIFY (company-kulla irukken)'),
        onPressed: () async {
          final s = await AuthService.session();
          final r = await AttendanceService.reVerify(s!.username);
          setState(() => msg = r);
          _load();
        }),
      const SizedBox(height: 4),
      const Text('Gate-la mark pottutu veliya ponaal "Suspicious" flag admin-ku pogum. Every 60 min Re-verify pannu.',
        style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
      if (msg.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(10), child: Text(msg))),
      const SizedBox(height: 8),
      const Text('My History', style: TextStyle(fontWeight: FontWeight.bold)),
      ...mine.take(30).map((e) => ListTile(
        leading: Icon(e.suspicious ? Icons.warning : Icons.check_circle, color: e.suspicious ? Colors.orange : Colors.green),
        title: Text('${e.date} — ${e.checkOut != null ? 'In+Out' : 'In only'}${e.suspicious ? ' ⚠ Suspicious' : ''}'),
        subtitle: Text('In: ${e.checkIn.substring(0, 16)} ${e.checkOut != null ? '\nOut: ${e.checkOut!.substring(0, 16)}' : ''}'),
        dense: true,
      )),
    ]));
  }
}

// ---------------- LEAVE / CRM TAB ----------------
class LeaveTab extends StatefulWidget { const LeaveTab({super.key}); @override State<LeaveTab> createState() => _Leave(); }
class _Leave extends State<LeaveTab> {
  final reason = TextEditingController();
  String type = 'Casual', from = '', to = '';
  List<LeaveReq> list = [];
  @override
  void initState() { super.initState(); _load(); _pickDefaults(); }
  void _pickDefaults() {
    final n = DateTime.now();
    from = '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    to = from;
  }
  Future<void> _load() async {
    list = await LeaveService.all();
    final s = await AuthService.session();
    if (s != null && s.role != 'admin') list = list.where((e) => e.username == s.username).toList();
    list = list.reversed.toList();
    if (mounted) setState(() {});
  }
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Leave Apply (Admin CRM inbox-ku pogum)', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      DropdownButtonFormField(value: type, items: const ['Casual', 'Sick', 'Earned', 'Permission', 'On-Duty', 'Other']
        .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => type = v.toString()), decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: OutlinedButton(child: Text('From: $from'), onPressed: () async {
          final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (d != null) setState(() => from = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
        })),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(child: Text('To: $to'), onPressed: () async {
          final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (d != null) setState(() => to = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
        })),
      ]),
      const SizedBox(height: 8),
      TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      FilledButton(onPressed: () async {
        final s = await AuthService.session();
        if (reason.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reason ezhuthu'))); return; }
        await LeaveService.apply(s!.username, type, from, to, reason.text.trim());
        reason.clear();
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Applied ✓ — Admin CRM inbox-ku poniruchu')));
      }, child: const Text('APPLY LEAVE')),
      const Divider(),
      ...list.map((l) => Card(child: ListTile(
        title: Text('${l.username} • ${l.type} (${l.status})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text('${l.from} → ${l.to}\n${l.reason}'),
        trailing: FutureBuilder<AppUser?>(future: AuthService.session(), builder: (c, s) {
          if (s.data?.role != 'admin') return const SizedBox();
          return PopupMenuButton(onSelected: (v) async { await LeaveService.setStatus(l.id, v.toString()); _load(); },
            itemBuilder: (_) => const [PopupMenuItem(value: 'Approved', child: Text('Approve')), PopupMenuItem(value: 'Rejected', child: Text('Reject'))]);
        }),
      ))),
    ]));
  }
}

// ---------------- DIARY TAB ----------------
class DiaryTab extends StatefulWidget { const DiaryTab({super.key}); @override State<DiaryTab> createState() => _Diary(); }
class _Diary extends State<DiaryTab> {
  final work = TextEditingController();
  List<DiaryEntry> list = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final all = await DiaryService.all();
    final s = await AuthService.session();
    list = (s != null && s.role != 'admin') ? all.where((e) => e.username == s.username).toList() : all;
    list = list.reversed.take(100).toList();
    if (mounted) setState(() {});
  }
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Daily Work Diary (ellraum daily update)', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      TextField(controller: work, maxLines: 3, decoration: const InputDecoration(labelText: 'Inniku enna work panna?', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      FilledButton(onPressed: () async {
        if (work.text.trim().isEmpty) return;
        final s = await AuthService.session();
        await DiaryService.add(s!.username, AttendanceService.todayKey(), work.text.trim());
        work.clear(); _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diary saved ✓')));
      }, child: const Text('SAVE TODAY WORK')),
      const Divider(),
      ...list.map((d) => Card(child: ListTile(title: Text('${d.username} • ${d.date}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), subtitle: Text(d.work)))),
    ]));
  }
}

// ---------------- REFERENCE TAB ----------------
class RefTab extends StatefulWidget { const RefTab({super.key}); @override State<RefTab> createState() => _Ref(); }
class _Ref extends State<RefTab> {
  final t = TextEditingController(), d = TextEditingController();
  List<Map<String, String>> list = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { list = (await ReferenceService.all()).reversed.toList(); if (mounted) setState(() {}); }
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Reference Tab', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('Employee referral / customer reference / document reference — ellam inga save pannu.', style: TextStyle(fontSize: 11, color: Colors.grey)),
      const SizedBox(height: 8),
      TextField(controller: t, decoration: const InputDecoration(labelText: 'Title (ex: Kumar referral - Fitter)', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: d, maxLines: 2, decoration: const InputDecoration(labelText: 'Details (name, phone, note)', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      FilledButton(onPressed: () async {
        if (t.text.trim().isEmpty) return;
        final s = await AuthService.session();
        await ReferenceService.add({'title': t.text.trim(), 'details': d.text.trim(), 'by': s?.username ?? ''});
        t.clear(); d.clear(); _load();
      }, child: const Text('ADD REFERENCE')),
      const Divider(),
      ...list.map((r) => Card(child: ListTile(title: Text(r['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), subtitle: Text('${r['details'] ?? ''}\nby ${r['by'] ?? ''} • ${r['on'] ?? ''}')))),
    ]));
  }
}

// ---------------- VISITORS TAB (live QR + entry + exit feedback) ----------------
class VisitTab extends StatefulWidget { const VisitTab({super.key}); @override State<VisitTab> createState() => _Vis(); }
class _Vis extends State<VisitTab> {
  final n = TextEditingController(), ph = TextEditingController(), pur = TextEditingController(), meet = TextEditingController();
  List<Map<String, String>> list = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { list = (await VisitorService.all()).reversed.toList(); if (mounted) setState(() {}); }
  @override
  Widget build(BuildContext context) {
    final qr = VisitorService.dailyQRPayload();
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        const Text('TODAY LIVE QR (visitors scan pannanum)', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(DateFormat('dd MMM yyyy').format(DateTime.now()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        QrImageView(data: qr, size: 170),
        const SizedBox(height: 4),
        SelectableText(qr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const Text('Everyday QR auto-matrumm — yesterday QR work aagathu.', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 6),
        OutlinedButton.icon(icon: const Icon(Icons.qr_code_scanner), label: const Text('SCAN & VERIFY QR'),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScanPage()))),
      ]))),
      const SizedBox(height: 8),
      const Text('Visitor Entry', style: TextStyle(fontWeight: FontWeight.bold)),
      TextField(controller: n, decoration: const InputDecoration(labelText: 'Visitor Name *', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: ph, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
      const SizedBox(height: 8),
      TextField(controller: pur, decoration: const InputDecoration(labelText: 'Purpose', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: meet, decoration: const InputDecoration(labelText: 'Yaara paakka (Meet)', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      FilledButton(onPressed: () async {
        if (n.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name kudu'))); return; }
        await VisitorService.entry({'name': n.text.trim(), 'phone': ph.text.trim(), 'purpose': pur.text.trim(), 'meet': meet.text.trim()});
        n.clear(); ph.clear(); pur.clear(); meet.clear(); _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visitor entry saved ✓')));
      }, child: const Text('ADD VISITOR ENTRY')),
      const Divider(),
      const Text('Exit Feedback (company vittu poka mothu)', style: TextStyle(fontWeight: FontWeight.bold)),
      ...List.generate(list.length, (i) {
        final v = list[i];
        final done = (v['feedback'] ?? '').isNotEmpty;
        return Card(child: ListTile(
          title: Text('${v['name']} ${done ? '✓ Feedback done' : '• Feedback pending'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: Text('${v['purpose'] ?? ''} • Meet: ${v['meet'] ?? ''}\nIn: ${v['in'] ?? ''}${done ? '\nFeedback: ${v['feedback']}' : ''}'),
          trailing: done ? const Icon(Icons.check, color: Colors.green) : IconButton(icon: const Icon(Icons.feedback_outlined),
            onPressed: () async {
              // need real index in stored list (reversed)
              final all = await VisitorService.all();
              final realIdx = all.length - 1 - i;
              final c = TextEditingController();
              if (!context.mounted) return;
              showDialog(context: context, builder: (_) => AlertDialog(
                title: const Text('Exit Feedback'), content: TextField(controller: c, maxLines: 2, decoration: const InputDecoration(hintText: 'Experience eppadi irundhuchu?')),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  FilledButton(onPressed: () async { await VisitorService.feedback(realIdx, c.text.trim()); if (context.mounted) Navigator.pop(context); _load(); }, child: const Text('SUBMIT'))],
              ));
            }),
        ));
      }),
    ]));
  }
}

class QRScanPage extends StatelessWidget {
  const QRScanPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Scan Visitor QR')),
      body: MobileScanner(onDetect: (cap) {
        final code = cap.barcodes.isNotEmpty ? (cap.barcodes.first.rawValue ?? '') : '';
        final ok = VisitorService.isQRValidToday(code);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Valid TODAY QR ✓ — entry allow pannu' : 'Invalid/Expired QR ✗ ($code)'),
          backgroundColor: ok ? Colors.green : Colors.red));
        if (ok) Navigator.pop(context);
      }));
  }
}

// ---------------- ADMIN TAB ----------------
class AdminTab extends StatefulWidget { const AdminTab({super.key}); @override State<AdminTab> createState() => _Admin(); }
class _Admin extends State<AdminTab> {
  List<AppUser> users = [];
  List<AttRecord> att = [];
  final nu = TextEditingController(), np = TextEditingController(), nn = TextEditingController(), nd = TextEditingController();
  String msg = '';
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    users = await AuthService.allUsers();
    att = await AttendanceService.all();
    att = att.reversed.take(200).toList();
    if (mounted) setState(() {});
  }
  @override
  Widget build(BuildContext context) {
    final sus = att.where((e) => e.suspicious).length;
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(color: sus > 0 ? Colors.orange.shade100 : Colors.green.shade50, child: Padding(padding: const EdgeInsets.all(12),
        child: Text('Today records: ${att.where((e) => e.date == AttendanceService.todayKey()).length} • Suspicious (gate-bypass): $sus',
          style: const TextStyle(fontWeight: FontWeight.bold)))),
      const SizedBox(height: 8),
      const Text('Create User + Password (app-la ye)', style: TextStyle(fontWeight: FontWeight.bold)),
      TextField(controller: nn, decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: nu, decoration: const InputDecoration(labelText: 'Username *', border: OutlineInputBorder()))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: np, decoration: const InputDecoration(labelText: 'Password *', border: OutlineInputBorder()))),
      ]),
      const SizedBox(height: 8),
      TextField(controller: nd, decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      FilledButton(onPressed: () async {
        final e = await AuthService.adminCreateUser(username: nu.text, password: np.text, name: nn.text, department: nd.text);
        setState(() => msg = e ?? 'User created ✓');
        if (e == null) { nu.clear(); np.clear(); nn.clear(); nd.clear(); _load(); }
      }, child: const Text('CREATE LOGIN')),
      if (msg.isNotEmpty) Text(msg),
      const Divider(),
      const Text('All Users (reset/delete)', style: TextStyle(fontWeight: FontWeight.bold)),
      ...users.map((usr) => Card(child: ListTile(
        title: Text('${usr.name} (${usr.username})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text('${usr.role} • ${usr.department} • ${usr.phone}'),
        trailing: PopupMenuButton(onSelected: (v) async {
          if (v == 'reset') {
            final c = TextEditingController();
            if (!context.mounted) return;
            showDialog(context: context, builder: (_) => AlertDialog(title: Text('Reset: ${usr.username}'),
              content: TextField(controller: c, decoration: const InputDecoration(hintText: 'New password (min 4)')),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(onPressed: () async { await AuthService.adminResetPassword(usr.username, c.text); if (context.mounted) Navigator.pop(context); }, child: const Text('SAVE'))]));
          } else if (v == 'del') {
            await AuthService.adminDeleteUser(usr.username);
            _load();
          }
        }, itemBuilder: (_) => const [PopupMenuItem(value: 'reset', child: Text('Reset password')), PopupMenuItem(value: 'del', child: Text('Delete user'))]),
      ))),
      const Divider(),
      Row(children: [
        const Text('Attendance (all) + Excel', style: TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        FilledButton.tonalIcon(icon: const Icon(Icons.table_chart), label: const Text('EXCEL'),
          onPressed: () async { try { await ExcelService.exportAll(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } }),
      ]),
      ...att.take(50).map((e) => ListTile(dense: true,
        leading: Icon(e.suspicious ? Icons.warning : Icons.check_circle, color: e.suspicious ? Colors.orange : Colors.green, size: 20),
        title: Text('${e.date} • ${e.username}${e.suspicious ? ' ⚠' : ''}', style: const TextStyle(fontSize: 12)),
        subtitle: Text('In: ${e.checkIn.length > 16 ? e.checkIn.substring(0, 16) : e.checkIn} ${e.checkOut != null ? '| Out ✓' : '| Out pending'}', style: const TextStyle(fontSize: 11)),
      )),
    ]));
  }
}

// ---------------- MORE / SETTINGS TAB ----------------
class SettingsTab extends StatefulWidget { const SettingsTab({super.key}); @override State<SettingsTab> createState() => _Set(); }
class _Set extends State<SettingsTab> {
  final lat = TextEditingController(), lng = TextEditingController(), rad = TextEditingController();
  AppUser? me;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    me = await AuthService.session();
    lat.text = AppConfig.companyLat.toString();
    lng.text = AppConfig.companyLng.toString();
    rad.text = AppConfig.geofenceRadiusMeters.toString();
    if (mounted) setState(() {});
  }
  @override
  Widget build(BuildContext context) {
    final isAdmin = me?.role == 'admin';
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Login Details', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('Name: ${me?.name ?? ''}\nUsername: ${me?.username ?? ''}\nRole: ${me?.role ?? ''}\nDept: ${me?.department ?? ''}\nPhone: ${me?.phone ?? ''}'),
        const SizedBox(height: 6),
        FutureBuilder(future: AuthService.session(), builder: (c, s) => const SizedBox()),
      ]))),
      const SizedBox(height: 8),
      const Card(child: Padding(padding: EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Company Location (GPS Gate)', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('191/1, Perundurai Main Road, Thindal, Erode - 638102', style: TextStyle(fontSize: 11, color: Colors.grey)),
      ]))),
      if (isAdmin) ...[
        TextField(controller: lat, decoration: const InputDecoration(labelText: 'Company Latitude', border: OutlineInputBorder()), keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        TextField(controller: lng, decoration: const InputDecoration(labelText: 'Company Longitude', border: OutlineInputBorder()), keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        TextField(controller: rad, decoration: const InputDecoration(labelText: 'Radius (meters, ex: 200)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        FilledButton(onPressed: () {
          AppConfig.companyLat = double.tryParse(lat.text) ?? AppConfig.companyLat;
          AppConfig.companyLng = double.tryParse(lng.text) ?? AppConfig.companyLng;
          AppConfig.geofenceRadiusMeters = double.tryParse(rad.text) ?? AppConfig.geofenceRadiusMeters;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location saved (this device). Permanent-ku code-la update pannu.')));
        }, child: const Text('SAVE LOCATION')),
      ] else ...[
        Text('Location: ${AppConfig.companyLat}, ${AppConfig.companyLng} • Radius: ${AppConfig.geofenceRadiusMeters}m\n(Admin mattum maatha mudiyum)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(icon: const Icon(Icons.table_chart), label: const Text('EXPORT ALL TO EXCEL'),
        onPressed: () async { try { await ExcelService.exportAll(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } }),
      const SizedBox(height: 8),
      FilledButton.tonalIcon(icon: const Icon(Icons.logout), label: const Text('LOGOUT'),
        onPressed: () async { await AuthService.logout(); if (!mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())); }),
      const SizedBox(height: 12),
      const Text('Rivera v3.0 • Offline-first • Works every day, every year • No expiry', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
    ]));
  }
}
