enum Environment {
  development,
  staging,
  production;

  static Environment fromValue(String value) {
    return Environment.values.firstWhere(
      (environment) => environment.name == value.toLowerCase(),
      orElse: () => Environment.development,
    );
  }
}
