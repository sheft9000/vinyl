import 'package:flutter/material.dart';

/// Spinge una pagina dentro la scheda corrente: la barra in basso e il
/// mini player restano al loro posto, come ci si aspetta su iOS.
Future<T?> pushPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

/// Spinge una pagina sopra tutto, barra inclusa: serve solo al player a
/// schermo intero, che sale dal basso.
Future<T?> pushFullScreen<T>(BuildContext context, Widget page) =>
    Navigator.of(context, rootNavigator: true).push<T>(
      PageRouteBuilder<T>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
