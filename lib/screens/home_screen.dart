import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/bill.dart';
import 'add_bill_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Bill> bills = [];
  final dbHelper = DBHelper();

  @override
  void initState() {
    super.initState();
    loadBills();
  }

  void loadBills() async {
    bills = await dbHelper.getBills();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bill Reminder")),
      body: ListView.builder(
        itemCount: bills.length,
        itemBuilder: (context, index) {
          final bill = bills[index];
          return ListTile(
            title: Text(bill.name),
            subtitle: Text("Due: ${bill.dueDate}"),
            trailing: IconButton(
              icon: Icon(Icons.check),
              onPressed: () async {
                bill.isPaid = 1;
                await dbHelper.updateBill(bill);
                loadBills();
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddBillScreen()),
          );
          loadBills();
        },
      ),
    );
  }
}