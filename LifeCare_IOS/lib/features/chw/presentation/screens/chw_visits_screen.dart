import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chw_visit_detail_screen.dart'; // Import the detail screen

class CHWVisitsScreen extends StatelessWidget {
  const CHWVisitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String chwId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (chwId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    final Stream<QuerySnapshot> visitsStream = FirebaseFirestore.instance
        .collection('visits')
        .where('chwId', isEqualTo: chwId)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('scheduledDate', descending: false)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Visits'),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: visitsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No upcoming visits found.'));
          }

          final visits = snapshot.data!.docs;

          return ListView.builder(
            itemCount: visits.length,
            itemBuilder: (context, index) {
              final data = visits[index].data() as Map<String, dynamic>;

              final scheduledDate = (data['scheduledDate'] as Timestamp)
                  .toDate();
              final formattedDate =
                  "${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year} ${scheduledDate.hour.toString().padLeft(2, '0')}:${scheduledDate.minute.toString().padLeft(2, '0')}";

              return ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.teal),
                title: Text(data['patientName'] ?? 'Unknown Patient'),
                subtitle: Text(
                  '${data['visitType'] ?? 'Visit'} • $formattedDate',
                ),
                trailing: Icon(
                  data['status'] == 'completed'
                      ? Icons.check_circle
                      : Icons.pending,
                  color: data['status'] == 'completed'
                      ? Colors.green
                      : Colors.orange,
                ),
                onTap: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CHWVisitDetailScreen(visitId: visits[index].id),
                    ),
                  );
                  if (result == true) {
                    // Optionally refresh the visits list if visit status changed
                    // (Since this is a StatelessWidget with StreamBuilder, the list auto-refreshes)
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
