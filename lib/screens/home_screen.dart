import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/bill.dart';
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

  @override
  void initState() {
    super.initState();
    loadBills();
  }

  Future<void> loadBills() async {
    setState(() {
      isLoading = true;
    });

    bills = await dbHelper.getBills();

    setState(() {
      isLoading = false;
    });
  }

  Future<void> togglePaid(Bill bill) async {
    bill.isPaid = bill.isPaid == 1 ? 0 : 1;
    await dbHelper.updateBill(bill);
    loadBills();
  }

  Widget _buildBillCard(Bill bill) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          bill.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text('Amount: ₱${bill.amount.toStringAsFixed(2)}'),
            Text('Due: ${bill.dueDate.split(' ')[0]}'),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            bill.isPaid == 1
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: bill.isPaid == 1 ? Colors.green : Colors.grey,
          ),
          onPressed: () => togglePaid(bill),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bill Reminder')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : bills.isEmpty
                ? const Center(child: Text('No bills yet. Add one to get started.'))
                : ListView.builder(
                    itemCount: bills.length,
                    itemBuilder: (context, index) {
                      final bill = bills[index];
                      return _buildBillCard(bill);
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddBillScreen()),
          );
          loadBills();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Bill'),
      ),
    );
  }
}
