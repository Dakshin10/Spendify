import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static String getBackendUrl() {
    if (kIsWeb) {
      return 'http://localhost:8001';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8001';
    }
    return 'http://localhost:8001';
  }

  static Future<Map<String, dynamic>> uploadStatement({
    required List<int> fileBytes,
    required String fileName,
    required String bankName,
    String? password,
    List<String>? existingFingerprints,
  }) async {
    final baseUrl = getBackendUrl();
    final uri = Uri.parse('$baseUrl/upload');

    final request = http.MultipartRequest('POST', uri);

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
    );
    request.files.add(multipartFile);

    request.fields['bank_name'] = bankName;
    if (password != null && password.isNotEmpty) {
      request.fields['password'] = password;
    }
    if (existingFingerprints != null) {
      request.fields['existing_fingerprints'] = jsonEncode(existingFingerprints);
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded;
      } else {
        try {
          final decoded = jsonDecode(response.body);
          throw Exception(decoded['detail'] ?? 'Server error: ${response.statusCode}');
        } catch (_) {
          throw Exception('Server error: ${response.statusCode}\n${response.body}');
        }
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<Map<String, dynamic>> syncSms(List<Map<String, dynamic>> messages, bool autoAddEnabled) async {
    final baseUrl = getBackendUrl();
    final uri = Uri.parse('$baseUrl/sync-sms');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messages': messages,
          'auto_add_enabled': autoAddEnabled,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final decoded = jsonDecode(response.body);
          throw Exception(decoded['detail'] ?? 'Server error: ${response.statusCode}');
        } catch (_) {
          throw Exception('Server error: ${response.statusCode}\n${response.body}');
        }
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<Map<String, dynamic>> approveTransaction(String transactionId) async {
    final baseUrl = getBackendUrl();
    final uri = Uri.parse('$baseUrl/approve-transaction');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'transaction_id': transactionId}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<Map<String, dynamic>> ignoreTransaction(String transactionId) async {
    final baseUrl = getBackendUrl();
    final uri = Uri.parse('$baseUrl/ignore-transaction');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'transaction_id': transactionId}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<Map<String, dynamic>> clearBackendTransactions() async {
    final baseUrl = getBackendUrl();
    final uri = Uri.parse('$baseUrl/clear-transactions');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }
}
