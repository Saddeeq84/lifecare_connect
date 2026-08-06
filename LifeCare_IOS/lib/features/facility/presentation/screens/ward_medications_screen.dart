import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WardMedicationsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final bool excludeEmergencyAdmissions;
  final bool filterByEmergency;

  const WardMedicationsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    this.excludeEmergencyAdmissions = false,
    this.filterByEmergency = false,
  });

  @override
  State<WardMedicationsScreen> createState() => _WardMedicationsScreenState();
}

class _WardMedicationsScreenState extends State<WardMedicationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicationNameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _routeController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedAdmissionId;
  String _frequency = 'once_daily';
  DateTime _selectedDateTime = DateTime.now();

  bool _isLoading = false;

  @override
  void dispose() {
    _medicationNameController.dispose();
    _dosageController.dispose();
    _routeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _recordMedication() async {
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
      // Save medication record
      await FirebaseFirestore.instance
          .collection('admissions')
          .doc(_selectedAdmissionId)
          .collection('medications')
          .add({
            'medicationName': _medicationNameController.text.trim(),
            'dosage': _dosageController.text.trim(),
            'route': _routeController.text.trim(),
            'frequency': _frequency,
            'notes': _notesController.text.trim(),
            'administeredBy': widget.staffId,
            'administeredByName': widget.staffName,
            'administeredAt': Timestamp.fromDate(_selectedDateTime),
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medication recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _medicationNameController.clear();
        _dosageController.clear();
        _routeController.clear();
        _notesController.clear();
        setState(() {
          _frequency = 'once_daily';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording medication: $e'),
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
        title: const Text('Medication Administration'),
        backgroundColor: Colors.indigo,
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
                  colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medication, color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Medication Administration',
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
                          isExpanded: true,
                          hint: const Text('Choose patient'),
                          items: admissions.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final patientName =
                                data['patientName'] ?? 'Unknown';
                            final ward = data['ward'] ?? 'N/A';
                            final bed = data['bed'] ?? 'N/A';

                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(
                                '$patientName (Ward: $ward, Bed: $bed)',
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
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

            // Medication Form
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
                              'Administration Date & Time *',
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

                    // Medication Details
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Medication Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Medication Name
                            TextFormField(
                              controller: _medicationNameController,
                              decoration: const InputDecoration(
                                labelText: 'Medication Name *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.local_pharmacy),
                                hintText: 'e.g., Paracetamol',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter medication name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Dosage
                            TextFormField(
                              controller: _dosageController,
                              decoration: const InputDecoration(
                                labelText: 'Dosage *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.medication_liquid),
                                hintText: 'e.g., 500mg',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter dosage';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Route
                            TextFormField(
                              controller: _routeController,
                              decoration: const InputDecoration(
                                labelText: 'Route *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.route),
                                hintText: 'e.g., Oral, IV, IM',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter route';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Frequency
                            DropdownButtonFormField<String>(
                              value: _frequency,
                              decoration: const InputDecoration(
                                labelText: 'Frequency *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.schedule),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'once_daily',
                                  child: Text('Once Daily'),
                                ),
                                DropdownMenuItem(
                                  value: 'twice_daily',
                                  child: Text('Twice Daily (BD)'),
                                ),
                                DropdownMenuItem(
                                  value: 'three_times_daily',
                                  child: Text('Three Times Daily (TDS)'),
                                ),
                                DropdownMenuItem(
                                  value: 'four_times_daily',
                                  child: Text('Four Times Daily (QDS)'),
                                ),
                                DropdownMenuItem(
                                  value: 'every_6_hours',
                                  child: Text('Every 6 Hours'),
                                ),
                                DropdownMenuItem(
                                  value: 'every_8_hours',
                                  child: Text('Every 8 Hours'),
                                ),
                                DropdownMenuItem(
                                  value: 'every_12_hours',
                                  child: Text('Every 12 Hours'),
                                ),
                                DropdownMenuItem(
                                  value: 'prn',
                                  child: Text('As Needed (PRN)'),
                                ),
                                DropdownMenuItem(
                                  value: 'stat',
                                  child: Text('STAT (Immediately)'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _frequency = value!;
                                });
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
                              'Administration Notes',
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
                                hintText:
                                    'Any observations after administration, patient reactions, etc...',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Record Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _recordMedication,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
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
                                'Record Medication',
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

            // Recent Medications History
            if (_selectedAdmissionId != null) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Recent Medications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('admissions')
                    .doc(_selectedAdmissionId)
                    .collection('medications')
                    .orderBy('administeredAt', descending: true)
                    .limit(10)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final medications = snapshot.data!.docs;

                  if (medications.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.medication_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No medication records yet',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: medications.length,
                    itemBuilder: (context, index) {
                      final data =
                          medications[index].data() as Map<String, dynamic>;
                      final medicationName =
                          data['medicationName'] ?? 'Unknown';
                      final dosage = data['dosage'] ?? 'N/A';
                      final route = data['route'] ?? 'N/A';
                      final frequency = data['frequency'] ?? 'N/A';
                      final administeredBy =
                          data['administeredByName'] ?? 'Unknown';
                      final administeredAt =
                          (data['administeredAt'] as Timestamp?)?.toDate();
                      final dateStr = administeredAt != null
                          ? DateFormat(
                              'MMM dd, yyyy - hh:mm a',
                            ).format(administeredAt)
                          : 'N/A';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo,
                            child: const Icon(
                              Icons.medication,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            medicationName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$dosage - $route - $frequency'),
                              Text(
                                'By: $administeredBy',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          trailing: Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
