import '../models/transaction_model.dart';

class SMSService {
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

    return TransactionModel(
      amount: amount,
      merchant: merchant,
      type: type,
      paymentMode: paymentMode,
      bank: bank,
      sender: sender,
      confidence: 90,
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

  /// Generates a list of mock SMS strings to simulate ingestion
  static List<Map<String, String>> getMockSMSList() {
    return [
      {
        "sender": "AD-HDFCBK",
        "message": "Alert: Your HDFC Bank Card ending 4321 spent Rs. 250.00 at Coffee & Snacks on 23-May-2026. Avail. Limit: Rs. 94,800.00."
      },
      {
        "sender": "VK-SBIUPI",
        "message": "Your a/c no. XXX1234 is debited by Rs. 110.00 on 23-May-2026 by transfer to Uber Ride via UPI (Ref: 612847192)."
      },
      {
        "sender": "AD-ICICIB",
        "message": "Transaction Alert: Rs 200.00 debited from ICICI Bank account for BigBasket order using Credit Card."
      },
      {
        "sender": "AD-FIMNY",
        "message": "Rs. 200.00 spent at Sneakers using Fi Money Debit Card. Track your spends on the Spendify App!"
      },
      {
        "sender": "AD-HDFCBK",
        "message": "Dear Customer, Rs. 300.00 was paid using UPI to Lunch with Team from your HDFC account on 22-May-2026."
      },
      {
        "sender": "VK-SBIUPI",
        "message": "Dear User, Rs 100.00 debited from your account to Starbucks Coffee via UPI."
      },
      {
        "sender": "AD-ICICIB",
        "message": "Transaction Alert: Your ICICI Bank account has been credited with Rs. 10,000.00 on 20-May-2026 for Monthly Salary."
      },
      {
        "sender": "VK-KOTAK",
        "message": "Charged: Rs. 50.00 was spent at Uber Ride from your Kotak Bank account ending 9876."
      }
    ];
  }
}
