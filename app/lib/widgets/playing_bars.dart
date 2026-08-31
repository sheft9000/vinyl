import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Le barrette che ballano accanto al brano in riproduzione.
/// Si fermano in pausa: e' il modo piu' immediato per far capire lo stato
/// senza aggiungere una scritta.
class PlayingBars extends StatefulWidget {
  const PlayingBars({
    super.key,
    required this.color,
    this.playing = true,
    this.size = 14,
  });

  final Color color;
  final bool playing;
  final double size;

  @override
  State<PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant PlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.playing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              // Fasi sfalsate: senza questo le tre barre salterebbero insieme.
              final phase = _controller.value * 2 * math.pi + i * 2.1;
              final t = widget.playing ? (math.sin(phase) + 1) / 2 : 0.35;
              return Container(
                width: widget.size * 0.22,
                height: widget.size * (0.28 + 0.72 * t),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(widget.size * 0.11),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
