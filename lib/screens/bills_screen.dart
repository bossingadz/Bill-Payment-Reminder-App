import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/db_helper.dart';
import '../models/bill.dart';
import '../models/bill_category.dart';
import '../ui/modern_ui.dart';
import 'summary_screen.dart';

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
  bool? selectedFilterIsPaid;

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

  List<Bill> get _filteredBills => _filterAndSortBills(bills);

  double get _filteredTotalAmount =>
      _filteredBills.fold(0, (sum, bill) => sum + bill.amount);

  int get _filteredBillsCount => _filteredBills.length;

  Bill? get _latestFilteredBill =>
      _filteredBills.isEmpty ? null : _filteredBills.first;

  String get _filterLabel {
    if (selectedFilterIsPaid == true) return 'Paid';
    if (selectedFilterIsPaid == false) return 'Unpaid';
    return 'All';
  }

  String get _activeFilterDescription {
    final status = selectedFilterIsPaid == null
        ? 'all bills'
        : selectedFilterIsPaid!
        ? 'paid bills'
        : 'unpaid bills';

    if (selectedPaidBacklogDate == null) return 'Showing $status.';
    return 'Showing $status paid on ${_dateFormat.format(selectedPaidBacklogDate!)}.';
  }

  DateTime? _parseDate(String? value) =>
      value == null ? null : DateTime.tryParse(value);

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  List<Bill> _filterAndSortBills(List<Bill> source) {
    final filtered = source.where((bill) {
      if (selectedFilterIsPaid != null) {
        final isPaid = bill.isPaid == 1;
        if (isPaid != selectedFilterIsPaid) return false;
      }

      if (selectedPaidBacklogDate != null) {
        final paidDate = _parseDate(bill.paidDate);
        if (paidDate == null) return false;
        return _isSameDate(paidDate, selectedPaidBacklogDate!);
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      if (a.isPaid != b.isPaid) return a.isPaid == 0 ? -1 : 1;

      if (a.isPaid == 1) {
        final aDate =
            _parseDate(a.paidDate) ?? _parseDate(a.dueDate) ?? DateTime(1900);
        final bDate =
            _parseDate(b.paidDate) ?? _parseDate(b.dueDate) ?? DateTime(1900);
        return bDate.compareTo(aDate);
      }

      final aDate = _parseDate(a.dueDate) ?? DateTime(9999);
      final bDate = _parseDate(b.dueDate) ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });

    return filtered;
  }

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

  void _setBillFilter(bool? isPaid) {
    setState(() {
      selectedFilterIsPaid = isPaid;
      if (isPaid == false) selectedPaidBacklogDate = null;
    });
  }

  void _openFilteredBillsSummary() {
    final filteredBills = _filteredBills;
    final title = '$_filterLabel Bills';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SummaryScreen(
          title: title,
          subtitle: _activeFilterDescription,
          summaryValue: _formatCurrency(_filteredTotalAmount),
          summaryLabel: 'Total amount',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF5B6CFF),
          bills: filteredBills,
          emptyMessage: 'No bills match the selected filter.',
        ),
      ),
    );
  }

  Future<void> _showBillFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Filter bills',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose which bills to show in the Bills section.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 18),
              _buildFilterOption(
                title: 'All bills',
                subtitle: '${bills.length} total bills',
                icon: Icons.receipt_long_rounded,
                selected: selectedFilterIsPaid == null,
                onTap: () {
                  Navigator.pop(context);
                  _setBillFilter(null);
                },
              ),
              _buildFilterOption(
                title: 'Paid bills',
                subtitle:
                    '${bills.where((bill) => bill.isPaid == 1).length} paid bills',
                icon: Icons.check_circle_outline_rounded,
                selected: selectedFilterIsPaid == true,
                onTap: () {
                  Navigator.pop(context);
                  _setBillFilter(true);
                },
              ),
              _buildFilterOption(
                title: 'Unpaid bills',
                subtitle:
                    '${bills.where((bill) => bill.isPaid == 0).length} unpaid bills',
                icon: Icons.pending_actions_rounded,
                selected: selectedFilterIsPaid == false,
                onTap: () {
                  Navigator.pop(context);
                  _setBillFilter(false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteBill(Bill bill) async {
    await dbHelper.deleteBill(bill.id!);
  }

  Future<void> _confirmDelete(Bill bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete "${bill.name}" from recent transactions?',
        ),
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

  Widget _buildBillCard(Bill bill) {
    final category =
        BillCategories.findById(bill.categoryId) ?? BillCategories.other;
    final isPaid = bill.isPaid == 1;

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
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isPaid
                      ? const Color(0xFFE9FBEE)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isPaid ? 'PAID' : 'UNPAID',
                  style: TextStyle(
                    color: isPaid
                        ? const Color(0xFF169B51)
                        : const Color(0xFFF97316),
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
                    isPaid ? 'Paid date' : 'Status',
                    isPaid && bill.paidDate != null
                        ? _formatDate(bill.paidDate!)
                        : 'Pending',
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
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildFilterOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppUi.primary.withValues(alpha: 0.10)
                : const Color(0xFFF6F8FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppUi.primary : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? AppUi.primary : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : AppUi.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: AppUi.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: InkWell(
        onTap: label == 'Filter'
            ? _showBillFilterSheet
            : _openFilteredBillsSummary,
        borderRadius: BorderRadius.circular(28),
        child: ModernStatCard(
          label: label,
          value: value,
          icon: icon,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredBills = _filteredBills;
    final latestFilteredBill = _latestFilteredBill;

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
                      subtitle:
                          'Review your paid history and recent transactions.',
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
                            _activeFilterDescription,
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
                                child: InkWell(
                                  onTap: _openFilteredBillsSummary,
                                  borderRadius: BorderRadius.circular(22),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatCurrency(_filteredTotalAmount),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Total bills',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: _openFilteredBillsSummary,
                                  borderRadius: BorderRadius.circular(22),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$_filteredBillsCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Bills found',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.calendar_month_rounded,
                                  ),
                                  label: Text(
                                    selectedPaidBacklogDate == null
                                        ? 'Pick date'
                                        : _dateFormat.format(
                                            selectedPaidBacklogDate!,
                                          ),
                                  ),
                                ),
                              ),
                              if (selectedPaidBacklogDate != null) ...[
                                const SizedBox(width: 10),
                                InkWell(
                                  onTap: () => setState(
                                    () => selectedPaidBacklogDate = null,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                    ),
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
                          latestFilteredBill?.name ?? 'None',
                          Icons.receipt_long_rounded,
                          const Color(0xFF5B6CFF),
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          'Filter',
                          _filterLabel,
                          Icons.tune_rounded,
                          const Color(0xFFEF4444),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SectionTitle(
                      title: 'Recent transactions',
                      subtitle: _activeFilterDescription,
                    ),
                    const SizedBox(height: 16),
                    if (filteredBills.isNotEmpty) ...[
                      ...filteredBills.map(_buildBillCard),
                    ] else
                      EmptyStateCard(
                        icon: Icons.archive_outlined,
                        title: 'No bills found',
                        subtitle:
                            'Try changing the filter or clearing the selected paid date.',
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
