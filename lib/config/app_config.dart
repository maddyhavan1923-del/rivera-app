// Rivera Group - Global App Config (v4)
// 1000-year safe: no hardcoded year limits, leap-year safe, offline-first.
import 'package:flutter/material.dart';

class AppConfig {
  static const String appName = 'Rivera Attendance v4';
  static const String version = 'v4.0';
  static const String companyName = 'Rivera Group of Companies';
  static const String companyAddress =
      '191/1, Perundurai Main Road, Opp. Veerappampalayam By-Pass Road, Thindal (Post), Erode, Tamil Nadu - 638 102, India';
  static const String companyPhone = '+91 (0)424 227 3399 / +91 77085 49900';
  static const String crmEmail = 'info@rivera.co.in';
  static const String companyWebsite = 'www.rivera.co.in';

  // Company GPS (Admin can update in-app: More -> Admin -> Set Location)
  static double companyLat = 11.3265;
  static double companyLng = 77.6950;
  static double geofenceRadiusMeters = 150;

  static const Color navy = Color(0xFF0B2A4A);
  static const Color blue = Color(0xFF145DA0);
  static const Color orange = Color(0xFFF26B21);
  static const Color bg = Color(0xFFF4F6FA);
  static const Color green = Color(0xFF1B9E4B);
  static const Color red = Color(0xFFD64545);

  static const String defaultAdminUser = 'admin';
  static const String defaultAdminPass = 'Rivera@123';

  // Anti-bypass: gate-la mark pottutu veliya pona pidikka
  static const int autoReVerifyMinutes = 15;
  static const bool blockMockLocation = true;
  static const String qrSecret = 'RIV-V4-2026';
}
