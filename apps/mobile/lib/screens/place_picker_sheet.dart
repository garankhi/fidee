import 'package:flutter/material.dart';

import '../models/nearby_place.dart';
import '../models/selected_place_tag.dart';

class PlacePickerSheetContent extends StatefulWidget {
  final List<NearbyPlace> places;
  final void Function(SelectedPlaceTag place) onSelected;
  final Future<SelectedPlaceTag?> Function(String name)? onCreateCustomPlace;
  final bool isLoading;
  final String? errorMessage;

  const PlacePickerSheetContent({
    super.key,
    required this.places,
    required this.onSelected,
    this.onCreateCustomPlace,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  State<PlacePickerSheetContent> createState() =>
      _PlacePickerSheetContentState();
}

class _PlacePickerSheetContentState extends State<PlacePickerSheetContent> {
  static const Color _accent = Color(0xFFEF4050);
  static const Color _sheet = Color(0xFF2B2B2B);
  static const Color _mutedText = Color(0xFFB7B7B7);

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customNameController = TextEditingController();
  String _searchQuery = '';
  bool _isCreatingCustom = false;
  bool _isSavingCustom = false;
  String? _customError;

  @override
  void dispose() {
    _searchController.dispose();
    _customNameController.dispose();
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

    setState(() {
      _isSavingCustom = true;
      _customError = null;
    });

    final created = await onCreate(name);
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
          const SizedBox(height: 20),
          _buildSearchField(),
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
        onPressed: () => setState(() => _isCreatingCustom = true),
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
          const SizedBox(height: 8),
          const Text(
            'Được tạo bởi Bạn',
            style: TextStyle(
              color: _mutedText,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
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
