import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Envuelve la pantalla que normalmente abre la aplicación.
class TaggyEntrada extends StatefulWidget {
  const TaggyEntrada({super.key, required this.destino});
  final Widget destino;

  @override
  State<TaggyEntrada> createState() => _TaggyEntradaState();
}

class _TaggyEntradaState extends State<TaggyEntrada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tiempo =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2560),
      )..addStatusListener((estado) {
        if (estado == AnimationStatus.completed && mounted) {
          setState(() => _terminada = true);
          _atlas?.dispose();
          _atlas = null;
        }
      });
  ui.Image? _atlas;
  bool _terminada = false;
  bool _iniciada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _terminada = true;
      _tiempo.stop();
      _atlas?.dispose();
      _atlas = null;
    } else if (!_terminada && !_iniciada) {
      _iniciada = true;
      _cargar();
    }
  }

  Future<void> _cargar() async {
    try {
      final data = await rootBundle.load('assets/taggy/entrada.png');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      late final ui.FrameInfo frame;
      try {
        frame = await codec.getNextFrame();
      } finally {
        codec.dispose();
      }
      if (!mounted || _terminada) {
        frame.image.dispose();
        return;
      }
      setState(() => _atlas = frame.image);
      _tiempo.forward();
    } catch (error) {
      debugPrint('TAGGY: no se pudo cargar la entrada ($error)');
      if (mounted) setState(() => _terminada = true);
    }
  }

  @override
  void dispose() {
    _tiempo.dispose();
    _atlas?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_terminada) return widget.destino;
    return ColoredBox(
      color: const Color(0xff0a1624),
      child: Center(
        child: LayoutBuilder(
          builder: (context, box) {
            final lado = math.min(
              360.0,
              math.min(box.maxWidth * 0.89, box.maxHeight),
            );
            return Semantics(
              label: 'TAGGY',
              image: true,
              child: CustomPaint(
                size: Size.square(lado),
                painter: _Fotograma(_atlas, _tiempo),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Fotograma extends CustomPainter {
  _Fotograma(this.atlas, this.tiempo) : super(repaint: tiempo);
  final ui.Image? atlas;
  final Animation<double> tiempo;

  @override
  void paint(Canvas canvas, Size size) {
    final imagen = atlas;
    if (imagen == null) return;
    final indice = math.min(63, (tiempo.value * 64).floor());
    final origen = Rect.fromLTWH(
      (indice % 8) * 320.0,
      (indice ~/ 8) * 320.0,
      320,
      320,
    );
    canvas.drawImageRect(
      imagen,
      origen,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_Fotograma oldDelegate) =>
      atlas != oldDelegate.atlas || tiempo != oldDelegate.tiempo;
}
