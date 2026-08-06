// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminTrainingAnalyticsScreen extends StatefulWidget {
  const AdminTrainingAnalyticsScreen({super.key});

  @override
  State<AdminTrainingAnalyticsScreen> createState() =>
      _AdminTrainingAnalyticsScreenState();
}

class _AdminTrainingAnalyticsScreenState
    extends State<AdminTrainingAnalyticsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedMaterialType = 'all';

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
                  'Training Materials Analytics',
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
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
                Tab(icon: Icon(Icons.library_books), text: 'Materials'),
                Tab(icon: Icon(Icons.people), text: 'User Engagement'),
                Tab(icon: Icon(Icons.school), text: 'Courses'),
              ],
            ),
          ),
          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildMaterialsTab(),
                _buildUserEngagementTab(),
                _buildCoursesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .where('targetRole', isEqualTo: 'chw')
          .snapshots(),
      builder: (context, coursesSnapshot) {
        if (coursesSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (coursesSnapshot.hasError) {
          return Center(child: Text('Error: ${coursesSnapshot.error}'));
        }

        final courses = coursesSnapshot.data?.docs ?? [];
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('courseProgress')
              .snapshots(),
          builder: (context, progressSnapshot) {
            if (progressSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            final progressDocs = progressSnapshot.data?.docs ?? [];

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, usersSnapshot) {
                final usersById = <String, Map<String, dynamic>>{};
                if (usersSnapshot.hasData) {
                  for (final userDoc in usersSnapshot.data!.docs) {
                    usersById[userDoc.id] =
                        userDoc.data() as Map<String, dynamic>;
                  }
                }

                if (courses.isEmpty) {
                  return Center(child: Text('No courses created yet'));
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('certificateAccess')
                      .snapshots(),
                  builder: (context, accessSnapshot) {
                    final certificateAccessById =
                        <String, Map<String, dynamic>>{};
                    if (accessSnapshot.hasData) {
                      for (final accessDoc in accessSnapshot.data!.docs) {
                        certificateAccessById[accessDoc.id] =
                            accessDoc.data() as Map<String, dynamic>;
                      }
                    }

                    return ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: courses.length,
                      itemBuilder: (context, index) {
                        final courseDoc = courses[index];
                        final course = courseDoc.data() as Map<String, dynamic>;
                        final courseProgress = progressDocs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['courseId'] == courseDoc.id;
                        }).toList();
                        return _buildCourseAnalyticsCard(
                          courseDoc.id,
                          course,
                          courseProgress,
                          usersById,
                          certificateAccessById,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCourseAnalyticsCard(
    String courseId,
    Map<String, dynamic> course,
    List<QueryDocumentSnapshot> progressDocs,
    Map<String, Map<String, dynamic>> usersById,
    Map<String, Map<String, dynamic>> certificateAccessById,
  ) {
    final activeLearners = progressDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['courseCompleted'] != true;
    }).toList();
    final completedLearners = progressDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['courseCompleted'] == true;
    }).toList();
    final total = progressDocs.length;
    final completionRate = total == 0
        ? 0.0
        : completedLearners.length / total * 100;
    final isActive = course['status'] == 'active';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.green : Colors.grey,
          child: Icon(
            isActive ? Icons.visibility : Icons.visibility_off,
            color: Colors.white,
          ),
        ),
        title: Text(course['title'] ?? 'Untitled Course'),
        subtitle: Text(
          '${isActive ? 'Visible' : 'Hidden'} • ${activeLearners.length} active • ${completedLearners.length} completed • ${completionRate.toStringAsFixed(1)}%',
        ),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Active',
                  activeLearners.length.toString(),
                  Icons.play_circle,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Completed',
                  completedLearners.length.toString(),
                  Icons.verified,
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Completion',
                  '${completionRate.toStringAsFixed(1)}%',
                  Icons.trending_up,
                  Colors.purple,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildLearnerSection(
            'Currently Taking',
            activeLearners,
            usersById,
            certificateAccessById,
            courseId,
            false,
          ),
          SizedBox(height: 12),
          _buildLearnerSection(
            'Completed Learners',
            completedLearners,
            usersById,
            certificateAccessById,
            courseId,
            true,
          ),
        ],
      ),
    );
  }

  Widget _buildLearnerSection(
    String title,
    List<QueryDocumentSnapshot> progressDocs,
    Map<String, Map<String, dynamic>> usersById,
    Map<String, Map<String, dynamic>> certificateAccessById,
    String courseId,
    bool canGrantCertificate,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        if (progressDocs.isEmpty)
          Text(
            'No learners in this group',
            style: TextStyle(color: Colors.grey[600]),
          )
        else
          ...progressDocs.map((progressDoc) {
            final progress = progressDoc.data() as Map<String, dynamic>;
            final userId = progress['userId']?.toString() ?? '';
            final user = usersById[userId] ?? {};
            final name = _displayUserName(user, userId);
            final score = _bestQuizScore(progress);
            final certificateAccess =
                certificateAccessById['${userId}_$courseId'] ?? {};
            return ListTile(
              dense: true,
              leading: CircleAvatar(child: Text(_initials(name))),
              title: Text(name),
              subtitle: Text(
                'Progress ${progress['progressPercentage'] ?? 0}%${score == null ? '' : ' • Final score $score%'}',
              ),
              trailing: canGrantCertificate
                  ? _buildCertificateAccessAction(
                      courseId,
                      userId,
                      certificateAccess,
                    )
                  : null,
            );
          }),
      ],
    );
  }

  Widget _buildCertificateAccessAction(
    String courseId,
    String userId,
    Map<String, dynamic> certificateAccess,
  ) {
    final hasPaid = certificateAccess['paid'] == true;
    final hasFreeAccess = certificateAccess['freeGranted'] == true;

    if (hasPaid) {
      return Chip(
        label: Text('Paid'),
        visualDensity: VisualDensity.compact,
        backgroundColor: Colors.green.shade50,
        labelStyle: TextStyle(color: Colors.green.shade800),
      );
    }

    if (hasFreeAccess) {
      return OutlinedButton(
        onPressed: () => _confirmRevokeFreeCertificate(courseId, userId),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
        child: Text('Revoke Free'),
      );
    }

    return TextButton(
      onPressed: () => _grantFreeCertificate(courseId, userId),
      child: Text('Grant Free'),
    );
  }

  String _displayUserName(Map<String, dynamic> user, String userId) {
    final fullName = (user['fullName'] ?? user['name'])?.toString();
    if (fullName != null && fullName.trim().isNotEmpty) return fullName;
    final first = user['firstName']?.toString() ?? '';
    final last = user['lastName']?.toString() ?? '';
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;
    return userId.length > 8
        ? 'User ${userId.substring(0, 8)}'
        : 'Unknown User';
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  int? _bestQuizScore(Map<String, dynamic> progress) {
    final attempts = progress['quizAttempts'];
    if (attempts is! Map || attempts.isEmpty) return null;
    int? best;
    for (final value in attempts.values) {
      if (value is Map && value['score'] is num) {
        final score = (value['score'] as num).toInt();
        best = best == null ? score : (score > best ? score : best);
      }
    }
    return best;
  }

  Future<void> _grantFreeCertificate(String courseId, String userId) async {
    if (userId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('certificateAccess')
        .doc('${userId}_$courseId')
        .set({
          'userId': userId,
          'courseId': courseId,
          'freeGranted': true,
          'paid': false,
          'grantedBy': 'admin',
          'grantedAt': FieldValue.serverTimestamp(),
          'revokedBy': FieldValue.delete(),
          'revokedAt': FieldValue.delete(),
        }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Certificate download access granted')),
      );
    }
  }

  Future<void> _confirmRevokeFreeCertificate(
    String courseId,
    String userId,
  ) async {
    if (userId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revoke free certificate?'),
        content: Text(
          'This learner will no longer be able to download this certificate for free unless they have already paid or you grant access again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _revokeFreeCertificate(courseId, userId);
    }
  }

  Future<void> _revokeFreeCertificate(String courseId, String userId) async {
    await FirebaseFirestore.instance
        .collection('certificateAccess')
        .doc('${userId}_$courseId')
        .set({
          'userId': userId,
          'courseId': courseId,
          'freeGranted': false,
          'revokedBy': 'admin',
          'revokedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Free certificate access revoked')),
      );
    }
  }

  Widget _buildOverviewTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('training_materials')
          .snapshots(),
      builder: (context, materialsSnapshot) {
        if (materialsSnapshot.hasError) {
          return Center(child: Text('Error: ${materialsSnapshot.error}'));
        }

        if (materialsSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final materials = materialsSnapshot.data?.docs ?? [];

        // Calculate statistics from real-time data
        int totalViews = 0;
        int totalDownloads = 0;

        for (var doc in materials) {
          final data = doc.data() as Map<String, dynamic>;
          totalViews += (data['viewCount'] as int? ?? 0);
          totalDownloads += (data['downloadCount'] as int? ?? 0);
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('user_progress')
              .snapshots(),
          builder: (context, progressSnapshot) {
            if (progressSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            // Calculate completion rates
            Map<String, Map<String, dynamic>> materialProgress = {};
            final progressDocs = progressSnapshot.data?.docs ?? [];

            for (var progressDoc in progressDocs) {
              final data = progressDoc.data() as Map<String, dynamic>;
              final materialId = data['materialId'] as String?;
              if (materialId != null) {
                if (!materialProgress.containsKey(materialId)) {
                  materialProgress[materialId] = {'total': 0, 'completed': 0};
                }
                materialProgress[materialId]!['total'] =
                    (materialProgress[materialId]!['total'] as int) + 1;
                if (data['status'] == 'completed') {
                  materialProgress[materialId]!['completed'] =
                      (materialProgress[materialId]!['completed'] as int) + 1;
                }
              }
            }

            // Calculate average completion rate
            double averageCompletionRate = 0;
            if (materialProgress.isNotEmpty) {
              double totalRate = 0;
              materialProgress.forEach((key, value) {
                final total = value['total'] as int;
                final completed = value['completed'] as int;
                if (total > 0) {
                  totalRate += (completed / total * 100);
                }
              });
              averageCompletionRate = totalRate / materialProgress.length;
            }

            return RefreshIndicator(
              onRefresh: () async {
                // Refresh is automatic with StreamBuilder
                return Future.value();
              },
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Cards
                    GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _buildSummaryCard(
                          'Total Materials',
                          materials.length.toString(),
                          Icons.library_books,
                          Colors.blue,
                        ),
                        _buildSummaryCard(
                          'Total Views',
                          totalViews.toString(),
                          Icons.visibility,
                          Colors.green,
                        ),
                        _buildSummaryCard(
                          'Total Downloads',
                          totalDownloads.toString(),
                          Icons.download,
                          Colors.orange,
                        ),
                        _buildSummaryCard(
                          'Avg Completion Rate',
                          '${averageCompletionRate.toStringAsFixed(1)}%',
                          Icons.check_circle,
                          Colors.purple,
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Material Type Breakdown
                    _buildMaterialTypeBreakdownRealtime(materials),

                    SizedBox(height: 24),

                    // Top Performing Materials
                    _buildTopPerformingMaterialsRealtime(
                      materials,
                      materialProgress,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMaterialsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('training_materials')
          .snapshots(),
      builder: (context, materialsSnapshot) {
        if (materialsSnapshot.hasError) {
          return Center(child: Text('Error: ${materialsSnapshot.error}'));
        }

        if (materialsSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final materials = materialsSnapshot.data?.docs ?? [];

        return Column(
          children: [
            _buildMaterialFilters(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  return Future.value();
                },
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('user_progress')
                      .snapshots(),
                  builder: (context, progressSnapshot) {
                    return ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: materials.length,
                      itemBuilder: (context, index) {
                        final materialDoc = materials[index];
                        final progressDocs = progressSnapshot.data?.docs ?? [];
                        return _buildMaterialCardRealtime(
                          materialDoc,
                          progressDocs,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserEngagementTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_progress')
          .snapshots(),
      builder: (context, progressSnapshot) {
        if (progressSnapshot.hasError) {
          return Center(child: Text('Error: ${progressSnapshot.error}'));
        }

        if (progressSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('training_materials')
              .snapshots(),
          builder: (context, materialsSnapshot) {
            if (materialsSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            final progressDocs = progressSnapshot.data?.docs ?? [];

            // Aggregate user engagement data in real-time
            Map<String, Map<String, dynamic>> userEngagement = {};

            for (var progressDoc in progressDocs) {
              final progressData = progressDoc.data() as Map<String, dynamic>;
              final userId = progressData['userId'] as String?;

              if (userId == null) continue;

              if (!userEngagement.containsKey(userId)) {
                userEngagement[userId] = {
                  'name': 'Loading...',
                  'role': 'unknown',
                  'materials_accessed': 0,
                  'materials_completed': 0,
                  'total_time_spent': 0.0,
                  'interactions': <Map<String, dynamic>>[],
                };
              }

              userEngagement[userId]!['materials_accessed'] =
                  (userEngagement[userId]!['materials_accessed'] as int) + 1;

              if (progressData['status'] == 'completed') {
                userEngagement[userId]!['materials_completed'] =
                    (userEngagement[userId]!['materials_completed'] as int) + 1;
              }

              userEngagement[userId]!['total_time_spent'] =
                  (userEngagement[userId]!['total_time_spent'] as num)
                      .toDouble() +
                  ((progressData['timeSpentMinutes'] as num?)?.toDouble() ?? 0);
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, usersSnapshot) {
                // Update user names and roles from users collection
                if (usersSnapshot.hasData) {
                  for (var userDoc in usersSnapshot.data!.docs) {
                    final userData = userDoc.data() as Map<String, dynamic>;
                    final userId = userDoc.id;

                    if (userEngagement.containsKey(userId)) {
                      userEngagement[userId]!['name'] =
                          userData['fullName'] ?? userData['name'] ?? 'Unknown';
                      userEngagement[userId]!['role'] =
                          userData['role'] ?? 'unknown';
                    }
                  }
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    return Future.value();
                  },
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEngagementSummary(userEngagement),
                        SizedBox(height: 24),
                        _buildUserEngagementList(userEngagement),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialTypeBreakdownRealtime(
    List<QueryDocumentSnapshot> materials,
  ) {
    Map<String, int> typeCount = {};
    Map<String, int> typeViews = {};

    for (var doc in materials) {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['type'] as String? ?? 'unknown';
      typeCount[type] = (typeCount[type] ?? 0) + 1;
      typeViews[type] =
          (typeViews[type] ?? 0) + (data['viewCount'] as int? ?? 0);
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Material Type Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ...typeCount.entries.map((entry) {
              final type = entry.key;
              final count = entry.value;
              final views = typeViews[type] ?? 0;
              final percentage = materials.isEmpty
                  ? 0
                  : (count / materials.length * 100);

              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          type.toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '$count materials (${percentage.toStringAsFixed(1)}%)',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getTypeColor(type),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '$views total views',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPerformingMaterialsRealtime(
    List<QueryDocumentSnapshot> materials,
    Map<String, Map<String, dynamic>> materialProgress,
  ) {
    // Convert to list with completion rates
    List<Map<String, dynamic>> materialsWithStats = materials.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final progress = materialProgress[doc.id];
      final total = progress?['total'] as int? ?? 0;
      final completed = progress?['completed'] as int? ?? 0;
      final completionRate = total > 0 ? (completed / total * 100) : 0.0;

      return {
        'id': doc.id,
        'title': data['title'] ?? 'Untitled',
        'type': data['type'] ?? 'unknown',
        'view_count': data['viewCount'] ?? 0,
        'unique_viewers': total,
        'completion_rate': completionRate,
      };
    }).toList();

    // Sort by view count
    materialsWithStats.sort(
      (a, b) => (b['view_count'] as int).compareTo(a['view_count'] as int),
    );
    final topMaterials = materialsWithStats.take(5).toList();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Performing Materials',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ...topMaterials.asMap().entries.map((entry) {
              final index = entry.key;
              final material = entry.value;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRankColor(index),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  material['title'] as String,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${material['type']} • ${material['view_count']} views • ${material['unique_viewers']} unique viewers',
                ),
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(material['completion_rate'] as num).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialCardRealtime(
    QueryDocumentSnapshot materialDoc,
    List<QueryDocumentSnapshot> progressDocs,
  ) {
    final data = materialDoc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Untitled';
    final type = data['type'] as String? ?? 'unknown';
    final viewCount = data['viewCount'] as int? ?? 0;
    final downloadCount = data['downloadCount'] as int? ?? 0;

    // Skip if filtered
    if (_selectedMaterialType != 'all' && type != _selectedMaterialType) {
      return Container();
    }

    // Filter progress for this material
    final materialProgress = progressDocs.where((doc) {
      final progressData = doc.data() as Map<String, dynamic>;
      return progressData['materialId'] == materialDoc.id;
    }).toList();

    final uniqueViewers = materialProgress.length;
    final completed = materialProgress.where((doc) {
      final progressData = doc.data() as Map<String, dynamic>;
      return progressData['status'] == 'completed';
    }).length;
    final completionRate = uniqueViewers > 0
        ? (completed / uniqueViewers * 100)
        : 0.0;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(type),
          child: Icon(_getTypeIcon(type), color: Colors.white),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${type.toUpperCase()} • $viewCount views • $uniqueViewers unique viewers',
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Statistics Row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Views',
                        viewCount.toString(),
                        Icons.visibility,
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Downloads',
                        downloadCount.toString(),
                        Icons.download,
                        Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Completion',
                        '${completionRate.toStringAsFixed(1)}%',
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // User Interactions
                Text(
                  'Active Users (${materialProgress.length})',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),

                if (materialProgress.isEmpty)
                  Text(
                    'No user interactions yet',
                    style: TextStyle(color: Colors.grey[600]),
                  )
                else
                  ...materialProgress.take(5).map((progressDoc) {
                    final progressData =
                        progressDoc.data() as Map<String, dynamic>;
                    final progress =
                        (progressData['progressPercentage'] as num?)
                            ?.toDouble() ??
                        0;
                    final status = progressData['status'] ?? 'in_progress';

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      title: Text(
                        'User ${progressData['userId']?.toString().substring(0, 8) ?? 'Unknown'}',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        '$status • ${progress.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 12),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Text('Filter by type: '),
          SizedBox(width: 8),
          DropdownButton<String>(
            value: _selectedMaterialType,
            onChanged: (value) {
              setState(() => _selectedMaterialType = value ?? 'all');
            },
            items: [
              DropdownMenuItem(value: 'all', child: Text('All Types')),
              DropdownMenuItem(value: 'video', child: Text('Videos')),
              DropdownMenuItem(value: 'pdf', child: Text('PDFs')),
              DropdownMenuItem(value: 'article', child: Text('Articles')),
              DropdownMenuItem(
                value: 'interactive',
                child: Text('Interactive'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(8),
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildEngagementSummary(
    Map<String, Map<String, dynamic>> userEngagement,
  ) {
    final totalUsers = userEngagement.length;
    final avgMaterialsAccessed = totalUsers == 0
        ? 0.0
        : userEngagement.values.fold<int>(
                0,
                (sum, user) => sum + (user['materials_accessed'] as int),
              ) /
              totalUsers;
    final totalTimeSpent = userEngagement.values.fold<double>(
      0,
      (sum, user) => sum + (user['total_time_spent'] as num).toDouble(),
    );

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Engagement Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                _buildStatItem(
                  'Active Users',
                  totalUsers.toString(),
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatItem(
                  'Avg Materials/User',
                  avgMaterialsAccessed.toStringAsFixed(1),
                  Icons.library_books,
                  Colors.green,
                ),
                _buildStatItem(
                  'Total Time Spent',
                  '${totalTimeSpent.toInt()} min',
                  Icons.access_time,
                  Colors.orange,
                ),
                _buildStatItem(
                  'Avg Time/User',
                  totalUsers == 0
                      ? '0 min'
                      : '${(totalTimeSpent / totalUsers).toInt()} min',
                  Icons.person_pin_circle,
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserEngagementList(
    Map<String, Map<String, dynamic>> userEngagement,
  ) {
    final sortedUsers = userEngagement.entries.toList();
    sortedUsers.sort(
      (a, b) => (b.value['materials_accessed'] as int).compareTo(
        a.value['materials_accessed'] as int,
      ),
    );

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Most Engaged Users',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ...sortedUsers.take(10).map((entry) {
              final userData = entry.value;
              final materialsAccessed = userData['materials_accessed'] as int;
              final materialsCompleted = userData['materials_completed'] as int;
              final timeSpent = (userData['total_time_spent'] as num)
                  .toDouble();
              final completionRate = materialsAccessed == 0
                  ? 0.0
                  : (materialsCompleted / materialsAccessed * 100);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRoleColor(userData['role']),
                  child: Text(
                    userData['name'].toString()[0].toUpperCase(),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(userData['name'] as String),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${userData['role']} • $materialsAccessed materials accessed',
                    ),
                    SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '$materialsCompleted completed • ${timeSpent.toInt()} min • ',
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: completionRate >= 70
                                ? Colors.green
                                : completionRate >= 40
                                ? Colors.orange
                                : Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${completionRate.toStringAsFixed(0)}%',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'video':
        return Colors.red;
      case 'pdf':
        return Colors.orange;
      case 'article':
        return Colors.blue;
      case 'interactive':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'video':
        return Icons.play_circle;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'article':
        return Icons.article;
      case 'interactive':
        return Icons.touch_app;
      default:
        return Icons.description;
    }
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.grey;
      case 2:
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'patient':
        return Colors.blue;
      case 'doctor':
        return Colors.red;
      case 'chw':
        return Colors.orange;
      case 'facility':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}
