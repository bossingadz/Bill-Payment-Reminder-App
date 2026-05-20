import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  NotificationPreferences _preferences = NotificationPreferences.defaults;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await AppSettingsService.loadNotificationPreferences();
    if (!mounted) return;

    setState(() {
      _preferences = preferences;
      _isLoading = false;
    });
  }

  Future<void> _updatePreferences(NotificationPreferences preferences) async {
    setState(() => _preferences = preferences);
    await AppSettingsService.saveNotificationPreferences(preferences);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Notification Preferences',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _SectionCard(
                    title: 'Alerts & reminders',
                    subtitle: 'Choose which notifications you want to receive for your bills and account activity.',
                    child: Column(
                      children: [
                        _PreferenceTile(
                          icon: Icons.notifications_active_outlined,
                          title: 'Due date reminders',
                          subtitle: 'Get alerts before upcoming bill due dates.',
                          value: _preferences.dueReminders,
                          onChanged: (value) => _updatePreferences(
                            _preferences.copyWith(dueReminders: value),
                          ),
                        ),
                        const Divider(height: 1),
                        _PreferenceTile(
                          icon: Icons.check_circle_outline_rounded,
                          title: 'Payment confirmations',
                          subtitle: 'Receive confirmation when a bill is marked as paid.',
                          value: _preferences.paymentConfirmations,
                          onChanged: (value) => _updatePreferences(
                            _preferences.copyWith(paymentConfirmations: value),
                          ),
                        ),
                        const Divider(height: 1),
                        _PreferenceTile(
                          icon: Icons.tips_and_updates_outlined,
                          title: 'Tips & app updates',
                          subtitle: 'See product tips and feature updates from the app.',
                          value: _preferences.tipsAndUpdates,
                          onChanged: (value) => _updatePreferences(
                            _preferences.copyWith(tipsAndUpdates: value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: const Color(0xFF5B6CFF)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, height: 1.3)),
      value: value,
      onChanged: onChanged,
    );
  }
}