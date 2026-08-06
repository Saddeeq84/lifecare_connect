// Profession to Department Dashboard Mapper
// Maps each profession type to their appropriate department dashboard

/// Department types that professionals can access
enum DepartmentType {
  opd,
  nursing,
  medicalRecords,
  pharmacy,
  laboratory,
  radiology,
  specialist,
  ward,
  publicHealth,
  emergency,
}

/// Maps a profession string to its primary department dashboard
class ProfessionDepartmentMapper {
  /// Returns the department dashboard type for a given profession
  /// Returns null if profession is not recognized
  static DepartmentType? getDepartmentForProfession(String? profession) {
    if (profession == null) return null;

    final professionLower = profession.toLowerCase().trim();

    // OPD Department Access
    // Doctors and Nurses access OPD dashboard
    if (_opdProfessions.contains(professionLower)) {
      return DepartmentType.opd;
    }

    // Nursing Department Access
    // Nurses, Nurse Assistants, CHOs, CHEWs, Midwives, Nurse Practitioners, Medical Assistants
    if (_nursingProfessions.contains(professionLower)) {
      return DepartmentType.nursing;
    }

    // Medical Records Department Access
    // Medical Record Officers, Health Information Managers, Front Desk Officers
    if (_medicalRecordsProfessions.contains(professionLower)) {
      return DepartmentType.medicalRecords;
    }

    // Pharmacy Department Access
    // Pharmacists, Inventory Managers, Pharmacy Technicians, Pharmacy Assistants
    if (_pharmacyProfessions.contains(professionLower)) {
      return DepartmentType.pharmacy;
    }

    // Laboratory Department Access
    // Lab Scientists, Lab Technicians, Lab Assistants, Phlebotomists, Pathologists, Lab Managers
    if (_laboratoryProfessions.contains(professionLower)) {
      return DepartmentType.laboratory;
    }

    // Radiology Department Access
    // Radiographers, Radiologists
    if (_radiologyProfessions.contains(professionLower)) {
      return DepartmentType.radiology;
    }

    // Public Health Department Access
    // Public Health Officers, Community Health Officers, CHEWs, Health Educators
    if (_publicHealthProfessions.contains(professionLower)) {
      return DepartmentType.publicHealth;
    }

    // Emergency Department Access
    // Emergency Physicians, Emergency Nurses, Paramedics, Triage Nurses
    if (_emergencyProfessions.contains(professionLower)) {
      return DepartmentType.emergency;
    }

    // Specialist Department Access
    // Medical Specialists (Surgeons, Dentists, Gynecologists, Pediatricians, etc.)
    if (_specialistProfessions.contains(professionLower)) {
      return DepartmentType.specialist;
    }

    return null;
  }

  /// Checks if a profession has access to the ward dashboard
  /// Doctors, Surgeons (all medical specialists), Nurses, Midwives, Nurse Assistants, Nurse Practitioners
  static bool hasWardAccess(String? profession) {
    if (profession == null) return false;

    final professionLower = profession.toLowerCase().trim();
    return _wardAccessProfessions.contains(professionLower);
  }

  /// Returns a list of all departments a profession has access to
  static List<DepartmentType> getAllDepartmentsForProfession(
    String? profession,
  ) {
    final departments = <DepartmentType>[];

    final primaryDepartment = getDepartmentForProfession(profession);
    if (primaryDepartment != null) {
      departments.add(primaryDepartment);
    }

    // Add ward access if applicable
    if (hasWardAccess(profession)) {
      departments.add(DepartmentType.ward);
    }

    return departments;
  }

  /// Returns a human-readable department name
  static String getDepartmentName(DepartmentType department) {
    switch (department) {
      case DepartmentType.opd:
        return 'Out-Patient Department';
      case DepartmentType.nursing:
        return 'Nursing Department';
      case DepartmentType.medicalRecords:
        return 'Medical Records';
      case DepartmentType.pharmacy:
        return 'Pharmacy';
      case DepartmentType.laboratory:
        return 'Laboratory';
      case DepartmentType.radiology:
        return 'Radiology';
      case DepartmentType.publicHealth:
        return 'Public Health';
      case DepartmentType.emergency:
        return 'Emergency Department';
      case DepartmentType.specialist:
        return 'Specialist Department';
      case DepartmentType.ward:
        return 'Ward Management';
    }
  }

  // ============================================
  // PROFESSION LISTS BY DEPARTMENT
  // ============================================

  /// OPD Department Professions
  static const Set<String> _opdProfessions = {'doctor'};

  /// Nursing Department Professions
  static const Set<String> _nursingProfessions = {
    'nurse',
    'nurse assistant',
    'nursing assistant',
    'community health officer',
    'cho',
    'community health extension worker',
    'chew',
    'midwife',
    'nurse practitioner',
    'medical assistant',
  };

  /// Medical Records Department Professions
  static const Set<String> _medicalRecordsProfessions = {
    'medical records officer',
    'medical record officer',
    'medical records',
    'health information manager',
    'front desk officer',
    'front desk',
    'data entry clerk',
    'customer service officer',
  };

  /// Pharmacy Department Professions
  static const Set<String> _pharmacyProfessions = {
    'pharmacist',
    'inventory manager',
    'pharmacy technician',
    'pharmacist technician',
    'pharmacy assistant',
    'pharmacist assistant',
  };

  /// Laboratory Department Professions
  static const Set<String> _laboratoryProfessions = {
    'lab scientist',
    'laboratory scientist',
    'lab technician',
    'laboratory technician',
    'lab assistant',
    'laboratory assistant',
    'phlebotomist',
    'pathologist',
    'lab manager',
    'laboratory manager',
  };

  /// Radiology Department Professions
  static const Set<String> _radiologyProfessions = {
    'radiographer',
    'radiologist',
    'radiology technician',
    'imaging technician',
  };

  /// Public Health Department Professions
  static const Set<String> _publicHealthProfessions = {
    'public health officer',
    'pho',
    'community health officer',
    'cho',
    'community health extension worker',
    'chew',
    'health educator',
    'environmental health officer',
    'disease surveillance officer',
    'epidemiologist',
    'public health specialist',
    'health promotion officer',
    'ipc manager',
    'ipc link nurse',
    'ipc practitioner',
    'ipc focal person',
    'ipc doctor',
    'scientific officer',
    'ipc technical officer',
  };

  /// Emergency Department Professions
  /// Emergency medical professionals who access the emergency department dashboard
  static const Set<String> _emergencyProfessions = {
    'emergency physician',
    'emergency doctor',
    'emergency nurse',
    'paramedic',
    'triage nurse',
    'emergency medical technician',
    'emt',
    'emergency medical services',
    'ems',
    'emergency room physician',
    'er physician',
    'emergency room nurse',
    'er nurse',
    'critical care paramedic',
    'flight paramedic',
    'emergency medical dispatcher',
  };

  /// Specialist Department Professions
  /// Medical specialists who access the specialist department dashboard
  static const Set<String> _specialistProfessions = {
    'surgeon',
    'medical specialist',
    'specialist',
    'dentist',
    'dental surgeon',
    'dental technician',
    'gynaecologist',
    'gynecologist',
    'anaesthesiologist',
    'anesthesiologist',
    'anesthetist',
    'obstetrician',
    'pediatrician',
    'paediatrician',
    'cardiologist',
    'neurologist',
    'orthopedic surgeon',
    'orthopedist',
    'ent specialist',
    'ent surgeon',
    'ophthalmologist',
    'urologist',
    'nephrologist',
    'oncologist',
    'dermatologist',
    'psychiatrist',
    'endocrinologist',
    'pulmonologist',
    'gastroenterologist',
    'rheumatologist',
    'hematologist',
    'infectious disease specialist',
    'general surgeon',
    'plastic surgeon',
    'vascular surgeon',
    'thoracic surgeon',
    'neurosurgeon',
    'maxillofacial surgeon',
  };

  /// Ward Access Professions
  /// Professions that can access the ward dashboard
  static const Set<String> _wardAccessProfessions = {
    // Doctors
    'doctor',

    // All Specialists (Surgeons and other medical specialists)
    'surgeon',
    'medical specialist',
    'specialist',
    'dentist',
    'dental surgeon',
    'gynaecologist',
    'gynecologist',
    'anaesthesiologist',
    'anesthesiologist',
    'anesthetist',
    'obstetrician',
    'pediatrician',
    'paediatrician',
    'cardiologist',
    'neurologist',
    'orthopedic surgeon',
    'orthopedist',
    'ent specialist',
    'ent surgeon',
    'ophthalmologist',
    'urologist',
    'nephrologist',
    'oncologist',
    'dermatologist',
    'psychiatrist',
    'endocrinologist',
    'pulmonologist',
    'gastroenterologist',
    'rheumatologist',
    'hematologist',
    'infectious disease specialist',
    'general surgeon',
    'plastic surgeon',
    'vascular surgeon',
    'thoracic surgeon',
    'neurosurgeon',
    'maxillofacial surgeon',

    // Nursing Professionals
    'nurse',
    'midwife',
    'nurse assistant',
    'nursing assistant',
    'nurse practitioner',
  };
}
