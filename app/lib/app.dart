import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/shell.dart';
import 'player/accent.dart';

class VinylApp extends ConsumerWidget {
  const VinylApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Il tema intero segue la copertina in ascolto, e ci arriva sfumando:
    // un cambio di colore istantaneo a ogni brano sarebbe fastidioso.
    final accent = ref.watch(accentProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: MaterialApp(
        title: 'Vinyl',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(accent),
        themeAnimationDuration: const Duration(milliseconds: 600),
        themeAnimationCurve: Curves.easeOutCubic,
        home: const Root(),
      ),
    );
  }
}
