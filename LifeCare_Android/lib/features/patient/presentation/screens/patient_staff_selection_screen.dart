// ignore_for_file: prefer_const_constructors, avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../sharedscreen/staff_list_widget.dart';
import 'comprehensive_book_appointment_screen.dart';

class PatientStaffSelectionScreen extends StatefulWidget {
  const PatientStaffSelectionScreen({super.key});

  @override
  State<PatientStaffSelectionScreen> createState() =>
      _PatientStaffSelectionScreenState();
}

class _PatientStaffSelectionScreenState
    extends State<PatientStaffSelectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onStaffSelected(DocumentSnapshot staffDoc) {
    // Navigate to appointment booking with pre-selected provider, but not from referral
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComprehensiveBookAppointmentScreen(
          preSelectedProvider: {
            'id': staffDoc.id,
            'name':
                (staffDoc.data() as Map<String, dynamic>)['fullName'] ??
                'Unknown',
            'type':
                (staffDoc.data() as Map<String, dynamic>)['role'] == 'doctor'
                ? 'Doctor'
                : 'CHW',
            'specialization':
                (staffDoc.data() as Map<String, dynamic>)['specialization'] ??
                'General Practice',
            'location':
                (staffDoc.data() as Map<String, dynamic>)['location'] ??
                'Not specified',
            'rating':
                (staffDoc.data() as Map<String, dynamic>)['rating'] ?? 4.5,
            'image':
                (staffDoc.data() as Map<String, dynamic>)['imageUrl'] ??
                (staffDoc.data() as Map<String, dynamic>)['profileImage'],
            'availability':
                (staffDoc.data() as Map<String, dynamic>)['availability'] ??
                'Available',
            'isApproved':
                (staffDoc.data() as Map<String, dynamic>)['isApproved'] ?? true,
          },
          fromReferral: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Healthcare Provider'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.local_hospital), text: 'Doctors'),
            Tab(icon: Icon(Icons.people), text: 'CHWs'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade50, Colors.teal.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 48,
                  color: Colors.teal.shade700,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Book an Appointment',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select a doctor or community health worker to book your appointment',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Tabs Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Doctors Tab
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available Doctors',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select a doctor to book your appointment',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _buildStaffList('doctor')),
                    ],
                  ),
                ),

                // CHWs Tab
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available Community Health Workers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select a CHW for community-based care and consultation',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _buildStaffList('chw')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffList(String role) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: role)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final allStaffList = snapshot.data?.docs ?? [];

        // Filter for approved staff and exclude rejected users
        final staffList = allStaffList.where((staff) {
          final staffData = staff.data() as Map<String, dynamic>;

          // First check if user is rejected - exclude if so
          if (staffData['isRejected'] == true) {
            return false;
          }

          if (role == 'chw') {
            // CHWs need to be approved or have no approval status (legacy accounts)
            return staffData['isApproved'] ?? true;
          } else {
            // For doctors, check approval (default to true if field doesn't exist)
            return staffData['isApproved'] ?? true;
          }
        }).toList();

        // Sort by name
        staffList.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aName =
              aData['displayName'] ??
              aData['fullName'] ??
              aData['name'] ??
              'Unknown';
          final bName =
              bData['displayName'] ??
              bData['fullName'] ??
              bData['name'] ??
              'Unknown';
          return aName.compareTo(bName);
        });

        if (staffList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  role == 'doctor' ? Icons.local_hospital : Icons.people,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${role == 'doctor' ? 'doctors' : 'CHWs'} available',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: staffList.length,
          itemBuilder: (context, index) {
            final staff = staffList[index];
            final staffData = staff.data() as Map<String, dynamic>;
            final staffName =
                staffData['displayName'] ??
                staffData['fullName'] ??
                staffData['name'] ??
                'Unknown ${role == 'doctor' ? 'Doctor' : 'CHW'}';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: role == 'doctor'
                      ? Colors.blue
                      : Colors.green,
                  child: Icon(
                    role == 'doctor' ? Icons.local_hospital : Icons.people,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  staffName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (staffData['specialization'] != null)
                      Text('Specialization: ${staffData['specialization']}'),
                    if (staffData['facilityName'] != null)
                      Text('Facility: ${staffData['facilityName']}'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text('${staffData['rating'] ?? 4.5}'),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Available',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _onStaffSelected(staff),
              ),
            );
          },
        );
      },
    );
  }
}
