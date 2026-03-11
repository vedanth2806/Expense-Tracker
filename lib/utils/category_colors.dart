import 'package:flutter/material.dart';

class CategoryColors {
  // Fixed colors per category — consistent across every screen
  static const Map<String, Color> _colors = {
    'Food': Color(0xFFEF4444),           // Red
    'Basic amenities': Color(0xFFEC4899), // Pink
    'Transport': Color(0xFFF97316),       // Orange
    'Bills': Color(0xFF3B82F6),           // Blue
    'Entertainment': Color(0xFF8B5CF6),   // Purple
    'Shopping': Color(0xFFEAB308),        // Yellow
    'Healthcare': Color(0xFF14B8A6),      // Teal
    'Investment': Color(0xFF10B981),      // Green
    'Others': Color(0xFF6B7280),          // Gray
  };

  static const Color _fallback = Color(0xFF6366F1);

  /// Returns the fixed color for [category]. Falls back to indigo if unknown.
  static Color getColor(String category) =>
      _colors[category] ?? _fallback;

  /// All entries in the map, for building legends from scratch.
  static Map<String, Color> get all => _colors;
}
