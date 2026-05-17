import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:reservation_app/widgets/main_shell.dart';
import 'utils/responsive_helper.dart';
import 'screens/mobile/login_screen.dart';
import 'screens/web/login_web_screen.dart';
import 'services/websocket_service.dart';
import 'utils/page_transitions.dart';
import 'config/app_config.dart';
import 'utils/storage.dart'; // 🔥 IMPORT

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Error loading .env file: $e");
  }

  // 🔥 Init storage cache SEBELUM runApp — agar hasSession() sinkron tersedia
  await Storage.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor         : Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WebSocketService.disconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      WebSocketService.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title                     : 'Reservasi Billiard Etan Patung',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme  : ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3 : true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _SlideTransitionBuilder(),
            TargetPlatform.iOS    : _SlideTransitionBuilder(),
          },
        ),
      ),
      // 🔥 FIX: AuthGate cek token dulu — tidak langsung ke /login
      // Storage.init() sudah dipanggil di main() sehingga hasSession() sinkron
      home: const _AuthGate(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(
              builder: (context) => ResponsiveHelper.isWeb(context)
                  ? const LoginWebScreen()
                  : const LoginScreen(),
            );
          case '/home':
            return MaterialPageRoute(
              builder: (_) => const MainShell(),
            );
          default:
            return MaterialPageRoute(
              builder: (context) => ResponsiveHelper.isWeb(context)
                  ? const LoginWebScreen()
                  : const LoginScreen(),
            );
        }
      },
    );
  }
}

// ── Auth Gate — cek token, arahkan ke home atau login ──────────────
// Dipanggil saat startup & refresh. Storage.init() sudah memuat token
// ke cache, sehingga hasSession() langsung tersedia tanpa async.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    if (Storage.hasSession()) {
      return const MainShell();
    }
    return ResponsiveHelper.isWeb(context)
        ? const LoginWebScreen()
        : const LoginScreen();
  }
}

// ── Slide transition builder ──
class _SlideTransitionBuilder extends PageTransitionsBuilder {
  const _SlideTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const curve = Curves.easeOutCubic;

    final tween = Tween(
      begin: const Offset(1.0, 0.0),
      end  : Offset.zero,
    ).chain(CurveTween(curve: curve));

    final secondaryTween = Tween(
      begin: Offset.zero,
      end  : const Offset(-0.25, 0.0),
    ).chain(CurveTween(curve: curve));

    return SlideTransition(
      position: animation.drive(tween),
      child   : SlideTransition(
        position: secondaryAnimation.drive(secondaryTween),
        child   : child,
      ),
    );
  }
}