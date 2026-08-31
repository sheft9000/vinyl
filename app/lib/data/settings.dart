import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Indirizzo del server e token. Sono le uniche due cose che l'app deve sapere
/// per esistere: tenerle qui, e non nel codice, e' cio' che permettera' di
/// passare dall'IP di casa a un indirizzo pubblico senza ricompilare nulla.
class ServerSettings {
  const ServerSettings({this.baseUrl = '', this.token = ''});

  final String baseUrl;
  final String token;

  bool get isConfigured => baseUrl.isNotEmpty && token.isNotEmpty;

  /// Tollera cio' che scriverai davvero nel campo: "192.168.1.10",
  /// "192.168.1.10:8080/", "http://casa.example.com".
  String get normalizedBaseUrl {
    var url = baseUrl.trim();
    if (url.isEmpty) return '';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    url = url.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(url);
    if (uri != null && !uri.hasPort && uri.path.isEmpty) url = '$url:8080';
    return url;
  }

  ServerSettings copyWith({String? baseUrl, String? token}) => ServerSettings(
        baseUrl: baseUrl ?? this.baseUrl,
        token: token ?? this.token,
      );
}

class SettingsNotifier extends StateNotifier<ServerSettings> {
  SettingsNotifier() : super(const ServerSettings()) {
    _load();
  }

  static const _kBaseUrl = 'server_base_url';
  static const _kToken = 'server_token';

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ServerSettings(
      baseUrl: prefs.getString(_kBaseUrl) ?? '',
      token: prefs.getString(_kToken) ?? '',
    );
    _loaded = true;
  }

  Future<void> save({required String baseUrl, required String token}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, baseUrl.trim());
    await prefs.setString(_kToken, token.trim());
    state = ServerSettings(baseUrl: baseUrl.trim(), token: token.trim());
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, ServerSettings>(
  (ref) => SettingsNotifier(),
);
