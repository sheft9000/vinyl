import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Le due direzioni estetiche in prova.
///
/// Temporaneo: quando avrai scelto, resta solo quella e questo file sparisce
/// insieme al selettore in cima alla Home.
enum Skin {
  /// L'app Musica di Apple: titoli grandi che collassano, liste raggruppate
  /// con separatori rientrati, tab bar sottile e traslucida.
  appleMusic('Apple Music'),

  /// Vetro stratificato in stile iOS 26: i controlli galleggiano sopra il
  /// contenuto invece di stare dentro barre piene.
  liquidGlass('Liquid Glass');

  const Skin(this.label);
  final String label;
}

class SkinNotifier extends StateNotifier<Skin> {
  SkinNotifier() : super(Skin.appleMusic) {
    _load();
  }

  static const _key = 'design_skin';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      state = Skin.values.firstWhere(
        (s) => s.name == saved,
        orElse: () => Skin.appleMusic,
      );
    }
  }

  Future<void> set(Skin skin) async {
    state = skin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, skin.name);
  }
}

final skinProvider =
    StateNotifierProvider<SkinNotifier, Skin>((ref) => SkinNotifier());
