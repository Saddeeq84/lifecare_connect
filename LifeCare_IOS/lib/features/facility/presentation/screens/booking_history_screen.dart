import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class BookingHistoryScreen extends StatelessWidget {
  const BookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Please log in'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking History'),
        backgroundColor: Colors.green.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('patientId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(child: Text('Failed to load history.'));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No bookings yet.'));
          }
          return ListView(
            children: docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final serviceType = data['serviceType'] ?? '';
              final status = data['status'] ?? '';
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              return ListTile(
                title: Text(_displayLabel(serviceType)),
                subtitle: Text(
                  timestamp != null
                      ? DateFormat.yMd().add_jm().format(timestamp)
                      : '',
                ),
                trailing: Text(status.toString().capitalize()),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  String _displayLabel(String key) {
    switch (key) {
      case 'lab_test':
        return 'Lab Test';
      case 'medicine_delivery':
        return 'Medicine Delivery';
      case 'scan':
        return 'Scan';
      case 'hospital_appointment':
        return 'Hospital Appointment';
      default:
        return key;
    }
  }
}

extension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1)}";
}
