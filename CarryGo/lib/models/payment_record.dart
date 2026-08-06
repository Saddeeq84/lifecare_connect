import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentRecord {
  final String reference;
  final String orderId;
  final String customerId;
  final String email;
  final int amountKobo;
  final String currency;
  final String status;
  final String provider;
  final String authorizationUrl;
  final double platformCommission;
  final double riderPayout;
  final String failureReason;

  const PaymentRecord({
    required this.reference,
    required this.orderId,
    required this.customerId,
    required this.email,
    required this.amountKobo,
    required this.currency,
    required this.status,
    required this.provider,
    required this.authorizationUrl,
    required this.platformCommission,
    required this.riderPayout,
    this.failureReason = '',
  });

  factory PaymentRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentRecord(
      reference: doc.id,
      orderId: data['orderId'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      email: data['email'] as String? ?? '',
      amountKobo: (data['amountKobo'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'NGN',
      status: data['status'] as String? ?? 'unknown',
      provider: data['provider'] as String? ?? 'paystack',
      authorizationUrl: data['authorizationUrl'] as String? ?? '',
      platformCommission: (data['platformCommission'] as num?)?.toDouble() ?? 0,
      riderPayout: (data['riderPayout'] as num?)?.toDouble() ?? 0,
      failureReason: data['failureReason'] as String? ?? '',
    );
  }
}
