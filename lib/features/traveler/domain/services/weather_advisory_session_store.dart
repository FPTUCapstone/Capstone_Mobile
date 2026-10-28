final class WeatherAdvisorySessionStore {
  final Set<String> _dismissedKeys = {};

  bool isDismissed(String advisoryKey) => _dismissedKeys.contains(advisoryKey);

  void dismiss(String advisoryKey) => _dismissedKeys.add(advisoryKey);
}
