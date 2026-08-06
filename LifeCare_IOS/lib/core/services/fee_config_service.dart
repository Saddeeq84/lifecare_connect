import 'package:cloud_firestore/cloud_firestore.dart';

/// Dynamic Fee Configuration Service
///
/// Fetches fee configuration from Firestore instead of using hardcoded constants.
/// Falls back to default values if Firestore config doesn't exist.
class FeeConfigService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Map<String, dynamic>? _cachedConfig;
  static DateTime? _lastFetch;
  static const Duration _cacheExpiration = Duration(minutes: 5);

  /// Get current fee configuration from Firestore
  /// Uses caching to reduce Firestore reads
  static Future<Map<String, dynamic>> getFeeConfig() async {
    // Return cached config if still valid
    if (_cachedConfig != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheExpiration) {
      return _cachedConfig!;
    }

    try {
      final doc = await _firestore
          .collection('app_configuration')
          .doc('fee_structure')
          .get();

      if (doc.exists) {
        _cachedConfig = doc.data();
        _lastFetch = DateTime.now();
        return _cachedConfig!;
      } else {
        // Return default configuration
        return _getDefaultConfig();
      }
    } catch (e) {
      print('Error fetching fee config: $e');
      // Return default on error
      return _getDefaultConfig();
    }
  }

  /// Force refresh the cached configuration
  static Future<void> refreshConfig() async {
    _cachedConfig = null;
    _lastFetch = null;
    await getFeeConfig();
  }

  /// Get a specific fee value
  static Future<double> getFee(String feeKey) async {
    final config = await getFeeConfig();
    return (config[feeKey] as num?)?.toDouble() ?? 0.0;
  }

  /// Get provider share percentage (default 70%)
  static Future<double> getProviderSharePercentage() async {
    final config = await getFeeConfig();
    return (config['providerSharePercentage'] as num?)?.toDouble() ?? 70.0;
  }

  /// Get admin share percentage (default 30%)
  static Future<double> getAdminSharePercentage() async {
    final config = await getFeeConfig();
    return (config['adminSharePercentage'] as num?)?.toDouble() ?? 30.0;
  }

  /// Get remote doctor share percentage (default 70%)
  static Future<double> getRemoteDoctorSharePercentage() async {
    final config = await getFeeConfig();
    return (config['remoteDoctorSharePercentage'] as num?)?.toDouble() ?? 70.0;
  }

  /// Get remote facility share percentage (default 30%)
  static Future<double> getRemoteFacilitySharePercentage() async {
    final config = await getFeeConfig();
    return (config['remoteFacilitySharePercentage'] as num?)?.toDouble() ??
        30.0;
  }

  /// Get CHW free appointment quota (default 3)
  static Future<int> getCHWFreeQuota() async {
    final config = await getFeeConfig();
    return config['chwFreeAppointmentQuota'] as int? ?? 3;
  }

  /// Calculate provider and admin shares from total amount
  static Future<Map<String, double>> calculateShares(double totalAmount) async {
    final providerPercentage = await getProviderSharePercentage();
    final providerShare = (totalAmount * providerPercentage / 100);
    final adminShare = totalAmount - providerShare;

    return {'providerShare': providerShare, 'adminShare': adminShare};
  }

  /// Get appointment fee based on type
  static Future<double> getAppointmentFee({
    required String providerType,
    required String appointmentType,
  }) async {
    final config = await getFeeConfig();
    final type = providerType.toLowerCase();
    final apptType = appointmentType.toLowerCase();

    if (type == 'doctor' || type.contains('doctor')) {
      if (apptType.contains('follow-up') || apptType.contains('followup')) {
        return (config['doctorFollowUp'] as num?)?.toDouble() ?? 1500.0;
      }
      if (apptType.contains('mental')) {
        return (config['doctorMentalHealth'] as num?)?.toDouble() ?? 3000.0;
      }
      if (apptType.contains('emergency')) {
        return (config['doctorEmergency'] as num?)?.toDouble() ?? 5000.0;
      }
      if (apptType.contains('specialist')) {
        return (config['doctorSpecialist'] as num?)?.toDouble() ?? 5000.0;
      }
      // Default to general consultation
      return (config['doctorGeneralConsultation'] as num?)?.toDouble() ??
          3000.0;
    } else if (type.contains('chw') || type.contains('community')) {
      return (config['patientCHWBooking'] as num?)?.toDouble() ?? 1000.0;
    }

    // Default fallback
    return (config['doctorGeneralConsultation'] as num?)?.toDouble() ?? 3000.0;
  }

  /// Get CHW booking fee
  static Future<double> getCHWDoctorBookingFee() async {
    final config = await getFeeConfig();
    return (config['chwDoctorBooking'] as num?)?.toDouble() ?? 2000.0;
  }

  /// Default configuration (matches existing hardcoded values)
  static Map<String, dynamic> _getDefaultConfig() {
    return {
      'doctorFollowUp': 1500.0,
      'doctorGeneralConsultation': 3000.0,
      'doctorMentalHealth': 3000.0,
      'doctorEmergency': 5000.0,
      'doctorSpecialist': 5000.0,
      'chwDoctorBooking': 2000.0,
      'patientCHWBooking': 1000.0,
      'chwFreeAppointmentQuota': 3,
      'providerSharePercentage': 70.0,
      'adminSharePercentage': 30.0,
      'remoteDoctorSharePercentage': 70.0,
      'remoteFacilitySharePercentage': 30.0,
      'currency': 'NGN',
      'currencySymbol': '₦',
    };
  }
}
