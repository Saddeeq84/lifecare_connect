import 'chw_wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/presentation/screens/ai_assistant_screen.dart';
import 'chw_registered_patients_screen.dart';
import 'chw_service_management_screen.dart';
import 'chw_reports_dashboard_screen.dart';

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
            final unreadCounts =
                data['unreadCounts'] as Map<String, dynamic>? ?? {};
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

  void _showSubmenu(BuildContext context, Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final submenu = item['submenu'] as List<Map<String, dynamic>>;
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  item['title'] as String,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ),
              ...submenu.map((subItem) {
                return ListTile(
                  leading: Icon(
                    subItem['icon'] as IconData,
                    color: Colors.teal,
                  ),
                  title: Text(subItem['title'] as String),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    if (subItem['route'] == '/chw_dashboard/ask_ai') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AIAssistantScreen(
                            assistantType: AIAssistantType.chw,
                          ),
                        ),
                      );
                    } else if (subItem['route'] ==
                        '/chw_dashboard/my_patients') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CHWRegisteredPatientsScreen(),
                        ),
                      );
                    } else if (subItem['route'] ==
                        '/chw_dashboard/take_course') {
                      // Will be implemented in the next step
                      context.go(subItem['route'] as String);
                    } else {
                      context.go(subItem['route'] as String);
                    }
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
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
        'icon': Icons.people,
        'title': 'Patients',
        'route': '/chw_dashboard/patients',
        'subtitle': 'View patients and register new ones',
        'hasSubmenu': true,
        'submenu': [
          {
            'icon': Icons.people,
            'title': 'My Registered Patients',
            'route': '/chw_dashboard/my_patients',
          },
          {
            'icon': Icons.list,
            'title': 'Facility Patient List',
            'route': '/chw_dashboard/patients',
          },
        ],
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
        'icon': Icons.health_and_safety,
        'title': 'Doctor Consultations',
        'route': '/chw_dashboard/doctor_consultations',
        'subtitle': 'Manage consultations with doctors',
      },
      {
        'icon': Icons.school,
        'title': 'Training',
        'route': '/chw_dashboard/training',
        'subtitle': 'Training resources and AI assistant',
        'hasSubmenu': true,
        'submenu': [
          {
            'icon': Icons.library_books,
            'title': 'Training Materials',
            'route': '/chw_dashboard/training',
          },
          {
            'icon': Icons.play_lesson,
            'title': 'Take Course',
            'route': '/chw_dashboard/take_course',
          },
          {
            'icon': Icons.smart_toy,
            'title': 'Ask AI Assistant',
            'route': '/chw_dashboard/ask_ai',
          },
        ],
      },
      {
        'icon': Icons.analytics,
        'title': 'Analytics & Reports',
        'route': '/chw_dashboard/analytics',
        'subtitle': 'View performance analytics and generate reports',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('CHW Dashboard'),
        backgroundColor: Colors.teal,
        actions: [
          // Service Management icon
          IconButton(
            icon: const Icon(Icons.medical_services),
            tooltip: 'Service Management',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CHWServiceManagementScreen(),
                ),
              );
            },
          ),
          // Wallet icon
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Wallet',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChwWalletScreen()),
              );
            },
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseAuth.instance.currentUser == null
                ? null
                : FirebaseFirestore.instance
                      .collection('notifications')
                      .where(
                        'userId',
                        isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                      )
                      .where('read', isEqualTo: false)
                      .snapshots(),
            builder: (context, snapshot) {
              final unreadNotifications = snapshot.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    tooltip: 'Notifications',
                    onPressed: () => context.go('/chw_dashboard/notifications'),
                  ),
                  if (unreadNotifications > 0)
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
                            unreadNotifications > 99
                                ? '99+'
                                : '$unreadNotifications',
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
              );
            },
          ),
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
                trailing: Icon(
                  item['hasSubmenu'] == true
                      ? Icons.expand_more
                      : Icons.arrow_forward_ios,
                  size: 18,
                  color: Colors.teal,
                ),
                onTap: () {
                  if (item['hasSubmenu'] == true) {
                    _showSubmenu(context, item);
                  } else if (item['route'] == '/chw_dashboard/ask_ai') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AIAssistantScreen(
                          assistantType: AIAssistantType.chw,
                        ),
                      ),
                    );
                  } else if (item['route'] == '/chw_dashboard/analytics') {
                    // Navigate to Reports Dashboard
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CHWReportsDashboardScreen(
                            chwId: user.uid,
                            chwName: user.displayName ?? 'CHW',
                          ),
                        ),
                      );
                    }
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
