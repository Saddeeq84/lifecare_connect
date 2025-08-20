import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AncPncChecklistScreen extends StatefulWidget {
  const AncPncChecklistScreen({super.key});

  @override
  State<AncPncChecklistScreen> createState() => _AncPncChecklistScreenState();
}

class _AncPncChecklistScreenState extends State<AncPncChecklistScreen> {
  Future<List<DocumentSnapshot>> _loadMyPatients() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    final String userId = currentUser.uid;
    final Set<String> patientIds = <String>{};

    // 1. Patients registered by this CHW
    final registeredPatients = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .where('createdBy', isEqualTo: userId)
        .get();
    for (final doc in registeredPatients.docs) {
      patientIds.add(doc.id);
    }

    // 2. Patients from health records (consultations, ANC visits, etc.)
    final healthRecords = await FirebaseFirestore.instance
        .collection('health_records')
        .where('providerId', isEqualTo: userId)
        .get();
    for (final doc in healthRecords.docs) {
      final data = doc.data();
      if (data['patientId'] != null) {
        patientIds.add(data['patientId']);
      }
    }

    // 3. Patients from appointments (approved, completed, attended, or any interaction)
    try {
      final appointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('providerId', isEqualTo: userId)
          .get();
      for (final doc in appointments.docs) {
        final data = doc.data();
        if (data['patientId'] != null) {
          patientIds.add(data['patientId']);
        }
      }
      // Also include self-registered patients who booked appointment with this CHW
      final selfAppointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('status', whereIn: ['completed', 'attended', 'approved'])
          .where('providerId', isEqualTo: userId)
          .get();
      for (final doc in selfAppointments.docs) {
        final data = doc.data();
        if (data['patientId'] != null) {
          patientIds.add(data['patientId']);
        }
      }
    } catch (e) {}

    // 4. Patients from referrals (sent or received)
    try {
      final referrals = await FirebaseFirestore.instance
          .collection('referrals')
          .where('referredById', isEqualTo: userId)
          .get();
      for (final doc in referrals.docs) {
        final data = doc.data();
        if (data['patientId'] != null) {
          patientIds.add(data['patientId']);
        }
      }
      final receivedReferrals = await FirebaseFirestore.instance
          .collection('referrals')
          .where('referredToId', isEqualTo: userId)
          .get();
      for (final doc in receivedReferrals.docs) {
        final data = doc.data();
        if (data['patientId'] != null) {
          patientIds.add(data['patientId']);
        }
      }
    } catch (e) {}

    // 5. Patients from general consultations (health_records with type 'General Consultation')
    final generalConsults = await FirebaseFirestore.instance
        .collection('health_records')
        .where('providerId', isEqualTo: userId)
        .where('type', isEqualTo: 'General Consultation')
        .get();
    for (final doc in generalConsults.docs) {
      final data = doc.data();
      if (data['patientId'] != null) {
        patientIds.add(data['patientId']);
      }
    }

    // 6. Patients from ANC consultations (health_records with type 'ANC Consultation')
    final ancConsults = await FirebaseFirestore.instance
        .collection('health_records')
        .where('providerId', isEqualTo: userId)
        .where('type', isEqualTo: 'ANC Consultation')
        .get();
    for (final doc in ancConsults.docs) {
      final data = doc.data();
      if (data['patientId'] != null) {
        patientIds.add(data['patientId']);
      }
    }

    // Get all patients that match these IDs
    if (patientIds.isEmpty) return [];
    final List<DocumentSnapshot> allDocs = [];
    final List<String> patientIdsList = patientIds.toList();
    const int batchSize = 10;
    for (int i = 0; i < patientIdsList.length; i += batchSize) {
      final batch = patientIdsList.sublist(
        i,
        i + batchSize > patientIdsList.length ? patientIdsList.length : i + batchSize,
      );
      final batchQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      allDocs.addAll(batchQuery.docs);
    }
    allDocs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aName = aData['name'] ?? aData['fullName'] ?? '';
      final bName = bData['name'] ?? bData['fullName'] ?? '';
      return aName.compareTo(bName);
    });
    return allDocs;
  }
  String? selectedPatientId;
  String? selectedPatientName;
  final Map<String, bool> ancChecklist = {
    'Blood pressure measured': false,
    'Urine tested for protein': false,
    'Weight recorded': false,
    'Fetal heart rate checked': false,
    'Iron/folic acid supplementation given': false,
    'Tetanus toxoid vaccination': false,
    'Counseling on danger signs': false,
    'Birth preparedness discussed': false,
  };
  final Map<String, bool> pncChecklist = {
    'Mother’s vital signs checked': false,
    'Breastfeeding assessed': false,
    'Uterine involution checked': false,
    'Perineum/incision site inspected': false,
    'Family planning discussed': false,
    'Immunizations for newborn': false,
    'Counseling on postpartum danger signs': false,
  };
  bool submitting = false;

  Future<void> submitChecklist() async {
    if (selectedPatientId == null || selectedPatientName == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: const Text('Are you sure you want to submit this checklist to the patient health record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => submitting = true);
    try {
      await FirebaseFirestore.instance.collection('health_records').add({
        'patientId': selectedPatientId,
        'patientName': selectedPatientName,
        'type': 'ANC/PNC Checklist',
        'ancChecklist': ancChecklist,
        'pncChecklist': pncChecklist,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checklist submitted to health record!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting checklist: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ANC/PNC Checklist'),
        backgroundColor: Colors.teal,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<List<DocumentSnapshot>>(
            future: _loadMyPatients(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No patients found');
              }
              final patients = snapshot.data!;
              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Select Patient'),
                value: selectedPatientId,
                items: patients.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? data['fullName'] ?? 'Unknown Patient';
                  return DropdownMenuItem(
                    value: doc.id,
                    child: Text(name),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedPatientId = val;
                    final selectedDoc = patients.firstWhere((doc) => doc.id == val);
                    final data = selectedDoc.data() as Map<String, dynamic>;
                    selectedPatientName = data['name'] ?? data['fullName'] ?? 'Unknown Patient';
                  });
                },
                validator: (val) => val == null ? 'Please select a patient' : null,
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('Antenatal Care (ANC) Checklist', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...ancChecklist.keys.map((label) => CheckboxListTile(
                title: Text(label),
                value: ancChecklist[label],
                onChanged: selectedPatientId == null ? null : (val) => setState(() => ancChecklist[label] = val ?? false),
              )),
          const Divider(height: 32),
          const Text('Postnatal Care (PNC) Checklist', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...pncChecklist.keys.map((label) => CheckboxListTile(
                title: Text(label),
                value: pncChecklist[label],
                onChanged: selectedPatientId == null ? null : (val) => setState(() => pncChecklist[label] = val ?? false),
              )),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: submitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Checklist'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: submitting || selectedPatientId == null ? null : submitChecklist,
          ),
        ],
      ),
    );
  }
}