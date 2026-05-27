class TransactionModel {

  final int? id;

  final String amount;
  final String merchant;
  final String type;
  final String paymentMode;
  final String bank;
  final String sender;
  final int confidence;
  final int timestamp;
  final String message;

  TransactionModel({

    this.id,

    required this.amount,
    required this.merchant,
    required this.type,
    required this.paymentMode,
    required this.bank,
    required this.sender,
    required this.confidence,
    required this.timestamp,
    required this.message,
  });

  factory TransactionModel.fromMap(
      Map<dynamic, dynamic> map) {

    return TransactionModel(

      id: map['id'],

      amount: map['amount'] ?? '',
      merchant: map['merchant'] ?? '',
      type: map['type'] ?? '',
      paymentMode: map['paymentMode'] ?? '',
      bank: map['bank'] ?? '',
      sender: map['sender'] ?? '',
      confidence: map['confidence'] ?? 0,
      timestamp: map['timestamp'] ?? 0,
      message: map['message'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {

    return {

      'id': id,
      'amount': amount,
      'merchant': merchant,
      'type': type,
      'paymentMode': paymentMode,
      'bank': bank,
      'sender': sender,
      'confidence': confidence,
      'timestamp': timestamp,
      'message': message,
    };
  }
}