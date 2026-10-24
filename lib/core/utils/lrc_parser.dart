class LrcLine {
  final Duration timestamp;
  final String text;

  const LrcLine({
    required this.timestamp,
    required this.text,
  });

  @override
  String toString() => '[${timestamp.inMilliseconds}ms] $text';
}

/// Robust parser for standard RFC/community synchronized .lrc lyrics.
class LrcParser {
  static final _lineRegex =
      RegExp(r'^((?:\[\d{1,3}:\d{2}(?:\.\d{1,3})?\])+)(.*)$');
  static final _tagRegex = RegExp(r'\[(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?\]');

  /// Parses raw LRC text into a chronologically sorted list of [LrcLine].
  static List<LrcLine> parse(String? lrcContent) {
    if (lrcContent == null || lrcContent.trim().isEmpty) {
      return const [];
    }

    final lines = <LrcLine>[];
    final rawLines = lrcContent.split(RegExp(r'\r?\n'));

    for (final line in rawLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final match = _lineRegex.firstMatch(trimmed);
      if (match == null) continue;

      final tagsPart = match.group(1)!;
      final textPart = match.group(2)?.trim() ?? '';

      final tagMatches = _tagRegex.allMatches(tagsPart);
      for (final tm in tagMatches) {
        final min = int.tryParse(tm.group(1) ?? '0') ?? 0;
        final sec = int.tryParse(tm.group(2) ?? '0') ?? 0;
        final msStr = tm.group(3) ?? '0';
        int ms = int.tryParse(msStr) ?? 0;
        if (msStr.length == 2) {
          ms *= 10;
        } else if (msStr.length == 1) {
          ms *= 100;
        }

        final duration = Duration(
          minutes: min,
          seconds: sec,
          milliseconds: ms,
        );

        lines.add(LrcLine(timestamp: duration, text: textPart));
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  /// Finds the index of the currently active line for [position].
  /// Returns -1 if [lines] is empty or [position] is before the first line.
  static int findActiveIndex(List<LrcLine> lines, Duration position) {
    if (lines.isEmpty) return -1;
    return lines.lastIndexWhere((line) => line.timestamp <= position);
  }
}
