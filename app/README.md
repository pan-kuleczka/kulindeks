# Indeks (Flutter)

A faster, cleaner client for the **mStudent API** (Simple S.A.'s university
backend) — reverse-engineered in `../docs/protocol.md`. Talks directly to each
university's backend over HTTPS; no pinning, no middleman.

> **Name:** "Indeks" (the Polish term for a student grade-book) is a placeholder
> chosen to avoid any trademark issue with the original "mStudent" app. To
> rebrand, change `name:` in `pubspec.yaml`, the display strings in
> `lib/main.dart` / `lib/ui/login_screen.dart`, and re-run
> `flutter create . --platforms=android,linux --org <you> --project-name <name>`.
> References to the *mStudent API* itself are factual and intentionally kept.

## Features (v0.1)
- **Multi-university login** via the live discovery endpoint (pick your college).
- **Unified dashboard**: next class, GPA, outstanding dues, unread messages.
- **Grades + GPA**: ECTS-weighted average and arithmetic mean, color-coded, per
  kierunek/semestr.
- **Calendar**: month/week timetable with a day agenda (weekly entries expanded
  to real dates), tap a room to open it in maps (the API returns room GPS),
  one-tap **.ics export**, and **Nextcloud (CalDAV) sync** from Settings.
- **Finances**: dues with an outstanding-total card.
- **Messages**: inbox with unread highlighting.
- **Speed/caching**: every screen renders cached data instantly, then refreshes
  in the background (`JsonCache`); the session is kept until it expires and only
  re-logs in on 401 — unlike the official app, which re-authenticates constantly.
- Session + credentials stored in a plain file in the app-support dir (no native keyring dep; portable across Android/iOS/Linux).

## Architecture
```
lib/
  api/      client.dart   MStudentClient — discovery, auth, endpoints (dep-free dart:io)
            models.dart   typed models (AuthSession, Grade, ClassEvent, …)
  state/    app_state.dart ChangeNotifier: auth + cache-first loaders (Resource<T>)
            cache.dart     TTL JSON cache (shared_preferences)
            session_store.dart  secure session/credential persistence
  ui/       login / home (bottom-nav) + dashboard/grades/timetable/finance/messages tabs
```
The API client is UI-agnostic and runs standalone (see `example/discover.dart`:
`dart run example/discover.dart`).

## Run on Linux (works right now, no phone needed)
```
bash build_linux.sh     # builds a native GTK app (uses nix for the toolchain)
bash run_linux.sh       # launches it with the right runtime libs (NixOS-friendly)
```
`build_linux.sh` pulls the Linux build toolchain via `nix-shell`; the binary
lands at `build/linux/x64/release/bundle/indeks`. `run_linux.sh` sets
`LD_LIBRARY_PATH` to the nix GTK libs so it launches cleanly on NixOS.
The storage layer is a plain file (no keyring dependency), so it runs anywhere.

## Build & run on Android
```
flutter pub get
flutter run                 # on a connected device/emulator
flutter build apk --release # installable APK
```
Requires Flutter ≥ 3.22 and the Android SDK. iOS: the code is iOS-compatible
(no Android-only APIs); run `flutter create . --platforms=ios` to add the iOS
project, then build on a Mac.

## Status / next
Read-only today. Natural next steps: message detail view + attachments, push
notifications (FCM — the API has `/api/notifications/...`), scholarships &
bank-account screens, timetable week/calendar view, biometric unlock.

> Personal project. Not affiliated with or endorsed by Simple S.A. or any
> university. Use your own credentials against your own account.
