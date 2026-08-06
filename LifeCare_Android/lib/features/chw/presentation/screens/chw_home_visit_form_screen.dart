import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CHWHomeVisitFormScreen extends StatefulWidget {
  final String patientId;
  final Map<String, dynamic> patientData;

  const CHWHomeVisitFormScreen({
    super.key,
    required this.patientId,
    required this.patientData,
  });

  @override
  State<CHWHomeVisitFormScreen> createState() => _CHWHomeVisitFormScreenState();
}

class _CHWHomeVisitFormScreenState extends State<CHWHomeVisitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Visit Information
  DateTime _visitDate = DateTime.now();
  String? _visitPurpose;
  final _addressController = TextEditingController();

  // Patient Assessment
  final _temperatureController = TextEditingController();
  final _bloodPressureController = TextEditingController();
  final _symptomsController = TextEditingController();
  final _complaintsController = TextEditingController();

  // Home Environment Assessment
  bool _cleanWaterAvailable = true;
  bool _sanitationAdequate = true;
  bool _ventilationAdequate = true;
  bool _mosquitoNetPresent = false;
  bool _firstAidKitPresent = false;
  final _environmentalHazardsController = TextEditingController();

  // Hygiene Practices
  bool _handwashingPracticed = true;
  bool _foodStorageSafe = true;
  bool _wasteDisposalProper = true;
  final _hygieneNotesController = TextEditingController();

  // Medication Adherence
  bool _medicationAvailable = true;
  bool _takingMedicationAsPrescibed = true;
  final _medicationIssuesController = TextEditingController();

  // Health Education Provided
  final List<String> _educationTopics = [];

  // Interventions
  final List<String> _interventions = [];
  final _interventionNotesController = TextEditingController();

  // Follow-up Actions
  bool _referralNeeded = false;
  final _referralReasonController = TextEditingController();
  bool _followUpRequired = false;
  DateTime? _followUpDate;

  // General Notes
  final _notesController = TextEditingController();

  final List<String> _visitPurposeOptions = [
    'Routine follow-up',
    'Post-discharge visit',
    'Medication monitoring',
    'Health education',
    'Environmental assessment',
    'Family support',
    'Chronic disease management',
    'Maternal/child health',
    'Elderly care',
    'Palliative care',
  ];

  final List<String> _educationTopicOptions = [
    'Medication adherence',
    'Nutrition and diet',
    'Hygiene practices',
    'Disease prevention',
    'Water sanitation',
    'Malaria prevention',
    'Waste management',
    'Family planning',
    'Child care',
    'Exercise and mobility',
    'Mental health',
  ];

  final List<String> _interventionOptions = [
    'Vital signs monitoring',
    'Wound dressing',
    'Medication administration',
    'Health education',
    'Referral made',
    'Mosquito net provided',
    'Water treatment',
    'Nutrition counseling',
    'Psychosocial support',
    'Family counseling',
  ];

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.patientData['address'] ?? '';
  }

  @override
  void dispose() {
    _addressController.dispose();
    _temperatureController.dispose();
    _bloodPressureController.dispose();
    _symptomsController.dispose();
    _complaintsController.dispose();
    _environmentalHazardsController.dispose();
    _hygieneNotesController.dispose();
    _medicationIssuesController.dispose();
    _interventionNotesController.dispose();
    _referralReasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveHomeVisit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final chwId = FirebaseAuth.instance.currentUser?.uid;
      if (chwId == null) throw Exception('CHW not logged in');

      final serviceCost = await _getServiceCost('home_visit');

      final walletDoc = await FirebaseFirestore.instance
          .collection('chw_patient_wallets')
          .doc(widget.patientId)
          .get();

      final balance = walletDoc.data()?['balance'] ?? 0.0;

      if (balance < serviceCost) {
        throw Exception(
          'Insufficient wallet balance. Required: ₦$serviceCost, Available: ₦$balance',
        );
      }

      final homeVisitRef = FirebaseFirestore.instance
          .collection('chw_patient_records')
          .doc(widget.patientId)
          .collection('home_visits')
          .doc();

      final homeVisitData = {
        'visitId': homeVisitRef.id,
        'patientId': widget.patientId,
        'chwId': chwId,
        'visitDate': Timestamp.fromDate(_visitDate),
        'visitPurpose': _visitPurpose,
        'address': _addressController.text.trim(),
        'temperature': double.tryParse(_temperatureController.text),
        'bloodPressure': _bloodPressureController.text.trim(),
        'symptoms': _symptomsController.text.trim(),
        'complaints': _complaintsController.text.trim(),
        'cleanWaterAvailable': _cleanWaterAvailable,
        'sanitationAdequate': _sanitationAdequate,
        'ventilationAdequate': _ventilationAdequate,
        'mosquitoNetPresent': _mosquitoNetPresent,
        'firstAidKitPresent': _firstAidKitPresent,
        'environmentalHazards': _environmentalHazardsController.text.trim(),
        'handwashingPracticed': _handwashingPracticed,
        'foodStorageSafe': _foodStorageSafe,
        'wasteDisposalProper': _wasteDisposalProper,
        'hygieneNotes': _hygieneNotesController.text.trim(),
        'medicationAvailable': _medicationAvailable,
        'takingMedicationAsPrescibed': _takingMedicationAsPrescibed,
        'medicationIssues': _medicationIssuesController.text.trim(),
        'educationTopics': _educationTopics,
        'interventions': _interventions,
        'interventionNotes': _interventionNotesController.text.trim(),
        'referralNeeded': _referralNeeded,
        'referralReason': _referralReasonController.text.trim(),
        'followUpRequired': _followUpRequired,
        'followUpDate': _followUpDate != null
            ? Timestamp.fromDate(_followUpDate!)
            : null,
        'notes': _notesController.text.trim(),
        'serviceCost': serviceCost,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await homeVisitRef.set(homeVisitData);
      await _processServicePayment(serviceCost, chwId, 'Home Visit');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Home visit recorded successfully!'),
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
      return services?[serviceType]?.toDouble() ?? 300.0;
    }
    return 300.0;
  }

  Future<void> _processServicePayment(
    double amount,
    String chwId,
    String serviceType,
  ) async {
    final batch = FirebaseFirestore.instance.batch();

    final walletRef = FirebaseFirestore.instance
        .collection('chw_patient_wallets')
        .doc(widget.patientId);

    batch.set(walletRef, {
      'patientId': widget.patientId,
      'balance': FieldValue.increment(-amount),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final chwAmount = amount * 0.7;
    final adminAmount = amount * 0.3;

    final chwWalletRef = FirebaseFirestore.instance
        .collection('chw_wallets')
        .doc(chwId);

    batch.set(chwWalletRef, {
      'balance': FieldValue.increment(chwAmount),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

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
        title: const Text('Home Visit Record'),
        backgroundColor: Colors.orange,
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
                    _buildPatientInfo(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('Visit Information', Icons.event),
                    _buildVisitInfoSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader(
                      'Patient Assessment',
                      Icons.medical_services,
                    ),
                    _buildPatientAssessmentSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('Home Environment', Icons.home),
                    _buildEnvironmentSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('Hygiene Practices', Icons.clean_hands),
                    _buildHygieneSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader(
                      'Medication Adherence',
                      Icons.medication,
                    ),
                    _buildMedicationSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('Health Education', Icons.school),
                    _buildEducationSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('Interventions', Icons.healing),
                    _buildInterventionsSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader(
                      'Follow-up & Referral',
                      Icons.follow_the_signs,
                    ),
                    _buildFollowUpSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('General Notes', Icons.note),
                    _buildNotesSection(),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveHomeVisit,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          'Save Home Visit',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
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
      color: Colors.orange.shade50,
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
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
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
              subtitle: Text(
                DateFormat('MMM dd, yyyy - hh:mm a').format(_visitDate),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _visitDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _visitDate = date);
                },
              ),
            ),
            DropdownButtonFormField<String>(
              value: _visitPurpose,
              decoration: const InputDecoration(
                labelText: 'Purpose of Visit',
                border: OutlineInputBorder(),
              ),
              items: _visitPurposeOptions
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _visitPurpose = val),
              validator: (val) => val == null ? 'Please select purpose' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address Visited',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientAssessmentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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
                    controller: _bloodPressureController,
                    decoration: const InputDecoration(
                      labelText: 'Blood Pressure',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _symptomsController,
              decoration: const InputDecoration(
                labelText: 'Current Symptoms',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _complaintsController,
              decoration: const InputDecoration(
                labelText: 'Complaints',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text('Clean Water Available'),
              value: _cleanWaterAvailable,
              onChanged: (val) =>
                  setState(() => _cleanWaterAvailable = val ?? true),
            ),
            CheckboxListTile(
              title: const Text('Sanitation Adequate'),
              value: _sanitationAdequate,
              onChanged: (val) =>
                  setState(() => _sanitationAdequate = val ?? true),
            ),
            CheckboxListTile(
              title: const Text('Ventilation Adequate'),
              value: _ventilationAdequate,
              onChanged: (val) =>
                  setState(() => _ventilationAdequate = val ?? true),
            ),
            CheckboxListTile(
              title: const Text('Mosquito Net Present'),
              value: _mosquitoNetPresent,
              onChanged: (val) =>
                  setState(() => _mosquitoNetPresent = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('First Aid Kit Present'),
              value: _firstAidKitPresent,
              onChanged: (val) =>
                  setState(() => _firstAidKitPresent = val ?? false),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _environmentalHazardsController,
              decoration: const InputDecoration(
                labelText: 'Environmental Hazards Identified',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHygieneSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text('Handwashing Practiced'),
              value: _handwashingPracticed,
              onChanged: (val) =>
                  setState(() => _handwashingPracticed = val ?? true),
            ),
            CheckboxListTile(
              title: const Text('Food Storage Safe'),
              value: _foodStorageSafe,
              onChanged: (val) =>
                  setState(() => _foodStorageSafe = val ?? true),
            ),
            CheckboxListTile(
              title: const Text('Waste Disposal Proper'),
              value: _wasteDisposalProper,
              onChanged: (val) =>
                  setState(() => _wasteDisposalProper = val ?? true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hygieneNotesController,
              decoration: const InputDecoration(
                labelText: 'Hygiene Observations',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text('Medication Available'),
              value: _medicationAvailable,
              onChanged: (val) =>
                  setState(() => _medicationAvailable = val ?? true),
            ),
            CheckboxListTile(
              title: const Text('Taking Medication as Prescribed'),
              value: _takingMedicationAsPrescibed,
              onChanged: (val) =>
                  setState(() => _takingMedicationAsPrescibed = val ?? true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _medicationIssuesController,
              decoration: const InputDecoration(
                labelText: 'Medication Issues/Concerns',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationSection() {
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
              children: _educationTopicOptions.map((topic) {
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
          ],
        ),
      ),
    );
  }

  Widget _buildInterventionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Interventions Provided',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _interventionOptions.map((intervention) {
                final selected = _interventions.contains(intervention);
                return FilterChip(
                  label: Text(intervention),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _interventions.add(intervention);
                      } else {
                        _interventions.remove(intervention);
                      }
                    });
                  },
                  selectedColor: Colors.blue.shade200,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _interventionNotesController,
              decoration: const InputDecoration(
                labelText: 'Intervention Details',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowUpSection() {
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
            if (_referralNeeded)
              TextFormField(
                controller: _referralReasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Referral',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            const Divider(),
            CheckboxListTile(
              title: const Text('Follow-up Visit Required'),
              value: _followUpRequired,
              onChanged: (val) =>
                  setState(() => _followUpRequired = val ?? false),
            ),
            if (_followUpRequired)
              ListTile(
                title: const Text('Follow-up Date'),
                subtitle: Text(
                  _followUpDate != null
                      ? DateFormat('MMM dd, yyyy').format(_followUpDate!)
                      : 'Not set',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => _followUpDate = date);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'General Notes',
            border: OutlineInputBorder(),
            hintText: 'Additional observations, recommendations, etc.',
          ),
          maxLines: 5,
        ),
      ),
    );
  }
}
