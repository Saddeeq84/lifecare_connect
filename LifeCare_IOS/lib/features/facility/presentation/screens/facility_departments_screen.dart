// lib/features/facility/presentation/screens/facility_departments_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FacilityDepartmentsScreen extends StatefulWidget {
  const FacilityDepartmentsScreen({super.key});

  @override
  State<FacilityDepartmentsScreen> createState() =>
      _FacilityDepartmentsScreenState();
}

class _FacilityDepartmentsScreenState extends State<FacilityDepartmentsScreen> {
  String? _facilityType;
  String? _facilityName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFacilityInfo();
  }

  Future<void> _loadFacilityInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (mounted) {
          setState(() {
            _facilityType = data?['type'] as String?;
            _facilityName = data?['name'] as String?;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading facility info: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, Map<String, dynamic>> _getDepartmentDetails() {
    return {
      // Hospital Departments
      'Emergency Department': {
        'description':
            '24/7 immediate medical care for life-threatening conditions and injuries',
        'services': [
          'Trauma care and resuscitation',
          'Emergency surgery',
          'Critical patient stabilization',
          'Triage and assessment',
          'Emergency medications',
        ],
        'roles': [
          'Emergency Physician',
          'Emergency Nurse',
          'Paramedic',
          'Triage Nurse',
        ],
      },
      'Inpatient Department (IPD)': {
        'description':
            'Round-the-clock care for hospitalized patients requiring extended treatment',
        'services': [
          'Patient admission and discharge',
          'Ward management',
          'Medication administration',
          'Patient monitoring',
          'Post-operative care',
        ],
        'roles': ['Doctor', 'Nurse', 'Ward Clerk', 'Patient Care Assistant'],
      },
      'Intensive Care Unit (ICU)': {
        'description':
            'Specialized care for critically ill patients requiring constant monitoring',
        'services': [
          'Critical patient monitoring',
          'Ventilator support',
          'Advanced life support',
          'Multi-organ support',
          'Invasive procedures',
        ],
        'roles': [
          'Intensivist',
          'ICU Nurse',
          'Respiratory Therapist',
          'Critical Care Specialist',
        ],
      },
      'Surgery Department': {
        'description':
            'Performs surgical procedures and provides pre/post-operative care',
        'services': [
          'Elective surgeries',
          'Emergency operations',
          'Pre-operative assessment',
          'Post-operative care',
          'Surgical instrument sterilization',
        ],
        'roles': [
          'Surgeon',
          'Anesthesiologist',
          'Scrub Nurse',
          'Operating Room Technician',
        ],
      },
      'Pediatrics': {
        'description':
            'Specialized medical care for infants, children, and adolescents',
        'services': [
          'Child health assessments',
          'Immunizations',
          'Growth monitoring',
          'Pediatric treatments',
          'Developmental screening',
        ],
        'roles': ['Pediatrician', 'Pediatric Nurse', 'Child Life Specialist'],
      },
      'Obstetrics & Gynecology': {
        'description':
            'Women\'s reproductive health, pregnancy, childbirth, and postpartum care',
        'services': [
          'Prenatal care',
          'Labor and delivery',
          'Gynecological examinations',
          'Family planning',
          'Postnatal care',
        ],
        'roles': ['Obstetrician', 'Gynecologist', 'Midwife', 'OB Nurse'],
      },
      'Orthopedics': {
        'description':
            'Diagnosis and treatment of musculoskeletal system disorders',
        'services': [
          'Fracture management',
          'Joint replacement',
          'Sports injury treatment',
          'Spine surgery',
          'Cast and splint application',
        ],
        'roles': [
          'Orthopedic Surgeon',
          'Orthopedic Nurse',
          'Physical Therapist',
        ],
      },
      'Cardiology': {
        'description':
            'Diagnosis and treatment of heart and cardiovascular diseases',
        'services': [
          'ECG and stress tests',
          'Echocardiography',
          'Cardiac catheterization',
          'Heart disease management',
          'Pacemaker implantation',
        ],
        'roles': ['Cardiologist', 'Cardiac Nurse', 'Cardiovascular Technician'],
      },
      'Neurology': {
        'description':
            'Treatment of nervous system disorders including brain and spinal cord',
        'services': [
          'Neurological assessments',
          'EEG monitoring',
          'Stroke management',
          'Seizure treatment',
          'Neurosurgical procedures',
        ],
        'roles': [
          'Neurologist',
          'Neurosurgeon',
          'Neuro Nurse',
          'EEG Technician',
        ],
      },
      'Radiology': {
        'description': 'Medical imaging for diagnosis and treatment guidance',
        'services': [
          'X-ray imaging',
          'CT scans',
          'MRI scans',
          'Ultrasound',
          'Image interpretation and reporting',
        ],
        'roles': [
          'Radiologist',
          'Radiographer',
          'MRI Technician',
          'Ultrasound Technician',
        ],
      },
      'Public Health': {
        'description':
            'Promotes community health through prevention, education, and environmental health following WHO and Nigeria CDC guidelines',
        'services': [
          'Immunization programs (Nigeria immunization schedule)',
          'Disease surveillance and notifiable disease reporting',
          'Health education and promotion',
          'Environmental health and hospital waste management',
          'Infection prevention and control (HAI surveillance)',
          'Outbreak investigation and response',
          'Hand hygiene surveillance',
          'Water quality and sanitation monitoring',
          'Food safety inspections',
          'Community outreach and health campaigns',
        ],
        'roles': [
          'Public Health Officer',
          'Community Health Officer',
          'Community Health Extension Worker',
          'Health Educator',
          'Environmental Health Officer',
          'Disease Surveillance Officer',
          'Epidemiologist',
        ],
      },
      'Laboratory': {
        'description':
            'Performs diagnostic tests on blood, tissue, and body fluids',
        'services': [
          'Blood tests and analysis',
          'Urine analysis',
          'Microbiology testing',
          'Pathology examinations',
          'Quality control',
        ],
        'roles': [
          'Lab Scientist',
          'Medical Lab Technician',
          'Phlebotomist',
          'Lab Manager',
        ],
      },
      'Pharmacy': {
        'description':
            'Medication management, dispensing, and pharmaceutical care',
        'services': [
          'Medication dispensing',
          'Drug inventory management',
          'Prescription verification',
          'Patient counseling',
          'Drug interaction monitoring',
        ],
        'roles': [
          'Pharmacist',
          'Pharmacy Technician',
          'Pharmacy Assistant',
          'Inventory Manager',
        ],
      },
      'Physiotherapy': {
        'description': 'Physical rehabilitation and movement therapy services',
        'services': [
          'Physical assessments',
          'Exercise therapy',
          'Manual therapy',
          'Electrotherapy',
          'Rehabilitation programs',
        ],
        'roles': [
          'Physiotherapist',
          'Physical Therapy Assistant',
          'Rehabilitation Specialist',
        ],
      },
      'Nutrition & Dietetics': {
        'description':
            'Nutritional assessment, counseling, and therapeutic diet planning',
        'services': [
          'Nutritional assessments',
          'Diet planning',
          'Therapeutic nutrition',
          'Nutrition counseling',
          'Food service management',
        ],
        'roles': [
          'Dietitian',
          'Nutritionist',
          'Diet Technician',
          'Food Service Manager',
        ],
      },
      'Medical Records': {
        'description':
            'Management of patient medical records, front desk operations and patient service coordination',
        'services': [
          'Patient registration',
          'Patient check-in/check-out',
          'Appointment scheduling',
          'Record keeping',
          'Data entry and filing',
          'Report generation',
          'Records retrieval',
          'Insurance verification',
          'Payment collection',
          'Visitor guidance',
        ],
        'roles': [
          'Medical Records Officer',
          'Data Entry Clerk',
          'Records Manager',
          'Front Desk Officer',
          'Customer Service Representative',
        ],
      },
      'Housekeeping': {
        'description':
            'Maintains cleanliness and hygiene throughout the facility',
        'services': [
          'Ward cleaning',
          'Waste management',
          'Disinfection and sterilization',
          'Linen management',
          'Infection control support',
        ],
        'roles': [
          'Cleaner',
          'Housekeeping Supervisor',
          'Waste Management Officer',
        ],
      },
      'Security': {
        'description':
            'Ensures safety and security of patients, staff, and facility',
        'services': [
          'Access control',
          'Surveillance monitoring',
          'Emergency response',
          'Visitor management',
          'Asset protection',
        ],
        'roles': ['Security', 'Security Supervisor', 'Safety Officer'],
      },
      'Dental Department': {
        'description':
            'Comprehensive dental and oral health services within the hospital',
        'services': [
          'Dental consultations',
          'Oral examinations',
          'Dental procedures',
          'Oral surgery',
          'Preventive care',
        ],
        'roles': [
          'Dentist',
          'Dental Surgeon',
          'Dental Therapist',
          'Dental Technician',
        ],
      },
      'Ophthalmology Department': {
        'description': 'Eye care and vision services within the hospital',
        'services': [
          'Eye examinations',
          'Vision testing',
          'Eye surgery',
          'Contact lens fitting',
          'Glaucoma management',
        ],
        'roles': ['Ophthalmologist', 'Optometrist', 'Ophthalmic Technician'],
      },
      'ENT Department': {
        'description': 'Ear, Nose, and Throat specialized medical services',
        'services': [
          'ENT examinations',
          'Hearing tests',
          'Sinus treatment',
          'Throat procedures',
          'Balance disorder treatment',
        ],
        'roles': ['ENT Surgeon', 'ENT Nurse', 'Audiologist'],
      },
      'Nursing': {
        'description': 'Professional nursing care and patient support services',
        'services': [
          'Vital signs monitoring',
          'Wound care and dressing',
          'Medication administration',
          'Patient education',
          'Injection services',
        ],
        'roles': ['Nurse', 'Nursing Assistant', 'Nurse Practitioner'],
      },

      // Clinic Departments
      'Out-Patient Department (OPD)': {
        'description':
            'Primary healthcare consultations, outpatient services, and basic medical care for non-admitted patients',
        'services': [
          'General medical consultations',
          'Follow-up appointments',
          'Health screenings',
          'Minor procedures',
          'Minor illness treatment',
          'Preventive care',
          'Specialist referrals',
          'Queue management',
          'Medical records management',
          'Vital signs recording',
          'Patient admission coordination',
        ],
        'roles': [
          'Doctor',
          'Nurse',
          'Medical Assistant',
          'Medical Records Officer',
        ],
      },
      'Specialist Department': {
        'description':
            'Specialized medical consultations and advanced treatments by medical specialists',
        'services': [
          'Specialist consultations',
          'Advanced diagnostic procedures',
          'Specialized treatment plans',
          'Follow-up specialist care',
          'Medical specialty procedures',
          'Expert medical opinions',
          'Referral coordination',
          'Complex case management',
          'Specialized therapy sessions',
          'Advanced medical interventions',
        ],
        'roles': [
          'Medical Specialist',
          'Specialist Nurse',
          'Medical Fellow',
          'Specialty Assistant',
        ],
      },

      // Dental Clinic Departments
      'General Dentistry': {
        'description': 'Comprehensive dental care and oral health services',
        'services': [
          'Dental examinations',
          'Teeth cleaning',
          'Cavity fillings',
          'Tooth extractions',
          'Oral health education',
        ],
        'roles': ['Dentist', 'Dental Hygienist', 'Dental Assistant'],
      },
      'Oral Surgery': {
        'description':
            'Surgical procedures for dental and maxillofacial conditions',
        'services': [
          'Tooth extractions',
          'Wisdom tooth removal',
          'Dental implants',
          'Jaw surgery',
          'Facial trauma treatment',
        ],
        'roles': ['Oral Surgeon', 'Surgical Assistant', 'Anesthesiologist'],
      },
      'Orthodontics': {
        'description': 'Correction of teeth and jaw alignment issues',
        'services': [
          'Braces fitting',
          'Teeth alignment',
          'Retainer placement',
          'Jaw repositioning',
          'Progress monitoring',
        ],
        'roles': ['Orthodontist', 'Orthodontic Assistant', 'Dental Technician'],
      },
      'Periodontics': {
        'description': 'Treatment of gum diseases and supporting structures',
        'services': [
          'Gum disease treatment',
          'Scaling and root planing',
          'Gum surgery',
          'Dental implant placement',
          'Periodontal maintenance',
        ],
        'roles': ['Periodontist', 'Dental Hygienist', 'Periodontal Assistant'],
      },
      'Pediatric Dentistry': {
        'description': 'Specialized dental care for children',
        'services': [
          'Child dental examinations',
          'Preventive treatments',
          'Fluoride applications',
          'Cavity treatment',
          'Dental education for children',
        ],
        'roles': [
          'Pediatric Dentist',
          'Pediatric Dental Assistant',
          'Child Behavior Specialist',
        ],
      },

      // Eye Clinic Departments
      'Ophthalmology': {
        'description': 'Medical and surgical treatment of eye diseases',
        'services': [
          'Eye examinations',
          'Cataract surgery',
          'Glaucoma treatment',
          'Retinal procedures',
          'Laser eye surgery',
        ],
        'roles': ['Ophthalmologist', 'Ophthalmic Nurse', 'Surgical Technician'],
      },
      'Optometry': {
        'description': 'Eye health examinations and vision correction',
        'services': [
          'Vision testing',
          'Prescription of glasses',
          'Contact lens fitting',
          'Eye disease detection',
          'Vision therapy',
        ],
        'roles': ['Optometrist', 'Optometric Technician', 'Vision Therapist'],
      },
      'Contact Lens Service': {
        'description': 'Specialized contact lens fitting and care',
        'services': [
          'Contact lens fitting',
          'Lens type selection',
          'Usage training',
          'Follow-up care',
          'Lens replacement',
        ],
        'roles': ['Optometrist', 'Contact Lens Specialist', 'Optician'],
      },
      'Optical Dispensary': {
        'description': 'Eyewear selection, fitting, and adjustments',
        'services': [
          'Eyeglass dispensing',
          'Frame selection',
          'Lens fitting',
          'Adjustments and repairs',
          'Optical accessories',
        ],
        'roles': ['Optician', 'Optical Assistant', 'Optical Technician'],
      },
      'Surgical Unit': {
        'description': 'Specialized eye surgical procedures',
        'services': [
          'Pre-operative assessment',
          'Eye surgeries',
          'Post-operative care',
          'Laser procedures',
          'Surgical recovery monitoring',
        ],
        'roles': [
          'Surgeon',
          'Surgical Nurse',
          'Anesthesiologist',
          'Operating Room Technician',
        ],
      },

      // Physiotherapy Center Departments
      'Orthopedic Physiotherapy': {
        'description':
            'Rehabilitation for musculoskeletal injuries and conditions',
        'services': [
          'Post-surgery rehabilitation',
          'Fracture recovery',
          'Joint mobilization',
          'Strength training',
          'Pain management',
        ],
        'roles': [
          'Physiotherapist',
          'Orthopedic Specialist',
          'Rehabilitation Assistant',
        ],
      },
      'Neurological Physiotherapy': {
        'description': 'Treatment for nervous system disorders and injuries',
        'services': [
          'Stroke rehabilitation',
          'Balance training',
          'Gait training',
          'Spinal cord injury therapy',
          'Movement disorder management',
        ],
        'roles': [
          'Neuro Physiotherapist',
          'Occupational Therapist',
          'Movement Specialist',
        ],
      },
      'Cardiopulmonary Physiotherapy': {
        'description': 'Respiratory and cardiac rehabilitation services',
        'services': [
          'Breathing exercises',
          'Chest physiotherapy',
          'Cardiac rehabilitation',
          'Endurance training',
          'Respiratory care',
        ],
        'roles': ['Cardiopulmonary Physiotherapist', 'Respiratory Therapist'],
      },
      'Sports Physiotherapy': {
        'description': 'Treatment and prevention of sports-related injuries',
        'services': [
          'Sports injury assessment',
          'Performance enhancement',
          'Injury prevention',
          'Return-to-sport programs',
          'Athletic conditioning',
        ],
        'roles': [
          'Sports Physiotherapist',
          'Athletic Trainer',
          'Sports Therapist',
        ],
      },
      'Pediatric Physiotherapy': {
        'description':
            'Physical therapy for children and developmental conditions',
        'services': [
          'Developmental assessment',
          'Motor skills training',
          'Postural correction',
          'Neurological conditions',
          'Congenital disorder management',
        ],
        'roles': ['Pediatric Physiotherapist', 'Child Development Specialist'],
      },
      'Geriatric Physiotherapy': {
        'description': 'Rehabilitation services for elderly patients',
        'services': [
          'Fall prevention',
          'Mobility training',
          'Arthritis management',
          'Balance exercises',
          'Age-related condition treatment',
        ],
        'roles': ['Geriatric Physiotherapist', 'Elderly Care Specialist'],
      },

      // Mental Health Center Departments
      'Psychiatry': {
        'description': 'Medical treatment of mental health disorders',
        'services': [
          'Psychiatric evaluation',
          'Medication management',
          'Crisis intervention',
          'Mental illness treatment',
          'Follow-up care',
        ],
        'roles': [
          'Psychiatrist',
          'Psychiatric Nurse',
          'Mental Health Specialist',
        ],
      },
      'Clinical Psychology': {
        'description': 'Psychological assessment and therapy services',
        'services': [
          'Psychological testing',
          'Psychotherapy',
          'Behavioral therapy',
          'Cognitive assessment',
          'Treatment planning',
        ],
        'roles': [
          'Clinical Psychologist',
          'Psychotherapist',
          'Behavioral Therapist',
        ],
      },
      'Counseling': {
        'description': 'Professional counseling and mental health support',
        'services': [
          'Individual counseling',
          'Group therapy',
          'Family counseling',
          'Grief counseling',
          'Stress management',
        ],
        'roles': ['Counselor', 'Therapist', 'Social Worker'],
      },
      'Occupational Therapy': {
        'description': 'Helps patients develop daily living and work skills',
        'services': [
          'Skills assessment',
          'Vocational rehabilitation',
          'Daily living training',
          'Cognitive therapy',
          'Environmental adaptation',
        ],
        'roles': ['Occupational Therapist', 'Rehabilitation Counselor'],
      },
      'Social Work': {
        'description': 'Social support and resource coordination for patients',
        'services': [
          'Case management',
          'Resource connection',
          'Family support',
          'Discharge planning',
          'Community liaison',
        ],
        'roles': ['Social Worker', 'Case Manager', 'Community Health Officer'],
      },
      'Substance Abuse Treatment': {
        'description': 'Treatment and recovery programs for addiction',
        'services': [
          'Addiction assessment',
          'Detoxification support',
          'Recovery programs',
          'Relapse prevention',
          'Support group facilitation',
        ],
        'roles': [
          'Addiction Counselor',
          'Substance Abuse Specialist',
          'Recovery Coach',
        ],
      },
      'Crisis Intervention': {
        'description': '24/7 emergency mental health services',
        'services': [
          'Crisis assessment',
          'Emergency psychiatric care',
          'Suicide prevention',
          'Crisis stabilization',
          'Safety planning',
        ],
        'roles': [
          'Crisis Counselor',
          'Emergency Psychiatric Nurse',
          'Crisis Specialist',
        ],
      },

      // Pharmacy Departments
      'Dispensary': {
        'description': 'Medication preparation and distribution services',
        'services': [
          'Prescription filling',
          'Medication dispensing',
          'Patient counseling',
          'Dosage verification',
          'Drug interaction checks',
        ],
        'roles': ['Pharmacist', 'Pharmacy Technician', 'Dispensing Assistant'],
      },
      'Clinical Pharmacy': {
        'description': 'Patient-focused pharmaceutical care and consultations',
        'services': [
          'Medication therapy management',
          'Clinical consultations',
          'Drug utilization review',
          'Pharmacokinetic monitoring',
          'Patient education',
        ],
        'roles': ['Clinical Pharmacist', 'Pharmaceutical Specialist'],
      },
      'Drug Information': {
        'description': 'Pharmaceutical information and education services',
        'services': [
          'Drug information queries',
          'Literature research',
          'Staff education',
          'Drug updates',
          'Evidence-based recommendations',
        ],
        'roles': ['Drug Information Pharmacist', 'Pharmaceutical Consultant'],
      },
      'Inventory Management': {
        'description': 'Medication stock control and procurement',
        'services': [
          'Stock management',
          'Drug procurement',
          'Expiry monitoring',
          'Storage optimization',
          'Supply chain coordination',
        ],
        'roles': [
          'Inventory Manager',
          'Procurement Officer',
          'Stock Controller',
        ],
      },

      // Laboratory Departments
      'Clinical Chemistry': {
        'description': 'Chemical analysis of body fluids for disease diagnosis',
        'services': [
          'Blood chemistry analysis',
          'Enzyme testing',
          'Hormone assays',
          'Metabolite measurement',
          'Toxicology screening',
        ],
        'roles': ['Clinical Chemist', 'Lab Technician', 'Chemical Analyst'],
      },
      'Hematology': {
        'description': 'Blood cell analysis and blood disorders diagnosis',
        'services': [
          'Complete blood count',
          'Blood typing',
          'Coagulation testing',
          'Blood smear examination',
          'Hemoglobin analysis',
        ],
        'roles': ['Hematologist', 'Lab Scientist', 'Phlebotomist'],
      },
      'Microbiology': {
        'description':
            'Detection and identification of disease-causing microorganisms',
        'services': [
          'Bacterial culture',
          'Antibiotic sensitivity testing',
          'Viral testing',
          'Fungal identification',
          'Parasitology',
        ],
        'roles': [
          'Microbiologist',
          'Lab Technician',
          'Infection Control Specialist',
        ],
      },
      'Histopathology': {
        'description': 'Microscopic examination of tissue samples',
        'services': [
          'Tissue processing',
          'Microscopic examination',
          'Cancer diagnosis',
          'Biopsy analysis',
          'Cytology',
        ],
        'roles': ['Pathologist', 'Histotechnologist', 'Cytotechnologist'],
      },
      'Immunology': {
        'description': 'Testing for immune system function and diseases',
        'services': [
          'Antibody testing',
          'Allergy testing',
          'Autoimmune screening',
          'Immune function assessment',
          'Transplant compatibility',
        ],
        'roles': ['Immunologist', 'Lab Scientist', 'Serologist'],
      },
      'Molecular Biology': {
        'description': 'DNA/RNA testing and genetic analysis',
        'services': [
          'PCR testing',
          'Genetic screening',
          'DNA sequencing',
          'Molecular diagnostics',
          'Infectious disease detection',
        ],
        'roles': ['Molecular Biologist', 'Genetic Analyst', 'Lab Technician'],
      },
      'Blood Bank': {
        'description': 'Blood collection, testing, storage, and distribution',
        'services': [
          'Blood donation',
          'Blood typing and screening',
          'Blood component preparation',
          'Storage management',
          'Transfusion services',
        ],
        'roles': [
          'Blood Bank Officer',
          'Transfusion Specialist',
          'Phlebotomist',
        ],
      },
      'Sample Collection': {
        'description': 'Proper collection and handling of laboratory specimens',
        'services': [
          'Blood collection',
          'Specimen receiving',
          'Sample labeling',
          'Transport coordination',
          'Quality assurance',
        ],
        'roles': ['Phlebotomist', 'Sample Collection Officer', 'Lab Assistant'],
      },

      // Default/General Services
      'General Services': {
        'description': 'Comprehensive general healthcare services',
        'services': [
          'General consultations',
          'Basic treatments',
          'Health screenings',
          'Referrals',
          'Follow-up care',
        ],
        'roles': ['Doctor', 'Nurse', 'Medical Assistant'],
      },
      'Clinical Services': {
        'description': 'Direct patient care and clinical procedures',
        'services': [
          'Medical examinations',
          'Treatment procedures',
          'Patient monitoring',
          'Clinical assessments',
          'Care coordination',
        ],
        'roles': ['Doctor', 'Nurse', 'Clinical Officer', 'Medical Assistant'],
      },
      'Support Services': {
        'description': 'Non-clinical support for facility operations',
        'services': [
          'Patient support',
          'Facility maintenance',
          'Administrative support',
          'Resource management',
          'Logistics coordination',
        ],
        'roles': [
          'Support Staff',
          'Maintenance Officer',
          'Logistics Coordinator',
        ],
      },
    };
  }

  List<Map<String, dynamic>> _getDepartments() {
    if (_facilityType == null) return [];

    final facilityTypeLower = _facilityType!.toLowerCase().trim();

    // Hospital departments
    if (facilityTypeLower == 'hospital') {
      return [
        {
          'name': 'Emergency Department',
          'icon': Icons.emergency,
          'color': Colors.red,
        },
        {
          'name': 'Out-Patient Department (OPD)',
          'icon': Icons.medical_services,
          'color': Colors.blue,
        },
        {
          'name': 'Inpatient Department (IPD)',
          'icon': Icons.local_hotel,
          'color': Colors.teal,
        },
        {
          'name': 'Intensive Care Unit (ICU)',
          'icon': Icons.health_and_safety,
          'color': Colors.purple,
        },
        {
          'name': 'Surgery Department',
          'icon': Icons.healing,
          'color': Colors.orange,
        },
        {'name': 'Pediatrics', 'icon': Icons.child_care, 'color': Colors.pink},
        {
          'name': 'Obstetrics & Gynecology',
          'icon': Icons.pregnant_woman,
          'color': Colors.deepPurple,
        },
        {
          'name': 'Orthopedics',
          'icon': Icons.accessible,
          'color': Colors.indigo,
        },
        {
          'name': 'Cardiology',
          'icon': Icons.favorite,
          'color': Colors.red[700]!,
        },
        {
          'name': 'Neurology',
          'icon': Icons.psychology,
          'color': Colors.deepOrange,
        },
        {'name': 'Radiology', 'icon': Icons.camera_alt, 'color': Colors.cyan},
        {'name': 'Laboratory', 'icon': Icons.biotech, 'color': Colors.green},
        {
          'name': 'Pharmacy',
          'icon': Icons.medication,
          'color': Colors.lightGreen,
        },
        {
          'name': 'Public Health',
          'icon': Icons.health_and_safety,
          'color': Colors.green[700]!,
        },
        {
          'name': 'Specialist Department',
          'icon': Icons.medical_services,
          'color': Colors.deepPurple,
        },
        {
          'name': 'Physiotherapy',
          'icon': Icons.accessibility_new,
          'color': Colors.amber,
        },
        {
          'name': 'Nutrition & Dietetics',
          'icon': Icons.restaurant,
          'color': Colors.lime,
        },
        {
          'name': 'Medical Records',
          'icon': Icons.folder_shared,
          'color': Colors.blueGrey,
        },
        {
          'name': 'Dental Department',
          'icon': Icons.medication_liquid,
          'color': Colors.lightBlue,
        },
        {
          'name': 'Ophthalmology Department',
          'icon': Icons.remove_red_eye,
          'color': Colors.indigo,
        },
        {'name': 'ENT Department', 'icon': Icons.hearing, 'color': Colors.teal},
        {
          'name': 'Nursing',
          'icon': Icons.local_hospital,
          'color': Colors.pink[300]!,
        },
        {
          'name': 'Housekeeping',
          'icon': Icons.cleaning_services,
          'color': Colors.brown,
        },
        {'name': 'Security', 'icon': Icons.security, 'color': Colors.grey},
      ];
    }
    // Clinic/PHC departments
    else if (facilityTypeLower == 'clinic' ||
        facilityTypeLower == 'clinic/phc') {
      return [
        {
          'name': 'Out-Patient Department (OPD)',
          'icon': Icons.medical_services,
          'color': Colors.blue,
        },
        {'name': 'Pharmacy', 'icon': Icons.medication, 'color': Colors.green},
        {'name': 'Laboratory', 'icon': Icons.biotech, 'color': Colors.purple},
        {'name': 'Nursing', 'icon': Icons.local_hospital, 'color': Colors.pink},
        {
          'name': 'Public Health',
          'icon': Icons.health_and_safety,
          'color': Colors.green[700]!,
        },
        {
          'name': 'Specialist Department',
          'icon': Icons.medical_services,
          'color': Colors.deepPurple,
        },
        {
          'name': 'Medical Records',
          'icon': Icons.folder_shared,
          'color': Colors.blueGrey,
        },
      ];
    }
    // Dental Clinic departments
    else if (facilityTypeLower == 'dental clinic') {
      return [
        {
          'name': 'General Dentistry',
          'icon': Icons.medication_liquid,
          'color': Colors.blue,
        },
        {'name': 'Oral Surgery', 'icon': Icons.healing, 'color': Colors.red},
        {
          'name': 'Orthodontics',
          'icon': Icons.straighten,
          'color': Colors.purple,
        },
        {
          'name': 'Periodontics',
          'icon': Icons.local_hospital,
          'color': Colors.green,
        },
        {
          'name': 'Pediatric Dentistry',
          'icon': Icons.child_care,
          'color': Colors.pink,
        },
      ];
    }
    // Eye Clinic departments
    else if (facilityTypeLower == 'eye clinic') {
      return [
        {
          'name': 'Ophthalmology',
          'icon': Icons.remove_red_eye,
          'color': Colors.blue,
        },
        {'name': 'Optometry', 'icon': Icons.visibility, 'color': Colors.teal},
        {
          'name': 'Contact Lens Service',
          'icon': Icons.lens,
          'color': Colors.purple,
        },
        {
          'name': 'Optical Dispensary',
          'icon': Icons.store,
          'color': Colors.green,
        },
        {'name': 'Surgical Unit', 'icon': Icons.healing, 'color': Colors.red},
      ];
    }
    // Physiotherapy Center departments
    else if (facilityTypeLower == 'physiotherapy center') {
      return [
        {
          'name': 'Orthopedic Physiotherapy',
          'icon': Icons.accessible,
          'color': Colors.blue,
        },
        {
          'name': 'Neurological Physiotherapy',
          'icon': Icons.psychology,
          'color': Colors.purple,
        },
        {
          'name': 'Cardiopulmonary Physiotherapy',
          'icon': Icons.favorite,
          'color': Colors.red,
        },
        {
          'name': 'Sports Physiotherapy',
          'icon': Icons.sports_soccer,
          'color': Colors.green,
        },
        {
          'name': 'Pediatric Physiotherapy',
          'icon': Icons.child_care,
          'color': Colors.pink,
        },
        {
          'name': 'Geriatric Physiotherapy',
          'icon': Icons.elderly,
          'color': Colors.orange,
        },
      ];
    }
    // Mental Health Center departments
    else if (facilityTypeLower == 'mental health center') {
      return [
        {'name': 'Psychiatry', 'icon': Icons.psychology, 'color': Colors.blue},
        {
          'name': 'Clinical Psychology',
          'icon': Icons.person,
          'color': Colors.teal,
        },
        {'name': 'Counseling', 'icon': Icons.chat, 'color': Colors.green},
        {
          'name': 'Occupational Therapy',
          'icon': Icons.work,
          'color': Colors.purple,
        },
        {'name': 'Social Work', 'icon': Icons.people, 'color': Colors.orange},
        {
          'name': 'Substance Abuse Treatment',
          'icon': Icons.healing,
          'color': Colors.red,
        },
        {
          'name': 'Crisis Intervention',
          'icon': Icons.crisis_alert,
          'color': Colors.amber,
        },
      ];
    }
    // Pharmacy departments (standalone pharmacy)
    else if (facilityTypeLower == 'pharmacy') {
      return [
        {'name': 'Dispensary', 'icon': Icons.medication, 'color': Colors.green},
        {
          'name': 'Clinical Pharmacy',
          'icon': Icons.medical_services,
          'color': Colors.blue,
        },
        {
          'name': 'Drug Information',
          'icon': Icons.info,
          'color': Colors.purple,
        },
        {
          'name': 'Inventory Management',
          'icon': Icons.inventory,
          'color': Colors.orange,
        },
      ];
    }
    // Laboratory departments (standalone laboratory)
    else if (facilityTypeLower == 'laboratory') {
      return [
        {
          'name': 'Clinical Chemistry',
          'icon': Icons.science,
          'color': Colors.blue,
        },
        {'name': 'Hematology', 'icon': Icons.bloodtype, 'color': Colors.red},
        {'name': 'Microbiology', 'icon': Icons.biotech, 'color': Colors.green},
        {
          'name': 'Histopathology',
          'icon': Icons.local_hospital,
          'color': Colors.purple,
        },
        {'name': 'Immunology', 'icon': Icons.shield, 'color': Colors.teal},
        {
          'name': 'Molecular Biology',
          'icon': Icons.science,
          'color': Colors.indigo,
        },
        {
          'name': 'Blood Bank',
          'icon': Icons.water_drop,
          'color': Colors.red[900]!,
        },
        {
          'name': 'Sample Collection',
          'icon': Icons.medication_liquid,
          'color': Colors.orange,
        },
      ];
    }
    // Default departments for other types
    else {
      return [
        {
          'name': 'General Services',
          'icon': Icons.medical_services,
          'color': Colors.blue,
        },
        {
          'name': 'Clinical Services',
          'icon': Icons.local_hospital,
          'color': Colors.teal,
        },
        {
          'name': 'Support Services',
          'icon': Icons.support,
          'color': Colors.green,
        },
      ];
    }
  }

  Future<int> _getStaffCountForDepartment(String departmentName) async {
    if (_facilityName == null) return 0;

    try {
      final collection =
          '${_facilityName!.toLowerCase().replaceAll(' ', '_')}_users';
      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where('department', isEqualTo: departmentName)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  void _showDepartmentDetails(String departmentName, int staffCount) {
    final departmentDetails = _getDepartmentDetails();
    final details =
        departmentDetails[departmentName] ??
        {
          'description': 'Department information not available',
          'services': <String>[],
          'roles': <String>[],
        };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.apartment, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(departmentName, style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Staff Count Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Staff Members: $staffCount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Description Section
              Text(
                'Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                details['description'] as String,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),

              // Services Section
              if ((details['services'] as List).isNotEmpty) ...[
                Text(
                  'Key Services',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                ...(details['services'] as List).map(
                  (service) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            service.toString(),
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Staff Roles Section
              if ((details['roles'] as List).isNotEmpty) ...[
                Text(
                  'Staff Roles',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (details['roles'] as List)
                      .map(
                        (role) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Text(
                            role.toString(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.purple.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Departments'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _facilityType == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to load facility information',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.indigo.shade200),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Facility Type: $_facilityType',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Departments in your facility',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _getDepartments().length,
                    itemBuilder: (context, index) {
                      final department = _getDepartments()[index];
                      final departmentName = department['name'] as String;

                      return FutureBuilder<int>(
                        future: _getStaffCountForDepartment(departmentName),
                        builder: (context, snapshot) {
                          final staffCount = snapshot.data ?? 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: (department['color'] as Color)
                                    .withOpacity(0.2),
                                child: Icon(
                                  department['icon'],
                                  color: department['color'],
                                ),
                              ),
                              title: Text(
                                departmentName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: staffCount > 0
                                  ? Text(
                                      '$staffCount staff member${staffCount != 1 ? 's' : ''}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    )
                                  : null,
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey,
                              ),
                              onTap: () => _showDepartmentDetails(
                                departmentName,
                                staffCount,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
