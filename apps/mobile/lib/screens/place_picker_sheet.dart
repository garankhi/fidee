import 'package:flutter/material.dart';

import '../models/custom_address_validation.dart';
import '../models/nearby_place.dart';
import '../models/selected_place_tag.dart';

class PlacePickerSheetContent extends StatefulWidget {
  final List<NearbyPlace> places;
  final void Function(SelectedPlaceTag place) onSelected;
  final Future<SelectedPlaceTag?> Function(
    String name,
    String visibility,
    String? address,
  )? onCreateCustomPlace;
  final Future<String?> Function()? onResolveCustomAddress;
  final Future<CustomAddressValidation?> Function(String address)?
      onValidateCustomAddress;
  final bool isLoading;
  final String? errorMessage;

  const PlacePickerSheetContent({
    super.key,
    required this.places,
    required this.onSelected,
    this.onCreateCustomPlace,
    this.onResolveCustomAddress,
    this.onValidateCustomAddress,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  State<PlacePickerSheetContent> createState() =>
      _PlacePickerSheetContentState();
}

class _VisibilityOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _VisibilityOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _PlacePickerSheetContentState._accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : _PlacePickerSheetContentState._mutedText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _PlacePickerSheetContentState._mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacePickerSheetContentState extends State<PlacePickerSheetContent> {
  static const Color _accent = Color(0xFFEF4050);
  static const Color _sheet = Color(0xFF2B2B2B);
  static const Color _mutedText = Color(0xFFB7B7B7);

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customNameController = TextEditingController();
  final TextEditingController _customAddressController = TextEditingController();
  String _searchQuery = '';
  bool _isCreatingCustom = false;
  bool _isSavingCustom = false;
  String _customVisibility = 'FRIENDS';
  String? _customError;
  String? _customWarning;
  bool _addressWarningAcknowledged = false;

  @override
  void dispose() {
    _searchController.dispose();
    _customNameController.dispose();
    _customAddressController.dispose();
    super.dispose();
  }

  List<NearbyPlace> get _filteredPlaces {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return widget.places;

    return widget.places.where((place) {
      return place.displayName.toLowerCase().contains(query) ||
          place.address.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _startCustomPlaceCreation() async {
    setState(() {
      _isCreatingCustom = true;
      _customError = null;
      _customWarning = null;
      _addressWarningAcknowledged = false;
    });

    final resolver = widget.onResolveCustomAddress;
    if (resolver == null || _customAddressController.text.trim().isNotEmpty) {
      return;
    }

    final resolvedAddress = await resolver();
    if (!mounted || resolvedAddress == null || resolvedAddress.trim().isEmpty) {
      return;
    }

    if (_customAddressController.text.trim().isEmpty) {
      _customAddressController.text = resolvedAddress.trim();
    }
  }

  Future<void> _saveCustomPlace() async {
    final name = _customNameController.text.trim();
    if (name.length < 2) {
      setState(() => _customError = 'Tên địa điểm cần ít nhất 2 ký tự');
      return;
    }

    final onCreate = widget.onCreateCustomPlace;
    if (onCreate == null) {
      setState(() => _customError = 'Chưa thể tạo địa điểm lúc này');
      return;
    }

    final address = _customAddressController.text.trim();
    final validator = widget.onValidateCustomAddress;
    if (validator != null && address.isNotEmpty && !_addressWarningAcknowledged) {
      final validation = await validator(address);
      if (!mounted) return;
      if (validation?.isFarFromCurrentLocation == true) {
        final distance = validation?.distanceMeters;
        setState(() {
          _customWarning = distance == null
              ? 'Địa chỉ này có vẻ cách xa vị trí hiện tại. Nhấn Lưu lần nữa nếu vẫn muốn dùng.'
              : 'Địa chỉ này có vẻ cách xa vị trí hiện tại khoảng ${distance}m. Nhấn Lưu lần nữa nếu vẫn muốn dùng.';
          _addressWarningAcknowledged = true;
        });
        return;
      }
    }

    setState(() {
      _isSavingCustom = true;
      _customError = null;
      _customWarning = null;
    });

    final created = await onCreate(
      name,
      _customVisibility,
      address.isEmpty ? null : address,
    );
    if (!mounted) return;

    setState(() => _isSavingCustom = false);
    if (created == null) {
      setState(() => _customError = 'Không tạo được địa điểm, thử lại nhé');
      return;
    }

    widget.onSelected(created);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: const BoxDecoration(
        color: _sheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          if (!_isCreatingCustom) ...[
            const SizedBox(height: 20),
            _buildSearchField(),
          ],
          if (widget.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.errorMessage!,
              style: const TextStyle(color: _accent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 18),
          if (_isCreatingCustom)
            _buildCustomPlaceForm()
          else if (widget.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(color: _accent),
            )
          else if (_filteredPlaces.isEmpty)
            _buildEmptyState()
          else
            Expanded(child: _buildPlaceList()),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF6E6E6E), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const ValueKey('place-search-field'),
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: 'Tìm gần đây...',
                hintStyle: TextStyle(
                  color: Color(0xFF6E6E6E),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceList() {
    final places = _filteredPlaces;

    return ListView.separated(
      itemCount: places.length + 1,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
      itemBuilder: (context, index) {
        if (index == places.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 18),
            child: _buildCustomButton(),
          );
        }

        final place = places[index];
        return Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            leading: _buildCategoryIcon(),
            title: Text(
              place.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              place.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: place.distanceMeters > 0
                ? Text(
                    '${place.distanceMeters}m',
                    style: const TextStyle(
                      color: _mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
            onTap: () => widget.onSelected(SelectedPlaceTag.fromNearby(place)),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const Text(
            'Hmm... Có vẻ là',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'địa điểm này chưa có trên bản đồ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _buildCustomButton(),
        ],
      ),
    );
  }

  Widget _buildCustomButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _startCustomPlaceCreation,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text(
          'Thêm địa điểm tùy chỉnh',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildCustomPlaceForm() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          const Text(
            'Thêm địa điểm tùy chỉnh',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const ValueKey('custom-place-name-field'),
                  controller: _customNameController,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Tên địa điểm',
                    hintStyle: const TextStyle(color: Color(0xFF8D8D8D)),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _accent, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('custom-place-address-field'),
            controller: _customAddressController,
            onChanged: (_) => setState(() {
              _customWarning = null;
              _addressWarningAcknowledged = false;
            }),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Địa chỉ hoặc khu vực',
              hintStyle: const TextStyle(color: Color(0xFF8D8D8D)),
              prefixIcon: const Icon(
                Icons.location_on_rounded,
                color: Color(0xFF8D8D8D),
                size: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildVisibilityToggle(),
          if (_customWarning != null) ...[
            const SizedBox(height: 10),
            Text(
              _customWarning!,
              style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          if (_customError != null) ...[
            const SizedBox(height: 10),
            Text(
              _customError!,
              style: const TextStyle(color: _accent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSavingCustom ? null : _saveCustomPlace,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _accent.withValues(alpha: 0.45),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isSavingCustom
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Lưu',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VisibilityOption(
            label: 'Bạn bè',
            icon: Icons.group_rounded,
            selected: _customVisibility == 'FRIENDS',
            onTap: () => setState(() => _customVisibility = 'FRIENDS'),
          ),
          _VisibilityOption(
            label: 'Riêng tư',
            icon: Icons.lock_rounded,
            selected: _customVisibility == 'PRIVATE',
            onTap: () => setState(() => _customVisibility = 'PRIVATE'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
      child: const Icon(
        Icons.restaurant_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}
