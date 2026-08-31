import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';

/// Caricamento, errore e contenuto in un posto solo, cosi' ogni schermata
/// gestisce gli imprevisti allo stesso modo invece di reinventarli.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.sliver = false,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  /// Dentro una CustomScrollView il contenuto deve essere uno sliver.
  final bool sliver;

  Widget _wrap(Widget child) =>
      sliver ? SliverFillRemaining(hasScrollBody: false, child: child) : child;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => _wrap(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          ),
        ),
      ),
      error: (error, _) => _wrap(ErrorPanel(message: '$error', onRetry: onRetry)),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: Vinyl.textDim),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Vinyl.textDim, height: 1.4),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Vinyl.text,
                  side: const BorderSide(color: Vinyl.strokeStrong),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Riprova'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.library_music_rounded,
                size: 38, color: Vinyl.textDim.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Vinyl.textDim, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Titolo di sezione, usato in tutte le schermate per dare lo stesso ritmo.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Vinyl.gutter, 26, Vinyl.gutter, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleLarge),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
