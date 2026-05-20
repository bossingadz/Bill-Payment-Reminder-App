class Bill {
  int? id;
  String name;
  double amount;
  String dueDate;
  int isPaid;
  String? paidDate;
  String? categoryId;
  int reminderDays;

  Bill({
    this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    this.isPaid = 0,
    this.paidDate,
    this.categoryId,
    this.reminderDays = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'dueDate': dueDate,
      'isPaid': isPaid,
      'paidDate': paidDate,
      'categoryId': categoryId,
      'reminderDays': reminderDays,
    };
  }

  Map<String, dynamic> toFirestoreMap({required String userEmail}) {
    return {
      'id': id,
      'userEmail': userEmail,
      'name': name,
      'amount': amount,
      'dueDate': dueDate,
      'isPaid': isPaid,
      'paidDate': paidDate,
      'categoryId': categoryId,
      'reminderDays': reminderDays,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'],
      name: map['name'],
      amount: map['amount'],
      dueDate: map['dueDate'],
      isPaid: map['isPaid'],
      paidDate: map['paidDate'],
      categoryId: map['categoryId'],
      reminderDays: map['reminderDays'] ?? 1,
    );
  }
}