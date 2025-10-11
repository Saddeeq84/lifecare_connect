// lib/screens/facilityscreen/facility_patient_list_screen.dart

// ignore_for_file: use_build_context_synchronously, unnecessary_string_interpolations

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class FacilityPatientListScreen extends StatefulWidget {
  const FacilityPatientListScreen({super.key});

  @override
  State<FacilityPatientListScreen> createState() =>
      _FacilityPatientListScreenState();
}

class _FacilityPatientListScreenState extends State<FacilityPatientListScreen> {
  final String currentFacilityId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Patients'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patients...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Patients List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getPatientsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text('Error loading patients: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No patients found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Patients will appear here when they book services',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Use FutureBuilder to get patient details
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getPatientDetails(snapshot.data!.docs),
                  builder: (context, patientSnapshot) {
                    if (patientSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (patientSnapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 64, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading patient details: ${patientSnapshot.error}',
                            ),
                          ],
                        ),
                      );
                    }

                    final allPatients = patientSnapshot.data ?? [];

                    // Filter patients based on search query
                    final filteredPatients = allPatients.where((patientData) {
                      final name =
                          (patientData['name'] ?? patientData['fullName'] ?? '')
                              .toString()
                              .toLowerCase();
                      final email = (patientData['email'] ?? '')
                          .toString()
                          .toLowerCase();
                      return name.contains(searchQuery) ||
                          email.contains(searchQuery);
                    }).toList();

                    if (filteredPatients.isEmpty && searchQuery.isNotEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No patients match your search',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filteredPatients.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final patientData = filteredPatients[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: Colors.purple.shade100,
                              child: Text(
                                _getInitials(
                                  patientData['name'] ??
                                      patientData['fullName'] ??
                                      'Unknown',
                                ),
                                style: TextStyle(
                                  color: Colors.purple.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              patientData['name'] ??
                                  patientData['fullName'] ??
                                  'Unknown Patient',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                if (patientData['email'] != null)
                                  Text(
                                    patientData['email'],
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                if (patientData['phone'] != null)
                                  Text(
                                    patientData['phone'],
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Patient',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${patientData['serviceRequestCount']} visits',
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (patientData['lastVisit'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Last visit: ${_formatDate(patientData['lastVisit'])}',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) => _handlePatientAction(
                                context,
                                patientData,
                                value,
                              ),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'view_history',
                                  child: Row(
                                    children: [
                                      Icon(Icons.history),
                                      SizedBox(width: 8),
                                      Text('View History'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'send_message',
                                  child: Row(
                                    children: [
                                      Icon(Icons.message),
                                      SizedBox(width: 8),
                                      Text('Send Message'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'view_profile',
                                  child: Row(
                                    children: [
                                      Icon(Icons.person),
                                      SizedBox(width: 8),
                                      Text('View Profile'),
                                    ],
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getPatientsStream() {
    // Get patients who have service requests with this facility
    return FirebaseFirestore.instance
        .collection('service_requests')
        .where('facilityId', isEqualTo: currentFacilityId)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> _getPatientDetails(
    List<QueryDocumentSnapshot> serviceRequests,
  ) async {
    if (serviceRequests.isEmpty) {
      return [];
    }

    // Get unique patient IDs from service requests
    final patientIds = serviceRequests
        .map(
          (doc) => (doc.data() as Map<String, dynamic>)['patientId'] as String?,
        )
        .where((id) => id != null && id.isNotEmpty)
        .toSet()
        .toList();

    if (patientIds.isEmpty) {
      return [];
    }

    // Split into chunks if more than 10 (Firestore 'whereIn' limit)
    final List<Map<String, dynamic>> allPatients = [];

    for (int i = 0; i < patientIds.length; i += 10) {
      final chunk = patientIds.skip(i).take(10).toList();

      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final userDoc in userQuery.docs) {
        final userData = userDoc.data();

        // Get service request count for this patient
        final patientServiceRequests = serviceRequests
            .where(
              (req) =>
                  (req.data() as Map<String, dynamic>)['patientId'] ==
                  userDoc.id,
            )
            .length;

        // Get latest service request date
        final latestRequest = serviceRequests
            .where(
              (req) =>
                  (req.data() as Map<String, dynamic>)['patientId'] ==
                  userDoc.id,
            )
            .map(
              (req) =>
                  (req.data() as Map<String, dynamic>)['createdAt']
                      as Timestamp?,
            )
            .where((timestamp) => timestamp != null)
            .map((timestamp) => timestamp!.toDate())
            .fold<DateTime?>(
              null,
              (latest, current) =>
                  latest == null || current.isAfter(latest) ? current : latest,
            );

        allPatients.add({
          ...userData,
          'id': userDoc.id,
          'serviceRequestCount': patientServiceRequests,
          'lastVisit': latestRequest,
        });
      }
    }

    return allPatients;
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  void _handlePatientAction(
    BuildContext context,
    Map<String, dynamic> patientData,
    String action,
  ) {
    switch (action) {
      case 'view_history':
        _showPatientHistory(context, patientData);
        break;
      case 'send_message':
        _sendMessageToPatient(context, patientData);
        break;
      case 'view_profile':
        _showPatientProfile(context, patientData);
        break;
    }
  }

  void _showPatientHistory(
    BuildContext context,
    Map<String, dynamic> patientData,
  ) {
    final patientId = patientData['id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Service History - ${patientData['name'] ?? 'Unknown Patient'}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('service_requests')
                      .where('facilityId', isEqualTo: currentFacilityId)
                      .where('patientId', isEqualTo: patientId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('No service history found'),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final service = snapshot.data!.docs[index];
                        final serviceData =
                            service.data() as Map<String, dynamic>;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(
                                serviceData['status'],
                              ),
                              child: Icon(
                                _getStatusIcon(serviceData['status']),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              serviceData['serviceName'] ?? 'Unknown Service',
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status: ${serviceData['status']}'),
                                if (serviceData['createdAt'] != null)
                                  Text(
                                    'Date: ${_formatDate((serviceData['createdAt'] as Timestamp).toDate())}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendMessageToPatient(
    BuildContext context,
    Map<String, dynamic> patientData,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Opening message with ${patientData['name'] ?? 'Unknown Patient'}',
        ),
        backgroundColor: Colors.blue,
      ),
    );

    // Show messaging dialog interface
    _showMessagingDialog(context, patientData);
  }

  void _showPatientProfile(
    BuildContext context,
    Map<String, dynamic> patientData,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.purple.shade100,
                  radius: 25,
                  child: Text(
                    _getInitials(
                      patientData['name'] ??
                          patientData['fullName'] ??
                          'Unknown',
                    ),
                    style: TextStyle(
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientData['name'] ??
                            patientData['fullName'] ??
                            'Unknown Patient',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      Text(
                        'Patient ID: ${patientData['id']}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Email', patientData['email']),
            _buildInfoRow('Phone', patientData['phone']),
            _buildInfoRow(
              'Total Visits',
              '${patientData['serviceRequestCount']}',
            ),
            if (patientData['lastVisit'] != null)
              _buildInfoRow(
                'Last Visit',
                _formatDate(patientData['lastVisit']),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value ?? 'Not provided')),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'approved':
        return Icons.thumb_up;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  void _showMessagingDialog(
    BuildContext context,
    Map<String, dynamic> patientData,
  ) {
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.purple.shade100,
                child: Text(
                  _getInitials(patientData['name'] ?? 'Unknown'),
                  style: TextStyle(
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Send Message'),
                    Text(
                      patientData['name'] ?? 'Unknown Patient',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Send a message to this patient:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Type your message here...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will be delivered via the app notification system',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (messageController.text.trim().isNotEmpty) {
                  Navigator.pop(context);

                  // Show loading
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AlertDialog(
                      content: Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 20),
                          Text('Sending message...'),
                        ],
                      ),
                    ),
                  );

                  try {
                    // Implement actual message sending to Firebase
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser == null) {
                      throw Exception('User not authenticated');
                    }

                    // Create message document in Firestore
                    final messageData = {
                      'senderId': currentUser.uid,
                      'senderType': 'facility',
                      'senderName':
                          'Facility', // You might want to get actual facility name
                      'recipientId': patientData['id'],
                      'recipientType': 'patient',
                      'recipientName': patientData['name'] ?? 'Unknown Patient',
                      'message': messageController.text.trim(),
                      'messageType': 'text',
                      'status': 'sent',
                      'isRead': false,
                      'sentAt': FieldValue.serverTimestamp(),
                      'createdAt': FieldValue.serverTimestamp(),
                      'conversationId':
                          '${currentUser.uid}_${patientData['id']}',
                    };

                    // Add message to Firestore
                    final messageRef = await FirebaseFirestore.instance
                        .collection('messages')
                        .add(messageData);

                    // Create or update conversation document
                    final conversationData = {
                      'participants': [currentUser.uid, patientData['id']],
                      'participantTypes': {
                        '${currentUser.uid}': 'facility',
                        '${patientData['id']}': 'patient',
                      },
                      'participantNames': {
                        '${currentUser.uid}': 'Facility',
                        '${patientData['id']}':
                            patientData['name'] ?? 'Unknown Patient',
                      },
                      'lastMessage': messageController.text.trim(),
                      'lastMessageSenderId': currentUser.uid,
                      'lastMessageAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                      'unreadCount': {
                        '${currentUser.uid}': 0,
                        '${patientData['id']}': FieldValue.increment(1),
                      },
                    };

                    await FirebaseFirestore.instance
                        .collection('conversations')
                        .doc('${currentUser.uid}_${patientData['id']}')
                        .set(conversationData, SetOptions(merge: true));

                    // Push notification functionality can be implemented via Cloud Functions
                    // Cloud Functions would listen for new messages and send FCM notifications

                    Navigator.pop(context); // Close loading dialog

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Message sent to ${patientData['name']}! Message ID: ${messageRef.id.substring(0, 8)}',
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(context); // Close loading dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to send message: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a message'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Message'),
            ),
          ],
        );
      },
    );
  }
}
