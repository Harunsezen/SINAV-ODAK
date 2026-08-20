import 'dart:async';

import 'package:flutter/material.dart';

/// Tek dokunuşta **adım**, basılı tutunca **akan** artırma/azaltma düğmesi.
///
/// ## Neden iki davranış
///
/// Stepper küçük düzeltme için hızlı, uzak değer için işkence. Klavye
/// girişi uzak değer için hızlı ama "biraz artır" için fazla iş. Üçüncü
/// yol basılı tutmak: parmağını bırakmadan istediğin sayıya akıyorsun.
///
/// ```
/// tek dokunuş        → ±[step]        (varsayılan 5)
/// basılı tut         → ±[holdStep]    (varsayılan 1), hızlanarak
/// ```
///
/// ## Zamanlama
///
/// | An | Olan |
/// | --- | --- |
/// | 0 ms | parmak indi, henüz bir şey olmadı |
/// | [holdDelay] (500 ms) | akış başlar, ilk ±1 |
/// | sonra | her adımda aralık [decay] ile kısalır |
/// | [minInterval] (40 ms) | en hızlı; daha fazla hızlanmaz |
/// | bırakınca | anında durur |
///
/// **Neden gecikme var:** gecikme olmadan her dokunuş hem ±5 hem akış
/// başlatırdı; kullanıcı "bir kere bastım, üç arttı" derdi.
///
/// **Neden en hızlıda sınır var:** sınırsız hızlanma parmağı kaldırma
/// süresinde 100 birim atlatıyor ve değer kontrol edilemez hâle geliyor.
class HoldRepeatButton extends StatefulWidget {
  const HoldRepeatButton({
    required this.icon,
    required this.onStep,
    required this.enabled,
    this.step = 5,
    this.holdStep = 1,
    this.holdDelay = const Duration(milliseconds: 500),
    this.firstInterval = const Duration(milliseconds: 180),
    this.minInterval = const Duration(milliseconds: 40),
    this.decay = 0.85,
    super.key,
  });

  final IconData icon;

  /// Kaç birim değişeceğini alır. Tek dokunuşta [step], akışta [holdStep].
  final ValueChanged<int> onStep;

  /// Sınıra dayanınca `false` — düğme pasifleşiyor ve akış durdurulmuyor
  /// bile başlatılmıyor.
  final bool enabled;

  final int step;
  final int holdStep;
  final Duration holdDelay;
  final Duration firstInterval;
  final Duration minInterval;

  /// Her tekrarda aralığın çarpanı (<1 = hızlanma).
  final double decay;

  @override
  State<HoldRepeatButton> createState() => _HoldRepeatButtonState();
}

class _HoldRepeatButtonState extends State<HoldRepeatButton> {
  Timer? _delay;
  Timer? _repeat;
  Duration _interval = Duration.zero;

  /// Akış başladıysa, parmak kalkınca tek-dokunuş adımı UYGULANMAZ.
  bool _flowed = false;

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _cancel() {
    _delay?.cancel();
    _repeat?.cancel();
    _delay = null;
    _repeat = null;
  }

  void _down() {
    if (!widget.enabled) return;
    _flowed = false;
    _interval = widget.firstInterval;
    _delay = Timer(widget.holdDelay, _startFlow);
  }

  void _startFlow() {
    _flowed = true;
    widget.onStep(widget.holdStep);
    _scheduleNext();
  }

  void _scheduleNext() {
    _repeat = Timer(_interval, () {
      if (!mounted || !widget.enabled) {
        _cancel();
        return;
      }
      widget.onStep(widget.holdStep);
      // Hızlan, ama tabanın altına inme.
      final next = (_interval.inMicroseconds * widget.decay).round();
      _interval = Duration(
        microseconds: next < widget.minInterval.inMicroseconds
            ? widget.minInterval.inMicroseconds
            : next,
      );
      _scheduleNext();
    });
  }

  void _up() {
    final wasFlow = _flowed;
    _cancel();
    if (!wasFlow && widget.enabled) {
      // Akış hiç başlamadı → bu bir TEK DOKUNUŞ.
      widget.onStep(widget.step);
    }
    _flowed = false;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).disabledColor;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: GestureDetector(
        onTapDown: (_) => _down(),
        onTapUp: (_) => _up(),
        onTapCancel: _cancel,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // Dokunma hedefi 48x48'in altına inmesin.
          padding: const EdgeInsets.all(12),
          child: Icon(widget.icon, color: color, size: 24),
        ),
      ),
    );
  }
}
