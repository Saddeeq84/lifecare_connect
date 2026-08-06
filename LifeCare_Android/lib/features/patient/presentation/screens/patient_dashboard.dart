import 'package:flutter/material.dart';
import 'patient_appointment_screen.dart';
import 'patient_education_screen.dart';
import 'my_health_tab.dart';
import 'package:lifecare_connect/features/patient/presentation/screens/patient_consultations_screen.dart'
    as consult;
import 'patient_referrals_screen.dart';
import 'patient_settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'patient_wallet_screen.dart';
import 'patient_analytics_screen.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/presentation/screens/ai_assistant_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientDashboard extends StatelessWidget {
  const PatientDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const PatientDashboardMainView();
  }
}

class PatientDashboardMainView extends StatefulWidget {
  const PatientDashboardMainView({super.key});

  @override
  State<PatientDashboardMainView> createState() =>
      _PatientDashboardMainViewState();
}

class _PatientDashboardMainViewState extends State<PatientDashboardMainView> {
  // Get user ID from Firebase Auth or SharedPreferences (Termii login)
  Future<String> _getUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return user.uid;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? '';
  }

  @override
  void initState() {
    super.initState();
    _listenForUnreadMessages();
  }

  void _listenForUnreadMessages() async {
    final userId = await _getUserId();
    if (userId.isEmpty) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Dashboard'),
        backgroundColor: Colors.teal,
        actions: [
          // Wallet icon
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Wallet',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PatientWalletScreen(),
                ),
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
                  context.goNamed('patient-messages');
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
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PatientSettingsScreen(),
                ),
              );
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
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (shouldLogout == true) {
                // Sign out from Firebase Auth
                await FirebaseAuth.instance.signOut();

                // Clear SharedPreferences for Termii login users
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('user_id');
                  await prefs.remove('user_phone');
                  await prefs.remove('user_role');
                  print('✅ SharedPreferences cleared for logout');
                } catch (e) {
                  print('⚠️ Error clearing SharedPreferences: $e');
                }

                if (mounted) {
                  context.go('/login');
                }
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to LifeCare Connect!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Access your health services and stay connected',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: dashboardItems.length,
                separatorBuilder: (context, idx) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final item = dashboardItems[idx];
                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 18,
                      ),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: (item['color'] as Color)
                                .withOpacity(0.18),
                            child: Icon(
                              item['icon'],
                              color: item['color'],
                              size: 32,
                            ),
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
                        item['label'],
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[900],
                            ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.grey,
                      ),
                      onTap: () {
                        final action = item['action'];
                        if (action != null && action is String) {
                          _handleDashboardItemTap(context, action);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _showChatBadge = false;
  int _unreadCount = 0;

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: Text('$feature is coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get dashboardItems => [
    {
      'icon': Icons.health_and_safety,
      'label': 'My Health',
      'action': 'health',
      'color': Colors.red,
    },
    {
      'icon': Icons.calendar_today,
      'label': 'Appointments',
      'action': 'appointments',
      'color': Colors.blue,
      // 'showBadge': _showAppointmentBadge, // Not used in this patch
    },
    {
      'icon': Icons.medical_services,
      'label': 'Consultations',
      'action': 'consultations',
      'color': Colors.teal,
    },
    {
      'icon': Icons.transfer_within_a_station,
      'label': 'Referrals',
      'action': 'referrals',
      'color': Colors.indigo,
    },
    {
      'icon': Icons.school,
      'label': 'Education',
      'action': 'education',
      'color': Colors.orange,
    },
    {
      'icon': Icons.analytics,
      'label': 'Health Analytics',
      'action': 'analytics',
      'color': Colors.green,
    },
  ];

  void _handleDashboardItemTap(BuildContext context, String action) async {
    final userId = await _getUserId();

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to continue')),
      );
      return;
    }

    switch (action) {
      case 'health':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MyHealthTab(patientId: userId),
          ),
        );
        break;
      case 'appointments':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientAppointmentsScreen(userId: userId),
          ),
        );
        break;
      case 'consultations':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => consult.PatientConsultationsScreen(),
          ),
        );
        break;
      case 'referrals':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientReferralsScreen(userId: userId),
          ),
        );
        break;
      case 'education':
        // Show submenu for Education
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Health Education',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.library_books,
                      color: Colors.orange,
                    ),
                    title: const Text('Educational Materials'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PatientEducationScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.smart_toy, color: Colors.orange),
                    title: const Text('Ask AI Assistant'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AIAssistantScreen(
                            assistantType: AIAssistantType.patient,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
        break;
      case 'analytics':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PatientAnalyticsScreen(),
          ),
        );
        break;
      case 'chatbot':
        _showComingSoonDialog(context, 'AI Chatbot');
        break;
    }
  }
}
