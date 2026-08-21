/// Canonical provider trust predicate shared by discovery, matching, badges,
/// map eligibility, and checkout gating.
///
/// The companion web client must implement the same three-factor predicate.
/// A row is trusted only when the provider is approved, the background check is
/// verified, and the server supplied a usable completion timestamp.
library;

import '../generated/contracts.dart';

Map<dynamic, dynamic>? _asMap(Object? value) => value is Map ? value : null;

Object? _first(Iterable<Object?> values) {
  for (final value in values) {
    if (value != null && value.toString().trim().isNotEmpty) return value;
  }
  return null;
}

/// Accepts either a provider row or a program/service row containing a nested
/// `providerId`/`provider`. Snake-case and normalized camel-case keys are both
/// supported at this repository boundary.
bool providerTrusted(Map<dynamic, dynamic> row) {
  final provider = _asMap(row['providerId']) ?? _asMap(row['provider']);
  final status = _first([
    provider?['status'],
    provider?['providerStatus'],
    provider?['provider_status'],
    row['providerStatus'],
    row['provider_status'],
    // A provider profile itself has `status`; a program's `status` means
    // published/draft and must not be confused with provider approval.
    if (provider == null) row['status'],
  ])?.toString().trim().toLowerCase();
  final backgroundStatus = _first([
    provider?['backgroundCheckStatus'],
    provider?['background_check_status'],
    row['backgroundCheckStatus'],
    row['background_check_status'],
  ])?.toString().trim().toLowerCase();
  final completedAt = _first([
    provider?['backgroundCheckCompletedAt'],
    provider?['background_check_completed_at'],
    row['backgroundCheckCompletedAt'],
    row['background_check_completed_at'],
  ]);

  return status == kContractApprovedProviderStatus &&
      backgroundStatus == kContractVerifiedBackgroundStatus &&
      completedAt != null &&
      DateTime.tryParse(completedAt.toString()) != null;
}

/// Honest provider-owned status copy for dashboards and onboarding surfaces.
String providerTrustStatus(Map<dynamic, dynamic> row) {
  if (providerTrusted(row)) return 'Background check verified';
  final provider = _asMap(row['providerId']) ?? _asMap(row['provider']) ?? row;
  final completedAt =
      provider['backgroundCheckCompletedAt'] ??
      provider['background_check_completed_at'];
  final background =
      (provider['backgroundCheckStatus'] ??
              provider['background_check_status'] ??
              'pending')
          .toString()
          .toLowerCase();
  if (background == kContractVerifiedBackgroundStatus && completedAt == null) {
    return 'Background check pending completion';
  }
  if (background == 'rejected' || background == 'failed') {
    return 'Background check needs attention';
  }
  return 'Background check pending';
}
