// ignore_for_file: prefer_const_constructors, avoid_print, avoid_function_literals_in_foreach_calls

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifecare_connect/utils/web_utils.dart';
import '../../../../core/services/local_cache_service.dart';
import '../../../../core/services/low_data_mode_service.dart';
import '../../../shared/data/services/wallet_service.dart';
import '../../data/models/course_model.dart';
import '../../data/services/course_certificate_pdf_service.dart';
import 'chw_course_details_screen.dart';

class CHWTakeCoursesScreen extends StatefulWidget {
  final String learnerRole;

  const CHWTakeCoursesScreen({super.key, this.learnerRole = 'chw'});

  @override
  State<CHWTakeCoursesScreen> createState() => _CHWTakeCoursesScreenState();
}

class _CHWTakeCoursesScreenState extends State<CHWTakeCoursesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalCacheService _cache = LocalCacheService();
  final LowDataModeService _lowDataMode = LowDataModeService();
  String _selectedCategory = 'all';
  String _searchQuery = '';
  String? _lastCertificatePaymentReference;

  final List<String> categories = [
    'all',
    'maternal_health',
    'child_health',
    'nutrition',
    'disease_management',
    'public_health',
    'communication',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _lowDataMode.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Take Course'),
          backgroundColor: Colors.teal,
          elevation: 0,
          actions: [
            AnimatedBuilder(
              animation: _lowDataMode,
              builder: (context, _) {
                return IconButton(
                  tooltip: _lowDataMode.enabled
                      ? 'Low-data mode is on'
                      : 'Low-data mode is off',
                  onPressed: () async {
                    await _lowDataMode.setEnabled(!_lowDataMode.enabled);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _lowDataMode.enabled
                              ? 'Low-data mode enabled. Images and videos load only when requested.'
                              : 'Low-data mode disabled.',
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    _lowDataMode.enabled
                        ? Icons.signal_cellular_alt
                        : Icons.signal_cellular_4_bar,
                  ),
                );
              },
            ),
          ],
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
                return FutureBuilder<List<Course>>(
                  future: _cachedCourses(),
                  builder: (context, cacheSnapshot) {
                    final cached = cacheSnapshot.data ?? const <Course>[];
                    if (cached.isEmpty) {
                      return _buildCourseLoadError(snapshot.error);
                    }
                    return Column(
                      children: [
                        _offlineCachedNotice('Showing saved course list.'),
                        ListView.builder(
                          padding: const EdgeInsets.all(16),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cached.length,
                          itemBuilder: (context, index) {
                            return _buildCourseCard(context, cached[index]);
                          },
                        ),
                      ],
                    );
                  },
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final courses = snapshot.data!.docs
                  .map((doc) => Course.fromFirestore(doc))
                  .toList();
              Future.microtask(() => _cacheCourses(courses));

              // Filter by search query
              final filteredCourses = courses
                  .where(
                    (course) =>
                        _courseVisibleToLearner(course) &&
                        _courseMatchesSelectedCategory(course) &&
                        (course.title.toLowerCase().contains(_searchQuery) ||
                            course.description.toLowerCase().contains(
                              _searchQuery,
                            )),
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
    return FutureBuilder<String?>(
      future: _currentLearnerId(),
      builder: (context, learnerSnapshot) {
        if (learnerSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final userId = learnerSnapshot.data;
        if (userId == null) {
          return const Center(
            child: Text('Please log in to view certificates.'),
          );
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
                    if (courseSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Card(
                        child: ListTile(title: Text('Loading...')),
                      );
                    }

                    if (courseSnapshot.hasError ||
                        !courseSnapshot.data!.exists) {
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
      },
    );
  }

  Future<void> _handleCertificateDownload(
    Course course,
    CourseProgress progress,
  ) async {
    final userId = await _currentLearnerId();
    if (userId == null) return;
    if (!mounted) return;

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
        final paymentMethod = await _selectCertificatePaymentMethod(
          certificateFee,
        );
        if (paymentMethod == null) return;
        final paid = paymentMethod == 'card'
            ? await _payCertificateByCard(course, certificateFee)
            : await WalletService.deductWallet(
                certificateFee,
                description: 'Certificate download: ${course.title}',
              );
        if (!paid) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                paymentMethod == 'card'
                    ? 'Card payment was not completed or could not be verified.'
                    : 'Insufficient wallet balance for certificate payment.',
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
              'paymentMethod': paymentMethod,
              if (_lastCertificatePaymentReference != null)
                'paymentReference': _lastCertificatePaymentReference,
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
                  : 'After confirmation, choose card payment or wallet payment where available. Once paid, you can download this certificate unlimited times.',
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
    final prefs = await SharedPreferences.getInstance();
    final staffName = prefs.getString('staff_name');
    final userRole = prefs.getString('user_role');
    if ((userRole == 'facility_staff' ||
            userRole == 'service_provider_staff') &&
        staffName != null &&
        staffName.trim().isNotEmpty) {
      return staffName.trim();
    }
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

  Future<String?> _currentLearnerId() async {
    final authId = FirebaseAuth.instance.currentUser?.uid;
    if (authId != null && authId.isNotEmpty) return authId;
    final prefs = await SharedPreferences.getInstance();
    final staffId = prefs.getString('staff_id');
    if (staffId != null && staffId.trim().isNotEmpty) return staffId.trim();
    final userId = prefs.getString('user_id');
    if (userId != null && userId.trim().isNotEmpty) return userId.trim();
    return null;
  }

  Future<String> _currentLearnerEmail() async {
    final authEmail = FirebaseAuth.instance.currentUser?.email;
    if (authEmail != null && authEmail.trim().isNotEmpty) {
      return authEmail.trim();
    }
    final prefs = await SharedPreferences.getInstance();
    final staffEmail = prefs.getString('staff_email');
    if (staffEmail != null && staffEmail.trim().isNotEmpty) {
      return staffEmail.trim();
    }
    return 'noemail@example.com';
  }

  Future<String?> _selectCertificatePaymentMethod(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('user_role');
    final staffWithoutWallet =
        userRole == 'facility_staff' || userRole == 'service_provider_staff';
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Certificate Payment'),
        content: Text(
          'Certificate fee: ₦${amount.toStringAsFixed(0)}\n\n'
          'Select how you want to pay. Card payment is available for facility staff and for users who prefer not to use wallet balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (!staffWithoutWallet)
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'wallet'),
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Wallet'),
            ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'card'),
            icon: const Icon(Icons.credit_card),
            label: const Text('Card'),
          ),
        ],
      ),
    );
  }

  Future<bool> _payCertificateByCard(Course course, double amount) async {
    final email = await _currentLearnerEmail();
    final reference =
        'CERT_${course.id}_${DateTime.now().millisecondsSinceEpoch}';
    _lastCertificatePaymentReference = null;
    try {
      final initResponse = await http.post(
        Uri.parse(
          'https://us-central1-lifecare-connect.cloudfunctions.net/paystackInitialize',
        ),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'amount': (amount * 100).round(),
          'reference': reference,
        }),
      );
      final initData = jsonDecode(initResponse.body);
      if (initResponse.statusCode != 200 || initData['status'] != true) {
        throw Exception(initData['message'] ?? 'Unable to initialize payment');
      }
      final authUrl = initData['data']['authorization_url'];
      await openWebTab(authUrl);
      if (!mounted) return false;
      final shouldVerify = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete Card Payment'),
          content: const Text(
            'The Paystack payment page has opened. After completing payment, click “I have paid” to verify and unlock your certificate.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('I have paid'),
            ),
          ],
        ),
      );
      if (shouldVerify != true) return false;
      final verifyResponse = await http.post(
        Uri.parse(
          'https://us-central1-lifecare-connect.cloudfunctions.net/paystackVerify',
        ),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'reference': reference}),
      );
      final verifyData = jsonDecode(verifyResponse.body);
      final success =
          verifyResponse.statusCode == 200 &&
          verifyData['status'] == true &&
          verifyData['data']?['status'] == 'success';
      if (success) _lastCertificatePaymentReference = reference;
      return success;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Card payment error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
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

  /// Get active courses. Category filtering is done locally to avoid requiring
  /// a composite Firestore index for every category + date query path.
  Stream<QuerySnapshot> _getCoursesStream() {
    return _firestore
        .collection('courses')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(120)
        .snapshots();
  }

  bool _courseVisibleToLearner(Course course) {
    final target = course.targetRole.toLowerCase().trim();
    final role = widget.learnerRole.toLowerCase().trim();
    return target == 'all' ||
        target == role ||
        target == 'chw' ||
        (role == 'facility_staff' && target == 'staff') ||
        (role == 'doctor' && target == 'clinical');
  }

  bool _courseMatchesSelectedCategory(Course course) {
    if (_selectedCategory == 'all') return true;
    final normalizedCourseCategory = _normalizeCategory(course.category);
    final normalizedSelectedCategory = _normalizeCategory(_selectedCategory);
    return normalizedCourseCategory == normalizedSelectedCategory;
  }

  String _normalizeCategory(String category) {
    if (category == 'community_health_prevention' ||
        category == 'public_health') {
      return 'public_health';
    }
    return category;
  }

  String get _courseCacheKey =>
      'courses_${widget.learnerRole}_$_selectedCategory';

  Future<void> _cacheCourses(List<Course> courses) async {
    final visible = courses
        .where(
          (course) =>
              _courseVisibleToLearner(course) &&
              _courseMatchesSelectedCategory(course),
        )
        .toList();
    await _cache.set(
      key: _courseCacheKey,
      data: visible.map(_courseCacheMap).toList(),
      expiry: const Duration(days: 14),
    );
  }

  Future<List<Course>> _cachedCourses() async {
    final cached = await _cache.get(_courseCacheKey);
    if (cached is! List) return const [];
    final courses = cached
        .whereType<Map>()
        .map(
          (item) =>
              Course.fromMap(Map<String, dynamic>.from(item), '${item['id']}'),
        )
        .where(
          (course) =>
              _courseVisibleToLearner(course) &&
              _courseMatchesSelectedCategory(course) &&
              (course.title.toLowerCase().contains(_searchQuery) ||
                  course.description.toLowerCase().contains(_searchQuery)),
        )
        .toList();
    return courses;
  }

  Widget _buildCourseLoadError(Object? error) {
    final message = error.toString().contains('failed-precondition')
        ? 'Courses are temporarily unavailable while the list is being prepared. Please try again shortly.'
        : 'Unable to load courses. Please check your connection and try again.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red.shade700),
        ),
      ),
    );
  }

  Map<String, dynamic> _courseCacheMap(Course course) {
    return {
      ...course.toMap(),
      'id': course.id,
      'createdAt': course.createdAt.toIso8601String(),
      'updatedAt': course.updatedAt?.toIso8601String(),
    };
  }

  Widget _offlineCachedNotice(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.orange.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
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
    if (category == 'community_health_prevention' ||
        category == 'public_health') {
      return 'Public Health';
    }
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
