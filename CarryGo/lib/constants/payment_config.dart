class PaymentConfig {
  // Set this to your Firebase Cloud Functions base URL in production.
  // Example: https://us-central1-carrygo.cloudfunctions.net
  static const paystackBackendBaseUrl =
      'https://us-central1-carrygo-bf7cb.cloudfunctions.net';

  static bool get hasBackend => paystackBackendBaseUrl.trim().isNotEmpty;
}
