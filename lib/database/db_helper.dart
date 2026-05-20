import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/bill.dart';
import '../services/auth_service.dart';

class DBHelper {
  static Database? _database;
  static final List<Bill> _webBills = []; // For web fallback
  static final StreamController<void> _localBillsChangedController =
      StreamController<void>.broadcast();

  String? get _currentUserEmail {
    final email = AuthService.currentUser?.email?.trim().toLowerCase();
    return email == null || email.isEmpty ? null : email;
  }

  CollectionReference<Map<String, dynamic>> _userBillsCollection(String email) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('bills');
  }

  Stream<List<Bill>> watchBills() {
    final email = _currentUserEmail;
    if (email != null) {
      return _userBillsCollection(email).snapshots().map((snapshot) {
        final bills = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] ??= int.tryParse(doc.id);
          return Bill.fromMap(data);
        }).toList();

        bills.sort(
          (a, b) => DateTime.parse(a.dueDate).compareTo(DateTime.parse(b.dueDate)),
        );
        return bills;
      });
    }

    return _watchLocalBills();
  }

  Stream<List<Bill>> _watchLocalBills() async* {
    yield await getBills();
    yield* _localBillsChangedController.stream.asyncMap((_) => getBills());
  }

  void _notifyLocalBillsChanged() {
    if (!_localBillsChangedController.isClosed) {
      _localBillsChangedController.add(null);
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB();
    return _database!;
  }

  Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'bills.db');

    return await openDatabase(
      path,
      version: 4, // Increment version for migration
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE bills(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            amount REAL,
            dueDate TEXT,
            isPaid INTEGER,
            paidDate TEXT,
            categoryId TEXT,
            reminderDays INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE bills ADD COLUMN categoryId TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE bills ADD COLUMN reminderDays INTEGER DEFAULT 1');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE bills ADD COLUMN paidDate TEXT');
        }
      },
    );
  }

  Future<int> insertBill(Bill bill) async {
    final email = _currentUserEmail;
    if (email != null) {
      bill.id ??= DateTime.now().microsecondsSinceEpoch;
      await _userBillsCollection(email)
          .doc(bill.id.toString())
          .set(bill.toFirestoreMap(userEmail: email));
      return 1;
    }

    if (kIsWeb) {
      bill.id = _webBills.length + 1;
      _webBills.add(bill);
      _notifyLocalBillsChanged();
      return 1;
    }
    final db = await database;
    final result = await db.insert('bills', bill.toMap());
    _notifyLocalBillsChanged();
    return result;
  }

  Future<List<Bill>> getBills() async {
    final email = _currentUserEmail;
    if (email != null) {
      final snapshot = await _userBillsCollection(email).get();
      final bills = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] ??= int.tryParse(doc.id);
        return Bill.fromMap(data);
      }).toList();

      bills.sort(
        (a, b) => DateTime.parse(a.dueDate).compareTo(DateTime.parse(b.dueDate)),
      );
      return bills;
    }

    if (kIsWeb) {
      return _webBills;
    }
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('bills');

    return maps.map((e) => Bill.fromMap(e)).toList();
  }

  Future<int> updateBill(Bill bill) async {
    final email = _currentUserEmail;
    if (email != null && bill.id != null) {
      await _userBillsCollection(email)
          .doc(bill.id.toString())
          .set(bill.toFirestoreMap(userEmail: email), SetOptions(merge: true));
      return 1;
    }

    if (kIsWeb) {
      final index = _webBills.indexWhere((b) => b.id == bill.id);
      if (index != -1) {
        _webBills[index] = bill;
        _notifyLocalBillsChanged();
        return 1;
      }
      return 0;
    }
    final db = await database;
    final result = await db.update(
      'bills',
      bill.toMap(),
      where: 'id = ?',
      whereArgs: [bill.id],
    );
    _notifyLocalBillsChanged();
    return result;
  }

  Future<int> deleteBill(int id) async {
    final email = _currentUserEmail;
    if (email != null) {
      await _userBillsCollection(email).doc(id.toString()).delete();
      return 1;
    }

    if (kIsWeb) {
      _webBills.removeWhere((b) => b.id == id);
      _notifyLocalBillsChanged();
      return 1;
    }
    final db = await database;
    final result = await db.delete('bills', where: 'id = ?', whereArgs: [id]);
    _notifyLocalBillsChanged();
    return result;
  }
}