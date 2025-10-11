// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminStaffScreen extends StatelessWidget {
  const AdminStaffScreen({super.key});

  Widget _buildStaffList(String role) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: role)
          .orderBy('createdAt', descending: true)
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

        final staffList = snapshot.data?.docs ?? [];

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
                  'No ${role == 'doctor' ? 'doctors' : 'CHWs'} found',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: staffList.length,
          itemBuilder: (context, index) {
            final staff = staffList[index].data() as Map<String, dynamic>;
            final staffId = staffList[index].id;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
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
                  staff['displayName'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(staff['email'] ?? 'No email'),
                    if (staff['specialization'] != null)
                      Text('Specialization: ${staff['specialization']}'),
                    if (staff['facilityName'] != null)
                      Text('Facility: ${staff['facilityName']}'),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'view':
                        _showStaffDetails(context, staff, staffId);
                        break;
                      case 'edit':
                        _editStaff(context, staff, staffId);
                        break;
                      case 'delete':
                        _deleteStaff(
                          context,
                          staffId,
                          staff['displayName'] ?? 'Unknown',
                        );
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Text('View Details'),
                    ),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showStaffDetails(
    BuildContext context,
    Map<String, dynamic> staff,
    String staffId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(staff['displayName'] ?? 'Staff Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${staff['email'] ?? 'N/A'}'),
            Text('Role: ${staff['role'] ?? 'N/A'}'),
            if (staff['specialization'] != null)
              Text('Specialization: ${staff['specialization']}'),
            if (staff['facilityName'] != null)
              Text('Facility: ${staff['facilityName']}'),
            if (staff['phone'] != null) Text('Phone: ${staff['phone']}'),
            Text('Staff ID: $staffId'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _editStaff(
    BuildContext context,
    Map<String, dynamic> staff,
    String staffId,
  ) {
    // Placeholder for edit functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality not implemented yet')),
    );
  }

  void _deleteStaff(BuildContext context, String staffId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff'),
        content: Text('Are you sure you want to delete $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(staffId)
                    .delete();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Staff deleted successfully')),
                );
              } catch (e) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting staff: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Staff Directory'),
          backgroundColor: Colors.teal,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.local_hospital), text: 'Doctors'),
              Tab(icon: Icon(Icons.people), text: 'CHWs'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildStaffList('doctor'), _buildStaffList('chw')],
        ),
      ),
    );
  }
}
