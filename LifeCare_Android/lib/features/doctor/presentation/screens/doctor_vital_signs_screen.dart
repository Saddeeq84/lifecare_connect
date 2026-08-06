import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DoctorVitalSignsScreen extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const DoctorVitalSignsScreen({super.key, required this.appointment});

  @override
  State<DoctorVitalSignsScreen> createState() => _DoctorVitalSignsScreenState();
}

class _DoctorVitalSignsScreenState extends State<DoctorVitalSignsScreen> {
  bool _isChecking = true;
  Map<String, dynamic>? _existingVitals;

  @override
  void initState() {
    super.initState();
    _checkExistingVitals();
  }

  Future<void> _checkExistingVitals() async {
    try {
      final patientId = widget.appointment['patientId'];
      if (patientId == null) {
        setState(() => _isChecking = false);
        return;
      }

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final vitalsQuery = await FirebaseFirestore.instance
          .collection('health_records')
          .where('patientId', isEqualTo: patientId)
          .where('type', isEqualTo: 'VITAL_SIGNS')
          .where('recordedDateOnly', isEqualTo: today)
          .limit(1)
          .get();

      if (vitalsQuery.docs.isNotEmpty) {
        setState(() {
          _existingVitals = vitalsQuery.docs.first.data();
          _isChecking = false;
        });
      } else {
        setState(() => _isChecking = false);
      }
    } catch (e) {
      print('Error checking existing vitals: \$e');
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _existingVitals != null ? 'View Vital Signs' : 'Vital Signs',
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isChecking
          ? const Center(child: CircularProgressIndicator())
          : _existingVitals != null
          ? _buildExistingVitalsView()
          : _buildNoVitalsView(),
    );
  }

  Widget _buildExistingVitalsView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.blue.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vital Signs Already Recorded',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This patient\'s vitals have been recorded today. No duplicate entry needed.',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient: ${widget.appointment['patientName'] ?? 'Unknown Patient'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Recorded by: ${_existingVitals!['recordedByRole'] == 'nursing' ? 'Nursing Staff' : 'Doctor'}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _existingVitals!['recordedDate'] ?? 'N/A',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Vital Signs',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildVitalCard(
          'Blood Pressure',
          '${_existingVitals!['bloodPressure']?['systolic'] ?? 'N/A'}/${_existingVitals!['bloodPressure']?['diastolic'] ?? 'N/A'} mmHg',
          Icons.favorite,
          Colors.red,
        ),
        _buildVitalCard(
          'Temperature',
          '${_existingVitals!['temperature'] ?? 'N/A'} °C',
          Icons.thermostat,
          Colors.orange,
        ),
        _buildVitalCard(
          'Pulse',
          '${_existingVitals!['pulse'] ?? 'N/A'} bpm',
          Icons.monitor_heart,
          Colors.pink,
        ),
        _buildVitalCard(
          'Respiratory Rate',
          '${_existingVitals!['respiratoryRate'] ?? 'N/A'} /min',
          Icons.air,
          Colors.blue,
        ),
        _buildVitalCard(
          'SpO2',
          '${_existingVitals!['spo2'] ?? 'N/A'} %',
          Icons.opacity,
          Colors.cyan,
        ),
        _buildVitalCard(
          'Weight',
          '${_existingVitals!['weight'] ?? 'N/A'} kg',
          Icons.monitor_weight,
          Colors.purple,
        ),
        _buildVitalCard(
          'Height',
          '${_existingVitals!['height'] ?? 'N/A'} cm',
          Icons.height,
          Colors.indigo,
        ),
        if (_existingVitals!['bmi'] != null)
          _buildVitalCard(
            'BMI',
            '${_existingVitals!['bmi']?.toStringAsFixed(1)} - ${_existingVitals!['bmiCategory']}',
            Icons.calculate,
            Colors.teal,
          ),
        if (_existingVitals!['bloodGlucose'] != null)
          _buildVitalCard(
            'Blood Glucose',
            '${_existingVitals!['bloodGlucose']} mg/dL',
            Icons.bloodtype,
            Colors.deepOrange,
          ),
        if (_existingVitals!['notes'] != null &&
            _existingVitals!['notes'].toString().isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Clinical Notes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_existingVitals!['notes'].toString()),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVitalCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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

  Widget _buildNoVitalsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Vital Signs Recorded Today',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This patient does not have vital signs recorded for today.\n\nPlease ask nursing staff to record vitals first.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
