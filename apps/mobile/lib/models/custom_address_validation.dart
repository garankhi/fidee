class CustomAddressValidation {
  final bool isFarFromCurrentLocation;
  final int? distanceMeters;

  const CustomAddressValidation({
    required this.isFarFromCurrentLocation,
    this.distanceMeters,
  });
}
