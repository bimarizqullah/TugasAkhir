import 'package:flutter/material.dart';

// ── Geser horizontal (push = kiri, pop = kanan) ──────────
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SlideDirection direction;

  SlidePageRoute({
    required this.page,
    this.direction = SlideDirection.left,
  }) : super(
          transitionDuration  : const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, secondaryAnimation, child) {
            final begin = direction == SlideDirection.left
                ? const Offset(1.0, 0.0)
                : const Offset(-1.0, 0.0);

            const end   = Offset.zero;
            const curve = Curves.easeOutCubic;

            final tween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: curve));

            final offsetAnimation = animation.drive(tween);

            // Secondary animation — halaman lama geser sedikit ke kiri
            final secondaryTween = Tween(
              begin: Offset.zero,
              end  : direction == SlideDirection.left
                  ? const Offset(-0.25, 0.0)
                  : const Offset(0.25, 0.0),
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: offsetAnimation,
              child: SlideTransition(
                position: secondaryAnimation.drive(secondaryTween),
                child   : child,
              ),
            );
          },
        );
}

enum SlideDirection { left, right }

// ── Fade + Scale — untuk fullscreen dialog (Reservasi) ───
class FadeScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeScalePageRoute({required this.page})
      : super(
          fullscreenDialog         : true,
          transitionDuration       : const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, __, child) {
            const curve = Curves.easeOutCubic;

            final fadeTween = Tween<double>(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: curve));

            final scaleTween = Tween<double>(begin: 0.92, end: 1.0)
                .chain(CurveTween(curve: curve));

            return FadeTransition(
              opacity: animation.drive(fadeTween),
              child  : ScaleTransition(
                scale: animation.drive(scaleTween),
                child: child,
              ),
            );
          },
        );
}

// ── Slide dari bawah — untuk modal/bottom sheet screen ───
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideUpPageRoute({required this.page})
      : super(
          fullscreenDialog         : true,
          transitionDuration       : const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, __, child) {
            const curve = Curves.easeOutCubic;

            final tween = Tween(
              begin: const Offset(0.0, 1.0),
              end  : Offset.zero,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child   : child,
            );
          },
        );
}