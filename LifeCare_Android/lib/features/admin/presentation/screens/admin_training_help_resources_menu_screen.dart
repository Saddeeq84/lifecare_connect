// ignore_for_file: prefer_const_constructors, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'admin_training_materials_management_screen.dart';
import 'admin_help_videos_screen.dart';
import 'admin_training_analytics_screen.dart';
import 'admin_chw_course_editor_screen.dart';

class AdminTrainingHelpResourcesMenuScreen extends StatefulWidget {
  const AdminTrainingHelpResourcesMenuScreen({super.key});

  @override
  State<AdminTrainingHelpResourcesMenuScreen> createState() =>
      _AdminTrainingHelpResourcesMenuScreenState();
}

class _AdminTrainingHelpResourcesMenuScreenState
    extends State<AdminTrainingHelpResourcesMenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        title: const Text('Training & Help Resources'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Courses', icon: Icon(Icons.school)),
            Tab(text: 'Training Materials', icon: Icon(Icons.description)),
            Tab(text: 'Help Videos', icon: Icon(Icons.play_circle_outline)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Courses tab
          const AdminCHWCourseEditorScreen(),
          // Training Materials tab
          const AdminTrainingMaterialsManagementScreen(),
          // Help Videos tab
          const AdminHelpVideosScreen(),
          // Analytics tab
          const AdminTrainingAnalyticsScreen(),
        ],
      ),
    );
  }
}
