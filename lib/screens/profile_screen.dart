import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_settings_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../ui/modern_ui.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';
import 'login_screen.dart';
import 'notification_preferences_screen.dart';
import 'privacy_security_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileDetails _profile = ProfileDetails.defaults;
  bool _dueDateRemindersEnabled = NotificationPreferences.defaults.dueReminders;
  bool _isLoadingProfile = true;

  static const String _guestModeKey = 'continue_as_guest';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.loadProfile();
    final notificationPreferences = await AppSettingsService.loadNotificationPreferences();
    final accountProfile = _profileForCurrentUser(profile);

    if (!mounted) return;

    setState(() {
      _profile = accountProfile;
      _dueDateRemindersEnabled = notificationPreferences.dueReminders;
      _isLoadingProfile = false;
    });
  }

  ProfileDetails _profileForCurrentUser(ProfileDetails savedProfile) {
    final user = AuthService.currentUser;
    final email = user?.email?.trim();

    if (email == null || email.isEmpty) {
      return savedProfile;
    }

    final savedName = savedProfile.fullName.trim();
    final shouldUseEmailName = savedName.isEmpty ||
        savedName == ProfileDetails.defaults.fullName ||
        savedName == _nameFromEmail(savedProfile.email);

    return savedProfile.copyWith(
      fullName: shouldUseEmailName ? _nameFromEmail(email) : savedProfile.fullName,
      email: email,
    );
  }

  String _nameFromEmail(String email) {
    final namePart = email.split('@').first.trim();
    if (namePart.isEmpty) return ProfileDetails.defaults.fullName;

    return namePart
        .split(RegExp(r'[._\-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(initialProfile: _profile),
      ),
    );

    if (updated == true) {
      await _loadProfile();
    }
  }

  Future<void> _openNotificationPreferences() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationPreferencesScreen()),
    );

    await _loadProfile();
  }

  Future<void> _openPrivacySecurity() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()),
    );
  }

  Future<void> _openHelpSupport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestModeKey, false);
    await AuthService.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      backgroundColor: AppUi.background,
      body: AppScreenBackground(
        child: SafeArea(
          child: _isLoadingProfile
              ? const Center(child: CircularProgressIndicator())
              : ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            ModernTopBar(
              title: 'Profile',
              subtitle: 'Manage your account, reminders, and preferences.',
              onBack: () => Navigator.pop(context),
              trailing: Container(
                width: 48,
                height: 48,
                decoration: AppUi.softCardDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.settings_outlined),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppUi.heroGradient,
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x265B6CFF),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white24,
                    child: Text(
                      profile.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    profile.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    profile.bio,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _ProfileBadge(
                        icon: Icons.mail_outline_rounded,
                        label: profile.email,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ProfileStatCard(
                    icon: Icons.receipt_long_rounded,
                    label: 'Bills tracked',
                    value: 'All bills',
                    color: Color(0xFF5B6CFF),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _ProfileStatCard(
                    icon: Icons.notifications_active_rounded,
                    label: 'Reminders',
                    value: _dueDateRemindersEnabled ? 'Enabled' : 'Disabled',
                    color: Color(0xFF2EAE7D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionTitle(
              title: 'Account settings',
              subtitle: 'Customize your app and personal preferences.',
            ),
            const SizedBox(height: 12),
            _ProfileMenuCard(
              icon: Icons.person_outline_rounded,
              title: 'Personal information',
              subtitle: 'Update your profile details and display name.',
              onTap: _openEditProfile,
            ),
            const SizedBox(height: 12),
            _ProfileMenuCard(
              icon: Icons.notifications_none_rounded,
              title: 'Notification preferences',
              subtitle: 'Control alerts and reminder behavior.',
              onTap: _openNotificationPreferences,
            ),
            const SizedBox(height: 12),
            _ProfileMenuCard(
              icon: Icons.lock_outline_rounded,
              title: 'Privacy & security',
              subtitle: 'Review app access and security settings.',
              onTap: _openPrivacySecurity,
            ),
            const SizedBox(height: 12),
            _ProfileMenuCard(
              icon: Icons.help_outline_rounded,
              title: 'Help & support',
              subtitle: 'Get assistance and learn how to use the app.',
              onTap: _openHelpSupport,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _signOut(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD64545),
                  side: const BorderSide(color: Color(0xFFD64545)),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  backgroundColor: Colors.white,
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProfileBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppUi.glassDecoration(borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ProfileStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ModernStatCard(
      label: label,
      value: value,
      icon: icon,
      color: color,
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ProfileMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: AppUi.softCardDecoration(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppUi.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppUi.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}