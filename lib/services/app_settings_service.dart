import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  final bool dueReminders;
  final bool paymentConfirmations;
  final bool tipsAndUpdates;

  const NotificationPreferences({
    required this.dueReminders,
    required this.paymentConfirmations,
    required this.tipsAndUpdates,
  });

  static const defaults = NotificationPreferences(
    dueReminders: true,
    paymentConfirmations: true,
    tipsAndUpdates: false,
  );

  NotificationPreferences copyWith({
    bool? dueReminders,
    bool? paymentConfirmations,
    bool? tipsAndUpdates,
  }) {
    return NotificationPreferences(
      dueReminders: dueReminders ?? this.dueReminders,
      paymentConfirmations: paymentConfirmations ?? this.paymentConfirmations,
      tipsAndUpdates: tipsAndUpdates ?? this.tipsAndUpdates,
    );
  }
}

class PrivacySecuritySettings {
  final bool appLock;
  final bool biometricUnlock;
  final bool analyticsSharing;

  const PrivacySecuritySettings({
    required this.appLock,
    required this.biometricUnlock,
    required this.analyticsSharing,
  });

  static const defaults = PrivacySecuritySettings(
    appLock: false,
    biometricUnlock: false,
    analyticsSharing: true,
  );

  PrivacySecuritySettings copyWith({
    bool? appLock,
    bool? biometricUnlock,
    bool? analyticsSharing,
  }) {
    return PrivacySecuritySettings(
      appLock: appLock ?? this.appLock,
      biometricUnlock: biometricUnlock ?? this.biometricUnlock,
      analyticsSharing: analyticsSharing ?? this.analyticsSharing,
    );
  }
}

class AppSettingsService {
  static const _dueRemindersKey = 'notification_due_reminders';
  static const _paymentConfirmationsKey = 'notification_payment_confirmations';
  static const _tipsUpdatesKey = 'notification_tips_updates';

  static const _appLockKey = 'privacy_app_lock';
  static const _biometricUnlockKey = 'privacy_biometric_unlock';
  static const _analyticsSharingKey = 'privacy_analytics_sharing';

  static Future<NotificationPreferences> loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    return NotificationPreferences(
      dueReminders: prefs.getBool(_dueRemindersKey) ?? NotificationPreferences.defaults.dueReminders,
      paymentConfirmations: prefs.getBool(_paymentConfirmationsKey) ?? NotificationPreferences.defaults.paymentConfirmations,
      tipsAndUpdates: prefs.getBool(_tipsUpdatesKey) ?? NotificationPreferences.defaults.tipsAndUpdates,
    );
  }

  static Future<void> saveNotificationPreferences(NotificationPreferences settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dueRemindersKey, settings.dueReminders);
    await prefs.setBool(_paymentConfirmationsKey, settings.paymentConfirmations);
    await prefs.setBool(_tipsUpdatesKey, settings.tipsAndUpdates);
  }

  static Future<PrivacySecuritySettings> loadPrivacySecuritySettings() async {
    final prefs = await SharedPreferences.getInstance();

    return PrivacySecuritySettings(
      appLock: prefs.getBool(_appLockKey) ?? PrivacySecuritySettings.defaults.appLock,
      biometricUnlock: prefs.getBool(_biometricUnlockKey) ?? PrivacySecuritySettings.defaults.biometricUnlock,
      analyticsSharing: prefs.getBool(_analyticsSharingKey) ?? PrivacySecuritySettings.defaults.analyticsSharing,
    );
  }

  static Future<void> savePrivacySecuritySettings(PrivacySecuritySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockKey, settings.appLock);
    await prefs.setBool(_biometricUnlockKey, settings.biometricUnlock);
    await prefs.setBool(_analyticsSharingKey, settings.analyticsSharing);
  }
}