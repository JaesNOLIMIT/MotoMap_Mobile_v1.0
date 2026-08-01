class RiderProfile {
  const RiderProfile({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.phoneNumber,
    required this.birthDate,
    this.avatarPath,
  });

  final String userId;
  final String firstName;
  final String lastName;
  final String username;
  final String phoneNumber;
  final DateTime birthDate;
  final String? avatarPath;

  String get displayName => '$firstName $lastName'.trim();

  String get initials {
    final first = firstName.trim().isEmpty ? '' : firstName.trim()[0];
    final last = lastName.trim().isEmpty ? '' : lastName.trim()[0];
    final value = '$first$last'.toUpperCase();
    return value.isEmpty ? 'R' : value;
  }

  factory RiderProfile.fromJson(Map<String, dynamic> json) => RiderProfile(
    userId: json['user_id'] as String,
    firstName: json['first_name'] as String,
    lastName: json['last_name'] as String,
    username: json['username'] as String,
    phoneNumber: json['phone_number'] as String,
    birthDate: DateTime.parse(json['birth_date'] as String),
    avatarPath: json['avatar_path'] as String?,
  );
}
