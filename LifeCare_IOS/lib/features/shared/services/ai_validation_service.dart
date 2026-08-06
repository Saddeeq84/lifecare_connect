import 'package:flutter/material.dart';

/// AI-powered validation service for medical data entry
/// Provides real-time monitoring and error detection to reduce medical errors
class AIValidationService {
  /// Validate medication prescription
  static Future<ValidationResult> validatePrescription({
    required String medicationName,
    required String dosage,
    required String frequency,
    required String route,
    String? patientAge,
    String? patientWeight,
    List<String>? existingMedications,
    List<String>? allergies,
    List<String>? conditions,
  }) async {
    final warnings = <String>[];
    final suggestions = <String>[];
    ValidationSeverity severity = ValidationSeverity.safe;

    // Check for common prescription errors
    final medLower = medicationName.toLowerCase();
    final dosageLower = dosage.toLowerCase();

    // 1. Check dosage format
    if (!dosageLower.contains(RegExp(r'\d+'))) {
      warnings.add(
        '⚠️ Dosage should include a numeric value (e.g., 500mg, 10ml)',
      );
      severity = ValidationSeverity.warning;
    }

    // 2. Check for high-risk medications
    final highRiskMeds = {
      'warfarin': 'Requires INR monitoring. Check for bleeding risk.',
      'insulin': 'Monitor blood glucose. Adjust based on readings.',
      'digoxin': 'Narrow therapeutic window. Monitor for toxicity.',
      'methotrexate': 'Weekly dosing. Check renal and hepatic function.',
      'morphine': 'Controlled substance. Monitor respiratory rate.',
      'heparin': 'Monitor aPTT or anti-Xa levels.',
    };

    for (var med in highRiskMeds.entries) {
      if (medLower.contains(med.key)) {
        warnings.add('🔴 HIGH-RISK MEDICATION: ${med.value}');
        severity = ValidationSeverity.critical;
        break;
      }
    }

    // 3. Check for drug interactions
    if (existingMedications != null && existingMedications.isNotEmpty) {
      final interactions = _checkDrugInteractions(
        medLower,
        existingMedications,
      );
      if (interactions.isNotEmpty) {
        warnings.add('⚠️ POTENTIAL DRUG INTERACTION: $interactions');
        severity = severity == ValidationSeverity.critical
            ? severity
            : ValidationSeverity.warning;
      }
    }

    // 4. Check allergies
    if (allergies != null && allergies.isNotEmpty) {
      for (var allergy in allergies) {
        if (medLower.contains(allergy.toLowerCase()) ||
            _checkDrugClass(medLower, allergy.toLowerCase())) {
          warnings.add('🚫 ALLERGY ALERT: Patient allergic to $allergy');
          severity = ValidationSeverity.critical;
        }
      }
    }

    // 5. Age-specific warnings
    if (patientAge != null) {
      final age = int.tryParse(patientAge);
      if (age != null) {
        if (age < 18 && _isPediatricContraindicated(medLower)) {
          warnings.add('⚠️ PEDIATRIC WARNING: Not recommended for children');
          severity = ValidationSeverity.warning;
        }
        if (age > 65 && _isGeriatricCaution(medLower)) {
          warnings.add(
            '⚠️ GERIATRIC CAUTION: Start with lower dose in elderly',
          );
          suggestions.add('Consider reducing initial dose by 25-50%');
        }
      }
    }

    // 6. Common dosage errors
    if (medLower.contains('paracetamol') ||
        medLower.contains('acetaminophen')) {
      if (dosageLower.contains('1000') || dosageLower.contains('1g')) {
        final match = RegExp(r'(\d+)\s*(g|mg)').firstMatch(dosageLower);
        if (match != null) {
          final value = int.tryParse(match.group(1) ?? '0') ?? 0;
          final unit = match.group(2);
          if ((unit == 'g' && value > 1) || (unit == 'mg' && value > 1000)) {
            warnings.add(
              '🔴 OVERDOSE RISK: Maximum single dose is 1000mg (1g)',
            );
            severity = ValidationSeverity.critical;
          }
        }
      }
      suggestions.add('Max daily dose: 4000mg. Avoid in liver disease.');
    }

    // 7. Antibiotic stewardship
    if (_isAntibiotic(medLower)) {
      suggestions.add(
        '💊 Antibiotic prescribed. Ensure culture sent if applicable.',
      );
      suggestions.add(
        'Duration: Typically 5-7 days unless specified otherwise.',
      );
    }

    // 8. Route-specific warnings
    if (route.toLowerCase() == 'iv' || route.toLowerCase() == 'intravenous') {
      warnings.add('⚠️ IV route: Ensure proper dilution and infusion rate');
      suggestions.add('Monitor infusion site for phlebitis/extravasation');
    }

    return ValidationResult(
      isValid: severity != ValidationSeverity.critical,
      severity: severity,
      warnings: warnings,
      suggestions: suggestions,
      aiRecommendation: _generatePrescriptionRecommendation(
        medicationName,
        dosage,
        frequency,
        route,
      ),
    );
  }

  /// Validate laboratory results
  static Future<ValidationResult> validateLabResult({
    required String testName,
    required String result,
    required String unit,
    String? referenceRange,
    String? patientAge,
    String? patientSex,
  }) async {
    final warnings = <String>[];
    final suggestions = <String>[];
    ValidationSeverity severity = ValidationSeverity.safe;

    final numericResult = double.tryParse(
      result.replaceAll(RegExp(r'[^0-9.]'), ''),
    );

    if (numericResult == null) {
      warnings.add('⚠️ Result should be numeric for quantitative tests');
      return ValidationResult(
        isValid: true,
        severity: ValidationSeverity.warning,
        warnings: warnings,
        suggestions: [],
      );
    }

    final testLower = testName.toLowerCase();

    // Critical value alerts
    final criticalValues = _checkCriticalValues(
      testLower,
      numericResult,
      patientSex,
    );
    if (criticalValues != null) {
      warnings.add('🔴 CRITICAL VALUE: $criticalValues');
      severity = ValidationSeverity.critical;
      suggestions.add('Notify physician immediately. Confirm result.');
    }

    // Impossible values detection
    final impossibleCheck = _checkImpossibleValues(testLower, numericResult);
    if (impossibleCheck != null) {
      warnings.add('❌ IMPOSSIBLE VALUE: $impossibleCheck');
      warnings.add('Please verify result and re-test if necessary');
      severity = ValidationSeverity.critical;
    }

    // Reference range validation
    final rangeCheck = _checkReferenceRange(
      testLower,
      numericResult,
      patientSex,
      patientAge,
    );
    if (rangeCheck != null) {
      if (rangeCheck.contains('High') || rangeCheck.contains('Low')) {
        warnings.add('⚠️ OUT OF RANGE: $rangeCheck');
        severity = severity == ValidationSeverity.critical
            ? severity
            : ValidationSeverity.warning;
      }
    }

    // Clinical correlation suggestions
    final clinicalSuggestions = _getLabClinicalSuggestions(
      testLower,
      numericResult,
    );
    suggestions.addAll(clinicalSuggestions);

    return ValidationResult(
      isValid:
          severity != ValidationSeverity.critical ||
          !impossibleCheck.toString().contains('IMPOSSIBLE'),
      severity: severity,
      warnings: warnings,
      suggestions: suggestions,
      aiRecommendation: _generateLabRecommendation(
        testName,
        numericResult,
        unit,
      ),
    );
  }

  /// Validate vital signs
  static Future<ValidationResult> validateVitalSigns({
    double? systolicBP,
    double? diastolicBP,
    double? heartRate,
    double? temperature,
    double? respiratoryRate,
    double? oxygenSaturation,
    String? patientAge,
  }) async {
    final warnings = <String>[];
    final suggestions = <String>[];
    ValidationSeverity severity = ValidationSeverity.safe;

    // Blood Pressure
    if (systolicBP != null && diastolicBP != null) {
      if (systolicBP > 180 || diastolicBP > 120) {
        warnings.add(
          '🔴 HYPERTENSIVE EMERGENCY: BP $systolicBP/$diastolicBP mmHg',
        );
        suggestions.add(
          'Immediate medical attention required. Consider antihypertensive.',
        );
        severity = ValidationSeverity.critical;
      } else if (systolicBP < 90 || diastolicBP < 60) {
        warnings.add('🔴 HYPOTENSION: BP $systolicBP/$diastolicBP mmHg');
        suggestions.add('Check for shock, dehydration, or medication effect.');
        severity = ValidationSeverity.critical;
      } else if (systolicBP > 140 || diastolicBP > 90) {
        warnings.add('⚠️ Elevated BP: $systolicBP/$diastolicBP mmHg');
        suggestions.add(
          'Monitor closely. Lifestyle modifications recommended.',
        );
        severity = ValidationSeverity.warning;
      }

      // Check for impossible BP values
      if (systolicBP < diastolicBP) {
        warnings.add(
          '❌ IMPOSSIBLE VALUE: Systolic cannot be less than diastolic',
        );
        severity = ValidationSeverity.critical;
      }
      if (systolicBP > 300 || diastolicBP > 200) {
        warnings.add(
          '❌ IMPOSSIBLE VALUE: BP reading exceeds physiological limits',
        );
        severity = ValidationSeverity.critical;
      }
    }

    // Heart Rate
    if (heartRate != null) {
      if (heartRate < 40) {
        warnings.add('🔴 SEVERE BRADYCARDIA: HR ${heartRate.toInt()} bpm');
        suggestions.add(
          'Check for heart block, medication effect, or hypothyroidism.',
        );
        severity = ValidationSeverity.critical;
      } else if (heartRate > 150) {
        warnings.add('🔴 SEVERE TACHYCARDIA: HR ${heartRate.toInt()} bpm');
        suggestions.add('Assess for arrhythmia, sepsis, or hypovolemia.');
        severity = ValidationSeverity.critical;
      } else if (heartRate < 60 || heartRate > 100) {
        warnings.add('⚠️ Abnormal heart rate: ${heartRate.toInt()} bpm');
        severity = severity == ValidationSeverity.critical
            ? severity
            : ValidationSeverity.warning;
      }
    }

    // Temperature
    if (temperature != null) {
      if (temperature >= 40.0) {
        warnings.add(
          '🔴 HYPERPYREXIA: Temperature ${temperature.toStringAsFixed(1)}°C',
        );
        suggestions.add(
          'Urgent cooling measures needed. Check for heat stroke or infection.',
        );
        severity = ValidationSeverity.critical;
      } else if (temperature < 35.0) {
        warnings.add(
          '🔴 HYPOTHERMIA: Temperature ${temperature.toStringAsFixed(1)}°C',
        );
        suggestions.add(
          'Warming measures needed. Check for exposure or sepsis.',
        );
        severity = ValidationSeverity.critical;
      } else if (temperature >= 38.0) {
        warnings.add(
          '⚠️ Fever: Temperature ${temperature.toStringAsFixed(1)}°C',
        );
        suggestions.add('Consider antipyretics. Investigate source of fever.');
        severity = severity == ValidationSeverity.critical
            ? severity
            : ValidationSeverity.warning;
      }
    }

    // Oxygen Saturation
    if (oxygenSaturation != null) {
      if (oxygenSaturation < 90) {
        warnings.add('🔴 SEVERE HYPOXEMIA: SpO2 ${oxygenSaturation.toInt()}%');
        suggestions.add(
          'Oxygen therapy required. Consider ABG and chest X-ray.',
        );
        severity = ValidationSeverity.critical;
      } else if (oxygenSaturation < 94) {
        warnings.add('⚠️ Low oxygen saturation: ${oxygenSaturation.toInt()}%');
        suggestions.add('Supplemental oxygen may be needed.');
        severity = severity == ValidationSeverity.critical
            ? severity
            : ValidationSeverity.warning;
      }
      if (oxygenSaturation > 100) {
        warnings.add('❌ IMPOSSIBLE VALUE: SpO2 cannot exceed 100%');
        severity = ValidationSeverity.critical;
      }
    }

    // Respiratory Rate
    if (respiratoryRate != null) {
      if (respiratoryRate < 10) {
        warnings.add('🔴 SEVERE BRADYPNEA: RR ${respiratoryRate.toInt()}/min');
        suggestions.add(
          'Check for respiratory depression or neurological issues.',
        );
        severity = ValidationSeverity.critical;
      } else if (respiratoryRate > 30) {
        warnings.add('🔴 SEVERE TACHYPNEA: RR ${respiratoryRate.toInt()}/min');
        suggestions.add(
          'Assess for respiratory distress, pain, or metabolic acidosis.',
        );
        severity = ValidationSeverity.critical;
      }
    }

    return ValidationResult(
      isValid: !warnings.any((w) => w.contains('IMPOSSIBLE')),
      severity: severity,
      warnings: warnings,
      suggestions: suggestions,
      aiRecommendation:
          'Vital signs reviewed. ${warnings.isEmpty ? "All parameters within acceptable range." : "Please review warnings above."}',
    );
  }

  // Helper methods
  static String _checkDrugInteractions(String newMed, List<String> existing) {
    final interactions = <String>[];

    // Common drug interactions
    final interactionMap = {
      'warfarin': ['aspirin', 'nsaid', 'ibuprofen', 'naproxen'],
      'metformin': ['contrast', 'iodine'],
      'ace inhibitor': ['nsaid', 'potassium'],
      'lithium': ['nsaid', 'thiazide', 'ace inhibitor'],
    };

    for (var entry in interactionMap.entries) {
      if (newMed.contains(entry.key)) {
        for (var existingMed in existing) {
          for (var interacting in entry.value) {
            if (existingMed.toLowerCase().contains(interacting)) {
              interactions.add('${entry.key} + $interacting');
            }
          }
        }
      }
    }

    return interactions.join(', ');
  }

  static bool _checkDrugClass(String med, String allergy) {
    // Check if medication belongs to same class as allergy
    final penicillins = ['amoxicillin', 'ampicillin', 'penicillin'];
    final nsaids = ['ibuprofen', 'naproxen', 'diclofenac', 'aspirin'];

    if (allergy.contains('penicillin') &&
        penicillins.any((p) => med.contains(p))) {
      return true;
    }
    if (allergy.contains('nsaid') && nsaids.any((n) => med.contains(n))) {
      return true;
    }

    return false;
  }

  static bool _isPediatricContraindicated(String med) {
    final contraindicated = ['aspirin', 'tetracycline', 'doxycycline'];
    return contraindicated.any((c) => med.contains(c));
  }

  static bool _isGeriatricCaution(String med) {
    final caution = ['benzodiazepine', 'diazepam', 'morphine', 'tramadol'];
    return caution.any((c) => med.contains(c));
  }

  static bool _isAntibiotic(String med) {
    final antibiotics = [
      'cillin',
      'mycin',
      'floxacin',
      'cef',
      'azithromycin',
      'metronidazole',
      'cotrimoxazole',
    ];
    return antibiotics.any((a) => med.contains(a));
  }

  static String? _checkCriticalValues(String test, double value, String? sex) {
    if (test.contains('glucose') || test.contains('sugar')) {
      if (value < 2.8) {
        return 'Severe hypoglycemia (<2.8 mmol/L). Risk of seizures.';
      }
      if (value > 20) return 'Severe hyperglycemia (>20 mmol/L). Risk of DKA.';
    }
    if (test.contains('potassium') || test.contains('k+')) {
      if (value < 2.5) {
        return 'Severe hypokalemia (<2.5 mmol/L). Cardiac arrhythmia risk.';
      }
      if (value > 6.0) {
        return 'Severe hyperkalemia (>6.0 mmol/L). Cardiac arrest risk.';
      }
    }
    if (test.contains('hemoglobin') || test.contains('hb')) {
      if (value < 7.0) {
        return 'Severe anemia (<7 g/dL). Transfusion may be needed.';
      }
    }
    if (test.contains('platelet')) {
      if (value < 50) {
        return 'Severe thrombocytopenia (<50 x10⁹/L). Bleeding risk.';
      }
    }
    if (test.contains('wbc') || test.contains('white')) {
      if (value < 2.0) return 'Severe leukopenia (<2 x10⁹/L). Infection risk.';
      if (value > 30) {
        return 'Severe leukocytosis (>30 x10⁹/L). Investigate cause.';
      }
    }
    return null;
  }

  static String? _checkImpossibleValues(String test, double value) {
    if (test.contains('oxygen') || test.contains('spo2')) {
      if (value > 100) return 'SpO2 cannot exceed 100%';
    }
    if (test.contains('hemoglobin') && value > 20) {
      return 'Hemoglobin >20 g/dL is extremely rare. Verify result.';
    }
    if (test.contains('glucose') && value > 50 && value < 1) {
      return 'Glucose <1 mmol/L incompatible with life. Verify result.';
    }
    return null;
  }

  static String? _checkReferenceRange(
    String test,
    double value,
    String? sex,
    String? age,
  ) {
    // Basic reference ranges
    if (test.contains('hemoglobin') || test.contains('hb')) {
      if (sex?.toLowerCase() == 'male') {
        if (value < 13.0) return 'Low (Normal: 13-17 g/dL)';
        if (value > 17.0) return 'High (Normal: 13-17 g/dL)';
      } else {
        if (value < 12.0) return 'Low (Normal: 12-15 g/dL)';
        if (value > 15.0) return 'High (Normal: 12-15 g/dL)';
      }
    }
    return null;
  }

  static List<String> _getLabClinicalSuggestions(String test, double value) {
    final suggestions = <String>[];

    if (test.contains('glucose') && value > 11.1) {
      suggestions.add('Consider HbA1c for diabetes assessment');
      suggestions.add('Check for polyuria, polydipsia, weight loss');
    }
    if (test.contains('creatinine') && value > 120) {
      suggestions.add('Calculate eGFR for renal function assessment');
      suggestions.add('Review medications for nephrotoxic agents');
    }

    return suggestions;
  }

  static String _generatePrescriptionRecommendation(
    String med,
    String dose,
    String freq,
    String route,
  ) {
    return '💊 Prescription: $med $dose $freq ($route route). Ensure patient counseling on usage, side effects, and adherence.';
  }

  static String _generateLabRecommendation(
    String test,
    double value,
    String unit,
  ) {
    return '🧪 Lab Result: $test = $value $unit. Clinical correlation recommended.';
  }
}

/// Validation result model
class ValidationResult {
  final bool isValid;
  final ValidationSeverity severity;
  final List<String> warnings;
  final List<String> suggestions;
  final String? aiRecommendation;

  ValidationResult({
    required this.isValid,
    required this.severity,
    required this.warnings,
    required this.suggestions,
    this.aiRecommendation,
  });

  bool get hasCriticalIssues => severity == ValidationSeverity.critical;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasSuggestions => suggestions.isNotEmpty;
}

/// Severity levels for validation
enum ValidationSeverity {
  safe, // No issues
  info, // Informational only
  warning, // Caution advised
  critical, // Requires immediate attention
}

/// Extension to get color for severity
extension ValidationSeverityColor on ValidationSeverity {
  Color get color {
    switch (this) {
      case ValidationSeverity.safe:
        return Colors.green;
      case ValidationSeverity.info:
        return Colors.blue;
      case ValidationSeverity.warning:
        return Colors.orange;
      case ValidationSeverity.critical:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case ValidationSeverity.safe:
        return Icons.check_circle;
      case ValidationSeverity.info:
        return Icons.info;
      case ValidationSeverity.warning:
        return Icons.warning;
      case ValidationSeverity.critical:
        return Icons.error;
    }
  }
}
