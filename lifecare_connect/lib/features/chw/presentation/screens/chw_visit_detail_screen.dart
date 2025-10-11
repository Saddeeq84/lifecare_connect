// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CHWVisitDetailScreen extends StatefulWidget {
  final String visitId; // Firestore doc ID

  const CHWVisitDetailScreen({super.key, required this.visitId});

  @override
  State<CHWVisitDetailScreen> createState() => _CHWVisitDetailScreenState();
}

class _CHWVisitDetailScreenState extends State<CHWVisitDetailScreen> {
  bool _isLoading = false;

  Future<DocumentSnapshot> _getVisit() {
    return FirebaseFirestore.instance
        .collection('visits')
        .doc(widget.visitId)
        .get();
  }

  Future<void> _markCompleted() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('visits')
          .doc(widget.visitId)
          .update({'status': 'completed'});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visit marked as completed')),
      );

      Navigator.of(context).pop(true); // Return true to refresh list if needed
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating visit: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _getVisit(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text('Visit not found')));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final scheduledDate = (data['scheduledDate'] as Timestamp).toDate();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Visit Details'),
            backgroundColor: Colors.teal,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient: ${data['patientName'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Visit Type: ${data['visitType'] ?? 'N/A'}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scheduled Date: ${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year} ${scheduledDate.hour.toString().padLeft(2, '0')}:${scheduledDate.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Status: ${data['status'] ?? 'pending'}',
                  style: TextStyle(
                    fontSize: 16,
                    color: data['status'] == 'completed'
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Notes:',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data['notes'] ?? 'No additional notes.',
                  style: const TextStyle(fontSize: 14),
                ),
                const Spacer(),
                if (data['status'] != 'completed')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _markCompleted,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Mark as Completed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
