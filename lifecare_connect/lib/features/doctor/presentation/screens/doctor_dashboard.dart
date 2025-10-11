import 'doctor_wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

// --- DashboardItem class ---
class DashboardItem {
  final IconData icon;
  final String label;
  final String route;

  const DashboardItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

// --- DashboardTile widget ---
class DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const DashboardTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.indigo.shade100,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.shade50,
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.indigo.shade800),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Dashboard items list ---
const List<DashboardItem> _doctorDashboardItems = [
  DashboardItem(
    icon: Icons.people,
    label: 'My Patients',
    route: '/doctor_patients',
  ),
  DashboardItem(
    icon: Icons.calendar_today,
    label: 'Appointments',
    route: '/doctor_dashboard/appointments',
  ),
  DashboardItem(
    icon: Icons.message,
    label: 'Messages',
    route: '/doctor_messages',
  ),
  DashboardItem(
    icon: Icons.send_to_mobile,
    label: 'Referrals',
    route: '/doctor_referrals',
  ),
  DashboardItem(
    icon: Icons.library_books,
    label: 'Clinical Resources',
    route: '/doctor_resources',
  ),
  DashboardItem(
    icon: Icons.analytics,
    label: 'Reports & Analytics',
    route: '/doctor_analytics',
  ),
  DashboardItem(
    icon: Icons.video_call,
    label: 'Consultation',
    route: '/doctor_dashboard/consultation',
  ),
  DashboardItem(
    icon: Icons.account_balance_wallet,
    label: 'Wallet',
    route: '/wallet',
  ),
];

// --- DoctorDashboard widget ---
class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  String doctorName = 'Doctor';
  bool isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDoctorInfo();
    _listenForUnreadMessages();
  }

  Future<void> _loadDoctorInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          final data = doc.data()!;
          setState(() {
            doctorName =
                data['name'] ??
                data['fullName'] ??
                'Dr. ${user.displayName ?? (user.email?.split('@')[0] ?? 'Doctor')}';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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

  Future<void> _logout(BuildContext context) async {
    _showLogoutDialog(context);
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Logout'),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout from your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLogout(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
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
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.upcoming, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Coming Soon'),
          ],
        ),
        content: Text(
          '$feature feature is under development and will be available in a future update.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.indigo)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Doctor Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        actions: [
          // Messages IconButton with unread badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.message, color: Colors.white),
                tooltip: 'Messages',
                onPressed: () => context.push('/doctor_dashboard/messages'),
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
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            tooltip: 'Profile',
            onPressed: () => context.push('/doctor_profile'),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () => context.push('/doctor_dashboard/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : Text(
                      "Welcome, $doctorName",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: _doctorDashboardItems.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _doctorDashboardItems[index];
                  return ListTile(
                    leading: Icon(
                      item.icon,
                      color: Colors.indigo.shade800,
                      size: 28,
                    ),
                    title: Text(
                      item.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      switch (item.route) {
                        case '/doctor_patients':
                          context.push('/doctor_dashboard/patients');
                          break;
                        case '/doctor_appointments':
                          context.push('/doctor_dashboard/appointments');
                          break;
                        case '/doctor_messages':
                          context.push('/doctor_dashboard/messages');
                          break;
                        case '/doctor_referrals':
                          context.push('/doctor_dashboard/referrals');
                          break;
                        case '/doctor_resources':
                          context.push('/doctor_resources');
                          break;
                        case '/doctor_analytics':
                          context.push('/doctor_dashboard/analytics');
                          break;
                        case '/consultation':
                          context.push('/doctor_dashboard/consultation');
                          break;
                        case '/wallet':
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DoctorWalletScreen(),
                            ),
                          );
                          break;
                        default:
                          context.push(item.route);
                      }
                    },
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
            ),
          ],
        ),
      ),
    );
  }
}
