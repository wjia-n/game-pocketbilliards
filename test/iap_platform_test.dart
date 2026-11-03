import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbilliards/services/iap_service.dart';

void main() {
  test('iOS maps to the single Gold Star product', () {
    expect(StoreService.productIdsFor(TargetPlatform.iOS), {'pocketbilliardsstar'});
    expect(StoreService.starId, 'pocketbilliardsstar');
  });
  test('Android maps to coffee + chocolate only', () {
    expect(StoreService.productIdsFor(TargetPlatform.android),
        {'pocketbilliardscoffee', 'pocketbilliardschocolate'});
    expect(StoreService.productIdsFor(TargetPlatform.android),
        isNot(contains('pocketbilliardsstar')));
  });
}
