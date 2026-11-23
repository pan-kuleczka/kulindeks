import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'state/cache.dart';
import 'state/notifications.dart';
import 'state/session_store.dart';
import 'state/settings.dart';
import 'ui/home_screen.dart';
import 'ui/login_screen.dart';
import 'ui/util.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cache = await JsonCache.open();
  final state = AppState(SessionStore(), cache, SettingsStore(), NotificationService());
  await state.bootstrap();
  runApp(MStudentApp(state));
}

ThemeData _theme(Color seed, Brightness b, bool highContrast) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: b,
      contrastLevel: highContrast ? 1.0 : 0.0,
    ),
    useMaterial3: true,
  );
}

class MStudentApp extends StatelessWidget {
  final AppState state;
  const MStudentApp(this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: Consumer<AppState>(
        builder: (context, s, _) {
          final seed = hexColor(s.prefs.accentColor);
          final hc = s.prefs.theme == AppThemeMode.highContrast;
          final mode = switch (s.prefs.theme) {
            AppThemeMode.light => ThemeMode.light,
            AppThemeMode.dark => ThemeMode.dark,
            _ => ThemeMode.system,
          };
          return MaterialApp(
            title: 'Kulindeks',
            debugShowCheckedModeBanner: false,
            theme: _theme(seed, Brightness.light, hc),
            darkTheme: _theme(seed, Brightness.dark, hc),
            themeMode: mode,
            locale: Locale(s.prefs.locale),
            supportedLocales: const [Locale('pl'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery.withClampedTextScaling(
              minScaleFactor: s.prefs.fontScale,
              maxScaleFactor: s.prefs.fontScale,
              child: child!,
            ),
            home: switch (s.status) {
              AuthStatus.unknown =>
                const Scaffold(body: Center(child: CircularProgressIndicator())),
              AuthStatus.loggedOut => const LoginScreen(),
              AuthStatus.loggedIn => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}
