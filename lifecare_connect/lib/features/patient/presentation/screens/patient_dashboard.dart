import 'package:flutter/material.dart';
import 'patient_appointment_screen.dart';
import 'patient_education_screen.dart';
import 'my_health_tab.dart';
import 'package:lifecare_connect/features/patient/presentation/screens/patient_consultations_screen.dart'
    as consult;
import 'patient_referrals_screen.dart';
import 'package:lifecare_connect/features/shared/presentation/screens/messages_screen.dart';
import 'patient_settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'patient_wallet_screen.dart';
import 'package:go_router/go_router.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Dashboard'),
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
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MessagesScreen()));
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
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientSettingsScreen()));
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
                      child: const Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (shouldLogout == true) {
                await FirebaseAuth.instance.signOut();
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
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
                            backgroundColor: (item['color'] as Color).withOpacity(0.18),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
  // bool _showAppointmentBadge = false; // Unused, can be removed

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
      'icon': Icons.school,
      'label': 'Education',
      'action': 'education',
      'color': Colors.orange,
    },
    {
      'icon': Icons.message,
      'label': 'Messages',
      'action': 'messages',
      'color': Colors.teal,
      'showBadge': _showChatBadge,
    },
    {
      'icon': Icons.account_balance_wallet,
      'label': 'Wallet',
      'action': 'wallet',
      'color': Colors.amber,
    },
  ];

  void _handleDashboardItemTap(BuildContext context, String action) {
    switch (action) {
      case 'health':
        final currentUser = FirebaseAuth.instance.currentUser;
        final patientId = currentUser?.uid ?? '';
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MyHealthTab(patientId: patientId)),
        );
        break;
      case 'appointments':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PatientAppointmentsScreen()),
        );
        break;
      case 'consultations':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => consult.PatientConsultationsScreen()),
        );
        break;
      case 'referrals':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PatientReferralsScreen(),
          ),
        );
        break;
      case 'education':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PatientEducationScreen(),
          ),
        );
        break;
      case 'messages':
        setState(() => _showChatBadge = false);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MessagesScreen()),
        );
        break;
      case 'wallet':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PatientWalletScreen()),
        );
        break;
      case 'chatbot':
        _showComingSoonDialog(context, 'AI Chatbot');
        break;
    }
  }
}

