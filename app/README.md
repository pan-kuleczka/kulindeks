# Kulindeks (Flutter app)

A faster, cleaner client for the **mStudent API** (Simple S.A.'s university
backend) — reverse-engineered in [`../docs/protocol.md`](../docs/protocol.md).
Talks directly to each university's backend over HTTPS; no middleman.

Part of the [Kulindeks](https://github.com/pan-kuleczka/kulindeks) project.
**Independent / unofficial** — not affiliated with Simple S.A. or any university.

## Features
- **Multi-university login** via the live discovery endpoint.
- **Dashboard** — identity card → full student info, next class, GPA, dues, unread
  messages; every tile taps through to its section.
- **Timetable** — Day / Week / Month calendar on a time grid, swipe to change
  period, room → maps, `.ics` export, one-tap **Nextcloud (CalDAV) sync**.
- **Grades** — ECTS-weighted + arithmetic averages, color-coded, per programme/semester.
- **Finances** — dues and scholarships.
- **Messages** — inbox + full message view.
- **Appearance & i18n** — light / dark / high-contrast themes, custom accent color,
  font scale, **Polish & English** (switchable at login and in settings).
- **Notifications** — class reminders a configurable time before each class
  (OS-scheduled on Android; in-app timers on desktop).
- **Speed / offline** — cache-first rendering, background refresh, and a clear
  offline banner that keeps showing cached data.

## Architecture
```
lib/
  api/      client.dart   MStudentClient — discovery, auth, endpoints (dep-free dart:io)
            models.dart   typed models (AuthSession, Grade, ClassEvent, …)
            caldav.dart   minimal CalDAV push for Nextcloud sync
  l10n/     strings.dart  pl / en dictionary
  state/    app_state.dart   ChangeNotifier: auth + cache-first loaders (Resource<T>)
            settings.dart    prefs (theme, locale, font, accent, notifications, Nextcloud)
            session_store.dart  on-device session/credential persistence
            cache.dart / notifications.dart
  ui/       login / home (bottom-nav) + dashboard/timetable/grades/finance/messages
            + student_info / message_detail / settings
```
The API client is UI-agnostic and runs standalone — see
`example/discover.dart` (`dart run example/discover.dart`).

**Credentials & data** are stored in a plain file in the app-support directory
(no native keyring dependency; portable across Android/iOS/Linux). Nothing leaves
the device except requests to your own university's server. No analytics.

## Run on Linux desktop
```bash
bash build_linux.sh     # builds a native GTK app (uses nix for the toolchain)
bash run_linux.sh       # launches it with the right runtime libs (NixOS-friendly)
```
Binary lands at `build/linux/x64/release/bundle/kulindeks`.

## Build for Android
With a standard Flutter + Android SDK setup:
```bash
flutter pub get
flutter build apk --release                 # universal APK (all ABIs)
flutter build apk --release --split-per-abi # one APK per ABI (smaller downloads)
flutter build appbundle --release           # .aab for Play Store
```
On **NixOS**, the SDK/JDK/NDK are assembled by nix — just run:
```bash
bash build_apk.sh          # release APKs for arm64-v8a, armeabi-v7a, x86_64
```
(`build_apk.sh` uses `android-shell.nix`, which pins the Android SDK + NDK and
applies the NixOS-specific `aapt2` override.)

iOS: the code is iOS-compatible (no Android-only APIs); run
`flutter create . --platforms=ios` to add the iOS project, then build on a Mac.

## License
[GNU GPL v3](../LICENSE).
