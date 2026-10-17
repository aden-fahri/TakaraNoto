import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/zainnoto/logic/dues_status.dart';

void main() {
  test('deriveChargeStatus menurunkan status dari nominal terbayar', () {
    expect(
      deriveChargeStatus(amountDue: 100, paid: 0, waived: false),
      ChargeStatus.unpaid,
    );
    expect(
      deriveChargeStatus(amountDue: 100, paid: 50, waived: false),
      ChargeStatus.partial,
    );
    expect(
      deriveChargeStatus(amountDue: 100, paid: 100, waived: false),
      ChargeStatus.paid,
    );
    expect(
      deriveChargeStatus(amountDue: 100, paid: 120, waived: false),
      ChargeStatus.paid,
    );
    expect(
      deriveChargeStatus(amountDue: 100, paid: 100, waived: true),
      ChargeStatus.waived,
    );
  });
}
