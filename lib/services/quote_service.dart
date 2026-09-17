import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/quote.dart';

/// Loads the bundled Burda facts once per run.
abstract final class QuoteService {
  static List<Quote>? _cache;

  static Future<List<Quote>> load() async {
    if (_cache case final cached?) return cached;
    final raw = await rootBundle.loadString('assets/quotes.json');
    final quotes = (jsonDecode(raw) as List)
        .map((entry) => Quote.fromJson(entry as Map<String, dynamic>))
        .toList();
    return _cache = quotes;
  }
}
