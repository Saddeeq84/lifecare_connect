import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/ai_validation_service.dart';
import '../../../shared/widgets/ai_validation_dialog.dart';

class CHWANCFormScreen extends StatefulWidget {
  final String patientId;
  final Map<String, dynamic> patientData;

  const CHWANCFormScreen({
    super.key,
    required this.patientId,
    required this.patientData,
  });

  @override
  State<CHWANCFormScreen> createState() => _CHWANCFormScreenState();
}

class _CHWANCFormScreenState extends State<CHWANCFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Visit Information
  DateTime _visitDate = DateTime.now();
  final _gestationalAgeController = TextEditingController();
  final _gravityController = TextEditingController();
  final _parityController = TextEditingController();

  // Vital Signs
  final _weightController = TextEditingController();
  final _bloodPressureController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _pulseController = TextEditingController();

  // Physical Examination
  final _fundalHeightController = TextEditingController();
  String? _fetalHeartRate;
  String? _fetalPresentation;
  bool _edemaPresent = false;

  // Risk Assessment
  final List<String> _dangerSigns = [];
  final _complaintsController = TextEditingController();

  // Lab Tests & Results
  bool _bloodTestDone = false;
  String? _bloodType;
  String? _hemoglobinLevel;
  bool _urineDipstickDone = false;
  String? _urineProtein;
  String? _urineGlucose;
  bool _hivTestDone = false;
  String? _hivResult;
  bool _hepatitisBTestDone = false;
  String? _hepatitisBResult;
  bool _syphilisTestDone = false;
  String? _syphilisResult;

  // Interventions
  bool _ironFolicAcidGiven = false;
  bool _malariaIPTpGiven = false;
  final _malariaIPTpDoseController = TextEditingController();
  bool _tetanusToxoidGiven = false;
  final _tetanusToxoidDoseController = TextEditingController();
  bool _mosquitoNetProvided = false;
  bool _dewormed = false;

  // Health Education
  final List<String> _educationTopics = [];
  final _nutritionAdviceController = TextEditingController();
  final _notesController = TextEditingController();

  // Referral
  bool _referralNeeded = false;
  final _referralReasonController = TextEditingController();
  String? _referralFacility;

  // Next Visit
  DateTime? _nextVisitDate;

  final List<String> _availableDangerSigns = [
    'Severe headache',
    'Blurred vision',
    'Severe abdominal pain',
    'Vaginal bleeding',
    'High fever',
    'Convulsions',
    'Swelling of hands/face',
    'Reduced fetal movement',
    'Water breaking',
    'Severe vomiting',
    'Difficulty breathing',
    'Severe weakness/dizziness',
  ];

  final List<String> _educationOptions = [
    'Nutrition during pregnancy',
    'Danger signs in pregnancy',
    'Birth preparedness',
    'Breastfeeding',
    'Family planning',
    'Hygiene practices',
    'Malaria prevention',
    'HIV prevention',
    'Exercise during pregnancy',
    'Medication adherence',
  ];

  @override
  void dispose() {
    _gestationalAgeController.dispose();
    _gravityController.dispose();
    _parityController.dispose();
    _weightController.dispose();
    _bloodPressureController.dispose();
    _temperatureController.dispose();
    _pulseController.dispose();
    _fundalHeightController.dispose();
    _complaintsController.dispose();
    _malariaIPTpDoseController.dispose();
    _tetanusToxoidDoseController.dispose();
    _nutritionAdviceController.dispose();
    _notesController.dispose();
    _referralReasonController.dispose();
    super.dispose();
  }

  Future<void> _saveANCVisit() async {
    if (!_formKey.currentState!.validate()) return;

    // AI Validation: Check vital signs for emergency values (advisory only)
    final bpText = _bloodPressureController.text.trim();
    final tempText = _temperatureController.text.trim();
    final pulseText = _pulseController.text.trim();

    // Parse blood pressure (format: "120/80")
    double? systolic;
    double? diastolic;
    if (bpText.isNotEmpty && bpText.contains('/')) {
      final parts = bpText.split('/');
      if (parts.length == 2) {
        systolic = double.tryParse(parts[0].trim());
        diastolic = double.tryParse(parts[1].trim());
      }
    }

    if (systolic != null || tempText.isNotEmpty || pulseText.isNotEmpty) {
      final vitalsResult = await AIValidationService.validateVitalSigns(
        systolicBP: systolic,
        diastolicBP: diastolic,
        temperature: tempText.isNotEmpty ? double.tryParse(tempText) : null,
        heartRate: pulseText.isNotEmpty ? double.tryParse(pulseText) : null,
      );

      if (vitalsResult.severity == ValidationSeverity.critical) {
        await AIValidationDialog.show(
          context: context,
          result: vitalsResult,
          title: 'AI Vital Signs Advisory',
        );
      }
    }

    setState(() => _isLoading = true);

    try {
      final chwId = FirebaseAuth.instance.currentUser?.uid;
      if (chwId == null) throw Exception('CHW not logged in');

      // Calculate service cost
      final serviceCost = await _getServiceCost('anc');

      // Check patient wallet balance
      final walletDoc = await FirebaseFirestore.instance
          .collection('chw_patient_wallets')
          .doc(widget.patientId)
          .get();

      final walletData = walletDoc.data();
      final balance = walletData?['balance'] ?? 0.0;

      if (balance < serviceCost) {
        throw Exception(
          'Insufficient wallet balance. Required: ₦$serviceCost, Available: ₦$balance',
        );
      }

      // Create ANC record
      final ancRecordRef = FirebaseFirestore.instance
          .collection('chw_patient_records')
          .doc(widget.patientId)
          .collection('anc_visits')
          .doc();

      final ancData = {
        'visitId': ancRecordRef.id,
        'patientId': widget.patientId,
        'chwId': chwId,
        'visitDate': Timestamp.fromDate(_visitDate),
        'gestationalAge': int.tryParse(_gestationalAgeController.text),
        'gravity': int.tryParse(_gravityController.text),
        'parity': int.tryParse(_parityController.text),
        'weight': double.tryParse(_weightController.text),
        'bloodPressure': _bloodPressureController.text.trim(),
        'temperature': double.tryParse(_temperatureController.text),
        'pulse': int.tryParse(_pulseController.text),
        'fundalHeight': double.tryParse(_fundalHeightController.text),
        'fetalHeartRate': _fetalHeartRate,
        'fetalPresentation': _fetalPresentation,
        'edemaPresent': _edemaPresent,
        'dangerSigns': _dangerSigns,
        'complaints': _complaintsController.text.trim(),
        'bloodTestDone': _bloodTestDone,
        'bloodType': _bloodType,
        'hemoglobinLevel': _hemoglobinLevel,
        'urineDipstickDone': _urineDipstickDone,
        'urineProtein': _urineProtein,
        'urineGlucose': _urineGlucose,
        'hivTestDone': _hivTestDone,
        'hivResult': _hivResult,
        'hepatitisBTestDone': _hepatitisBTestDone,
        'hepatitisBResult': _hepatitisBResult,
        'syphilisTestDone': _syphilisTestDone,
        'syphilisResult': _syphilisResult,
        'ironFolicAcidGiven': _ironFolicAcidGiven,
        'malariaIPTpGiven': _malariaIPTpGiven,
        'malariaIPTpDose': _malariaIPTpDoseController.text.trim(),
        'tetanusToxoidGiven': _tetanusToxoidGiven,
        'tetanusToxoidDose': _tetanusToxoidDoseController.text.trim(),
        'mosquitoNetProvided': _mosquitoNetProvided,
        'dewormed': _dewormed,
        'educationTopics': _educationTopics,
        'nutritionAdvice': _nutritionAdviceController.text.trim(),
        'notes': _notesController.text.trim(),
        'referralNeeded': _referralNeeded,
        'referralReason': _referralReasonController.text.trim(),
        'referralFacility': _referralFacility,
        'nextVisitDate': _nextVisitDate != null
            ? Timestamp.fromDate(_nextVisitDate!)
            : null,
        'serviceCost': serviceCost,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await ancRecordRef.set(ancData);

      // Process payment
      await _processServicePayment(serviceCost, chwId, 'ANC Visit');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ANC visit recorded successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<double> _getServiceCost(String serviceType) async {
    final chwId = FirebaseAuth.instance.currentUser?.uid;
    final serviceDoc = await FirebaseFirestore.instance
        .collection('chw_services')
        .doc(chwId)
        .get();

    if (serviceDoc.exists) {
      final services = serviceDoc.data()?['services'] as Map<String, dynamic>?;
      return services?[serviceType]?.toDouble() ?? 500.0; // Default price
    }
    return 500.0; // Default price if not set
  }

  Future<void> _processServicePayment(
    double amount,
    String chwId,
    String serviceType,
  ) async {
    final batch = FirebaseFirestore.instance.batch();

    // Deduct from patient wallet
    final walletRef = FirebaseFirestore.instance
        .collection('chw_patient_wallets')
        .doc(widget.patientId);

    batch.update(walletRef, {
      'balance': FieldValue.increment(-amount),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // Calculate 70/30 split
    final chwAmount = amount * 0.7;
    final adminAmount = amount * 0.3;

    // Credit CHW wallet
    final chwWalletRef = FirebaseFirestore.instance
        .collection('chw_wallets')
        .doc(chwId);

    batch.set(chwWalletRef, {
      'balance': FieldValue.increment(chwAmount),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Credit admin wallet (assuming admin ID is stored in config)
    // For now, we'll create a separate collection for admin earnings
    final adminEarningsRef = FirebaseFirestore.instance
        .collection('admin_earnings')
        .doc();

    batch.set(adminEarningsRef, {
      'amount': adminAmount,
      'source': 'chw_service',
      'chwId': chwId,
      'patientId': widget.patientId,
      'serviceType': serviceType,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Create transaction record
    final transactionRef = FirebaseFirestore.instance
        .collection('chw_transactions')
        .doc();

    batch.set(transactionRef, {
      'type': 'service_payment',
      'patientId': widget.patientId,
      'chwId': chwId,
      'serviceType': serviceType,
      'totalAmount': amount,
      'chwAmount': chwAmount,
      'adminAmount': adminAmount,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antenatal Care (ANC) Visit'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Info Header
                    _buildPatientInfo(),
                    const SizedBox(height: 24),

                    // Visit Information
                    _buildSectionHeader('Visit Information', Icons.event),
                    _buildVisitInfoSection(),
                    const SizedBox(height: 24),

                    // Vital Signs
                    _buildSectionHeader('Vital Signs', Icons.favorite),
                    _buildVitalSignsSection(),
                    const SizedBox(height: 24),

                    // Physical Examination
                    _buildSectionHeader(
                      'Physical Examination',
                      Icons.medical_services,
                    ),
                    _buildPhysicalExamSection(),
                    const SizedBox(height: 24),

                    // Risk Assessment
                    _buildSectionHeader(
                      'Risk Assessment & Complaints',
                      Icons.warning_amber,
                    ),
                    _buildRiskAssessmentSection(),
                    const SizedBox(height: 24),

                    // Laboratory Tests
                    _buildSectionHeader('Laboratory Tests', Icons.biotech),
                    _buildLabTestsSection(),
                    const SizedBox(height: 24),

                    // Interventions
                    _buildSectionHeader('Interventions', Icons.medication),
                    _buildInterventionsSection(),
                    const SizedBox(height: 24),

                    // Health Education
                    _buildSectionHeader('Health Education', Icons.school),
                    _buildHealthEducationSection(),
                    const SizedBox(height: 24),

                    // Referral
                    _buildSectionHeader('Referral', Icons.local_hospital),
                    _buildReferralSection(),
                    const SizedBox(height: 24),

                    // Next Visit
                    _buildSectionHeader('Next Visit', Icons.calendar_today),
                    _buildNextVisitSection(),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveANCVisit,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          'Save ANC Visit',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPatientInfo() {
    return Card(
      color: Colors.pink.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.patientData['fullName'] ?? 'Unknown',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Phone: ${widget.patientData['phone'] ?? 'N/A'}'),
            Text('Gender: ${widget.patientData['gender'] ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.pink),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.pink,
          ),
        ),
      ],
    );
  }

  Widget _buildVisitInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              title: const Text('Visit Date'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_visitDate)),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _visitDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _visitDate = date);
                  }
                },
              ),
            ),
            TextFormField(
              controller: _gestationalAgeController,
              decoration: const InputDecoration(
                labelText: 'Gestational Age (weeks)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (val) =>
                  val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _gravityController,
                    decoration: const InputDecoration(
                      labelText: 'Gravidity (G)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _parityController,
                    decoration: const InputDecoration(
                      labelText: 'Parity (P)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalSignsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bloodPressureController,
              decoration: const InputDecoration(
                labelText: 'Blood Pressure (e.g., 120/80)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _temperatureController,
                    decoration: const InputDecoration(
                      labelText: 'Temperature (°C)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _pulseController,
                    decoration: const InputDecoration(
                      labelText: 'Pulse (bpm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhysicalExamSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _fundalHeightController,
              decoration: const InputDecoration(
                labelText: 'Fundal Height (cm)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _fetalHeartRate,
              decoration: const InputDecoration(
                labelText: 'Fetal Heart Rate',
                border: OutlineInputBorder(),
              ),
              items: [
                'Normal (120-160 bpm)',
                'Below 120 bpm',
                'Above 160 bpm',
                'Not detected',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _fetalHeartRate = val),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _fetalPresentation,
              decoration: const InputDecoration(
                labelText: 'Fetal Presentation',
                border: OutlineInputBorder(),
              ),
              items: [
                'Cephalic',
                'Breech',
                'Transverse',
                'Not determined',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _fetalPresentation = val),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Edema Present'),
              value: _edemaPresent,
              onChanged: (val) => setState(() => _edemaPresent = val ?? false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskAssessmentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Danger Signs',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableDangerSigns.map((sign) {
                final selected = _dangerSigns.contains(sign);
                return FilterChip(
                  label: Text(sign),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _dangerSigns.add(sign);
                      } else {
                        _dangerSigns.remove(sign);
                      }
                    });
                  },
                  selectedColor: Colors.red.shade200,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _complaintsController,
              decoration: const InputDecoration(
                labelText: 'Other Complaints',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabTestsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text('Blood Test Done'),
              value: _bloodTestDone,
              onChanged: (val) => setState(() => _bloodTestDone = val ?? false),
            ),
            if (_bloodTestDone) ...[
              DropdownButtonFormField<String>(
                value: _bloodType,
                decoration: const InputDecoration(
                  labelText: 'Blood Type',
                  border: OutlineInputBorder(),
                ),
                items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => _bloodType = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _hemoglobinLevel,
                decoration: const InputDecoration(
                  labelText: 'Hemoglobin Level',
                  border: OutlineInputBorder(),
                ),
                items:
                    [
                          'Normal (>11 g/dL)',
                          'Mild anemia (9-11 g/dL)',
                          'Moderate anemia (7-9 g/dL)',
                          'Severe anemia (<7 g/dL)',
                        ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (val) => setState(() => _hemoglobinLevel = val),
              ),
            ],
            const Divider(),
            CheckboxListTile(
              title: const Text('Urine Dipstick Done'),
              value: _urineDipstickDone,
              onChanged: (val) =>
                  setState(() => _urineDipstickDone = val ?? false),
            ),
            if (_urineDipstickDone) ...[
              DropdownButtonFormField<String>(
                value: _urineProtein,
                decoration: const InputDecoration(
                  labelText: 'Protein',
                  border: OutlineInputBorder(),
                ),
                items: ['Negative', 'Trace', '+', '++', '+++']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => _urineProtein = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _urineGlucose,
                decoration: const InputDecoration(
                  labelText: 'Glucose',
                  border: OutlineInputBorder(),
                ),
                items: ['Negative', 'Trace', '+', '++', '+++']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => _urineGlucose = val),
              ),
            ],
            const Divider(),
            _buildTestCheckbox(
              'HIV Test',
              _hivTestDone,
              (val) => setState(() => _hivTestDone = val ?? false),
              _hivResult,
              (val) => setState(() => _hivResult = val),
            ),
            const Divider(),
            _buildTestCheckbox(
              'Hepatitis B Test',
              _hepatitisBTestDone,
              (val) => setState(() => _hepatitisBTestDone = val ?? false),
              _hepatitisBResult,
              (val) => setState(() => _hepatitisBResult = val),
            ),
            const Divider(),
            _buildTestCheckbox(
              'Syphilis Test',
              _syphilisTestDone,
              (val) => setState(() => _syphilisTestDone = val ?? false),
              _syphilisResult,
              (val) => setState(() => _syphilisResult = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCheckbox(
    String title,
    bool testDone,
    Function(bool?) onTestChanged,
    String? result,
    Function(String?) onResultChanged,
  ) {
    return Column(
      children: [
        CheckboxListTile(
          title: Text(title),
          value: testDone,
          onChanged: onTestChanged,
        ),
        if (testDone)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonFormField<String>(
              value: result,
              decoration: InputDecoration(
                labelText: '$title Result',
                border: const OutlineInputBorder(),
              ),
              items: [
                'Negative',
                'Positive',
                'Indeterminate',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onResultChanged,
            ),
          ),
      ],
    );
  }

  Widget _buildInterventionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text('Iron & Folic Acid Given'),
              value: _ironFolicAcidGiven,
              onChanged: (val) =>
                  setState(() => _ironFolicAcidGiven = val ?? false),
            ),
            const Divider(),
            CheckboxListTile(
              title: const Text('Malaria IPTp Given'),
              value: _malariaIPTpGiven,
              onChanged: (val) =>
                  setState(() => _malariaIPTpGiven = val ?? false),
            ),
            if (_malariaIPTpGiven)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextFormField(
                  controller: _malariaIPTpDoseController,
                  decoration: const InputDecoration(
                    labelText: 'IPTp Dose (e.g., SP2, SP3)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            const Divider(),
            CheckboxListTile(
              title: const Text('Tetanus Toxoid Given'),
              value: _tetanusToxoidGiven,
              onChanged: (val) =>
                  setState(() => _tetanusToxoidGiven = val ?? false),
            ),
            if (_tetanusToxoidGiven)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextFormField(
                  controller: _tetanusToxoidDoseController,
                  decoration: const InputDecoration(
                    labelText: 'TT Dose (e.g., TT1, TT2)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            const Divider(),
            CheckboxListTile(
              title: const Text('Mosquito Net Provided'),
              value: _mosquitoNetProvided,
              onChanged: (val) =>
                  setState(() => _mosquitoNetProvided = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('Deworming Done'),
              value: _dewormed,
              onChanged: (val) => setState(() => _dewormed = val ?? false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthEducationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Topics Discussed',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _educationOptions.map((topic) {
                final selected = _educationTopics.contains(topic);
                return FilterChip(
                  label: Text(topic),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _educationTopics.add(topic);
                      } else {
                        _educationTopics.remove(topic);
                      }
                    });
                  },
                  selectedColor: Colors.green.shade200,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nutritionAdviceController,
              decoration: const InputDecoration(
                labelText: 'Nutrition Advice Given',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text('Referral Needed'),
              value: _referralNeeded,
              onChanged: (val) =>
                  setState(() => _referralNeeded = val ?? false),
            ),
            if (_referralNeeded) ...[
              TextFormField(
                controller: _referralReasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Referral',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _referralFacility,
                decoration: const InputDecoration(
                  labelText: 'Referral Facility',
                  border: OutlineInputBorder(),
                ),
                items:
                    [
                          'General Hospital',
                          'Teaching Hospital',
                          'Specialist Clinic',
                          'Other',
                        ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (val) => setState(() => _referralFacility = val),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNextVisitSection() {
    return Card(
      child: ListTile(
        title: const Text('Next Visit Date'),
        subtitle: Text(
          _nextVisitDate != null
              ? DateFormat('MMM dd, yyyy').format(_nextVisitDate!)
              : 'Not set',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 28)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              setState(() => _nextVisitDate = date);
            }
          },
        ),
      ),
    );
  }
}
