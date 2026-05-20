import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/db_helper.dart';
import '../models/bill.dart';
import '../models/bill_category.dart';
import '../services/app_settings_service.dart';
import '../ui/modern_ui.dart';
import 'notification_preferences_screen.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final DBHelper dbHelper = DBHelper();
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  List<Bill> _bills = [];
  bool _dueRemindersEnabled = NotificationPreferences.defaults.dueReminders;
  bool _isLoading = true;
  StreamSubscription<List<Bill>>? _billsSubscription;

  @override
  void initState() {
    super.initState();
    _listenToBills();
    _loadPreferences();
  }

  @override
  void dispose() {
    _billsSubscription?.cancel();
    super.dispose();
  }

  void _listenToBills() {
    _billsSubscription?.cancel();
    setState(() => _isLoading = true);

    _billsSubscription = dbHelper.watchBills().listen(
      (items) {
        if (!mounted) return;
        setState(() {
          _bills = items;
          _isLoading = false;
        });
      },
      onError: (error) {
        debugPrint('Error watching reminder bills: $error');
        if (!mounted) return;
        setState(() => _isLoading = false);
      },
    );
  }

  Future<void> _loadPreferences() async {
    final preferences = await AppSettingsService.loadNotificationPreferences();
    if (!mounted) return;
    setState(() {
      _dueRemindersEnabled = preferences.dueReminders;
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final bills = await dbHelper.getBills();
      final preferences = await AppSettingsService.loadNotificationPreferences();

      if (!mounted) return;

      setState(() {
        _bills = bills;
        _dueRemindersEnabled = preferences.dueReminders;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openNotificationPreferences() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationPreferencesScreen()),
    );

    await _loadPreferences();
  }

  List<Bill> get _activeBills {
    final items = _bills.where((bill) => bill.isPaid == 0).toList();
    items.sort(
      (a, b) => DateTime.parse(a.dueDate).compareTo(DateTime.parse(b.dueDate)),
    );
    return items;
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value.split(' ').first;
    return _dateFormat.format(date);
  }

  DateTime? _reminderDate(Bill bill) {
    final dueDate = DateTime.tryParse(bill.dueDate);
    if (dueDate == null) return null;
    return dueDate.subtract(Duration(days: bill.reminderDays));
  }

  String _reminderStatus(Bill bill) {
    final dueDate = DateTime.tryParse(bill.dueDate);
    final reminderDate = _reminderDate(bill);
    if (dueDate == null || reminderDate == null) return 'Reminder date unavailable';

    final now = DateTime.now();
    final normalizedNow = DateTime(now.year, now.month, now.day);
    final normalizedReminder = DateTime(reminderDate.year, reminderDate.month, reminderDate.day);
    final normalizedDue = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (normalizedDue.isBefore(normalizedNow)) return 'Bill overdue';
    if (normalizedReminder.isAtSameMomentAs(normalizedNow)) return 'Reminder scheduled for today';
    if (normalizedReminder.isBefore(normalizedNow)) return 'Reminder window already started';

    final daysUntilReminder = normalizedReminder.difference(normalizedNow).inDays;
    if (daysUntilReminder == 1) return 'Reminder starts tomorrow';
    return 'Reminder starts in $daysUntilReminder days';
  }

  Color _statusColor(Bill bill) {
    final dueDate = DateTime.tryParse(bill.dueDate);
    if (dueDate == null) return Colors.grey;
    if (dueDate.isBefore(DateTime.now())) return const Color(0xFFE35D5D);

    final reminderDate = _reminderDate(bill);
    if (reminderDate != null && !reminderDate.isAfter(DateTime.now())) {
      return const Color(0xFF2EAE7D);
    }

    return const Color(0xFF5B6CFF);
  }

  @override
  Widget build(BuildContext context) {
    final activeBills = _activeBills;

    return Scaffold(
      backgroundColor: AppUi.background,
      body: AppScreenBackground(
        child: SafeArea(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    ModernTopBar(
                      title: 'Reminders',
                      subtitle: 'Keep track of alert windows before each due date.',
                      onBack: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 20),
                    HeroCard(
                      title: 'Reminder Center',
                      subtitle: _dueRemindersEnabled
                          ? 'Due date reminders are enabled. Review when each active bill should notify you.'
                          : 'Due date reminders are currently disabled. Turn them on to receive reminder alerts.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: _ReminderSummaryChip(
                                  value: '${activeBills.length}',
                                  label: 'Active bills',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ReminderSummaryChip(
                                  value: _dueRemindersEnabled ? 'On' : 'Off',
                                  label: 'Reminders',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _openNotificationPreferences,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppUi.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            icon: const Icon(Icons.tune_rounded),
                            label: const Text('Manage Reminder Settings'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SectionTitle(
                      title: 'Scheduled reminders',
                      subtitle: _dueRemindersEnabled
                          ? 'This list shows active bills and when their reminder windows begin.'
                          : 'Enable due date reminders to activate reminder scheduling for future bills.',
                    ),
                    const SizedBox(height: 16),
                    if (activeBills.isEmpty)
                      const EmptyStateCard(
                        icon: Icons.notifications_off_outlined,
                        title: 'No active reminders',
                        subtitle: 'Add unpaid bills to start seeing reminder schedules here.',
                      )
                    else
                      ...activeBills.map((bill) {
                        final category = BillCategories.findById(bill.categoryId) ?? BillCategories.other;
                        final reminderDate = _reminderDate(bill);
                        final statusColor = _statusColor(bill);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(18),
                          decoration: AppUi.softCardDecoration(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: category.lightColor,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(category.icon, color: category.color),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bill.name,
                                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          category.name,
                                          style: TextStyle(color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _reminderStatus(bill),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ReminderDetailTile(
                                      icon: Icons.calendar_today_outlined,
                                      label: 'Reminder date',
                                      value: reminderDate == null ? 'Unavailable' : _dateFormat.format(reminderDate),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ReminderDetailTile(
                                      icon: Icons.event_outlined,
                                      label: 'Due date',
                                      value: _formatDate(bill.dueDate),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}

class _ReminderSummaryChip extends StatelessWidget {
  final String value;
  final String label;

  const _ReminderSummaryChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppUi.glassDecoration(borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _ReminderDetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReminderDetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SoftInfoTile(
      label: label,
      value: value,
      icon: icon,
    );
  }
}