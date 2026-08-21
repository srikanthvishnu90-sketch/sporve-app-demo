import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sporve_app/core/generated/contracts.dart';

void main() {
  test('generated Dart policy matches the machine-readable contract', () {
    final contract =
        jsonDecode(File('contracts/product_contracts.json').readAsStringSync())
            as Map<String, dynamic>;
    final fees = contract['fees'] as Map<String, dynamic>;
    final plans = contract['plans'] as Map<String, dynamic>;

    expect(fees['sporveBookingFeeBps'], kContractSporveBookingFeeBps);
    expect(
      fees['sporveOffPlatformInvoiceFeeBps'],
      kContractSporveOffPlatformInvoiceFeeBps,
    );
    expect(
      (plans['pro'] as Map)['monthlyPriceUsd'],
      kContractProMonthlyPriceUsd,
    );
    expect(
      (plans['enterprise'] as Map)['monthlyPriceUsd'],
      kContractEnterpriseMonthlyPriceUsd,
    );
    expect(
      (contract['bookingStatuses'] as List).toSet(),
      kContractBookingStatuses,
    );
    expect(
      (contract['paymentStatuses'] as List).toSet(),
      kContractPaymentStatuses,
    );
  });
}
