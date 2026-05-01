import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reservation_app/widgets/main_shell.dart';
import 'screens/login_screen.dart';
import 'services/websocket_service.dart';
import 'utils/page_transitions.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor        : Colors.transparent,
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
      title                     : 'Billiard Booking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme  : ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3 : true,
        // Animasi default untuk semua Navigator.pushNamed
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _SlideTransitionBuilder(),
            TargetPlatform.iOS    : _SlideTransitionBuilder(),
          },
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home' : (context) => const MainShell(),
      },
    );
  }
}

// Builder untuk route bernama (/login → /home)
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