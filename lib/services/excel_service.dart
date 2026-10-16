// Excel export — ella data-um Excel-la edukalam (excel v4 CellValue API fixed)
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'attendance_service.dart';
import 'data_services.dart';
import 'auth_service.dart';

class ExcelService {
  // Dynamic value-ah CellValue-ah maathum (excel 4.x requirement)
  static CellValue cv(dynamic v) {
    if (v == null) return const TextCellValue('');
    if (v is bool) return BoolCellValue(v);
    if (v is int) return IntCellValue(v);
    if (v is double) return DoubleCellValue(v);
    if (v is DateTime) return TextCellValue(v.toIso8601String());
    return TextCellValue(v.toString());
  }

  static Future<String> exportAll() async {
    final excel = Excel.createExcel();
    // Attendance sheet
    final att = await AttendanceService.all();
    final s1 = excel['Attendance'];
    s1.appendRow(['Date', 'User', 'CheckIn', 'CheckOut', 'Distance(m)', 'Verified', 'Suspicious', 'Note'].map(cv).toList());
    for (final r in att) {
      s1.appendRow([r.date, r.username, r.checkIn, r.checkOut ?? '', r.distanceM, r.verified, r.suspicious, r.note].map(cv).toList());
    }
    // Leave sheet
    final leaves = await LeaveService.all();
    final s2 = excel['Leave_CRM'];
    s2.appendRow(['ID', 'User', 'Type', 'From', 'To', 'Reason', 'Status', 'AppliedOn'].map(cv).toList());
    for (final l in leaves) {
      s2.appendRow([l.id, l.username, l.type, l.from, l.to, l.reason, l.status, l.appliedOn].map(cv).toList());
    }
    // Diary sheet
    final diary = await DiaryService.all();
    final s3 = excel['Daily_Diary'];
    s3.appendRow(['Date', 'User', 'Work', 'CreatedOn'].map(cv).toList());
    for (final d in diary) {
      s3.appendRow([d.date, d.username, d.work, d.createdOn].map(cv).toList());
    }
    // Visitors sheet
    final vis = await VisitorService.all();
    final s4 = excel['Visitors'];
    s4.appendRow(['Name', 'Phone', 'Purpose', 'Meet', 'In', 'Out', 'Feedback'].map(cv).toList());
    for (final v in vis) {
      s4.appendRow([v['name'], v['phone'], v['purpose'], v['meet'], v['in'], v['out'], v['feedback']].map(cv).toList());
    }
    // Users sheet
    final users = await AuthService.allUsers();
    final s5 = excel['Users'];
    s5.appendRow(['Username', 'Name', 'Role', 'Dept', 'Phone', 'CreatedOn'].map(cv).toList());
    for (final u in users) {
      s5.appendRow([u.username, u.name, u.role, u.department, u.phone, u.createdOn].map(cv).toList());
    }
    excel.delete('Sheet1');
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fname = 'Rivera_Export_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour}${now.minute}.xlsx';
    final file = File('${dir.path}/$fname');
    await file.writeAsBytes(excel.encode()!);
    await Share.shareXFiles([XFile(file.path)], text: 'Rivera Export - $fname');
    return file.path;
  }
}
