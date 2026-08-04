import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppDateUtils {
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return formatDate(date);
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  static String dateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}

/// Generate anonymous identity from uid + timestamp (same logic as website)
Map<String, String> generateAnonymousIdentity(
    String uid, int timestamp, List<String> names, List<String> colors) {
  final seed = uid + timestamp.toString();
  int hash = 0;
  for (int i = 0; i < seed.length; i++) {
    final char = seed.codeUnitAt(i);
    hash = (hash << 5) - hash + char;
    hash = hash & 0xFFFFFFFF; // Convert to 32-bit integer
  }
  final nameIndex = hash.abs() % names.length;
  final colorIndex = (hash.abs() >> 8) % colors.length;
  return {
    'name': names[nameIndex],
    'color': colors[colorIndex],
  };
}

Color hexToColor(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 6 || hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

String formatTimer(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
