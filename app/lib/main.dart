import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Va fatto prima di creare qualunque AudioPlayer: e' cio' che tiene viva la
  // riproduzione a schermo spento e popola i comandi della schermata di blocco.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.gab83126.vinyl.audio',
    androidNotificationChannelName: 'Riproduzione',
    androidNotificationOngoing: true,
  );

  runApp(const ProviderScope(child: VinylApp()));
}
