import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/db_helper.dart';
import '../models/bill.dart';
import '../models/bill_category.dart';
import '../ui/modern_ui.dart';
import 'add_bill_screen.dart';
import 'bills_screen.dart';
import 'profile_screen.dart';
import 'reminders_screen.dart';
import 'summary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DBHelper dbHelper = DBHelper();
  List<Bill> bills = [];
  bool isLoading = true;
  StreamSubscription<List<Bill>>? _billsSubscription;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _listenToBills();
  }

  @override
  void dispose() {
    _billsSubscription?.cancel();
    super.dispose();
  }

  void _listenToBills() {
    _billsSubscription?.cancel();
    setState(() {
      isLoading = true;
    });

    _billsSubscription = dbHelper.watchBills().listen(
      (items) {
        if (!mounted) return;
        setState(() {
          bills = items;
          isLoading = false;
        });
      },
      onError: (error) {
        debugPrint('Error watching bills: $error');
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
      },
    );
  }

  Future<void> loadBills() async {
    setState(() {
      isLoading = true;
    });

    try {
      bills = await dbHelper.getBills();
    } catch (e) {
      // Handle error, perhaps show a snackbar or log
      debugPrint('Error loading bills: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> togglePaid(Bill bill) async {
    final isMarkingPaid = bill.isPaid == 0;
    bill.isPaid = isMarkingPaid ? 1 : 0;
    bill.paidDate = isMarkingPaid ? DateTime.now().toIso8601String() : null;
    await dbHelper.updateBill(bill);
  }

  Future<void> deleteBill(Bill bill) async {
    await dbHelper.deleteBill(bill.id!);
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

  List<Bill> get _activeBills {
    final activeBills = bills.where((bill) => bill.isPaid == 0).toList();
    activeBills.sort(
      (a, b) => DateTime.parse(a.dueDate).compareTo(DateTime.parse(b.dueDate)),
    );
    return activeBills;
  }

  double get _totalOutstanding => bills
      .where((bill) => bill.isPaid == 0)
      .fold(0, (sum, bill) => sum + bill.amount);

  Future<void> _openAddBill() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBillScreen()),
    );
  }

  String _formatDate(String value) {
    final dueDate = DateTime.tryParse(value);
    if (dueDate == null) return value.split(' ').first;
    return _dateFormat.format(dueDate);
  }

  String _formatCurrency(double value) => '₱${_currencyFormat.format(value)}';

  String _reminderLabel(Bill bill) {
    final dueDate = DateTime.tryParse(bill.dueDate);
    if (dueDate == null) return 'Reminder unavailable';

    final difference = dueDate.difference(DateTime.now()).inDays;
    if (bill.isPaid == 1) {
      final paidDate = bill.paidDate;
      if (paidDate != null) {
        return 'Paid on ${_formatDate(paidDate)}';
      }
      return 'Paid';
    }
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Column(
        children: [
          ModernStatCard(
            label: title,
            value: value,
            icon: icon,
            color: color,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _buildMiniChart(color),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid({required List<Widget> cards}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final isNarrow = constraints.maxWidth < 430;
        final columns = isNarrow ? 2 : 3;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 12,
          children: cards
              .map(
                (card) => SizedBox(
                  width: itemWidth,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildMiniChart(Color color) {
    return SizedBox(
      height: 32,
      child: CustomPaint(
        painter: MiniChartPainter(color: color),
        size: const Size(double.infinity, 32),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return SectionTitle(title: title, subtitle: subtitle);
  }

  Widget _buildBillCard(Bill bill) {
    final statusColor = _statusColor(bill);

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AppUi.softCardDecoration(
          borderRadius: BorderRadius.circular(28),
        ),
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
                    value: _formatCurrency(bill.amount),
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
    return SoftInfoTile(
      label: label,
      value: value,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcomingBills = _upcomingBills;
    final overdueBills = _overdueBills;
    final activeBills = _activeBills;

    return Scaffold(
      backgroundColor: AppUi.background,
      body: AppScreenBackground(
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: loadBills,
                  child: ListView(
                    padding: const EdgeInsets.all(0),
                    children: [
                      _buildHeader(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            _buildPromoBanner(),
                            const SizedBox(height: 28),
                            _buildSummaryGrid(
                              cards: [
                                _buildSummaryCard(
                                  title: 'Outstanding',
                                  value: _formatCurrency(_totalOutstanding),
                                  icon: Icons.account_balance_wallet_outlined,
                                  color: const Color(0xFF5B6CFF),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SummaryScreen(
                                          title: 'Outstanding Balance',
                                          subtitle: 'See all unpaid bills contributing to your current outstanding balance.',
                                          summaryValue: _formatCurrency(_totalOutstanding),
                                          summaryLabel: 'Outstanding total',
                                          icon: Icons.account_balance_wallet_outlined,
                                          color: const Color(0xFF5B6CFF),
                                          bills: activeBills,
                                          emptyMessage: 'You have no outstanding unpaid bills right now.',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _buildSummaryCard(
                                  title: 'Upcoming',
                                  value: '${upcomingBills.length}',
                                  icon: Icons.calendar_month_outlined,
                                  color: const Color(0xFF2EAE7D),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SummaryScreen(
                                          title: 'Upcoming Bills',
                                          subtitle: 'Review bills that are scheduled for future due dates and need attention soon.',
                                          summaryValue: '${upcomingBills.length}',
                                          summaryLabel: 'Upcoming bills',
                                          icon: Icons.calendar_month_outlined,
                                          color: const Color(0xFF2EAE7D),
                                          bills: upcomingBills,
                                          emptyMessage: 'There are no upcoming bills at the moment.',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _buildSummaryCard(
                                  title: 'Overdue',
                                  value: '${overdueBills.length}',
                                  icon: Icons.warning_amber_rounded,
                                  color: const Color(0xFFE35D5D),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SummaryScreen(
                                          title: 'Overdue Bills',
                                          subtitle: 'Review unpaid bills that have already passed their due dates and need immediate attention.',
                                          summaryValue: '${overdueBills.length}',
                                          summaryLabel: 'Overdue bills',
                                          icon: Icons.warning_amber_rounded,
                                          color: const Color(0xFFE35D5D),
                                          bills: overdueBills,
                                          emptyMessage: 'You have no overdue bills right now.',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            _buildSectionHeader(
                              'Reminder Status',
                              'Track your upcoming and overdue bills here. Paid history is in the Bills tab.',
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      if (activeBills.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: EmptyStateCard(
                            icon: Icons.receipt_long_rounded,
                            title: 'No active bills',
                            subtitle: bills.isEmpty
                                ? 'Tap Add Bill to create your first billing reminder.'
                                : 'All current bills are paid. View your paid history in the Bills tab.',
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: activeBills.map(_buildBillCard).toList(),
                          ),
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddBill,
        backgroundColor: AppUi.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 12,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', 0),
              _buildNavItem(Icons.receipt_long_rounded, 'Bills', 1),
              const SizedBox(width: 60),
              _buildNavItem(Icons.notifications_rounded, 'Reminders', 2),
              _buildNavItem(Icons.person_rounded, 'Profile', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: ModernTopBar(
        title: 'Bill Reminder',
        subtitle: 'A smarter view of your upcoming payments.',
        trailing: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/images/app_logo.png',
            width: 52,
            height: 52,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return HeroCard(
      title: 'Stay ahead of your bills',
      subtitle:
          'Add bills, monitor upcoming due dates, and stay ahead of reminders with a cleaner dashboard.',
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: _openAddBill,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppUi.primary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add Bill'),
          ),
          const Spacer(),
          Container(
            width: 62,
            height: 62,
            decoration: AppUi.glassDecoration(
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    return InkWell(
      onTap: () {
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BillsScreen()),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RemindersScreen()),
          );
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: index == 0
                ? const Color(0xFF5B6CFF)
                : Colors.grey.shade400,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: index == 0
                  ? const Color(0xFF5B6CFF)
                  : Colors.grey.shade400,
              fontWeight: index == 0 ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class MiniChartPainter extends CustomPainter {
  final Color color;

  MiniChartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final points = [
      Offset(0, size.height * 0.6),
      Offset(size.width * 0.25, size.height * 0.4),
      Offset(size.width * 0.5, size.height * 0.5),
      Offset(size.width * 0.75, size.height * 0.3),
      Offset(size.width, size.height * 0.2),
    ];

    final path = Path();
    path.moveTo(0, size.height);
    for (final point in points) {
      path.lineTo(point.dx, point.dy);
    }
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, fillPaint);

    final linePath = Path();
    linePath.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(linePath, paint);

    // Draw dots at data points
    for (final point in points) {
      canvas.drawCircle(point, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(MiniChartPainter oldDelegate) => false;
}
