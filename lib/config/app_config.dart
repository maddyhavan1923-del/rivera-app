// Rivera Group - Global App Config
// 1000-year safe: no hardcoded year limits, all dates use DateTime + UTC, leap-year safe via Dart SDK.
import 'package:flutter/material.dart';

class AppConfig {
  // ---- Company ----
  static const String companyName = 'Rivera Group of Companies';
  static const String companyAddress =
      '191/1, Perundurai Main Road, Opp. Veerappampalayam By-Pass Road, Thindal (Post), Erode, Tamil Nadu - 638 102, India';
  static const String companyPhone = '+91 (0)424 227 3399 / +91 77085 49900';
  static const String companyEmail = 'info@rivera.co.in';
  static const String companyWebsite = 'www.rivera.co.in';

  // Company gate GPS — Admin can update inside app (Settings tab).
  // Default: Thindal, Erode approx. Change to exact gate coordinates after install.
  static double companyLat = 11.3265;
  static double companyLng = 77.6950;
  static double geofenceRadiusMeters = 200; // inside company = present
  static double gateBufferMeters = 500; // gate-marked but outside = suspicious

  // ---- Brand colours (Rivera blue/orange) ----
  static const Color navy = Color(0xFF0B2A4A);
  static const Color blue = Color(0xFF145DA0);
  static const Color orange = Color(0xFFF26B21);
  static const Color bg = Color(0xFFF4F6FA);

  // ---- Default admin (change after first login!) ----
  static const String defaultAdminUser = 'admin';
  static const String defaultAdminPass = 'Rivera@123';

  // ---- Anti-bypass rules ----
  // Gate-la mark pottutu veliya ponna pidikka:
  static const int reVerifyMinutes = 60; // every 60 min re-verify location
  static const int autoSuspiciousMinutes = 30; // geofence veliya 30 min irundha 'Suspicious'
  static const bool blockMockLocation = true;
  static const bool requireSelfieOnCheckIn = false; // true aakina selfie compulsory

  // ---- Daily live QR (visitors) ----
  // QR payload changes every day: RIVERA-VISIT-yyyy-MM-dd-SECRET
  static const String qrSecret = 'RIV-V3-2026';
}
