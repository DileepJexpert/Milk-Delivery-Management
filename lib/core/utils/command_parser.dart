/// Tiny keyword-based parser that converts a free-text command (typed by the
/// milkman or transcribed from voice) into an actionable intent.
///
/// Examples it recognises:
///   "skip A-102"                  → Skip(target: "A-102", date: today)
///   "pause Sharma"                → Skip(target: "Sharma", date: today)
///   "skip Verma tomorrow"         → Skip(target: "Verma", date: tomorrow)
///   "extra 1L for Sharma"         → ExtraOrder(target, qty=1)
///   "2L tomorrow A-101"           → ExtraOrder(target=A-101, qty=2, tomorrow)
///
/// The parser is deliberately permissive and language-mixed (English / Hindi
/// keywords). It returns null for unrecognised input so the caller can fall
/// back to a "didn't understand" message.
class CommandParser {
  static const _skipKeywords = ['skip', 'pause', 'रोक', 'छोड़', 'nahi'];
  static const _extraKeywords = ['extra', 'अतिरिक्त', 'और', 'aur', 'one time', 'one-time'];
  static const _tomorrowKeywords = ['tomorrow', 'कल', 'kal'];

  static ParsedCommand? parse(String input) {
    final lower = input.trim().toLowerCase();
    if (lower.isEmpty) return null;

    final isTomorrow = _tomorrowKeywords.any(lower.contains);
    final dateOffset = isTomorrow ? 1 : 0;

    // Quantity (e.g. "2L", "1.5 l", "500g")
    double? qty;
    final qtyMatch =
        RegExp(r'(\d+(?:\.\d+)?)\s*l\b').firstMatch(lower);
    if (qtyMatch != null) {
      qty = double.tryParse(qtyMatch.group(1)!);
    }

    if (_extraKeywords.any(lower.contains)) {
      final target = _extractTarget(input, [
        ..._extraKeywords,
        ..._tomorrowKeywords,
        'for',
        'के लिए',
      ]);
      if (target == null) return null;
      return ParsedCommand(
        intent: CommandIntent.extraOrder,
        target: target,
        quantity: qty,
        dateOffset: dateOffset,
        raw: input,
      );
    }

    if (_skipKeywords.any(lower.contains)) {
      final target = _extractTarget(input, [
        ..._skipKeywords,
        ..._tomorrowKeywords,
      ]);
      if (target == null) return null;
      return ParsedCommand(
        intent: CommandIntent.skip,
        target: target,
        dateOffset: dateOffset,
        raw: input,
      );
    }

    return null;
  }

  /// Strips out keywords and quantity tokens to leave just the customer
  /// identifier (name or flat number).
  static String? _extractTarget(String input, List<String> noiseWords) {
    var s = input;
    for (final w in noiseWords) {
      s = s.replaceAll(RegExp(w, caseSensitive: false), ' ');
    }
    s = s.replaceAll(RegExp(r'\d+(?:\.\d+)?\s*l\b', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.isEmpty ? null : s;
  }
}

enum CommandIntent { skip, extraOrder }

class ParsedCommand {
  ParsedCommand({
    required this.intent,
    required this.target,
    required this.dateOffset,
    required this.raw,
    this.quantity,
  });

  final CommandIntent intent;

  /// Free-text identifier — needs to be fuzzy-matched against flat numbers
  /// + owner names by the caller.
  final String target;
  final double? quantity;

  /// 0 = today, 1 = tomorrow.
  final int dateOffset;
  final String raw;
}
