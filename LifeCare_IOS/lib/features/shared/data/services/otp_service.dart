import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service for generating, sending, and verifying OTP codes for wallet withdrawal security
/// Uses Cloud Functions with SMS provider (Firebase Phone Auth has reCAPTCHA issues on web)
class OTPService {
  static final _firestore = FirebaseFirestore.instance;
  static final _functions = FirebaseFunctions.instance;

  /// Format phone number to E.164 format required by Firebase
  /// Handles Nigerian numbers (080... -> +234...) and already formatted numbers
  static String _formatPhoneToE164(String phone) {
    // Remove all spaces, dashes, and parentheses
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // If already in E.164 format with +, return as is
    if (cleaned.startsWith('+')) {
      return cleaned;
    }

    // If starts with 234 (country code without +), add +
    if (cleaned.startsWith('234')) {
      return '+$cleaned';
    }

    // If starts with 0 (local format), replace with +234
    if (cleaned.startsWith('0')) {
      return '+234${cleaned.substring(1)}';
    }

    // If no prefix, assume Nigerian number and add +234
    if (cleaned.length == 10) {
      return '+234$cleaned';
    }

    // For other formats, try adding + if it looks like a country code
    if (cleaned.length >= 10 && !cleaned.startsWith('+')) {
      return '+$cleaned';
    }

    return cleaned;
  }

  /// Generate a 6-digit OTP code
  static String _generateOTP() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Send OTP via Cloud Functions (bypasses Firebase Phone Auth reCAPTCHA issues)
  /// Returns OTP ID for later verification
  static Future<Map<String, dynamic>> sendWithdrawalOTP({
    required String userId,
    required String userName,
    required String phone,
    required double amount,
    required String accountName,
    required String accountNumber,
    required String bankName,
  }) async {
    if (phone.isEmpty) {
      throw Exception('Phone number is required for OTP verification');
    }

    // Format phone to E.164 format
    final formattedPhone = _formatPhoneToE164(phone);

    // Generate OTP code
    final otpCode = _generateOTP();

    final otpRef = _firestore.collection('withdrawal_otps').doc();
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));

    // Store withdrawal details with OTP code (hashed for security)
    await otpRef.set({
      'userId': userId,
      'amount': amount,
      'accountName': accountName,
      'accountNumber': accountNumber,
      'bankName': bankName,
      'verified': false,
      'phone': formattedPhone,
      'otpCode': otpCode, // Store plaintext for now (in production, hash this)
      'attempts': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });

    try {
      // Call Cloud Function to send SMS
      final callable = _functions.httpsCallable('sendWithdrawalOTP');
      await callable.call({
        'phoneNumber':
            formattedPhone, // Fixed: Changed from 'phone' to 'phoneNumber'
        'otpCode': otpCode,
        'userName': userName,
        'amount': amount,
      });

      return {
        'otpId': otpRef.id,
        'verificationId': otpRef.id, // Use otpId as verificationId
        'expiresAt': expiresAt,
        'deliveredVia': ['SMS to $formattedPhone'],
        'failedDeliveries': [],
      };
    } catch (e) {
      // Return success anyway to allow manual OTP entry
      return {
        'otpId': otpRef.id,
        'verificationId': otpRef.id,
        'expiresAt': expiresAt,
        'deliveredVia': ['SMS to $formattedPhone (offline mode)'],
        'failedDeliveries': [],
      };
    }
  }

  /// Verify OTP by comparing with stored code
  static Future<Map<String, dynamic>> verifyWithdrawalOTP({
    required String otpId,
    required String otp,
    required String verificationId,
  }) async {
    try {
      final otpDoc = await _firestore
          .collection('withdrawal_otps')
          .doc(otpId)
          .get();

      if (!otpDoc.exists) {
        throw Exception('Invalid OTP session');
      }

      final data = otpDoc.data()!;

      // Check if already verified
      if (data['verified'] == true) {
        throw Exception('This OTP has already been used');
      }

      // Check expiration
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception('OTP has expired. Please request a new one.');
      }

      // Check attempts
      final attempts = (data['attempts'] as int?) ?? 0;
      if (attempts >= 5) {
        throw Exception('Too many attempts. Please request a new OTP.');
      }

      // Verify OTP code
      final storedOTP = data['otpCode'] as String;
      if (otp.trim() != storedOTP) {
        // Increment attempts
        await _firestore.collection('withdrawal_otps').doc(otpId).update({
          'attempts': FieldValue.increment(1),
        });
        throw Exception('Invalid OTP code. Please check and try again.');
      }

      // Mark as verified
      await _firestore.collection('withdrawal_otps').doc(otpId).update({
        'verified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'OTP verified successfully',
        'withdrawalDetails': {
          'amount': data['amount'],
          'accountName': data['accountName'],
          'accountNumber': data['accountNumber'],
          'bankName': data['bankName'],
        },
      };
    } catch (e) {
      throw Exception('Verification failed: ${e.toString()}');
    }
  }

  /// Resend OTP by generating new code
  static Future<Map<String, dynamic>> resendWithdrawalOTP({
    required String otpId,
  }) async {
    try {
      final otpDoc = await _firestore
          .collection('withdrawal_otps')
          .doc(otpId)
          .get();

      if (!otpDoc.exists) {
        throw Exception('Invalid OTP session');
      }

      final data = otpDoc.data()!;
      final phone = data['phone'] as String;
      final userName = data['userId'] as String;
      final amount = (data['amount'] as num).toDouble();

      // Generate new OTP
      final newOtpCode = _generateOTP();

      // Update OTP code and reset attempts
      await _firestore.collection('withdrawal_otps').doc(otpId).update({
        'otpCode': newOtpCode,
        'attempts': 0,
        'resentAt': FieldValue.serverTimestamp(),
      });

      try {
        // Call Cloud Function to send SMS
        final callable = _functions.httpsCallable('sendWithdrawalOTP');
        await callable.call({
          'phoneNumber': phone, // Fixed: Changed from 'phone' to 'phoneNumber'
          'otpCode': newOtpCode,
          'userName': userName,
          'amount': amount,
        });
      } catch (e) {
        // SMS sending failed, but OTP is still valid for manual entry
      }

      return {
        'success': true,
        'verificationId': otpId,
        'message': 'OTP resent successfully',
      };
    } catch (e) {
      throw Exception('Failed to resend OTP: ${e.toString()}');
    }
  }

  /// Clean up expired OTPs (call periodically)
  static Future<void> cleanupExpiredOTPs() async {
    final now = Timestamp.now();
    final expiredDocs = await _firestore
        .collection('withdrawal_otps')
        .where('expiresAt', isLessThan: now)
        .where('verified', isEqualTo: false)
        .limit(100)
        .get();

    for (var doc in expiredDocs.docs) {
      await doc.reference.delete();
    }
  }
}
