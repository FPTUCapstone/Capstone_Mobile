import 'dart:io';

/// Validates whether [value] is a valid API base URL.
///
/// A valid API base URL must:
/// - Be non-empty and contain no whitespace characters
/// - Successfully parse as a URI
/// - Have an HTTP or HTTPS scheme
/// - Have a non-empty host (rejecting scheme-only URLs like `https://`,
///   query-only authorities like `https://?query`, and fragment-only authorities
///   like `https://#fragment`).
bool isValidApiBaseUrl(String value) {
  if (value.trim().isEmpty || value.contains(RegExp(r'\s'))) {
    return false;
  }
  final uri = Uri.tryParse(value);
  if (uri == null) {
    return false;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return false;
  }
  if (uri.host.isEmpty) {
    return false;
  }
  return true;
}

/// Runs the CLI validation logic with injectable sinks for testing.
int runValidateApiBaseUrl(
  List<String> args, {
  StringSink? out,
  StringSink? err,
}) {
  final stdoutSink = out ?? stdout;
  final stderrSink = err ?? stderr;

  if (args.isEmpty) {
    stderrSink.writeln(
      'Error: API_BASE_URL argument is missing.\n'
      'Usage: dart run tool/validate_api_base_url.dart <API_BASE_URL>',
    );
    return 1;
  }

  final rawUrl = args[0];
  if (!isValidApiBaseUrl(rawUrl)) {
    stderrSink.writeln(
      'Error: API_BASE_URL must be a valid HTTP or HTTPS URL with a non-empty host.\n'
      'The provided value does not satisfy these requirements.',
    );
    return 1;
  }

  stdoutSink.writeln('API_BASE_URL is valid.');
  return 0;
}

void main(List<String> args) {
  final exitCode = runValidateApiBaseUrl(args);
  if (exitCode != 0) {
    exit(exitCode);
  }
}
