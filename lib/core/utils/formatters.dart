import 'package:flutter/services.dart';

String formatIndianRupees(double value) {
  final valStr = value.toStringAsFixed(0);
  final clean = valStr.replaceAll(RegExp(r'\D'), '');
  if (clean.isEmpty) return "0";
  int len = clean.length;
  if (len <= 3) return clean;
  final last3 = clean.substring(len - 3);
  final remaining = clean.substring(0, len - 3);
  final List<String> chunks = [];
  int i = remaining.length;
  while (i > 0) {
    if (i >= 2) {
      chunks.insert(0, remaining.substring(i - 2, i));
      i -= 2;
    } else {
      chunks.insert(0, remaining.substring(0, i));
      break;
    }
  }
  return "${chunks.join(',')},$last3";
}

double parseFormattedAmount(String text) {
  final clean = text.replaceAll(RegExp(r'\D'), '');
  return double.tryParse(clean) ?? 0.0;
}
