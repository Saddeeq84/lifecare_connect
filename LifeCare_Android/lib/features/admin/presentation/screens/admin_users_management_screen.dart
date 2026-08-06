// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../shared/data/services/user_analytics_service.dart';

class AdminUsersManagementScreen extends StatefulWidget {
  const AdminUsersManagementScreen({super.key});

  @override
  State<AdminUsersManagementScreen> createState() =>
      _AdminUsersManagementScreenState();
}

class _AdminUsersManagementScreenState extends State<AdminUsersManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedRole = 'all';
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: 0, // Explicitly set to 0 to avoid index out of range
    );
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      // Add a limit to prevent loading too many users at once
      final result = await UserAnalyticsService.getAllUsersWithAnalytics(
        limit: 100, // Limit to 100 users for better performance
      );

      final users = result['users'] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _allUsers = users;
          _filteredUsers = users;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      print('Error loading users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading users: Failed to fetch user data. Please try again.',
            ),
            action: SnackBarAction(label: 'Retry', onPressed: _loadUsers),
          ),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final userData = user['user_data'] as Map<String, dynamic>;
        final role = userData['role']?.toString().toLowerCase() ?? '';
        final name =
            userData['fullName']?.toString().toLowerCase() ??
            userData['name']?.toString().toLowerCase() ??
            '';

        // Role filter
        bool roleMatch = _selectedRole == 'all' || role == _selectedRole;

        // Search filter
        bool searchMatch =
            _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());

        return roleMatch && searchMatch;
      }).toList();
    });
  }

  void _onTabChanged(int index) {
    setState(() {
      switch (index) {
        case 0:
          _selectedRole = 'all';
          break;
        case 1:
          _selectedRole = 'patient';
          break;
        case 2:
          _selectedRole = 'doctor';
          break;
        case 3:
          _selectedRole = 'chw';
          break;
      }
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header with title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Text(
                  'Users Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700],
                  ),
                ),
              ],
            ),
          ),
          // TabBar
          Container(
            color: Colors.teal,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              onTap: _onTabChanged,
              tabs: [
                Tab(
                  icon: Icon(Icons.people),
                  text: 'All (${_getRoleCount('all')})',
                ),
                Tab(
                  icon: Icon(Icons.person),
                  text: 'Patients (${_getRoleCount('patient')})',
                ),
                Tab(
                  icon: Icon(Icons.medical_services),
                  text: 'Doctors (${_getRoleCount('doctor')})',
                ),
                Tab(
                  icon: Icon(Icons.health_and_safety),
                  text: 'CHWs (${_getRoleCount('chw')})',
                ),
              ],
            ),
          ),
          _buildSearchAndFilters(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading user analytics...'),
                        SizedBox(height: 8),
                        Text(
                          'This may take a moment',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildUsersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _applyFilters();
                  },
                ),
              ),
              SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _loadUsers,
                tooltip: 'Refresh',
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildQuickStats(),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatChip('Total Users', _allUsers.length, Colors.blue),
          SizedBox(width: 8),
          _buildStatChip(
            'Active Today',
            _countUsersByActivityStatus(_allUsers, 'active_today'),
            Colors.green,
          ),
          SizedBox(width: 8),
          _buildStatChip(
            'Active This Week',
            _countUsersByActivityStatus(_allUsers, 'active_this_week'),
            Colors.lightGreen,
          ),
          SizedBox(width: 8),
          _buildStatChip(
            'Inactive (30d+)',
            _countUsersByActivityStatus(_allUsers, 'inactive_long'),
            Colors.red,
          ),
          SizedBox(width: 8),
          _buildStatChip(
            'Never Active',
            _countUsersByActivityStatus(_allUsers, 'never_active'),
            Colors.grey,
          ),
          SizedBox(width: 8),
          _buildStatChip(
            'Filtered Results',
            _filteredUsers.length,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          SizedBox(width: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _filteredUsers.length,
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final userData = user['user_data'] as Map<String, dynamic>;
    final analytics = user['analytics'] as Map<String, dynamic>;
    final role = userData['role']?.toString().toLowerCase() ?? '';

    final name = userData['fullName'] ?? userData['name'] ?? 'Unknown User';
    final email = userData['email'] ?? 'No email';
    final isApproved = userData['isApproved'] ?? false;
    final isRejected = userData['isRejected'] ?? false;
    final createdAt = userData['createdAt'] as Timestamp?;
    final lastActivity = analytics['last_activity'] as Timestamp?;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _showUserDetails(user),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  _buildRoleAvatar(role),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(isApproved, isRejected, role),
                ],
              ),
              SizedBox(height: 12),

              // Activity status row
              _buildActivityStatusRow(analytics),

              SizedBox(height: 8),

              // Analytics row
              _buildAnalyticsRow(analytics, role),

              SizedBox(height: 12),

              // Footer row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (createdAt != null)
                    Text(
                      'Joined: ${DateFormat('MMM dd, yyyy').format(createdAt.toDate())}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  if (lastActivity != null)
                    Text(
                      'Last active: ${_formatRelativeTime(lastActivity.toDate())}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleAvatar(String role) {
    IconData icon;
    Color color;

    switch (role) {
      case 'patient':
        icon = Icons.person;
        color = Colors.blue;
        break;
      case 'doctor':
        icon = Icons.medical_services;
        color = Colors.red;
        break;
      case 'chw':
        icon = Icons.health_and_safety;
        color = Colors.orange;
        break;
      case 'facility':
        icon = Icons.business;
        color = Colors.teal;
        break;
      case 'admin':
        icon = Icons.admin_panel_settings;
        color = Colors.purple;
        break;
      default:
        icon = Icons.person_outline;
        color = Colors.grey;
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildStatusBadge(bool isApproved, bool isRejected, String role) {
    if (role == 'patient') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Active',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      );
    }

    if (isRejected) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Rejected',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      );
    }

    if (isApproved) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Approved',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Pending',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.orange,
        ),
      ),
    );
  }

  Widget _buildActivityStatusRow(Map<String, dynamic> analytics) {
    final activityStatus =
        analytics['activity_status'] as String? ?? 'never_active';
    final daysSinceLastActivity = analytics['days_since_last_activity'] as int?;
    final recentActivityCount = analytics['recent_activity_count'] as int? ?? 0;

    final statusInfo = UserAnalyticsService.getActivityStatusInfo(
      activityStatus,
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: (statusInfo['color'] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (statusInfo['color'] as Color).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusInfo['icon'] as IconData,
            size: 12,
            color: statusInfo['color'] as Color,
          ),
          SizedBox(width: 6),
          Text(
            statusInfo['label'] as String,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusInfo['color'] as Color,
            ),
          ),
          if (daysSinceLastActivity != null && daysSinceLastActivity > 0) ...[
            SizedBox(width: 8),
            Text(
              '• ${daysSinceLastActivity}d ago',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: recentActivityCount > 10
                  ? Colors.green
                  : recentActivityCount > 5
                  ? Colors.orange
                  : Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$recentActivityCount',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow(Map<String, dynamic> analytics, String role) {
    return Row(
      children: [
        Expanded(
          child: _buildAnalyticItem(
            'Training',
            '${analytics['training_completed'] ?? 0}/${analytics['training_materials_accessed'] ?? 0}',
            Icons.school,
            Colors.blue,
          ),
        ),
        SizedBox(width: 16),
        Expanded(child: _buildRoleSpecificAnalytic(analytics, role)),
      ],
    );
  }

  Widget _buildRoleSpecificAnalytic(
    Map<String, dynamic> analytics,
    String role,
  ) {
    switch (role) {
      case 'patient':
        return _buildAnalyticItem(
          'Appointments',
          '${analytics['total_appointments'] ?? 0}',
          Icons.calendar_today,
          Colors.green,
        );
      case 'doctor':
      case 'chw':
        return _buildAnalyticItem(
          'Consultations',
          '${analytics['total_consultations'] ?? 0}',
          Icons.medical_services,
          Colors.red,
        );
      case 'facility':
        return _buildAnalyticItem(
          'Services',
          '${analytics['total_services'] ?? 0}',
          Icons.business_center,
          Colors.teal,
        );
      default:
        return _buildAnalyticItem(
          'Activity',
          'N/A',
          Icons.timeline,
          Colors.grey,
        );
    }
  }

  Widget _buildAnalyticItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserDetailScreen(user: user)),
    );
  }

  int _getRoleCount(String role) {
    if (role == 'all') return _allUsers.length;
    return _allUsers.where((user) {
      final userData = user['user_data'] as Map<String, dynamic>;
      return userData['role']?.toString().toLowerCase() == role;
    }).length;
  }

  int _countUsersByActivityStatus(
    List<Map<String, dynamic>> users,
    String targetStatus,
  ) {
    return users.where((user) {
      if (user['analytics'] == null) return false;

      final analytics = user['analytics'] as Map<String, dynamic>;
      final activityStatus =
          analytics['activity_status'] as String? ?? 'never_active';

      return activityStatus == targetStatus;
    }).length;
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(dateTime);
    }
  }
}

class UserDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserDetailScreen({super.key, required this.user});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  bool _isLoading = false;
  Map<String, dynamic> _detailedAnalytics = {};

  @override
  void initState() {
    super.initState();
    _loadDetailedAnalytics();
  }

  Future<void> _loadDetailedAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final userId = widget.user['id'];
      final userData = widget.user['user_data'] as Map<String, dynamic>;
      final role = userData['role']?.toString().toLowerCase();

      // Debug information
      debugPrint('Loading analytics for user: $userId, role: $role');

      final analytics = await UserAnalyticsService.getUserAnalytics(
        userId: userId,
        role: role,
      );

      debugPrint('Analytics loaded successfully: ${analytics.keys}');

      setState(() {
        _detailedAnalytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading detailed analytics: $e');
      setState(() {
        _detailedAnalytics = {
          'error': true,
          'message': e.toString(),
          'training_materials': {},
          'activity_analytics': {},
          'performance_metrics': {},
        };
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading analytics: ${e.toString()}'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadDetailedAnalytics,
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = widget.user['user_data'] as Map<String, dynamic>;
    final role = userData['role']?.toString().toLowerCase() ?? '';
    final name = userData['fullName'] ?? userData['name'] ?? 'Unknown User';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadDetailedAnalytics,
              tooltip: 'Refresh Analytics',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading user analytics...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : _detailedAnalytics['error'] == true
          ? _buildErrorState()
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserInfoCard(userData, role),
                  SizedBox(height: 16),
                  _buildTrainingAnalytics(),
                  SizedBox(height: 16),
                  _buildActivityAnalytics(role),
                  SizedBox(height: 16),
                  _buildPerformanceMetrics(),
                ],
              ),
            ),
    );
  }

  Widget _buildUserInfoCard(Map<String, dynamic> userData, String role) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildInfoRow(
              'Name',
              userData['fullName'] ?? userData['name'] ?? 'Unknown',
            ),
            _buildInfoRow('Email', userData['email'] ?? 'Not provided'),
            _buildInfoRow('Role', role.toUpperCase()),
            _buildInfoRow('Phone', userData['phone'] ?? 'Not provided'),
            if (userData['location'] != null)
              _buildInfoRow('Location', userData['location']),
            if (userData['createdAt'] != null)
              _buildInfoRow(
                'Joined',
                DateFormat(
                  'MMM dd, yyyy',
                ).format((userData['createdAt'] as Timestamp).toDate()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildTrainingAnalytics() {
    final trainingData =
        _detailedAnalytics['training_materials'] as Map<String, dynamic>? ?? {};
    final hasTrainingData = trainingData.isNotEmpty;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Training Materials Analytics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (!hasTrainingData)
              _buildNoDataWidget('No training analytics available yet')
            else ...[
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildStatCard(
                    'Videos Watched',
                    '${trainingData['videos_watched'] ?? 0}',
                    Icons.play_circle,
                    Colors.red,
                  ),
                  _buildStatCard(
                    'Materials Read',
                    '${trainingData['materials_read'] ?? 0}',
                    Icons.description,
                    Colors.green,
                  ),
                  _buildStatCard(
                    'Downloads',
                    '${trainingData['materials_downloaded'] ?? 0}',
                    Icons.download,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'Completed',
                    '${trainingData['completed_trainings'] ?? 0}',
                    Icons.check_circle,
                    Colors.purple,
                  ),
                ],
              ),
              SizedBox(height: 12),
              _buildStatCard(
                'Total Training Time',
                '${(trainingData['total_training_time_minutes'] ?? 0).toInt()} minutes',
                Icons.access_time,
                Colors.teal,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityAnalytics(String role) {
    final activityData =
        _detailedAnalytics['activity_analytics'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  '${role.toUpperCase()} Activity Analytics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildRoleSpecificActivityAnalytics(activityData, role),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSpecificActivityAnalytics(
    Map<String, dynamic> activityData,
    String role,
  ) {
    switch (role) {
      case 'patient':
        final appointments =
            activityData['appointments'] as Map<String, dynamic>? ?? {};
        final referrals =
            activityData['referrals'] as Map<String, dynamic>? ?? {};
        final education =
            activityData['education'] as Map<String, dynamic>? ?? {};

        return Column(
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildStatCard(
                  'Total Appointments',
                  '${appointments['total'] ?? 0}',
                  Icons.calendar_today,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Completed',
                  '${appointments['completed'] ?? 0}',
                  Icons.check,
                  Colors.green,
                ),
                _buildStatCard(
                  'Referrals',
                  '${referrals['total'] ?? 0}',
                  Icons.send,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Health Tips Read',
                  '${education['health_tips_read'] ?? 0}',
                  Icons.tips_and_updates,
                  Colors.purple,
                ),
              ],
            ),
          ],
        );

      case 'doctor':
      case 'chw':
        final appointments =
            activityData['appointments'] as Map<String, dynamic>? ?? {};
        final consultations =
            activityData['consultations'] as Map<String, dynamic>? ?? {};
        final referrals =
            activityData['referrals'] as Map<String, dynamic>? ?? {};

        return Column(
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildStatCard(
                  'Total Appointments',
                  '${appointments['total'] ?? 0}',
                  Icons.calendar_today,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Accepted',
                  '${appointments['accepted'] ?? 0}',
                  Icons.check,
                  Colors.green,
                ),
                _buildStatCard(
                  'Consultations',
                  '${consultations['total'] ?? 0}',
                  Icons.medical_services,
                  Colors.red,
                ),
                _buildStatCard(
                  'Referrals Made',
                  '${referrals['total'] ?? 0}',
                  Icons.send,
                  Colors.orange,
                ),
              ],
            ),
          ],
        );

      case 'facility':
        final services =
            activityData['services'] as Map<String, dynamic>? ?? {};
        final appointments =
            activityData['appointments'] as Map<String, dynamic>? ?? {};
        final referrals =
            activityData['referrals'] as Map<String, dynamic>? ?? {};

        return GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildStatCard(
              'Services Offered',
              '${services['total'] ?? 0}',
              Icons.business_center,
              Colors.teal,
            ),
            _buildStatCard(
              'Appointments',
              '${appointments['total'] ?? 0}',
              Icons.calendar_today,
              Colors.blue,
            ),
            _buildStatCard(
              'Referrals Received',
              '${referrals['total'] ?? 0}',
              Icons.input,
              Colors.orange,
            ),
            _buildStatCard(
              'Referrals Accepted',
              '${referrals['accepted'] ?? 0}',
              Icons.check,
              Colors.green,
            ),
          ],
        );

      default:
        return Text('No activity analytics available for this role.');
    }
  }

  Widget _buildPerformanceMetrics() {
    final performanceData =
        _detailedAnalytics['performance_metrics'] as Map<String, dynamic>? ??
        {};

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Performance Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildStatCard(
                  'Performance Score',
                  '${(performanceData['performance_score'] ?? 0).toStringAsFixed(1)}%',
                  Icons.score,
                  Colors.purple,
                ),
                _buildStatCard(
                  'Activity Trend',
                  '${(performanceData['activity_trend_percentage'] ?? 0).toStringAsFixed(1)}%',
                  performanceData['activity_trend_percentage'] != null &&
                          performanceData['activity_trend_percentage'] >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  performanceData['activity_trend_percentage'] != null &&
                          performanceData['activity_trend_percentage'] >= 0
                      ? Colors.green
                      : Colors.red,
                ),
                _buildStatCard(
                  'This Month Activities',
                  '${performanceData['this_month_activities'] ?? 0}',
                  Icons.calendar_month,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Last Month Activities',
                  '${performanceData['last_month_activities'] ?? 0}',
                  Icons.history,
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final errorMessage =
        _detailedAnalytics['message'] ?? 'Unknown error occurred';

    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Unable to Load Analytics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'We encountered an issue while loading the user analytics data.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[700],
                  fontFamily: 'monospace',
                ),
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadDetailedAnalytics,
                  icon: Icon(Icons.refresh),
                  label: Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back),
                  label: Text('Go Back'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataWidget(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 48, color: Colors.grey[400]),
          SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
