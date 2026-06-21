import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/billing_provider.dart';
import '../services/billing_sync_service.dart';

const _sheetBackground = Color(0xFF252020);
const _primaryRed = Color(0xFFEF484F);
const _softSurface = Color(0x33FFFFFF);

Future<bool?> showProPlanPickerSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ProPlanPickerSheet(),
  );
}

class ProPlanPickerSheet extends ConsumerStatefulWidget {
  const ProPlanPickerSheet({super.key});

  @override
  ConsumerState<ProPlanPickerSheet> createState() => _ProPlanPickerSheetState();
}

class _ProPlanPickerSheetState extends ConsumerState<ProPlanPickerSheet> {
  String _selectedProductId = Config.revenueCatMonthlyProductId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final state = ref.read(billingControllerProvider);
      if (state.offerings == null) {
        ref.read(billingControllerProvider.notifier).loadOfferings();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final billingState = ref.watch(billingControllerProvider);
    final packages = billingState.proPackages;
    final monthly = _findPackage(packages, Config.revenueCatMonthlyProductId);
    final yearly = _findPackage(packages, Config.revenueCatYearlyProductId);
    final selectedPackage = _findPackage(packages, _selectedProductId);
    final isBusy = billingState.isPurchasing || billingState.isRestoring;

    return ProPlanPickerShell(
      monthlyPrice: monthly?.storeProduct.priceString ?? '49.000đ/tháng',
      yearlyPrice: yearly?.storeProduct.priceString ?? '399.000đ/năm',
      selectedProductId: _selectedProductId,
      isLoading: billingState.isLoading && packages.isEmpty,
      isBusy: isBusy,
      errorMessage: billingState.errorMessage,
      hasPackages: packages.isNotEmpty,
      onSelect: (productId) => setState(() => _selectedProductId = productId),
      onContinue: selectedPackage == null || isBusy
          ? null
          : () => _purchaseSelected(selectedPackage),
      onRestore: isBusy ? null : _restore,
    );
  }

  Package? _findPackage(List<Package> packages, String productId) {
    for (final package in packages) {
      if (package.storeProduct.identifier == productId) return package;
    }
    return null;
  }

  Future<void> _purchaseSelected(Package package) async {
    final authService = ref.read(authServiceProvider);
    final appUserId = await authService.getCurrentUserSub();
    final customerInfo = await ref
        .read(billingControllerProvider.notifier)
        .purchasePackage(
          package,
          appUserId: appUserId,
          billingSyncService: BillingSyncService(authService: authService),
        );
    if (!mounted) return;

    final hasPro =
        customerInfo?.entitlements.active.containsKey(
          Config.revenueCatEntitlementPro,
        ) ??
        false;
    if (hasPro) {
      await _refreshProfileAndClose();
    }
  }

  Future<void> _restore() async {
    final authService = ref.read(authServiceProvider);
    final appUserId = await authService.getCurrentUserSub();
    final customerInfo = await ref
        .read(billingControllerProvider.notifier)
        .restorePurchases(
          appUserId: appUserId,
          billingSyncService: BillingSyncService(authService: authService),
        );
    if (!mounted) return;

    final hasPro =
        customerInfo?.entitlements.active.containsKey(
          Config.revenueCatEntitlementPro,
        ) ??
        false;
    if (hasPro) {
      await _refreshProfileAndClose();
    }
  }

  Future<void> _refreshProfileAndClose() async {
    await ref.read(authControllerProvider.notifier).refreshProfileDetails();
    if (!mounted) return;
    Navigator.pop(context, true);
  }
}

class ProPlanPickerPreview extends StatelessWidget {
  final String monthlyPrice;
  final String yearlyPrice;

  const ProPlanPickerPreview({
    super.key,
    required this.monthlyPrice,
    required this.yearlyPrice,
  });

  @override
  Widget build(BuildContext context) {
    return ProPlanPickerShell(
      monthlyPrice: monthlyPrice,
      yearlyPrice: yearlyPrice,
      selectedProductId: Config.revenueCatMonthlyProductId,
      isLoading: false,
      isBusy: false,
      hasPackages: true,
      onSelect: (_) {},
      onContinue: () {},
      onRestore: () {},
    );
  }
}

class ProPlanPickerShell extends StatelessWidget {
  final String monthlyPrice;
  final String yearlyPrice;
  final String selectedProductId;
  final bool isLoading;
  final bool isBusy;
  final bool hasPackages;
  final String? errorMessage;
  final ValueChanged<String> onSelect;
  final VoidCallback? onContinue;
  final VoidCallback? onRestore;

  const ProPlanPickerShell({
    super.key,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.selectedProductId,
    required this.isLoading,
    required this.isBusy,
    required this.hasPackages,
    required this.onSelect,
    required this.onContinue,
    required this.onRestore,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: _sheetBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Chọn gói FIDEE Pro',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '50 lượt AI mỗi ngày, video check-in 3 giây và upload từ thư viện.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.74),
                fontSize: 14,
                fontFamily: 'SF Pro',
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 22),
            if (isLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: CircularProgressIndicator(color: _primaryRed),
                ),
              ),
            ] else ...[
              _PlanOption(
                title: 'Hằng tháng',
                price: monthlyPrice,
                isSelected:
                    selectedProductId == Config.revenueCatMonthlyProductId,
                onTap: () => onSelect(Config.revenueCatMonthlyProductId),
              ),
              const SizedBox(height: 12),
              _PlanOption(
                title: 'Hằng năm',
                price: yearlyPrice,
                isSelected:
                    selectedProductId == Config.revenueCatYearlyProductId,
                onTap: () => onSelect(Config.revenueCatYearlyProductId),
              ),
            ],
            if (!isLoading && !hasPackages) ...[
              const SizedBox(height: 14),
              const Text(
                'Chưa tải được gói Pro. Vui lòng thử lại sau.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFA3A8),
                  fontSize: 13,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: _primaryRed,
                disabledBackgroundColor: _primaryRed.withValues(alpha: 0.45),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Tiếp tục',
                      style: TextStyle(
                        fontSize: 17,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRestore,
              child: const Text(
                'Khôi phục giao dịch',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanOption extends StatelessWidget {
  final String title;
  final String price;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanOption({
    required this.title,
    required this.price,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x33EF484F) : _softSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? _primaryRed
                : Colors.white.withValues(alpha: 0.1),
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? _primaryRed : Colors.white70,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              price,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 16,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
