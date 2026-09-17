import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/quote.dart';
import '../services/quote_service.dart';

/// Rotating Burda fact, swapped every few seconds with a cross fade.
class QuoteDisplay extends StatefulWidget {
  const QuoteDisplay({super.key});

  static const Duration interval = Duration(seconds: 7);

  @override
  State<QuoteDisplay> createState() => _QuoteDisplayState();
}

class _QuoteDisplayState extends State<QuoteDisplay> {
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
    super.dispose();
  }

  Future<void> _loadQuotes() async {
    final quotes = await QuoteService.load();
    if (!mounted) return;
    setState(() {
      _quotes = quotes;
      _current = quotes.isEmpty ? null : quotes[_random.nextInt(quotes.length)];
    });
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: Text(
        _current == null ? '' : '"${_current!.content}"',
        key: ValueKey(_current?.content),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontSize: 15.5,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}
