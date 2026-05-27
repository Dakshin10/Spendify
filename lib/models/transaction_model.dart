class TransactionModel {
  final String? id;
  final String fingerprint;
  final String amount;
  final String merchant;
  final String category;
  final String type;
  final String paymentMode;
  final String bank;
  final String sender;
  final int confidence;
  final int autoAdded;
  final int timestamp;
  final String message;

  TransactionModel({
    this.id,
    required this.fingerprint,
    required this.amount,
    required this.merchant,
    required this.category,
    required this.type,
    required this.paymentMode,
    required this.bank,
    required this.sender,
    required this.confidence,
    required this.autoAdded,
    required this.timestamp,
    required this.message,
  });

  String get transactionType => type.toLowerCase();
  String get bankSource => bank;
  String get sourceType => sender;

  factory TransactionModel.fromMap(Map<dynamic, dynamic> map) {
    // Resolve flexible types and sources
    final rawType = map['type']?.toString() ?? map['transactionType']?.toString() ?? map['transaction_type']?.toString() ?? '';
    final rawBank = map['bank']?.toString() ?? map['bankSource']?.toString() ?? map['bank_source']?.toString() ?? '';
    final rawSender = map['sender']?.toString() ?? map['sourceType']?.toString() ?? map['source_type']?.toString() ?? '';

    return TransactionModel(
      id: map['id']?.toString(),
      fingerprint: map['fingerprint']?.toString() ?? '',
      amount: map['amount']?.toString() ?? '',
      merchant: map['merchant']?.toString() ?? '',
      category: map['category']?.toString() ?? 'Other',
      type: rawType,
      paymentMode: map['paymentMode']?.toString() ?? '',
      bank: rawBank,
      sender: rawSender,
      confidence: map['confidence'] is int ? map['confidence'] : int.tryParse(map['confidence']?.toString() ?? '0') ?? 0,
      autoAdded: map['autoAdded'] is int ? map['autoAdded'] : int.tryParse(map['autoAdded']?.toString() ?? '1') ?? 1,
      timestamp: map['timestamp'] is int ? map['timestamp'] : int.tryParse(map['timestamp']?.toString() ?? '0') ?? 0,
      message: map['message']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fingerprint': fingerprint,
      'amount': amount,
      'merchant': merchant,
      'category': category,
      'type': type,
      'paymentMode': paymentMode,
      'bank': bank,
      'sender': sender,
      'confidence': confidence,
      'autoAdded': autoAdded,
      'timestamp': timestamp,
      'message': message,
    };
  }
}