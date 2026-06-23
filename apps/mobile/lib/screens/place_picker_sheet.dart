import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/custom_address_validation.dart';
import '../models/nearby_place.dart';
import '../models/selected_place_tag.dart';
import '../models/suggestion.dart';
import '../services/goong_autocomplete_service.dart';

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

  /// Optional seam for injecting a test-controlled service instance.
  /// Production code leaves this null and the state instantiates its own.
  final GoongAutocompleteService? autocompleteService;

  /// Device GPS coordinates passed from the caller (e.g. SendImageScreen).
  /// Used as location bias for autocomplete requests and as the reference
  /// point for Haversine distance validation (Req 2.4, 3.3, 6.1).
  /// When null the widget falls back to the 0.0/0.0 placeholder until the
  /// caller has GPS available, which is always graceful (Req 6.5).
  final double? deviceLat;
  final double? deviceLng;

  const PlacePickerSheetContent({
    super.key,
    required this.places,
    required this.onSelected,
    this.onCreateCustomPlace,
    this.onResolveCustomAddress,
    this.onValidateCustomAddress,
    this.isLoading = false,
    this.errorMessage,
    this.autocompleteService,
    this.deviceLat,
    this.deviceLng,
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

  // --- Autocomplete state ---

  /// Service instance used for all autocomplete and place-detail calls.
  /// Injected via [PlacePickerSheetContent.autocompleteService] in tests;
  /// created lazily on first use in production (no startup provider needed —
  /// this is inline, non-critical-path data per AGENTS.md §6 rule 5).
  late final GoongAutocompleteService _autocompleteService =
      widget.autocompleteService ?? GoongAutocompleteService();

  /// Current list of autocomplete suggestions shown in the overlay.
  List<Suggestion> _suggestions = [];

  /// True while a fetch is in flight; drives the inline loading indicator.
  bool _isLoadingSuggestions = false;

  /// 400 ms debounce timer reset on each keystroke.
  Timer? _debounceTimer;

  /// Coordinates retrieved from Place Detail API after the user picks a
  /// suggestion. Cleared when the user manually edits the address field.
  SuggestionCoordinates? _selectedCoordinates;

  /// Set to true while the address field is being populated programmatically
  /// (suggestion selection or reverse-geocode prefill) so that [_onAddressTextChanged]
  /// can skip API calls for those changes.
  bool _isSelectionPopulating = false;

  /// The overlay entry that floats the suggestion list below the address field.
  OverlayEntry? _suggestionOverlay;

  /// LayerLink that connects the address field ([CompositedTransformTarget])
  /// to the overlay ([CompositedTransformFollower]).
  final LayerLink _layerLink = LayerLink();

  /// The trimmed query string that triggered the most-recently-started fetch.
  /// Used to discard stale in-flight results when a newer query supersedes them.
  String _currentQuery = '';

  /// Device GPS coordinates used as location bias for autocomplete requests.
  /// Initialized from [PlacePickerSheetContent.deviceLat] / [deviceLng] in
  /// [initState]. Falls back to 0.0 placeholders when not provided (Req 6.5).
  double? _deviceLat;
  double? _deviceLng;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    // Wire real GPS coordinates passed from the caller (Req 2.4, 6.1).
    // Null means GPS is unavailable — Haversine validation falls back to
    // onValidateCustomAddress (Req 6.5).
    _deviceLat = widget.deviceLat;
    _deviceLng = widget.deviceLng;
  }

  // ---------------------------------------------------------------------------
  // Autocomplete behavior methods
  // ---------------------------------------------------------------------------

  /// Hides and removes the suggestion overlay (Req 3.4, 3.5).
  ///
  /// Removes the [OverlayEntry] from the [Overlay], nullifies the reference,
  /// and schedules a rebuild so any state that depended on overlay visibility
  /// is updated correctly.
  void _hideSuggestionOverlay() {
    if (_suggestionOverlay == null) return;
    _suggestionOverlay!.remove();
    _suggestionOverlay = null;
    if (mounted) setState(() {});
  }

  /// Shows (or refreshes) the suggestion overlay below the address field.
  ///
  /// - If the overlay is already inserted, calls [OverlayEntry.markNeedsBuild]
  ///   to rebuild in-place (no flicker from remove+insert).
  /// - Otherwise creates and inserts a new [OverlayEntry].
  ///
  /// Layout (Req 3.1, 3.2, 3.3, 8.4):
  /// - [CompositedTransformFollower] anchors 52px below the address field.
  /// - A full-screen transparent [GestureDetector] sits behind the list so
  ///   tapping outside dismisses the overlay (Req 3.5).
  /// - The list container is a dark [Material] with rounded corners.
  /// - While loading: single-line [CircularProgressIndicator] — NOT a
  ///   full-screen spinner (AGENTS.md §5, Req 3.3).
  /// - While not loading: [ListView.builder] capped at 5 items (Req 3.2).
  void _showSuggestionOverlay() {
    if (_suggestionOverlay != null) {
      // Already inserted — just tell it to rebuild with fresh state.
      _suggestionOverlay!.markNeedsBuild();
      return;
    }

    final overlay = Overlay.of(context);

    _suggestionOverlay = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            // Full-screen transparent layer — tap outside dismisses overlay
            // (Req 3.5).
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideSuggestionOverlay,
                child: const SizedBox.expand(),
              ),
            ),
            // Suggestion list anchored below the address field.
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 52),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF2B2B2B),
                  child: _isLoadingSuggestions
                      ? const SizedBox(
                          height: 48,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: _accent,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: min(_suggestions.length, 5),
                          itemBuilder: (_, index) {
                            final suggestion = _suggestions[index];
                            return InkWell(
                              onTap: () => _onSuggestionSelected(suggestion),
                              borderRadius: index == 0
                                  ? const BorderRadius.vertical(
                                      top: Radius.circular(10),
                                    )
                                  : (index == min(_suggestions.length, 5) - 1
                                      ? const BorderRadius.vertical(
                                          bottom: Radius.circular(10),
                                        )
                                      : BorderRadius.zero),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      color: _mutedText,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            suggestion.mainText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            suggestion.secondaryText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: _mutedText,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_suggestionOverlay!);
  }

  /// Called when the user taps a suggestion item.
  ///
  /// Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 6.4:
  /// 1. Suppresses the programmatic text change from triggering autocomplete
  ///    (Req 4.5) by setting [_isSelectionPopulating] = true.
  /// 2. Populates the address field with '{mainText}, {secondaryText}' (Req 4.1).
  /// 3. Closes the suggestion overlay (Req 4.2).
  /// 4. Asynchronously fetches place coordinates via
  ///    [GoongAutocompleteService.fetchPlaceCoordinates] (Req 4.3).
  /// 5. Stores valid coordinates in [_selectedCoordinates] for later
  ///    Haversine validation (Req 4.4).
  /// 6. Null coordinates, non-200 responses, network errors, and timeouts
  ///    are non-blocking — they fall back to [onValidateCustomAddress] on
  ///    save (Req 4.3, 4.4, 6.4).
  Future<void> _onSuggestionSelected(Suggestion suggestion) async {
    // Req 4.5 — suppress the onChanged event that results from setting text
    // programmatically so _onAddressTextChanged skips the debounce/API path.
    _isSelectionPopulating = true;

    // Req 4.1 — populate the address field.
    _customAddressController.text =
        '${suggestion.mainText}, ${suggestion.secondaryText}';

    // Re-enable debounce suppression after the text change event is processed.
    _isSelectionPopulating = false;

    // Req 4.2 — close the overlay immediately.
    _hideSuggestionOverlay();

    // Req 4.3 — asynchronously fetch coordinates for the selected place.
    // Errors and null results are intentionally swallowed (Req 4.3, 6.4).
    try {
      final coords = await _autocompleteService.fetchPlaceCoordinates(
        placeId: suggestion.placeId,
      );

      // Widget-lifecycle guard — do nothing if the widget was disposed while
      // the request was in flight (Req 4.3).
      if (!mounted) return;

      // Req 4.4 — store valid coordinates; null means fall back on save.
      if (coords != null) {
        setState(() {
          _selectedCoordinates = coords;
        });
      }
    } on Object {
      // Non-blocking — any unexpected error falls back to
      // onValidateCustomAddress on save (Req 6.4).
    }
  }

  /// Fetches autocomplete suggestions for [query] via [_autocompleteService].
  ///
  /// Requirements 2.4, 2.5, 3.3, 3.4:
  /// - Tracks the active query with [_currentQuery] to detect stale results.
  /// - Sets loading state and shows the overlay immediately so the user sees
  ///   an inline indicator (not a full-screen spinner — inline is OK per AGENTS.md §5).
  /// - Discards results that arrive after the widget is unmounted or a newer
  ///   query has already been dispatched.
  /// - Hides the overlay on empty results; shows it on non-empty results.
  Future<void> _fetchSuggestions(String query) async {
    // Track which request is active so stale results can be discarded.
    _currentQuery = query;

    // Start inline loading: clear previous suggestions and show the overlay
    // with a loading indicator (Req 3.3).
    setState(() {
      _isLoadingSuggestions = true;
      _suggestions = [];
    });
    _showSuggestionOverlay();

    // Use device coordinates when available; placeholder 0.0 until task 6.1
    // wires real GPS.
    final lat = _deviceLat ?? 0.0;
    final lng = _deviceLng ?? 0.0;

    final results = await _autocompleteService.fetchSuggestions(
      query: query,
      latitude: lat,
      longitude: lng,
    );

    // Stale-result guard (Req 2.4, 2.5): discard if unmounted or superseded.
    if (!mounted || _currentQuery != query) return;

    // Update state with fresh results.
    setState(() {
      _suggestions = results;
      _isLoadingSuggestions = false;
    });

    // Show or hide overlay based on result count (Req 3.4).
    if (results.isEmpty) {
      _hideSuggestionOverlay();
    } else {
      _showSuggestionOverlay();
    }
  }

  /// Called on every text change in the custom-place address field.
  ///
  /// Responsibilities (Requirements 2.1, 2.2, 2.3, 4.5, 5.2, 8.1, 8.2, 8.3):
  /// - Ignore programmatic updates (reverse-geocode prefill, suggestion selection).
  /// - Clear stored coordinates/warning/ack on any manual edit after a
  ///   suggestion was previously selected (Req 5.2).
  /// - Cancel debounce + clear suggestions + hide overlay for short inputs (Req 2.3, 8.3).
  /// - Reset the 400 ms debounce timer and schedule [_fetchSuggestions] (Req 2.1, 2.2).
  void _onAddressTextChanged(String value) {
    // Req 4.5 / 8.1 / 8.2 — programmatic set from selection or reverse-geocode
    // prefill must not trigger an autocomplete call.
    if (_isSelectionPopulating) return;

    // Req 5.2 — any manual edit after a suggestion was selected clears the
    // stored suggestion data so a later save uses free-text validation.
    if (_selectedCoordinates != null ||
        _customWarning != null ||
        _addressWarningAcknowledged) {
      setState(() {
        _selectedCoordinates = null;
        _customWarning = null;
        _addressWarningAcknowledged = false;
      });
    }

    final trimmed = value.trim();

    // Req 2.3 / 8.3 — for very short input, cancel pending work and clear UI.
    if (trimmed.length < 2) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _hideSuggestionOverlay();
      if (_suggestions.isNotEmpty || _isLoadingSuggestions) {
        setState(() {
          _suggestions = [];
          _isLoadingSuggestions = false;
        });
      }
      return;
    }

    // Req 2.1 / 2.2 — reset the 400 ms debounce timer on every keystroke.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 400),
      () => _fetchSuggestions(trimmed),
    );
  }

  @override
  void dispose() {
    // Cancel any pending debounce so it cannot fire after the widget is gone.
    _debounceTimer?.cancel();
    _debounceTimer = null;

    // Stale in-flight results are discarded by the mounted/query guard inside
    // _fetchSuggestions, so no explicit cancellation is needed beyond clearing
    // the query tracker so any result that arrives sees a mismatch.
    _currentQuery = '';

    // Remove the overlay if it is still shown (e.g. user dismissed the sheet
    // by swiping while the overlay was open).
    _suggestionOverlay?.remove();
    _suggestionOverlay = null;

    _searchController.dispose();
    _customNameController.dispose();
    _customAddressController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Distance helpers
  // ---------------------------------------------------------------------------

  /// Returns the great-circle distance in whole meters between two geographic
  /// coordinates using the `latlong2` [Distance] class (Haversine formula).
  ///
  /// Deterministic and side-effect-free — suitable for direct use in tests and
  /// in [_saveCustomPlace] for Req 6.1/6.2 coordinate cross-validation.
  int _haversineDistanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Distance()
        .as(LengthUnit.Meter, LatLng(lat1, lng1), LatLng(lat2, lng2))
        .round();
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
      // Req 8.1, 8.2 — set the prefilled address without triggering the
      // debounce or an autocomplete API call.  The flag is read synchronously
      // inside _onAddressTextChanged, so the simple true→set→false sequence
      // is sufficient (no await crosses the boundary).
      _isSelectionPopulating = true;
      _customAddressController.text = resolvedAddress.trim();
      _isSelectionPopulating = false;
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

    // Step 1 — Empty address bypass (Req 5.5): skip all validation and save.
    if (address.isEmpty) {
      setState(() {
        _isSavingCustom = true;
        _customError = null;
        _customWarning = null;
      });
      final created = await onCreate(name, _customVisibility, null);
      if (!mounted) return;
      setState(() => _isSavingCustom = false);
      if (created == null) {
        setState(() => _customError = 'Không tạo được địa điểm, thử lại nhé');
        return;
      }
      widget.onSelected(created);
      return;
    }

    // Step 2 — Selected-coordinate Haversine validation (Req 6.1, 6.2, 6.3, 6.4, 6.5):
    // Only enter this path when all three conditions hold:
    //   • stored suggestion coordinates are available,
    //   • device GPS coordinates are available,
    //   • the user has NOT yet acknowledged a distance warning.
    final coords = _selectedCoordinates;
    final devLat = _deviceLat;
    final devLng = _deviceLng;

    if (coords != null && devLat != null && devLng != null && !_addressWarningAcknowledged) {
      final distance = _haversineDistanceMeters(devLat, devLng, coords.lat, coords.lng);

      if (distance > 500) {
        // Req 6.2 — show warning with whole-meter distance, ask to save again.
        setState(() {
          _customWarning =
              'Địa chỉ này cách vị trí hiện tại khoảng ${distance}m. Nhấn Lưu lần nữa để xác nhận.';
          _addressWarningAcknowledged = true;
        });
        return;
      }

      // Req 6.1 / 6.3 — distance ≤ 500 m: skip onValidateCustomAddress, go to save.
      setState(() {
        _isSavingCustom = true;
        _customError = null;
        _customWarning = null;
      });
      final created = await onCreate(name, _customVisibility, address);
      if (!mounted) return;
      setState(() => _isSavingCustom = false);
      if (created == null) {
        setState(() => _customError = 'Không tạo được địa điểm, thử lại nhé');
        return;
      }
      widget.onSelected(created);
      return;
    }

    // Step 3 — Save-twice acknowledged (Req 6.3): user already saw the Haversine
    // warning and is tapping Lưu a second time → proceed directly to save.
    if (_addressWarningAcknowledged) {
      setState(() {
        _isSavingCustom = true;
        _customError = null;
        _customWarning = null;
      });
      final created = await onCreate(name, _customVisibility, address);
      if (!mounted) return;
      setState(() => _isSavingCustom = false);
      if (created == null) {
        setState(() => _customError = 'Không tạo được địa điểm, thử lại nhé');
        return;
      }
      widget.onSelected(created);
      return;
    }

    // Step 4 — Manual free-text validation fallback (Req 5.3, 5.4):
    // _selectedCoordinates is null OR device GPS is unavailable → use
    // the existing onValidateCustomAddress callback with the same save-twice
    // warning pattern.
    final validator = widget.onValidateCustomAddress;
    if (validator != null) {
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

    // Step 5 — Proceed to save (Req 5.1).
    setState(() {
      _isSavingCustom = true;
      _customError = null;
      _customWarning = null;
    });

    final created = await onCreate(
      name,
      _customVisibility,
      address,
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
          // CompositedTransformTarget anchors the suggestion overlay
          // directly below this address field (Req 8.4).
          CompositedTransformTarget(
            link: _layerLink,
            child: TextField(
              key: const ValueKey('custom-place-address-field'),
              controller: _customAddressController,
              onChanged: _onAddressTextChanged,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Nhập địa chỉ',
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
