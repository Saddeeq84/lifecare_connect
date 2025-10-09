// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:intl/intl.dart';

class PatientConsultationsScreen extends StatelessWidget {
  const PatientConsultationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Consultations'),
        backgroundColor: Colors.green.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('patientId', isEqualTo: userId)
            .where('status', isEqualTo: 'completed')
            .orderBy('completedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading consultations'));
          }
          final consultations = snapshot.data?.docs ?? [];
          if (consultations.isEmpty) {
            return const Center(child: Text('No completed consultations yet.'));
          }
          return ListView.builder(
            itemCount: consultations.length,
            itemBuilder: (context, index) {
              final data = consultations[index].data() as Map<String, dynamic>;
              final date = data['completedAt'] != null
                  ? (data['completedAt'] as Timestamp).toDate()
                  : null;
              final dateStr = date != null
                  ? DateFormat('MMM dd, yyyy • hh:mm a').format(date)
                  : 'Date not set';
              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  title: Text(data['appointmentType'] ?? 'Consultation'),
                  subtitle: Text('Provider: ${data['providerName'] ?? 'N/A'}\nDate: $dateStr'),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                  onTap: () => showDialog(
                    context: context,
                    builder: (context) => _ConsultationDetailsDialog(data: data),
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

class _ConsultationDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ConsultationDetailsDialog({required this.data});

  @override
  Widget build(BuildContext context) {
    final completedAt = data['completedAt'] != null
        ? (data['completedAt'] as Timestamp).toDate()
        : null;
    return AlertDialog(
      title: Text(data['appointmentType'] ?? 'Consultation Details'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Provider', '${data['providerName']} (${data['providerType']})'),
            _buildDetailRow('Completed', completedAt != null
                ? DateFormat('MMM dd, yyyy • hh:mm a').format(completedAt)
                : 'Date not available'),
            _buildDetailRow('Status', data['status'] ?? 'Unknown'),
            _buildDetailRow('Urgency', data['urgency'] ?? 'Normal'),
            if (data['preConsultationData'] != null && data['preConsultationData']['mainComplaint'] != null)
              _buildDetailRow('Main Complaint', data['preConsultationData']['mainComplaint']),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.videocam),
                  label: const Text('Join Video Call'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.of(context).pop();
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Consultation Completed'),
                        content: const Text('This consultation is completed. To speak with a provider, please book a new appointment.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.call),
                  label: const Text('Join Audio Call'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.of(context).pop();
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Consultation Completed'),
                        content: const Text('This consultation is completed. To speak with a provider, please book a new appointment.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
