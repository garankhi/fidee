import 'auth_service.dart';

class ProfileDetails {
  const ProfileDetails({
    this.firstName,
    this.lastName,
    this.preferredUsername,
    this.avatarUrl,
    this.bio,
    this.since,
    required this.tier,
  });

  final String? firstName;
  final String? lastName;
  final String? preferredUsername;
  final String? avatarUrl;
  final String? bio;
  final String? since;
  final UserTier tier;

  factory ProfileDetails.fromJson(Map<String, dynamic> json) {
    final displayName = (json['displayName'] as String?)?.trim();
    final nameParts = displayName == null || displayName.isEmpty
        ? const <String>[]
        : displayName.split(RegExp(r'\s+'));

    final createdAt = json['createdAt'] as String?;
    String? since;
    if (createdAt != null && createdAt.trim().isNotEmpty) {
      since = DateTime.tryParse(createdAt)?.year.toString();
    }

    return ProfileDetails(
      firstName: nameParts.isEmpty ? null : nameParts.first,
      lastName: nameParts.length > 1 ? nameParts.skip(1).join(' ') : null,
      preferredUsername: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      tier: json['plan'] == 'PRO' ? UserTier.pro : UserTier.free,
      since: since,
    );
  }
}
