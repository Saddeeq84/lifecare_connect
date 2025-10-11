// Facility Dashboard Screen
// Main dashboard for facility users, provides navigation to facility features.

// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'facility_profile_screen.dart';
import 'facility_settings_screen.dart';
import 'facility_booking_screen.dart';
import 'facility_messages_screen.dart';
import 'facility_patient_list_screen.dart';
import 'facility_analytics_screen.dart';
import 'facility_services_screen.dart';
import 'facility_staff_list.dart';
import 'package:go_router/go_router.dart';

Future<void> _handleLogout(BuildContext context) async {
  _showLogoutDialog(context);
}

void _showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.logout, color: Colors.red),
          SizedBox(width: 8),
          Text('Logout'),
        ],
      ),
      content: Text('Are you sure you want to logout from your account?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context); // Close the dialog before logging out
            await _performLogout(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text('Logout'),
        ),
      ],
    ),
  );
}

Future<void> _performLogout(BuildContext context) async {
  try {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      context.go('/login');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logout failed: ${e.toString()}"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

class FacilityDashboard extends StatefulWidget {
  const FacilityDashboard({super.key});

  @override
  State<FacilityDashboard> createState() => _FacilityDashboardState();
}

class _FacilityDashboardState extends State<FacilityDashboard> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _listenForUnreadMessages();
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
              totalUnread += unreadCounts[userId] is int
                  ? unreadCounts[userId] as int
                  : 0;
            }
          }
          if (mounted) {
            setState(() {
              _unreadCount = totalUnread;
            });
          }
        });
  }

  List<Map<String, dynamic>> get dashboardItems => [
    {"icon": Icons.calendar_today, "label": "Bookings", "action": "bookings"},
    {"icon": Icons.chat, "label": "Messages", "action": "messages"},
    {"icon": Icons.people, "label": "My Patients", "action": "patients"},
    {"icon": Icons.medical_services, "label": "Services", "action": "services"},
    {
      "icon": Icons.analytics,
      "label": "Reports & Analytics",
      "action": "analytics",
    },
    {"icon": Icons.group, "label": "Staff", "action": "staff"},
    {
      "icon": Icons.account_balance_wallet,
      "label": "Wallet",
      "action": "wallet",
    },
  ];

  void _navigateToProfile(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FacilityProfileScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToSettings(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FacilitySettingsScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToBookings(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FacilityBookingScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening bookings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToMessages(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FacilityMessagesScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening messages: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToPatients(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const FacilityPatientListScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening patient list: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToAnalytics(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const FacilityAnalyticsScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening analytics: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToServices(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FacilityServicesScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening services: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleDashboardItemTap(BuildContext context, String action) {
    switch (action) {
      case 'bookings':
        _navigateToBookings(context);
        break;
      case 'messages':
        _navigateToMessages(context);
        break;
      case 'patients':
        _navigateToPatients(context);
        break;
      case 'analytics':
        _navigateToAnalytics(context);
        break;
      case 'services':
        _navigateToServices(context);
        break;
      case 'staff':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                FacilityStaffListScreen(facilityName: 'chana health center'),
          ),
        );
        break;
      case 'wallet':
        _showComingSoonDialog(context, 'Wallet');
        break;
      default:
        _showComingSoonDialog(context, 'Feature');
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$feature feature is under development and will be available in a future update.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Stay tuned for updates!',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Facility Dashboard"),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        actions: [
          // Messages IconButton with unread badge
          Stack(
            children: [
              IconButton(
                onPressed: () => _navigateToMessages(context),
                icon: const Icon(Icons.chat),
                tooltip: "Messages",
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
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
          // Profile navigation button
          IconButton(
            onPressed: () => _navigateToProfile(context),
            icon: const Icon(Icons.person),
            tooltip: "Profile",
          ),
          // Settings navigation button
          IconButton(
            onPressed: () => _navigateToSettings(context),
            icon: const Icon(Icons.settings),
            tooltip: "Settings",
          ),
          // Logout button
          IconButton(
            onPressed: () => _handleLogout(context),
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: dashboardItems.length,
        separatorBuilder: (context, index) => Divider(height: 1),
        itemBuilder: (context, index) {
          final item = dashboardItems[index];
          return ListTile(
            leading: Icon(item["icon"], color: Colors.teal.shade800, size: 28),
            title: Text(
              item["label"],
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: Colors.grey,
            ),
            onTap: () => _handleDashboardItemTap(context, item['action']),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }
}
