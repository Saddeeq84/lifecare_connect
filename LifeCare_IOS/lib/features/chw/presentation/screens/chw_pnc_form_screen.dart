import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CHWPNCFormScreen extends StatefulWidget {
  final String patientId;
  final Map<String, dynamic> patientData;

  const CHWPNCFormScreen({
    super.key,
    required this.patientId,
    required this.patientData,
  });

  @override
  State<CHWPNCFormScreen> createState() => _CHWPNCFormScreenState();
}

class _CHWPNCFormScreenState extends State<CHWPNCFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Visit Information
  DateTime _visitDate = DateTime.now();
  final _daysPostpartumController = TextEditingController();
  String? _deliveryType;
  String? _deliveryPlace;
  DateTime? _deliveryDate;

  // Mother's Health
  final _temperatureController = TextEditingController();
  final _bloodPressureController = TextEditingController();
  final _pulseController = TextEditingController();
  bool _vaginalBleedingNormal = true;
  bool _lochiaNormal = true;
  bool _breastsPainful = false;
  bool _nipplesCracked = false;
  final _complaintsController = TextEditingController();

  // Mother Danger Signs
  final List<String> _motherDangerSigns = [];

  // Baby's Health
  final _babyWeightController = TextEditingController();
  final _babyTempController = TextEditingController();
  bool _babyBreathing = true;
  bool _babyFeeding = true;
  bool _cordNormal = true;
  bool _jaundicePresent = false;
  final _babyComplaintsController = TextEditingController();

  // Baby Danger Signs
  final List<String> _babyDangerSigns = [];

  // Breastfeeding Assessment
  String? _breastfeedingStatus;
  bool _exclusiveBreastfeeding = true;
  final _breastfeedingDifficultiesController = TextEditingController();

  // Interventions
  bool _vitaminAGiven = false;
  bool _ironSupplementGiven = false;
  bool _familyPlanningDiscussed = false;
  String? _familyPlanningMethod;
  bool _vaccinesGiven = false;
  final _vaccinesDetailsController = TextEditingController();

  // Health Education
  final List<String> _educationTopics = [];
  final _notesController = TextEditingController();

  // Referral
  bool _motherReferralNeeded = false;
  bool _babyReferralNeeded = false;
  final _referralReasonController = TextEditingController();

  // Next Visit
  DateTime? _nextVisitDate;

  final List<String> _motherDangerSignOptions = [
    'Heavy vaginal bleeding',
    'Foul-smelling discharge',
    'High fever',
    'Severe headache',
    'Blurred vision',
    'Convulsions',
    'Severe abdominal pain',
    'Difficulty breathing',
    'Swelling of hands/face',
    'Severe weakness',
    'Loss of consciousness',
  ];

  final List<String> _babyDangerSignOptions = [
    'Not feeding well',
    'Fever or cold',
    'Fast breathing',
    'Chest indrawing',
    'Yellow skin/eyes',
    'Convulsions',
    'Lethargy',
    'Red/swollen cord',
    'Cord discharge',
    'Not passing urine',
    'Persistent crying',
    'Vomiting everything',
  ];

  final List<String> _educationOptions = [
    'Breastfeeding techniques',
    'Exclusive breastfeeding',
    'Newborn care',
    'Cord care',
    'Hygiene practices',
    'Nutrition for mother',
    'Danger signs recognition',
    'Family planning',
    'Immunization schedule',
    'Baby development',
  ];

  @override
  void dispose() {
    _daysPostpartumController.dispose();
    _temperatureController.dispose();
    _bloodPressureController.dispose();
    _pulseController.dispose();
    _complaintsController.dispose();
    _babyWeightController.dispose();
    _babyTempController.dispose();
    _babyComplaintsController.dispose();
    _breastfeedingDifficultiesController.dispose();
    _vaccinesDetailsController.dispose();
    _notesController.dispose();
    _referralReasonController.dispose();
    super.dispose();
  }

  Future<void> _savePNCVisit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final chwId = FirebaseAuth.instance.currentUser?.uid;
      if (chwId == null) throw Exception('CHW not logged in');

      final serviceCost = await _getServiceCost('pnc');

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

      final pncRecordRef = FirebaseFirestore.instance
          .collection('chw_patient_records')
          .doc(widget.patientId)
          .collection('pnc_visits')
          .doc();

      final pncData = {
        'visitId': pncRecordRef.id,
        'patientId': widget.patientId,
        'chwId': chwId,
        'visitDate': Timestamp.fromDate(_visitDate),
        'daysPostpartum': int.tryParse(_daysPostpartumController.text),
        'deliveryType': _deliveryType,
        'deliveryPlace': _deliveryPlace,
        'deliveryDate': _deliveryDate != null
            ? Timestamp.fromDate(_deliveryDate!)
            : null,
        'motherTemperature': double.tryParse(_temperatureController.text),
        'motherBloodPressure': _bloodPressureController.text.trim(),
        'motherPulse': int.tryParse(_pulseController.text),
        'vaginalBleedingNormal': _vaginalBleedingNormal,
        'lochiaNormal': _lochiaNormal,
        'breastsPainful': _breastsPainful,
        'nipplesCracked': _nipplesCracked,
        'motherComplaints': _complaintsController.text.trim(),
        'motherDangerSigns': _motherDangerSigns,
        'babyWeight': double.tryParse(_babyWeightController.text),
        'babyTemperature': double.tryParse(_babyTempController.text),
        'babyBreathing': _babyBreathing,
        'babyFeeding': _babyFeeding,
        'cordNormal': _cordNormal,
        'jaundicePresent': _jaundicePresent,
        'babyComplaints': _babyComplaintsController.text.trim(),
        'babyDangerSigns': _babyDangerSigns,
        'breastfeedingStatus': _breastfeedingStatus,
        'exclusiveBreastfeeding': _exclusiveBreastfeeding,
        'breastfeedingDifficulties': _breastfeedingDifficultiesController.text
            .trim(),
        'vitaminAGiven': _vitaminAGiven,
        'ironSupplementGiven': _ironSupplementGiven,
        'familyPlanningDiscussed': _familyPlanningDiscussed,
        'familyPlanningMethod': _familyPlanningMethod,
        'vaccinesGiven': _vaccinesGiven,
        'vaccinesDetails': _vaccinesDetailsController.text.trim(),
        'educationTopics': _educationTopics,
        'notes': _notesController.text.trim(),
        'motherReferralNeeded': _motherReferralNeeded,
        'babyReferralNeeded': _babyReferralNeeded,
        'referralReason': _referralReasonController.text.trim(),
        'nextVisitDate': _nextVisitDate != null
            ? Timestamp.fromDate(_nextVisitDate!)
            : null,
        'serviceCost': serviceCost,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await pncRecordRef.set(pncData);
      await _processServicePayment(serviceCost, chwId, 'PNC Visit');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PNC visit recorded successfully!'),
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
      return services?[serviceType]?.toDouble() ?? 400.0;
    }
    return 400.0;
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
        title: const Text('Postnatal Care (PNC) Visit'),
        backgroundColor: Colors.purple,
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

                    _buildSectionHeader(
                      'Visit & Delivery Information',
                      Icons.event,
                    ),
                    _buildVisitInfoSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader(
                      'Mother\'s Health Assessment',
                      Icons.pregnant_woman,
                    ),
                    _buildMotherHealthSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader(
                      'Baby\'s Health Assessment',
                      Icons.child_care,
                    ),
                    _buildBabyHealthSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader(
                      'Breastfeeding Assessment',
                      Icons.baby_changing_station,
                    ),
                    _buildBreastfeedingSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('Interventions', Icons.medication),
                    _buildInterventionsSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('Health Education', Icons.school),
                    _buildHealthEducationSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('Referral', Icons.local_hospital),
                    _buildReferralSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('Next Visit', Icons.calendar_today),
                    _buildNextVisitSection(),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _savePNCVisit,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          'Save PNC Visit',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
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
      color: Colors.purple.shade50,
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
        Icon(icon, color: Colors.purple),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.purple,
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
                  if (date != null) setState(() => _visitDate = date);
                },
              ),
            ),
            TextFormField(
              controller: _daysPostpartumController,
              decoration: const InputDecoration(
                labelText: 'Days Postpartum',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (val) =>
                  val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Delivery Date'),
              subtitle: Text(
                _deliveryDate != null
                    ? DateFormat('MMM dd, yyyy').format(_deliveryDate!)
                    : 'Not set',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().subtract(
                      const Duration(days: 7),
                    ),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _deliveryDate = date);
                },
              ),
            ),
            DropdownButtonFormField<String>(
              value: _deliveryType,
              decoration: const InputDecoration(
                labelText: 'Delivery Type',
                border: OutlineInputBorder(),
              ),
              items: [
                'Normal Vaginal Delivery',
                'Caesarean Section',
                'Assisted Delivery',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _deliveryType = val),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _deliveryPlace,
              decoration: const InputDecoration(
                labelText: 'Place of Delivery',
                border: OutlineInputBorder(),
              ),
              items: [
                'Hospital',
                'Health Center',
                'Home',
                'Traditional Birth Attendant',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _deliveryPlace = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotherHealthSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _bloodPressureController,
              decoration: const InputDecoration(
                labelText: 'Blood Pressure (e.g., 120/80)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Vaginal Bleeding Normal'),
              value: _vaginalBleedingNormal,
              onChanged: (val) =>
                  setState(() => _vaginalBleedingNormal = val ?? true),
            ),
            CheckboxListTile(
              title: const Text('Lochia Normal'),
              value: _lochiaNormal,
              onChanged: (val) => setState(() => _lochiaNormal = val ?? true),
            ),
            CheckboxListTile(
              title: const Text('Breasts Painful/Engorged'),
              value: _breastsPainful,
              onChanged: (val) =>
                  setState(() => _breastsPainful = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('Nipples Cracked'),
              value: _nipplesCracked,
              onChanged: (val) =>
                  setState(() => _nipplesCracked = val ?? false),
            ),
            const SizedBox(height: 12),
            const Text(
              'Mother Danger Signs',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _motherDangerSignOptions.map((sign) {
                final selected = _motherDangerSigns.contains(sign);
                return FilterChip(
                  label: Text(sign),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _motherDangerSigns.add(sign);
                      } else {
                        _motherDangerSigns.remove(sign);
                      }
                    });
                  },
                  selectedColor: Colors.red.shade200,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _complaintsController,
              decoration: const InputDecoration(
                labelText: 'Other Complaints',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBabyHealthSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _babyWeightController,
                    decoration: const InputDecoration(
                      labelText: 'Baby Weight (kg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _babyTempController,
                    decoration: const InputDecoration(
                      labelText: 'Baby Temp (°C)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Baby Breathing Normally'),
              value: _babyBreathing,
              onChanged: (val) => setState(() => _babyBreathing = val ?? true),
            ),
            CheckboxListTile(
              title: const Text('Baby Feeding Well'),
              value: _babyFeeding,
              onChanged: (val) => setState(() => _babyFeeding = val ?? true),
            ),
            CheckboxListTile(
              title: const Text('Umbilical Cord Normal'),
              value: _cordNormal,
              onChanged: (val) => setState(() => _cordNormal = val ?? true),
            ),
            CheckboxListTile(
              title: const Text('Jaundice Present'),
              value: _jaundicePresent,
              onChanged: (val) =>
                  setState(() => _jaundicePresent = val ?? false),
            ),
            const SizedBox(height: 12),
            const Text(
              'Baby Danger Signs',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _babyDangerSignOptions.map((sign) {
                final selected = _babyDangerSigns.contains(sign);
                return FilterChip(
                  label: Text(sign),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _babyDangerSigns.add(sign);
                      } else {
                        _babyDangerSigns.remove(sign);
                      }
                    });
                  },
                  selectedColor: Colors.red.shade200,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _babyComplaintsController,
              decoration: const InputDecoration(
                labelText: 'Baby Complaints',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreastfeedingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _breastfeedingStatus,
              decoration: const InputDecoration(
                labelText: 'Breastfeeding Status',
                border: OutlineInputBorder(),
              ),
              items: [
                'Established well',
                'Some difficulties',
                'Not breastfeeding',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _breastfeedingStatus = val),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Exclusive Breastfeeding (0-6 months)'),
              value: _exclusiveBreastfeeding,
              onChanged: (val) =>
                  setState(() => _exclusiveBreastfeeding = val ?? true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _breastfeedingDifficultiesController,
              decoration: const InputDecoration(
                labelText: 'Breastfeeding Difficulties',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
          children: [
            CheckboxListTile(
              title: const Text('Vitamin A Given to Mother'),
              value: _vitaminAGiven,
              onChanged: (val) => setState(() => _vitaminAGiven = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('Iron Supplement Given to Mother'),
              value: _ironSupplementGiven,
              onChanged: (val) =>
                  setState(() => _ironSupplementGiven = val ?? false),
            ),
            const Divider(),
            CheckboxListTile(
              title: const Text('Family Planning Discussed'),
              value: _familyPlanningDiscussed,
              onChanged: (val) =>
                  setState(() => _familyPlanningDiscussed = val ?? false),
            ),
            if (_familyPlanningDiscussed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: DropdownButtonFormField<String>(
                  value: _familyPlanningMethod,
                  decoration: const InputDecoration(
                    labelText: 'Family Planning Method',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                            'Condoms',
                            'Pills',
                            'Injection',
                            'IUD',
                            'Implant',
                            'Natural methods',
                            'Not decided',
                          ]
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                  onChanged: (val) =>
                      setState(() => _familyPlanningMethod = val),
                ),
              ),
            const Divider(),
            CheckboxListTile(
              title: const Text('Baby Vaccines Given'),
              value: _vaccinesGiven,
              onChanged: (val) => setState(() => _vaccinesGiven = val ?? false),
            ),
            if (_vaccinesGiven)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextFormField(
                  controller: _vaccinesDetailsController,
                  decoration: const InputDecoration(
                    labelText: 'Vaccine Details (e.g., BCG, OPV0)',
                    border: OutlineInputBorder(),
                  ),
                ),
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
              title: const Text('Mother Referral Needed'),
              value: _motherReferralNeeded,
              onChanged: (val) =>
                  setState(() => _motherReferralNeeded = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('Baby Referral Needed'),
              value: _babyReferralNeeded,
              onChanged: (val) =>
                  setState(() => _babyReferralNeeded = val ?? false),
            ),
            if (_motherReferralNeeded || _babyReferralNeeded)
              TextFormField(
                controller: _referralReasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Referral',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
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
              initialDate: DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) setState(() => _nextVisitDate = date);
          },
        ),
      ),
    );
  }
}
