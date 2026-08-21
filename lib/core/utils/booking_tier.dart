/// D4 drops tier selection for new bookings. Historical PRO/ELITE rows remain
/// immutable and must explain why their recorded price differs from base price.
String? historicalBookingTierLabel(Map booking) {
  final raw = (booking['selectedTier'] ?? booking['selected_tier'])
      ?.toString()
      .trim();
  if (raw == null || raw.isEmpty || raw.toLowerCase() == 'standard') {
    return null;
  }
  final normalized = raw
      .toLowerCase()
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
  return '$normalized tier · historical recorded price';
}
