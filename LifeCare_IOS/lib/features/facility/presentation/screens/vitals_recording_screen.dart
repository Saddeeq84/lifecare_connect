import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class VitalsRecordingScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String facilityId;

  const VitalsRecordingScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.facilityId,
  });

  @override
  State<VitalsRecordingScreen> createState() => _VitalsRecordingScreenState();
}

class _VitalsRecordingScreenState extends State<VitalsRecordingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bpSystolicController = TextEditingController();
  final _bpDiastolicController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _pulseController = TextEditingController();
  final _respiratoryRateController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _bloodGlucoseController = TextEditingController();
  final _notesController = TextEditingController();

  double? _calculatedBMI;
  bool _isLoading = false;

  @override
  void dispose() {
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _temperatureController.dispose();
    _pulseController.dispose();
    _respiratoryRateController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _spo2Controller.dispose();
    _bloodGlucoseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculateBMI() {
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);

    if (weight != null && height != null && height > 0) {
      final heightInMeters = height / 100;
      setState(() {
        _calculatedBMI = weight / (heightInMeters * heightInMeters);
      });
    }
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Future<void> _saveVitals() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final vitalsData = {
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'facilityId': widget.facilityId,
        'department':
            'Nursing Department', // Required for Firestore security rules
        'bloodPressure': {
          'systolic': int.tryParse(_bpSystolicController.text),
          'diastolic': int.tryParse(_bpDiastolicController.text),
        },
        'temperature': double.tryParse(_temperatureController.text),
        'pulse': int.tryParse(_pulseController.text),
        'respiratoryRate': int.tryParse(_respiratoryRateController.text),
        'weight': double.tryParse(_weightController.text),
        'height': double.tryParse(_heightController.text),
        'bmi': _calculatedBMI,
        'bmiCategory': _calculatedBMI != null
            ? _getBMICategory(_calculatedBMI!)
            : null,
        'spo2': int.tryParse(_spo2Controller.text),
        'bloodGlucose': double.tryParse(_bloodGlucoseController.text),
        'notes': _notesController.text.trim(),
        'recordedAt': FieldValue.serverTimestamp(),
        'recordedDate': DateFormat('MMM dd, yyyy - hh:mm a').format(now),
        'recordedDateOnly': DateFormat(
          'yyyy-MM-dd',
        ).format(today), // Date marker for today
        'recordedBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        'recordedByName': 'Nursing Staff', // This should be dynamically set
        'recordedByRole': 'nursing', // Mark as recorded by nursing
        'type': 'VITAL_SIGNS',
        // Additional fields for nursing medical records compatibility
        'systolic': int.tryParse(_bpSystolicController.text),
        'diastolic': int.tryParse(_bpDiastolicController.text),
        'oxygenSaturation': int.tryParse(_spo2Controller.text),
      };

      // Save to health_records collection (primary storage)
      await FirebaseFirestore.instance
          .collection('health_records')
          .add(vitalsData);

      // Also save to vitals_records for backward compatibility
      await FirebaseFirestore.instance
          .collection('vitals_records')
          .add(vitalsData);

      // Also save to patient's medical record
      await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(widget.patientId)
          .collection('vitals')
          .add(vitalsData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vitals recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording vitals: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Vitals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // Navigate to vitals history
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VitalsHistoryScreen(
                    patientId: widget.patientId,
                    patientName: widget.patientName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient: ${widget.patientName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.now())}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Blood Pressure
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Blood Pressure (mmHg)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _bpSystolicController,
                            decoration: const InputDecoration(
                              labelText: 'Systolic',
                              hintText: '120',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _bpDiastolicController,
                            decoration: const InputDecoration(
                              labelText: 'Diastolic',
                              hintText: '80',
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
            ),

            // Temperature
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _temperatureController,
                  decoration: const InputDecoration(
                    labelText: 'Temperature (°C)',
                    hintText: '36.5',
                    border: OutlineInputBorder(),
                    suffixText: '°C',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ),

            // Pulse
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _pulseController,
                  decoration: const InputDecoration(
                    labelText: 'Pulse (bpm)',
                    hintText: '72',
                    border: OutlineInputBorder(),
                    suffixText: 'bpm',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ),

            // Respiratory Rate
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _respiratoryRateController,
                  decoration: const InputDecoration(
                    labelText: 'Respiratory Rate (breaths/min)',
                    hintText: '16',
                    border: OutlineInputBorder(),
                    suffixText: '/min',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ),

            // Weight and Height with BMI
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Anthropometry',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            decoration: const InputDecoration(
                              labelText: 'Weight (kg)',
                              hintText: '70',
                              border: OutlineInputBorder(),
                              suffixText: 'kg',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => _calculateBMI(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            decoration: const InputDecoration(
                              labelText: 'Height (cm)',
                              hintText: '170',
                              border: OutlineInputBorder(),
                              suffixText: 'cm',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => _calculateBMI(),
                          ),
                        ),
                      ],
                    ),
                    if (_calculatedBMI != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'BMI: ${_calculatedBMI!.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getBMICategory(_calculatedBMI!),
                              style: TextStyle(
                                color:
                                    _calculatedBMI! < 18.5 ||
                                        _calculatedBMI! >= 25
                                    ? Colors.orange
                                    : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // SpO2
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _spo2Controller,
                  decoration: const InputDecoration(
                    labelText: 'SpO2 (%)',
                    hintText: '98',
                    border: OutlineInputBorder(),
                    suffixText: '%',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ),

            // Blood Glucose
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _bloodGlucoseController,
                  decoration: const InputDecoration(
                    labelText: 'Blood Glucose (mmol/L)',
                    hintText: '5.5',
                    border: OutlineInputBorder(),
                    suffixText: 'mmol/L',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ),

            // Notes
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Additional observations...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveVitals,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Vitals', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// Vitals History Screen
class VitalsHistoryScreen extends StatelessWidget {
  final String patientId;
  final String patientName;

  const VitalsHistoryScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vitals History')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('facility_patients')
            .doc(patientId)
            .collection('vitals')
            .orderBy('recordedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No vitals records found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final timestamp = data['recordedAt'] as Timestamp?;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timestamp != null
                            ? DateFormat(
                                'MMM dd, yyyy - hh:mm a',
                              ).format(timestamp.toDate())
                            : 'Date not available',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Divider(height: 16),
                      _buildVitalRow(
                        'BP',
                        data['bloodPressure'] != null
                            ? '${data['bloodPressure']['systolic']}/${data['bloodPressure']['diastolic']} mmHg'
                            : '-',
                      ),
                      _buildVitalRow(
                        'Temperature',
                        data['temperature'] != null
                            ? '${data['temperature']}°C'
                            : '-',
                      ),
                      _buildVitalRow(
                        'Pulse',
                        data['pulse'] != null ? '${data['pulse']} bpm' : '-',
                      ),
                      _buildVitalRow(
                        'RR',
                        data['respiratoryRate'] != null
                            ? '${data['respiratoryRate']}/min'
                            : '-',
                      ),
                      _buildVitalRow(
                        'Weight',
                        data['weight'] != null ? '${data['weight']} kg' : '-',
                      ),
                      _buildVitalRow(
                        'Height',
                        data['height'] != null ? '${data['height']} cm' : '-',
                      ),
                      if (data['bmi'] != null)
                        _buildVitalRow(
                          'BMI',
                          '${data['bmi'].toStringAsFixed(1)} (${data['bmiCategory']})',
                        ),
                      if (data['spo2'] != null)
                        _buildVitalRow('SpO2', '${data['spo2']}%'),
                      if (data['bloodGlucose'] != null)
                        _buildVitalRow(
                          'Blood Glucose',
                          '${data['bloodGlucose']} mmol/L',
                        ),
                      if (data['notes'] != null &&
                          data['notes'].toString().isNotEmpty) ...[
                        const Divider(height: 16),
                        Text(
                          'Notes: ${data['notes']}',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildVitalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }
}
