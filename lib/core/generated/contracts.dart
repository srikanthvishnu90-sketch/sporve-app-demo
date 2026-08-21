/// Generated projection of `contracts/product_contracts.json`.
///
/// Do not edit policy values here without changing the JSON contract and its
/// cross-surface decision record in the same change.
library;

const int kContractSchemaVersion = 1;
const int kContractSporveBookingFeeBps = 0;
const int kContractSporveOffPlatformInvoiceFeeBps = 0;

const double kContractFreeMonthlyPriceUsd = 0;
const int kContractFreeAiMonthlyQuota = 3;
const int kContractFreeSeatLimit = 1;

const double kContractProMonthlyPriceUsd = 34.99;
const int kContractProSeatLimit = 3;

const double kContractEnterpriseMonthlyPriceUsd = 149;

const String kContractApprovedProviderStatus = 'approved';
const String kContractVerifiedBackgroundStatus = 'verified';

const Set<String> kContractBookingStatuses = {
  'pending',
  'confirmed',
  'declined',
  'completed',
  'no_show',
  'cancelled',
};

const Set<String> kContractPaymentStatuses = {
  'unpaid',
  'processing',
  'paid',
  'partially_refunded',
  'refunded',
  'failed',
};
