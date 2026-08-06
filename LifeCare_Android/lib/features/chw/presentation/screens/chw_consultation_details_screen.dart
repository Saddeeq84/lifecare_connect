// ignore_for_file: use_build_context_synchronously, prefer_final_fields, deprecated_member_use, prefer_const_constructors, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/data/services/health_records_service.dart';
import '../../../shared/helpers/chw_message_helper.dart';

class CHWConsultationDetailsScreen extends StatefulWidget {
  final String appointmentId;
  final String patientId;
  final String patientName;
  final Map<String, dynamic> appointmentData;
  final bool isReadOnly;

  const CHWConsultationDetailsScreen({
    super.key,
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.appointmentData,
    this.isReadOnly = false,
  });

  @override
  State<CHWConsultationDetailsScreen> createState() =>
      _CHWConsultationDetailsScreenState();
}

class _CHWConsultationDetailsScreenState
    extends State<CHWConsultationDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _consultationFormKey = GlobalKey<FormState>();

  // Patient Assessment Fields
  final _chiefComplaintController = TextEditingController();
  final _symptomsController = TextEditingController();
  final _notesController = TextEditingController();

  // Vital Signs Fields
  final _temperatureController = TextEditingController();
  final _bloodPressureController = TextEditingController();
  final _pulseRateController = TextEditingController();
  final _respiratoryRateController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  // Education & Counseling Fields
  final _healthEducationController = TextEditingController();
  final _counselingNotesController = TextEditingController();
  final _birthPreparednessController = TextEditingController();
  final _followUpAdviceController = TextEditingController();

  // AI Analysis State
  String _aiSymptomInterpretation = '';
  String _aiReferralRecommendation = '';
  List<String> _aiHealthEducationTopics = [];
  bool _showAIAlert = false;
  String _aiAlertMessage = '';
  Color _aiAlertColor = Colors.orange;
  bool _isAnalyzingSymptoms = false;

  // Legacy fields for backward compatibility
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _vitalsController = TextEditingController();

  bool _isLoading = false;

  // Common Chief Complaints based on Primary Healthcare best practices
  final List<String> _commonChiefComplaints = [
    'Fever',
    'Cough and Cold',
    'Diarrhea',
    'Vomiting',
    'Abdominal Pain',
    'Headache',
    'Body Pain/Malaise',
    'Difficulty Breathing',
    'Chest Pain',
    'Rash/Skin Problem',
    'Wound/Injury',
    'Ear Pain',
    'Sore Throat',
    'Eye Problem',
    'Weakness/Fatigue',
    'Loss of Appetite',
    'Pregnancy-Related Issue',
    'Child Immunization',
    'Family Planning',
    'Health Education Request',
    'Other (specify below)',
  ];

  String? _selectedChiefComplaint;

  final List<String> _commonSymptoms = [
    'Fever',
    'Cough',
    'Headache',
    'Diarrhea',
    'Vomiting',
    'Body Pain',
    'Abdominal Pain',
    'Difficulty Breathing',
    'Chest Pain',
    'Dizziness',
    'Fatigue',
    'Loss of Appetite',
  ];

  final List<String> _healthEducationTopics = [
    'Hand Washing',
    'Nutrition',
    'Malaria Prevention',
    'Use of Mosquito Nets',
    'Oral Rehydration',
    'Safe Water',
    'Hygiene Practices',
    'Breastfeeding',
    'Immunization',
    'When to Seek Medical Help',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chiefComplaintController.dispose();
    _symptomsController.dispose();
    _notesController.dispose();
    _temperatureController.dispose();
    _bloodPressureController.dispose();
    _pulseRateController.dispose();
    _respiratoryRateController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _healthEducationController.dispose();
    _counselingNotesController.dispose();
    _birthPreparednessController.dispose();
    _followUpAdviceController.dispose();
    _diagnosisController.dispose();
    _treatmentController.dispose();
    _vitalsController.dispose();
    super.dispose();
  }

  // AI-Powered Symptom Analysis
  Future<void> _analyzeSymptoms() async {
    if (_symptomsController.text.trim().isEmpty) {
      return;
    }

    setState(() => _isAnalyzingSymptoms = true);

    try {
      final symptoms = _symptomsController.text.trim().toLowerCase();
      final temp = double.tryParse(_temperatureController.text.trim()) ?? 0;
      final bp = _bloodPressureController.text.trim();

      // AI Symptom Interpretation
      String interpretation = '';
      String referralAdvice = '';
      List<String> educationTopics = [];
      bool needsReferral = false;
      String alertMsg = '';
      Color alertColor = Colors.orange;

      // Critical vital signs check
      if (temp > 38.5) {
        needsReferral = true;
        alertMsg =
            '⚠️ HIGH FEVER DETECTED! Immediate medical attention recommended.';
        alertColor = Colors.red;
        referralAdvice =
            'URGENT: Refer to doctor immediately for high fever (>38.5°C)';
      } else if (temp < 35.0 && temp > 0) {
        needsReferral = true;
        alertMsg =
            '⚠️ HYPOTHERMIA DETECTED! Immediate medical attention required.';
        alertColor = Colors.red;
        referralAdvice =
            'URGENT: Refer to doctor immediately for low temperature';
      }

      // Blood pressure analysis
      if (bp.isNotEmpty) {
        final bpParts = bp.split('/');
        if (bpParts.length == 2) {
          final systolic = int.tryParse(bpParts[0]) ?? 0;
          final diastolic = int.tryParse(bpParts[1]) ?? 0;

          if (systolic > 140 || diastolic > 90) {
            needsReferral = true;
            alertMsg = '⚠️ HIGH BLOOD PRESSURE! Refer to doctor.';
            alertColor = Colors.red;
            referralAdvice =
                'URGENT: Hypertension detected. Refer to doctor for management.';
          } else if (systolic < 90 || diastolic < 60) {
            needsReferral = true;
            alertMsg = '⚠️ LOW BLOOD PRESSURE! Medical evaluation needed.';
            alertColor = Colors.orange;
            referralAdvice = 'Refer to doctor for hypotension evaluation.';
          }
        }
      }

      // Symptom-based analysis
      if (symptoms.contains('chest pain') ||
          symptoms.contains('difficulty breathing')) {
        needsReferral = true;
        interpretation = 'EMERGENCY: Possible cardiac or respiratory emergency';
        referralAdvice =
            'URGENT REFERRAL: Immediate medical evaluation required for chest pain/breathing difficulty';
        alertMsg = '🚨 EMERGENCY! Immediate referral required!';
        alertColor = Colors.red;
      } else if (symptoms.contains('severe headache') &&
          symptoms.contains('stiff neck')) {
        needsReferral = true;
        interpretation = 'WARNING: Possible meningitis';
        referralAdvice =
            'URGENT: Refer to doctor immediately - possible meningitis';
        alertMsg = '⚠️ Possible meningitis! Immediate referral needed.';
        alertColor = Colors.red;
      } else if (symptoms.contains('fever') && symptoms.contains('cough')) {
        interpretation =
            'Likely respiratory infection (flu, pneumonia, or COVID-19)';
        referralAdvice =
            'Monitor closely. Refer if symptoms worsen or fever persists >3 days';
        educationTopics = [
          'Hand Washing',
          'Cough Etiquette',
          'When to Seek Medical Help',
        ];
      } else if (symptoms.contains('diarrhea') &&
          symptoms.contains('vomiting')) {
        interpretation = 'Likely gastroenteritis (stomach infection)';
        referralAdvice =
            'Monitor hydration status. Refer if signs of severe dehydration';
        educationTopics = [
          'Oral Rehydration',
          'Safe Water',
          'Hygiene Practices',
        ];
      } else if (symptoms.contains('fever') &&
          symptoms.contains('headache') &&
          symptoms.contains('body pain')) {
        interpretation = 'Possible malaria or viral infection';
        referralAdvice =
            'Recommend malaria test. Refer to facility for testing and treatment';
        educationTopics = ['Malaria Prevention', 'Use of Mosquito Nets'];
        needsReferral = true;
      } else if (symptoms.contains('abdominal pain') &&
          symptoms.contains('pregnant')) {
        needsReferral = true;
        interpretation = 'Abdominal pain in pregnancy requires evaluation';
        referralAdvice =
            'URGENT: Refer pregnant woman with abdominal pain immediately';
        alertMsg = '⚠️ Pregnant woman with abdominal pain - Refer immediately!';
        alertColor = Colors.red;
      }

      setState(() {
        _aiSymptomInterpretation = interpretation.isEmpty
            ? 'Continue monitoring. Document symptoms and vital signs.'
            : interpretation;
        _aiReferralRecommendation = referralAdvice.isEmpty
            ? 'No immediate referral needed. Continue monitoring.'
            : referralAdvice;
        _aiHealthEducationTopics = educationTopics;
        _showAIAlert = needsReferral || temp > 38.5;
        _aiAlertMessage = alertMsg;
        _aiAlertColor = alertColor;
      });
    } catch (e) {
      print('Error analyzing symptoms: $e');
    } finally {
      setState(() => _isAnalyzingSymptoms = false);
    }
  }

  // IMPORTANT: Preserving exact original save logic for database compatibility
  Future<void> _saveConsultation() async {
    if (!_consultationFormKey.currentState!.validate()) {
      _tabController.animateTo(0);
      return;
    }

    // Validate required IDs
    if (widget.patientId.trim().isEmpty ||
        widget.appointmentId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Missing patient or appointment information'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Completion'),
        content: const Text(
          'Are you sure you want to complete this consultation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      debugPrint('💾 Saving consultation for patient: ${widget.patientId}');
      debugPrint('💾 Appointment ID: ${widget.appointmentId}');
      debugPrint('💾 CHW ID: ${currentUser.uid}');

      // Prepare vital signs summary for legacy field
      final vitalsSummary = [
        if (_temperatureController.text.isNotEmpty)
          'Temp: ${_temperatureController.text}°C',
        if (_bloodPressureController.text.isNotEmpty)
          'BP: ${_bloodPressureController.text}',
        if (_pulseRateController.text.isNotEmpty)
          'Pulse: ${_pulseRateController.text} bpm',
        if (_respiratoryRateController.text.isNotEmpty)
          'RR: ${_respiratoryRateController.text}',
        if (_weightController.text.isNotEmpty)
          'Weight: ${_weightController.text} kg',
        if (_heightController.text.isNotEmpty)
          'Height: ${_heightController.text} cm',
      ].join(', ');

      // Update legacy controllers for backward compatibility
      _vitalsController.text = vitalsSummary;
      _diagnosisController.text = _aiSymptomInterpretation;
      _treatmentController.text = _aiReferralRecommendation.isEmpty
          ? _healthEducationController.text.trim()
          : _aiReferralRecommendation;

      // EXACT ORIGINAL DATA STRUCTURE - DO NOT MODIFY
      final healthRecordData = {
        'appointmentId': widget.appointmentId,
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'chwId': currentUser.uid,
        'symptoms': _symptomsController.text.trim(),
        'diagnosis': _diagnosisController.text.trim(),
        'treatment': _treatmentController.text.trim(),
        'vitals': _vitalsController.text.trim(),
        'notes': _notesController.text.trim(),
        'prescriptions': [], // Empty - CHWs don't prescribe
        'labRequests': [], // Empty - CHWs don't order labs
        'consultationDate': DateTime.now().toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed',
        'statusFlag': 'completed',
        // Additional CHW-specific fields (won't break existing structure)
        'chiefComplaint': _selectedChiefComplaint == 'Other (specify below)'
            ? _chiefComplaintController.text.trim()
            : (_selectedChiefComplaint ??
                  _chiefComplaintController.text.trim()),
        'vitalSigns': {
          'temperature': _temperatureController.text.trim(),
          'bloodPressure': _bloodPressureController.text.trim(),
          'pulseRate': _pulseRateController.text.trim(),
          'respiratoryRate': _respiratoryRateController.text.trim(),
          'weight': _weightController.text.trim(),
          'height': _heightController.text.trim(),
        },
        'aiAnalysis': {
          'symptomInterpretation': _aiSymptomInterpretation,
          'referralRecommendation': _aiReferralRecommendation,
          'healthEducationTopics': _aiHealthEducationTopics,
        },
        'healthEducation': _healthEducationController.text.trim(),
        'counselingNotes': _counselingNotesController.text.trim(),
        'birthPreparedness': _birthPreparednessController.text.trim(),
        'followUpAdvice': _followUpAdviceController.text.trim(),
      };

      // EXACT ORIGINAL SAVE CALL - DO NOT MODIFY
      await HealthRecordsService.saveCHWConsultation(
        patientUid: widget.patientId,
        chwUid: currentUser.uid,
        chwName: 'Community Health Worker',
        consultationData: healthRecordData,
      );

      // Create automatic referral if AI recommends it
      if (_showAIAlert &&
          _aiReferralRecommendation.toLowerCase().contains('urgent')) {
        try {
          await FirebaseFirestore.instance.collection('referrals').add({
            'patientId': widget.patientId,
            'patientName': widget.patientName,
            'referredBy': currentUser.uid,
            'referrerType': 'chw',
            'reason': _aiReferralRecommendation,
            'symptoms': _symptomsController.text.trim(),
            'vitalSigns': healthRecordData['vitalSigns'],
            'urgency': 'high',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Error creating automatic referral: $e');
        }
      }

      final appointmentUpdate = {
        ...widget.appointmentData,
        'appointmentId': widget.appointmentId,
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'chwId': currentUser.uid,
        'status': 'completed',
        'statusFlag': 'completed',
        'consultationCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .set(appointmentUpdate, SetOptions(merge: true));

      // EXACT ORIGINAL NOTIFICATION LOGIC - DO NOT MODIFY
      try {
        if (_vitalsController.text.trim().isNotEmpty) {
          await CHWMessageHelper.sendHealthRecordUpdateToPatient(
            widget.patientId,
            'vitals',
            _vitalsController.text.trim(),
          );
        }
        // Note: Not sending prescription/lab notifications since lists are empty
      } catch (e) {
        debugPrint('Error sending health record update to patient: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consultation completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      context.pop();
    } catch (e) {
      debugPrint('Error saving consultation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving consultation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CHW Consultation - ${widget.patientName}'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/chw_dashboard/patients'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () => context.go('/chw_dashboard/profile'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.monitor_heart), text: 'Patient Assessment'),
            Tab(icon: Icon(Icons.school), text: 'Education & Counseling'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPatientAssessmentTab(),
          _buildEducationCounselingTab(),
        ],
      ),
      bottomNavigationBar: widget.isReadOnly
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: widget.isReadOnly || _isLoading
                    ? null
                    : _saveConsultation,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: const Text('Complete Consultation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
    );
  }

  Widget _buildPatientAssessmentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _consultationFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Info Card
            Card(
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient: ${widget.patientName}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Appointment ID: ${widget.appointmentId}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // AI Alert Card
            if (_showAIAlert)
              Card(
                color: _aiAlertColor.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: _aiAlertColor, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _aiAlertMessage,
                          style: TextStyle(
                            color: _aiAlertColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_showAIAlert) const SizedBox(height: 16),

            // Chief Complaint - Dropdown
            DropdownButtonFormField<String>(
              value: _selectedChiefComplaint,
              decoration: InputDecoration(
                labelText: 'Chief Complaint *',
                hintText: 'Select the main reason for this visit',
                prefixIcon: const Icon(Icons.medical_information),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              isExpanded: true,
              items: _commonChiefComplaints.map((complaint) {
                return DropdownMenuItem<String>(
                  value: complaint,
                  child: Text(complaint),
                );
              }).toList(),
              onChanged: widget.isReadOnly
                  ? null
                  : (value) {
                      setState(() {
                        _selectedChiefComplaint = value;
                        // Always update the controller
                        if (value == 'Other (specify below)') {
                          _chiefComplaintController
                              .clear(); // Clear for manual entry
                        } else {
                          _chiefComplaintController.text = value ?? '';
                        }
                      });
                    },
              validator: (value) =>
                  value == null ? 'Please select chief complaint' : null,
            ),
            const SizedBox(height: 16),

            // Additional details field if "Other" is selected
            if (_selectedChiefComplaint == 'Other (specify below)')
              Column(
                children: [
                  TextFormField(
                    controller: _chiefComplaintController,
                    enabled: !widget.isReadOnly,
                    decoration: InputDecoration(
                      labelText: 'Specify Chief Complaint *',
                      hintText: 'Please describe the main complaint...',
                      prefixIcon: const Icon(Icons.edit),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 2,
                    validator: (value) => value?.trim().isEmpty ?? true
                        ? 'Please specify the chief complaint'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Symptoms
            const Text(
              'Symptoms',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonSymptoms.map((symptom) {
                return ActionChip(
                  label: Text(symptom),
                  onPressed: widget.isReadOnly
                      ? null
                      : () {
                          final currentText = _symptomsController.text.trim();
                          if (currentText.isEmpty) {
                            _symptomsController.text = symptom;
                          } else if (!currentText.contains(symptom)) {
                            _symptomsController.text = '$currentText, $symptom';
                          }
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _symptomsController,
              enabled: !widget.isReadOnly,
              decoration: InputDecoration(
                labelText: 'Detailed Symptoms *',
                hintText: 'Describe all symptoms in detail...',
                prefixIcon: const Icon(Icons.sick),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: _isAnalyzingSymptoms
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.psychology, color: Colors.teal),
                  onPressed: widget.isReadOnly || _isAnalyzingSymptoms
                      ? null
                      : _analyzeSymptoms,
                  tooltip: 'Analyze with AI',
                ),
              ),
              maxLines: 3,
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Vital Signs
            Text(
              'Vital Signs',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _temperatureController,
                    enabled: !widget.isReadOnly,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Temperature (°C)',
                      prefixIcon: const Icon(Icons.thermostat),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) => _analyzeSymptoms(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _bloodPressureController,
                    enabled: !widget.isReadOnly,
                    decoration: InputDecoration(
                      labelText: 'Blood Pressure',
                      hintText: '120/80',
                      prefixIcon: const Icon(Icons.favorite),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) => _analyzeSymptoms(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _pulseRateController,
                    enabled: !widget.isReadOnly,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Pulse (bpm)',
                      prefixIcon: const Icon(Icons.monitor_heart),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _respiratoryRateController,
                    enabled: !widget.isReadOnly,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Respiratory Rate',
                      prefixIcon: const Icon(Icons.air),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    enabled: !widget.isReadOnly,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Weight (kg)',
                      prefixIcon: const Icon(Icons.monitor_weight),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _heightController,
                    enabled: !widget.isReadOnly,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Height (cm)',
                      prefixIcon: const Icon(Icons.height),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // AI Symptom Interpretation
            if (_aiSymptomInterpretation.isNotEmpty)
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.psychology, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'AI Analysis',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _aiSymptomInterpretation,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            if (_aiSymptomInterpretation.isNotEmpty) const SizedBox(height: 16),

            // AI Referral Recommendation
            if (_aiReferralRecommendation.isNotEmpty)
              Card(
                color:
                    _aiReferralRecommendation.toLowerCase().contains('urgent')
                    ? Colors.red.shade50
                    : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_hospital,
                            color:
                                _aiReferralRecommendation
                                    .toLowerCase()
                                    .contains('urgent')
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Referral Recommendation',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _aiReferralRecommendation,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              _aiReferralRecommendation.toLowerCase().contains(
                                'urgent',
                              )
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_aiReferralRecommendation.isNotEmpty)
              const SizedBox(height: 16),

            // Additional Notes
            TextFormField(
              controller: _notesController,
              enabled: !widget.isReadOnly,
              decoration: InputDecoration(
                labelText: 'Additional Notes',
                hintText: 'Any other observations or concerns...',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationCounselingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Health Education
          const Text(
            'Health Education',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (_aiHealthEducationTopics.isNotEmpty) ...[
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'AI Suggested Topics',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _aiHealthEducationTopics.map((topic) {
                        return Chip(
                          label: Text(topic),
                          backgroundColor: Colors.green.shade100,
                          avatar: Icon(
                            Icons.check_circle,
                            color: Colors.green.shade700,
                            size: 18,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          const Text(
            'Common Health Topics',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _healthEducationTopics.map((topic) {
              return ActionChip(
                label: Text(topic),
                onPressed: widget.isReadOnly
                    ? null
                    : () {
                        final currentText = _healthEducationController.text
                            .trim();
                        if (currentText.isEmpty) {
                          _healthEducationController.text = '• $topic: ';
                        } else {
                          _healthEducationController.text =
                              '$currentText\n• $topic: ';
                        }
                      },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _healthEducationController,
            enabled: !widget.isReadOnly,
            decoration: InputDecoration(
              labelText: 'Health Education Provided',
              hintText: 'Document health topics discussed with patient...',
              prefixIcon: const Icon(Icons.school),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 20),

          // Counseling
          const Text(
            'Counseling Notes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _counselingNotesController,
            enabled: !widget.isReadOnly,
            decoration: InputDecoration(
              labelText: 'Counseling Provided',
              hintText: 'Document counseling and patient concerns addressed...',
              prefixIcon: const Icon(Icons.psychology),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 20),

          // Birth Preparedness
          const Text(
            'Birth Preparedness',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete for pregnant patients',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _birthPreparednessController,
            enabled: !widget.isReadOnly,
            decoration: InputDecoration(
              labelText: 'Birth Preparedness Plan',
              hintText: 'Birth plan, danger signs, facility preparedness...',
              prefixIcon: const Icon(Icons.pregnant_woman),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 20),

          // Follow-up Advice
          const Text(
            'Follow-up Advice',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _followUpAdviceController,
            enabled: !widget.isReadOnly,
            decoration: InputDecoration(
              labelText: 'Follow-up Instructions',
              hintText: 'When to return, warning signs to watch for...',
              prefixIcon: const Icon(Icons.event_repeat),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}
