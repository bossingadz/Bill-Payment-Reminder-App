import 'package:shared_preferences/shared_preferences.dart';

class ProfileDetails {
  final String fullName;
  final String email;
  final String phoneNumber;
  final String bio;

  const ProfileDetails({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.bio,
  });

  static const ProfileDetails defaults = ProfileDetails(
    fullName: 'Cline User',
    email: 'cline.user@example.com',
    phoneNumber: '+63 912 345 6789',
    bio: 'Manage your bill reminder preferences and account overview.',
  );

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  ProfileDetails copyWith({
    String? fullName,
    String? email,
    String? phoneNumber,
    String? bio,
  }) {
    return ProfileDetails(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bio: bio ?? this.bio,
    );
  }
}

class ProfileService {
  static const String _fullNameKey = 'profile_full_name';
  static const String _emailKey = 'profile_email';
  static const String _phoneNumberKey = 'profile_phone_number';
  static const String _bioKey = 'profile_bio';

  static Future<ProfileDetails> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    return ProfileDetails(
      fullName: prefs.getString(_fullNameKey) ?? ProfileDetails.defaults.fullName,
      email: prefs.getString(_emailKey) ?? ProfileDetails.defaults.email,
      phoneNumber: prefs.getString(_phoneNumberKey) ?? ProfileDetails.defaults.phoneNumber,
      bio: prefs.getString(_bioKey) ?? ProfileDetails.defaults.bio,
    );
  }

  static Future<void> saveProfile(ProfileDetails profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fullNameKey, profile.fullName);
    await prefs.setString(_emailKey, profile.email);
    await prefs.setString(_phoneNumberKey, profile.phoneNumber);
    await prefs.setString(_bioKey, profile.bio);
  }
}