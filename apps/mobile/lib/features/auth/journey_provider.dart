import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/journey_entry.dart';
import '../../services/journey_service.dart';
import 'auth_providers.dart';

enum JourneyPeriod { all, week, month }

class JourneyState {
  final Map<JourneyEntryType, List<JourneyEntry>> entries;
  final Map<JourneyEntryType, String?> nextCursors;
  final Map<JourneyEntryType, bool> hasMore;
  final Set<JourneyEntryType> loadedTypes;
  final JourneyEntryType selectedType;
  final JourneyPeriod period;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  const JourneyState({
    this.entries = const <JourneyEntryType, List<JourneyEntry>>{
      JourneyEntryType.checkin: <JourneyEntry>[],
      JourneyEntryType.review: <JourneyEntry>[],
    },
    this.nextCursors = const <JourneyEntryType, String?>{
      JourneyEntryType.checkin: null,
      JourneyEntryType.review: null,
    },
    this.hasMore = const <JourneyEntryType, bool>{
      JourneyEntryType.checkin: true,
      JourneyEntryType.review: true,
    },
    this.loadedTypes = const <JourneyEntryType>{},
    this.selectedType = JourneyEntryType.checkin,
    this.period = JourneyPeriod.all,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  List<JourneyEntry> get selectedEntries =>
      entries[selectedType] ?? const <JourneyEntry>[];

  bool get selectedHasMore => hasMore[selectedType] ?? false;

  List<JourneyEntry> get visibleEntries {
    final now = DateTime.now();
    return selectedEntries.where((entry) {
      final created = entry.createdDate;
      if (created == null || period == JourneyPeriod.all) return true;
      final cutoff = switch (period) {
        JourneyPeriod.week => now.subtract(const Duration(days: 7)),
        JourneyPeriod.month => now.subtract(const Duration(days: 30)),
        JourneyPeriod.all => now,
      };
      return created.isAfter(cutoff);
    }).toList(growable: false);
  }

  JourneyState copyWith({
    Map<JourneyEntryType, List<JourneyEntry>>? entries,
    Map<JourneyEntryType, String?>? nextCursors,
    Map<JourneyEntryType, bool>? hasMore,
    Set<JourneyEntryType>? loadedTypes,
    JourneyEntryType? selectedType,
    JourneyPeriod? period,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return JourneyState(
      entries: entries ?? this.entries,
      nextCursors: nextCursors ?? this.nextCursors,
      hasMore: hasMore ?? this.hasMore,
      loadedTypes: loadedTypes ?? this.loadedTypes,
      selectedType: selectedType ?? this.selectedType,
      period: period ?? this.period,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final journeyServiceProvider = Provider<JourneyService>((ref) {
  return JourneyService(ref.watch(authServiceProvider));
});

final journeyControllerProvider =
    AutoDisposeNotifierProvider<JourneyController, JourneyState>(
      JourneyController.new,
    );

class JourneyController extends AutoDisposeNotifier<JourneyState> {
  late JourneyService _service;

  @override
  JourneyState build() {
    _service = ref.watch(journeyServiceProvider);
    Future.microtask(() => refresh());
    return const JourneyState();
  }

  Future<void> refresh() => _load(reset: true);

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.selectedHasMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    await _load(reset: false);
  }

  Future<void> selectType(JourneyEntryType type) async {
    if (state.selectedType == type) return;
    final shouldLoad = !state.loadedTypes.contains(type);
    state = state.copyWith(
      selectedType: type,
      isLoading: shouldLoad,
      isLoadingMore: false,
      clearErrorMessage: true,
    );
    if (shouldLoad) {
      await _load(reset: true);
    }
  }

  void selectPeriod(JourneyPeriod period) {
    state = state.copyWith(period: period);
  }

  Future<void> _load({required bool reset}) async {
    final requestedType = state.selectedType;
    if (reset) {
      state = state.copyWith(isLoading: true, clearErrorMessage: true);
    }

    try {
      final page = await _fetchPage(
        requestedType,
        cursor: reset ? null : state.nextCursors[requestedType],
      );
      final nextEntries = Map<JourneyEntryType, List<JourneyEntry>>.from(
        state.entries,
      );
      nextEntries[requestedType] = reset
          ? page.entries
          : <JourneyEntry>[
              ...(state.entries[requestedType] ?? const <JourneyEntry>[]),
              ...page.entries,
            ];

      state = state.copyWith(
        entries: nextEntries,
        nextCursors: <JourneyEntryType, String?>{
          ...state.nextCursors,
          requestedType: page.nextCursor,
        },
        hasMore: <JourneyEntryType, bool>{
          ...state.hasMore,
          requestedType: page.hasMore,
        },
        loadedTypes: <JourneyEntryType>{
          ...state.loadedTypes,
          requestedType,
        },
        isLoading: false,
        isLoadingMore: false,
        clearErrorMessage: true,
      );
    } on JourneyException catch (error) {
      if (state.selectedType == requestedType) {
        state = state.copyWith(
          errorMessage: error.message,
          isLoading: false,
          isLoadingMore: false,
        );
      }
    }
  }

  Future<JourneyPage> _fetchPage(
    JourneyEntryType type, {
    String? cursor,
  }) {
    return switch (type) {
      JourneyEntryType.checkin => _service.fetchCheckins(cursor: cursor),
      JourneyEntryType.review => _service.fetchReviews(cursor: cursor),
    };
  }
}
