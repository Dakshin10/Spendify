import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/state/app_state.dart';
import '../models/transaction_model.dart';
import 'api_service.dart';
import 'sms_service.dart';
import 'notification_service.dart';

class TransactionSyncService {
  static const String _syncKey = "last_sms_sync_timestamp";

  /// Synchronizes SMS messages with the FastAPI backend, deduplicates them,
  /// maps response items, and writes them to the local SQLite database.
  static Future<Map<String, dynamic>> syncTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int lastSyncTimestamp = prefs.getInt(_syncKey) ?? 0;

      // 1. Get filtered transactional SMS messages from the device
      final List<Map<String, dynamic>> messages = 
          await SMSService.getInboxSMSMessages(sinceTimestamp: lastSyncTimestamp);

      if (messages.isEmpty) {
        return {
          "status": "success",
          "syncedCount": 0,
          "message": "Already up to date."
        };
      }

      // 2. Send messages to FastAPI /sync-sms endpoint with the auto-add setting
      final autoAddEnabled = AppState.instance.autoAddTransactions;
      final Map<String, dynamic> response = await ApiService.syncSms(messages, autoAddEnabled);
      
      if (response["status"] != "success") {
        throw Exception(response["message"] ?? "API returned non-success response.");
      }

      // 3. Map API response data to TransactionModel
      final List<dynamic> data = response["data"] ?? [];
      final List<TransactionModel> newTransactions = [];

      for (var item in data) {
        final tx = TransactionModel(
          id: item["id"]?.toString(),
          fingerprint: item["fingerprint"] ?? '',
          amount: item["amount"] ?? "0.00",
          merchant: item["merchant"] ?? "Unknown Merchant",
          type: item["type"] ?? "DEBIT",
          paymentMode: item["paymentMode"] ?? "UPI",
          bank: item["bank"] ?? "Bank",
          sender: item["sender"] ?? "SMS",
          confidence: item["confidence"] ?? 90,
          autoAdded: item["auto_added"] is int ? item["auto_added"] : int.tryParse(item["auto_added"]?.toString() ?? '1') ?? 1,
          timestamp: item["timestamp"] ?? DateTime.now().millisecondsSinceEpoch,
          message: item["message"] ?? "",
          category: item["category"] ?? "Other",
        );
        newTransactions.add(tx);
      }

      // 4. Batch insert new transactions locally and trigger state reload
      if (newTransactions.isNotEmpty) {
        await AppState.instance.addTransactions(newTransactions);
        
        // Save category overrides if any
        for (int i = 0; i < newTransactions.length; i++) {
          final tx = newTransactions[i];
          final apiTx = data[i];
          final String? category = apiTx["category"];
          if (category != null && category.isNotEmpty && tx.id != null) {
            await AppState.instance.setCategoryOverride(tx.id!, category);
          }
          
          // 5. Trigger passive or actionable notification for each synced transaction
          if (tx.id != null) {
            await NotificationService.showTransactionNotification(
              id: tx.id!,
              title: tx.autoAdded == 1 ? "Transaction Auto-Added" : "Transaction Detected",
              body: "₹${tx.amount} spent at ${tx.merchant}",
              autoAdded: tx.autoAdded == 1,
            );
          }
        }
      }

      // 6. Update the last sync timestamp to the latest timestamp in the messages
      int maxTimestamp = lastSyncTimestamp;
      for (var msg in messages) {
        final int ts = msg["timestamp"] ?? 0;
        if (ts > maxTimestamp) {
          maxTimestamp = ts;
        }
      }
      await prefs.setInt(_syncKey, maxTimestamp);

      return {
        "status": "success",
        "syncedCount": newTransactions.length,
        "message": "Successfully synchronized ${newTransactions.length} new transactions."
      };
    } catch (e) {
      debugPrint("Transaction sync failed: $e");
      rethrow;
    }
  }
}
