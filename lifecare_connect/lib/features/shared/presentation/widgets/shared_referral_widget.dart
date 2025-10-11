// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SharedReferralWidget extends StatelessWidget {
  final String role;
  final String? userId;

  const SharedReferralWidget({super.key, required this.role, this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('referrals')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading referrals: ${snapshot.error}'),
          );
        }

        final referrals = snapshot.data?.docs ?? [];

        if (referrals.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.compare_arrows, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No referrals found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: referrals.length,
          itemBuilder: (context, index) {
            final referral = referrals[index].data() as Map<String, dynamic>;
            final createdAt = referral['created_at'] as Timestamp?;
            final status = referral['status'] ?? 'pending';
            final urgency = referral['urgency'] ?? 'normal';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getUrgencyColor(urgency).withOpacity(0.1),
                  child: Icon(
                    Icons.compare_arrows,
                    color: _getUrgencyColor(urgency),
                  ),
                ),
                title: Text(referral['patient_name'] ?? 'Unknown Patient'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From: ${referral['from_provider'] ?? 'Unknown Provider'}',
                    ),
                    Text(
                      'To: ${referral['to_facility'] ?? 'Unknown Facility'}',
                    ),
                    Text(
                      'Reason: ${referral['reason'] ?? 'No reason provided'}',
                    ),
                    if (createdAt != null)
                      Text(
                        'Date: ${DateFormat('MMM dd, yyyy - HH:mm').format(createdAt.toDate())}',
                      ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getStatusColor(status).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getUrgencyColor(urgency).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getUrgencyColor(urgency).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        urgency.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: _getUrgencyColor(urgency),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      case 'in_progress':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'high':
      case 'urgent':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
      case 'normal':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
