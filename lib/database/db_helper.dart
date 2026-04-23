import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/bill.dart';

class DBHelper {
  static Database? _database;
  static List<Bill> _webBills = []; // For web fallback

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB();
    return _database!;
  }

  Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'bills.db');

    return await openDatabase(
      path,
      version: 3, // Increment version for migration
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE bills(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            amount REAL,
            dueDate TEXT,
            isPaid INTEGER,
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
      },
    );
  }

  Future<int> insertBill(Bill bill) async {
    if (kIsWeb) {
      bill.id = _webBills.length + 1;
      _webBills.add(bill);
      return 1;
    }
    final db = await database;
    return await db.insert('bills', bill.toMap());
  }

  Future<List<Bill>> getBills() async {
    if (kIsWeb) {
      return _webBills;
    }
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('bills');

    return maps.map((e) => Bill.fromMap(e)).toList();
  }

  Future<int> updateBill(Bill bill) async {
    if (kIsWeb) {
      final index = _webBills.indexWhere((b) => b.id == bill.id);
      if (index != -1) {
        _webBills[index] = bill;
        return 1;
      }
      return 0;
    }
    final db = await database;
    return await db.update(
      'bills',
      bill.toMap(),
      where: 'id = ?',
      whereArgs: [bill.id],
    );
  }

  Future<int> deleteBill(int id) async {
    if (kIsWeb) {
      _webBills.removeWhere((b) => b.id == id);
      return 1;
    }
    final db = await database;
    return await db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }
}