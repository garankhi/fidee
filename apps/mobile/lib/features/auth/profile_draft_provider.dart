import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_draft_provider.g.dart';

class ProfileDraft {
  final String? firstName;
  final String? lastName;
  final String? gender;
  final DateTime? dob;
  final String? username;

  const ProfileDraft({
    this.firstName,
    this.lastName,
    this.gender,
    this.dob,
    this.username,
  });

  ProfileDraft copyWith({
    String? firstName,
    String? lastName,
    String? gender,
    DateTime? dob,
    String? username,
  }) {
    return ProfileDraft(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      username: username ?? this.username,
    );
  }
}

@riverpod
class ProfileDraftController extends _$ProfileDraftController {
  @override
  ProfileDraft build() {
    return const ProfileDraft();
  }

  void updateName(String firstName, String lastName) {
    state = state.copyWith(firstName: firstName, lastName: lastName);
  }

  void updateInfo(String gender, DateTime dob) {
    state = state.copyWith(gender: gender, dob: dob);
  }

  void updateUsername(String username) {
    state = state.copyWith(username: username);
  }

  void clear() {
    state = const ProfileDraft();
  }
}
