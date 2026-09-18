/// Utility to parse and normalize group invitation QR payloads and codes.
///
/// Supported formats:
/// 1. Deep link: `tripmate://groups/join?code=<8-char alphanumeric>`
/// 2. Direct code: `<8-char alphanumeric>`
final class QrInvitationParser {
  const QrInvitationParser._();

  static final _codeRegex = RegExp(r'^[A-Za-z0-9]{8}$');

  /// Parses a raw [input] from a QR scan or text entry.
  ///
  /// Returns an 8-character uppercase normalized invitation code, or `null` if invalid.
  static String? parse(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Direct 8-character code check
    if (_codeRegex.hasMatch(trimmed)) {
      return trimmed.toUpperCase();
    }

    // URI check
    try {
      final uri = Uri.parse(trimmed);
      if (uri.scheme == 'tripmate' &&
          uri.host == 'groups' &&
          uri.path == '/join') {
        final code = uri.queryParameters['code'];
        if (code != null && _codeRegex.hasMatch(code.trim())) {
          return code.trim().toUpperCase();
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
