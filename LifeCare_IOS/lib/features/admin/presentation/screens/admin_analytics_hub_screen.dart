// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'admin_reports_analytics_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
              icon: Icon(Icons.analytics_outlined, size: 22),
              text: 'System Reports',
            ),
            Tab(
              icon: Icon(Icons.people_outline, size: 22),
              text: 'User Analytics',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // System Reports Tab
          AdminReportsAnalyticsScreen(),

          // User Analytics Tab
          AdminUsersManagementScreen(),
        ],
      ),
    );
  }
}
