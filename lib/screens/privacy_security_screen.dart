import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  PrivacySecuritySettings _settings = PrivacySecuritySettings.defaults;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await AppSettingsService.loadPrivacySecuritySettings();
    if (!mounted) return;

    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _updateSettings(PrivacySecuritySettings settings) async {
    setState(() => _settings = settings);
    await AppSettingsService.savePrivacySecuritySettings(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Privacy & Security',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _PrivacySection(
                    title: 'Security controls',
                    subtitle: 'Manage how your app is protected on this device.',
                    child: Column(
                      children: [
                        _SecurityTile(
                          icon: Icons.lock_outline_rounded,
                          title: 'App lock',
                          subtitle: 'Require an extra lock step when opening the app.',
                          value: _settings.appLock,
                          onChanged: (value) => _updateSettings(_settings.copyWith(appLock: value)),
                        ),
                        const Divider(height: 1),
                        _SecurityTile(
                          icon: Icons.fingerprint_rounded,
                          title: 'Biometric unlock',
                          subtitle: 'Use fingerprint or face unlock where supported.',
                          value: _settings.biometricUnlock,
                          onChanged: (value) => _updateSettings(_settings.copyWith(biometricUnlock: value)),
                        ),
                        const Divider(height: 1),
                        _SecurityTile(
                          icon: Icons.analytics_outlined,
                          title: 'Usage analytics',
                          subtitle: 'Help improve the app by sharing anonymous usage data.',
                          value: _settings.analyticsSharing,
                          onChanged: (value) => _updateSettings(_settings.copyWith(analyticsSharing: value)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: 'Your data',
                    items: const [
                      'Bill reminders and profile details are stored locally on this device.',
                      'You can update or remove local information anytime from the app.',
                      'Guest mode keeps your information available only on this device.',
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _PrivacySection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade600, height: 1.4)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SecurityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SecurityTile({
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

class _InfoCard extends StatelessWidget {
  final String title;
  final List<String> items;

  const _InfoCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF5B6CFF)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}