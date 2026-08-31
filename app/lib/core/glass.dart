import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Il vetro di iOS: sfocatura di cio' che sta sotto, una velatura scura sopra
/// e un bordo di un pixel che ne definisce l'orlo. Senza il bordo la superficie
/// sembra sporcizia sullo schermo invece che un pannello.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.blur = 24,
    this.tint = 0.62,
    this.borderRadius,
    this.border,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double blur;
  final double tint;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B10).withValues(alpha: tint),
            borderRadius: radius,
            border: border,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Alone di colore dietro al contenuto, preso dalla copertina in ascolto.
/// E' quello che fa sembrare l'interfaccia illuminata da dentro.
class AccentWash extends StatelessWidget {
  const AccentWash({
    super.key,
    required this.color,
    required this.child,
    this.strength = 0.30,
    this.height = 420,
  });

  final Color color;
  final Widget child;
  final double strength;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: height,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: strength),
                  color.withValues(alpha: strength * 0.35),
                  Vinyl.bg.withValues(alpha: 0),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
