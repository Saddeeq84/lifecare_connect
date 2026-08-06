import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'facility_register_patient_screen.dart';

class FacilityPatientListScreen extends StatefulWidget {
  const FacilityPatientListScreen({super.key});

  @override
  State<FacilityPatientListScreen> createState() =>
      _FacilityPatientListScreenState();
}

class _FacilityPatientListScreenState extends State<FacilityPatientListScreen> {
  String currentFacilityId = '';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _facilityType;
  bool _isLoadingFacilityType = true;

  @override
  void initState() {
    super.initState();
    _loadFacilityData();
  }

  Future<void> _loadFacilityData() async {
    try {
      print('👥 [PatientList] Loading facility data...');
      // First check if staff is logged in
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');
      print('👥 [PatientList] User role: $userRole');

      if (userRole == 'facility_staff') {
        // Staff login - get facilityId from SharedPreferences
        final facilityId = prefs.getString('facility_id') ?? '';
        print('👥 [PatientList] Staff facilityId from prefs: $facilityId');

        if (facilityId.isNotEmpty) {
          // Fetch facility type from facility document
          final facilityDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(facilityId)
              .get();

          if (facilityDoc.exists) {
            final data = facilityDoc.data();
            if (mounted) {
              setState(() {
                currentFacilityId = facilityId;
                _facilityType = data?['type'] as String?;
                _isLoadingFacilityType = false;
              });
              print(
                '✅ [PatientList] Set currentFacilityId: $currentFacilityId',
              );
              print('✅ [PatientList] Facility type: $_facilityType');
            }
          } else {
            print(
              '❌ [PatientList] Facility document not found for ID: $facilityId',
            );
          }
        } else {
          print(
            '⚠️ [PatientList] facilityId is empty! Staff needs to re-login.',
          );
        }
      } else {
        print('👥 [PatientList] Admin login detected');
        // Facility admin login - get from Firebase Auth
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          print('👥 [PatientList] Firebase Auth user ID: ${user.uid}');
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (doc.exists) {
            final data = doc.data();
            if (mounted) {
              setState(() {
                currentFacilityId = user.uid;
                _facilityType = data?['type'] as String?;
                _isLoadingFacilityType = false;
              });
              print(
                '✅ [PatientList] Set currentFacilityId: $currentFacilityId',
              );
              print('✅ [PatientList] Facility type: $_facilityType');
            }
          }
        }
      }
    } catch (e) {
      print('❌ [PatientList] Error loading facility data: $e');
      if (mounted) {
        setState(() => _isLoadingFacilityType = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isLifecareInsurance {
    return _facilityType != null &&
        _facilityType!.toLowerCase().trim() == 'lifecare insurance';
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
      // Only facility admin can register patients (this screen is only accessible from facility dashboard)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FacilityRegisterPatientScreen(),
            ),
          );
          // Refresh the list if a patient was registered
          if (result == true && mounted) {
            setState(() {});
          }
        },
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Register Patient'),
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
            child: _isLoadingFacilityType
                ? Center(
                    child: CircularProgressIndicator(
                      color: Colors.purple.shade700,
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
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
                              Icon(
                                Icons.error,
                                size: 64,
                                color: Colors.red[300],
                              ),
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
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (patientSnapshot.hasError) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error,
                                    size: 64,
                                    color: Colors.red[300],
                                  ),
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
                          final filteredPatients = allPatients.where((
                            patientData,
                          ) {
                            final name =
                                (patientData['name'] ??
                                        patientData['fullName'] ??
                                        '')
                                    .toString()
                                    .toLowerCase();
                            final email = (patientData['email'] ?? '')
                                .toString()
                                .toLowerCase();
                            return name.contains(searchQuery) ||
                                email.contains(searchQuery);
                          }).toList();

                          if (filteredPatients.isEmpty &&
                              searchQuery.isNotEmpty) {
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      if (patientData['email'] != null)
                                        Text(
                                          patientData['email'],
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      if (patientData['phone'] != null)
                                        Text(
                                          patientData['phone'],
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
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
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
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
                                  trailing: _isLifecareInsurance
                                      ? PopupMenuButton<String>(
                                          onSelected: (value) =>
                                              _handlePatientAction(
                                                context,
                                                patientData,
                                                value,
                                              ),
                                          itemBuilder: (context) => [
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
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.edit,
                                                    color: Colors.blue,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Edit Patient'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Delete Patient',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      : PopupMenuButton<String>(
                                          onSelected: (value) =>
                                              _handlePatientAction(
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
    print('👥 [PatientList] _getPatientsStream called');
    print('👥 [PatientList] currentFacilityId: "$currentFacilityId"');
    print(
      '👥 [PatientList] Querying: facility_patients where facilityId == "$currentFacilityId"',
    );

    // All facilities get facility-registered patients from facility_patients collection
    return FirebaseFirestore.instance
        .collection('facility_patients')
        .where('facilityId', isEqualTo: currentFacilityId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> _getPatientDetails(
    List<QueryDocumentSnapshot> docs,
  ) async {
    if (docs.isEmpty) {
      return [];
    }

    // All facilities now get docs from facility_patients collection
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        ...data,
        'id': doc.id,
        'patientId': doc.id,
        'serviceRequestCount':
            0, // Can be enhanced to count actual service requests if needed
        'lastVisit': data['updatedAt'] != null
            ? (data['updatedAt'] as Timestamp).toDate()
            : (data['createdAt'] != null
                  ? (data['createdAt'] as Timestamp).toDate()
                  : null),
      };
    }).toList();
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
      case 'edit':
        _editPatient(context, patientData);
        break;
      case 'delete':
        _deletePatient(context, patientData);
        break;
    }
  }

  Future<void> _editPatient(
    BuildContext context,
    Map<String, dynamic> patientData,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPatientScreen(patientData: patientData),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _deletePatient(
    BuildContext context,
    Map<String, dynamic> patientData,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Patient'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${patientData['fullName'] ?? 'this patient'}"?\n\n'
          'This action cannot be undone. All patient data including:\n'
          '• Personal information\n'
          '• Medical records\n'
          '• Appointments\n'
          '• Admissions\n'
          'will be permanently removed from the database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final patientId = patientData['patientId'] ?? patientData['id'];

      // Delete from facility_patients collection
      await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(patientId)
          .delete();

      // Delete related admissions
      final admissions = await FirebaseFirestore.instance
          .collection('admissions')
          .where('patientId', isEqualTo: patientId)
          .get();

      for (var admission in admissions.docs) {
        await admission.reference.delete();
      }

      // Delete related appointments
      final appointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .get();

      for (var appointment in appointments.docs) {
        await appointment.reference.delete();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Patient "${patientData['fullName']}" deleted successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting patient: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                        currentUser.uid: 'facility',
                        '${patientData['id']}': 'patient',
                      },
                      'participantNames': {
                        currentUser.uid: 'Facility',
                        '${patientData['id']}':
                            patientData['name'] ?? 'Unknown Patient',
                      },
                      'lastMessage': messageController.text.trim(),
                      'lastMessageSenderId': currentUser.uid,
                      'lastMessageAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                      'unreadCount': {
                        currentUser.uid: 0,
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

// =====================================================
// Edit Patient Screen
// =====================================================
class EditPatientScreen extends StatefulWidget {
  final Map<String, dynamic> patientData;

  const EditPatientScreen({super.key, required this.patientData});

  @override
  State<EditPatientScreen> createState() => _EditPatientScreenState();
}

class _EditPatientScreenState extends State<EditPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _registrationNumberController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _emergencyContactController;
  late final TextEditingController _emergencyContactNameController;

  String? _selectedGender;
  String? _selectedBloodGroup;
  DateTime? _dateOfBirth;
  bool _isSubmitting = false;
  String? _originalRegistrationNumber;

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroupOptions = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    _registrationNumberController = TextEditingController(
      text: widget.patientData['registrationNumber'] ?? '',
    );
    _originalRegistrationNumber = widget.patientData['registrationNumber'];
    _fullNameController = TextEditingController(
      text: widget.patientData['fullName'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.patientData['email'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.patientData['phone'] ?? '',
    );
    _addressController = TextEditingController(
      text: widget.patientData['address'] ?? '',
    );
    _emergencyContactController = TextEditingController(
      text: widget.patientData['emergencyContact'] ?? '',
    );
    _emergencyContactNameController = TextEditingController(
      text: widget.patientData['emergencyContactName'] ?? '',
    );
    _selectedGender = widget.patientData['gender'];
    _selectedBloodGroup = widget.patientData['bloodGroup'];

    if (widget.patientData['dateOfBirth'] != null) {
      try {
        if (widget.patientData['dateOfBirth'] is Timestamp) {
          _dateOfBirth = (widget.patientData['dateOfBirth'] as Timestamp)
              .toDate();
        } else if (widget.patientData['dateOfBirth'] is String) {
          _dateOfBirth = DateTime.parse(widget.patientData['dateOfBirth']);
        }
      } catch (e) {
        // Handle date parsing error
      }
    }
  }

  @override
  void dispose() {
    _registrationNumberController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _emergencyContactNameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _dateOfBirth ??
          DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  Future<bool> _checkRegistrationNumberExists(String registrationNumber) async {
    // Skip check if registration number hasn't changed
    if (registrationNumber == _originalRegistrationNumber) {
      return false;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    final query = await FirebaseFirestore.instance
        .collection('facility_patients')
        .where('facilityId', isEqualTo: currentUser.uid)
        .where('registrationNumber', isEqualTo: registrationNumber)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  Future<void> _updatePatient() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select date of birth'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select gender'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if registration number is already in use
    final registrationNumber = _registrationNumberController.text.trim();
    final exists = await _checkRegistrationNumberExists(registrationNumber);

    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Registration number "$registrationNumber" is already assigned to another patient',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final patientId =
          widget.patientData['patientId'] ?? widget.patientData['id'];

      await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(patientId)
          .update({
            'registrationNumber': registrationNumber,
            'fullName': _fullNameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'dateOfBirth': Timestamp.fromDate(_dateOfBirth!),
            'gender': _selectedGender,
            'bloodGroup': _selectedBloodGroup,
            'emergencyContact': _emergencyContactController.text.trim(),
            'emergencyContactName': _emergencyContactNameController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating patient: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Patient'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _registrationNumberController,
              decoration: const InputDecoration(
                labelText: 'Registration Number *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Registration number is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Full name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Phone number is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wc),
              ),
              items: _genderOptions.map((gender) {
                return DropdownMenuItem(value: gender, child: Text(gender));
              }).toList(),
              onChanged: (value) => setState(() => _selectedGender = value),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake),
              title: Text(
                _dateOfBirth == null
                    ? 'Date of Birth *'
                    : 'DOB: ${DateFormat('MMM dd, yyyy').format(_dateOfBirth!)}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedBloodGroup,
              decoration: const InputDecoration(
                labelText: 'Blood Group',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.bloodtype),
              ),
              items: _bloodGroupOptions.map((bloodGroup) {
                return DropdownMenuItem(
                  value: bloodGroup,
                  child: Text(bloodGroup),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedBloodGroup = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyContactNameController,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyContactController,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_in_talk),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _updatePatient,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Update Patient',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
