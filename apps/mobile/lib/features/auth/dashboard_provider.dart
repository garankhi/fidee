import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/dashboard_place.dart';
import '../../services/discovery_feed_service.dart';
import 'auth_providers.dart';

part 'dashboard_provider.g.dart';

const _unset = Object();

class DashboardState {
  final List<DashboardPlace> hotPlaces;
  final List<DashboardPlace> recommendedPlaces;
  final List<DashboardPlace> friendActivities;
  final List<Map<String, dynamic>> vibes;
  final List<DashboardPlace> searchResults;
  final String searchQuery;
  final String? selectedVibe;
  final String? category;
  final int? priceMax;
  final int? radius;
  final String? sortBy;
  final String? nextCursor;
  final bool hasMore;
  final bool isSearching;
  final bool isLoadingMore;

  const DashboardState({
    this.hotPlaces = const <DashboardPlace>[],
    this.recommendedPlaces = const <DashboardPlace>[],
    this.friendActivities = const <DashboardPlace>[],
    this.vibes = const <Map<String, dynamic>>[],
    this.searchResults = const <DashboardPlace>[],
    this.searchQuery = '',
    this.selectedVibe,
    this.category,
    this.priceMax,
    this.radius,
    this.sortBy,
    this.nextCursor,
    this.hasMore = false,
    this.isSearching = false,
    this.isLoadingMore = false,
  });

  bool get isSearchMode =>
      searchQuery.trim().isNotEmpty ||
      selectedVibe != null ||
      category != null ||
      priceMax != null ||
      radius != null ||
      sortBy != null;

  DashboardState copyWith({
    List<DashboardPlace>? hotPlaces,
    List<DashboardPlace>? recommendedPlaces,
    List<DashboardPlace>? friendActivities,
    List<Map<String, dynamic>>? vibes,
    List<DashboardPlace>? searchResults,
    String? searchQuery,
    Object? selectedVibe = _unset,
    Object? category = _unset,
    Object? priceMax = _unset,
    Object? radius = _unset,
    Object? sortBy = _unset,
    Object? nextCursor = _unset,
    bool? hasMore,
    bool? isSearching,
    bool? isLoadingMore,
  }) {
    return DashboardState(
      hotPlaces: hotPlaces ?? this.hotPlaces,
      recommendedPlaces: recommendedPlaces ?? this.recommendedPlaces,
      friendActivities: friendActivities ?? this.friendActivities,
      vibes: vibes ?? this.vibes,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedVibe: identical(selectedVibe, _unset)
          ? this.selectedVibe
          : selectedVibe as String?,
      category: identical(category, _unset)
          ? this.category
          : category as String?,
      priceMax: identical(priceMax, _unset) ? this.priceMax : priceMax as int?,
      radius: identical(radius, _unset) ? this.radius : radius as int?,
      sortBy: identical(sortBy, _unset) ? this.sortBy : sortBy as String?,
      nextCursor: identical(nextCursor, _unset)
          ? this.nextCursor
          : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isSearching: isSearching ?? this.isSearching,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

@riverpod
class DashboardController extends _$DashboardController {
  late DiscoveryFeedService _service;
  int _searchRevision = 0;

  @override
  DashboardState build() {
    _service = DiscoveryFeedService(ref.watch(authServiceProvider));
    Future.microtask(loadDiscoveryFeed);
    return const DashboardState();
  }

  Future<void> loadDiscoveryFeed() async {
    try {
      final location = ref
          .read(locationControllerProvider)
          .valueOrNull
          ?.currentPosition;
      final feed = await _service.fetchFeed(
        lat: location?.latitude ?? 10.7769,
        lng: location?.longitude ?? 106.7009,
      );
      state = state.copyWith(
        hotPlaces: feed.hotPlaces.map(_toDashboardPlace).toList(),
        recommendedPlaces: feed.recommendedPlaces
            .map(_toDashboardPlace)
            .toList(),
        friendActivities: feed.friendsActivity.map(_toDashboardPlace).toList(),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to load discovery feed.',
        name: 'DashboardController',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> search({String? query}) async {
    final revision = ++_searchRevision;
    final nextQuery = query ?? state.searchQuery;
    state = state.copyWith(
      searchQuery: nextQuery,
      isSearching: true,
      isLoadingMore: false,
      nextCursor: null,
      hasMore: false,
    );
    if (!state.isSearchMode) {
      state = state.copyWith(
        searchResults: const <DashboardPlace>[],
        isSearching: false,
      );
      return;
    }

    final page = await _fetchSearchPage();
    if (revision != _searchRevision) return;
    state = state.copyWith(
      searchResults: page.places.map(_toDashboardPlace).toList(),
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      isSearching: false,
    );
  }

  Future<void> selectVibe(String vibeId) async {
    final nextVibe = state.selectedVibe == vibeId ? null : vibeId;
    state = state.copyWith(selectedVibe: nextVibe, searchQuery: '');
    await search();
  }

  Future<void> applyFilters({
    String? category,
    int? priceMax,
    int? radius,
    String? sortBy,
  }) async {
    state = state.copyWith(
      category: category,
      priceMax: priceMax,
      radius: radius,
      sortBy: sortBy,
    );
    await search();
  }

  void clearSearch() {
    _searchRevision++;
    state = state.copyWith(
      searchQuery: '',
      selectedVibe: null,
      category: null,
      priceMax: null,
      radius: null,
      sortBy: null,
      searchResults: const <DashboardPlace>[],
      nextCursor: null,
      hasMore: false,
      isSearching: false,
      isLoadingMore: false,
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.nextCursor == null) {
      return;
    }
    final revision = _searchRevision;
    state = state.copyWith(isLoadingMore: true);
    final page = await _fetchSearchPage(cursor: state.nextCursor);
    if (revision != _searchRevision) return;
    state = state.copyWith(
      searchResults: <DashboardPlace>[
        ...state.searchResults,
        ...page.places.map(_toDashboardPlace),
      ],
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      isLoadingMore: false,
    );
  }

  Future<DiscoverySearchPage> _fetchSearchPage({String? cursor}) async {
    final location = ref
        .read(locationControllerProvider)
        .valueOrNull
        ?.currentPosition;
    return _service.searchPlaces(
      lat: location?.latitude ?? 10.7769,
      lng: location?.longitude ?? 106.7009,
      query: state.searchQuery,
      vibe: state.selectedVibe,
      category: state.category,
      priceMax: state.priceMax,
      radius: state.radius,
      sortBy: state.sortBy,
      cursor: cursor,
    );
  }

  DashboardPlace _toDashboardPlace(DiscoveryPlace place) {
    return DashboardPlace(
      id: place.placeId,
      name: place.name,
      category: place.categoryLabel,
      rating: place.avgRating,
      distanceKm: place.distanceMeters / 1000,
      imageUrl: _buildImageUrl(place.coverMediaId),
      friendsCount: place.friendCheckinCount ?? place.checkinCount,
      priceMin: place.priceMin,
      priceMax: place.priceMax,
      vibes: place.vibes,
      services: place.services,
    );
  }

  String _buildImageUrl(String? mediaId) {
    if (mediaId == null || mediaId.isEmpty) {
      return 'https://images.unsplash.com/photo-1541658016709-82535e94bc69?w=500';
    }
    return 'https://api.fidee.site/media/$mediaId';
  }
}
