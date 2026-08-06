import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WardVitalSignsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final bool excludeEmergencyAdmissions;
  final bool filterByEmergency;

  const WardVitalSignsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    this.excludeEmergencyAdmissions = false,
    this.filterByEmergency = false,
  });

  @override
  State<WardVitalSignsScreen> createState() => _WardVitalSignsScreenState();
}

class _WardVitalSignsScreenState extends State<WardVitalSignsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _temperatureController = TextEditingController();
  final _pulseController = TextEditingController();
  final _respiratoryRateController = TextEditingController();
  final _bloodPressureSystolicController = TextEditingController();
  final _bloodPressureDiastolicController = TextEditingController();
  final _oxygenSaturationController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedAdmissionId;
  DateTime _selectedDateTime = DateTime.now();

  bool _isLoading = false;

  @override
  void dispose() {
    _temperatureController.dispose();
    _pulseController.dispose();
    _respiratoryRateController.dispose();
    _bloodPressureSystolicController.dispose();
    _bloodPressureDiastolicController.dispose();
    _oxygenSaturationController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveVitalSigns() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAdmissionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save vital signs
      await FirebaseFirestore.instance
          .collection('admissions')
          .doc(_selectedAdmissionId)
          .collection('vital_signs')
          .add({
            'temperature': _temperatureController.text.trim(),
            'pulse': _pulseController.text.trim(),
            'respiratoryRate': _respiratoryRateController.text.trim(),
            'bloodPressureSystolic': _bloodPressureSystolicController.text
                .trim(),
            'bloodPressureDiastolic': _bloodPressureDiastolicController.text
                .trim(),
            'oxygenSaturation': _oxygenSaturationController.text.trim(),
            'weight': _weightController.text.trim(),
            'notes': _notesController.text.trim(),
            'recordedBy': widget.staffId,
            'recordedByName': widget.staffName,
            'recordedAt': Timestamp.fromDate(_selectedDateTime),
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vital signs recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _temperatureController.clear();
        _pulseController.clear();
        _respiratoryRateController.clear();
        _bloodPressureSystolicController.clear();
        _bloodPressureDiastolicController.clear();
        _oxygenSaturationController.clear();
        _weightController.clear();
        _notesController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording vital signs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vital Signs'),
        backgroundColor: Colors.purple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade400, Colors.purple.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Record Vital Signs',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.facilityName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Patient Selection
            StreamBuilder<QuerySnapshot>(
              stream: widget.filterByEmergency
                  ? FirebaseFirestore.instance
                        .collection('admissions')
                        .where('facilityId', isEqualTo: widget.facilityId)
                        .where('status', isEqualTo: 'admitted')
                        .where('admissionType', isEqualTo: 'emergency')
                        .snapshots()
                  : widget.excludeEmergencyAdmissions
                  ? FirebaseFirestore.instance
                        .collection('admissions')
                        .where('facilityId', isEqualTo: widget.facilityId)
                        .where('status', isEqualTo: 'admitted')
                        .where('admissionType', isNotEqualTo: 'emergency')
                        .snapshots()
                  : FirebaseFirestore.instance
                        .collection('admissions')
                        .where('facilityId', isEqualTo: widget.facilityId)
                        .where('status', isEqualTo: 'admitted')
                        .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final admissions = snapshot.data!.docs;

                if (admissions.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No admitted patients',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
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
                          value: _selectedAdmissionId,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          hint: const Text('Choose patient'),
                          items: admissions.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final patientName =
                                data['patientName'] ?? 'Unknown';
                            final ward = data['ward'] ?? 'N/A';
                            final bed = data['bed'] ?? 'N/A';

                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    patientName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Ward: $ward | Bed: $bed',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedAdmissionId = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Vital Signs Form
            if (_selectedAdmissionId != null) ...[
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date & Time
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Date & Time *',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: _selectDateTime,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  DateFormat(
                                    'MMM dd, yyyy - hh:mm a',
                                  ).format(_selectedDateTime),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Vital Signs Inputs
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vital Signs',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Temperature
                            TextFormField(
                              controller: _temperatureController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Temperature (°C)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.thermostat),
                                hintText: 'e.g., 37.5',
                              ),
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final temp = double.tryParse(value);
                                  if (temp == null || temp < 30 || temp > 45) {
                                    return 'Enter a valid temperature (30-45°C)';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Pulse
                            TextFormField(
                              controller: _pulseController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Pulse (bpm)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.monitor_heart),
                                hintText: 'e.g., 72',
                              ),
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final pulse = int.tryParse(value);
                                  if (pulse == null ||
                                      pulse < 30 ||
                                      pulse > 200) {
                                    return 'Enter a valid pulse (30-200 bpm)';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Respiratory Rate
                            TextFormField(
                              controller: _respiratoryRateController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Respiratory Rate (breaths/min)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.air),
                                hintText: 'e.g., 16',
                              ),
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final rate = int.tryParse(value);
                                  if (rate == null || rate < 8 || rate > 60) {
                                    return 'Enter a valid rate (8-60)';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Blood Pressure
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller:
                                        _bloodPressureSystolicController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'BP Systolic',
                                      border: OutlineInputBorder(),
                                      hintText: '120',
                                    ),
                                    validator: (value) {
                                      if (value != null && value.isNotEmpty) {
                                        final bp = int.tryParse(value);
                                        if (bp == null || bp < 60 || bp > 250) {
                                          return 'Invalid (60-250)';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('/', style: TextStyle(fontSize: 24)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller:
                                        _bloodPressureDiastolicController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'BP Diastolic',
                                      border: OutlineInputBorder(),
                                      hintText: '80',
                                    ),
                                    validator: (value) {
                                      if (value != null && value.isNotEmpty) {
                                        final bp = int.tryParse(value);
                                        if (bp == null || bp < 40 || bp > 150) {
                                          return 'Invalid (40-150)';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Oxygen Saturation
                            TextFormField(
                              controller: _oxygenSaturationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Oxygen Saturation (%)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.bloodtype),
                                hintText: 'e.g., 98',
                              ),
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final spo2 = int.tryParse(value);
                                  if (spo2 == null || spo2 < 70 || spo2 > 100) {
                                    return 'Enter a valid SpO2 (70-100%)';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Weight
                            TextFormField(
                              controller: _weightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Weight (kg)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.monitor_weight),
                                hintText: 'e.g., 70',
                              ),
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final weight = double.tryParse(value);
                                  if (weight == null ||
                                      weight < 0 ||
                                      weight > 300) {
                                    return 'Enter a valid weight (0-300 kg)';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Any additional observations...',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveVitalSigns,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Record Vital Signs',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
