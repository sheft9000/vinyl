import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';

/// Indirizzo del server e token. E' anche la schermata che vedi al primo
/// avvio, quando l'app non sa ancora a chi parlare.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.isFirstRun = false});

  final bool isFirstRun;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _url;
  late final TextEditingController _token;

  bool _testing = false;
  String? _message;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _url = TextEditingController(text: settings.baseUrl);
    _token = TextEditingController(text: settings.token);
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    setState(() {
      _testing = true;
      _message = null;
    });

    await ref.read(settingsProvider.notifier).save(
          baseUrl: _url.text,
          token: _token.text,
        );

    try {
      final stats = await ref.read(apiClientProvider).testConnection();
      if (!mounted) return;
      setState(() {
        _ok = true;
        _message = 'Connesso: ${stats.tracks} brani, ${stats.albums} album, '
            '${formatTotal(Duration(milliseconds: stats.totalDurationMs))} '
            'di musica.';
      });
      _invalidateEverything();
      if (widget.isFirstRun && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.of(context).maybePop();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _ok = false;
        _message = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ok = false;
        _message = '$e';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _invalidateEverything() {
    ref.invalidate(statsProvider);
    ref.invalidate(recentAlbumsProvider);
    ref.invalidate(recentTracksProvider);
    ref.invalidate(allAlbumsProvider);
    ref.invalidate(allArtistsProvider);
    ref.invalidate(genresProvider);
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsProvider);

    return Scaffold(
      backgroundColor: Vinyl.bg,
      appBar: AppBar(
        title: Text(widget.isFirstRun ? 'Collega il server' : 'Impostazioni'),
        automaticallyImplyLeading: !widget.isFirstRun,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            Vinyl.gutter, 8, Vinyl.gutter, 160),
        children: [
          if (widget.isFirstRun) ...[
            Text(
              'Vinyl riproduce la libreria che sta sul tuo computer. '
              'Serve l\'indirizzo del server e il token che hai scritto nel '
              'file .env.',
              style: TextStyle(
                color: Vinyl.textDim,
                height: 1.45,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
          ],
          const _Label('Indirizzo del server'),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(
              hintText: '192.168.1.10:8080',
              prefixIcon: Icon(Icons.dns_outlined, color: Vinyl.textDim),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Senza porta viene usata la 8080. Su rete locale basta l\'IP '
            'del computer che fa girare il server.',
            style: TextStyle(fontSize: 12, color: Vinyl.textDim, height: 1.4),
          ),
          const SizedBox(height: 22),
          const _Label('Token'),
          TextField(
            controller: _token,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'API_TOKEN',
              prefixIcon: Icon(Icons.key_outlined, color: Vinyl.textDim),
            ),
          ),
          const SizedBox(height: 26),
          FilledButton(
            onPressed: _testing ? null : _saveAndTest,
            child: _testing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Salva e verifica'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 18),
            _Banner(message: _message!, ok: _ok),
          ],
          if (!widget.isFirstRun) ...[
            const SizedBox(height: 34),
            const _Label('Libreria'),
            stats.when(
              data: (LibraryStats s) => _StatsCard(stats: s),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (e, _) => Text(
                '$e',
                style: const TextStyle(color: Vinyl.textDim, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: Vinyl.textDim,
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.ok});

  final String message;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF3ECF8E) : const Color(0xFFFF7A7A);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final LibraryStats stats;

  @override
  Widget build(BuildContext context) {
    final rows = {
      'Artisti': '${stats.artists}',
      'Album': '${stats.albums}',
      'Brani': '${stats.tracks}',
      'Durata totale':
          formatTotal(Duration(milliseconds: stats.totalDurationMs)),
    };

    return Container(
      decoration: BoxDecoration(
        color: Vinyl.surface,
        borderRadius: BorderRadius.circular(Vinyl.radiusCard),
        border: Border.all(color: Vinyl.stroke),
      ),
      child: Column(
        children: [
          for (final entry in rows.entries)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Text(entry.key,
                      style: const TextStyle(
                          color: Vinyl.textDim, fontSize: 14)),
                  const Spacer(),
                  Text(entry.value,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
