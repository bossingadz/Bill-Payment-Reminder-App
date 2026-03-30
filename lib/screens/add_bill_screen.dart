import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/bill.dart';
import '../services/notification_service.dart';

class AddBillScreen extends StatefulWidget {
  @override
  _AddBillScreenState createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final nameController = TextEditingController();
  final amountController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  final dbHelper = DBHelper();

  void saveBill() async {
  final bill = Bill(
    name: nameController.text,
    amount: double.parse(amountController.text),
    dueDate: selectedDate.toString(),
  );

  await dbHelper.insertBill(bill);

  final reminderDate = selectedDate.subtract(Duration(days: 1));

  await NotificationService.scheduleNotification(
    title: "Bill Reminder",
    body: "${nameController.text} is due tomorrow!",
    scheduledDate: reminderDate,
  );

  Navigator.pop(context);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Bill")),
      body: Column(
        children: [
          TextField(controller: nameController, decoration: InputDecoration(labelText: "Bill Name")),
          TextField(controller: amountController, decoration: InputDecoration(labelText: "Amount")),
          ElevatedButton(
            child: Text("Pick Date"),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => selectedDate = picked);
            },
          ),
          ElevatedButton(
            child: Text("Save"),
            onPressed: saveBill,
          ),
        ],
      ),
    );
  }
}