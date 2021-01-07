String twoDigitString(duration, {includeMilliseconds: false}) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String twoDigitHours = twoDigits(duration.inHours.floor());
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  String twoDigitMilliseconds = twoDigits((duration.inMilliseconds.remainder(1000)/10).floor());
  List<String> result = [];
  if (duration.inHours.floor() > 0)
    result.add(twoDigitHours);
  result.add(twoDigitMinutes);
  result.add(twoDigitSeconds);
  if (includeMilliseconds)
    result.add(twoDigitMilliseconds);
  return result.join(":");
}

Duration minDuration(a, b) {
  return a < b ? a : b;
}

Duration maxDuration(a, b) {
  return a > b ? a : b;
}

double durationRatio(a, b) {
  return (a.inMicroseconds / b.inMicroseconds);
}

Duration divideDuration(a, b) {
  return Duration(microseconds: (a.inMicroseconds ~/ b));
}


Duration parseDuration(String s) {
  int hours = 0;
  int minutes = 0;
  int micros;
  List<String> parts = s.split(':');
  if (parts.length > 2) {
    hours = int.parse(parts[parts.length - 3]);
  }
  if (parts.length > 1) {
    minutes = int.parse(parts[parts.length - 2]);
  }
  micros = (double.parse(parts[parts.length - 1]) * 1000000).round();
  return Duration(hours: hours, minutes: minutes, microseconds: micros);
}

