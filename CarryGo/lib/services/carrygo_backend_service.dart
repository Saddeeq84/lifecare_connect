import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../constants/payment_config.dart';
import 'pricing_service.dart';

class CarryGoBackendService {
  Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> confirmDeliveryOtp({
    required String orderId,
    required String otp,
  }) async {
    if (!PaymentConfig.hasBackend) return false;

    final response = await http.post(
      Uri.parse('${PaymentConfig.paystackBackendBaseUrl}/confirmDeliveryOtp'),
      headers: await _headers(),
      body: jsonEncode({
        'orderId': orderId,
        'otp': otp,
      }),
    );

    if (response.statusCode >= 400) {
      throw StateError('Delivery confirmation failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['delivered'] == true;
  }

  Future<List<String>> initializeMvpCollections() async {
    if (!PaymentConfig.hasBackend) {
      throw StateError('Configure the Cloud Functions base URL first.');
    }

    final response = await http.post(
      Uri.parse(
        '${PaymentConfig.paystackBackendBaseUrl}/initializeMvpCollections',
      ),
      headers: await _headers(),
    );

    if (response.statusCode >= 400) {
      throw StateError(
          'MVP collection initialization failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return List<String>.from(data['collections'] as List? ?? const []);
  }

  Future<List<String>> initializePhase2Collections() async {
    if (!PaymentConfig.hasBackend) {
      throw StateError('Configure the Cloud Functions base URL first.');
    }

    final response = await http.post(
      Uri.parse(
        '${PaymentConfig.paystackBackendBaseUrl}/initializePhase2Collections',
      ),
      headers: await _headers(),
    );

    if (response.statusCode >= 400) {
      throw StateError(
          'Phase 2 collection initialization failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return List<String>.from(data['collections'] as List? ?? const []);
  }

  Future<List<String>> initializePhase3Collections() async {
    if (!PaymentConfig.hasBackend) {
      throw StateError('Configure the Cloud Functions base URL first.');
    }

    final response = await http.post(
      Uri.parse(
        '${PaymentConfig.paystackBackendBaseUrl}/initializePhase3Collections',
      ),
      headers: await _headers(),
    );

    if (response.statusCode >= 400) {
      throw StateError(
          'Phase 3 collection initialization failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return List<String>.from(data['collections'] as List? ?? const []);
  }

  Future<PricingResult?> calculateDeliveryFee({
    required String city,
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required String parcelSize,
    required String parcelWeight,
    required String urgency,
    required String condition,
  }) async {
    if (!PaymentConfig.hasBackend) return null;

    final response = await http.post(
      Uri.parse('${PaymentConfig.paystackBackendBaseUrl}/calculateDeliveryFee'),
      headers: await _headers(),
      body: jsonEncode({
        'city': city,
        'pickup_latitude': pickupLatitude,
        'pickup_longitude': pickupLongitude,
        'dropoff_latitude': dropoffLatitude,
        'dropoff_longitude': dropoffLongitude,
        'parcel_size': parcelSize,
        'parcel_weight': parcelWeight,
        'urgency': urgency,
        'condition': condition,
      }),
    );

    if (response.statusCode >= 400) {
      throw StateError('Fee calculation failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final total = (data['delivery_fee'] as num?)?.toDouble() ?? 0;
    final platformCommission =
        (data['platformCommission'] as num?)?.toDouble() ?? 0;
    final riderPayout = (data['riderPayout'] as num?)?.toDouble() ?? 0;
    final distanceKm = (data['distance_km'] as num?)?.toDouble() ?? 0;
    final baseFare = (data['baseFare'] as num?)?.toDouble() ?? 0;
    final distanceFee = (data['distanceFee'] as num?)?.toDouble() ?? 0;
    return PricingResult(
      baseFare: baseFare,
      distanceKm: distanceKm,
      distanceFee: distanceFee,
      sizeFee: (data['sizeFee'] as num?)?.toDouble() ?? 0,
      weightFee: (data['weightFee'] as num?)?.toDouble() ?? 0,
      urgencyMultiplier: (data['urgencyMultiplier'] as num?)?.toDouble() ?? 1,
      conditionMultiplier:
          (data['conditionMultiplier'] as num?)?.toDouble() ?? 1,
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? total,
      total: total,
      platformCommission: platformCommission,
      riderPayout: riderPayout,
    );
  }
}
