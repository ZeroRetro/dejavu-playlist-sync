class DurationFormatter {
  static String formatMs(int milliseconds) {
    if (milliseconds <= 0) return '00:00';
    final duration = Duration(milliseconds: milliseconds);
    return formatDuration(duration);
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final minStr = minutes.toString().padLeft(2, '0');
    final secStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minStr:$secStr';
    }
    return '$minStr:$secStr';
  }

  /// Formats duration in human-readable terms for playlist headers (e.g. "1 hr 14 min", "45 min", "32 sec")
  static String formatHumanMs(int milliseconds) {
    if (milliseconds <= 0) return '';
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return minutes > 0 ? '$hours hr $minutes min' : '$hours hr';
    }
    if (minutes > 0) {
      return '$minutes min';
    }
    return '$seconds sec';
  }
}
