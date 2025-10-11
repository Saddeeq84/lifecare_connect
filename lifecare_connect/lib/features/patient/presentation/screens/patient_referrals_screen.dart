// ignore_for_file: prefer_const_constructors, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/data/models/referral.dart';
import '../../../shared/data/services/referral_service.dart';

class PatientReferralsScreen extends StatefulWidget {
  const PatientReferralsScreen({super.key});

  @override
  State<PatientReferralsScreen> createState() => _PatientReferralsScreenState();
}

class _PatientReferralsScreenState extends State<PatientReferralsScreen> {
  List<Referral> _referrals = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadReferrals();
  }

  void _loadReferrals() {
    if (_currentUserId == null) return;

    setState(() {
      _isLoading = true;
    });

    ReferralService.getPatientReferrals(patientId: _currentUserId!).listen(
      (snapshot) {
        final referrals = snapshot.docs
            .map((doc) => Referral.fromFirestore(doc))
            .toList();
        setState(() {
          _referrals = referrals;
          _isLoading = false;
        });
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading referrals: $error')),
          );
        }
      },
    );
  }

  Future<void> _refreshReferrals() async {
    _loadReferrals();
  }

  void _showReferralDetails(Referral referral) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Referral Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Status', referral.status.toUpperCase()),
              _buildDetailRow('Doctor', referral.toProviderName),
              _buildDetailRow(
                'Facility',
                referral.facilityName ?? 'Not specified',
              ),
              _buildDetailRow('Urgency', referral.urgency.toUpperCase()),
              _buildDetailRow('Reason', referral.reason),
              _buildDetailRow('Created', referral.formattedCreatedDate),
              if (referral.notes?.isNotEmpty == true)
                _buildDetailRow('Notes', referral.notes!),
              if (referral.actionNotes?.isNotEmpty == true)
                _buildDetailRow('Action Notes', referral.actionNotes!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.access_time;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Referrals'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _refreshReferrals),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _referrals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No referrals yet',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your healthcare provider will refer you when needed',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshReferrals,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _referrals.length,
                    itemBuilder: (context, index) {
                      final referral = _referrals[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(referral.status),
                                child: Icon(
                                  _getStatusIcon(referral.status),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                referral.toProviderName,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(referral.facilityName ?? 'Not specified'),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(
                                            referral.status,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: _getStatusColor(referral.status),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          referral.status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: _getStatusColor(referral.status),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      if (referral.urgency == 'urgent')
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: Colors.red,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            'URGENT',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Created: ${referral.formattedCreatedDate}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => _showReferralDetails(referral),
                            ),
                            if (referral.status.toLowerCase() == 'approved')
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 16, right: 16, bottom: 16),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.event_available),
                                    label: Text('Book Appointment'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      context.push(
                                        '/book_appointment',
                                        extra: {
                                          'preSelectedProvider': referral.toProviderMap(),
                                          'fromReferral': true,
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
