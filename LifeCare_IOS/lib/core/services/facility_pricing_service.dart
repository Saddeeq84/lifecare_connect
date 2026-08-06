import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to fetch and manage facility-specific pricing
class FacilityPricingService {
  static final _firestore = FirebaseFirestore.instance;

  /// Cache to store facility prices to reduce Firestore reads
  static final Map<String, Map<String, dynamic>> _priceCache = {};

  /// Get price for a specific service in a facility
  /// Returns the custom price if set, otherwise returns the default price
  static Future<double> getServicePrice(
    String facilityId,
    String serviceId,
    double defaultPrice,
  ) async {
    try {
      // Check cache first
      if (_priceCache.containsKey(facilityId)) {
        final cachedPrice = _priceCache[facilityId]![serviceId];
        if (cachedPrice != null) {
          return (cachedPrice as num).toDouble();
        }
        return defaultPrice;
      }

      // Fetch from Firestore
      final doc = await _firestore
          .collection('facility_service_prices')
          .doc(facilityId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _priceCache[facilityId] = data;

        final price = data[serviceId];
        if (price != null) {
          return (price as num).toDouble();
        }
      }

      return defaultPrice;
    } catch (e) {
      print('Error fetching service price: $e');
      return defaultPrice;
    }
  }

  /// Get all prices for a facility
  static Future<Map<String, dynamic>> getAllPrices(String facilityId) async {
    try {
      // Check cache first
      if (_priceCache.containsKey(facilityId)) {
        return _priceCache[facilityId]!;
      }

      final doc = await _firestore
          .collection('facility_service_prices')
          .doc(facilityId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _priceCache[facilityId] = data;
        return data;
      }

      return {};
    } catch (e) {
      print('Error fetching facility prices: $e');
      return {};
    }
  }

  /// Clear cache for a specific facility (call after price updates)
  static void clearCache(String facilityId) {
    _priceCache.remove(facilityId);
  }

  /// Clear all cache
  static void clearAllCache() {
    _priceCache.clear();
  }

  /// Listen to price changes in real-time
  static Stream<Map<String, dynamic>> listenToPrices(String facilityId) {
    return _firestore
        .collection('facility_service_prices')
        .doc(facilityId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            final data = doc.data()!;
            _priceCache[facilityId] = data; // Update cache
            return data;
          }
          return <String, dynamic>{};
        });
  }

  /// Default prices for all services
  static const Map<String, double> defaultPrices = {
    // Appointments & Consultations
    'appointment_booking': 500.0,
    'general_consultation': 5000.0,
    'specialist_consultation': 10000.0,
    'follow_up_consultation': 3000.0,
    'emergency_consultation': 15000.0,
    'telemedicine_consultation': 4000.0,

    // Laboratory Services
    'blood_test_basic': 3000.0,
    'blood_test_full': 5000.0,
    'malaria_test': 1500.0,
    'typhoid_test': 2000.0,
    'hiv_test': 3000.0,
    'hepatitis_test': 5000.0,
    'pregnancy_test': 1000.0,
    'urine_test': 2000.0,
    'stool_test': 2000.0,
    'blood_sugar': 1500.0,
    'cholesterol_test': 3000.0,
    'liver_function': 7000.0,
    'kidney_function': 7000.0,
    'xray_chest': 5000.0,
    'xray_other': 6000.0,
    'ultrasound': 8000.0,
    'ecg': 4000.0,

    // Pharmacy/Medications
    'prescription_dispensing': 200.0,
    'medication_basic': 500.0,
    'medication_standard': 2000.0,
    'medication_premium': 5000.0,
    'antibiotics': 3000.0,
    'antimalarial': 2000.0,
    'pain_relief': 1000.0,
    'vitamins_supplements': 3000.0,

    // Nursing Services
    'vital_signs': 500.0,
    'injection_iv': 1000.0,
    'injection_im': 800.0,
    'dressing_minor': 1500.0,
    'dressing_major': 3000.0,
    'catheterization': 5000.0,
    'nasogastric_tube': 3000.0,
    'suture_removal': 2000.0,
    'blood_pressure_monitoring': 5000.0,

    // Admission & Ward Services
    'admission_fee': 10000.0,
    'bed_general_ward': 5000.0,
    'bed_private_ward': 15000.0,
    'bed_icu': 50000.0,
    'discharge_fee': 2000.0,

    // Minor Procedures
    'suturing': 5000.0,
    'incision_drainage': 7000.0,
    'nebulization': 2000.0,
    'ear_syringing': 2000.0,
    'circumcision': 20000.0,

    // Maternity Services
    'antenatal_visit': 5000.0,
    'delivery_normal': 50000.0,
    'delivery_caesarean': 150000.0,
    'postnatal_care': 5000.0,
    'family_planning': 3000.0,

    // Immunization
    'bcg_vaccine': 2000.0,
    'polio_vaccine': 1500.0,
    'dpt_vaccine': 2000.0,
    'hepatitis_b_vaccine': 3000.0,
    'measles_vaccine': 2000.0,
    'yellow_fever_vaccine': 5000.0,
    'covid_vaccine': 0.0,

    // Other Services
    'medical_report': 5000.0,
    'referral_letter': 2000.0,
    'prescription_refill': 1000.0,
    'health_talk': 0.0,
    'ambulance_service': 20000.0,
  };
}
