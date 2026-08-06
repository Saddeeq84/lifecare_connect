import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../constants/payment_config.dart';
import '../models/order.dart';

class PaystackInitResult {
  final String reference;
  final String authorizationUrl;
  final String accessCode;
  final bool demoMode;

  const PaystackInitResult({
    required this.reference,
    required this.authorizationUrl,
    required this.accessCode,
    required this.demoMode,
  });
}

class PaystackVerifyResult {
  final bool success;
  final String status;
  final String message;

  const PaystackVerifyResult({
    required this.success,
    required this.status,
    required this.message,
  });
}

class PaystackService {
  Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<PaystackInitResult> initializeTransaction({
    required Order order,
    required String email,
    String? riderSubaccount,
  }) async {
    final reference = 'CG-${DateTime.now().millisecondsSinceEpoch}-${order.id}';

    if (!PaymentConfig.hasBackend) {
      return PaystackInitResult(
        reference: reference,
        authorizationUrl: 'https://checkout.paystack.com/demo-$reference',
        accessCode: 'demo-access-code',
        demoMode: true,
      );
    }

    final response = await http.post(
      Uri.parse(
        '${PaymentConfig.paystackBackendBaseUrl}/initializePaystackPayment',
      ),
      headers: await _headers(),
      body: jsonEncode({
        'orderId': order.id,
        'email': email,
        'riderSubaccount': riderSubaccount,
      }),
    );

    if (response.statusCode >= 400) {
      throw StateError('Paystack initialization failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return PaystackInitResult(
      reference: data['reference'] as String? ?? reference,
      authorizationUrl: data['authorizationUrl'] as String? ?? '',
      accessCode: data['accessCode'] as String? ?? '',
      demoMode: false,
    );
  }

  Future<PaystackInitResult> initializeWalletTopup({
    required double amount,
    required String email,
    required String walletRole,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final reference = 'CGW-${DateTime.now().millisecondsSinceEpoch}-$userId';

    if (!PaymentConfig.hasBackend) {
      return PaystackInitResult(
        reference: reference,
        authorizationUrl: 'https://checkout.paystack.com/demo-$reference',
        accessCode: 'demo-access-code',
        demoMode: true,
      );
    }

    final response = await http.post(
      Uri.parse(
          '${PaymentConfig.paystackBackendBaseUrl}/initializeWalletTopup'),
      headers: await _headers(),
      body: jsonEncode({
        'amount': amount,
        'email': email,
        'walletRole': walletRole,
      }),
    );

    if (response.statusCode >= 400) {
      throw StateError('Wallet top-up initialization failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return PaystackInitResult(
      reference: data['reference'] as String? ?? reference,
      authorizationUrl: data['authorizationUrl'] as String? ?? '',
      accessCode: data['accessCode'] as String? ?? '',
      demoMode: false,
    );
  }

  Future<PaystackVerifyResult> verifyWalletTopup(String reference) async {
    if (!PaymentConfig.hasBackend) {
      return const PaystackVerifyResult(
        success: true,
        status: 'success',
        message: 'Demo wallet top-up accepted.',
      );
    }

    final response = await http.get(
      Uri.parse(
        '${PaymentConfig.paystackBackendBaseUrl}/verifyWalletTopup'
        '?reference=$reference',
      ),
      headers: await _headers(),
    );

    if (response.statusCode >= 400) {
      return PaystackVerifyResult(
        success: false,
        status: 'failed',
        message: response.body,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'failed';
    return PaystackVerifyResult(
      success: status == 'success',
      status: status,
      message: data['message'] as String? ?? '',
    );
  }

  Future<PaystackVerifyResult> verifyTransaction(String reference) async {
    if (!PaymentConfig.hasBackend) {
      return const PaystackVerifyResult(
        success: true,
        status: 'success',
        message: 'Demo verification accepted. Configure backend for live mode.',
      );
    }

    final response = await http.get(
      Uri.parse(
        '${PaymentConfig.paystackBackendBaseUrl}/verifyPaystackPayment'
        '?reference=$reference',
      ),
      headers: await _headers(),
    );

    if (response.statusCode >= 400) {
      return PaystackVerifyResult(
        success: false,
        status: 'failed',
        message: response.body,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'failed';
    return PaystackVerifyResult(
      success: status == 'success',
      status: status,
      message: data['message'] as String? ?? '',
    );
  }
}
