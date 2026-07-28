import 'package:fidey_mobile/models/pro_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('confirmed plan and sync status remain independent', () {
    const state = ProAccessState(
      confirmedPlan: ConfirmedProPlan.pro,
      syncStatus: BillingSyncStatus.failed,
    );

    expect(state.confirmedPlan, ConfirmedProPlan.pro);
    expect(state.syncStatus, BillingSyncStatus.failed);
  });
}
