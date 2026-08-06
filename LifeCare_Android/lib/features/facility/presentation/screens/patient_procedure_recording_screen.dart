import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class PatientProcedureRecordingScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final String preSelectedPatientId;
  final String preSelectedPatientName;
  final String? appointmentId; // Add appointmentId parameter

  const PatientProcedureRecordingScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    required this.preSelectedPatientId,
    required this.preSelectedPatientName,
    this.appointmentId, // Make it optional to avoid breaking other screens
  });

  @override
  State<PatientProcedureRecordingScreen> createState() =>
      _PatientProcedureRecordingScreenState();
}

class _PatientProcedureRecordingScreenState
    extends State<PatientProcedureRecordingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isLoadingProcedures = true;
  List<Map<String, dynamic>> _procedures = [];
  final List<Map<String, dynamic>> _defaultProcedures = [
    {
      'name': 'Wound Dressing',
      'category': 'Wound Care',
      'icon': Icons.healing,
      'color': Colors.red,
      'description': 'Change and apply wound dressings',
      'steps': [
        'Gather supplies (sterile gloves, dressing materials, antiseptic)',
        'Wash hands and wear PPE',
        'Remove old dressing carefully',
        'Clean wound with antiseptic solution',
        'Apply new sterile dressing',
        'Secure dressing properly',
        'Dispose of waste and document',
      ],
    },
    {
      'name': 'Catheterization',
      'category': 'Invasive Procedures',
      'icon': Icons.water_drop,
      'color': Colors.blue,
      'description': 'Urinary or IV catheter insertion',
      'steps': [
        'Explain procedure to patient',
        'Gather sterile catheter kit',
        'Position patient appropriately',
        'Maintain sterile technique',
        'Insert catheter gently',
        'Secure catheter and attach drainage bag',
        'Document procedure and output',
      ],
    },
    {
      'name': 'Vital Signs Monitoring',
      'category': 'Assessment',
      'icon': Icons.monitor_heart,
      'color': Colors.pink,
      'description': 'Monitor and record vital signs',
      'steps': [
        'Prepare equipment (BP cuff, thermometer, pulse oximeter)',
        'Measure blood pressure',
        'Check temperature',
        'Count pulse rate',
        'Measure respiratory rate',
        'Check oxygen saturation',
        'Document all readings',
      ],
    },
    {
      'name': 'Injections (IM/IV/SC)',
      'category': 'Medication Administration',
      'icon': Icons.medication_liquid,
      'color': Colors.green,
      'description': 'Administer injections',
      'steps': [
        'Verify medication order',
        'Check patient identity',
        'Prepare medication using aseptic technique',
        'Select appropriate injection site',
        'Clean site with alcohol swab',
        'Administer injection using correct technique',
        'Dispose of sharps safely',
        'Document administration',
      ],
      'requiresInput': false,
    },
    {
      'name': 'Oral Medication Administration',
      'category': 'Medication Administration',
      'icon': Icons.medication,
      'color': Colors.green,
      'description': 'Administer oral medications',
      'steps': [
        'Verify medication order (right patient, drug, dose, route, time)',
        'Check patient identity using two identifiers',
        'Assess patient\'s ability to swallow',
        'Explain medication purpose to patient',
        'Prepare medication at bedside if possible',
        'Observe patient taking medication',
        'Provide water or appropriate liquid',
        'Document administration immediately',
      ],
      'requiresInput': false,
    },
    {
      'name': 'Blood Transfusion',
      'category': 'Transfusion Therapy',
      'icon': Icons.bloodtype,
      'color': Colors.red.shade700,
      'description': 'Administer blood or blood products',
      'steps': [
        'Verify blood product order and consent',
        'Check patient identity with two nurses',
        'Verify blood type compatibility',
        'Check blood product for expiry and integrity',
        'Take baseline vital signs',
        'Prime blood administration set',
        'Start transfusion slowly (first 15 minutes)',
        'Monitor vital signs every 15 minutes initially',
        'Complete transfusion within 4 hours',
        'Document start time, finish time, and total volume',
      ],
      'requiresInput': true,
      'inputFields': [
        'timeStarted',
        'quantityMl',
        'durationHours',
        'dropsPerMinute',
        'estimatedFinishTime',
      ],
    },
    {
      'name': 'IV Fluid Therapy',
      'category': 'Fluid Management',
      'icon': Icons.water_damage,
      'color': Colors.blue.shade600,
      'description': 'Administer intravenous fluids',
      'steps': [
        'Verify IV fluid order',
        'Check patient identity',
        'Inspect IV fluid for clarity and expiry',
        'Prepare IV administration set',
        'Calculate drip rate based on ordered volume and time',
        'Prime IV tubing to remove air',
        'Connect to IV access or establish new access',
        'Set infusion rate on IV pump or regulate manually',
        'Monitor insertion site and patient response',
        'Document start time, type of fluid, rate, and volume',
      ],
      'requiresInput': true,
      'inputFields': [
        'fluidName',
        'timeStarted',
        'quantityMl',
        'durationHours',
        'dropsPerMinute',
        'estimatedFinishTime',
      ],
    },
    {
      'name': 'Fluid Output Monitoring',
      'category': 'Fluid Management',
      'icon': Icons.analytics_outlined,
      'color': Colors.amber.shade700,
      'description': 'Monitor and record all fluid outputs',
      'steps': [
        'Identify all sources of fluid output',
        'Empty urinary catheter bag and measure volume',
        'Record urine characteristics (color, clarity)',
        'Estimate vomitus volume if applicable',
        'Estimate diarrhea output if applicable',
        'Assess and estimate perspiration/sweats (mild/moderate/profuse)',
        'Record wound drainage if applicable',
        'Total all outputs for the period',
        'Document time, source, and volume of each output',
      ],
      'requiresInput': true,
      'inputFields': [
        'urineOutput',
        'vomitus',
        'diarrhea',
        'sweats',
        'woundDrainage',
      ],
    },
    {
      'name': 'Patient Feeding',
      'category': 'Nutrition & Hydration',
      'icon': Icons.restaurant,
      'color': Colors.orange.shade600,
      'description': 'Assist with patient feeding and fluid intake',
      'steps': [
        'Verify diet order and any restrictions',
        'Assess patient\'s ability to swallow',
        'Position patient upright (60-90 degrees)',
        'Check food temperature',
        'Encourage patient to self-feed if able',
        'Assist with feeding at patient\'s pace',
        'Record type and amount of food consumed',
        'Record oral fluid intake in ml',
        'Document patient\'s tolerance and any issues',
        'Keep patient upright 30 minutes post-feeding',
      ],
      'requiresInput': true,
      'inputFields': ['fluidVolumeMl', 'foodPercentageConsumed'],
    },
    {
      'name': 'ECG (Electrocardiogram)',
      'category': 'Cardiac Monitoring',
      'icon': Icons.monitor_heart_outlined,
      'color': Colors.purple,
      'description': 'Perform 12-lead electrocardiogram',
      'steps': [
        'Verify ECG order',
        'Explain procedure to patient',
        'Position patient supine and relaxed',
        'Expose chest and clean electrode sites',
        'Apply electrodes in correct positions (limb and chest leads)',
        'Ensure proper skin contact',
        'Instruct patient to remain still and breathe normally',
        'Record ECG tracing',
        'Label ECG with patient details and time',
        'Document procedure and alert physician of critical findings',
      ],
      'requiresInput': false,
    },
    {
      'name': 'Echocardiogram Preparation',
      'category': 'Cardiac Monitoring',
      'icon': Icons.favorite_border,
      'color': Colors.purple.shade700,
      'description': 'Prepare patient for echocardiogram',
      'steps': [
        'Verify echocardiogram order',
        'Explain procedure to patient',
        'Ensure patient has fasted if ordered (TEE)',
        'Position patient in left lateral decubitus position',
        'Expose chest area',
        'Assist sonographer during procedure',
        'Monitor patient comfort and vital signs',
        'Document procedure completion',
        'Provide post-procedure instructions',
      ],
      'requiresInput': false,
    },
    {
      'name': 'Specimen Collection',
      'category': 'Laboratory',
      'icon': Icons.biotech,
      'color': Colors.orange,
      'description': 'Collect blood, urine, or other specimens',
      'steps': [
        'Verify lab order and patient identity',
        'Gather collection supplies',
        'Explain procedure to patient',
        'Collect specimen using proper technique',
        'Label specimen correctly',
        'Complete lab requisition form',
        'Transport to lab promptly',
      ],
    },
    {
      'name': 'Oxygen Therapy',
      'category': 'Respiratory Care',
      'icon': Icons.air,
      'color': Colors.cyan,
      'description': 'Administer oxygen therapy',
      'steps': [
        'Check oxygen order and flow rate',
        'Assess patient\'s respiratory status',
        'Set up oxygen delivery system',
        'Apply nasal cannula or mask',
        'Ensure proper fit and comfort',
        'Monitor oxygen saturation',
        'Document oxygen administration',
      ],
    },
    {
      'name': 'NG Tube Insertion',
      'category': 'Invasive Procedures',
      'icon': Icons.cable,
      'color': Colors.deepOrange,
      'description': 'Nasogastric tube insertion and care',
      'steps': [
        'Explain procedure and obtain consent',
        'Position patient in high Fowler\'s position',
        'Measure tube length',
        'Lubricate tube tip',
        'Insert tube through nostril',
        'Verify placement',
        'Secure tube and document',
      ],
    },
    {
      'name': 'Suction Procedures',
      'category': 'Respiratory Care',
      'icon': Icons.air_outlined,
      'color': Colors.teal,
      'description': 'Oral, nasal, or tracheal suctioning',
      'steps': [
        'Assess need for suctioning',
        'Gather sterile suction equipment',
        'Explain to patient',
        'Maintain sterile technique',
        'Perform suctioning',
        'Monitor patient response',
        'Document procedure',
      ],
    },
    {
      'name': 'Patient Positioning',
      'category': 'Patient Care',
      'icon': Icons.bed,
      'color': Colors.brown,
      'description': 'Reposition patient to prevent pressure ulcers',
      'steps': [
        'Assess patient\'s current position',
        'Explain procedure to patient',
        'Get assistance if needed',
        'Use proper body mechanics',
        'Position patient safely',
        'Ensure comfort and alignment',
        'Document position and time',
      ],
    },
    {
      'name': 'Wound Care Assessment',
      'category': 'Wound Care',
      'icon': Icons.fact_check,
      'color': Colors.deepPurple,
      'description': 'Assess and document wound status',
      'steps': [
        'Expose wound area',
        'Assess wound size and depth',
        'Note wound appearance and drainage',
        'Check for signs of infection',
        'Photograph if needed',
        'Document findings',
        'Report concerns to physician',
      ],
    },
    {
      'name': 'IV Line Care',
      'category': 'Invasive Procedures',
      'icon': Icons.water,
      'color': Colors.indigo,
      'description': 'Maintain and monitor IV access',
      'steps': [
        'Assess IV site for complications',
        'Check IV flow rate',
        'Change dressing per protocol',
        'Flush line as ordered',
        'Monitor for infiltration/phlebitis',
        'Document site assessment',
        'Change IV per facility policy',
      ],
    },
    {
      'name': 'Blood Glucose Monitoring',
      'category': 'Assessment',
      'icon': Icons.bloodtype,
      'color': Colors.red.shade700,
      'description': 'Check blood sugar levels',
      'steps': [
        'Gather glucometer and supplies',
        'Verify patient identity',
        'Clean fingertip with alcohol',
        'Obtain blood sample',
        'Apply to test strip',
        'Record result',
        'Report abnormal values',
      ],
    },
    // Minor Surgical Procedures
    {
      'name': 'Suturing (Simple Laceration)',
      'category': 'Minor Surgical Procedures',
      'icon': Icons.healing_outlined,
      'color': Colors.blueGrey,
      'description': 'Close simple wounds with sutures',
      'steps': [
        'Assess wound and obtain consent',
        'Prepare sterile field and instruments',
        'Administer local anesthesia',
        'Clean and irrigate wound',
        'Apply sutures using proper technique',
        'Dress wound appropriately',
        'Provide wound care instructions',
      ],
    },
    {
      'name': 'Incision & Drainage (I&D)',
      'category': 'Minor Surgical Procedures',
      'icon': Icons.cut,
      'color': Colors.amber.shade700,
      'description': 'Drain abscess or fluid collection',
      'steps': [
        'Verify site and obtain consent',
        'Prepare sterile field',
        'Administer local anesthesia',
        'Make incision over abscess',
        'Drain purulent material',
        'Irrigate cavity',
        'Pack wound and dress',
        'Schedule follow-up',
      ],
    },
    {
      'name': 'Nail Removal (Partial/Complete)',
      'category': 'Minor Surgical Procedures',
      'icon': Icons.content_cut,
      'color': Colors.grey.shade700,
      'description': 'Remove ingrown or infected toenail',
      'steps': [
        'Assess nail and obtain consent',
        'Administer digital block',
        'Prepare sterile field',
        'Apply tourniquet if needed',
        'Remove affected nail portion',
        'Apply phenol if indicated',
        'Dress and provide care instructions',
      ],
    },
    {
      'name': 'Foreign Body Removal',
      'category': 'Minor Surgical Procedures',
      'icon': Icons.remove_circle_outline,
      'color': Colors.orange.shade700,
      'description': 'Remove superficial foreign bodies',
      'steps': [
        'Locate foreign body (X-ray if needed)',
        'Obtain consent',
        'Administer local anesthesia',
        'Prepare sterile field',
        'Make small incision if needed',
        'Extract foreign body carefully',
        'Close wound and dress',
        'Update tetanus if required',
      ],
    },
    {
      'name': 'Lipoma Excision',
      'category': 'Minor Surgical Procedures',
      'icon': Icons.circle_outlined,
      'color': Colors.purple.shade300,
      'description': 'Remove benign fatty tumor',
      'steps': [
        'Mark surgical site',
        'Obtain informed consent',
        'Administer local anesthesia',
        'Make elliptical incision',
        'Dissect and remove lipoma',
        'Achieve hemostasis',
        'Close in layers',
        'Send specimen for histology',
      ],
    },
    {
      'name': 'Sebaceous Cyst Excision',
      'category': 'Minor Surgical Procedures',
      'icon': Icons.bubble_chart,
      'color': Colors.teal.shade400,
      'description': 'Remove skin cyst completely',
      'steps': [
        'Assess cyst and obtain consent',
        'Mark incision line',
        'Inject local anesthesia',
        'Make elliptical incision',
        'Dissect cyst intact if possible',
        'Remove cyst wall completely',
        'Close skin and dress',
        'Provide aftercare instructions',
      ],
    },
    {
      'name': 'Skin Biopsy',
      'category': 'Minor Surgical Procedures',
      'icon': Icons.science,
      'color': Colors.pink.shade300,
      'description': 'Obtain skin sample for diagnosis',
      'steps': [
        'Identify lesion and obtain consent',
        'Choose biopsy technique (punch/excisional)',
        'Administer local anesthesia',
        'Perform biopsy',
        'Achieve hemostasis',
        'Close if needed or dress',
        'Place specimen in formalin',
        'Complete pathology request',
      ],
    },
    {
      'name': 'Wart Removal (Electrocautery)',
      'category': 'Minor Surgical Procedures',
      'icon': Icons.flash_on,
      'color': Colors.yellow.shade700,
      'description': 'Remove warts using cautery',
      'steps': [
        'Identify wart(s) and obtain consent',
        'Clean area thoroughly',
        'Administer local anesthesia',
        'Use electrocautery to destroy wart',
        'Scrape away dead tissue',
        'Apply antiseptic',
        'Dress wound',
        'Advise on healing and follow-up',
      ],
    },
    {
      'name': 'Circumcision (Adult)',
      'category': 'Minor Surgical Procedures',
      'icon': Icons.medical_services_outlined,
      'color': Colors.blue.shade600,
      'description': 'Surgical removal of foreskin',
      'steps': [
        'Obtain informed consent',
        'Prepare patient and surgical site',
        'Administer penile block or general anesthesia',
        'Apply circumcision clamp',
        'Remove foreskin',
        'Achieve hemostasis',
        'Close with absorbable sutures',
        'Apply dressing',
        'Provide postoperative care instructions',
      ],
    },
    {
      'name': 'Ear Syringing',
      'category': 'Minor Surgical Procedures',
      'icon': Icons.hearing,
      'color': Colors.lightBlue.shade400,
      'description': 'Remove impacted earwax',
      'steps': [
        'Assess ear with otoscope',
        'Explain procedure to patient',
        'Prepare warm water and syringe',
        'Position patient appropriately',
        'Gently irrigate ear canal',
        'Check for wax removal',
        'Dry ear canal',
        'Reassess with otoscope',
      ],
    },
    // Major Surgical Procedures
    {
      'name': 'Appendectomy',
      'category': 'Major Surgical Procedures',
      'icon': Icons.local_hospital,
      'color': Colors.red.shade600,
      'description': 'Surgical removal of appendix',
      'steps': [
        'Confirm diagnosis and obtain consent',
        'Prepare patient (NBM, IV access)',
        'Administer general anesthesia',
        'Make incision (open or laparoscopic)',
        'Locate and remove appendix',
        'Close in layers',
        'Monitor in recovery',
        'Provide postoperative care',
      ],
    },
    {
      'name': 'Hernia Repair',
      'category': 'Major Surgical Procedures',
      'icon': Icons.medical_information,
      'color': Colors.deepOrange.shade600,
      'description': 'Repair inguinal, umbilical, or incisional hernia',
      'steps': [
        'Assess hernia and obtain consent',
        'Prepare patient for surgery',
        'Administer anesthesia (general/regional)',
        'Make incision over hernia',
        'Reduce hernia contents',
        'Repair defect (with/without mesh)',
        'Close wound in layers',
        'Postoperative monitoring',
      ],
    },
    {
      'name': 'Cesarean Section (C-Section)',
      'category': 'Major Surgical Procedures',
      'icon': Icons.pregnant_woman,
      'color': Colors.pink.shade600,
      'description': 'Surgical delivery of baby',
      'steps': [
        'Assess indication and obtain consent',
        'Prepare patient (IV, catheter)',
        'Administer anesthesia (spinal/epidural)',
        'Make abdominal and uterine incisions',
        'Deliver baby and placenta',
        'Repair uterus',
        'Close abdomen in layers',
        'Postoperative mother-baby care',
      ],
    },
    {
      'name': 'Laparotomy (Exploratory)',
      'category': 'Major Surgical Procedures',
      'icon': Icons.search,
      'color': Colors.indigo.shade600,
      'description': 'Open abdominal exploration',
      'steps': [
        'Confirm indication and consent',
        'Prepare patient for major surgery',
        'Administer general anesthesia',
        'Make midline or paramedian incision',
        'Systematically explore abdomen',
        'Address pathology found',
        'Close abdomen in layers',
        'ICU/ward monitoring',
      ],
    },
    {
      'name': 'Thyroidectomy',
      'category': 'Major Surgical Procedures',
      'icon': Icons.accessibility_new,
      'color': Colors.purple.shade600,
      'description': 'Surgical removal of thyroid gland',
      'steps': [
        'Confirm diagnosis and obtain consent',
        'Prepare patient (thyroid function tests)',
        'Administer general anesthesia',
        'Make transverse neck incision',
        'Identify and preserve nerves/parathyroids',
        'Remove thyroid (partial/total)',
        'Achieve hemostasis and close',
        'Monitor calcium and voice postop',
      ],
    },
    {
      'name': 'Mastectomy',
      'category': 'Major Surgical Procedures',
      'icon': Icons.favorite_border,
      'color': Colors.pinkAccent.shade700,
      'description': 'Surgical removal of breast tissue',
      'steps': [
        'Confirm pathology and obtain consent',
        'Prepare patient psychologically',
        'Administer general anesthesia',
        'Mark surgical margins',
        'Remove breast tissue (simple/modified radical)',
        'Achieve hemostasis',
        'Insert drain if needed',
        'Close and dress',
        'Postoperative care and counseling',
      ],
    },
    {
      'name': 'Hysterectomy',
      'category': 'Major Surgical Procedures',
      'icon': Icons.female,
      'color': Colors.red.shade700,
      'description': 'Surgical removal of uterus',
      'steps': [
        'Assess indication and obtain consent',
        'Prepare patient (bowel prep if needed)',
        'Administer general anesthesia',
        'Make incision (abdominal/vaginal/laparoscopic)',
        'Clamp and divide blood supply',
        'Remove uterus (with/without cervix)',
        'Close vaginal cuff and abdomen',
        'Postoperative monitoring',
      ],
    },
    {
      'name': 'Bowel Resection',
      'category': 'Major Surgical Procedures',
      'icon': Icons.device_hub,
      'color': Colors.brown.shade600,
      'description': 'Removal of diseased bowel segment',
      'steps': [
        'Confirm indication and obtain consent',
        'Prepare bowel (mechanical prep)',
        'Administer general anesthesia',
        'Open abdomen',
        'Identify diseased segment',
        'Resect and create anastomosis',
        'Check for leaks',
        'Close abdomen',
        'ICU monitoring',
      ],
    },
    {
      'name': 'Craniotomy',
      'category': 'Major Surgical Procedures',
      'icon': Icons.psychology,
      'color': Colors.blueGrey.shade800,
      'description': 'Opening of skull to access brain',
      'steps': [
        'Confirm indication (tumor/bleed/trauma)',
        'Obtain informed consent',
        'Administer general anesthesia',
        'Position and prep patient',
        'Create bone flap',
        'Access and treat brain pathology',
        'Replace or remove bone flap',
        'Close scalp',
        'ICU neuro monitoring',
      ],
    },
    {
      'name': 'Joint Replacement (Hip/Knee)',
      'category': 'Major Surgical Procedures',
      'icon': Icons.accessibility,
      'color': Colors.cyan.shade700,
      'description': 'Replace damaged joint with prosthesis',
      'steps': [
        'Assess joint and obtain consent',
        'Prepare patient (optimize health)',
        'Administer anesthesia (general/spinal)',
        'Make surgical approach to joint',
        'Remove damaged bone and cartilage',
        'Insert prosthetic components',
        'Check stability and range of motion',
        'Close and dress',
        'Early mobilization and physiotherapy',
      ],
    },
  ];

  List<String> get _categories {
    final categories = _procedures
        .map((p) => p['category'] as String)
        .toSet()
        .toList();
    categories.sort();
    return ['All', ...categories];
  }

  List<Map<String, dynamic>> get _filteredProcedures {
    return _procedures.where((procedure) {
      final matchesSearch =
          procedure['name'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          procedure['description'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      final matchesCategory =
          _selectedCategory == 'All' ||
          procedure['category'] == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadProceduresFromServiceManagement();
  }

  Future<void> _loadProceduresFromServiceManagement() async {
    try {
      setState(() => _isLoadingProcedures = true);

      // Load procedures from both default list and service management
      final loadedProcedures = List<Map<String, dynamic>>.from(
        _defaultProcedures,
      );

      // Load custom services from Firestore
      final customServicesDoc = await FirebaseFirestore.instance
          .collection('facility_custom_services')
          .doc(widget.facilityId)
          .get();

      // Get custom services
      if (customServicesDoc.exists) {
        final customServicesData = customServicesDoc.data();
        if (customServicesData != null &&
            customServicesData['services'] != null) {
          final customServices =
              customServicesData['services'] as Map<String, dynamic>;

          // Add custom services to procedures list
          customServices.forEach((category, services) {
            if (services is List) {
              for (var service in services) {
                final serviceMap = Map<String, dynamic>.from(service as Map);

                // Only add if it looks like a procedure (not pharmacy items)
                if (category != 'Pharmacy/Medications') {
                  loadedProcedures.add({
                    'name': serviceMap['name'] ?? 'Unknown Service',
                    'category': category,
                    'icon': Icons.medical_services,
                    'color': Colors.purple,
                    'description': 'Custom ${category.toLowerCase()} service',
                    'steps': [
                      'Prepare patient and explain procedure',
                      'Gather necessary equipment',
                      'Perform service according to protocol',
                      'Document and monitor patient',
                    ],
                    'serviceId': serviceMap['id'],
                    'isCustom': true,
                    'defaultPrice':
                        (serviceMap['defaultPrice'] as num?)?.toDouble() ?? 0.0,
                  });
                }
              }
            }
          });
        }
      }

      setState(() {
        _procedures = loadedProcedures;
        _isLoadingProcedures = false;
      });
    } catch (e) {
      setState(() => _isLoadingProcedures = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading procedures: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Record Procedure', style: TextStyle(fontSize: 18)),
            Text(
              widget.preSelectedPatientName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingProcedures
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading available procedures...',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Patient Info Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.purple.shade50,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.purple.shade700,
                        child: Text(
                          widget.preSelectedPatientName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected Patient',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              widget.preSelectedPatientName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                    ],
                  ),
                ),

                // Search Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value.toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search procedures...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Category Filter
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            final isSelected = _selectedCategory == category;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(category),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() => _selectedCategory = category);
                                },
                                backgroundColor: Colors.white,
                                selectedColor: Colors.purple.shade100,
                                checkmarkColor: Colors.purple.shade700,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Procedures List
                Expanded(
                  child: _filteredProcedures.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No procedures found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredProcedures.length,
                          itemBuilder: (context, index) {
                            final procedure = _filteredProcedures[index];
                            return _buildProcedureCard(procedure);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildProcedureCard(Map<String, dynamic> procedure) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showProcedureDetails(procedure),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (procedure['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  procedure['icon'] as IconData,
                  size: 32,
                  color: procedure['color'] as Color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      procedure['name'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      procedure['description'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        procedure['category'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProcedureDetails(Map<String, dynamic> procedure) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProcedureDetailsBottomSheet(
        procedure: procedure,
        onRecord:
            (List<String> completedSteps, Map<String, dynamic> inputData) {
              Navigator.pop(context);
              _recordProcedure(procedure, completedSteps, inputData);
            },
      ),
    );
  }

  void _recordProcedure(
    Map<String, dynamic> procedure,
    List<String> completedSteps,
    Map<String, dynamic> inputData,
  ) async {
    // First, load procedure price from service management
    double procedurePrice = 0.0;
    String? procedureServiceId;

    try {
      // Check if this is a custom service with predefined serviceId and price
      if (procedure['isCustom'] == true && procedure['serviceId'] != null) {
        procedureServiceId = procedure['serviceId'];
        procedurePrice = (procedure['defaultPrice'] as num?)?.toDouble() ?? 0.0;
      } else {
        // Get procedure pricing from facility_service_prices
        final servicePricesDoc = await FirebaseFirestore.instance
            .collection('facility_service_prices')
            .doc(widget.facilityId)
            .get();

        if (servicePricesDoc.exists) {
          final servicePrices = servicePricesDoc.data() as Map<String, dynamic>;

          // Map procedure names to service IDs (for default procedures)
          final procedureServiceMap = {
            'Wound Dressing': 'wound_dressing',
            'Catheterization': 'catheterization',
            'Vital Signs Monitoring': 'vital_signs_monitoring',
            'Injections (IM/IV/SC)': 'injections',
            'Specimen Collection': 'specimen_collection',
            'Oxygen Therapy': 'oxygen_therapy',
            'NG Tube Insertion': 'ng_tube_insertion',
            'Suction Procedures': 'suction_procedures',
            'Patient Positioning': 'patient_positioning',
            'Wound Care Assessment': 'wound_care_assessment',
            'IV Line Care': 'iv_line_care',
            'Blood Glucose Monitoring': 'blood_glucose_monitoring',
            // Medication Administration
            'Oral Medication Administration': 'oral_medication',
            // Transfusion Therapy
            'Blood Transfusion': 'blood_transfusion',
            // Fluid Management
            'IV Fluid Therapy': 'iv_fluid_therapy',
            'Fluid Output Monitoring': 'fluid_output_monitoring',
            // Nutrition and Hydration
            'Patient Feeding': 'patient_feeding',
            // Cardiac Monitoring
            'ECG': 'ecg',
            'Echocardiogram Preparation': 'echocardiogram',
            // Minor Surgical Procedures
            'Suturing (Simple Laceration)': 'suturing',
            'Incision & Drainage (I&D)': 'incision_drainage',
            'Nail Removal (Partial/Complete)': 'nail_removal',
            'Foreign Body Removal': 'foreign_body_removal',
            'Lipoma Excision': 'lipoma_excision',
            'Sebaceous Cyst Excision': 'sebaceous_cyst_excision',
            'Skin Biopsy': 'skin_biopsy',
            'Wart Removal (Electrocautery)': 'wart_removal',
            'Circumcision (Adult)': 'circumcision',
            'Ear Syringing': 'ear_syringing',
            // Major Surgical Procedures
            'Appendectomy': 'appendectomy',
            'Hernia Repair': 'hernia_repair',
            'Cesarean Section (C-Section)': 'cesarean_section',
            'Laparotomy (Exploratory)': 'laparotomy',
            'Thyroidectomy': 'thyroidectomy',
            'Mastectomy': 'mastectomy',
            'Hysterectomy': 'hysterectomy',
            'Bowel Resection': 'bowel_resection',
            'Craniotomy': 'craniotomy',
            'Joint Replacement (Hip/Knee)': 'joint_replacement',
          };

          procedureServiceId = procedureServiceMap[procedure['name']];
          if (procedureServiceId != null &&
              servicePrices.containsKey(procedureServiceId)) {
            procedurePrice =
                (servicePrices[procedureServiceId] as num?)?.toDouble() ?? 0.0;
          }
        }
      }
    } catch (e) {
      // If price loading fails, set to 0
      procedurePrice = 0.0;
    }

    // Check if this is a time-based procedure
    final isTimeBased = procedure['name'].toString().toLowerCase().contains(
      'oxygen therapy',
    );

    // Show procedure recording form with price info
    final notesController = TextEditingController();
    final responseController = TextEditingController();
    final durationController = TextEditingController(text: '1');
    double finalPrice = procedurePrice;

    final confirmed = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Record ${procedure['name']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient: ${widget.preSelectedPatientName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (procedurePrice > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.attach_money,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isTimeBased
                                    ? 'Rate: ₦${procedurePrice.toStringAsFixed(2)}/hour'
                                    : 'Procedure Fee: ₦${procedurePrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          if (isTimeBased) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: durationController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: 'Duration (hours)',
                                      hintText: 'e.g., 2.5',
                                      border: const OutlineInputBorder(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      suffixIcon: Icon(
                                        Icons.access_time,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      final duration =
                                          double.tryParse(value) ?? 1.0;
                                      setDialogState(() {
                                        finalPrice = procedurePrice * duration;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calculate,
                                    color: Colors.green.shade700,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Total: ₦${finalPrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Procedure Notes',
                      hintText: 'Enter any observations or notes...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: responseController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Patient Response',
                      hintText: 'How did the patient respond?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final duration = isTimeBased
                      ? (double.tryParse(durationController.text) ?? 1.0)
                      : 1.0;
                  Navigator.pop(context, {
                    'confirmed': true,
                    'notes': notesController.text,
                    'response': responseController.text,
                    'duration': duration,
                    'finalPrice': isTimeBased
                        ? procedurePrice * duration
                        : procedurePrice,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save & Charge'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == null || confirmed['confirmed'] != true || !mounted) {
      notesController.dispose();
      responseController.dispose();
      durationController.dispose();
      return;
    }

    // Extract dialog results
    final notes = confirmed['notes'] as String;
    final response = confirmed['response'] as String;
    final duration = confirmed['duration'] as double;
    finalPrice = confirmed['finalPrice'] as double;

    // Save procedure record with billing
    try {
      // Get patient data to determine wallet type
      final patientDoc = await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(widget.preSelectedPatientId)
          .get();

      if (!patientDoc.exists) {
        throw Exception('Patient not found');
      }

      final patientData = patientDoc.data()!;

      // Determine wallet and check balance
      final registrationType = patientData['registrationType'] as String?;
      String? householdId;
      bool useHouseholdWallet = false;
      bool useMainWallet = false;
      double walletBalance = 0.0;
      String? actualWalletUserId;

      if (registrationType == 'household') {
        // Use household wallet
        useHouseholdWallet = true;
        householdId = patientData['householdId'] as String?;
        if (householdId == null || householdId.isEmpty) {
          throw Exception('Patient not assigned to a household');
        }

        final householdDoc = await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(householdId)
            .get();

        walletBalance =
            (householdDoc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      } else {
        // Try main wallet first
        double facilityWalletBalance =
            (patientData['walletBalance'] as num?)?.toDouble() ?? 0.0;

        actualWalletUserId = widget.preSelectedPatientId;
        var mainWalletDoc = await FirebaseFirestore.instance
            .collection('wallets')
            .doc(actualWalletUserId)
            .get();

        double mainWalletBalance = 0.0;
        if (mainWalletDoc.exists) {
          mainWalletBalance =
              (mainWalletDoc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
        }

        // Use wallet with sufficient balance
        if (facilityWalletBalance >= finalPrice) {
          walletBalance = facilityWalletBalance;
          useMainWallet = false;
        } else if (mainWalletBalance >= finalPrice) {
          walletBalance = mainWalletBalance;
          useMainWallet = true;
        } else {
          walletBalance = mainWalletBalance > facilityWalletBalance
              ? mainWalletBalance
              : facilityWalletBalance;
          useMainWallet = mainWalletBalance > facilityWalletBalance;
        }
      }

      // Check sufficient balance only if procedure has a fee
      if (finalPrice > 0 && walletBalance < finalPrice) {
        throw Exception(
          'Insufficient wallet balance. Required: ₦${finalPrice.toStringAsFixed(2)}, Available: ₦${walletBalance.toStringAsFixed(2)}',
        );
      }

      // Save procedure record to nursing_procedures
      final procedureData = {
        'facilityId': widget.facilityId,
        'patientId': widget.preSelectedPatientId,
        'patientName': widget.preSelectedPatientName,
        'procedureName': procedure['name'],
        'procedureCategory': procedure['category'],
        'performedBy': widget.staffName,
        'performedById': widget.staffId,
        'notes': notes,
        'patientResponse': response,
        'procedureFee': finalPrice,
        'paymentStatus': finalPrice > 0 ? 'paid' : 'free',
        'performedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'completedSteps':
            completedSteps, // Quality tracking: completed procedure steps
        'totalSteps': (procedure['steps'] as List).length,
        'allStepsCompleted':
            true, // Always true since we require all steps to record
        // Add fluid-related input data if present
        ...inputData,
      };

      // Calculate total fluid intake and output if this is a fluid-related procedure
      if (inputData.containsKey('quantityMl') ||
          inputData.containsKey('fluidVolumeMl')) {
        double totalIntake = 0;
        if (inputData.containsKey('quantityMl')) {
          totalIntake += inputData['quantityMl'] as double;
        }
        if (inputData.containsKey('fluidVolumeMl')) {
          totalIntake += inputData['fluidVolumeMl'] as double;
        }
        procedureData['fluidIntake'] = totalIntake;
        procedureData['fluidType'] = procedure['category'];
      }

      if (inputData.containsKey('urineOutput') ||
          inputData.containsKey('vomitus') ||
          inputData.containsKey('diarrhea') ||
          inputData.containsKey('woundDrainage')) {
        double totalOutput = 0;
        if (inputData.containsKey('urineOutput')) {
          totalOutput += inputData['urineOutput'] as double;
        }
        if (inputData.containsKey('vomitus')) {
          totalOutput += inputData['vomitus'] as double;
        }
        if (inputData.containsKey('diarrhea')) {
          totalOutput += inputData['diarrhea'] as double;
        }
        if (inputData.containsKey('woundDrainage')) {
          totalOutput += inputData['woundDrainage'] as double;
        }
        procedureData['fluidOutput'] = totalOutput;
      }

      // Add appointmentId if provided (for tracking treatment progress)
      if (widget.appointmentId != null && widget.appointmentId!.isNotEmpty) {
        procedureData['appointmentId'] = widget.appointmentId;
      }

      // Add duration if time-based
      if (isTimeBased) {
        procedureData['duration'] = duration;
        procedureData['hourlyRate'] = procedurePrice;
      }

      final procedureRef = await FirebaseFirestore.instance
          .collection('nursing_procedures')
          .add(procedureData);

      // Process payment if procedure has a fee
      if (finalPrice > 0) {
        // Deduct from patient wallet
        if (useHouseholdWallet && householdId != null) {
          await FirebaseFirestore.instance
              .collection('household_wallets')
              .doc(householdId)
              .update({'balance': FieldValue.increment(-finalPrice)});

          final transactionData = {
            'type': 'debit',
            'amount': finalPrice,
            'description': isTimeBased
                ? '${procedure['name']} (${duration}hrs) for ${widget.preSelectedPatientName}'
                : '${procedure['name']} for ${widget.preSelectedPatientName}',
            'patientId': widget.preSelectedPatientId,
            'patientName': widget.preSelectedPatientName,
            'procedureId': procedureRef.id,
            'timestamp': FieldValue.serverTimestamp(),
          };
          if (isTimeBased) transactionData['duration'] = duration;

          await FirebaseFirestore.instance
              .collection('household_wallets')
              .doc(householdId)
              .collection('transactions')
              .add(transactionData);
        } else if (useMainWallet) {
          await FirebaseFirestore.instance
              .collection('wallets')
              .doc(actualWalletUserId)
              .update({
                'balance': FieldValue.increment(-finalPrice),
                'updatedAt': FieldValue.serverTimestamp(),
              });

          final mainWalletTransactionData = {
            'type': 'debit',
            'amount': finalPrice,
            'description': isTimeBased
                ? '${procedure['name']} (${duration}hrs) at ${widget.facilityName}'
                : '${procedure['name']} at ${widget.facilityName}',
            'facilityId': widget.facilityId,
            'procedureId': procedureRef.id,
            'timestamp': FieldValue.serverTimestamp(),
            'balanceBefore': walletBalance,
            'balanceAfter': walletBalance - finalPrice,
            'status': 'completed',
          };
          if (isTimeBased) mainWalletTransactionData['duration'] = duration;

          await FirebaseFirestore.instance
              .collection('wallets')
              .doc(actualWalletUserId)
              .collection('transactions')
              .add(mainWalletTransactionData);
        } else {
          await FirebaseFirestore.instance
              .collection('facility_patients')
              .doc(widget.preSelectedPatientId)
              .update({'walletBalance': FieldValue.increment(-finalPrice)});

          final facilityPatientTransactionData = {
            'type': 'debit',
            'amount': finalPrice,
            'description': isTimeBased
                ? '${procedure['name']} (${duration}hrs)'
                : '${procedure['name']}',
            'procedureId': procedureRef.id,
            'timestamp': FieldValue.serverTimestamp(),
          };
          if (isTimeBased) {
            facilityPatientTransactionData['duration'] = duration;
          }

          await FirebaseFirestore.instance
              .collection('facility_patients')
              .doc(widget.preSelectedPatientId)
              .collection('transactions')
              .add(facilityPatientTransactionData);
        }

        // Credit facility wallet
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(widget.facilityId)
            .update({
              'balance': FieldValue.increment(finalPrice),
              'updatedAt': FieldValue.serverTimestamp(),
            });

        final facilityTransactionData = {
          'type': 'credit',
          'amount': finalPrice,
          'description': isTimeBased
              ? '${procedure['name']} (${duration}hrs) for ${widget.preSelectedPatientName}'
              : '${procedure['name']} for ${widget.preSelectedPatientName}',
          'patientId': widget.preSelectedPatientId,
          'patientName': widget.preSelectedPatientName,
          'staffId': widget.staffId,
          'staffName': widget.staffName,
          'procedureId': procedureRef.id,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
        };
        if (isTimeBased) facilityTransactionData['duration'] = duration;

        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(widget.facilityId)
            .collection('transactions')
            .add(facilityTransactionData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              finalPrice > 0
                  ? isTimeBased
                        ? '${procedure['name']} recorded. ${duration}hrs × ₦${procedurePrice.toStringAsFixed(2)} = ₦${finalPrice.toStringAsFixed(2)} charged.'
                        : '${procedure['name']} recorded. ₦${finalPrice.toStringAsFixed(2)} charged.'
                  : '${procedure['name']} recorded successfully',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context); // Return to patients list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      notesController.dispose();
      responseController.dispose();
      durationController.dispose();
    }
  }
}

// Stateful Bottom Sheet Widget for Procedure Details with Interactive Checkboxes
class _ProcedureDetailsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> procedure;
  final Function(List<String>, Map<String, dynamic>) onRecord;

  const _ProcedureDetailsBottomSheet({
    required this.procedure,
    required this.onRecord,
  });

  @override
  State<_ProcedureDetailsBottomSheet> createState() =>
      _ProcedureDetailsBottomSheetState();
}

class _ProcedureDetailsBottomSheetState
    extends State<_ProcedureDetailsBottomSheet> {
  late List<bool> _checkedSteps;
  late List<bool> _checkedIpcSteps;
  bool _showIpcChecklist = true; // Start expanded since it's mandatory
  bool _showAiAssistant = true;
  bool get _allStepsChecked => _checkedSteps.every((checked) => checked);
  bool get _allIpcStepsChecked => _checkedIpcSteps.every((checked) => checked);
  bool get _allRequiredStepsChecked => _allStepsChecked && _allIpcStepsChecked;
  List<String> _aiRecommendations = [];

  // Controllers for input fields
  final TextEditingController _fluidNameController = TextEditingController();
  final TextEditingController _timeStartedController = TextEditingController();
  final TextEditingController _quantityMlController = TextEditingController();
  final TextEditingController _durationHoursController =
      TextEditingController();
  final TextEditingController _dropsPerMinuteController =
      TextEditingController();
  final TextEditingController _estimatedFinishTimeController =
      TextEditingController();
  final TextEditingController _urineOutputController = TextEditingController();
  final TextEditingController _vomitusController = TextEditingController();
  final TextEditingController _diarrheaController = TextEditingController();
  final TextEditingController _sweatsController = TextEditingController();
  final TextEditingController _woundDrainageController =
      TextEditingController();
  final TextEditingController _fluidVolumeMlController =
      TextEditingController();
  final TextEditingController _foodPercentageController =
      TextEditingController();

  DateTime? _startTime;
  DateTime? _finishTime;

  @override
  void initState() {
    super.initState();
    final steps = widget.procedure['steps'] as List<String>;
    _checkedSteps = List.filled(steps.length, false);
    _checkedIpcSteps = List.filled(_getIpcSteps().length, false);
    _generateAiRecommendations();
  }

  @override
  void dispose() {
    _fluidNameController.dispose();
    _timeStartedController.dispose();
    _quantityMlController.dispose();
    _durationHoursController.dispose();
    _dropsPerMinuteController.dispose();
    _estimatedFinishTimeController.dispose();
    _urineOutputController.dispose();
    _vomitusController.dispose();
    _diarrheaController.dispose();
    _sweatsController.dispose();
    _woundDrainageController.dispose();
    _fluidVolumeMlController.dispose();
    _foodPercentageController.dispose();
    super.dispose();
  }

  List<String> get _completedSteps {
    final steps = widget.procedure['steps'] as List<String>;
    final procedureSteps = steps
        .asMap()
        .entries
        .where((entry) => _checkedSteps[entry.key])
        .map((entry) => entry.value)
        .toList();

    // Add completed IPC steps to the list
    final ipcSteps = _getIpcSteps();
    final completedIpcSteps = ipcSteps
        .asMap()
        .entries
        .where((entry) => _checkedIpcSteps[entry.key])
        .map((entry) => '[IPC] ${entry.value}')
        .toList();

    return [...procedureSteps, ...completedIpcSteps];
  }

  void _calculateDuration() {
    if (_startTime != null &&
        _quantityMlController.text.isNotEmpty &&
        _durationHoursController.text.isNotEmpty) {
      final quantity = double.tryParse(_quantityMlController.text) ?? 0;
      final durationHours = double.tryParse(_durationHoursController.text) ?? 0;

      if (durationHours > 0 && quantity > 0) {
        // Calculate finish time based on duration
        final durationMinutes = (durationHours * 60).round();
        final finishTime = _startTime!.add(Duration(minutes: durationMinutes));
        _finishTime = finishTime;
        _estimatedFinishTimeController.text =
            '${finishTime.hour.toString().padLeft(2, '0')}:${finishTime.minute.toString().padLeft(2, '0')}';

        // Calculate drops per minute
        // Standard IV tubing: 20 drops = 1 ml (macrodrip)
        final totalDrops = quantity * 20; // Total drops needed
        final dropsPerMinute =
            totalDrops / (durationHours * 60); // Drops per minute
        _dropsPerMinuteController.text = dropsPerMinute.toStringAsFixed(0);
      }
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final now = DateTime.now();
      final selectedTime = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );
      setState(() {
        if (isStartTime) {
          _startTime = selectedTime;
          _timeStartedController.text =
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
          _calculateDuration();
        } else {
          _finishTime = selectedTime;
          _estimatedFinishTimeController.text =
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        }
      });
    }
  }

  // Get IPC steps based on procedure category
  List<String> _getIpcSteps() {
    final category = widget.procedure['category'] as String;
    final procedureName = widget.procedure['name'] as String;

    // Base IPC steps for all procedures
    List<String> baseSteps = [
      'Hand hygiene performed',
      'PPE donned appropriately',
    ];

    // Category-specific IPC steps
    if (category.contains('Invasive') ||
        procedureName.contains('Catheterization') ||
        procedureName.contains('Injection') ||
        procedureName.contains('IV') ||
        procedureName.contains('Transfusion')) {
      baseSteps.addAll([
        'Sterile technique maintained',
        'Equipment sterilized/sterile',
      ]);
    }

    if (category.contains('Wound') ||
        procedureName.contains('Wound') ||
        procedureName.contains('Dressing')) {
      baseSteps.add('Wound area cleaned properly');
    }

    if (category.contains('Surgical') || procedureName.contains('Surgical')) {
      baseSteps.addAll(['Surgical site prepared', 'Sterile field maintained']);
    }

    // Universal closing steps
    baseSteps.addAll([
      'PPE removed safely',
      'Waste disposed properly',
      'Hand hygiene post-procedure',
    ]);

    return baseSteps;
  }

  // Generate AI recommendations based on procedure context
  void _generateAiRecommendations() {
    final category = widget.procedure['category'] as String;
    final procedureName = widget.procedure['name'] as String;
    final isCustom = widget.procedure['isCustom'] == true;
    List<String> recommendations = [];

    // Category-specific recommendations
    if (category.contains('Wound') || procedureName.contains('Wound')) {
      recommendations.addAll([
        '💡 Assess wound size, depth, and drainage before starting',
        '💡 Use aseptic technique to prevent infection',
        '💡 Document wound appearance and patient response',
      ]);
    }

    if (category.contains('Invasive') || procedureName.contains('Catheter')) {
      recommendations.addAll([
        '💡 Explain procedure to patient for comfort and cooperation',
        '💡 Position patient for optimal access and comfort',
        '💡 Monitor for signs of discomfort or complications',
      ]);
    }

    if (procedureName.contains('IV') ||
        procedureName.contains('Injection') ||
        procedureName.contains('Medication')) {
      recommendations.addAll([
        '💡 Verify patient identity using two identifiers',
        '💡 Check medication against order (right drug, dose, route, time)',
        '💡 Assess for allergies before administration',
      ]);
    }

    if (procedureName.contains('Vital Signs') ||
        procedureName.contains('Monitoring')) {
      recommendations.addAll([
        '💡 Ensure patient is rested for 5 mins before BP measurement',
        '💡 Use appropriate cuff size for accurate readings',
        '💡 Compare with previous readings for trends',
      ]);
    }

    if (procedureName.contains('Blood') ||
        procedureName.contains('Transfusion')) {
      recommendations.addAll([
        '💡 Verify blood product with two qualified staff',
        '💡 Monitor vital signs every 15 mins during first hour',
        '💡 Watch for transfusion reactions (fever, chills, rash)',
      ]);
    }

    if (procedureName.contains('Oxygen')) {
      recommendations.addAll([
        '💡 Assess respiratory status before starting',
        '💡 Ensure humidification for flows >4L/min',
        '💡 Monitor SpO2 and adjust flow as needed',
      ]);
    }

    if (procedureName.contains('Feeding') ||
        procedureName.contains('Nutrition')) {
      recommendations.addAll([
        '💡 Elevate head of bed 30-45° to prevent aspiration',
        '💡 Check tube placement before feeding',
        '💡 Monitor for signs of intolerance (nausea, bloating)',
      ]);
    }

    if (procedureName.contains('ECG') ||
        procedureName.contains('Cardiac') ||
        procedureName.contains('Echo')) {
      recommendations.addAll([
        '💡 Ensure patient is relaxed and lying still',
        '💡 Clean skin before electrode placement',
        '💡 Check for proper lead placement',
      ]);
    }

    if (procedureName.contains('Fluid') || procedureName.contains('Output')) {
      recommendations.addAll([
        '💡 Document all intake and output accurately',
        '💡 Monitor for fluid overload or dehydration signs',
        '💡 Report significant imbalances to physician',
      ]);
    }

    if (category.contains('Surgical') ||
        procedureName.contains('Surgery') ||
        procedureName.contains('Surgical')) {
      recommendations.addAll([
        '💡 Verify surgical consent is signed',
        '💡 Confirm surgical site marking',
        '💡 Ensure patient NPO status is maintained',
      ]);
    }

    // Universal recommendations for all procedures
    recommendations.addAll([
      '💡 Ensure patient comfort throughout procedure',
      '💡 Communicate clearly with patient during process',
      '💡 Document procedure details thoroughly',
    ]);

    // For custom procedures, add generic best practice
    if (isCustom) {
      recommendations.insert(
        0,
        '💡 Follow facility-specific protocols for this custom procedure',
      );
    }

    setState(() {
      _aiRecommendations = recommendations;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.procedure['color'] as Color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.procedure['icon'] as IconData,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.procedure['name'] as String,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.procedure['category'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // Description
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.procedure['description'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // AI Assistant Card (Collapsible, Non-intrusive)
                  if (_aiRecommendations.isNotEmpty) ...[
                    Card(
                      elevation: 0,
                      color: Colors.blue.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.blue.shade200, width: 1),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showAiAssistant = !_showAiAssistant;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.psychology,
                                      size: 20,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'AI Assistant',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade900,
                                          ),
                                        ),
                                        Text(
                                          'Best practice recommendations',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    _showAiAssistant
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: Colors.blue.shade700,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_showAiAssistant) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _aiRecommendations
                                    .map(
                                      (rec) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                rec,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade800,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Steps Checklist Header with Progress
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Procedure Steps Checklist',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        '${_checkedSteps.where((c) => c).length}/${_checkedSteps.length}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _allStepsChecked
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Interactive Checkboxes for Each Step
                  ...(widget.procedure['steps'] as List<String>)
                      .asMap()
                      .entries
                      .map((entry) {
                        return CheckboxListTile(
                          value: _checkedSteps[entry.key],
                          onChanged: (value) {
                            setState(() {
                              _checkedSteps[entry.key] = value ?? false;
                            });
                          },
                          title: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 14,
                              color: _checkedSteps[entry.key]
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade800,
                              decoration: _checkedSteps[entry.key]
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          secondary: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: (widget.procedure['color'] as Color)
                                  .withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: widget.procedure['color'] as Color,
                                ),
                              ),
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        );
                      }),
                  const SizedBox(height: 24),

                  // IPC Checklist (Collapsible)
                  Card(
                    elevation: 0,
                    color: Colors.green.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.green.shade200, width: 1),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showIpcChecklist = !_showIpcChecklist;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.verified_user,
                                    size: 20,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Infection Prevention & Control',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade900,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            '${_checkedIpcSteps.where((c) => c).length}/${_checkedIpcSteps.length} completed',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '• Required',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (_allIpcStepsChecked)
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade700,
                                    size: 20,
                                  ),
                                const SizedBox(width: 8),
                                Icon(
                                  _showIpcChecklist
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: Colors.green.shade700,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showIpcChecklist) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Column(
                              children: _getIpcSteps().asMap().entries.map((
                                entry,
                              ) {
                                return CheckboxListTile(
                                  value: _checkedIpcSteps[entry.key],
                                  onChanged: (value) {
                                    setState(() {
                                      _checkedIpcSteps[entry.key] =
                                          value ?? false;
                                    });
                                  },
                                  dense: true,
                                  title: Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _checkedIpcSteps[entry.key]
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade800,
                                      decoration: _checkedIpcSteps[entry.key]
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  activeColor: Colors.green.shade700,
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Input Fields for specific procedures
                  if (widget.procedure['requiresInput'] == true) ...[
                    Text(
                      'Procedure Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // IV Fluid Therapy - Fluid Name field
                    if (widget.procedure['inputFields']?.contains(
                          'fluidName',
                        ) ==
                        true) ...[
                      TextField(
                        controller: _fluidNameController,
                        decoration: InputDecoration(
                          labelText: 'Fluid Name',
                          hintText:
                              'e.g., Normal Saline, Dextrose 5%, Ringer\'s Lactate',
                          prefixIcon: const Icon(Icons.local_drink),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Blood Transfusion & IV Fluid Therapy fields
                    if (widget.procedure['inputFields']?.contains(
                          'timeStarted',
                        ) ==
                        true) ...[
                      TextField(
                        controller: _timeStartedController,
                        decoration: InputDecoration(
                          labelText: 'Time Started',
                          hintText: 'Tap to select time',
                          prefixIcon: const Icon(Icons.access_time),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        readOnly: true,
                        onTap: () => _selectTime(context, true),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _quantityMlController,
                        decoration: InputDecoration(
                          labelText: 'Quantity (ml)',
                          hintText: 'Enter volume in milliliters',
                          prefixIcon: const Icon(Icons.water_drop),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _calculateDuration(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // IV Fluid Therapy - Duration field
                    if (widget.procedure['inputFields']?.contains(
                          'durationHours',
                        ) ==
                        true) ...[
                      TextField(
                        controller: _durationHoursController,
                        decoration: InputDecoration(
                          labelText: 'Duration (hours)',
                          hintText: 'e.g., 4, 6, 8',
                          prefixIcon: const Icon(Icons.schedule),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          helperText: 'How long should the infusion run?',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => _calculateDuration(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // IV Fluid Therapy - Auto-calculated Drops per minute field (read-only)
                    if (widget.procedure['inputFields']?.contains(
                          'dropsPerMinute',
                        ) ==
                        true) ...[
                      TextField(
                        controller: _dropsPerMinuteController,
                        decoration: InputDecoration(
                          labelText: 'Drops per Minute',
                          hintText: 'Auto-calculated',
                          prefixIcon: const Icon(Icons.speed),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          helperText:
                              'Auto-calculated (Standard: 20 drops = 1ml)',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        readOnly: true,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Estimated finish time field (auto-calculated)
                    if (widget.procedure['inputFields']?.contains(
                          'estimatedFinishTime',
                        ) ==
                        true) ...[
                      TextField(
                        controller: _estimatedFinishTimeController,
                        decoration: InputDecoration(
                          labelText: 'Estimated Finish Time',
                          hintText: 'Auto-calculated',
                          prefixIcon: const Icon(Icons.timer_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        readOnly: true,
                        onTap: () => _selectTime(context, false),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Fluid Output Monitoring fields
                    if (widget.procedure['inputFields']?.contains(
                          'urineOutput',
                        ) ==
                        true) ...[
                      TextField(
                        controller: _urineOutputController,
                        decoration: InputDecoration(
                          labelText: 'Urine Output (ml)',
                          hintText: 'Volume from catheter bag',
                          prefixIcon: const Icon(Icons.opacity),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _vomitusController,
                        decoration: InputDecoration(
                          labelText: 'Vomitus (ml)',
                          hintText: 'Estimated volume',
                          prefixIcon: const Icon(Icons.invert_colors_off),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _diarrheaController,
                        decoration: InputDecoration(
                          labelText: 'Diarrhea (ml)',
                          hintText: 'Estimated volume',
                          prefixIcon: const Icon(Icons.water_damage),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _sweatsController,
                        decoration: InputDecoration(
                          labelText: 'Perspiration/Sweats',
                          hintText: 'Mild/Moderate/Profuse',
                          prefixIcon: const Icon(Icons.air),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _woundDrainageController,
                        decoration: InputDecoration(
                          labelText: 'Wound Drainage (ml)',
                          hintText: 'If applicable',
                          prefixIcon: const Icon(Icons.healing),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Patient Feeding fields
                    if (widget.procedure['inputFields']?.contains(
                          'fluidVolumeMl',
                        ) ==
                        true) ...[
                      TextField(
                        controller: _fluidVolumeMlController,
                        decoration: InputDecoration(
                          labelText: 'Oral Fluid Intake (ml)',
                          hintText: 'Volume of fluids consumed',
                          prefixIcon: const Icon(Icons.local_drink),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _foodPercentageController,
                        decoration: InputDecoration(
                          labelText: 'Food Consumed (%)',
                          hintText: 'Percentage of meal consumed',
                          prefixIcon: const Icon(Icons.restaurant),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],

                  // Warning if not all steps checked
                  if (!_allStepsChecked)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Complete all steps before recording',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  // IPC Completion Notice - Updated for mandatory requirement
                  if (!_allIpcStepsChecked)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'IPC checklist must be completed before recording',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!_allIpcStepsChecked) const SizedBox(height: 12),
                  // Record Button (disabled until all steps and IPC checked)
                  ElevatedButton.icon(
                    onPressed: _allRequiredStepsChecked
                        ? () {
                            // Gather input data
                            final inputData = <String, dynamic>{};
                            if (_fluidNameController.text.isNotEmpty) {
                              inputData['fluidName'] =
                                  _fluidNameController.text;
                            }
                            if (_timeStartedController.text.isNotEmpty) {
                              inputData['timeStarted'] =
                                  _timeStartedController.text;
                            }
                            if (_quantityMlController.text.isNotEmpty) {
                              inputData['quantityMl'] =
                                  double.tryParse(_quantityMlController.text) ??
                                  0.0;
                            }
                            if (_durationHoursController.text.isNotEmpty) {
                              inputData['durationHours'] =
                                  double.tryParse(
                                    _durationHoursController.text,
                                  ) ??
                                  0.0;
                            }
                            if (_dropsPerMinuteController.text.isNotEmpty) {
                              inputData['dropsPerMinute'] =
                                  double.tryParse(
                                    _dropsPerMinuteController.text,
                                  ) ??
                                  0.0;
                            }
                            if (_estimatedFinishTimeController
                                .text
                                .isNotEmpty) {
                              inputData['estimatedFinishTime'] =
                                  _estimatedFinishTimeController.text;
                            }
                            if (_startTime != null && _finishTime != null) {
                              final duration = _finishTime!
                                  .difference(_startTime!)
                                  .inMinutes;
                              inputData['durationMinutes'] = duration;
                            }
                            if (_urineOutputController.text.isNotEmpty) {
                              inputData['urineOutput'] =
                                  double.tryParse(
                                    _urineOutputController.text,
                                  ) ??
                                  0.0;
                            }
                            if (_vomitusController.text.isNotEmpty) {
                              inputData['vomitus'] =
                                  double.tryParse(_vomitusController.text) ??
                                  0.0;
                            }
                            if (_diarrheaController.text.isNotEmpty) {
                              inputData['diarrhea'] =
                                  double.tryParse(_diarrheaController.text) ??
                                  0.0;
                            }
                            if (_sweatsController.text.isNotEmpty) {
                              inputData['sweats'] = _sweatsController.text;
                            }
                            if (_woundDrainageController.text.isNotEmpty) {
                              inputData['woundDrainage'] =
                                  double.tryParse(
                                    _woundDrainageController.text,
                                  ) ??
                                  0.0;
                            }
                            if (_fluidVolumeMlController.text.isNotEmpty) {
                              inputData['fluidVolumeMl'] =
                                  double.tryParse(
                                    _fluidVolumeMlController.text,
                                  ) ??
                                  0.0;
                            }
                            if (_foodPercentageController.text.isNotEmpty) {
                              inputData['foodPercentageConsumed'] =
                                  double.tryParse(
                                    _foodPercentageController.text,
                                  ) ??
                                  0.0;
                            }

                            widget.onRecord(_completedSteps, inputData);
                          }
                        : null,
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Record This Procedure'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.procedure['color'] as Color,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
