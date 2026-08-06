// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'admin_analytics_screen.dart';
import 'admin_reports_analytics_screen.dart';
import 'admin_training_analytics_screen.dart';
import 'admin_users_management_screen.dart';

class AdminAnalyticsHubScreen extends StatefulWidget {
  const AdminAnalyticsHubScreen({super.key});

  @override
  State<AdminAnalyticsHubScreen> createState() =>
      _AdminAnalyticsHubScreenState();
}

class _AdminAnalyticsHubScreenState extends State<AdminAnalyticsHubScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final Map<int, Widget> _loadedTabs = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analytics Hub',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3.0,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          tabs: [
            Tab(
              icon: Icon(Icons.dashboard_outlined, size: 22),
              text: 'Overview',
            ),
            Tab(
              icon: Icon(Icons.assessment_outlined, size: 22),
              text: 'System Reports',
            ),
            Tab(
              icon: Icon(Icons.analytics_outlined, size: 22),
              text: 'User Analytics',
            ),
            Tab(
              icon: Icon(Icons.people_outline, size: 22),
              text: 'User Management',
            ),
            Tab(icon: Icon(Icons.school_outlined, size: 22), text: 'Training'),
          ],
        ),
      ),
      body: _buildCurrentTab(),
    );
  }

  Widget _buildCurrentTab() {
    final index = _tabController.index;
    return _loadedTabs.putIfAbsent(index, () {
      switch (index) {
        case 1:
          return const AdminReportsAnalyticsScreen();
        case 2:
          return const AdminAnalyticsScreen();
        case 3:
          return const AdminUsersManagementScreen();
        case 4:
          return const AdminTrainingAnalyticsScreen();
        case 0:
        default:
          return _buildOverviewTab();
      }
    });
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.teal.shade100),
          ),
          child: Row(
            children: [
              Icon(Icons.insights_outlined, color: Colors.teal.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Open one analytics section at a time for faster loading on weak networks.',
                  style: TextStyle(
                    color: Colors.teal.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildHubTile(
          icon: Icons.assessment_outlined,
          title: 'System Reports',
          subtitle:
              'Overview, platform analytics, users, financials, and printable reports.',
          color: Colors.indigo,
          tabIndex: 1,
        ),
        _buildHubTile(
          icon: Icons.analytics_outlined,
          title: 'User Analytics',
          subtitle:
              'Individual user behavior, activity, appointments, referrals, and engagement.',
          color: Colors.teal,
          tabIndex: 2,
        ),
        _buildHubTile(
          icon: Icons.people_outline,
          title: 'User Management',
          subtitle:
              'Search users, filter by role/activity, and inspect user analytics.',
          color: Colors.blue,
          tabIndex: 3,
        ),
        _buildHubTile(
          icon: Icons.school_outlined,
          title: 'Training Analytics',
          subtitle: 'Training materials, user engagement, courses, and uptake.',
          color: Colors.deepPurple,
          tabIndex: 4,
        ),
      ],
    );
  }

  Widget _buildHubTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required int tabIndex,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          _tabController.animateTo(tabIndex);
          setState(() {});
        },
      ),
    );
  }
}
