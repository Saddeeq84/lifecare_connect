import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ServiceManagementScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const ServiceManagementScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<ServiceManagementScreen> createState() =>
      _ServiceManagementScreenState();
}

class _ServiceManagementScreenState extends State<ServiceManagementScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, dynamic> _servicePrices = {};
  Map<String, List<Map<String, dynamic>>> _customServices = {};

  // Service categories
  final Map<String, List<Map<String, dynamic>>> _serviceCategories = {
    'Appointments & Consultations': [
      {
        'id': 'appointment_booking',
        'name': 'Appointment Booking Fee',
        'defaultPrice': 500.0,
      },
      {
        'id': 'remote_consultation',
        'name': 'Remote Consultation (Remote Doctor)',
        'defaultPrice': 5000.0,
      },
      {
        'id': 'general_consultation',
        'name': 'General Consultation',
        'defaultPrice': 5000.0,
      },
      {
        'id': 'specialist_consultation',
        'name': 'Specialist Consultation',
        'defaultPrice': 10000.0,
      },
      {
        'id': 'follow_up_consultation',
        'name': 'Follow-up Consultation',
        'defaultPrice': 3000.0,
      },
      {
        'id': 'emergency_consultation',
        'name': 'Emergency Consultation',
        'defaultPrice': 15000.0,
      },
      {
        'id': 'telemedicine_consultation',
        'name': 'Telemedicine Consultation',
        'defaultPrice': 4000.0,
      },
    ],
    'Laboratory Services': [
      {
        'id': 'blood_test_basic',
        'name': 'Basic Blood Test',
        'defaultPrice': 3000.0,
      },
      {
        'id': 'blood_test_full',
        'name': 'Full Blood Count (FBC)',
        'defaultPrice': 5000.0,
      },
      {'id': 'malaria_test', 'name': 'Malaria Test', 'defaultPrice': 1500.0},
      {'id': 'typhoid_test', 'name': 'Typhoid Test', 'defaultPrice': 2000.0},
      {'id': 'hiv_test', 'name': 'HIV Screening', 'defaultPrice': 3000.0},
      {
        'id': 'hepatitis_test',
        'name': 'Hepatitis B/C Test',
        'defaultPrice': 5000.0,
      },
      {
        'id': 'pregnancy_test',
        'name': 'Pregnancy Test',
        'defaultPrice': 1000.0,
      },
      {'id': 'urine_test', 'name': 'Urinalysis', 'defaultPrice': 2000.0},
      {'id': 'stool_test', 'name': 'Stool Analysis', 'defaultPrice': 2000.0},
      {
        'id': 'blood_sugar',
        'name': 'Blood Sugar (Glucose)',
        'defaultPrice': 1500.0,
      },
      {
        'id': 'cholesterol_test',
        'name': 'Cholesterol Test',
        'defaultPrice': 3000.0,
      },
      {
        'id': 'liver_function',
        'name': 'Liver Function Test',
        'defaultPrice': 7000.0,
      },
      {
        'id': 'kidney_function',
        'name': 'Kidney Function Test',
        'defaultPrice': 7000.0,
      },
      {'id': 'xray_chest', 'name': 'X-Ray (Chest)', 'defaultPrice': 5000.0},
      {'id': 'xray_other', 'name': 'X-Ray (Other)', 'defaultPrice': 6000.0},
      {'id': 'ultrasound', 'name': 'Ultrasound Scan', 'defaultPrice': 8000.0},
      {'id': 'ecg', 'name': 'ECG/EKG', 'defaultPrice': 4000.0},
    ],
    'Pharmacy/Medications': [
      {
        'id': 'paracetamol_500mg_tab',
        'name': 'Paracetamol 500mg',
        'form': 'Tablet',
        'unit': 'Per Tablet',
        'defaultPrice': 50.0,
      },
      {
        'id': 'ibuprofen_400mg_tab',
        'name': 'Ibuprofen 400mg',
        'form': 'Tablet',
        'unit': 'Per Tablet',
        'defaultPrice': 100.0,
      },
      {
        'id': 'amoxicillin_500mg_cap',
        'name': 'Amoxicillin 500mg',
        'form': 'Capsule',
        'unit': 'Per Capsule',
        'defaultPrice': 150.0,
      },
      {
        'id': 'ciprofloxacin_500mg_tab',
        'name': 'Ciprofloxacin 500mg',
        'form': 'Tablet',
        'unit': 'Per Tablet',
        'defaultPrice': 200.0,
      },
      {
        'id': 'metronidazole_400mg_tab',
        'name': 'Metronidazole 400mg',
        'form': 'Tablet',
        'unit': 'Per Tablet',
        'defaultPrice': 80.0,
      },
      {
        'id': 'artemether_lumefantrine_tab',
        'name': 'Artemether-Lumefantrine (Coartem)',
        'form': 'Tablet',
        'unit': 'Per Pack',
        'defaultPrice': 1200.0,
      },
      {
        'id': 'artesunate_injection',
        'name': 'Artesunate Injection',
        'form': 'Injection',
        'unit': 'Per Vial',
        'defaultPrice': 2500.0,
      },
      {
        'id': 'omeprazole_20mg_cap',
        'name': 'Omeprazole 20mg',
        'form': 'Capsule',
        'unit': 'Per Capsule',
        'defaultPrice': 120.0,
      },
      {
        'id': 'metformin_500mg_tab',
        'name': 'Metformin 500mg',
        'form': 'Tablet',
        'unit': 'Per Tablet',
        'defaultPrice': 100.0,
      },
      {
        'id': 'amlodipine_5mg_tab',
        'name': 'Amlodipine 5mg',
        'form': 'Tablet',
        'unit': 'Per Tablet',
        'defaultPrice': 150.0,
      },
      {
        'id': 'atenolol_50mg_tab',
        'name': 'Atenolol 50mg',
        'form': 'Tablet',
        'unit': 'Per Tablet',
        'defaultPrice': 120.0,
      },
      {
        'id': 'diclofenac_50mg_tab',
        'name': 'Diclofenac 50mg',
        'form': 'Tablet',
        'unit': 'Per Tablet',
        'defaultPrice': 80.0,
      },
      {
        'id': 'diclofenac_injection',
        'name': 'Diclofenac Injection',
        'form': 'Injection',
        'unit': 'Per Ampoule',
        'defaultPrice': 300.0,
      },
      {
        'id': 'promethazine_25mg_tab',
        'name': 'Promethazine 25mg',
        'form': 'Tablet',
        'unit': 'Per Tablet',
        'defaultPrice': 60.0,
      },
      {
        'id': 'multivitamin_tab',
        'name': 'Multivitamin',
        'form': 'Tablet',
        'unit': 'Per Tablet',
        'defaultPrice': 80.0,
      },
      {
        'id': 'vitamin_c_tab',
        'name': 'Vitamin C 1000mg',
        'form': 'Tablet',
        'unit': 'Per Tablet',
        'defaultPrice': 100.0,
      },
      {
        'id': 'folic_acid_5mg_tab',
        'name': 'Folic Acid 5mg',
        'form': 'Tablet',
        'unit': 'Per Tablet',
        'defaultPrice': 50.0,
      },
      {
        'id': 'ferrous_sulfate_tab',
        'name': 'Ferrous Sulfate (Iron)',
        'form': 'Tablet',
        'unit': 'Per Tablet',
        'defaultPrice': 70.0,
      },
      {
        'id': 'salbutamol_inhaler',
        'name': 'Salbutamol Inhaler',
        'form': 'Inhaler',
        'unit': 'Per Inhaler',
        'defaultPrice': 2000.0,
      },
      {
        'id': 'hydrocortisone_cream',
        'name': 'Hydrocortisone Cream 1%',
        'form': 'Cream',
        'unit': 'Per Tube',
        'defaultPrice': 500.0,
      },
      {
        'id': 'oral_rehydration_salts',
        'name': 'ORS (Oral Rehydration Salts)',
        'form': 'Sachet',
        'unit': 'Per Sachet',
        'defaultPrice': 100.0,
      },
      {
        'id': 'normal_saline_iv',
        'name': 'Normal Saline 0.9%',
        'form': 'IV Fluid',
        'unit': 'Per Bag (500ml)',
        'defaultPrice': 1000.0,
      },
      {
        'id': 'dextrose_5_iv',
        'name': 'Dextrose 5%',
        'form': 'IV Fluid',
        'unit': 'Per Bag (500ml)',
        'defaultPrice': 1200.0,
      },
      {
        'id': 'insulin_injection',
        'name': 'Insulin (Rapid Acting)',
        'form': 'Injection',
        'unit': 'Per Vial',
        'defaultPrice': 3500.0,
      },
      {
        'id': 'diazepam_5mg_tab',
        'name': 'Diazepam 5mg',
        'form': 'Tablet',
        'unit': 'Per Tablet',
        'defaultPrice': 100.0,
      },
    ],
    'Nursing Services': [
      {'id': 'vital_signs', 'name': 'Vital Signs Check', 'defaultPrice': 500.0},
      {'id': 'injection_iv', 'name': 'Injection (IV)', 'defaultPrice': 1000.0},
      {'id': 'injection_im', 'name': 'Injection (IM)', 'defaultPrice': 800.0},
      {
        'id': 'dressing_minor',
        'name': 'Wound Dressing (Minor)',
        'defaultPrice': 1500.0,
      },
      {
        'id': 'dressing_major',
        'name': 'Wound Dressing (Major)',
        'defaultPrice': 3000.0,
      },
      {
        'id': 'catheterization',
        'name': 'Catheterization',
        'defaultPrice': 5000.0,
      },
      {
        'id': 'nasogastric_tube',
        'name': 'Nasogastric Tube Insertion',
        'defaultPrice': 3000.0,
      },
      {
        'id': 'suture_removal',
        'name': 'Suture Removal',
        'defaultPrice': 2000.0,
      },
      {
        'id': 'blood_pressure_monitoring',
        'name': 'BP Monitoring (24hrs)',
        'defaultPrice': 5000.0,
      },
      {
        'id': 'blood_transfusion',
        'name': 'Blood Transfusion',
        'defaultPrice': 15000.0,
      },
      {
        'id': 'iv_fluid_therapy',
        'name': 'IV Fluid Therapy',
        'defaultPrice': 5000.0,
      },
      {
        'id': 'fluid_output_monitoring',
        'name': 'Fluid Output Monitoring',
        'defaultPrice': 2000.0,
      },
      {
        'id': 'patient_feeding',
        'name': 'Patient Feeding (Assisted)',
        'defaultPrice': 1500.0,
      },
    ],
    'In-Patient & Ward Services': [
      // === ADMISSION & DISCHARGE FEES ===
      {
        'id': 'admission_fee',
        'name': 'Admission Processing Fee',
        'defaultPrice': 10000.0,
        'category': 'Admission',
        'autoCharge': 'on_admission',
      },
      {
        'id': 'discharge_fee',
        'name': 'Discharge Processing Fee',
        'defaultPrice': 2000.0,
        'category': 'Discharge',
        'autoCharge': 'on_discharge',
      },

      // === WARD ACCOMMODATION (Per Night) ===
      // General Wards
      {
        'id': 'general_ward_bed',
        'name': 'General Ward Bed (Per Night)',
        'defaultPrice': 5000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'general_ward_male',
        'name': 'Male Ward Bed (Per Night)',
        'defaultPrice': 5000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'general_ward_female',
        'name': 'Female Ward Bed (Per Night)',
        'defaultPrice': 5000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'pediatric_ward',
        'name': 'Pediatric Ward Bed (Per Night)',
        'defaultPrice': 6000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },

      // Semi-Private & Private Wards
      {
        'id': 'semi_private_ward',
        'name': 'Semi-Private Ward (2-4 Beds/Night)',
        'defaultPrice': 10000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'private_ward_standard',
        'name': 'Private Ward Standard (Per Night)',
        'defaultPrice': 15000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'private_ward_ensuite',
        'name': 'Private Ward En-suite (Per Night)',
        'defaultPrice': 20000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'private_ward_deluxe',
        'name': 'Private Ward Deluxe (Per Night)',
        'defaultPrice': 25000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'vip_ward',
        'name': 'VIP Ward (Per Night)',
        'defaultPrice': 35000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },

      // Specialized Wards
      {
        'id': 'maternity_ward',
        'name': 'Maternity Ward Bed (Per Night)',
        'defaultPrice': 8000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'surgical_ward',
        'name': 'Surgical Ward Bed (Per Night)',
        'defaultPrice': 10000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'orthopedic_ward',
        'name': 'Orthopedic Ward Bed (Per Night)',
        'defaultPrice': 10000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'medical_ward',
        'name': 'Medical Ward Bed (Per Night)',
        'defaultPrice': 7000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },

      // Critical Care
      {
        'id': 'icu_general',
        'name': 'ICU Bed (Per Night)',
        'defaultPrice': 50000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'icu_neonatal',
        'name': 'Neonatal ICU (NICU) Bed (Per Night)',
        'defaultPrice': 60000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'icu_pediatric',
        'name': 'Pediatric ICU (PICU) Bed (Per Night)',
        'defaultPrice': 55000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'hdu',
        'name': 'High Dependency Unit (HDU) Bed (Per Night)',
        'defaultPrice': 35000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'isolation_ward',
        'name': 'Isolation Ward Bed (Per Night)',
        'defaultPrice': 25000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },

      // Emergency & Observation
      {
        'id': 'emergency_observation',
        'name': 'Emergency Observation Bed (Per Night)',
        'defaultPrice': 8000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'short_stay_ward',
        'name': 'Short Stay Ward (Per Night)',
        'defaultPrice': 7000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'recovery_room',
        'name': 'Recovery Room (Per Hour)',
        'defaultPrice': 5000.0,
        'category': 'Accommodation',
        'billingCycle': 'hourly',
      },

      // Special Accommodation
      {
        'id': 'amenity_bed',
        'name': 'Amenity Bed (Per Night)',
        'defaultPrice': 12000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },
      {
        'id': 'parent_accommodation',
        'name': 'Parent/Guardian Accommodation (Per Night)',
        'defaultPrice': 3000.0,
        'category': 'Accommodation',
        'billingCycle': 'daily',
      },

      // === DAILY NURSING & CARE SERVICES ===
      // Basic Care
      {
        'id': 'daily_nursing_care',
        'name': 'Daily Nursing Care (24hrs)',
        'defaultPrice': 3000.0,
        'category': 'Nursing Care',
        'billingCycle': 'daily',
        'autoCharge': 'daily_if_admitted',
      },
      {
        'id': 'vital_monitoring_ward',
        'name': 'Vital Signs Monitoring (Per Day)',
        'defaultPrice': 1000.0,
        'category': 'Monitoring',
        'billingCycle': 'per_service',
      },
      {
        'id': 'medication_administration',
        'name': 'Medication Administration (Per Day)',
        'defaultPrice': 1500.0,
        'category': 'Nursing Care',
        'billingCycle': 'per_service',
      },
      {
        'id': 'personal_hygiene_assistance',
        'name': 'Personal Hygiene Assistance',
        'defaultPrice': 2000.0,
        'category': 'Personal Care',
        'billingCycle': 'per_service',
      },

      // Specialized Nursing
      {
        'id': 'special_nursing_care',
        'name': 'Special Nursing Care (1:1)',
        'defaultPrice': 10000.0,
        'category': 'Nursing Care',
        'billingCycle': 'daily',
      },
      {
        'id': 'intensive_nursing',
        'name': 'Intensive Nursing Care (Per Day)',
        'defaultPrice': 8000.0,
        'category': 'Nursing Care',
        'billingCycle': 'daily',
      },
      {
        'id': 'post_op_care',
        'name': 'Post-Operative Care (Per Day)',
        'defaultPrice': 5000.0,
        'category': 'Nursing Care',
        'billingCycle': 'daily',
      },

      // Feeding Services
      {
        'id': 'patient_feeding_standard',
        'name': 'Patient Feeding - Standard Meal',
        'defaultPrice': 1500.0,
        'category': 'Feeding',
        'billingCycle': 'per_meal',
      },
      {
        'id': 'patient_feeding_therapeutic',
        'name': 'Patient Feeding - Therapeutic Diet',
        'defaultPrice': 2500.0,
        'category': 'Feeding',
        'billingCycle': 'per_meal',
      },
      {
        'id': 'patient_feeding_liquid',
        'name': 'Patient Feeding - Liquid Diet',
        'defaultPrice': 2000.0,
        'category': 'Feeding',
        'billingCycle': 'per_meal',
      },
      {
        'id': 'nasogastric_feeding',
        'name': 'Nasogastric Tube Feeding (Per Day)',
        'defaultPrice': 3000.0,
        'category': 'Feeding',
        'billingCycle': 'daily',
      },

      // Monitoring & Equipment
      {
        'id': 'oxygen_therapy',
        'name': 'Oxygen Therapy (Per Day)',
        'defaultPrice': 5000.0,
        'category': 'Monitoring',
        'billingCycle': 'daily',
      },
      {
        'id': 'nebulization_ward',
        'name': 'Nebulization Treatment (Per Session)',
        'defaultPrice': 2000.0,
        'category': 'Treatment',
        'billingCycle': 'per_service',
      },
      {
        'id': 'cardiac_monitoring',
        'name': 'Cardiac Monitoring (Per Day)',
        'defaultPrice': 8000.0,
        'category': 'Monitoring',
        'billingCycle': 'daily',
      },
      {
        'id': 'iv_infusion_monitoring',
        'name': 'IV Infusion Monitoring (Per Day)',
        'defaultPrice': 2000.0,
        'category': 'Monitoring',
        'billingCycle': 'daily',
      },

      // Physiotherapy & Rehabilitation
      {
        'id': 'physiotherapy_session',
        'name': 'Physiotherapy Session',
        'defaultPrice': 5000.0,
        'category': 'Therapy',
        'billingCycle': 'per_service',
      },
      {
        'id': 'chest_physiotherapy',
        'name': 'Chest Physiotherapy',
        'defaultPrice': 4000.0,
        'category': 'Therapy',
        'billingCycle': 'per_service',
      },
      {
        'id': 'occupational_therapy',
        'name': 'Occupational Therapy Session',
        'defaultPrice': 5000.0,
        'category': 'Therapy',
        'billingCycle': 'per_service',
      },

      // Hygiene & Sanitation
      {
        'id': 'bed_linen_change',
        'name': 'Bed Linen Change (Daily)',
        'defaultPrice': 500.0,
        'category': 'Housekeeping',
        'billingCycle': 'daily',
        'autoCharge': 'daily_if_admitted',
      },
      {
        'id': 'bedpan_service',
        'name': 'Bedpan Service',
        'defaultPrice': 500.0,
        'category': 'Personal Care',
        'billingCycle': 'per_service',
      },
      {
        'id': 'bed_bath',
        'name': 'Bed Bath Service',
        'defaultPrice': 2000.0,
        'category': 'Personal Care',
        'billingCycle': 'per_service',
      },

      // Documentation & Coordination
      {
        'id': 'ward_rounds',
        'name': 'Daily Ward Round (Doctor)',
        'defaultPrice': 3000.0,
        'category': 'Medical',
        'billingCycle': 'daily',
        'autoCharge': 'daily_if_admitted',
      },
      {
        'id': 'nursing_notes',
        'name': 'Nursing Documentation (Per Day)',
        'defaultPrice': 1000.0,
        'category': 'Administration',
        'billingCycle': 'daily',
        'autoCharge': 'daily_if_admitted',
      },
      {
        'id': 'discharge_planning',
        'name': 'Discharge Planning Services',
        'defaultPrice': 3000.0,
        'category': 'Discharge',
        'billingCycle': 'once',
        'autoCharge': 'on_discharge',
      },
    ],
    'Wound Care': [
      {
        'id': 'wound_dressing',
        'name': 'Wound Dressing',
        'defaultPrice': 3000.0,
      },
      {
        'id': 'wound_care_assessment',
        'name': 'Wound Care Assessment',
        'defaultPrice': 2000.0,
      },
    ],
    'Invasive Procedures': [
      {
        'id': 'catheterization',
        'name': 'Catheterization',
        'defaultPrice': 5000.0,
      },
      {
        'id': 'ng_tube_insertion',
        'name': 'NG Tube Insertion',
        'defaultPrice': 4000.0,
      },
      {'id': 'iv_line_care', 'name': 'IV Line Care', 'defaultPrice': 2000.0},
    ],
    'Assessment': [
      {
        'id': 'vital_signs_monitoring',
        'name': 'Vital Signs Monitoring',
        'defaultPrice': 500.0,
      },
      {
        'id': 'blood_glucose_monitoring',
        'name': 'Blood Glucose Monitoring',
        'defaultPrice': 1000.0,
      },
    ],
    'Medication Administration': [
      {
        'id': 'injections',
        'name': 'Injections (IM/IV/SC)',
        'defaultPrice': 1500.0,
      },
      {
        'id': 'oral_medication',
        'name': 'Oral Medication Administration',
        'defaultPrice': 500.0,
      },
    ],
    'Diagnostic Procedures': [
      {'id': 'ecg', 'name': 'ECG (Electrocardiogram)', 'defaultPrice': 5000.0},
      {
        'id': 'echocardiogram',
        'name': 'Echocardiogram',
        'defaultPrice': 25000.0,
      },
      {
        'id': 'pulse_oximetry',
        'name': 'Pulse Oximetry Monitoring',
        'defaultPrice': 2000.0,
      },
      {
        'id': 'blood_glucose_monitoring',
        'name': 'Blood Glucose Monitoring',
        'defaultPrice': 1000.0,
      },
    ],
    'Laboratory': [
      {
        'id': 'specimen_collection',
        'name': 'Specimen Collection',
        'defaultPrice': 1000.0,
      },
    ],
    'Respiratory Care': [
      {
        'id': 'oxygen_therapy',
        'name': 'Oxygen Therapy (Per Hour)',
        'defaultPrice': 2000.0,
        'billingCycle': 'hourly',
      },
      {
        'id': 'suction_procedures',
        'name': 'Suction Procedures',
        'defaultPrice': 2500.0,
      },
    ],
    'Patient Care': [
      {
        'id': 'patient_positioning',
        'name': 'Patient Positioning',
        'defaultPrice': 500.0,
      },
    ],
    'Minor Surgical Procedures': [
      {
        'id': 'suturing',
        'name': 'Suturing (Simple Laceration)',
        'defaultPrice': 5000.0,
      },
      {
        'id': 'incision_drainage',
        'name': 'Incision & Drainage',
        'defaultPrice': 7000.0,
      },
      {
        'id': 'nail_removal',
        'name': 'Nail Removal (Partial/Complete)',
        'defaultPrice': 8000.0,
      },
      {
        'id': 'foreign_body_removal',
        'name': 'Foreign Body Removal',
        'defaultPrice': 6000.0,
      },
      {
        'id': 'lipoma_excision',
        'name': 'Lipoma Excision',
        'defaultPrice': 15000.0,
      },
      {
        'id': 'sebaceous_cyst_excision',
        'name': 'Sebaceous Cyst Excision',
        'defaultPrice': 12000.0,
      },
      {'id': 'skin_biopsy', 'name': 'Skin Biopsy', 'defaultPrice': 10000.0},
      {
        'id': 'wart_removal',
        'name': 'Wart Removal (Electrocautery)',
        'defaultPrice': 5000.0,
      },
      {
        'id': 'circumcision',
        'name': 'Circumcision (Adult)',
        'defaultPrice': 20000.0,
      },
      {'id': 'ear_syringing', 'name': 'Ear Syringing', 'defaultPrice': 2000.0},
    ],
    'Major Surgical Procedures': [
      {'id': 'appendectomy', 'name': 'Appendectomy', 'defaultPrice': 200000.0},
      {
        'id': 'hernia_repair',
        'name': 'Hernia Repair',
        'defaultPrice': 150000.0,
      },
      {
        'id': 'cesarean_section',
        'name': 'Cesarean Section (C-Section)',
        'defaultPrice': 250000.0,
      },
      {
        'id': 'laparotomy',
        'name': 'Laparotomy (Exploratory)',
        'defaultPrice': 300000.0,
      },
      {
        'id': 'thyroidectomy',
        'name': 'Thyroidectomy',
        'defaultPrice': 350000.0,
      },
      {'id': 'mastectomy', 'name': 'Mastectomy', 'defaultPrice': 400000.0},
      {'id': 'hysterectomy', 'name': 'Hysterectomy', 'defaultPrice': 300000.0},
      {
        'id': 'bowel_resection',
        'name': 'Bowel Resection',
        'defaultPrice': 500000.0,
      },
      {'id': 'craniotomy', 'name': 'Craniotomy', 'defaultPrice': 1000000.0},
      {
        'id': 'joint_replacement',
        'name': 'Joint Replacement (Hip/Knee)',
        'defaultPrice': 800000.0,
      },
    ],
    'Maternity Services': [
      {
        'id': 'antenatal_visit',
        'name': 'Antenatal Visit',
        'defaultPrice': 5000.0,
      },
      {
        'id': 'delivery_normal',
        'name': 'Normal Delivery',
        'defaultPrice': 50000.0,
      },
      {
        'id': 'delivery_caesarean',
        'name': 'Caesarean Section',
        'defaultPrice': 150000.0,
      },
      {
        'id': 'postnatal_care',
        'name': 'Postnatal Care',
        'defaultPrice': 5000.0,
      },
      {
        'id': 'family_planning',
        'name': 'Family Planning Consultation',
        'defaultPrice': 3000.0,
      },
    ],
    'Immunization': [
      {'id': 'bcg_vaccine', 'name': 'BCG Vaccine', 'defaultPrice': 2000.0},
      {'id': 'polio_vaccine', 'name': 'Polio Vaccine', 'defaultPrice': 1500.0},
      {'id': 'dpt_vaccine', 'name': 'DPT Vaccine', 'defaultPrice': 2000.0},
      {
        'id': 'hepatitis_b_vaccine',
        'name': 'Hepatitis B Vaccine',
        'defaultPrice': 3000.0,
      },
      {
        'id': 'measles_vaccine',
        'name': 'Measles Vaccine',
        'defaultPrice': 2000.0,
      },
      {
        'id': 'yellow_fever_vaccine',
        'name': 'Yellow Fever Vaccine',
        'defaultPrice': 5000.0,
      },
      {'id': 'covid_vaccine', 'name': 'COVID-19 Vaccine', 'defaultPrice': 0.0},
    ],
    'Public Health Services': [
      {
        'id': 'immunization_management',
        'name': 'Immunization Program Management',
        'defaultPrice': 5000.0,
        'category': 'Program Management',
        'billingCycle': 'per_service',
      },
      {
        'id': 'environmental_surveillance',
        'name': 'Environmental Health Surveillance',
        'defaultPrice': 3000.0,
        'category': 'Surveillance',
        'billingCycle': 'per_service',
      },
      {
        'id': 'disease_surveillance_report',
        'name': 'Disease Surveillance & Reporting',
        'defaultPrice': 2000.0,
        'category': 'Surveillance',
        'billingCycle': 'per_service',
      },
      {
        'id': 'ipc_surveillance',
        'name': 'Infection Prevention & Control (IPC) Audit',
        'defaultPrice': 5000.0,
        'category': 'Facility-wide',
        'billingCycle': 'per_service',
      },
      {
        'id': 'outbreak_investigation',
        'name': 'Outbreak Investigation & Response',
        'defaultPrice': 10000.0,
        'category': 'Facility-wide',
        'billingCycle': 'per_service',
      },
      {
        'id': 'health_education_session',
        'name': 'Health Education Session',
        'defaultPrice': 5000.0,
        'category': 'Community Engagement',
        'billingCycle': 'per_service',
      },
      {
        'id': 'health_outreach_activity',
        'name': 'Community Health Outreach Activity',
        'defaultPrice': 15000.0,
        'category': 'Community Engagement',
        'billingCycle': 'per_service',
      },
      {
        'id': 'hand_hygiene_audit',
        'name': 'Hand Hygiene Compliance Audit',
        'defaultPrice': 3000.0,
        'category': 'IPC Activities',
        'billingCycle': 'per_service',
      },
      {
        'id': 'hai_surveillance',
        'name': 'Healthcare-Associated Infection (HAI) Surveillance',
        'defaultPrice': 5000.0,
        'category': 'Facility-wide',
        'billingCycle': 'per_service',
      },
      {
        'id': 'mobile_clinic_service',
        'name': 'Mobile Clinic Service Delivery',
        'defaultPrice': 20000.0,
        'category': 'Community Engagement',
        'billingCycle': 'per_service',
      },
      {
        'id': 'community_visit',
        'name': 'Community Health Visit',
        'defaultPrice': 8000.0,
        'category': 'Community Engagement',
        'billingCycle': 'per_service',
      },
      {
        'id': 'mass_immunization_campaign',
        'name': 'Mass Immunization Campaign',
        'defaultPrice': 50000.0,
        'category': 'Program Management',
        'billingCycle': 'per_service',
      },
    ],
    'Other Services': [
      {
        'id': 'medical_report',
        'name': 'Medical Report/Certificate',
        'defaultPrice': 5000.0,
      },
      {
        'id': 'referral_letter',
        'name': 'Referral Letter',
        'defaultPrice': 2000.0,
      },
      {
        'id': 'prescription_refill',
        'name': 'Prescription Refill',
        'defaultPrice': 1000.0,
      },
      {
        'id': 'health_talk',
        'name': 'Health Education/Talk',
        'defaultPrice': 0.0,
      },
      {
        'id': 'ambulance_service',
        'name': 'Ambulance Service',
        'defaultPrice': 20000.0,
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadServicePrices();
  }

  Future<void> _loadServicePrices() async {
    try {
      setState(() => _isLoading = true);

      final doc = await _firestore
          .collection('facility_service_prices')
          .doc(widget.facilityId)
          .get();

      if (doc.exists) {
        setState(() {
          _servicePrices = Map<String, dynamic>.from(doc.data() ?? {});
          _servicePrices.remove('facilityId');
          _servicePrices.remove('facilityName');
          _servicePrices.remove('lastUpdated');
          _servicePrices.remove('updatedBy');
        });

        // Merge any missing default prices (for new services added to the system)
        await _mergeNewDefaultPrices();
      } else {
        // Initialize with default prices
        await _initializeDefaultPrices();
      }

      // Load custom services
      await _loadCustomServices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading prices: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCustomServices() async {
    try {
      final doc = await _firestore
          .collection('facility_custom_services')
          .doc(widget.facilityId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['services'] != null) {
          final customServicesData = data['services'] as Map<String, dynamic>;

          setState(() {
            _customServices = {};
            customServicesData.forEach((category, services) {
              if (services is List) {
                _customServices[category] = List<Map<String, dynamic>>.from(
                  services.map((s) => Map<String, dynamic>.from(s as Map)),
                );
              }
            });
          });
        }
      }
    } catch (e) {
      // Ignore errors loading custom services
    }
  }

  Future<void> _mergeNewDefaultPrices() async {
    // Check for any new services in _serviceCategories that aren't in _servicePrices
    final newPrices = <String, dynamic>{};
    bool hasNewServices = false;

    _serviceCategories.forEach((category, services) {
      for (var service in services) {
        final serviceId = service['id'];
        if (!_servicePrices.containsKey(serviceId)) {
          newPrices[serviceId] = service['defaultPrice'];
          hasNewServices = true;
        }
      }
    });

    // If there are new services, merge them into Firestore
    if (hasNewServices) {
      newPrices['lastUpdated'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('facility_service_prices')
          .doc(widget.facilityId)
          .set(newPrices, SetOptions(merge: true));

      // Update local state
      setState(() {
        _servicePrices.addAll(newPrices);
        _servicePrices.remove('lastUpdated');
      });
    }
  }

  Future<void> _initializeDefaultPrices() async {
    final defaultPrices = <String, dynamic>{
      'facilityId': widget.facilityId,
      'facilityName': widget.facilityName,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    // Add all default prices
    _serviceCategories.forEach((category, services) {
      for (var service in services) {
        defaultPrices[service['id']] = service['defaultPrice'];
      }
    });

    await _firestore
        .collection('facility_service_prices')
        .doc(widget.facilityId)
        .set(defaultPrices, SetOptions(merge: true));

    setState(() {
      _servicePrices = Map<String, dynamic>.from(defaultPrices);
      _servicePrices.remove('facilityId');
      _servicePrices.remove('facilityName');
      _servicePrices.remove('lastUpdated');
      _servicePrices.remove('updatedBy');
    });
  }

  Future<void> _updateServicePrice(String serviceId, double newPrice) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      await _firestore
          .collection('facility_service_prices')
          .doc(widget.facilityId)
          .set({
            serviceId: newPrice,
            'lastUpdated': FieldValue.serverTimestamp(),
            'updatedBy': user?.email ?? 'Unknown',
          }, SetOptions(merge: true));

      setState(() {
        _servicePrices[serviceId] = newPrice;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating price: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditPriceDialog(Map<String, dynamic> service) async {
    final controller = TextEditingController(
      text: (_servicePrices[service['id']] ?? service['defaultPrice'])
          .toStringAsFixed(2),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Price: ${service['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Default Price: ₦${service['defaultPrice'].toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'New Price (NGN)',
                prefixText: '₦ ',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'Note: This price will apply to all services of this type in your facility.',
              style: TextStyle(fontSize: 11, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(controller.text);
              if (price != null && price >= 0) {
                Navigator.pop(context, price);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid price'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateServicePrice(service['id'], result);
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Default Prices?'),
        content: const Text(
          'This will reset ALL service prices to their default values. This action cannot be undone.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _initializeDefaultPrices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All prices reset to defaults'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showAddServiceDialog() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController(text: '0.00');
    final formController = TextEditingController();
    final unitController = TextEditingController();
    String? selectedCategory = _serviceCategories.keys.first;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isPharmacy = selectedCategory == 'Pharmacy/Medications';

          return AlertDialog(
            title: Text(
              isPharmacy ? 'Add Custom Medication' : 'Add Custom Service',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: isPharmacy
                          ? 'Medication Name *'
                          : 'Service Name *',
                      hintText: isPharmacy
                          ? 'e.g., Amoxicillin 250mg'
                          : 'e.g., Custom Consultation',
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      border: OutlineInputBorder(),
                    ),
                    items: _serviceCategories.keys.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCategory = value;
                      });
                    },
                  ),
                  if (isPharmacy) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: formController.text.isEmpty
                          ? null
                          : formController.text,
                      decoration: const InputDecoration(
                        labelText: 'Form *',
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Select dosage form'),
                      items: const [
                        DropdownMenuItem(
                          value: 'Tablet',
                          child: Text('Tablet'),
                        ),
                        DropdownMenuItem(
                          value: 'Capsule',
                          child: Text('Capsule'),
                        ),
                        DropdownMenuItem(
                          value: 'Syrup',
                          child: Text('Syrup/Suspension'),
                        ),
                        DropdownMenuItem(
                          value: 'Injection',
                          child: Text('Injection'),
                        ),
                        DropdownMenuItem(
                          value: 'IV Fluid',
                          child: Text('IV Fluid'),
                        ),
                        DropdownMenuItem(
                          value: 'Cream',
                          child: Text('Cream/Ointment'),
                        ),
                        DropdownMenuItem(value: 'Drops', child: Text('Drops')),
                        DropdownMenuItem(
                          value: 'Inhaler',
                          child: Text('Inhaler'),
                        ),
                        DropdownMenuItem(
                          value: 'Sachet',
                          child: Text('Sachet/Powder'),
                        ),
                        DropdownMenuItem(
                          value: 'Suppository',
                          child: Text('Suppository'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          formController.text = value ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit *',
                        hintText: 'e.g., Per Tablet, Per Pack, Per Vial',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price (NGN) *',
                      prefixText: '₦ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '* Required fields',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final price = double.tryParse(priceController.text);
                  final form = formController.text.trim();
                  final unit = unitController.text.trim();

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isPharmacy
                              ? 'Please enter medication name'
                              : 'Please enter service name',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (isPharmacy && form.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select dosage form'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (isPharmacy && unit.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter unit'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (price == null || price < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid price'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context, {
                    'name': name,
                    'category': selectedCategory,
                    'price': price,
                    'form': isPharmacy ? form : null,
                    'unit': isPharmacy ? unit : null,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(isPharmacy ? 'Add Medication' : 'Add Service'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      await _addCustomService(
        result['name'],
        result['category'],
        result['price'],
        form: result['form'],
        unit: result['unit'],
      );
    }
  }

  Future<void> _addCustomService(
    String name,
    String category,
    double price, {
    String? form,
    String? unit,
  }) async {
    try {
      // Generate a unique ID for the custom service
      final serviceId = 'custom_${DateTime.now().millisecondsSinceEpoch}';

      // Add to local state
      setState(() {
        if (!_customServices.containsKey(category)) {
          _customServices[category] = [];
        }

        final serviceData = {
          'id': serviceId,
          'name': name,
          'defaultPrice': price,
          'isCustom': true,
        };

        // Add medication-specific fields if provided
        if (form != null) serviceData['form'] = form;
        if (unit != null) serviceData['unit'] = unit;

        _customServices[category]!.add(serviceData);

        // Also add to service prices
        _servicePrices[serviceId] = price;
      });

      // Save to Firestore
      await _firestore
          .collection('facility_custom_services')
          .doc(widget.facilityId)
          .set({
            'facilityId': widget.facilityId,
            'facilityName': widget.facilityName,
            'services': _customServices,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Also update the price
      await _firestore
          .collection('facility_service_prices')
          .doc(widget.facilityId)
          .set({
            serviceId: price,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              category == 'Pharmacy/Medications'
                  ? 'Medication added successfully!'
                  : 'Custom service added successfully!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCustomService(
    Map<String, dynamic> service,
    String category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Custom Service?'),
        content: Text(
          'Are you sure you want to delete "${service['name']}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final serviceId = service['id'];

        // Remove from local state
        setState(() {
          _customServices[category]?.removeWhere((s) => s['id'] == serviceId);
          if (_customServices[category]?.isEmpty == true) {
            _customServices.remove(category);
          }
          _servicePrices.remove(serviceId);
        });

        // Update Firestore
        await _firestore
            .collection('facility_custom_services')
            .doc(widget.facilityId)
            .set({
              'services': _customServices,
              'lastUpdated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        // Remove from prices collection
        await _firestore
            .collection('facility_service_prices')
            .doc(widget.facilityId)
            .update({serviceId: FieldValue.delete()});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting service: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Management'),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadServicePrices,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') {
                _resetToDefaults();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restore, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Reset to Defaults'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Manage all service prices for ${widget.facilityName}. Changes apply immediately across the facility.',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Service categories
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _serviceCategories.length,
                    itemBuilder: (context, index) {
                      final category = _serviceCategories.keys.elementAt(index);
                      final defaultServices = _serviceCategories[category]!;
                      final customServices = _customServices[category] ?? [];
                      final services = [...defaultServices, ...customServices];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ExpansionTile(
                          title: Text(
                            category,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text('${services.length} services'),
                          children: services.map((service) {
                            final currentPrice =
                                _servicePrices[service['id']] ??
                                service['defaultPrice'];
                            final isModified =
                                currentPrice != service['defaultPrice'];
                            final isCustom = service['isCustom'] == true;
                            final hasForm = service['form'] != null;
                            final hasUnit = service['unit'] != null;

                            // Build subtitle text
                            String? subtitleText;
                            if (hasForm || hasUnit) {
                              final formText = hasForm ? service['form'] : '';
                              final unitText = hasUnit ? service['unit'] : '';
                              subtitleText = [
                                formText,
                                unitText,
                              ].where((s) => s.isNotEmpty).join(' • ');
                            }
                            if (isModified) {
                              final modText =
                                  'Default: ₦${service['defaultPrice'].toStringAsFixed(2)}';
                              subtitleText = subtitleText != null
                                  ? '$subtitleText\n$modText'
                                  : modText;
                            }

                            return ListTile(
                              title: Row(
                                children: [
                                  Expanded(child: Text(service['name'])),
                                  if (isCustom)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'CUSTOM',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: subtitleText != null
                                  ? Text(
                                      subtitleText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isModified
                                            ? Colors.grey
                                            : Colors.grey.shade700,
                                        decoration: isModified
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₦${currentPrice.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isModified
                                              ? Colors.orange
                                              : Colors.black,
                                        ),
                                      ),
                                      if (isModified)
                                        const Text(
                                          'Modified',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    color: Colors.blue,
                                    onPressed: () =>
                                        _showEditPriceDialog(service),
                                    tooltip: 'Edit Price',
                                  ),
                                  if (isCustom)
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      color: Colors.red,
                                      onPressed: () => _deleteCustomService(
                                        service,
                                        category,
                                      ),
                                      tooltip: 'Delete Service',
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddServiceDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Service'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }
}
