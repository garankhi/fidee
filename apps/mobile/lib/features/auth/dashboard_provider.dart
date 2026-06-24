import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../config.dart';
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
  final List<String> categories;
  final List<String> priceRanges;
  final List<String> disRanges;
  final List<String> sortOptions;
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
    this.categories = const <String>[],
    this.priceRanges = const <String>[],
    this.disRanges = const <String>[],
    this.sortOptions = const <String>[],
    this.nextCursor,
    this.hasMore = false,
    this.isSearching = false,
    this.isLoadingMore = false,
  });

  bool get isSearchMode =>
      searchQuery.trim().isNotEmpty ||
      selectedVibe != null ||
      categories.isNotEmpty ||
      priceRanges.isNotEmpty ||
      disRanges.isNotEmpty ||
      sortOptions.isNotEmpty;

  DashboardState copyWith({
    List<DashboardPlace>? hotPlaces,
    List<DashboardPlace>? recommendedPlaces,
    List<DashboardPlace>? friendActivities,
    List<Map<String, dynamic>>? vibes,
    List<DashboardPlace>? searchResults,
    String? searchQuery,
    Object? selectedVibe = _unset,
    List<String>? categories,
    List<String>? priceRanges,
    List<String>? disRanges,
    List<String>? sortOptions,
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
      categories: categories ?? this.categories,
      priceRanges: priceRanges ?? this.priceRanges,
      disRanges: disRanges ?? this.disRanges,
      sortOptions: sortOptions ?? this.sortOptions,
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
    List<String> categories = const <String>[],
    List<String> priceRanges = const <String>[],
    List<String> disRanges = const <String>[],
    List<String> sortOptions = const <String>[],
  }) async {
    state = state.copyWith(
      categories: List<String>.unmodifiable(categories),
      priceRanges: List<String>.unmodifiable(priceRanges),
      disRanges: List<String>.unmodifiable(disRanges),
      sortOptions: List<String>.unmodifiable(sortOptions),
    );
    await search();
  }

  void clearSearch() {
    _searchRevision++;
    state = state.copyWith(
      searchQuery: '',
      selectedVibe: null,
      categories: const <String>[],
      priceRanges: const <String>[],
      disRanges: const <String>[],
      sortOptions: const <String>[],
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
      categories: state.categories,
      priceRanges: state.priceRanges,
      disRanges: state.disRanges,
      sortOptions: state.sortOptions,
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
    return '${Config.apiBaseUrl}/media/$mediaId';
  }
}
