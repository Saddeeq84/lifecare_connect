// ignore_for_file: prefer_const_constructors, avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../shared/data/services/user_analytics_service.dart';
import '../../../../core/services/loading_service.dart';

class AdminTrainingEngagementScreen extends StatefulWidget {
  const AdminTrainingEngagementScreen({super.key});

  @override
  State<AdminTrainingEngagementScreen> createState() =>
      _AdminTrainingEngagementScreenState();
}

class _AdminTrainingEngagementScreenState
    extends State<AdminTrainingEngagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allUsers = [];
  Map<String, dynamic> _trainingMaterialStats = {};
  String _selectedRole = 'all';
  String _searchQuery = '';

  /// Safe conversion of dynamic values to double
  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTrainingEngagementData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTrainingEngagementData() async {
    setState(() => _isLoading = true);

    try {
      // Load all users with analytics
      final result = await UserAnalyticsService.getAllUsersWithAnalytics();
      final users = result['users'] as List<Map<String, dynamic>>;

      // Load training material statistics
      final trainingStats =
          await UserAnalyticsService.getTrainingMaterialStatistics();

      if (mounted) {
        setState(() {
          _allUsers = users;
          _trainingMaterialStats = trainingStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading training engagement data: $e');
      if (mounted) {
        setState(() => _isLoading = false);

        // Show user-friendly error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to load training engagement data. Please check your internet connection and try again.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadTrainingEngagementData,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Engagement Analytics'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Individual Users', icon: Icon(Icons.person)),
            Tab(text: 'Inactive Users', icon: Icon(Icons.person_off)),
            Tab(text: 'Material Stats', icon: Icon(Icons.library_books)),
          ],
        ),
      ),
      body: _isLoading
          ? LoadingService.buildLoadingWidget(
              message: 'Loading training engagement data...',
              size: 50.0,
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildIndividualUsersTab(),
                _buildInactiveUsersTab(),
                _buildMaterialStatsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final chwUsers = _allUsers
        .where((u) => u['user_data']['role'] == 'chw')
        .toList();
    final doctorUsers = _allUsers
        .where((u) => u['user_data']['role'] == 'doctor')
        .toList();
    final totalMaterials = _trainingMaterialStats['total_materials'] ?? 0;
    final totalViews = _trainingMaterialStats['total_views'] ?? 0;
    final totalDownloads = _trainingMaterialStats['total_downloads'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadTrainingEngagementData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Training Engagement Overview',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Summary Cards
            _buildSummaryCards(
              chwUsers,
              doctorUsers,
              totalMaterials,
              totalViews,
              totalDownloads,
            ),

            const SizedBox(height: 20),

            // Engagement by Role
            _buildEngagementByRoleSection(chwUsers, doctorUsers),

            const SizedBox(height: 20),

            // Top Performers
            _buildTopPerformersSection(),

            const SizedBox(height: 20),

            // Engagement Trends
            _buildEngagementTrendsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(
    List<Map<String, dynamic>> chwUsers,
    List<Map<String, dynamic>> doctorUsers,
    int totalMaterials,
    int totalViews,
    int totalDownloads,
  ) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildSummaryCard(
          'Total CHWs',
          '${chwUsers.length}',
          '${_getActiveUsersCount(chwUsers)} active',
          Icons.people,
          Colors.blue,
        ),
        _buildSummaryCard(
          'Total Doctors',
          '${doctorUsers.length}',
          '${_getActiveUsersCount(doctorUsers)} active',
          Icons.local_hospital,
          Colors.green,
        ),
        _buildSummaryCard(
          'Training Materials',
          '$totalMaterials',
          '$totalViews total views',
          Icons.library_books,
          Colors.orange,
        ),
        _buildSummaryCard(
          'Total Downloads',
          '$totalDownloads',
          'All materials',
          Icons.download,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementByRoleSection(
    List<Map<String, dynamic>> chwUsers,
    List<Map<String, dynamic>> doctorUsers,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Training Engagement by Role',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRoleEngagementCard('CHW', chwUsers, Colors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRoleEngagementCard(
                    'Doctors',
                    doctorUsers,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleEngagementCard(
    String role,
    List<Map<String, dynamic>> users,
    Color color,
  ) {
    final totalUsers = users.length;
    final activeUsers = _getActiveUsersCount(users);
    final totalTrainingAccessed = users.fold<int>(0, (sum, user) {
      final analytics = user['analytics'] as Map<String, dynamic>? ?? {};
      return sum + (analytics['training_materials_accessed'] as int? ?? 0);
    });
    final totalTrainingCompleted = users.fold<int>(0, (sum, user) {
      final analytics = user['analytics'] as Map<String, dynamic>? ?? {};
      return sum + (analytics['training_completed'] as int? ?? 0);
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                role,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEngagementMetric('Total Users', '$totalUsers'),
          _buildEngagementMetric('Active Users', '$activeUsers'),
          _buildEngagementMetric('Training Accessed', '$totalTrainingAccessed'),
          _buildEngagementMetric(
            'Training Completed',
            '$totalTrainingCompleted',
          ),
          _buildEngagementMetric(
            'Completion Rate',
            totalTrainingAccessed > 0
                ? '${((totalTrainingCompleted / totalTrainingAccessed) * 100).toStringAsFixed(1)}%'
                : '0%',
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformersSection() {
    // Get top performing users based on training completion
    final topPerformers = [..._allUsers]
      ..sort((a, b) {
        final aCompleted =
            (a['analytics'] as Map<String, dynamic>? ??
                    {})['training_completed']
                as int? ??
            0;
        final bCompleted =
            (b['analytics'] as Map<String, dynamic>? ??
                    {})['training_completed']
                as int? ??
            0;
        return bCompleted.compareTo(aCompleted);
      });

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Top Training Performers',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topPerformers.take(5).length,
              itemBuilder: (context, index) {
                final user = topPerformers[index];
                final userData = user['user_data'] as Map<String, dynamic>;
                final analytics =
                    user['analytics'] as Map<String, dynamic>? ?? {};
                return _buildTopPerformerItem(
                  user,
                  userData,
                  analytics,
                  index + 1,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPerformerItem(
    Map<String, dynamic> user,
    Map<String, dynamic> userData,
    Map<String, dynamic> analytics,
    int rank,
  ) {
    final name = userData['fullName'] ?? userData['name'] ?? 'Unknown User';
    final role = userData['role'] ?? 'unknown';
    final completed = analytics['training_completed'] as int? ?? 0;
    final accessed = analytics['training_materials_accessed'] as int? ?? 0;

    Color rankColor = Colors.grey;
    if (rank == 1) {
      rankColor = Colors.amber;
    } else if (rank == 2)
      rankColor = Colors.grey[400]!;
    else if (rank == 3)
      rankColor = Colors.orange[300]!;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: rankColor.withOpacity(0.2),
        child: Text(
          '$rank',
          style: TextStyle(color: rankColor, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${role.toUpperCase()} • $completed completed, $accessed accessed',
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$completed',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      ),
    );
  }

  Widget _buildEngagementTrendsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Engagement Trends',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[50],
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Training engagement trends chart\nwill be implemented here',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualUsersTab() {
    return Column(
      children: [
        _buildUserFilters(),
        Expanded(child: _buildFilteredUsersList()),
      ],
    );
  }

  Widget _buildUserFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search users by name...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRoleFilterChip('All', 'all'),
                _buildRoleFilterChip('CHW', 'chw'),
                _buildRoleFilterChip('Doctors', 'doctor'),
                _buildRoleFilterChip('Patients', 'patient'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterChip(String label, String value) {
    final isSelected = _selectedRole == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedRole = value);
        },
        backgroundColor: Colors.white,
        selectedColor: Colors.indigo.withOpacity(0.2),
        checkmarkColor: Colors.indigo,
      ),
    );
  }

  Widget _buildFilteredUsersList() {
    final filteredUsers = _allUsers.where((user) {
      final userData = user['user_data'] as Map<String, dynamic>;
      final name = (userData['fullName'] ?? userData['name'] ?? '')
          .toString()
          .toLowerCase();
      final role = userData['role'] ?? '';

      // Role filter
      final roleMatch = _selectedRole == 'all' || role == _selectedRole;

      // Search filter
      final searchMatch =
          _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());

      // Only show CHW and Doctor roles for training engagement
      final validRole = role == 'chw' || role == 'doctor';

      return roleMatch && searchMatch && validRole;
    }).toList();

    if (filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        return _buildIndividualUserCard(user);
      },
    );
  }

  Widget _buildIndividualUserCard(Map<String, dynamic> user) {
    final userData = user['user_data'] as Map<String, dynamic>;
    final analytics = user['analytics'] as Map<String, dynamic>? ?? {};

    final name = userData['fullName'] ?? userData['name'] ?? 'Unknown User';
    final role = userData['role'] ?? 'unknown';
    final email = userData['email'] ?? 'No email';
    final phone = userData['phoneNumber'] ?? 'No phone';

    final trainingAccessed =
        analytics['training_materials_accessed'] as int? ?? 0;
    final trainingCompleted = analytics['training_completed'] as int? ?? 0;
    final lastActivity = analytics['last_activity'] as Timestamp?;
    final activityStatus = analytics['activity_status'] ?? 'never_active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(role).withOpacity(0.2),
          child: Text(
            _getInitials(name),
            style: TextStyle(
              color: _getRoleColor(role),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${role.toUpperCase()} • ${_getActivityStatusLabel(activityStatus)}',
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.school, size: 14, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  '$trainingCompleted/$trainingAccessed training materials',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: _getActivityStatusIcon(activityStatus),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contact Information
                _buildUserDetailSection('Contact Information', [
                  _buildDetailRow('Email', email, Icons.email),
                  _buildDetailRow('Phone', phone, Icons.phone),
                ]),

                const SizedBox(height: 16),

                // Training Engagement Details
                _buildUserDetailSection('Training Engagement', [
                  _buildDetailRow(
                    'Materials Accessed',
                    '$trainingAccessed',
                    Icons.visibility,
                  ),
                  _buildDetailRow(
                    'Materials Completed',
                    '$trainingCompleted',
                    Icons.check_circle,
                  ),
                  _buildDetailRow(
                    'Completion Rate',
                    trainingAccessed > 0
                        ? '${((trainingCompleted / trainingAccessed) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.trending_up,
                  ),
                ]),

                const SizedBox(height: 16),

                // Activity Information
                _buildUserDetailSection('Activity Information', [
                  _buildDetailRow(
                    'Status',
                    _getActivityStatusLabel(activityStatus),
                    Icons.info,
                  ),
                  _buildDetailRow(
                    'Last Active',
                    lastActivity != null
                        ? _formatRelativeTime(lastActivity.toDate())
                        : 'Never',
                    Icons.access_time,
                  ),
                  _buildDetailRow(
                    'Account Created',
                    _formatDate(userData['createdAt']),
                    Icons.person_add,
                  ),
                ]),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _viewDetailedAnalytics(user),
                        icon: const Icon(Icons.analytics, size: 16),
                        label: const Text('View Analytics'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade100,
                          foregroundColor: Colors.blue.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _sendReminderNotification(user),
                        icon: const Icon(Icons.notifications, size: 16),
                        label: const Text('Send Reminder'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade100,
                          foregroundColor: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetailSection(String title, List<Widget> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(children: details),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveUsersTab() {
    // Filter users who have never logged in or haven't logged in for 30+ days
    final inactiveUsers = _allUsers.where((user) {
      final analytics = user['analytics'] as Map<String, dynamic>? ?? {};
      final activityStatus = analytics['activity_status'] ?? 'never_active';
      final userData = user['user_data'] as Map<String, dynamic>;
      final role = userData['role'] ?? '';

      // Only show CHW and Doctor roles
      final validRole = role == 'chw' || role == 'doctor';

      // Consider inactive if never active or inactive for 30+ days
      final isInactive =
          activityStatus == 'never_active' ||
          activityStatus == 'inactive_long' ||
          activityStatus == 'inactive_recent';

      return validRole && isInactive;
    }).toList();

    // Sort by inactivity severity (never active first, then by days inactive)
    inactiveUsers.sort((a, b) {
      final aStatus =
          (a['analytics'] as Map<String, dynamic>? ?? {})['activity_status'] ??
          '';
      final bStatus =
          (b['analytics'] as Map<String, dynamic>? ?? {})['activity_status'] ??
          '';

      if (aStatus == 'never_active' && bStatus != 'never_active') return -1;
      if (bStatus == 'never_active' && aStatus != 'never_active') return 1;

      return 0; // Maintain original order for same status
    });

    return Column(
      children: [
        // Inactive Users Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            border: Border(bottom: BorderSide(color: Colors.red.shade100)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inactive Users Detected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    Text(
                      '${inactiveUsers.length} users need attention - they may be redundant accounts',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: inactiveUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 64,
                        color: Colors.green[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Inactive Users!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All CHWs and Doctors are actively using the platform',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: inactiveUsers.length,
                  itemBuilder: (context, index) {
                    final user = inactiveUsers[index];
                    return _buildInactiveUserCard(user);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInactiveUserCard(Map<String, dynamic> user) {
    final userData = user['user_data'] as Map<String, dynamic>;
    final analytics = user['analytics'] as Map<String, dynamic>? ?? {};

    final name = userData['fullName'] ?? userData['name'] ?? 'Unknown User';
    final role = userData['role'] ?? 'unknown';
    final email = userData['email'] ?? 'No email';
    final createdAt = userData['createdAt'];
    final lastActivity = analytics['last_activity'] as Timestamp?;
    final activityStatus = analytics['activity_status'] ?? 'never_active';
    final daysSinceCreation = _calculateDaysSinceCreation(createdAt);

    Color severityColor = Colors.orange;
    String severityLabel = 'Inactive';

    if (activityStatus == 'never_active') {
      severityColor = Colors.red;
      severityLabel = 'Never Active';
    } else if (activityStatus == 'inactive_long') {
      severityColor = Colors.red.shade700;
      severityLabel = 'Long Inactive';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: severityColor.withOpacity(0.2),
                  child: Icon(
                    activityStatus == 'never_active'
                        ? Icons.person_off
                        : Icons.access_time,
                    color: severityColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${role.toUpperCase()} • $email',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: severityColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    severityLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: severityColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Inactive User Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildInactiveDetailRow(
                    'Account Created',
                    _formatDate(createdAt),
                    '$daysSinceCreation days ago',
                    Icons.person_add,
                  ),
                  _buildInactiveDetailRow(
                    'Last Activity',
                    lastActivity != null
                        ? _formatRelativeTime(lastActivity.toDate())
                        : 'Never logged in',
                    activityStatus == 'never_active'
                        ? 'Account may be unused'
                        : 'Potentially dormant',
                    Icons.access_time,
                  ),
                  _buildInactiveDetailRow(
                    'Training Engagement',
                    '${analytics['training_completed'] ?? 0} completed',
                    '${analytics['training_materials_accessed'] ?? 0} accessed',
                    Icons.school,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons for Inactive Users
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sendReactivationReminder(user),
                    icon: const Icon(Icons.email, size: 16),
                    label: const Text('Send Reminder'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                      foregroundColor: Colors.blue.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _markForReview(user),
                    icon: const Icon(Icons.flag, size: 16),
                    label: const Text('Mark for Review'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade100,
                      foregroundColor: Colors.orange.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showDeactivateDialog(user),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Deactivate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                    foregroundColor: Colors.red.shade800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveDetailRow(
    String label,
    String primary,
    String secondary,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  primary,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
                Text(
                  secondary,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialStatsTab() {
    final materials =
        _trainingMaterialStats['materials'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Training Material Statistics',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Overall Material Stats
          _buildOverallMaterialStats(),

          const SizedBox(height: 20),

          // Individual Material Performance
          if (materials.isNotEmpty) ...[
            Text(
              'Individual Material Performance',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: materials.length,
              itemBuilder: (context, index) {
                final material = materials[index] as Map<String, dynamic>;
                return _buildMaterialStatsCard(material);
              },
            ),
          ] else
            _buildNoMaterialsWidget(),
        ],
      ),
    );
  }

  Widget _buildOverallMaterialStats() {
    final totalMaterials = _trainingMaterialStats['total_materials'] ?? 0;
    final totalViews = _trainingMaterialStats['total_views'] ?? 0;
    final totalDownloads = _trainingMaterialStats['total_downloads'] ?? 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall Material Statistics',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOverallStatItem(
                    'Total Materials',
                    '$totalMaterials',
                    Icons.library_books,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildOverallStatItem(
                    'Total Views',
                    '$totalViews',
                    Icons.visibility,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildOverallStatItem(
                    'Total Downloads',
                    '$totalDownloads',
                    Icons.download,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildOverallStatItem(
                    'Avg Engagement',
                    totalMaterials > 0
                        ? '${(totalViews / totalMaterials).toStringAsFixed(1)}'
                        : '0',
                    Icons.trending_up,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialStatsCard(Map<String, dynamic> material) {
    final title = material['title'] ?? 'Untitled Material';
    final type = material['type'] ?? 'unknown';
    final viewCount = material['view_count'] ?? 0;
    final downloadCount = material['download_count'] ?? 0;
    final uniqueViewers = material['unique_viewers'] ?? 0;
    final completionRate = _safeToDouble(material['completion_rate']);
    final userInteractions =
        material['user_interactions'] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getMaterialTypeColor(type).withOpacity(0.2),
          child: Icon(
            _getMaterialTypeIcon(type),
            color: _getMaterialTypeColor(type),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${type.toUpperCase()} • $uniqueViewers unique viewers'),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: completionRate / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                completionRate >= 70
                    ? Colors.green
                    : completionRate >= 40
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${completionRate.toStringAsFixed(1)}% completion rate',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Material Statistics
                Row(
                  children: [
                    Expanded(
                      child: _buildMaterialMetric(
                        'Views',
                        '$viewCount',
                        Icons.visibility,
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildMaterialMetric(
                        'Downloads',
                        '$downloadCount',
                        Icons.download,
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildMaterialMetric(
                        'Unique Users',
                        '$uniqueViewers',
                        Icons.people,
                        Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _buildMaterialMetric(
                        'Completion',
                        '${completionRate.toStringAsFixed(1)}%',
                        Icons.check_circle,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // User Interactions
                if (userInteractions.isNotEmpty) ...[
                  Text(
                    'User Interactions (${userInteractions.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: userInteractions.length,
                      itemBuilder: (context, index) {
                        final interaction =
                            userInteractions[index] as Map<String, dynamic>;
                        return _buildUserInteractionItem(interaction);
                      },
                    ),
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'No user interactions recorded yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserInteractionItem(Map<String, dynamic> interaction) {
    final userName = interaction['user_name'] ?? 'Unknown User';
    final userRole = interaction['user_role'] ?? 'unknown';
    final progress = (interaction['progress'] ?? 0).toDouble();
    final status = interaction['status'] ?? 'not_started';
    final timeSpent = interaction['time_spent_minutes'] ?? 0;

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: _getRoleColor(userRole).withOpacity(0.2),
        child: Text(
          _getInitials(userName),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: _getRoleColor(userRole),
          ),
        ),
      ),
      title: Text(
        userName,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${userRole.toUpperCase()} • ${timeSpent}min • ${progress.toStringAsFixed(0)}% progress',
        style: const TextStyle(fontSize: 10),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _getStatusColor(status).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: _getStatusColor(status),
          ),
        ),
      ),
    );
  }

  Widget _buildNoMaterialsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Training Materials Found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload some training materials to see statistics here',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  int _getActiveUsersCount(List<Map<String, dynamic>> users) {
    return users.where((user) {
      final analytics = user['analytics'] as Map<String, dynamic>? ?? {};
      final status = analytics['activity_status'] ?? 'never_active';
      return status == 'active_today' ||
          status == 'active_this_week' ||
          status == 'active_this_month';
    }).length;
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'chw':
        return Colors.blue;
      case 'doctor':
        return Colors.green;
      case 'patient':
        return Colors.purple;
      case 'admin':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getInitials(String name) {
    final initials = name
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0] : '')
        .join('');
    return initials.length >= 2
        ? initials.substring(0, 2).toUpperCase()
        : initials.toUpperCase();
  }

  String _getActivityStatusLabel(String status) {
    switch (status) {
      case 'active_today':
        return 'Active Today';
      case 'active_this_week':
        return 'Active This Week';
      case 'active_this_month':
        return 'Active This Month';
      case 'inactive_recent':
        return 'Recently Inactive';
      case 'inactive_long':
        return 'Long Inactive';
      case 'never_active':
        return 'Never Active';
      default:
        return 'Unknown Status';
    }
  }

  Widget _getActivityStatusIcon(String status) {
    Color color;
    IconData icon;

    switch (status) {
      case 'active_today':
        color = Colors.green;
        icon = Icons.circle;
        break;
      case 'active_this_week':
        color = Colors.lightGreen;
        icon = Icons.circle;
        break;
      case 'active_this_month':
        color = Colors.orange;
        icon = Icons.circle;
        break;
      case 'inactive_recent':
        color = Colors.deepOrange;
        icon = Icons.circle;
        break;
      case 'inactive_long':
        color = Colors.red;
        icon = Icons.circle;
        break;
      case 'never_active':
        color = Colors.grey;
        icon = Icons.circle_outlined;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Icon(icon, color: color, size: 20);
  }

  Color _getMaterialTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return Colors.red;
      case 'pdf':
        return Colors.blue;
      case 'article':
        return Colors.green;
      case 'audio':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getMaterialTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return Icons.play_circle;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'article':
        return Icons.article;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.description;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'not_started':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'Unknown';
      }

      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${difference.inDays >= 730 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${difference.inDays >= 60 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  int _calculateDaysSinceCreation(dynamic createdAt) {
    if (createdAt == null) return 0;

    try {
      DateTime date;
      if (createdAt is Timestamp) {
        date = createdAt.toDate();
      } else if (createdAt is String) {
        date = DateTime.parse(createdAt);
      } else {
        return 0;
      }

      return DateTime.now().difference(date).inDays;
    } catch (e) {
      return 0;
    }
  }

  // Action Methods
  void _viewDetailedAnalytics(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.9,
          child: _buildDetailedAnalyticsModal(user),
        ),
      ),
    );
  }

  Widget _buildDetailedAnalyticsModal(Map<String, dynamic> user) {
    final userData = user['user_data'] as Map<String, dynamic>;
    final analytics = user['analytics'] as Map<String, dynamic>? ?? {};

    final name = userData['fullName'] ?? userData['name'] ?? 'Unknown User';
    final role = userData['role'] ?? 'unknown';

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Analytics: $name (${role.toUpperCase()})'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 16)),
              Tab(
                text: 'Training Progress',
                icon: Icon(Icons.school, size: 16),
              ),
              Tab(
                text: 'Activity Timeline',
                icon: Icon(Icons.timeline, size: 16),
              ),
              Tab(text: 'Performance', icon: Icon(Icons.trending_up, size: 16)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverviewAnalyticsTab(userData, analytics),
            _buildTrainingProgressTab(userData, analytics),
            _buildActivityTimelineTab(userData, analytics),
            _buildPerformanceTab(userData, analytics),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewAnalyticsTab(
    Map<String, dynamic> userData,
    Map<String, dynamic> analytics,
  ) {
    final name = userData['fullName'] ?? userData['name'] ?? 'Unknown User';
    final role = userData['role'] ?? 'unknown';
    final email = userData['email'] ?? 'No email';
    final phone = userData['phoneNumber'] ?? 'No phone';
    final createdAt = userData['createdAt'];
    final activityStatus = analytics['activity_status'] ?? 'never_active';
    final lastActivity = analytics['last_activity'] as Timestamp?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Profile Card
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: _getRoleColor(role).withOpacity(0.2),
                    child: Text(
                      _getInitials(name),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getRoleColor(role),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getRoleColor(role).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _getRoleColor(role).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getRoleColor(role),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _getActivityStatusIcon(activityStatus),
                            const SizedBox(width: 4),
                            Text(
                              _getActivityStatusLabel(activityStatus),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: [
              _buildQuickStatCard(
                'Training Materials',
                '${analytics['training_materials_accessed'] ?? 0}',
                'Accessed',
                Icons.library_books,
                Colors.blue,
              ),
              _buildQuickStatCard(
                'Training Completed',
                '${analytics['training_completed'] ?? 0}',
                'Finished',
                Icons.check_circle,
                Colors.green,
              ),
              _buildQuickStatCard(
                'Recent Activities',
                '${analytics['recent_activity_count'] ?? 0}',
                'Last 30 days',
                Icons.trending_up,
                Colors.orange,
              ),
              _buildQuickStatCard(
                'Account Age',
                '${_calculateDaysSinceCreation(createdAt)}',
                'Days',
                Icons.calendar_today,
                Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Contact Information Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Email', email, Icons.email),
                  _buildDetailRow('Phone', phone, Icons.phone),
                  _buildDetailRow('Role', role.toUpperCase(), Icons.work),
                  _buildDetailRow(
                    'Joined',
                    _formatDate(createdAt),
                    Icons.person_add,
                  ),
                  _buildDetailRow(
                    'Last Active',
                    lastActivity != null
                        ? _formatRelativeTime(lastActivity.toDate())
                        : 'Never',
                    Icons.access_time,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingProgressTab(
    Map<String, dynamic> userData,
    Map<String, dynamic> analytics,
  ) {
    final trainingAccessed = analytics['training_materials_accessed'] ?? 0;
    final trainingCompleted = analytics['training_completed'] ?? 0;
    final completionRate = trainingAccessed > 0
        ? (trainingCompleted / trainingAccessed) * 100
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Training Summary Card
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Training Progress Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$trainingAccessed',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const Text('Materials Accessed'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$trainingCompleted',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const Text('Completed'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${completionRate.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: completionRate >= 70
                                    ? Colors.green
                                    : completionRate >= 40
                                    ? Colors.orange
                                    : Colors.red,
                              ),
                            ),
                            const Text('Completion Rate'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: completionRate / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completionRate >= 70
                          ? Colors.green
                          : completionRate >= 40
                          ? Colors.orange
                          : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Training Categories Breakdown
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Training Categories Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // This would normally show actual training category data
                  // For now, we'll show placeholder data
                  _buildTrainingCategoryItem(
                    'Clinical Procedures',
                    5,
                    3,
                    Colors.blue,
                  ),
                  _buildTrainingCategoryItem(
                    'Patient Care',
                    3,
                    2,
                    Colors.green,
                  ),
                  _buildTrainingCategoryItem(
                    'Emergency Response',
                    2,
                    1,
                    Colors.red,
                  ),
                  _buildTrainingCategoryItem(
                    'Health Education',
                    4,
                    4,
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Training category breakdown requires detailed progress tracking to be implemented in the database.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Recommendations Card
          if (completionRate < 50)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Recommendations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildRecommendationItem(
                      'Increase Training Engagement',
                      'User has low completion rate. Consider sending training reminders.',
                      Icons.notifications_active,
                    ),
                    _buildRecommendationItem(
                      'Focus on Core Materials',
                      'Prioritize essential training materials for this role.',
                      Icons.priority_high,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityTimelineTab(
    Map<String, dynamic> userData,
    Map<String, dynamic> analytics,
  ) {
    final lastActivity = analytics['last_activity'] as Timestamp?;
    final recentActivityCount = analytics['recent_activity_count'] ?? 0;
    final daysSinceLastActivity = analytics['days_since_last_activity'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity Overview Card
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Activity Timeline',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimelineStatCard(
                          'Last Activity',
                          lastActivity != null
                              ? _formatRelativeTime(lastActivity.toDate())
                              : 'Never',
                          Icons.access_time,
                          lastActivity != null ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimelineStatCard(
                          'Recent Activities',
                          '$recentActivityCount',
                          Icons.trending_up,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Timeline Placeholder
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Activity History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sample timeline items (would be populated with real data)
                  if (lastActivity != null) ...[
                    _buildTimelineItem(
                      'Last Login',
                      _formatRelativeTime(lastActivity.toDate()),
                      Icons.login,
                      Colors.green,
                      isRecent:
                          daysSinceLastActivity != null &&
                          daysSinceLastActivity < 7,
                    ),
                  ],

                  _buildTimelineItem(
                    'Account Created',
                    _formatDate(userData['createdAt']),
                    Icons.person_add,
                    Colors.blue,
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Detailed activity timeline requires user activity logging to be implemented. Currently showing basic account milestones.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab(
    Map<String, dynamic> userData,
    Map<String, dynamic> analytics,
  ) {
    final role = userData['role'] ?? 'unknown';
    final trainingCompleted = analytics['training_completed'] ?? 0;
    final trainingAccessed = analytics['training_materials_accessed'] ?? 0;
    final recentActivity = analytics['recent_activity_count'] ?? 0;

    // Calculate performance score
    double performanceScore = 0;
    if (trainingAccessed > 0) {
      performanceScore = (trainingCompleted / trainingAccessed) * 100;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance Score Card
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Overall Performance Score',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: performanceScore / 100,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            performanceScore >= 70
                                ? Colors.green
                                : performanceScore >= 40
                                ? Colors.orange
                                : Colors.red,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${performanceScore.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: performanceScore >= 70
                                  ? Colors.green
                                  : performanceScore >= 40
                                  ? Colors.orange
                                  : Colors.red,
                            ),
                          ),
                          Text(
                            _getPerformanceLabel(performanceScore),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Performance Metrics Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildPerformanceMetric(
                'Training Efficiency',
                '${performanceScore.toStringAsFixed(1)}%',
                Icons.school,
                performanceScore >= 70
                    ? Colors.green
                    : performanceScore >= 40
                    ? Colors.orange
                    : Colors.red,
              ),
              _buildPerformanceMetric(
                'Activity Level',
                _getActivityLevel(recentActivity),
                Icons.trending_up,
                _getActivityLevelColor(recentActivity),
              ),
              _buildPerformanceMetric(
                'Engagement',
                _getEngagementLevel(trainingAccessed),
                Icons.favorite,
                _getEngagementLevelColor(trainingAccessed),
              ),
              _buildPerformanceMetric(
                'Role Suitability',
                _getRoleSuitability(role, performanceScore),
                Icons.work,
                Colors.blue,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Performance Insights Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.insights, color: Colors.indigo.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Performance Insights',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ..._generatePerformanceInsights(
                    performanceScore,
                    recentActivity,
                    trainingCompleted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingCategoryItem(
    String category,
    int total,
    int completed,
    Color color,
  ) {
    final percentage = total > 0 ? (completed / total) * 100 : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$completed/$total',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(
    String title,
    String description,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    String title,
    String time,
    IconData icon,
    Color color, {
    bool isRecent = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isRecent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'RECENT',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  time,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getPerformanceLabel(double score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Average';
    return 'Needs Improvement';
  }

  String _getActivityLevel(int recentActivity) {
    if (recentActivity >= 20) return 'High';
    if (recentActivity >= 10) return 'Medium';
    if (recentActivity >= 5) return 'Low';
    return 'Very Low';
  }

  Color _getActivityLevelColor(int recentActivity) {
    if (recentActivity >= 20) return Colors.green;
    if (recentActivity >= 10) return Colors.orange;
    if (recentActivity >= 5) return Colors.deepOrange;
    return Colors.red;
  }

  String _getEngagementLevel(int trainingAccessed) {
    if (trainingAccessed >= 10) return 'High';
    if (trainingAccessed >= 5) return 'Medium';
    if (trainingAccessed >= 2) return 'Low';
    return 'Very Low';
  }

  Color _getEngagementLevelColor(int trainingAccessed) {
    if (trainingAccessed >= 10) return Colors.green;
    if (trainingAccessed >= 5) return Colors.orange;
    if (trainingAccessed >= 2) return Colors.deepOrange;
    return Colors.red;
  }

  String _getRoleSuitability(String role, double performance) {
    if (performance >= 70) return 'Excellent';
    if (performance >= 50) return 'Good';
    return 'Training Needed';
  }

  List<Widget> _generatePerformanceInsights(
    double performanceScore,
    int recentActivity,
    int trainingCompleted,
  ) {
    List<Widget> insights = [];

    if (performanceScore >= 80) {
      insights.add(
        _buildInsightItem(
          'Excellent Performance',
          'This user shows outstanding engagement and completion rates.',
          Icons.star,
          Colors.green,
        ),
      );
    } else if (performanceScore >= 60) {
      insights.add(
        _buildInsightItem(
          'Good Performance',
          'This user is performing well but has room for improvement.',
          Icons.thumb_up,
          Colors.orange,
        ),
      );
    } else {
      insights.add(
        _buildInsightItem(
          'Needs Attention',
          'This user may need additional support or training reminders.',
          Icons.warning,
          Colors.red,
        ),
      );
    }

    if (recentActivity < 5) {
      insights.add(
        _buildInsightItem(
          'Low Recent Activity',
          'User has been less active lately. Consider sending engagement reminders.',
          Icons.notifications,
          Colors.orange,
        ),
      );
    }

    if (trainingCompleted == 0) {
      insights.add(
        _buildInsightItem(
          'No Completed Training',
          'User has not completed any training materials yet.',
          Icons.school,
          Colors.red,
        ),
      );
    }

    return insights;
  }

  Widget _buildInsightItem(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendReminderNotification(Map<String, dynamic> user) {
    // Send training reminder notification
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Training Reminder'),
        content: Text(
          'Send a training engagement reminder to ${user['user_data']['fullName'] ?? 'Unknown User'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Training reminder sent successfully!'),
                ),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _sendReactivationReminder(Map<String, dynamic> user) {
    // Send reactivation reminder to inactive user
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Reactivation Reminder'),
        content: Text(
          'Send a reactivation reminder to ${user['user_data']['fullName'] ?? 'Unknown User'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reactivation reminder sent!')),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _markForReview(Map<String, dynamic> user) {
    // Mark user for manual review
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark for Review'),
        content: Text(
          'Mark ${user['user_data']['fullName'] ?? 'Unknown User'} for manual review? This will flag the account for administrator attention.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User marked for review')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Mark for Review'),
          ),
        ],
      ),
    );
  }

  void _showDeactivateDialog(Map<String, dynamic> user) {
    // Show deactivation confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate User Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to deactivate ${user['user_data']['fullName'] ?? 'Unknown User'}?',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Warning',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• User will lose access to the platform\n• All data will be preserved but marked inactive\n• This action can be reversed later',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User account deactivated')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}
