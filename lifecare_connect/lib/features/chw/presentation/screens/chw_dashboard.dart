

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CHWDashboard extends StatefulWidget {
  const CHWDashboard({super.key});

  @override
  State<CHWDashboard> createState() => _CHWDashboardState();
}

class _CHWDashboardState extends State<CHWDashboard> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardItems = [
      {
        'icon': Icons.calendar_today,
        'title': 'Appointments',
        'route': '/chw_dashboard/appointments',
        'subtitle': 'View and manage appointments',
      },
      {
        'icon': Icons.message,
        'title': 'Messages',
        'route': '/chw_dashboard/messages',
        'subtitle': 'Communicate with patients',
      },
      {
        'icon': Icons.people,
        'title': 'Patients',
        'route': '/chw_dashboard/patients',
        'subtitle': 'Patient list and details',
      },

      {
        'icon': Icons.person_add,
        'title': 'Register Patient',
        'route': '/chw_dashboard/register_patient',
        'subtitle': 'Add a new patient',
      },
      {
        'icon': Icons.local_hospital,
        'title': 'Referrals',
        'route': '/chw_dashboard/referrals',
        'subtitle': 'Refer patients to facilities',
      },
      {
        'icon': Icons.medical_services,
        'title': 'Consultations',
        'route': '/chw_dashboard/consultations',
        'subtitle': 'Record consultations',
      },
      {
        'icon': Icons.school,
        'title': 'Training',
        'route': '/chw_dashboard/training',
        'subtitle': 'Access training resources',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('CHW Dashboard'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              context.go('/chw_dashboard/profile');
            },
          ),
           IconButton(
             icon: const Icon(Icons.account_balance_wallet),
             tooltip: 'Wallet',
             onPressed: () {
               showDialog(
                 context: context,
                 builder: (BuildContext context) {
                   return AlertDialog(
                     title: const Text('Wallet'),
                     content: const Text('Coming Soon'),
                     actions: [
                       TextButton(
                         onPressed: () => Navigator.of(context).pop(),
                         child: const Text('OK'),
                       ),
                     ],
                   );
                 },
               );
             },
           ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              context.go('/chw_dashboard/settings');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    TextButton(
                      child: const Text('Logout'),
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              );
              if (shouldLogout == true) {

                try {
                  await FirebaseAuth.instance.signOut();
                } catch (e) {

                }
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.separated(
          itemCount: dashboardItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = dashboardItems[index];
            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(item['icon'] as IconData, color: Colors.teal, size: 32),
                title: Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(item['subtitle'] as String),
                trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.teal),
                onTap: () {
                    context.go(item['route'] as String);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

