import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/presentation/screens/ai_assistant_screen.dart';
import '../../../shared/presentation/widgets/resource_popup_button.dart';
import 'public_health_reports_screen.dart';
import '../widgets/staff_password_change_dialog.dart';

class PublicHealthDashboardScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const PublicHealthDashboardScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<PublicHealthDashboardScreen> createState() =>
      _PublicHealthDashboardScreenState();
}

class _PublicHealthDashboardScreenState
    extends State<PublicHealthDashboardScreen> {
  int _totalImmunizations = 0;
  int _scheduledToday = 0;
  int _completedToday = 0;
  int _pendingSurveys = 0;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _loadingStats = true);

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Load immunization statistics
      final immunizationsSnapshot = await FirebaseFirestore.instance
          .collection('immunizations')
          .where('facilityId', isEqualTo: widget.facilityId)
          .get();

      final scheduledTodaySnapshot = await FirebaseFirestore.instance
          .collection('immunizations')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('scheduledDate', isGreaterThanOrEqualTo: todayStart)
          .where('scheduledDate', isLessThan: todayEnd)
          .get();

      final completedTodaySnapshot = await FirebaseFirestore.instance
          .collection('immunizations')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('completedDate', isGreaterThanOrEqualTo: todayStart)
          .where('completedDate', isLessThan: todayEnd)
          .where('status', isEqualTo: 'completed')
          .get();

      // Load survey statistics
      final surveysSnapshot = await FirebaseFirestore.instance
          .collection('public_health_surveys')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'pending')
          .get();

      setState(() {
        _totalImmunizations = immunizationsSnapshot.docs.length;
        _scheduledToday = scheduledTodaySnapshot.docs.length;
        _completedToday = completedTodaySnapshot.docs.length;
        _pendingSurveys = surveysSnapshot.docs.length;
        _loadingStats = false;
      });
    } catch (e) {
      print('Error loading public health statistics: $e');
      setState(() => _loadingStats = false);
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      try {
        await FirebaseAuth.instance.signOut();
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        title: Text('${widget.facilityName} - Public Health'),
        actions: [
          const ResourcePopupButton(assistantType: AIAssistantType.doctor),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Navigate to notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => StaffPasswordChangeDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              _buildWelcomeCard(),
              const SizedBox(height: 20),

              // Statistics Cards
              _buildStatisticsSection(),
              const SizedBox(height: 24),

              // Quick Actions Section
              const Text(
                'Key Functional Areas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Following WHO and Nigeria CDC Guidelines',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              _buildDashboardCards(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[700]!, Colors.green[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.staffName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, MMM d, y').format(now),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.health_and_safety,
              size: 48,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return _loadingStats
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Immunizations',
                      _totalImmunizations.toString(),
                      Icons.vaccines,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Scheduled Today',
                      _scheduledToday.toString(),
                      Icons.calendar_today,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Completed Today',
                      _completedToday.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Pending Surveys',
                      _pendingSurveys.toString(),
                      Icons.assignment,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCards() {
    final dashboardItems = [
      {
        'title': 'Immunization Management',
        'subtitle': 'Track vaccines, schedules & coverage',
        'icon': Icons.vaccines,
        'color': Colors.blue[600]!,
        'route': '/immunization_management',
      },
      {
        'title': 'Environmental Surveillance',
        'subtitle': 'Monitor sanitation & environmental health',
        'icon': Icons.eco,
        'color': Colors.green[600]!,
        'route': '/environmental_surveillance',
      },
      {
        'title': 'Disease Surveillance',
        'subtitle': 'Track disease patterns & outbreaks',
        'icon': Icons.monitor_heart,
        'color': Colors.orange[600]!,
        'route': '/disease_surveillance',
      },
      {
        'title': 'Outbreak Investigation',
        'subtitle': 'Investigate & respond to outbreaks',
        'icon': Icons.crisis_alert,
        'color': Colors.purple[600]!,
        'route': '/outbreak_investigation',
      },
      {
        'title': 'Health Education',
        'subtitle': 'Community health education programs',
        'icon': Icons.school,
        'color': Colors.teal[600]!,
        'route': '/health_education',
      },
      {
        'title': 'Health Outreach',
        'subtitle': 'Community outreach & engagement',
        'icon': Icons.groups,
        'color': Colors.indigo[600]!,
        'route': '/health_outreach',
      },
      {
        'title': 'Reports',
        'subtitle': 'View public health surveillance data',
        'icon': Icons.assessment_outlined,
        'color': Colors.grey[700]!,
        'route': 'public_health_reports',
      },
    ];

    return Column(
      children: dashboardItems.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildDashboardCard(
            title: item['title'] as String,
            subtitle: item['subtitle'] as String,
            icon: item['icon'] as IconData,
            color: item['color'] as Color,
            onTap: () {
              if (item['route'] == 'public_health_reports') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PublicHealthReportsScreen(
                      facilityId: widget.facilityId,
                      facilityName: widget.facilityName,
                    ),
                  ),
                );
                return;
              }
              GoRouter.of(context).push(
                item['route'] as String,
                extra: {
                  'facilityId': widget.facilityId,
                  'facilityName': widget.facilityName,
                  'staffId': widget.staffId,
                  'staffName': widget.staffName,
                  if (item['initialTabIndex'] != null)
                    'initialTabIndex': item['initialTabIndex'],
                },
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 28, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade400,
        ),
        onTap: onTap,
      ),
    );
  }
}

class DashboardItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  DashboardItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
