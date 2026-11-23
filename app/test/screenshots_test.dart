// Generates app screenshots headlessly with mock data (no network, no account).
// Uses the real Android UI font (Roboto, Apache-2.0, loaded from test/fonts/).
// Run:  flutter test test/screenshots_test.dart
// Output: ../screenshots/*.png  (phone resolution, light/dark, PL/EN).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kulindeks/api/models.dart';
import 'package:kulindeks/state/app_state.dart';
import 'package:kulindeks/state/cache.dart';
import 'package:kulindeks/state/notifications.dart';
import 'package:kulindeks/state/session_store.dart';
import 'package:kulindeks/state/settings.dart';
import 'package:kulindeks/ui/home_screen.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String dir;
  _FakePathProvider(this.dir);
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

String _d(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

Future<void> _loadFonts() async {
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    final bytes = File('test/fonts/$f').readAsBytesSync();
    roboto.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await roboto.load();
  // color emoji (flags etc.) as a fallback family
  final emoji = FontLoader('NotoColorEmoji')
    ..addFont(Future.value(
        ByteData.sublistView(File('test/fonts/NotoColorEmoji.ttf').readAsBytesSync())));
  await emoji.load();
}

Future<AppState> _mockState() async {
  final state = AppState(
      SessionStore(), await JsonCache.open(), SettingsStore(), NotificationService());
  state.status = AuthStatus.loggedIn;
  state.collegeName = 'Uniwersytet Przykładowy';
  state.kierunekId = 1;
  state.semestr = 3;

  state.info.value = {
    'imie': 'Jan', 'drugieImie': 'Maria', 'nazwisko': 'Kowalski',
    'numerAlbumu': '123456',
  };
  state.kierunki.value = [
    Kierunek.fromJson({
      'id': 1, 'nazwa': 'Informatyka', 'wydzial': 'Wydział Nauk Ścisłych',
      'tryb': 'stacjonarne', 'rodzaj': 'I stopnia', 'status': 'aktywny',
    }),
  ];
  state.semestry.value = [
    Semestr.fromJson({'id': 3, 'nazwa': 'Semestr 3', 'semestr': 3, 'aktywny': true}),
  ];

  final subjects = [
    ['Analiza matematyczna', 'Wykład', '4.5', 6.0],
    ['Programowanie obiektowe', 'Ćwiczenia laboratoryjne', '5.0', 5.0],
    ['Fizyka', 'Wykład', '4.0', 4.0],
    ['Język angielski', 'Lektorat', '4.5', 2.0],
    ['Systemy operacyjne', 'Seminarium', null, 3.0],
  ];
  state.grades.value = [
    for (var i = 0; i < subjects.length; i++)
      Grade.fromJson({
        'przedmiot': subjects[i][0], 'typPrzedmiotu': subjects[i][1],
        'nazwaOceny': subjects[i][2], 'liczbaPunktow': subjects[i][3],
        'dydaktykTytulNaukowy': 'dr', 'dydaktykImie': 'Anna', 'dydaktykNazwisko': 'Nowak',
        'typZakonczenia': 'Egzamin', 'liczbaGodzin': 30, 'numerTerminu': 1,
        'dataWystawienia': '2026-02-0${i + 1}',
      }),
  ];

  final monday = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  final plan = [
    [0, 'Pon.', '08:00', '09:30', 'Analiza matematyczna', 'Wykład'],
    [0, 'Pon.', '10:00', '11:30', 'Programowanie obiektowe', 'Ćwiczenia laboratoryjne'],
    [1, 'Wt.', '09:15', '10:45', 'Fizyka', 'Wykład'],
    [2, 'Śr.', '08:00', '09:30', 'Język angielski', 'Lektorat'],
    [2, 'Śr.', '11:30', '13:00', 'Systemy operacyjne', 'Seminarium'],
    [3, 'Czw.', '10:00', '11:30', 'Algorytmy', 'Ćwiczenia laboratoryjne'],
    [4, 'Pt.', '09:00', '10:30', 'Bazy danych', 'Wykład'],
  ];
  state.timetable.value = [
    for (final e in plan)
      ClassEvent.fromJson({
        'przedmiot': e[4], 'typPrzedmiotu': e[5], 'dzienTygodnia': e[1],
        'odDzien': _d(monday.add(Duration(days: e[0] as int))),
        'doDzien': _d(monday.add(Duration(days: e[0] as int))),
        'odGodzina': e[2], 'doGodzina': e[3],
        'imie': 'Anna', 'nazwisko': 'Nowak', 'tytul': 'dr',
        'sala': 'Bud_A_nr_12 Ul. Przykładowa 1', 'salaAdres': 'Ul. Przykładowa 1 Warszawa',
        'sala_latitude': 52.23, 'sala_longitude': 21.01,
      }),
  ];

  state.dues.value = [
    Naleznosc.fromJson({
      'idFinanse': 1, 'rodzaj': 'Czesne', 'typ': 'Opłata', 'tytul': 'Czesne — semestr zimowy',
      'ma': 1200.0, 'pozostalo': 1200.0, 'waluta': 'PLN', 'czyDoOplaty': true, 'czyOpacono': false,
    }),
    Naleznosc.fromJson({
      'idFinanse': 2, 'rodzaj': 'Legitymacja', 'typ': 'Opłata', 'tytul': 'Duplikat legitymacji',
      'ma': 22.0, 'pozostalo': 0.0, 'waluta': 'PLN', 'czyDoOplaty': false, 'czyOpacono': true,
    }),
  ];

  final msgs = [
    ['Spotkanie organizacyjne', 'Dziekanat', false],
    ['Wyniki egzaminu z analizy', 'dr Anna Nowak', false],
    ['Zapisy na seminarium', 'Sekretariat', true],
    ['Harmonogram sesji', 'Dziekanat', true],
  ];
  state.messages.value = [
    for (var i = 0; i < msgs.length; i++)
      MessageHeader.fromJson({
        'id': i + 1, 'temat': msgs[i][0], 'osoba': msgs[i][1],
        'data': '2026-02-1${i}T09:${30 + i}:00', 'przeczytana': msgs[i][2],
      }),
  ];
  return state;
}

Widget _app(AppState state, Brightness b) => ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2962FF), brightness: b),
          useMaterial3: true,
          fontFamily: 'Roboto',
          fontFamilyFallback: const ['NotoColorEmoji'],
        ),
        locale: Locale(state.prefs.locale),
        supportedLocales: const [Locale('pl'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeScreen(),
      ),
    );

void main() {
  setUpAll(() async {
    final tmp = Directory.systemTemp.createTempSync('kul_ss').path;
    PathProviderPlatform.instance = _FakePathProvider(tmp);
    SharedPreferences.setMockInitialValues({});
    Intl.defaultLocale = 'pl_PL';
    await initializeDateFormatting('pl_PL');
    await initializeDateFormatting('en');
    await loadAppFonts(); // MaterialIcons etc.
    await _loadFonts(); // real Android UI font (Roboto) + color emoji
  });

  testWidgets('generate screenshots', (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = await _mockState();
    Directory('../screenshots').createSync(recursive: true);

    // (filename, tabIndex, locale, brightness)
    final shots = <List<Object>>[
      ['dashboard', 0, 'pl', Brightness.light],
      ['timetable', 1, 'pl', Brightness.light],
      ['grades', 2, 'pl', Brightness.light],
      ['finance', 3, 'pl', Brightness.light],
      ['messages', 4, 'pl', Brightness.light],
      ['dashboard-dark', 0, 'pl', Brightness.dark],
      ['timetable-dark', 1, 'pl', Brightness.dark],
      ['grades-dark', 2, 'pl', Brightness.dark],
      ['dashboard-en', 0, 'en', Brightness.light],
      ['timetable-en', 1, 'en', Brightness.light],
    ];

    for (final s in shots) {
      final name = s[0] as String;
      final tab = s[1] as int;
      final locale = s[2] as String;
      final brightness = s[3] as Brightness;

      if (state.prefs.locale != locale) {
        await tester.runAsync(() => state.setLocale(locale));
      }
      state.tab = tab;
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: _app(state, brightness)));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.75);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('../screenshots/$name.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });
}
