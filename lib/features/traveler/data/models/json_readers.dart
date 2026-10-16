/// Lenient readers for optional JSON fields: a missing or wrongly typed value
/// is null.
library;

int? readInt(Object? value) => value is num ? value.toInt() : null;

double? readDouble(Object? value) => value is num ? value.toDouble() : null;

bool? readBool(Object? value) => value is bool ? value : null;

String? readString(Object? value) => value is String ? value : null;
