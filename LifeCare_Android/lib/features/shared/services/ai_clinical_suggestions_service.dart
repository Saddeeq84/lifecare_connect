import 'dart:async';

/// AI-powered clinical suggestions service for inline assistance during consultation
/// Provides non-intrusive, context-aware suggestions for diagnosis, examination, and treatment
class AIClinicalSuggestionsService {
  /// Get differential diagnosis suggestions based on symptoms
  static Future<List<String>> getDifferentialDiagnosisSuggestions({
    required String complaints,
    String? history,
    String? examination,
  }) async {
    // Simulate API delay for realistic behavior
    await Future.delayed(const Duration(milliseconds: 500));

    final suggestions = <String>[];
    final complaintsLower = complaints.toLowerCase();

    // Fever-related conditions
    if (complaintsLower.contains('fever') ||
        complaintsLower.contains('temperature')) {
      if (complaintsLower.contains('cough') ||
          complaintsLower.contains('cold')) {
        suggestions.addAll([
          'Upper Respiratory Tract Infection',
          'Pneumonia',
          'Bronchitis',
        ]);
      }
      if (complaintsLower.contains('headache') ||
          complaintsLower.contains('body pain')) {
        suggestions.addAll(['Malaria', 'Typhoid fever', 'Dengue fever']);
      }
      if (complaintsLower.contains('diarrhea') ||
          complaintsLower.contains('vomiting')) {
        suggestions.addAll([
          'Gastroenteritis',
          'Food poisoning',
          'Typhoid fever',
        ]);
      }
    }

    // Respiratory symptoms
    if (complaintsLower.contains('cough') ||
        complaintsLower.contains('breathing')) {
      if (complaintsLower.contains('wheeze') ||
          complaintsLower.contains('asthma')) {
        suggestions.addAll(['Asthma exacerbation', 'Bronchospasm', 'COPD']);
      }
      if (complaintsLower.contains('chest pain') ||
          complaintsLower.contains('difficulty')) {
        suggestions.addAll(['Pneumonia', 'Pulmonary embolism', 'Pleurisy']);
      }
    }

    // Gastrointestinal symptoms
    if (complaintsLower.contains('abdominal pain') ||
        complaintsLower.contains('stomach')) {
      if (complaintsLower.contains('upper') ||
          complaintsLower.contains('epigastric')) {
        suggestions.addAll(['Gastritis', 'Peptic ulcer disease', 'GERD']);
      }
      if (complaintsLower.contains('lower right') ||
          complaintsLower.contains('rlq')) {
        suggestions.addAll([
          'Appendicitis',
          'Ectopic pregnancy',
          'Ovarian cyst',
        ]);
      }
    }

    // Headache-related
    if (complaintsLower.contains('headache')) {
      if (complaintsLower.contains('severe') ||
          complaintsLower.contains('worst')) {
        suggestions.addAll([
          'Migraine',
          'Meningitis',
          'Subarachnoid hemorrhage',
        ]);
      } else {
        suggestions.addAll(['Tension headache', 'Migraine', 'Sinusitis']);
      }
    }

    // Cardiovascular
    if (complaintsLower.contains('chest pain')) {
      suggestions.addAll([
        'Acute coronary syndrome',
        'Angina',
        'Musculoskeletal pain',
        'GERD',
      ]);
    }

    // Remove duplicates and limit to top 5
    return suggestions.toSet().take(5).toList();
  }

  /// Get examination suggestions based on complaints and history
  static Future<List<String>> getExaminationSuggestions({
    required String complaints,
    String? history,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final suggestions = <String>[];
    final complaintsLower = complaints.toLowerCase();

    // Respiratory examination
    if (complaintsLower.contains('cough') ||
        complaintsLower.contains('breathing') ||
        complaintsLower.contains('chest')) {
      suggestions.addAll([
        'Respiratory rate and pattern',
        'Chest auscultation (breath sounds, wheeze, crackles)',
        'Oxygen saturation (SpO2)',
        'Percussion for dullness or hyperresonance',
      ]);
    }

    // Cardiovascular examination
    if (complaintsLower.contains('chest pain') ||
        complaintsLower.contains('palpitation') ||
        complaintsLower.contains('dizzy')) {
      suggestions.addAll([
        'Blood pressure (both arms if indicated)',
        'Heart rate and rhythm',
        'Cardiac auscultation (murmurs, gallops)',
        'Peripheral pulses and edema',
      ]);
    }

    // Abdominal examination
    if (complaintsLower.contains('abdominal') ||
        complaintsLower.contains('stomach') ||
        complaintsLower.contains('diarrhea')) {
      suggestions.addAll([
        'Abdominal inspection (distension, scars)',
        'Palpation (tenderness, guarding, rebound)',
        'Bowel sounds auscultation',
        'Hepatomegaly and splenomegaly assessment',
      ]);
    }

    // Neurological examination
    if (complaintsLower.contains('headache') ||
        complaintsLower.contains('weakness') ||
        complaintsLower.contains('numbness')) {
      suggestions.addAll([
        'Level of consciousness (GCS)',
        'Cranial nerve examination',
        'Motor and sensory examination',
        'Reflexes and coordination',
      ]);
    }

    // General examination points
    if (complaintsLower.contains('fever')) {
      suggestions.addAll([
        'Temperature measurement',
        'Signs of dehydration',
        'Lymphadenopathy',
        'Skin rash or lesions',
      ]);
    }

    return suggestions.take(6).toList();
  }

  /// Get treatment plan suggestions based on diagnosis
  static Future<List<String>> getTreatmentPlanSuggestions({
    required String diagnosis,
    String? examination,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final suggestions = <String>[];
    final diagnosisLower = diagnosis.toLowerCase();

    // URTI/Common cold
    if (diagnosisLower.contains('urti') ||
        diagnosisLower.contains('upper respiratory') ||
        diagnosisLower.contains('common cold')) {
      suggestions.addAll([
        'Paracetamol 500mg-1g TDS PRN for fever/pain',
        'Adequate hydration and rest',
        'Steam inhalation for congestion',
        'Review if no improvement in 5-7 days',
      ]);
    }

    // Malaria
    if (diagnosisLower.contains('malaria')) {
      suggestions.addAll([
        'Artemether-Lumefantrine (Coartem) - weight-based dosing',
        'Paracetamol for fever',
        'Ensure patient completes full course',
        'Follow-up in 3 days to confirm response',
      ]);
    }

    // Gastroenteritis
    if (diagnosisLower.contains('gastroenteritis') ||
        diagnosisLower.contains('diarrhea')) {
      suggestions.addAll([
        'ORS (Oral Rehydration Salt) - frequent small amounts',
        'Zinc supplementation (20mg daily for 10-14 days)',
        'Continue feeding (BRAT diet initially)',
        'Metronidazole if suspected bacterial cause',
      ]);
    }

    // Hypertension
    if (diagnosisLower.contains('hypertension') ||
        diagnosisLower.contains('high blood pressure')) {
      suggestions.addAll([
        'Lifestyle modification counseling (diet, exercise, salt restriction)',
        'Start antihypertensive (Amlodipine 5mg OD or Enalapril 5mg OD)',
        'Monitor BP regularly',
        'Check for end-organ damage (renal function, ECG)',
      ]);
    }

    // Diabetes
    if (diagnosisLower.contains('diabetes') ||
        diagnosisLower.contains('hyperglycemia')) {
      suggestions.addAll([
        'Dietary counseling and glycemic control',
        'Metformin 500mg BD (if newly diagnosed Type 2)',
        'Regular blood glucose monitoring',
        'Screen for complications (foot exam, eye exam)',
      ]);
    }

    // Asthma
    if (diagnosisLower.contains('asthma')) {
      suggestions.addAll([
        'Salbutamol inhaler 2 puffs PRN for symptoms',
        'Trigger avoidance counseling',
        'Consider inhaled corticosteroid if frequent symptoms',
        'Action plan for exacerbations',
      ]);
    }

    // Peptic ulcer/Gastritis
    if (diagnosisLower.contains('gastritis') ||
        diagnosisLower.contains('peptic ulcer') ||
        diagnosisLower.contains('dyspepsia')) {
      suggestions.addAll([
        'Omeprazole 20mg OD before breakfast',
        'Avoid NSAIDs, alcohol, spicy foods',
        'Small frequent meals',
        'Review in 2-4 weeks',
      ]);
    }

    // Pneumonia
    if (diagnosisLower.contains('pneumonia')) {
      suggestions.addAll([
        'Amoxicillin 1g TDS for 7 days (or appropriate antibiotic)',
        'Adequate hydration and rest',
        'Paracetamol for fever',
        'Review in 48-72 hours or earlier if worsening',
      ]);
    }

    return suggestions.take(5).toList();
  }

  /// Get quick clinical tips based on current context
  static List<String> getQuickTips(String fieldType) {
    switch (fieldType) {
      case 'diagnosis':
        return [
          '💡 Consider differential diagnoses',
          '💡 Include severity/staging if applicable',
          '💡 Specify if provisional or confirmed',
        ];
      case 'examination':
        return [
          '💡 Document vital signs',
          '💡 Use IPPA: Inspection, Palpation, Percussion, Auscultation',
          '💡 Note both positive and pertinent negative findings',
        ];
      case 'treatment':
        return [
          '💡 Include non-pharmacological interventions',
          '💡 Consider patient education and counseling',
          '💡 Set clear follow-up timeline',
        ];
      default:
        return [];
    }
  }
}
