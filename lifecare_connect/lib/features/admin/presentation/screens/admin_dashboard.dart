// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, prefer_const_literals_to_create_immutables, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}


class _AdminDashboardState extends State<AdminDashboard> {
  String _adminName = 'Admin';
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAdminDocument();
      _fetchAdminName();
      _listenForUnreadMessages();
    });
  }

  void _listenForUnreadMessages() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userId = user.uid;
    FirebaseFirestore.instance
        .collection('messages')
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .listen((snapshot) {
      int totalUnread = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;
        if (unreadCounts != null && unreadCounts[userId] != null) {
          totalUnread += unreadCounts[userId] is int ? unreadCounts[userId] as int : 0;
        }
      }
      if (mounted) {
        setState(() {
          _unreadCount = totalUnread;
        });
      }
    });
  }

  Future<void> _checkAdminDocument() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Admin user exists but no Firestore document was found."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _fetchAdminName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      final data = userDoc.data()!;
      setState(() {
        _adminName = data['name'] ?? 'Admin';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        backgroundColor: Colors.teal,
        actions: [
          // Messages IconButton with unread badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.message),
                tooltip: 'Messages',
                onPressed: () => context.push('/admin_dashboard/messages'),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.email),
            tooltip: 'Send Email',
            onPressed: () => _showEmailDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.goNamed('admin-settings'),
          ),
      IconButton(
        icon: Icon(Icons.logout),
        tooltip: 'Logout',
        onPressed: () => _confirmLogout(context),
      ),
    ],
  ),
  body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            Text(
              'Welcome, $_adminName!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            DashboardTile(
              icon: Icons.person,
              title: 'Approve Accounts',
              subtitle: 'Review all pending account requests',
              onTap: () => context.push('/admin_dashboard/approvals'),
            ),
            DashboardTile(
              icon: Icons.add_business,
              title: 'Register Health Facility',
              subtitle: 'Add a new health facility to the system',
              onTap: () => context.push('/admin_dashboard/register_facility'),
            ),
            DashboardTile(
              icon: Icons.school,
              title: 'Training Materials',
              subtitle: 'View or upload training materials',
              onTap: () => context.push('/admin_dashboard/upload_training'),
            ),
            DashboardTile(
              icon: Icons.message,
              title: 'Messages',
              subtitle: 'View and manage messages',
              onTap: () => context.push('/admin_dashboard/messages'),
            ),
            DashboardTile(
              icon: Icons.analytics,
              title: 'Reports & Analytics',
              subtitle: 'Comprehensive system analytics and reporting',
              onTap: () => context.push('/admin_dashboard/reports_analytics'),
            ),
            DashboardTile(
              icon: Icons.account_balance,
              title: 'Finance',
              subtitle: 'Manage financial transactions',
              onTap: () => _showComingSoonDialog(context, 'Finance'),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text("Logout"),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.upcoming, color: Colors.teal),
            SizedBox(width: 8),
            Text('Coming Soon'),
          ],
        ),
        content: Text(
          '$feature feature is under development and will be available in a future update.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }

  void _showEmailDialog(BuildContext context) {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    String selectedRole = 'all';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedRole,
              items: [
                DropdownMenuItem(value: 'all', child: Text('All Users')),
                DropdownMenuItem(value: 'doctor', child: Text('Doctors')),
                DropdownMenuItem(value: 'chw', child: Text('CHWs')),
                DropdownMenuItem(value: 'facility', child: Text('Facilities')),
                DropdownMenuItem(value: 'patient', child: Text('Patients')),
              ],
              onChanged: (value) => selectedRole = value ?? 'all',
              decoration: InputDecoration(labelText: 'Recipient Group'),
            ),
            TextField(
              controller: subjectController,
              decoration: InputDecoration(labelText: 'Subject'),
            ),
            TextField(
              controller: messageController,
              decoration: InputDecoration(labelText: 'Message'),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: Text('Send'),
            onPressed: () async {
              final shouldSend = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Confirm Send'),
                  content: Text('Are you sure you want to send this email to the selected group?'),
                  actions: [
                    TextButton(
                      child: Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    ElevatedButton(
                      child: Text('Send'),
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              );
              if (shouldSend == true) {
                Navigator.of(context).pop();
                await _sendBulkEmail(selectedRole, subjectController.text, messageController.text);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendBulkEmail(String role, String subject, String message) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west2');
      final result = await functions
        .httpsCallable('sendBulkEmail')
        .call({'role': role, 'subject': subject, 'message': message});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email sent: ${result.data['sent']} success, ${result.data['failed']} failed'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send email: $e'), backgroundColor: Colors.red)
      );
    }
  }
}

class DashboardTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const DashboardTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        leading: Icon(icon, size: 32, color: Colors.teal),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
