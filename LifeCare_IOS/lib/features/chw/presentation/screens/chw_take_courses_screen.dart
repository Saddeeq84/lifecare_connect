// ignore_for_file: prefer_const_constructors, avoid_print, avoid_function_literals_in_foreach_calls

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../shared/data/services/wallet_service.dart';
import '../../data/models/course_model.dart';
import '../../data/services/course_certificate_pdf_service.dart';
import 'chw_course_details_screen.dart';

class CHWTakeCoursesScreen extends StatefulWidget {
  const CHWTakeCoursesScreen({super.key});

  @override
  State<CHWTakeCoursesScreen> createState() => _CHWTakeCoursesScreenState();
}

class _CHWTakeCoursesScreenState extends State<CHWTakeCoursesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedCategory = 'all';
  String _searchQuery = '';

  final List<String> categories = [
    'all',
    'maternal_health',
    'child_health',
    'nutrition',
    'disease_management',
    'communication',
    'other',
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Take Course'),
          backgroundColor: Colors.teal,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Courses'),
              Tab(text: 'Certificates'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildCoursesTab(), _buildCertificatesTab()],
        ),
      ),
    );
  }

  Widget _buildCoursesTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.teal,
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search courses...',
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                hintStyle: const TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          // Category Filter
          Container(
            color: Colors.teal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                labelStyle: const TextStyle(color: Colors.white),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownColor: Colors.teal,
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              items: categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(
                    _formatCategoryName(category),
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
          ),
          // Courses List
          StreamBuilder<QuerySnapshot>(
            stream: _getCoursesStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final courses = snapshot.data!.docs
                  .map((doc) => Course.fromFirestore(doc))
                  .toList();

              // Filter by search query
              final filteredCourses = courses
                  .where(
                    (course) =>
                        course.title.toLowerCase().contains(_searchQuery) ||
                        course.description.toLowerCase().contains(_searchQuery),
                  )
                  .toList();

              if (filteredCourses.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredCourses.length,
                itemBuilder: (context, index) {
                  return _buildCourseCard(context, filteredCourses[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCertificatesTab() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Please log in to view certificates.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('courseProgress')
          .where('userId', isEqualTo: userId)
          .where('courseCompleted', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final progresses = snapshot.data!.docs
            .map((doc) => CourseProgress.fromFirestore(doc))
            .toList();

        if (progresses.isEmpty) {
          return _buildEmptyCertificatesState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: progresses.length,
          itemBuilder: (context, index) {
            final progress = progresses[index];
            return FutureBuilder<DocumentSnapshot>(
              future: _firestore
                  .collection('courses')
                  .doc(progress.courseId)
                  .get(),
              builder: (context, courseSnapshot) {
                if (courseSnapshot.connectionState == ConnectionState.waiting) {
                  return const Card(child: ListTile(title: Text('Loading...')));
                }

                if (courseSnapshot.hasError || !courseSnapshot.data!.exists) {
                  return Card(
                    child: ListTile(
                      title: Text('Course not found'),
                      subtitle: Text('ID: ${progress.courseId}'),
                    ),
                  );
                }

                final course = Course.fromFirestore(courseSnapshot.data!);
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(course.title),
                    subtitle: Text(
                      'Completed on ${progress.completedAt?.toLocal().toString().split(' ')[0] ?? 'N/A'}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () =>
                          _handleCertificateDownload(course, progress),
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

  Future<void> _handleCertificateDownload(
    Course course,
    CourseProgress progress,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    if (!_isCertificateEligible(progress)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Certificate is available after 100% completion and at least 70% in the final assessment.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final accessDoc = await _firestore
        .collection('certificateAccess')
        .doc('${userId}_${course.id}')
        .get();
    final access = accessDoc.data() ?? {};
    final unlocked = access['paid'] == true || access['freeGranted'] == true;
    final learnerName = await _getCurrentLearnerName();
    final certificateFee = course.certificateFee;

    final confirmed = await _confirmCertificateDownload(
      course: course,
      learnerName: learnerName,
      certificateFee: certificateFee,
      unlocked: unlocked,
    );
    if (confirmed != true) return;

    if (!unlocked) {
      if (certificateFee <= 0) {
        await _firestore
            .collection('certificateAccess')
            .doc('${userId}_${course.id}')
            .set({
              'userId': userId,
              'courseId': course.id,
              'paid': false,
              'freeGranted': true,
              'amount': 0,
              'grantedReason': 'Course certificate fee is free',
              'grantedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } else {
        final paid = await WalletService.deductWallet(
          certificateFee,
          description: 'Certificate download: ${course.title}',
        );
        if (!paid) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Insufficient wallet balance for certificate payment.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        await _firestore
            .collection('certificateAccess')
            .doc('${userId}_${course.id}')
            .set({
              'userId': userId,
              'courseId': course.id,
              'paid': true,
              'freeGranted': false,
              'amount': certificateFee,
              'paidAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    }

    await _downloadCertificate(course, progress, learnerName);
  }

  bool _isCertificateEligible(CourseProgress progress) {
    if (!progress.courseCompleted || progress.progressPercentage < 100) {
      return false;
    }
    if (progress.quizAttempts.isEmpty) return false;
    return progress.quizAttempts.values.any(
      (attempt) => attempt.passed && attempt.score >= 70,
    );
  }

  Future<bool?> _confirmCertificateDownload({
    required Course course,
    required String learnerName,
    required double certificateFee,
    required bool unlocked,
  }) {
    final today = DateFormat('MMMM d, yyyy').format(DateTime.now());
    final feeText = certificateFee <= 0
        ? 'Free'
        : '₦${certificateFee.toStringAsFixed(0)}';
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview Certificate Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPreviewRow('Learner name', learnerName),
            _buildPreviewRow('Course', course.title),
            _buildPreviewRow('Certificate date', today),
            _buildPreviewRow(
              'Certificate cost',
              unlocked ? 'Already unlocked' : feeText,
            ),
            const SizedBox(height: 12),
            Text(
              unlocked
                  ? 'This certificate is already unlocked. You can download it again without another payment.'
                  : certificateFee <= 0
                  ? 'No payment is required for this certificate.'
                  : 'Payment will be deducted from your wallet only after you confirm. Once confirmed, you can download this certificate unlimited times.',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              unlocked || certificateFee <= 0
                  ? 'Download Certificate'
                  : 'Confirm & Pay',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadCertificate(
    Course course,
    CourseProgress progress,
    String learnerName,
  ) async {
    final issuedDate = DateTime.now();
    final score = _bestCertificateScore(progress);
    final certificateId =
        '${progress.userId.substring(0, progress.userId.length < 8 ? progress.userId.length : 8)}-${course.id.substring(0, course.id.length < 8 ? course.id.length : 8)}';
    final pdf = await CourseCertificatePdfService.buildCertificate(
      learnerName: learnerName,
      courseTitle: course.title,
      issuedDate: issuedDate,
      certificateId: certificateId,
      signatureUrl: course.certificateSignatureUrl,
    );

    await Printing.layoutPdf(
      name:
          'Certificate_${course.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf',
      onLayout: (format) => pdf.save(),
    );

    await _firestore
        .collection('courseCertificates')
        .doc('${progress.userId}_${course.id}')
        .set({
          'userId': progress.userId,
          'courseId': course.id,
          'courseName': course.title,
          'finalScore': score ?? 70,
          'issuedAt': issuedDate,
          'lastDownloadedAt': FieldValue.serverTimestamp(),
          'certificateUrl': '',
        }, SetOptions(merge: true));
  }

  Future<String> _getCurrentLearnerName() async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    if (userId == null) return user?.displayName ?? 'Learner';
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final data = userDoc.data() ?? {};
    final fullName = (data['fullName'] ?? data['name'])?.toString();
    if (fullName != null && fullName.trim().isNotEmpty) return fullName.trim();
    final first = data['firstName']?.toString() ?? '';
    final last = data['lastName']?.toString() ?? '';
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;
    return user?.displayName ?? 'Learner';
  }

  int? _bestCertificateScore(CourseProgress progress) {
    int? best;
    for (final attempt in progress.quizAttempts.values) {
      if (attempt.passed && attempt.score >= 70) {
        best = best == null
            ? attempt.score
            : (attempt.score > best ? attempt.score : best);
      }
    }
    return best;
  }

  Widget _buildEmptyCertificatesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No certificates yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete courses to earn certificates',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  /// Get courses stream filtered by category
  Stream<QuerySnapshot> _getCoursesStream() {
    Query query = _firestore
        .collection('courses')
        .where('status', isEqualTo: 'active')
        .where('targetRole', isEqualTo: 'chw')
        .orderBy('createdAt', descending: true);

    if (_selectedCategory != 'all') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    return query.snapshots();
  }

  /// Build course card
  Widget _buildCourseCard(BuildContext context, Course course) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course Image
          if (course.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.network(
                course.imageUrl!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Colors.teal.shade100,
                    child: const Icon(
                      Icons.school,
                      size: 64,
                      color: Colors.teal,
                    ),
                  );
                },
              ),
            )
          else
            Container(
              height: 150,
              color: Colors.teal.shade100,
              child: const Icon(Icons.school, size: 64, color: Colors.teal),
            ),

          // Course Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Badge
                Chip(
                  label: Text(
                    _formatCategoryName(course.category),
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  course.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  course.description,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Course Info Row
                Row(
                  children: [
                    Icon(Icons.book, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      '${course.totalLessons} lessons',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      '${course.durationWeeks} weeks',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.language, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      '${course.availableLanguages.length} langs',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Enroll Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CHWCourseDetailsScreen(course: course),
                        ),
                      );
                    },
                    child: const Text(
                      'View & Enroll',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
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

  /// Build empty state
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No courses available' : 'No courses found',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Check back later for new courses'
                : 'Try a different search term',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// Format category name for display
  String _formatCategoryName(String category) {
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
