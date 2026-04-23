import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/db_helper.dart';
import '../models/bill.dart';
import '../models/bill_category.dart';
import 'add_bill_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DBHelper dbHelper = DBHelper();
  List<Bill> bills = [];
  bool isLoading = true;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    loadBills();
  }

  Future<void> loadBills() async {
    setState(() {
      isLoading = true;
    });

    try {
      bills = await dbHelper.getBills();
    } catch (e) {
      // Handle error, perhaps show a snackbar or log
      print('Error loading bills: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> togglePaid(Bill bill) async {
    bill.isPaid = bill.isPaid == 1 ? 0 : 1;
    await dbHelper.updateBill(bill);
    loadBills();
  }

  Future<void> deleteBill(Bill bill) async {
    await dbHelper.deleteBill(bill.id!);
    loadBills();
  }

  Future<void> _confirmDelete(Bill bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bill'),
        content: Text('Are you sure you want to delete "${bill.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      deleteBill(bill);
    }
  }

  List<Bill> get _upcomingBills {
    final now = DateTime.now();
    final upcoming = bills.where((bill) {
      final dueDate = DateTime.tryParse(bill.dueDate);
      return bill.isPaid == 0 && dueDate != null && !dueDate.isBefore(now);
    }).toList();

    upcoming.sort(
      (a, b) => DateTime.parse(a.dueDate).compareTo(DateTime.parse(b.dueDate)),
    );
    return upcoming;
  }

  List<Bill> get _overdueBills {
    final now = DateTime.now();
    final overdue = bills.where((bill) {
      final dueDate = DateTime.tryParse(bill.dueDate);
      return bill.isPaid == 0 && dueDate != null && dueDate.isBefore(now);
    }).toList();

    overdue.sort(
      (a, b) => DateTime.parse(a.dueDate).compareTo(DateTime.parse(b.dueDate)),
    );
    return overdue;
  }

  double get _totalOutstanding => bills
      .where((bill) => bill.isPaid == 0)
      .fold(0, (sum, bill) => sum + bill.amount);

  Future<void> _openAddBill() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBillScreen()),
    );
    loadBills();
  }

  String _formatDate(String value) {
    final dueDate = DateTime.tryParse(value);
    if (dueDate == null) return value.split(' ').first;
    return _dateFormat.format(dueDate);
  }

  String _reminderLabel(Bill bill) {
    final dueDate = DateTime.tryParse(bill.dueDate);
    if (dueDate == null) return 'Reminder unavailable';

    final difference = dueDate.difference(DateTime.now()).inDays;
    if (bill.isPaid == 1) return 'Paid';
    if (difference < 0) return 'Overdue reminder';
    if (difference == 0) return 'Due today';
    if (difference <= bill.reminderDays) return 'Reminder scheduled';
    return 'Reminder ${bill.reminderDays} day${bill.reminderDays == 1 ? '' : 's'} before due date';
  }

  Color _statusColor(Bill bill) {
    final dueDate = DateTime.tryParse(bill.dueDate);
    if (bill.isPaid == 1) return Colors.green;
    if (dueDate != null && dueDate.isBefore(DateTime.now())) {
      return Colors.redAccent;
    }
    return const Color(0xFF5B6CFF);
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildBillCard(Bill bill) {
    final statusColor = _statusColor(bill);

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (BillCategories.findById(bill.categoryId)?.lightColor ?? BillCategories.other.lightColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    BillCategories.findById(bill.categoryId)?.icon ?? BillCategories.other.icon,
                    color: BillCategories.findById(bill.categoryId)?.color ?? BillCategories.other.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _reminderLabel(bill),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(bill),
                ),
                IconButton(
                  icon: Icon(
                    bill.isPaid == 1
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: bill.isPaid == 1 ? Colors.green : Colors.grey,
                    size: 28,
                  ),
                  onPressed: () => togglePaid(bill),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    label: 'Amount',
                    value: '₱${bill.amount.toStringAsFixed(2)}',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoTile(
                    label: 'Due Date',
                    value: _formatDate(bill.dueDate),
                    icon: Icons.calendar_month_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF5B6CFF)),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B6CFF), Color(0xFF8A63FF)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Billing Reminder',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add bills, monitor upcoming due dates, and stay ahead of reminders.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _openAddBill,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF5B6CFF),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Bill'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.notifications_active_rounded,
            color: Colors.white,
            size: 52,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcomingBills = _upcomingBills;
    final overdueBills = _overdueBills;

    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: loadBills,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello!',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Bill Reminder Dashboard',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: loadBills,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildQuickActionCard(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildSummaryCard(
                          title: 'Outstanding',
                          value: '₱${_totalOutstanding.toStringAsFixed(0)}',
                          icon: Icons.savings_outlined,
                          color: const Color(0xFF5B6CFF),
                        ),
                        const SizedBox(width: 12),
                        _buildSummaryCard(
                          title: 'Upcoming',
                          value: '${upcomingBills.length}',
                          icon: Icons.schedule_outlined,
                          color: const Color(0xFF2EAE7D),
                        ),
                        const SizedBox(width: 12),
                        _buildSummaryCard(
                          title: 'Overdue',
                          value: '${overdueBills.length}',
                          icon: Icons.warning_amber_rounded,
                          color: const Color(0xFFE35D5D),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _buildSectionHeader(
                      'Reminder Status',
                      'Track your upcoming, overdue, and paid bills in one place.',
                    ),
                    const SizedBox(height: 16),
                    if (bills.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.receipt_long_rounded,
                              size: 54,
                              color: Color(0xFF5B6CFF),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No bills yet',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap Add Bill to create your first billing reminder.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    else ...bills.map(_buildBillCard),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddBill,
        icon: const Icon(Icons.add),
        label: const Text('Add Bill'),
      ),
    );
  }
}
