import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ios.dart';
import '../data/settings.dart';
import 'home/home_page.dart';
import 'library/library_page.dart';
import 'player/bottom_chrome.dart';
import 'search/search_page.dart';
import 'settings/settings_page.dart';

/// Le tre schede, il mini player e la barra in basso.
///
/// Ogni scheda ha il proprio Navigator: aprendo un album da "Cerca" e poi
/// tornando su "Home", la ricerca è ancora dove l'avevi lasciata.
class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  int _index = 0;

  final _navigatorKeys = List.generate(3, (_) => GlobalKey<NavigatorState>());

  void _onTap(int index) {
    if (index == _index) {
      // Ritoccare la scheda attiva riporta alla sua radice, come su iOS.
      _navigatorKeys[index].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _index = index);
  }

  Widget _tab(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) =>
          MaterialPageRoute(builder: (_) => child, settings: settings),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = _navigatorKeys[_index].currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        } else if (_index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        backgroundColor: IOS.background,
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: [
            _tab(0, const HomePage()),
            _tab(1, const SearchPage()),
            _tab(2, const LibraryPage()),
          ],
        ),
        bottomNavigationBar:
            BottomChrome(currentIndex: _index, onTap: _onTap),
      ),
    );
  }
}

/// Decide cosa mostrare all'avvio: la configurazione se non sappiamo ancora
/// dove sia il server, altrimenti l'app.
class Root extends ConsumerWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final loaded = ref.watch(settingsProvider.notifier).loaded;

    if (!loaded && !settings.isConfigured) {
      return const Scaffold(
        backgroundColor: IOS.background,
        body: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!settings.isConfigured) {
      return const SettingsPage(isFirstRun: true);
    }

    return const Shell();
  }
}
