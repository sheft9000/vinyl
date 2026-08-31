import 'dart:ui';

import 'package:flutter/widgets.dart';

/// I valori veri del sistema iOS in modalità scura.
///
/// Non sono colori scelti a occhio: sono quelli che Apple usa nelle sue app.
/// È la ragione principale per cui un'interfaccia "sembra iOS" o non lo sembra.
abstract final class IOS {
  /// Sfondo delle schermate. Su iOS scuro è nero pieno, non grigio scuro:
  /// sugli schermi OLED i pixel si spengono e il contenuto galleggia.
  static const background = Color(0xFF000000);

  /// Superfici sollevate (celle di lista, campi, schede).
  static const surface = Color(0xFF1C1C1E); // systemGray6 dark
  static const surfaceHigh = Color(0xFF2C2C2E); // systemGray5 dark
  static const surfaceHigher = Color(0xFF3A3A3C); // systemGray4 dark

  /// Separatore: 65% di opacità su un grigio bluastro. Quasi invisibile
  /// singolarmente, decisivo quando ce ne sono venti in colonna.
  static const separator = Color(0xA6545458);
  static const separatorOpaque = Color(0xFF38383A);

  static const label = Color(0xFFFFFFFF);
  static const labelSecondary = Color(0x99EBEBF5); // 60%
  static const labelTertiary = Color(0x4DEBEBF5); // 30%
  static const labelQuaternary = Color(0x2EEBEBF5); // 18%

  static const fill = Color(0x5B787880); // systemFill dark
  static const fillSecondary = Color(0x51787880);
  static const fillTertiary = Color(0x3D767680);

  /// Rossi e blu di sistema, per quando serve un colore che non sia l'accento.
  static const red = Color(0xFFFF453A);
  static const blue = Color(0xFF0A84FF);

  /// Raggi di curvatura: iOS usa continuous corners, molto più morbidi dei
  /// raggi circolari. Flutter li approssima bene con valori generosi.
  static const radiusCell = 10.0;
  static const radiusCard = 12.0;
  static const radiusSheet = 14.0;

  /// Margine standard delle schermate iOS.
  static const margin = 16.0;

  /// Altezza della tab bar, esclusa l'area sicura in basso.
  static const tabBarHeight = 49.0;
  static const navBarHeight = 44.0;
}

/// La scala tipografica di iOS, con i nomi che usa Apple.
///
/// I pesi e le spaziature contano quanto i corpi: i titoli grandi di iOS sono
/// bold con crenatura negativa, il corpo è regular a 17, e le didascalie non
/// scendono mai sotto 11.
abstract final class IOSText {
  static const _text = 'Inter';
  static const _display = 'InterDisplay';

  static const largeTitle = TextStyle(
    fontFamily: _display,
    fontSize: 34,
    height: 41 / 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
    color: IOS.label,
  );

  static const title1 = TextStyle(
    fontFamily: _display,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: IOS.label,
  );

  static const title2 = TextStyle(
    fontFamily: _display,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: IOS.label,
  );

  static const title3 = TextStyle(
    fontFamily: _display,
    fontSize: 20,
    height: 25 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: IOS.label,
  );

  static const headline = TextStyle(
    fontFamily: _text,
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: IOS.label,
  );

  static const body = TextStyle(
    fontFamily: _text,
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.4,
    color: IOS.label,
  );

  static const callout = TextStyle(
    fontFamily: _text,
    fontSize: 16,
    height: 21 / 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.3,
    color: IOS.label,
  );

  static const subhead = TextStyle(
    fontFamily: _text,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    color: IOS.label,
  );

  static const footnote = TextStyle(
    fontFamily: _text,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    color: IOS.labelSecondary,
  );

  static const caption1 = TextStyle(
    fontFamily: _text,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    color: IOS.labelSecondary,
  );

  static const caption2 = TextStyle(
    fontFamily: _text,
    fontSize: 11,
    height: 13 / 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.06,
    color: IOS.labelSecondary,
  );

  /// Etichette della tab bar: 10pt medium, la misura esatta di iOS.
  static const tabLabel = TextStyle(
    fontFamily: _text,
    fontSize: 10,
    height: 12 / 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.05,
  );
}

/// Il vetro di iOS non è solo sfocatura: sotto c'è un aumento di saturazione
/// che fa "accendere" i colori che filtrano attraverso. Senza quello sembra
/// vetro smerigliato sporco; con quello sembra iOS.
class IOSBlur extends StatelessWidget {
  const IOSBlur({
    super.key,
    required this.child,
    this.sigma = 30,
    this.tint = const Color(0xC7101014),
    this.saturation = 1.7,
    this.borderRadius,
    this.specular = false,
    this.shadow = false,
  });

  final Widget child;
  final double sigma;
  final Color tint;
  final double saturation;
  final BorderRadius? borderRadius;

  /// Bordo luminoso in alto a sinistra che si spegne in basso a destra, più
  /// una luce interna che scende dal margine superiore. Sono i due dettagli
  /// che distinguono una lastra di vetro da un rettangolo semitrasparente.
  final bool specular;

  /// Ombra propria: serve solo agli elementi che galleggiano staccati dal
  /// bordo dello schermo, per dare loro uno spessore.
  final bool shadow;

  /// Matrice di saturazione: mescola ogni canale con la luminanza percepita.
  static List<double> _saturate(double s) {
    const lumR = 0.2126, lumG = 0.7152, lumB = 0.0722;
    final invR = (1 - s) * lumR;
    final invG = (1 - s) * lumG;
    final invB = (1 - s) * lumB;
    return <double>[
      invR + s, invG, invB, 0, 0, //
      invR, invG + s, invB, 0, 0, //
      invR, invG, invB + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;

    // Due filtri annidati invece di ImageFilter.compose: quest'ultimo viene
    // ignorato in silenzio da Impeller su Android, e il vetro resta trasparente
    // e basta. Annidati funzionano ovunque, al costo di un passaggio in piu'.
    Widget pane = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: BackdropFilter(
          filter: ColorFilter.matrix(_saturate(saturation)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tint,
              borderRadius: radius,
              gradient: specular
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x1FFFFFFF), Color(0x00FFFFFF)],
                      stops: [0, 0.5],
                    )
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );

    if (specular) {
      pane = Stack(
        children: [
          pane,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _SpecularEdge(radius)),
            ),
          ),
        ],
      );
    }

    if (shadow) {
      pane = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x73000000),
              blurRadius: 26,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: pane,
      );
    }

    return pane;
  }
}

/// Il filo di luce sul bordo del vetro: intenso dove la luce arriva,
/// quasi spento sul lato opposto. Un bordo di spessore uniforme fa sembrare
/// il pannello un rettangolo disegnato; questo lo fa sembrare un oggetto.
class _SpecularEdge extends CustomPainter {
  const _SpecularEdge(this.radius);

  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x8CFFFFFF), Color(0x0FFFFFFF), Color(0x38FFFFFF)],
        stops: [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawRRect(radius.toRRect(rect).deflate(0.5), paint);
  }

  @override
  bool shouldRepaint(_SpecularEdge oldDelegate) => oldDelegate.radius != radius;
}

/// Il filo di un pixel che separa le celle di una lista, rientrato a sinistra
/// per allinearsi al testo e non all'icona. È un dettaglio minuscolo che iOS
/// rispetta sempre e che, se manca, si nota senza sapere perché.
class IOSSeparator extends StatelessWidget {
  const IOSSeparator({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(height: 0.5, color: IOS.separator),
    );
  }
}
