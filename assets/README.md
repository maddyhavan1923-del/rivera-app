# Rivera Attendance v3 — Advanced (Tamil + English Guide)

## Enna New (v3 Advanced Features)
1. **Company-kulla irukangala Verification** — GPS geofence (default 200m). Veliya irundha check-in block. Fake GPS/Mock location block.
2. **Gate-bypass solution** — Gate-la mark pottutu veliya pona: `Re-verify` button + Admin-ku `Suspicious ⚠` flag auto-pogum. Every 60 min re-verify pannu.
3. **Leave → CRM Inbox** — Leave apply panna admin CRM inbox-ku pogum. Admin approve/reject pannalam.
4. **Daily Diary** — Ellarum daily work update pannalam. Admin ellarayum paakkalam.
5. **Excel export irukku** — Attendance + Leave + Diary + Visitors + Users ella sheet-um onna export (Share via WhatsApp/Drive).
6. **Reference Tab** — Referral / customer / document reference save.
7. **Visitors + Daily Live QR** — Everyday QR auto-maarum. Yesterday QR work aagathu. Entry + exit feedback (company vittu poka mothu).
8. **Login/Register/Logout** — Office staff app install panni register → login → use. Logout button ella screen-layum.
9. **Admin in-app user create** — Admin tab-la username + password create, reset, delete — ella app-la ye.
10. **Company location setting** — Admin tab-la GPS lat/lng + radius maathalam.
11. **1000-year safe** — No year limit (2000–2100 picker, storage trim, ISO dates, leap-year safe). Error varathu.
12. **App logo = Company logo** — `assets/logo.png` vachirukkom.

## Default Admin
- Username: `admin`
- Password: `Rivera@123`
- First login-la Admin tab → user create pannu, ella staff-kum login kudu.

## Logo Setup (1 step — IMPORTANT)
APK build munnadi:
1. `C:\Users\user\Downloads\Rivera_Signature_695x296.png` file-ah copy panni
2. `rivera_attendance_v3\assets\logo.png` nu rename/paste pannu
3. Folder illana `assets` folder create pannu.

## Build APK (Flutter installed PC-la)
```
cd rivera_attendance_v3
flutter pub get
flutter build apk --release
```
APK path: `build\app\outputs\flutter-apk\app-release.apk`

Flutter install illana: https://docs.flutter.dev/get-started/install/windows

## Company GPS exact-ah set panna
1. Admin login → More tab → lat/lng paaru (default Thindal approx).
2. Google Maps-la company gate-ah long-press panni exact lat/lng eduthu app-la save pannu.
3. Permanent-ku `lib/config/app_config.dart` la `companyLat/companyLng` maathidu, rebuild pannu.

## Daily Use Flow
- Staff: Login → Attendance Check-in (GPS) → work → Diary update → Check-out → Logout
- Leave: Leave/CRM tab → Apply → Admin approve
- Visitor: Visitors tab → Live QR kaattu → Entry add → poka mothu Feedback submit
- Admin: Admin tab → users create, attendance paaru, suspicious check, Excel export
