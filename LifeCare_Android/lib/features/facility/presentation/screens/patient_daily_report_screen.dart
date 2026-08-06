import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PatientDailyReportScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const PatientDailyReportScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<PatientDailyReportScreen> createState() =>
      _PatientDailyReportScreenState();
}

class _PatientDailyReportScreenState extends State<PatientDailyReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _admittedPatients = [];
  String? _selectedPatientId;

  @override
  void initState() {
    super.initState();
    _loadAdmittedPatients();
  }

  Future<void> _loadAdmittedPatients() async {
    setState(() => _isLoading = true);

    try {
      // Query admitted patients from admissions collection (same as ward medications)
      final snapshot = await FirebaseFirestore.instance
          .collection('admissions')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'admitted')
          .get();

      _admittedPatients = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'patientId': data['patientId'],
          'name': data['patientName'],
          'wardId': data['wardId'],
          'wardName': data['ward'],
          'bedNumber': data['bed'],
          'admittedAt': data['admissionDate'],
          ...data,
        };
      }).toList();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading patients: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createDailyReport(Map<String, dynamic> patient) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDailyReportForm(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          staffName: widget.staffName,
          patientId: patient['patientId'] as String,
          patientName: patient['name'] as String,
          wardId: patient['wardId'] as String?,
          bedNumber: patient['bedNumber'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Daily Reports'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Card(
                    color: Colors.deepOrange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.description,
                            color: Colors.deepOrange,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '24-Hour Nursing Report',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Select patient to create daily report',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Patient Selection
                  if (_admittedPatients.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No admitted patients',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Patient *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedPatientId,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          isExpanded: true,
                          hint: const Text('Choose a patient to create report'),
                          items: _admittedPatients.map((patient) {
                            return DropdownMenuItem<String>(
                              value: patient['id'] as String,
                              child: Text(
                                '${patient['name']} (Ward: ${patient['wardName'] ?? 'N/A'}, Bed: ${patient['bedNumber'] ?? 'N/A'})',
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedPatientId = value);
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _selectedPatientId == null
                                ? null
                                : () {
                                    final patient = _admittedPatients
                                        .firstWhere(
                                          (p) => p['id'] == _selectedPatientId,
                                        );
                                    _createDailyReport(patient);
                                  },
                            icon: const Icon(Icons.add_circle),
                            label: const Text(
                              'Create Daily Report',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

// Patient Daily Report Form
class PatientDailyReportForm extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final String patientId;
  final String patientName;
  final String? wardId;
  final String? bedNumber;

  const PatientDailyReportForm({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    required this.patientId,
    required this.patientName,
    this.wardId,
    this.bedNumber,
  });

  @override
  State<PatientDailyReportForm> createState() => _PatientDailyReportFormState();
}

class _PatientDailyReportFormState extends State<PatientDailyReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _chiefComplaintsController = TextEditingController();
  final _assessmentController = TextEditingController();
  final _interventionsController = TextEditingController();
  final _evaluationController = TextEditingController();
  final _planController = TextEditingController();
  final _vitalSignsController = TextEditingController();
  final _intakeOutputController = TextEditingController();
  final _painScoreController = TextEditingController();

  String _consciousnessLevel = 'Alert';
  String _respiratoryStatus = 'Normal';
  String _cardiovascularStatus = 'Stable';
  String _mobilityStatus = 'Ambulating';
  String _skinIntegrity = 'Intact';
  bool _isSaving = false;

  DateTime _reportDate = DateTime.now();
  String _shift = 'Day Shift (7AM-3PM)';

  @override
  void dispose() {
    _chiefComplaintsController.dispose();
    _assessmentController.dispose();
    _interventionsController.dispose();
    _evaluationController.dispose();
    _planController.dispose();
    _vitalSignsController.dispose();
    _intakeOutputController.dispose();
    _painScoreController.dispose();
    super.dispose();
  }

  Future<void> _saveReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final reportData = {
        'facilityId': widget.facilityId,
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'wardId': widget.wardId,
        'bedNumber': widget.bedNumber,
        'reportDate': Timestamp.fromDate(_reportDate),
        'shift': _shift,
        'reportedBy': widget.staffName,
        'reportedById': widget.staffId,

        // Subjective Data
        'chiefComplaints': _chiefComplaintsController.text.trim(),
        'painScore': _painScoreController.text.trim(),

        // Objective Data
        'vitalSigns': _vitalSignsController.text.trim(),
        'consciousnessLevel': _consciousnessLevel,
        'respiratoryStatus': _respiratoryStatus,
        'cardiovascularStatus': _cardiovascularStatus,
        'mobilityStatus': _mobilityStatus,
        'skinIntegrity': _skinIntegrity,

        // Intake and Output
        'intakeOutput': _intakeOutputController.text.trim(),

        // Assessment
        'nursingAssessment': _assessmentController.text.trim(),

        // Interventions
        'interventions': _interventionsController.text.trim(),

        // Evaluation
        'evaluation': _evaluationController.text.trim(),

        // Plan
        'plan': _planController.text.trim(),

        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save report to patient_daily_reports collection
      final reportRef = await FirebaseFirestore.instance
          .collection('patient_daily_reports')
          .add(reportData);

      // Also save to admissions subcollection for easy tracking
      await FirebaseFirestore.instance
          .collection('admissions')
          .doc(widget.patientId)
          .collection('daily_reports')
          .doc(reportRef.id)
          .set({
            'reportId': reportRef.id,
            'reportDate': Timestamp.fromDate(_reportDate),
            'shift': _shift,
            'reportedBy': widget.staffName,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily report saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('24-Hour Nursing Report'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Patient Info Card
            Card(
              color: Colors.deepOrange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.deepOrange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.patientName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ward: ${widget.wardId ?? 'N/A'} • Bed: ${widget.bedNumber ?? 'N/A'}',
                      style: TextStyle(color: Colors.deepOrange.shade700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Report Date and Shift
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Report Date'),
                    subtitle: Text(
                      DateFormat('MMM dd, yyyy').format(_reportDate),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _reportDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 7),
                        ),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _reportDate = date);
                      }
                    },
                  ),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              value: _shift,
              decoration: const InputDecoration(
                labelText: 'Shift',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Day Shift (7AM-3PM)',
                  child: Text('Day Shift (7AM-3PM)'),
                ),
                DropdownMenuItem(
                  value: 'Evening Shift (3PM-11PM)',
                  child: Text('Evening Shift (3PM-11PM)'),
                ),
                DropdownMenuItem(
                  value: 'Night Shift (11PM-7AM)',
                  child: Text('Night Shift (11PM-7AM)'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _shift = value);
              },
            ),
            const SizedBox(height: 24),

            // SUBJECTIVE DATA
            _buildSectionHeader('SUBJECTIVE DATA', Icons.chat),
            _buildTextField(
              controller: _chiefComplaintsController,
              label: 'Chief Complaints / Patient Concerns',
              hint: 'What is the patient reporting?',
              maxLines: 3,
            ),
            _buildTextField(
              controller: _painScoreController,
              label: 'Pain Assessment (0-10 scale)',
              hint: 'Pain score and location',
            ),
            const SizedBox(height: 24),

            // OBJECTIVE DATA
            _buildSectionHeader('OBJECTIVE DATA', Icons.monitor_heart),
            _buildTextField(
              controller: _vitalSignsController,
              label: 'Vital Signs',
              hint: 'BP, HR, RR, Temp, SpO2',
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please record vital signs';
                }
                return null;
              },
            ),
            _buildDropdownField(
              label: 'Level of Consciousness',
              value: _consciousnessLevel,
              items: ['Alert', 'Lethargic', 'Confused', 'Unresponsive'],
              onChanged: (value) =>
                  setState(() => _consciousnessLevel = value!),
            ),
            _buildDropdownField(
              label: 'Respiratory Status',
              value: _respiratoryStatus,
              items: ['Normal', 'Labored', 'On Oxygen', 'Dyspneic'],
              onChanged: (value) => setState(() => _respiratoryStatus = value!),
            ),
            _buildDropdownField(
              label: 'Cardiovascular Status',
              value: _cardiovascularStatus,
              items: ['Stable', 'Tachycardic', 'Bradycardic', 'Arrhythmic'],
              onChanged: (value) =>
                  setState(() => _cardiovascularStatus = value!),
            ),
            _buildDropdownField(
              label: 'Mobility Status',
              value: _mobilityStatus,
              items: [
                'Ambulating',
                'Assisted Ambulation',
                'Bed Rest',
                'Immobile',
              ],
              onChanged: (value) => setState(() => _mobilityStatus = value!),
            ),
            _buildDropdownField(
              label: 'Skin Integrity',
              value: _skinIntegrity,
              items: ['Intact', 'Redness', 'Pressure Sore', 'Wound Present'],
              onChanged: (value) => setState(() => _skinIntegrity = value!),
            ),
            _buildTextField(
              controller: _intakeOutputController,
              label: 'Intake & Output (24 hours)',
              hint: 'Total intake (ml) vs. output (ml)',
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // ASSESSMENT
            _buildSectionHeader('NURSING ASSESSMENT', Icons.assessment),
            _buildTextField(
              controller: _assessmentController,
              label: 'Assessment / Nursing Diagnosis',
              hint: 'Your professional assessment of patient condition',
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please provide nursing assessment';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // INTERVENTIONS
            _buildSectionHeader('INTERVENTIONS', Icons.medical_services),
            _buildTextField(
              controller: _interventionsController,
              label: 'Nursing Interventions Provided',
              hint: 'Medications given, procedures performed, care provided',
              maxLines: 5,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please document interventions';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // EVALUATION
            _buildSectionHeader('EVALUATION', Icons.check_circle),
            _buildTextField(
              controller: _evaluationController,
              label: 'Patient Response / Evaluation',
              hint: 'How did patient respond to interventions?',
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // PLAN
            _buildSectionHeader('PLAN', Icons.schedule),
            _buildTextField(
              controller: _planController,
              label: 'Plan of Care for Next 24 Hours',
              hint: 'Continued monitoring, medications, tests, procedures',
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please document plan of care';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Save Button
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveReport,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepOrange),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
