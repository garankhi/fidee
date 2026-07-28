enum ConfirmedProPlan { free, pro }

enum BillingSyncStatus { idle, reconciling, failed }

enum BillingActivationStatus { none, pending, failed }

enum BillingPurchaseOutcome { purchased, alreadyOwned, cancelled, failed }

class BillingSyncResult {
  final ConfirmedProPlan plan;
  final String entitlement;
  final DateTime reconciledAt;

  const BillingSyncResult({
    required this.plan,
    required this.entitlement,
    required this.reconciledAt,
  });

  factory BillingSyncResult.fromJson(Map<String, dynamic> json) {
    final rawPlan = json['plan'];
    final entitlement = json['entitlement'];
    final reconciledAt = json['reconciledAt'];
    if ((rawPlan != 'FREE' && rawPlan != 'PRO') ||
        (entitlement != 'free' && entitlement != 'pro') ||
        reconciledAt is! String) {
      throw const FormatException(
        'Invalid backend Pro reconciliation response',
      );
    }

    final parsedDate = DateTime.tryParse(reconciledAt);
    if (parsedDate == null) {
      throw const FormatException(
        'Invalid backend Pro reconciliation timestamp',
      );
    }

    return BillingSyncResult(
      plan: rawPlan == 'PRO' ? ConfirmedProPlan.pro : ConfirmedProPlan.free,
      entitlement: entitlement as String,
      reconciledAt: parsedDate,
    );
  }
}

class ProAccessState {
  final ConfirmedProPlan confirmedPlan;
  final BillingSyncStatus syncStatus;
  final String? syncMessage;

  const ProAccessState({
    required this.confirmedPlan,
    required this.syncStatus,
    this.syncMessage,
  });
}
