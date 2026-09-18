import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/quote.dart';
import '../services/quote_service.dart';

/// Rotating Burda fact. Each change lands with a short chromatic glitch, the
/// way the original swapped its quotes.
class QuoteDisplay extends StatefulWidget {
  const QuoteDisplay({super.key});

  static const Duration interval = Duration(seconds: 7);
  static const Duration glitchDuration = Duration(milliseconds: 450);

  @override
  State<QuoteDisplay> createState() => _QuoteDisplayState();
}

class _QuoteDisplayState extends State<QuoteDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glitch = AnimationController(
    duration: QuoteDisplay.glitchDuration,
    vsync: this,
  );

  final Random _random = Random();
  List<Quote> _quotes = const [];
  Quote? _current;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glitch.dispose();
    super.dispose();
  }

  Future<void> _loadQuotes() async {
    final quotes = await QuoteService.load();
    if (!mounted) return;
    setState(() {
      _quotes = quotes;
      _current = quotes.isEmpty ? null : quotes[_random.nextInt(quotes.length)];
    });
    _glitch.forward(from: 0);
    if (quotes.length > 1) {
      _timer = Timer.periodic(QuoteDisplay.interval, (_) => _rotate());
    }
  }

  void _rotate() {
    if (!mounted || _quotes.length < 2) return;
    Quote next;
    do {
      next = _quotes[_random.nextInt(_quotes.length)];
    } while (next.content == _current?.content);
    setState(() => _current = next);
    _glitch.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge?.copyWith(
      fontSize: 15.5,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w600,
      height: 1.35,
    );
    final text = _current == null ? '' : '"${_current!.content}"';

    return AnimatedBuilder(
      animation: _glitch,
      builder: (context, child) {
        // Strong offsets at the start, settling to nothing.
        final strength = 1 - Curves.easeOutCubic.transform(_glitch.value);
        final shake = sin(_glitch.value * pi * 6) * 7 * strength;

        return Stack(
          alignment: Alignment.center,
          children: [
            if (strength > 0.02) ...[
              _layer(text, style, Offset(-shake, 0), const Color(0xFFFF3B3B)),
              _layer(text, style, Offset(shake, 0), const Color(0xFF00E5FF)),
            ],
            Opacity(
              opacity: (1 - strength * 0.35).clamp(0.0, 1.0),
              child: Text(text, textAlign: TextAlign.center, style: style),
            ),
          ],
        );
      },
    );
  }

  Widget _layer(String text, TextStyle? style, Offset offset, Color color) {
    return Transform.translate(
      offset: offset,
      child: Opacity(
        opacity: 0.45,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: style?.copyWith(color: color),
        ),
      ),
    );
  }
}
