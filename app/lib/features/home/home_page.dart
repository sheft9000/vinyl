import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/skin.dart';
import 'home_apple.dart';
import 'home_glass.dart';

/// Sceglie la variante da mostrare.
///
/// Deve stare *dentro* la rotta, non fuori: il Navigator di ogni scheda
/// costruisce la propria rotta iniziale una volta sola, quindi cambiare il
/// widget passato allo Shell non avrebbe alcun effetto una volta avviata l'app.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(skinProvider)) {
      Skin.appleMusic => const HomeApple(),
      Skin.liquidGlass => const HomeGlass(),
    };
  }
}
