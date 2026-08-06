import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RadiologyReportingScreen extends StatefulWidget {
  final String facilityId;
  final String radiologistId;
  final String radiologistName;

  const RadiologyReportingScreen({
    super.key,
    required this.facilityId,
    required this.radiologistId,
    required this.radiologistName,
  });

  @override
  State<RadiologyReportingScreen> createState() =>
      _RadiologyReportingScreenState();
}

class _RadiologyReportingScreenState extends State<RadiologyReportingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Radiology Reports')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pending_imaging')
            .where('facilityId', isEqualTo: widget.facilityId)
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.scanner_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No pending imaging requests',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final timestamp = data['createdAt'] as Timestamp?;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EnterRadiologyReportScreen(
                          imagingId: doc.id,
                          imagingData: data,
                          radiologistId: widget.radiologistId,
                          radiologistName: widget.radiologistName,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                data['imagingType'] ?? 'Unknown Imaging',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'PENDING',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Text(
                          'Patient: ${data['patientName'] ?? 'Unknown'}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Requested by: ${data['clinicianName'] ?? 'Unknown'}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (timestamp != null)
                          Text(
                            'Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate())}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Cost: ₦${(data['cost'] as num).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EnterRadiologyReportScreen(
                                        imagingId: doc.id,
                                        imagingData: data,
                                        radiologistId: widget.radiologistId,
                                        radiologistName: widget.radiologistName,
                                      ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Write Report'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class EnterRadiologyReportScreen extends StatefulWidget {
  final String imagingId;
  final Map<String, dynamic> imagingData;
  final String radiologistId;
  final String radiologistName;

  const EnterRadiologyReportScreen({
    super.key,
    required this.imagingId,
    required this.imagingData,
    required this.radiologistId,
    required this.radiologistName,
  });

  @override
  State<EnterRadiologyReportScreen> createState() =>
      _EnterRadiologyReportScreenState();
}

class _EnterRadiologyReportScreenState
    extends State<EnterRadiologyReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clinicalInfoController = TextEditingController();
  final _techniqueController = TextEditingController();
  final _findingsController = TextEditingController();
  final _impressionController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setDefaultTechnique();
  }

  void _setDefaultTechnique() {
    final imagingType = widget.imagingData['imagingType'] as String;

    if (imagingType.contains('X-Ray')) {
      _techniqueController.text =
          'Digital radiography performed in standard projections.';
    } else if (imagingType.contains('Ultrasound')) {
      _techniqueController.text =
          'Real-time ultrasound examination using a convex transducer.';
    } else if (imagingType.contains('CT')) {
      _techniqueController.text =
          'Helical CT scan performed with intravenous contrast.';
    } else if (imagingType.contains('MRI')) {
      _techniqueController.text =
          'MRI examination performed using standard sequences (T1, T2, FLAIR).';
    } else if (imagingType.contains('Echo')) {
      _techniqueController.text =
          '2D Echocardiography with Doppler assessment.';
    }
  }

  @override
  void dispose() {
    _clinicalInfoController.dispose();
    _techniqueController.dispose();
    _findingsController.dispose();
    _impressionController.dispose();
    super.dispose();
  }

  Future<void> _saveReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final cost = (widget.imagingData['cost'] as num).toDouble();
      final patientId = widget.imagingData['patientId'];

      // Get patient data
      final patientDoc = await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(patientId)
          .get();

      if (!patientDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final patientData = patientDoc.data()!;
      final registrationType = patientData['registrationType'] as String?;

      // Get wallet balance based on registration type
      double walletBalance;
      String? householdId;
      bool useHouseholdWallet = false;

      if (registrationType == 'household') {
        // For household members, use household wallet
        useHouseholdWallet = true;
        householdId = patientData['householdId'] as String?;

        if (householdId == null || householdId.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Patient is not assigned to a household'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        final householdDoc = await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(householdId)
            .get();

        walletBalance =
            (householdDoc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      } else {
        // For individual patients, use individual wallet
        walletBalance =
            (patientData['walletBalance'] as num?)?.toDouble() ?? 0.0;
      }

      if (walletBalance < cost) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient ${useHouseholdWallet ? 'household' : 'patient'} wallet balance. Required: ₦${cost.toStringAsFixed(2)}, Available: ₦${walletBalance.toStringAsFixed(2)}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final reportData = {
        'clinicalInformation': _clinicalInfoController.text.trim(),
        'technique': _techniqueController.text.trim(),
        'findings': _findingsController.text.trim(),
        'impression': _impressionController.text.trim(),
        'reportedBy': widget.radiologistName,
        'reportedById': widget.radiologistId,
        'reportedAt': FieldValue.serverTimestamp(),
      };

      // Update imaging request status
      await FirebaseFirestore.instance
          .collection('pending_imaging')
          .doc(widget.imagingId)
          .update({
            'status': 'completed',
            'report': reportData,
            'completedAt': FieldValue.serverTimestamp(),
          });

      // Save to patient's imaging results
      await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(patientId)
          .collection('imaging_results')
          .add({
            'imagingId': widget.imagingId,
            'imagingType': widget.imagingData['imagingType'],
            'report': reportData,
            'cost': cost,
            'clinicianName': widget.imagingData['clinicianName'],
            'completedAt': FieldValue.serverTimestamp(),
          });

      // Deduct from wallet based on registration type
      if (useHouseholdWallet && householdId != null) {
        // Deduct from household wallet for household members
        await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(householdId)
            .update({'balance': FieldValue.increment(-cost)});

        // Record transaction in household
        await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(householdId)
            .collection('transactions')
            .add({
              'type': 'debit',
              'amount': cost,
              'description':
                  'Imaging: ${widget.imagingData['imagingType']} for ${patientData['fullName']}',
              'patientId': patientId,
              'patientName': patientData['fullName'],
              'timestamp': FieldValue.serverTimestamp(),
            });
      } else {
        // Deduct from individual patient wallet (wallets collection)
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(patientId)
            .update({
              'balance': FieldValue.increment(-cost),
              'updatedAt': FieldValue.serverTimestamp(),
            });

        // Record transaction in patient wallet
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(patientId)
            .collection('transactions')
            .add({
              'type': 'debit',
              'amount': cost,
              'description': 'Radiology - ${widget.imagingData['imagingType']}',
              'reportedBy': widget.radiologistName,
              'reportedById': widget.radiologistId,
              'timestamp': FieldValue.serverTimestamp(),
              'status': 'completed',
            });
      }

      // Credit the facility wallet
      final facilityId = widget.imagingData['facilityId'];
      if (facilityId != null) {
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(facilityId)
            .update({
              'balance': FieldValue.increment(cost),
              'updatedAt': FieldValue.serverTimestamp(),
            });

        // Record transaction in facility wallet
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(facilityId)
            .collection('transactions')
            .add({
              'type': 'credit',
              'amount': cost,
              'description':
                  'Radiology revenue - ${widget.imagingData['imagingType']} for ${patientData['fullName']}',
              'patientId': patientId,
              'patientName': patientData['fullName'],
              'radiologistId': widget.radiologistId,
              'radiologistName': widget.radiologistName,
              'timestamp': FieldValue.serverTimestamp(),
              'status': 'completed',
            });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Report saved. ₦${cost.toStringAsFixed(2)} deducted from wallet.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = widget.imagingData['createdAt'] as Timestamp?;

    return Scaffold(
      appBar: AppBar(title: const Text('Radiology Report')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Imaging Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.imagingData['imagingType'] ?? 'Unknown Imaging',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 16),
                    Text('Patient: ${widget.imagingData['patientName']}'),
                    Text(
                      'Requested by: ${widget.imagingData['clinicianName']}',
                    ),
                    if (timestamp != null)
                      Text(
                        'Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate())}',
                      ),
                    Text(
                      'Cost: ₦${(widget.imagingData['cost'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Clinical Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CLINICAL INFORMATION',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _clinicalInfoController,
                      decoration: const InputDecoration(
                        hintText: 'Enter clinical history and indication...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter clinical information';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Technique
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TECHNIQUE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _techniqueController,
                      decoration: const InputDecoration(
                        hintText: 'Describe imaging technique used...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter technique';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Findings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FINDINGS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _findingsController,
                      decoration: const InputDecoration(
                        hintText: 'Describe detailed imaging findings...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 8,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter findings';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Impression/Conclusion
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'IMPRESSION/CONCLUSION',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _impressionController,
                      decoration: const InputDecoration(
                        hintText: 'Summary and radiological impression...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter impression';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Reporting Info
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reported by: ${widget.radiologistName}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.now())}',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveReport,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save Report & Deduct from Wallet',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
