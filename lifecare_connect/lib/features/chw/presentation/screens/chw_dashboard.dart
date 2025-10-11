import 'chw_wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chw_ask_ai_screen.dart';

class CHWDashboard extends StatefulWidget {
  const CHWDashboard({super.key});

  @override
  State<CHWDashboard> createState() => _CHWDashboardState();
}

class _CHWDashboardState extends State<CHWDashboard> {
  bool _showChatBadge = false;
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
        .where('participants', arrayContains: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      int totalUnread = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final unreadCounts = data['unreadCounts'] as Map<String, dynamic>? ?? {};
        final unread = unreadCounts[userId] ?? 0;
        if (unread is int && unread > 0) {
          totalUnread += unread;
        }
      }
      if (mounted) {
        setState(() {
          _unreadCount = totalUnread;
          _showChatBadge = totalUnread > 0;
        });
      }
    });
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
        'showBadge': _showChatBadge,
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
      {
        'icon': Icons.smart_toy,
        'title': 'Ask AI',
        'route': '/chw_dashboard/ask_ai',
        'subtitle': 'Get instant answers from AI (Coming Soon)',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('CHW Dashboard'),
        backgroundColor: Colors.teal,
        actions: [
          // Message icon with badge and count
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.message),
                tooltip: 'Messages',
                onPressed: () {
                  setState(() {
                    _showChatBadge = false;
                    _unreadCount = 0;
                  });
                  context.go('/chw_dashboard/messages');
                },
              ),
              if (_showChatBadge && _unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ChwWalletScreen(),
                ),
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
                } catch (e) {}
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
                leading: Stack(
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      color: Colors.teal,
                      size: 32,
                    ),
                    if (item['showBadge'] == true)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  item['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(item['subtitle'] as String),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: Colors.teal,
                ),
                onTap: () {
                  if (item['route'] == '/chw_dashboard/ask_ai') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CHWAskAIScreen()),
                    );
                  } else {
                    context.go(item['route'] as String);
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
