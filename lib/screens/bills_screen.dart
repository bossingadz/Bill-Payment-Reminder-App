import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/db_helper.dart';
import '../models/bill.dart';
import '../models/bill_category.dart';
import '../ui/modern_ui.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final DBHelper dbHelper = DBHelper();
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');

  List<Bill> bills = [];
  bool isLoading = true;
  DateTime? selectedPaidBacklogDate;
  StreamSubscription<List<Bill>>? _billsSubscription;

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
      debugPrint('Error loading bills: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  List<Bill> get _paidBills {
    final paidBills = bills.where((bill) => bill.isPaid == 1 && bill.paidDate != null);

    if (selectedPaidBacklogDate == null) {
      final allPaidBills = paidBills.toList();
      allPaidBills.sort(
        (a, b) => DateTime.parse(b.paidDate!).compareTo(DateTime.parse(a.paidDate!)),
      );
      return allPaidBills;
    }

    final selected = DateTime(
      selectedPaidBacklogDate!.year,
      selectedPaidBacklogDate!.month,
      selectedPaidBacklogDate!.day,
    );

    final filtered = paidBills.where((bill) {
      final paidDate = DateTime.tryParse(bill.paidDate!);
      if (paidDate == null) return false;

      final normalized = DateTime(paidDate.year, paidDate.month, paidDate.day);
      return normalized == selected;
    }).toList();

    filtered.sort(
      (a, b) => DateTime.parse(b.paidDate!).compareTo(DateTime.parse(a.paidDate!)),
    );
    return filtered;
  }

  double get _totalPaid => _paidBills.fold(0, (sum, bill) => sum + bill.amount);

  int get _totalPaidCount => _paidBills.length;

  Bill? get _latestPaidBill => _paidBills.isEmpty ? null : _paidBills.first;

  String _formatDate(String value) {
    final dueDate = DateTime.tryParse(value);
    if (dueDate == null) return value.split(' ').first;
    return _dateFormat.format(dueDate);
  }

  String _formatCurrency(double amount) => '₱${_currencyFormat.format(amount)}';

  Future<void> _pickPaidBacklogDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedPaidBacklogDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedPaidBacklogDate = picked;
      });
    }
  }

  Future<void> _deleteBill(Bill bill) async {
    await dbHelper.deleteBill(bill.id!);
  }

  Future<void> _confirmDelete(Bill bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Are you sure you want to delete "${bill.name}" from recent transactions?'),
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
      await _deleteBill(bill);
    }
  }

  Widget _buildPaidBillCard(Bill bill) {
    final category = BillCategories.findById(bill.categoryId) ?? BillCategories.other;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: AppUi.softCardDecoration(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: category.lightColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(category.icon, color: category.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      category.name,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9FBEE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'PAID',
                  style: TextStyle(
                    color: Color(0xFF169B51),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
               const SizedBox(width: 8),
               IconButton(
                 onPressed: () => _confirmDelete(bill),
                 style: IconButton.styleFrom(
                   backgroundColor: const Color(0xFFFFF1F1),
                   foregroundColor: const Color(0xFFEF4444),
                 ),
                 icon: const Icon(Icons.delete_outline_rounded),
                 tooltip: 'Delete transaction',
               ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetaItem('Amount', _formatCurrency(bill.amount)),
                ),
                Expanded(
                  child: _buildMetaItem(
                    'Paid date',
                    bill.paidDate != null ? _formatDate(bill.paidDate!) : 'Unknown',
                  ),
                ),
                Expanded(
                  child: _buildMetaItem('Due date', _formatDate(bill.dueDate)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: ModernStatCard(
        label: label,
        value: value,
        icon: icon,
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestPaidBill = _latestPaidBill;

    return Scaffold(
      backgroundColor: AppUi.background,
      body: AppScreenBackground(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: loadBills,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    ModernTopBar(
                      title: 'Bills',
                      subtitle: 'Review your paid history and recent transactions.',
                      onBack: () => Navigator.pop(context),
                      trailing: Container(
                        width: 48,
                        height: 48,
                        decoration: AppUi.softCardDecoration(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.more_horiz_rounded),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6B7CFF), Color(0xFF8E67FF)],
                      ),
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Paid bills history',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          selectedPaidBacklogDate == null
                              ? 'Track every paid bill in one place with a premium backlog view.'
                              : 'Showing paid bills for ${_dateFormat.format(selectedPaidBacklogDate!)}.',
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.5,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatCurrency(_totalPaid),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Total paid',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$_totalPaidCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Bills paid',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _pickPaidBacklogDate,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF5D67FF),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                icon: const Icon(Icons.calendar_month_rounded),
                                label: Text(
                                  selectedPaidBacklogDate == null
                                      ? 'Pick date'
                                      : _dateFormat.format(selectedPaidBacklogDate!),
                                ),
                              ),
                            ),
                            if (selectedPaidBacklogDate != null) ...[
                              const SizedBox(width: 10),
                              InkWell(
                                onTap: () => setState(() => selectedPaidBacklogDate = null),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatCard(
                        'Latest bill',
                        latestPaidBill?.name ?? 'None',
                        Icons.receipt_long_rounded,
                        const Color(0xFF5B6CFF),
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Filter',
                        selectedPaidBacklogDate == null ? 'All time' : 'Active',
                        Icons.tune_rounded,
                        const Color(0xFFEF4444),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SectionTitle(
                    title: 'Recent transactions',
                    subtitle: 'A polished list of your successfully paid bills.',
                  ),
                  const SizedBox(height: 16),
                  if (_paidBills.isNotEmpty) ...[
                    ..._paidBills.map(_buildPaidBillCard),
                  ] else
                    EmptyStateCard(
                      icon: Icons.archive_outlined,
                      title: 'No paid bills recorded yet',
                      subtitle: selectedPaidBacklogDate == null
                          ? 'Once you mark bills as paid, they will appear here.'
                          : 'No bills were marked paid on the selected date.',
                    ),
                ],
              ),
            ),
      ),
    );
  }
}
