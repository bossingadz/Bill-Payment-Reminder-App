import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/db_helper.dart';
import '../models/bill.dart';
import '../models/bill_category.dart';
import '../services/app_settings_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';

class AddBillScreen extends StatefulWidget {
  const AddBillScreen({super.key});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController customReminderDaysController = TextEditingController();
  final DBHelper dbHelper = DBHelper();
  DateTime selectedDate = DateTime.now();
  BillCategory selectedCategory = BillCategories.other;
  int selectedReminderDays = 1;
  bool isCustomReminderDays = false;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final NumberFormat _amountFormat = NumberFormat('#,##0.00');
  bool _isFormattingAmount = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    amountController.addListener(_formatAmountInput);
  }

  @override
  void dispose() {
    amountController.removeListener(_formatAmountInput);
    nameController.dispose();
    amountController.dispose();
    customReminderDaysController.dispose();
    super.dispose();
  }

  void _formatAmountInput() {
    if (_isFormattingAmount) return;

    final text = amountController.text;
    if (text.isEmpty) return;

    final sanitized = text.replaceAll(',', '');
    if (sanitized == '.') {
      _isFormattingAmount = true;
      amountController.value = const TextEditingValue(
        text: '0.',
        selection: TextSelection.collapsed(offset: 2),
      );
      _isFormattingAmount = false;
      return;
    }

    final parts = sanitized.split('.');
    if (parts.length > 2) return;

    final integerPart = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
    final decimalPart = parts.length == 2
        ? parts[1].replaceAll(RegExp(r'[^0-9]'), '')
        : '';

    if (integerPart.isEmpty && decimalPart.isEmpty) {
      _isFormattingAmount = true;
      amountController.clear();
      _isFormattingAmount = false;
      return;
    }

    final normalizedInteger = integerPart.isEmpty ? '0' : integerPart;
    final formattedInteger = NumberFormat('#,##0').format(int.parse(normalizedInteger));

    String formattedText = formattedInteger;
    if (parts.length == 2) {
      formattedText += '.${decimalPart.substring(0, decimalPart.length > 2 ? 2 : decimalPart.length)}';
    }

    if (formattedText == text) return;

    _isFormattingAmount = true;
    amountController.value = TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
    _isFormattingAmount = false;
  }

  Future<void> saveBill() async {
    if (_isSaving) return;

    final name = nameController.text.trim();
    final amountText = amountController.text.trim().replaceAll(',', '');

    if (name.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a bill name and amount.')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      return;
    }

    final reminderDays = _selectedReminderDays();
    if (reminderDays == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid custom reminder day.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final bill = Bill(
      name: name,
      amount: amount,
      dueDate: selectedDate.toIso8601String(),
      categoryId: selectedCategory.id,
      reminderDays: reminderDays,
    );

    try {
      await dbHelper.insertBill(bill);

      // Schedule notification in background
      final preferences = await AppSettingsService.loadNotificationPreferences();
      final reminderDate = selectedDate.subtract(Duration(days: reminderDays));
      if (preferences.dueReminders && reminderDate.isAfter(DateTime.now())) {
        NotificationService.scheduleNotification(
          id: bill.id?.toInt() ?? DateTime.now().microsecondsSinceEpoch ~/ 1000,
          title: 'Bill Reminder',
          body: '$name is due in $reminderDays day${reminderDays == 1 ? '' : 's'}!',
          scheduledDate: reminderDate,
        );
      }

      // Navigate to home screen after successful save
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save bill: $e')),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  int? _selectedReminderDays() {
    if (!isCustomReminderDays) return selectedReminderDays;

    final days = int.tryParse(customReminderDaysController.text.trim());
    if (days == null || days < 0) return null;
    return days;
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Bill')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5B6CFF), Color(0xFF8A63FF)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Billing Reminder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add a bill, set the due date, and get notified before payment is due.',
                    style: TextStyle(color: Colors.white, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Bill Name',
                      prefixIcon: const Icon(Icons.receipt_long_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: const Icon(Icons.payments_outlined),
                      hintText: _amountFormat.format(0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: Color(0xFF5B6CFF),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Due Date',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _dateFormat.format(selectedDate),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: pickDate,
                          child: const Text('Pick Date'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: BillCategories.all.map((category) {
                            final isSelected = selectedCategory.id == category.id;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedCategory = category;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? category.lightColor
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? category.color
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      category.icon,
                                      size: 18,
                                      color: category.color,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      category.name,
                                      style: TextStyle(
                                        color: category.color,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reminder Days Before Due',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [1, 3, 5, 7].map((days) {
                            final isSelected = !isCustomReminderDays && selectedReminderDays == days;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isCustomReminderDays = false;
                                    selectedReminderDays = days;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF5B6CFF)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF5B6CFF)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    '$days day${days == 1 ? '' : 's'}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              isCustomReminderDays = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isCustomReminderDays
                                  ? const Color(0xFFEFF2FF)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isCustomReminderDays
                                    ? const Color(0xFF5B6CFF)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_calendar_outlined,
                                  color: isCustomReminderDays
                                      ? const Color(0xFF5B6CFF)
                                      : Colors.grey.shade700,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: customReminderDaysController,
                                    enabled: isCustomReminderDays,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Custom days before due',
                                      hintText: 'Example: 10',
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        isCustomReminderDays = true;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF8F3),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          color: Color(0xFF2EAE7D),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'A reminder will be scheduled ${_selectedReminderDays() ?? 0} day${(_selectedReminderDays() ?? 0) == 1 ? '' : 's'} before the bill due date whenever possible.',
                            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : saveBill,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  _isSaving ? 'Saving...' : 'Save Bill',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
