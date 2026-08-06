import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CHWImmunizationFormScreen extends StatefulWidget {
  final String patientId;
  final Map<String, dynamic> patientData;

  const CHWImmunizationFormScreen({
    super.key,
    required this.patientId,
    required this.patientData,
  });

  @override
  State<CHWImmunizationFormScreen> createState() =>
      _CHWImmunizationFormScreenState();
}

class _CHWImmunizationFormScreenState extends State<CHWImmunizationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Immunization Details
  DateTime _immunizationDate = DateTime.now();
  String? _vaccineType;
  String? _doseNumber;
  final _batchNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  String? _administrationSite;
  String? _administrationRoute;
  final _childWeightController = TextEditingController();
  final _childTemperatureController = TextEditingController();

  // Pre-immunization Assessment
  bool _childHealthyToday = true;
  bool _noRecentIllness = true;
  bool _noAllergies = true;
  bool _noPreviousReactions = true;
  final _assessmentNotesController = TextEditingController();

  // Adverse Events
  bool _adverseEventOccurred = false;
  final List<String> _adverseEvents = [];
  final _adverseEventDetailsController = TextEditingController();
  String? _adverseEventSeverity;
  bool _referredForAdverseEvent = false;

  // Follow-up
  DateTime? _nextVaccineDate;
  String? _nextVaccine;
  final _followUpNotesController = TextEditingController();

  // General Notes
  final _notesController = TextEditingController();

  final Map<String, List<String>> _vaccineSchedule = {
    'BCG': ['At birth'],
    'OPV': [
      'At birth',
      'Dose 1 (6 weeks)',
      'Dose 2 (10 weeks)',
      'Dose 3 (14 weeks)',
    ],
    'Pentavalent': [
      'Dose 1 (6 weeks)',
      'Dose 2 (10 weeks)',
      'Dose 3 (14 weeks)',
    ],
    'PCV': ['Dose 1 (6 weeks)', 'Dose 2 (10 weeks)', 'Dose 3 (14 weeks)'],
    'Rotavirus': ['Dose 1 (6 weeks)', 'Dose 2 (10 weeks)'],
    'IPV': ['Dose 1 (14 weeks)'],
    'Measles-Rubella': ['Dose 1 (9 months)', 'Dose 2 (15 months)'],
    'Yellow Fever': ['At 9 months'],
    'Meningitis A': ['Dose 1 (9 months)'],
    'Vitamin A': ['6 months', '12 months', 'Every 6 months'],
  };

  final List<String> _administrationSites = [
    'Right arm (deltoid)',
    'Left arm (deltoid)',
    'Right thigh (vastus lateralis)',
    'Left thigh (vastus lateralis)',
    'Other',
  ];

  final List<String> _administrationRoutes = [
    'Intramuscular (IM)',
    'Subcutaneous (SC)',
    'Intradermal (ID)',
    'Oral',
  ];

  final List<String> _adverseEventOptions = [
    'Mild fever',
    'Injection site pain',
    'Injection site swelling',
    'Injection site redness',
    'Irritability',
    'Drowsiness',
    'Loss of appetite',
    'Vomiting',
    'Diarrhea',
    'Rash',
    'Severe allergic reaction',
    'Seizures',
  ];

  final List<String> _severityLevels = ['Mild', 'Moderate', 'Severe'];

  @override
  void dispose() {
    _batchNumberController.dispose();
    _expiryDateController.dispose();
    _childWeightController.dispose();
    _childTemperatureController.dispose();
    _assessmentNotesController.dispose();
    _adverseEventDetailsController.dispose();
    _followUpNotesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveImmunization() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final chwId = FirebaseAuth.instance.currentUser?.uid;
      if (chwId == null) throw Exception('CHW not logged in');

      final serviceCost = await _getServiceCost('immunization');

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

      final immunizationRef = FirebaseFirestore.instance
          .collection('chw_patient_records')
          .doc(widget.patientId)
          .collection('immunizations')
          .doc();

      final immunizationData = {
        'immunizationId': immunizationRef.id,
        'patientId': widget.patientId,
        'chwId': chwId,
        'immunizationDate': Timestamp.fromDate(_immunizationDate),
        'vaccineType': _vaccineType,
        'doseNumber': _doseNumber,
        'batchNumber': _batchNumberController.text.trim(),
        'expiryDate': _expiryDateController.text.trim(),
        'administrationSite': _administrationSite,
        'administrationRoute': _administrationRoute,
        'childWeight': double.tryParse(_childWeightController.text),
        'childTemperature': double.tryParse(_childTemperatureController.text),
        'childHealthyToday': _childHealthyToday,
        'noRecentIllness': _noRecentIllness,
        'noAllergies': _noAllergies,
        'noPreviousReactions': _noPreviousReactions,
        'assessmentNotes': _assessmentNotesController.text.trim(),
        'adverseEventOccurred': _adverseEventOccurred,
        'adverseEvents': _adverseEvents,
        'adverseEventDetails': _adverseEventDetailsController.text.trim(),
        'adverseEventSeverity': _adverseEventSeverity,
        'referredForAdverseEvent': _referredForAdverseEvent,
        'nextVaccineDate': _nextVaccineDate != null
            ? Timestamp.fromDate(_nextVaccineDate!)
            : null,
        'nextVaccine': _nextVaccine,
        'followUpNotes': _followUpNotesController.text.trim(),
        'notes': _notesController.text.trim(),
        'serviceCost': serviceCost,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await immunizationRef.set(immunizationData);
      await _processServicePayment(serviceCost, chwId, 'Immunization');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Immunization recorded successfully!'),
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
      return services?[serviceType]?.toDouble() ?? 200.0;
    }
    return 200.0;
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

    batch.update(walletRef, {
      'balance': FieldValue.increment(-amount),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

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
        title: const Text('Immunization Record'),
        backgroundColor: Colors.teal,
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

                    _buildSectionHeader('Vaccine Information', Icons.vaccines),
                    _buildVaccineInfoSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader(
                      'Pre-immunization Assessment',
                      Icons.health_and_safety,
                    ),
                    _buildAssessmentSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader(
                      'Adverse Events Monitoring',
                      Icons.warning_amber,
                    ),
                    _buildAdverseEventsSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('Follow-up Schedule', Icons.schedule),
                    _buildFollowUpSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('General Notes', Icons.note),
                    _buildNotesSection(),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveImmunization,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          'Save Immunization',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
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
      color: Colors.teal.shade50,
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
            Text('Age: ${widget.patientData['age'] ?? 'N/A'}'),
            Text('Phone: ${widget.patientData['phone'] ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.teal),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildVaccineInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              title: const Text('Immunization Date'),
              subtitle: Text(
                DateFormat('MMM dd, yyyy - hh:mm a').format(_immunizationDate),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _immunizationDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _immunizationDate = date);
                },
              ),
            ),
            const Divider(),
            DropdownButtonFormField<String>(
              value: _vaccineType,
              decoration: const InputDecoration(
                labelText: 'Vaccine Type',
                border: OutlineInputBorder(),
              ),
              items: _vaccineSchedule.keys
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _vaccineType = val;
                  _doseNumber = null;
                });
              },
              validator: (val) => val == null ? 'Please select vaccine' : null,
            ),
            const SizedBox(height: 12),
            if (_vaccineType != null)
              DropdownButtonFormField<String>(
                value: _doseNumber,
                decoration: const InputDecoration(
                  labelText: 'Dose Number',
                  border: OutlineInputBorder(),
                ),
                items: _vaccineSchedule[_vaccineType]!
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => _doseNumber = val),
                validator: (val) => val == null ? 'Please select dose' : null,
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _batchNumberController,
              decoration: const InputDecoration(
                labelText: 'Batch/Lot Number',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _expiryDateController,
              decoration: const InputDecoration(
                labelText: 'Expiry Date (MM/YYYY)',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _administrationSite,
              decoration: const InputDecoration(
                labelText: 'Administration Site',
                border: OutlineInputBorder(),
              ),
              items: _administrationSites
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _administrationSite = val),
              validator: (val) => val == null ? 'Please select site' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _administrationRoute,
              decoration: const InputDecoration(
                labelText: 'Administration Route',
                border: OutlineInputBorder(),
              ),
              items: _administrationRoutes
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _administrationRoute = val),
              validator: (val) => val == null ? 'Please select route' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _childWeightController,
                    decoration: const InputDecoration(
                      labelText: 'Child Weight (kg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _childTemperatureController,
                    decoration: const InputDecoration(
                      labelText: 'Temperature (°C)',
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

  Widget _buildAssessmentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text('Child is healthy today'),
              value: _childHealthyToday,
              onChanged: (val) =>
                  setState(() => _childHealthyToday = val ?? true),
            ),
            CheckboxListTile(
              title: const Text('No recent illness'),
              value: _noRecentIllness,
              onChanged: (val) =>
                  setState(() => _noRecentIllness = val ?? true),
            ),
            CheckboxListTile(
              title: const Text('No known allergies'),
              value: _noAllergies,
              onChanged: (val) => setState(() => _noAllergies = val ?? true),
            ),
            CheckboxListTile(
              title: const Text('No previous adverse reactions'),
              value: _noPreviousReactions,
              onChanged: (val) =>
                  setState(() => _noPreviousReactions = val ?? true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _assessmentNotesController,
              decoration: const InputDecoration(
                labelText: 'Assessment Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdverseEventsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              title: const Text('Adverse Event Occurred'),
              value: _adverseEventOccurred,
              onChanged: (val) =>
                  setState(() => _adverseEventOccurred = val ?? false),
            ),
            if (_adverseEventOccurred) ...[
              const SizedBox(height: 8),
              const Text(
                'Select adverse events:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _adverseEventOptions.map((event) {
                  final selected = _adverseEvents.contains(event);
                  return FilterChip(
                    label: Text(event),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _adverseEvents.add(event);
                        } else {
                          _adverseEvents.remove(event);
                        }
                      });
                    },
                    selectedColor: Colors.red.shade200,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _adverseEventDetailsController,
                decoration: const InputDecoration(
                  labelText: 'Event Details',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _adverseEventSeverity,
                decoration: const InputDecoration(
                  labelText: 'Severity Level',
                  border: OutlineInputBorder(),
                ),
                items: _severityLevels
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => _adverseEventSeverity = val),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Referred for adverse event management'),
                value: _referredForAdverseEvent,
                onChanged: (val) =>
                    setState(() => _referredForAdverseEvent = val ?? false),
              ),
            ],
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
            DropdownButtonFormField<String>(
              value: _nextVaccine,
              decoration: const InputDecoration(
                labelText: 'Next Vaccine Due',
                border: OutlineInputBorder(),
              ),
              items: _vaccineSchedule.keys
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _nextVaccine = val),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Next Vaccine Date'),
              subtitle: Text(
                _nextVaccineDate != null
                    ? DateFormat('MMM dd, yyyy').format(_nextVaccineDate!)
                    : 'Not set',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 28)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (date != null) setState(() => _nextVaccineDate = date);
                },
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _followUpNotesController,
              decoration: const InputDecoration(
                labelText: 'Follow-up Instructions',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
            hintText:
                'Additional observations, parent education provided, etc.',
          ),
          maxLines: 5,
        ),
      ),
    );
  }
}
