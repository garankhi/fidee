class Suggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;

  const Suggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });
}

class SuggestionCoordinates {
  final double lat;
  final double lng;

  const SuggestionCoordinates({required this.lat, required this.lng});
}
