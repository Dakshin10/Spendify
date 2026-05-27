import '../models/transaction_model.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';

class SMSService {
  /// Fetches historical and incoming SMS messages from the device, requesting permissions,
  /// and filtering only financial transaction SMS.
  static Future<List<Map<String, dynamic>>> getInboxSMSMessages({int? sinceTimestamp}) async {
    // 1. Check and request SMS permission
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
    }
    if (!status.isGranted) {
      throw Exception("SMS permission is required to sync transactions.");
    }

    final Telephony telephony = Telephony.instance;
    List<SmsMessage> messages;
    try {
      messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      );
    } catch (e) {
      throw Exception("Failed to read SMS inbox: $e");
    }

    final List<Map<String, dynamic>> result = [];
    final List<String> financialSenders = [
      'HDFCBK', 'SBIINB', 'ICICIB', 'AXISBK', 'KOTAKB', 'PNBSMS', 'CBSSBI',
      'GPAYIN', 'PHONEP', 'PAYTMB', 'AMAZON', 'CREDIN', 'MOBIKW',
      'HDFC', 'SBI', 'ICICI', 'AXIS', 'KOTAK', 'PAYTM', 'PHONEPE', 'GPAY',
      'BHIM', 'CRED'
    ];

    for (var msg in messages) {
      final address = msg.address ?? "";
      final body = msg.body ?? "";
      final date = msg.date ?? 0;

      if (sinceTimestamp != null && date <= sinceTimestamp) {
        continue;
      }

      // 1. Filter by financial sender address
      final addrUpper = address.toUpperCase();
      final cleanAddress = addrUpper.contains('-') ? addrUpper.split('-').last : addrUpper;
      final isFinSender = financialSenders.any((sender) => cleanAddress.contains(sender));
      if (!isFinSender) continue;

      // 2. Filter out non-transactional patterns
      final bodyLower = body.toLowerCase();
      final isOtp = bodyLower.contains('otp') || bodyLower.contains('one time password') || bodyLower.contains('verification code');
      final isPromo = bodyLower.contains('cashback') || bodyLower.contains('reward') || bodyLower.contains('coupon') || bodyLower.contains('voucher') || bodyLower.contains('win');
      final isBal = bodyLower.contains('available balance') || bodyLower.contains('avl bal') || bodyLower.contains('mini statement');
      
      if (isOtp || isPromo || isBal) continue;

      // 3. Keep transactional messages
      final isTxn = bodyLower.contains('debited') ||
          bodyLower.contains('credited') ||
          bodyLower.contains('spent') ||
          bodyLower.contains('received') ||
          bodyLower.contains('payment') ||
          bodyLower.contains('withdrawn') ||
          bodyLower.contains('paid') ||
          bodyLower.contains('sent');

      if (!isTxn) continue;

      result.add({
        "sender": address,
        "body": body,
        "timestamp": date,
      });
    }

    return result;
  }
  /// Parses a raw SMS text message and returns a TransactionModel if it is a transaction.
  /// Returns null if the SMS does not match a financial transaction.
  static TransactionModel? parseSMS(String message, String sender) {
    final cleanedMsg = message.toLowerCase();
    
    // Check if it looks like a financial transaction
    final isDebit = _isDebit(cleanedMsg);
    final isCredit = _isCredit(cleanedMsg);
    
    if (!isDebit && !isCredit) {
      return null;
    }

    final String type = isDebit ? "DEBIT" : "CREDIT";

    // Extract amount
    final double? parsedAmount = _extractAmount(message);
    if (parsedAmount == null) return null;
    final String amount = parsedAmount.toStringAsFixed(2);

    // Extract merchant
    final String merchant = _extractMerchant(message, isDebit);

    // Extract payment mode
    final String paymentMode = _extractPaymentMode(cleanedMsg);

    // Extract bank name
    final String bank = _extractBank(sender, cleanedMsg);

    final String fingerprint = "local_${sender}_${amount}_${DateTime.now().millisecondsSinceEpoch}";
    return TransactionModel(
      fingerprint: fingerprint,
      amount: amount,
      merchant: merchant,
      category: 'Other',
      type: type,
      paymentMode: paymentMode,
      bank: bank,
      sender: sender,
      confidence: 90,
      autoAdded: 1,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      message: message,
    );
  }

  static bool _isDebit(String msg) {
    return msg.contains('spent') ||
        msg.contains('debited') ||
        msg.contains('charged') ||
        msg.contains('withdrawn') ||
        msg.contains('sent') ||
        msg.contains('paid');
  }

  static bool _isCredit(String msg) {
    return msg.contains('credited') ||
        msg.contains('received') ||
        msg.contains('deposited') ||
        msg.contains('added');
  }

  static double? _extractAmount(String msg) {
    // Regex to match things like Rs 250, Rs. 250.00, INR 120.50, ₹ 1,000.00, etc.
    final RegExp regExp = RegExp(
      r'(?:rs\.?|inr|₹)\s*([0-9,]+\.?[0-9]*)',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(msg);
    if (match != null) {
      final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
      return double.tryParse(amountStr);
    }
    return null;
  }

  static String _extractMerchant(String msg, bool isDebit) {
    // Check patterns like: "at [Merchant]", "to [Merchant]", "on [Merchant]"
    final RegExp atReg = RegExp(r'\b(?:at|to|on)\s+([A-Za-z0-9\s&]+?)(?:\s+from|\s+using|\s+via|\s+on|\s+ref|\s+txn|\.|\n|$)', caseSensitive: false);
    final match = atReg.firstMatch(msg);
    if (match != null) {
      final name = match.group(1)?.trim() ?? '';
      if (name.isNotEmpty && name.length < 30) {
        return _capitalize(name);
      }
    }
    return isDebit ? "Unknown Merchant" : "Salary/Sender";
  }

  static String _extractPaymentMode(String msg) {
    if (msg.contains('upi') || msg.contains('vpa')) {
      return "UPI";
    } else if (msg.contains('card') || msg.contains('credit card') || msg.contains('debit card')) {
      return "Card";
    } else if (msg.contains('bank transfer') || msg.contains('neft') || msg.contains('rtgs') || msg.contains('imps')) {
      return "Bank Transfer";
    } else {
      return "Cash";
    }
  }

  static String _extractBank(String sender, String msg) {
    final senderUpper = sender.toUpperCase();
    if (senderUpper.contains('HDFC')) return "HDFC Bank";
    if (senderUpper.contains('SBI')) return "SBI";
    if (senderUpper.contains('ICICI')) return "ICICI Bank";
    if (senderUpper.contains('AXIS')) return "Axis Bank";
    if (senderUpper.contains('KOTAK')) return "Kotak Bank";
    if (senderUpper.contains('FIMNY')) return "Fi Money";
    
    // Check message body
    if (msg.contains('hdfc')) return "HDFC Bank";
    if (msg.contains('sbi')) return "SBI";
    if (msg.contains('icici')) return "ICICI Bank";
    
    return "Bank";
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
