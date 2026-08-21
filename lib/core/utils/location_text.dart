/// Builds one honest, non-duplicated location label from repository data.
///
/// Supabase and historical rows may provide either a structured address or a
/// preformatted string. A structured `line1` sometimes already contains the
/// city/state; those components must not be appended a second time.
String locationText(
  Object? address, {
  Object? fallback,
  String unavailable = 'Location TBD',
}) {
  String clean(Object? value) => value?.toString().trim() ?? '';
  String normalized(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  if (address is Map) {
    final line1 = clean(address['line1'] ?? address['addressLine1']);
    final city = clean(address['city']);
    final state = clean(address['state']);
    final parts = <String>[];

    void addIfMissing(String value) {
      if (value.isEmpty) return;
      final candidate = normalized(value);
      final represented = parts.any((part) {
        final existing = normalized(part);
        final existingTokens = existing.split(' ').where((token) {
          return token.isNotEmpty;
        }).toSet();
        final candidateTokens = candidate.split(' ').where((token) {
          return token.isNotEmpty;
        });
        return existing == candidate ||
            (candidateTokens.isNotEmpty &&
                candidateTokens.every(existingTokens.contains));
      });
      if (!represented) parts.add(value);
    }

    addIfMissing(line1);
    addIfMissing(city);
    addIfMissing(state);
    if (parts.isNotEmpty) return parts.join(', ');
  } else {
    final value = clean(address);
    if (value.isNotEmpty) return value;
  }

  final fallbackValue = clean(fallback);
  return fallbackValue.isEmpty ? unavailable : fallbackValue;
}
