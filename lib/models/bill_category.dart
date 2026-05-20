// bill_category.dart
import 'package:flutter/material.dart';

class BillCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final Color lightColor;

  const BillCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.lightColor,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };
}

class BillCategories {
  static const List<BillCategory> all = [
    BillCategory(
      id: 'utilities',
      name: 'Utilities',
      icon: Icons.bolt_outlined,
      color: Color(0xFFF59E0B),
      lightColor: Color(0xFFFEF3C7),
    ),
    BillCategory(
      id: 'rent',
      name: 'Rent',
      icon: Icons.home_outlined,
      color: Color(0xFF6C63FF),
      lightColor: Color(0xFFEEEDFE),
    ),
    BillCategory(
      id: 'subscriptions',
      name: 'Subscriptions',
      icon: Icons.subscriptions_outlined,
      color: Color(0xFFEC4899),
      lightColor: Color(0xFFFCE7F3),
    ),
    BillCategory(
      id: 'insurance',
      name: 'Insurance',
      icon: Icons.shield_outlined,
      color: Color(0xFF10B981),
      lightColor: Color(0xFFD1FAE5),
    ),
    BillCategory(
      id: 'internet',
      name: 'Internet',
      icon: Icons.wifi_outlined,
      color: Color(0xFF3B82F6),
      lightColor: Color(0xFFDBEAFE),
    ),
    BillCategory(
      id: 'phone',
      name: 'Phone',
      icon: Icons.phone_android_outlined,
      color: Color(0xFF8B5CF6),
      lightColor: Color(0xFFEDE9FE),
    ),
    BillCategory(
      id: 'water',
      name: 'Water',
      icon: Icons.water_drop_outlined,
      color: Color(0xFF06B6D4),
      lightColor: Color(0xFFCFFAFE),
    ),
    BillCategory(
      id: 'groceries',
      name: 'Groceries',
      icon: Icons.shopping_cart_outlined,
      color: Color(0xFF22C55E),
      lightColor: Color(0xFFDCFCE7),
    ),
    BillCategory(
      id: 'transport',
      name: 'Transport',
      icon: Icons.directions_car_outlined,
      color: Color(0xFFF97316),
      lightColor: Color(0xFFFFEDD5),
    ),
    BillCategory(
      id: 'health',
      name: 'Health',
      icon: Icons.favorite_outline,
      color: Color(0xFFEF4444),
      lightColor: Color(0xFFFEE2E2),
    ),
    BillCategory(
      id: 'education',
      name: 'Education',
      icon: Icons.school_outlined,
      color: Color(0xFF0EA5E9),
      lightColor: Color(0xFFE0F2FE),
    ),
    BillCategory(
      id: 'other',
      name: 'Other',
      icon: Icons.more_horiz,
      color: Color(0xFF6B7280),
      lightColor: Color(0xFFF3F4F6),
    ),
  ];

  static BillCategory? findById(String? id) {
    if (id == null) return null;
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  static BillCategory get other =>
      all.firstWhere((c) => c.id == 'other');
}