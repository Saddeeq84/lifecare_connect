// ignore_for_file: avoid_print

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserAnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Safe conversion of dynamic values to double
  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Get comprehensive user analytics data
  static Future<Map<String, dynamic>> getUserAnalytics({
    required String userId,
    String? role,
  }) async {
    try {
      // Add timeout to prevent infinite loading
      return await Future.any([
        _getUserAnalyticsInternal(userId: userId, role: role),
        Future.delayed(Duration(seconds: 15), () {
          print('Analytics loading timeout after 15 seconds');
          return <String, dynamic>{
            'error': 'timeout',
            'message': 'Analytics loading took too long',
          };
        }),
      ]);
    } catch (e) {
      print('Error getting user analytics: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> _getUserAnalyticsInternal({
    required String userId,
    String? role,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return {};

      final userData = userDoc.data()!;
      final userRole = userData['role']?.toString().toLowerCase() ?? '';

      Map<String, dynamic> analytics = {
        'user_info': userData,
        'role': userRole,
      };

      // Training Materials Analytics
      analytics.addAll(await _getTrainingMaterialAnalytics(userId, userRole));

      // Activity Analytics
      analytics.addAll(await _getActivityAnalytics(userId, userRole));

      // Performance Metrics
      analytics.addAll(await _getPerformanceMetrics(userId, userRole));

      return analytics;
    } catch (e) {
      print('Error getting user analytics: $e');
      return {};
    }
  }

  /// Get training material related analytics
  static Future<Map<String, dynamic>> _getTrainingMaterialAnalytics(
    String userId,
    String userRole,
  ) async {
    try {
      print('Getting training material analytics for: $userId');
      Map<String, dynamic> trainingAnalytics = {};

      // Get user progress on training materials
      print('Fetching user progress...');
      final progressSnapshot = await _firestore
          .collection('user_progress')
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(
            Duration(seconds: 5),
            onTimeout: () {
              print('User progress query timed out');
              throw TimeoutException('User progress query timeout');
            },
          );

      List<Map<String, dynamic>> trainingProgress = [];
      int totalWatched = 0;
      int totalRead = 0;
      int totalDownloaded = 0;
      int totalCompleted = 0;
      double totalTimeSpent = 0;

      print('Processing ${progressSnapshot.docs.length} progress documents');

      for (var doc in progressSnapshot.docs) {
        final progressData = doc.data();
        trainingProgress.add(progressData);

        final status = progressData['status']?.toString() ?? '';
        final timeSpent = _safeToDouble(progressData['timeSpentMinutes']);
        totalTimeSpent += timeSpent;

        if (status == 'completed') totalCompleted++;

        // Get material details to categorize
        final materialId = progressData['materialId'];
        if (materialId != null) {
          try {
            final materialDoc = await _firestore
                .collection('training_materials')
                .doc(materialId)
                .get()
                .timeout(Duration(seconds: 2));

            if (materialDoc.exists) {
              final materialData = materialDoc.data()!;
              final type = materialData['type']?.toString() ?? '';

              if (type == 'video') totalWatched++;
              if (type == 'pdf' || type == 'article') totalRead++;
            }
          } catch (e) {
            print('Error fetching material $materialId: $e');
            // Continue processing other materials
          }
        }
      }

      // Get download activities from user activities log
      print('Fetching download activities...');
      final downloadActivities = await _firestore
          .collection('user_activities')
          .where('userId', isEqualTo: userId)
          .where('action', isEqualTo: 'download')
          .get()
          .timeout(
            Duration(seconds: 5),
            onTimeout: () {
              print('Download activities query timed out');
              return _firestore
                  .collection('user_activities')
                  .limit(0)
                  .get(); // Return empty
            },
          );

      totalDownloaded = downloadActivities.docs.length;

      print('Training analytics complete');

      trainingAnalytics['training_materials'] = {
        'videos_watched': totalWatched,
        'materials_read': totalRead,
        'materials_downloaded': totalDownloaded,
        'completed_trainings': totalCompleted,
        'total_training_time_minutes': totalTimeSpent,
        'progress_details': trainingProgress,
      };

      return trainingAnalytics;
    } catch (e) {
      print('Error getting training analytics: $e');
      return {
        'training_materials': {
          'videos_watched': 0,
          'materials_read': 0,
          'materials_downloaded': 0,
          'completed_trainings': 0,
          'total_training_time_minutes': 0.0,
          'progress_details': [],
        },
      };
    }
  }

  /// Get activity analytics based on user role
  static Future<Map<String, dynamic>> _getActivityAnalytics(
    String userId,
    String userRole,
  ) async {
    try {
      Map<String, dynamic> activityData = {};

      switch (userRole) {
        case 'patient':
          activityData = await _getPatientActivityAnalytics(userId);
          break;
        case 'doctor':
          activityData = await _getDoctorActivityAnalytics(userId);
          break;
        case 'chw':
          activityData = await _getCHWActivityAnalytics(userId);
          break;
        case 'facility':
          activityData = await _getFacilityActivityAnalytics(userId);
          break;
      }

      return {'activity_analytics': activityData};
    } catch (e) {
      print('Error getting activity analytics: $e');
      return {'activity_analytics': {}};
    }
  }

  /// Patient specific analytics
  static Future<Map<String, dynamic>> _getPatientActivityAnalytics(
    String userId,
  ) async {
    try {
      print('Getting patient activity analytics for: $userId');

      // Get appointments
      print('Fetching appointments...');
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: userId)
          .get()
          .timeout(
            Duration(seconds: 5),
            onTimeout: () {
              print('Appointments query timed out');
              return Future.error('Appointments query timeout');
            },
          );

      int totalAppointments = appointmentsSnapshot.docs.length;
      int completedAppointments = appointmentsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'completed')
          .length;
      int cancelledAppointments = appointmentsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'cancelled')
          .length;

      print('Appointments loaded: $totalAppointments total');

      // Get referrals received
      print('Fetching referrals...');
      final referralsSnapshot = await _firestore
          .collection('referrals')
          .where('patientId', isEqualTo: userId)
          .get()
          .timeout(
            Duration(seconds: 5),
            onTimeout: () {
              print('Referrals query timed out');
              return Future.error('Referrals query timeout');
            },
          );

      int totalReferrals = referralsSnapshot.docs.length;
      int completedReferrals = referralsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'completed')
          .length;

      print('Referrals loaded: $totalReferrals total');

      // Get educational content interactions
      print('Fetching education interactions...');
      final educationInteractions = await _firestore
          .collection('user_activities')
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: 'education')
          .get()
          .timeout(
            Duration(seconds: 5),
            onTimeout: () {
              print('Education interactions query timed out');
              return Future.error('Education interactions query timeout');
            },
          );

      int healthTipsRead = educationInteractions.docs
          .where((doc) => doc.data()['action'] == 'health_tip_read')
          .length;
      int educationalVideosWatched = educationInteractions.docs
          .where((doc) => doc.data()['action'] == 'educational_video_watched')
          .length;

      print('Education interactions loaded');
      print('Patient analytics complete');

      return {
        'appointments': {
          'total': totalAppointments,
          'completed': completedAppointments,
          'cancelled': cancelledAppointments,
        },
        'referrals': {'total': totalReferrals, 'completed': completedReferrals},
        'education': {
          'health_tips_read': healthTipsRead,
          'educational_videos_watched': educationalVideosWatched,
        },
      };
    } catch (e) {
      print('Error in _getPatientActivityAnalytics: $e');
      // Return empty data instead of failing
      return {
        'appointments': {'total': 0, 'completed': 0, 'cancelled': 0},
        'referrals': {'total': 0, 'completed': 0},
        'education': {'health_tips_read': 0, 'educational_videos_watched': 0},
      };
    }
  }

  /// Doctor specific analytics
  static Future<Map<String, dynamic>> _getDoctorActivityAnalytics(
    String userId,
  ) async {
    // Get appointments as provider
    final appointmentsSnapshot = await _firestore
        .collection('appointments')
        .where('providerId', isEqualTo: userId)
        .get();

    int totalAppointments = appointmentsSnapshot.docs.length;
    int completedAppointments = appointmentsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'completed')
        .length;
    int acceptedAppointments = appointmentsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'accepted')
        .length;
    int rejectedAppointments = appointmentsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'rejected')
        .length;

    // Get consultations conducted
    final consultationsSnapshot = await _firestore
        .collection('consultations')
        .where('doctorId', isEqualTo: userId)
        .get();

    int totalConsultations = consultationsSnapshot.docs.length;
    int completedConsultations = consultationsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'completed')
        .length;

    // Get referrals made
    final referralsSnapshot = await _firestore
        .collection('referrals')
        .where('referredBy', isEqualTo: userId)
        .get();

    int totalReferrals = referralsSnapshot.docs.length;

    return {
      'appointments': {
        'total': totalAppointments,
        'completed': completedAppointments,
        'accepted': acceptedAppointments,
        'rejected': rejectedAppointments,
      },
      'consultations': {
        'total': totalConsultations,
        'completed': completedConsultations,
      },
      'referrals': {'total': totalReferrals},
    };
  }

  /// CHW specific analytics
  static Future<Map<String, dynamic>> _getCHWActivityAnalytics(
    String userId,
  ) async {
    // Get appointments as CHW
    final appointmentsSnapshot = await _firestore
        .collection('appointments')
        .where('providerId', isEqualTo: userId)
        .get();

    int totalAppointments = appointmentsSnapshot.docs.length;
    int completedAppointments = appointmentsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'completed')
        .length;
    int acceptedAppointments = appointmentsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'accepted')
        .length;
    int rejectedAppointments = appointmentsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'rejected')
        .length;

    // Get patients registered by CHW
    final patientsSnapshot = await _firestore
        .collection('users')
        .where('registeredBy', isEqualTo: userId)
        .where('role', isEqualTo: 'patient')
        .get();

    int patientsRegistered = patientsSnapshot.docs.length;

    // Get consultations conducted
    final consultationsSnapshot = await _firestore
        .collection('consultations')
        .where('chwId', isEqualTo: userId)
        .get();

    int totalConsultations = consultationsSnapshot.docs.length;
    int completedConsultations = consultationsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'completed')
        .length;

    // Get referrals made
    final referralsSnapshot = await _firestore
        .collection('referrals')
        .where('referredBy', isEqualTo: userId)
        .get();

    int totalReferrals = referralsSnapshot.docs.length;

    return {
      'appointments': {
        'total': totalAppointments,
        'completed': completedAppointments,
        'accepted': acceptedAppointments,
        'rejected': rejectedAppointments,
      },
      'patients': {'registered': patientsRegistered},
      'consultations': {
        'total': totalConsultations,
        'completed': completedConsultations,
      },
      'referrals': {'total': totalReferrals},
    };
  }

  /// Facility specific analytics
  static Future<Map<String, dynamic>> _getFacilityActivityAnalytics(
    String userId,
  ) async {
    // Get services provided
    final servicesSnapshot = await _firestore
        .collection('facility_services')
        .where('facilityId', isEqualTo: userId)
        .get();

    int totalServices = servicesSnapshot.docs.length;

    // Get appointments at facility
    final appointmentsSnapshot = await _firestore
        .collection('appointments')
        .where('facilityId', isEqualTo: userId)
        .get();

    int totalAppointments = appointmentsSnapshot.docs.length;
    int completedAppointments = appointmentsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'completed')
        .length;

    // Get referrals received
    final referralsSnapshot = await _firestore
        .collection('referrals')
        .where('referredTo', isEqualTo: userId)
        .get();

    int totalReferrals = referralsSnapshot.docs.length;
    int acceptedReferrals = referralsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'accepted')
        .length;

    return {
      'services': {'total': totalServices},
      'appointments': {
        'total': totalAppointments,
        'completed': completedAppointments,
      },
      'referrals': {'total': totalReferrals, 'accepted': acceptedReferrals},
    };
  }

  /// Get performance metrics
  static Future<Map<String, dynamic>> _getPerformanceMetrics(
    String userId,
    String userRole,
  ) async {
    try {
      print('Getting performance metrics for: $userId');
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 1);
      final lastMonth = DateTime(now.year, now.month - 1, 1);

      // Get user activities for performance calculation with timeout
      print('Fetching this month activities...');
      final thisMonthActivities = await _firestore
          .collection('user_activities')
          .where('userId', isEqualTo: userId)
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(thisMonth),
          )
          .get()
          .timeout(
            Duration(seconds: 5),
            onTimeout: () {
              print('This month activities query timed out');
              return _firestore.collection('user_activities').limit(0).get();
            },
          );

      print('Fetching last month activities...');
      final lastMonthActivities = await _firestore
          .collection('user_activities')
          .where('userId', isEqualTo: userId)
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(lastMonth),
          )
          .where('timestamp', isLessThan: Timestamp.fromDate(thisMonth))
          .get()
          .timeout(
            Duration(seconds: 5),
            onTimeout: () {
              print('Last month activities query timed out');
              return _firestore.collection('user_activities').limit(0).get();
            },
          );

      int thisMonthCount = thisMonthActivities.docs.length;
      int lastMonthCount = lastMonthActivities.docs.length;

      double activityTrend = 0;
      if (lastMonthCount > 0) {
        activityTrend =
            ((thisMonthCount - lastMonthCount) / lastMonthCount) * 100;
      }

      print('Performance metrics complete');

      // Calculate role-specific performance scores
      double performanceScore = 0;
      switch (userRole) {
        case 'doctor':
        case 'chw':
          // Performance based on consultation completion rate
          final consultations = await _firestore
              .collection('consultations')
              .where('${userRole}Id', isEqualTo: userId)
              .get()
              .timeout(
                Duration(seconds: 5),
                onTimeout: () {
                  print('Consultations query timed out');
                  return _firestore.collection('consultations').limit(0).get();
                },
              );

          if (consultations.docs.isNotEmpty) {
            final completed = consultations.docs
                .where((doc) => doc.data()['status'] == 'completed')
                .length;
            performanceScore = (completed / consultations.docs.length) * 100;
          }
          break;
        case 'patient':
          // Performance based on appointment attendance
          final appointments = await _firestore
              .collection('appointments')
              .where('patientId', isEqualTo: userId)
              .get()
              .timeout(
                Duration(seconds: 5),
                onTimeout: () {
                  print('Patient appointments query timed out');
                  return _firestore.collection('appointments').limit(0).get();
                },
              );

          if (appointments.docs.isNotEmpty) {
            final attended = appointments.docs
                .where((doc) => doc.data()['status'] == 'completed')
                .length;
            performanceScore = (attended / appointments.docs.length) * 100;
          }
          break;
      }

      return {
        'performance_metrics': {
          'activity_trend_percentage': activityTrend,
          'performance_score': performanceScore,
          'this_month_activities': thisMonthCount,
          'last_month_activities': lastMonthCount,
        },
      };
    } catch (e) {
      print('Error calculating performance metrics: $e');
      return {
        'performance_metrics': {
          'activity_trend_percentage': 0.0,
          'performance_score': 0.0,
          'this_month_activities': 0,
          'last_month_activities': 0,
        },
      };
    }
  }

  /// Get all users with comprehensive filtering and analytics for admin dashboard
  static Future<Map<String, dynamic>> getAllUsersWithAnalytics({
    String? roleFilter,
    String? activityStatusFilter,
    DateTime? registrationStartDate,
    DateTime? registrationEndDate,
    DateTime? activityStartDate,
    DateTime? activityEndDate,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    try {
      Query query = _firestore.collection('users');

      // Apply role filter
      if (roleFilter != null && roleFilter.isNotEmpty) {
        query = query.where('role', isEqualTo: roleFilter);
      }

      // Apply registration date filter
      if (registrationStartDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(registrationStartDate),
        );
      }

      if (registrationEndDate != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(registrationEndDate),
        );
      }

      query = query.orderBy('createdAt', descending: true);

      // Apply pagination
      if (offset != null && offset > 0) {
        // For offset, we need to use startAfterDocument, but for simplicity
        // we'll fetch all and apply offset in memory for now
      }

      if (limit != null) {
        query = query.limit((offset ?? 0) + limit);
      }

      // Add timeout using Future.timeout
      final usersSnapshot = await query.get().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
          'Failed to load users - request timed out',
          const Duration(seconds: 30),
        ),
      );

      List<Map<String, dynamic>> allUsers = [];
      final now = DateTime.now();

      // Get user activities for activity-based filtering if needed
      Map<String, List<QueryDocumentSnapshot>> userActivities = {};

      if (activityStatusFilter != null ||
          activityStartDate != null ||
          activityEndDate != null) {
        // Batch fetch activities for all users
        final userIds = usersSnapshot.docs.map((doc) => doc.id).toList();

        // Split into smaller batches to avoid Firestore limitations
        for (int i = 0; i < userIds.length; i += 30) {
          final batchIds = userIds.skip(i).take(30).toList();

          Query activityQuery = _firestore
              .collection('user_activities')
              .where('userId', whereIn: batchIds)
              .orderBy('timestamp', descending: true);

          if (activityStartDate != null) {
            activityQuery = activityQuery.where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(activityStartDate),
            );
          }

          if (activityEndDate != null) {
            activityQuery = activityQuery.where(
              'timestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(activityEndDate),
            );
          }

          final batchActivities = await activityQuery.get();

          for (var doc in batchActivities.docs) {
            final docData = doc.data() as Map<String, dynamic>?;
            final userId = docData?['userId'] as String?;
            if (userId != null) {
              userActivities[userId] = userActivities[userId] ?? [];
              userActivities[userId]!.add(doc);
            }
          }
        }
      }

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final userId = userDoc.id;

        // Apply search filter
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final fullName = (userData['fullName'] ?? userData['name'] ?? '')
              .toString()
              .toLowerCase();
          final email = (userData['email'] ?? '').toString().toLowerCase();
          final phone = (userData['phone'] ?? '').toString().toLowerCase();
          final searchLower = searchQuery.toLowerCase();

          if (!fullName.contains(searchLower) &&
              !email.contains(searchLower) &&
              !phone.contains(searchLower)) {
            continue;
          }
        }

        // Calculate analytics using the CORRECT fields from your app
        final analytics = await _calculateUserAnalyticsFromUserData(
          userId,
          userData,
          now,
          activityStartDate,
          activityEndDate,
        );

        // Apply activity status filter
        if (activityStatusFilter != null && activityStatusFilter.isNotEmpty) {
          if (analytics['activity_status'] != activityStatusFilter) {
            continue;
          }
        }

        allUsers.add({
          'id': userId,
          'user_data': userData,
          'analytics': analytics,
        });
      }

      // Apply offset after filtering
      final startIndex = offset ?? 0;
      final endIndex = limit != null
          ? (startIndex + limit).clamp(0, allUsers.length)
          : allUsers.length;

      final paginatedUsers = startIndex < allUsers.length
          ? allUsers.sublist(startIndex, endIndex)
          : <Map<String, dynamic>>[];

      // Calculate totals for different activity statuses
      final activityStatusCounts = <String, int>{};
      final roleCounts = <String, int>{};

      for (var user in allUsers) {
        final analytics = user['analytics'] as Map<String, dynamic>;
        final userData = user['user_data'] as Map<String, dynamic>;
        final activityStatus = analytics['activity_status'] ?? 'inactive';
        final role = userData['role']?.toString().toLowerCase() ?? 'unknown';

        activityStatusCounts[activityStatus] =
            (activityStatusCounts[activityStatus] ?? 0) + 1;
        roleCounts[role] = (roleCounts[role] ?? 0) + 1;
      }

      print(
        'Successfully loaded ${paginatedUsers.length} of ${allUsers.length} users with filters',
      );

      return {
        'users': paginatedUsers,
        'total_count': allUsers.length,
        'activity_status_counts': activityStatusCounts,
        'role_counts': roleCounts,
        'pagination': {
          'offset': startIndex,
          'limit': limit,
          'has_more': endIndex < allUsers.length,
        },
      };
    } on TimeoutException {
      print('Timeout error getting users - operation took too long');
      throw Exception('Loading users timed out. Please try again.');
    } catch (e) {
      print('Error getting users with analytics: $e');
      throw Exception(
        'Failed to load user data. Please check your connection and try again.',
      );
    }
  }

  /// Get all users with basic analytics (backward compatibility)
  static Future<List<Map<String, dynamic>>> getAllUsersWithBasicAnalytics({
    String? roleFilter,
    int? limit,
  }) async {
    final result = await getAllUsersWithAnalytics(
      roleFilter: roleFilter,
      limit: limit ?? 50,
    );
    return result['users'] as List<Map<String, dynamic>>;
  }

  /// Calculate user analytics from user data using the correct fields and activity collections
  static Future<Map<String, dynamic>> _calculateUserAnalyticsFromUserData(
    String userId,
    Map<String, dynamic> userData,
    DateTime now,
    DateTime? activityStartDate,
    DateTime? activityEndDate,
  ) async {
    Map<String, dynamic> analytics = {};

    // Get basic fields from user data
    final lastSeen = userData['lastSeen'] as Timestamp?;
    final isOnline = userData['isOnline'] ?? false;
    final createdAt = userData['createdAt'] as Timestamp?;

    DateTime? lastActivityDate = lastSeen?.toDate();

    // If user is currently online, treat current time as last activity
    if (isOnline) {
      lastActivityDate = now;
    }

    // If no lastSeen, check activity in other collections
    lastActivityDate ??= await _getLastActivityFromCollections(userId);

    // If still no activity, use registration date for very recent users (within 7 days)
    if (lastActivityDate == null && createdAt != null) {
      final registrationDate = createdAt.toDate();
      final daysSinceRegistration = now.difference(registrationDate).inDays;

      // Treat users registered within last 7 days as potentially recently active
      if (daysSinceRegistration <= 7) {
        lastActivityDate = registrationDate;
        analytics['activity_source'] = 'registration_fallback';
      }
    }

    // Apply activity date filtering if specified
    if (activityStartDate != null && lastActivityDate != null) {
      if (lastActivityDate.isBefore(activityStartDate)) {
        lastActivityDate =
            null; // Exclude this user from activity-based filtering
      }
    }

    if (activityEndDate != null && lastActivityDate != null) {
      if (lastActivityDate.isAfter(activityEndDate)) {
        lastActivityDate =
            null; // Exclude this user from activity-based filtering
      }
    }

    // Calculate activity status using actual user activity data
    analytics['activity_status'] = _calculateActivityStatus(
      lastActivityDate,
      now,
    );
    analytics['last_activity'] = lastSeen;
    analytics['last_activity_date'] = lastActivityDate;
    analytics['is_online'] = isOnline;
    analytics['days_since_last_activity'] = lastActivityDate != null
        ? now.difference(lastActivityDate).inDays
        : null;

    // Calculate registration age
    if (createdAt != null) {
      analytics['days_since_registration'] = now
          .difference(createdAt.toDate())
          .inDays;
      analytics['registration_date'] = createdAt.toDate();
    }

    final role = userData['role']?.toString().toLowerCase() ?? 'unknown';

    // Set placeholder values for role-specific stats to avoid additional queries
    // These can be populated on-demand when viewing detailed analytics
    switch (role) {
      case 'patient':
        analytics['total_appointments'] = 0; // Placeholder
        break;
      case 'doctor':
      case 'chw':
        analytics['total_consultations'] = 0; // Placeholder
        break;
      case 'facility':
        analytics['total_services'] = 0; // Placeholder
        break;
    }

    // Set placeholder values for training progress
    analytics['training_materials_accessed'] = 0; // Placeholder
    analytics['training_completed'] = 0; // Placeholder

    return analytics;
  }

  /// Check user activity in other collections (appointments, messages, consultations)
  static Future<DateTime?> _getLastActivityFromCollections(
    String userId,
  ) async {
    try {
      DateTime? latestActivity;

      // Check appointments (as patient or provider)
      final appointmentsQuery1 = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      final appointmentsQuery2 = await _firestore
          .collection('appointments')
          .where('providerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      for (var queryResult in [appointmentsQuery1, appointmentsQuery2]) {
        if (queryResult.docs.isNotEmpty) {
          final timestamp =
              queryResult.docs.first.data()['createdAt'] as Timestamp?;
          if (timestamp != null) {
            final date = timestamp.toDate();
            if (latestActivity == null || date.isAfter(latestActivity)) {
              latestActivity = date;
            }
          }
        }
      }

      // Check messages (as sender)
      final messagesQuery = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messagesQuery.docs.isNotEmpty) {
        final timestamp =
            messagesQuery.docs.first.data()['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final date = timestamp.toDate();
          if (latestActivity == null || date.isAfter(latestActivity)) {
            latestActivity = date;
          }
        }
      }

      // Check consultations
      final consultationsQuery1 = await _firestore
          .collection('consultations')
          .where('patientId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      final consultationsQuery2 = await _firestore
          .collection('consultations')
          .where('providerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      for (var queryResult in [consultationsQuery1, consultationsQuery2]) {
        if (queryResult.docs.isNotEmpty) {
          final timestamp =
              queryResult.docs.first.data()['createdAt'] as Timestamp?;
          if (timestamp != null) {
            final date = timestamp.toDate();
            if (latestActivity == null || date.isAfter(latestActivity)) {
              latestActivity = date;
            }
          }
        }
      }

      return latestActivity;
    } catch (e) {
      print('Error checking activity collections for user $userId: $e');
      return null;
    }
  }

  /// Calculate user activity status based on last activity date
  static String _calculateActivityStatus(
    DateTime? lastActivityDate,
    DateTime now,
  ) {
    if (lastActivityDate == null) {
      return 'inactive';
    }

    final daysSinceLastActivity = now.difference(lastActivityDate).inDays;
    final hoursSinceLastActivity = now.difference(lastActivityDate).inHours;

    if (hoursSinceLastActivity <= 1) {
      return 'active';
    } else if (daysSinceLastActivity == 0) {
      return 'active';
    } else if (daysSinceLastActivity <= 7) {
      return 'recently_active';
    } else if (daysSinceLastActivity <= 30) {
      return 'recently_active';
    } else {
      return 'inactive';
    }
  }

  /// Get activity status display info
  static Map<String, dynamic> getActivityStatusInfo(String status) {
    switch (status) {
      case 'active_today':
        return {
          'label': 'Active Today',
          'color': Colors.green,
          'icon': Icons.circle,
          'description': 'User was active today',
        };
      case 'active_this_week':
        return {
          'label': 'Active This Week',
          'color': Colors.lightGreen,
          'icon': Icons.circle,
          'description': 'User was active within the last week',
        };
      case 'active_this_month':
        return {
          'label': 'Active This Month',
          'color': Colors.orange,
          'icon': Icons.circle,
          'description': 'User was active within the last month',
        };
      case 'inactive_recent':
        return {
          'label': 'Recently Inactive',
          'color': Colors.deepOrange,
          'icon': Icons.circle,
          'description': 'User hasn\'t been active in 1-3 months',
        };
      case 'inactive_long':
        return {
          'label': 'Long Inactive',
          'color': Colors.red,
          'icon': Icons.circle,
          'description': 'User hasn\'t been active for over 3 months',
        };
      case 'never_active':
        return {
          'label': 'Never Active',
          'color': Colors.grey,
          'icon': Icons.circle_outlined,
          'description': 'User has never used the app',
        };
      default:
        return {
          'label': 'Unknown',
          'color': Colors.grey,
          'icon': Icons.help_outline,
          'description': 'Activity status unknown',
        };
    }
  }

  /// Log user activity for analytics tracking
  static Future<void> logUserActivity({
    required String userId,
    required String action,
    required String category,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('user_activities').add({
        'userId': userId,
        'action': action,
        'category': category,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging user activity: $e');
    }
  }

  /// Get user statistics summary for admin dashboard with enhanced date range filtering
  static Future<Map<String, dynamic>> getUserStatisticsSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('users');

      // Apply registration date filters for user counts
      if (startDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final usersSnapshot = await query.get();

      Map<String, int> stats = {
        'total': usersSnapshot.docs.length,
        'doctors': 0,
        'chw': 0,
        'patients': 0,
        'admin': 0,
        'facility': 0,
        'active_today': 0,
        'active_this_week': 0,
        'active_this_month': 0,
        'inactive_recent': 0,
        'inactive_long': 0,
        'never_active': 0,
        'new_this_month': 0,
      };

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDay = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      );
      final monthStart = DateTime(now.year, now.month, 1);

      // Process each user for role and activity statistics
      for (var doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = doc.id;
        final role = data['role']?.toString().toLowerCase() ?? '';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        // Count by role
        switch (role) {
          case 'doctor':
            stats['doctors'] = stats['doctors']! + 1;
            break;
          case 'chw':
            stats['chw'] = stats['chw']! + 1;
            break;
          case 'patient':
            stats['patients'] = stats['patients']! + 1;
            break;
          case 'admin':
            stats['admin'] = stats['admin']! + 1;
            break;
          case 'facility':
            stats['facility'] = stats['facility']! + 1;
            break;
        }

        // Count new users this month (registration-based)
        if (createdAt != null && createdAt.isAfter(monthStart)) {
          stats['new_this_month'] = stats['new_this_month']! + 1;
        }

        // Calculate activity status using enhanced analytics
        final analytics = await _calculateUserAnalyticsFromUserData(
          userId,
          data,
          now,
          startDate,
          endDate,
        );

        final lastActivityDate = analytics['last_activity_date'] as DateTime?;

        // Count activity based on actual activity dates
        if (lastActivityDate != null) {
          // Active today
          if (lastActivityDate.isAfter(today)) {
            stats['active_today'] = stats['active_today']! + 1;
          }
          // Active this week
          else if (lastActivityDate.isAfter(weekStartDay)) {
            stats['active_this_week'] = stats['active_this_week']! + 1;
          }
          // Active this month
          else if (lastActivityDate.isAfter(monthStart)) {
            stats['active_this_month'] = stats['active_this_month']! + 1;
          }
          // Inactive recent (1-3 months)
          else if (lastActivityDate.isAfter(
            now.subtract(const Duration(days: 90)),
          )) {
            stats['inactive_recent'] = stats['inactive_recent']! + 1;
          }
          // Inactive long (3+ months)
          else {
            stats['inactive_long'] = stats['inactive_long']! + 1;
          }
        } else {
          // Never active or no detectable activity
          stats['never_active'] = stats['never_active']! + 1;
        }
      }

      // Additional helpful statistics
      final totalActive =
          stats['active_today']! +
          stats['active_this_week']! +
          stats['active_this_month']!;
      final totalInactive =
          stats['inactive_recent']! +
          stats['inactive_long']! +
          stats['never_active']!;
      final engagementRate = stats['total']! > 0
          ? (totalActive / stats['total']! * 100).round()
          : 0;

      stats['total_active'] = totalActive;
      stats['total_inactive'] = totalInactive;
      stats['engagement_rate'] = engagementRate;

      return stats;
    } catch (e) {
      print('Error getting user statistics summary: $e');
      return {};
    }
  }

  /// Get available filter options for users
  static Map<String, List<Map<String, String>>> getFilterOptions() {
    return {
      'activity_status': [
        {'value': '', 'label': 'All Activity Levels'},
        {'value': 'active', 'label': 'Active (Last 24 hours)'},
        {'value': 'recently_active', 'label': 'Recently Active (Last 30 days)'},
        {'value': 'inactive', 'label': 'Inactive (30+ days)'},
      ],
      'roles': [
        {'value': '', 'label': 'All Roles'},
        {'value': 'admin', 'label': 'Admin'},
        {'value': 'doctor', 'label': 'Doctor'},
        {'value': 'chw', 'label': 'CHW'},
        {'value': 'patient', 'label': 'Patient'},
        {'value': 'facility', 'label': 'Facility'},
      ],
    };
  }

  /// Get training material view/download statistics
  static Future<Map<String, dynamic>> getTrainingMaterialStatistics({
    String? materialId,
  }) async {
    try {
      Query query = _firestore.collection('training_materials');

      if (materialId != null) {
        query = query.where(FieldPath.documentId, isEqualTo: materialId);
      }

      final materialsSnapshot = await query.get();
      List<Map<String, dynamic>> materialStats = [];

      for (var doc in materialsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Get detailed user interactions
        final userProgressSnapshot = await _firestore
            .collection('user_progress')
            .where('materialId', isEqualTo: doc.id)
            .get();

        List<Map<String, dynamic>> userInteractions = [];
        for (var progressDoc in userProgressSnapshot.docs) {
          final progressData = progressDoc.data();

          // Get user details
          final userDoc = await _firestore
              .collection('users')
              .doc(progressData['userId'])
              .get();

          if (userDoc.exists) {
            userInteractions.add({
              'user_id': progressData['userId'],
              'user_name':
                  userDoc.data()?['fullName'] ??
                  userDoc.data()?['name'] ??
                  'Unknown',
              'user_role': userDoc.data()?['role'] ?? 'unknown',
              'progress': _safeToDouble(progressData['progressPercentage']),
              'status': progressData['status'] ?? 'not_started',
              'last_accessed': progressData['lastAccessedAt'],
              'time_spent_minutes': _safeToDouble(
                progressData['timeSpentMinutes'],
              ),
            });
          }
        }

        materialStats.add({
          'material_id': doc.id,
          'title': data['title'] ?? 'Untitled',
          'type': data['type'] ?? 'unknown',
          'target_roles': data['targetRoles'] ?? [],
          'view_count': data['viewCount'] ?? 0,
          'download_count': data['downloadCount'] ?? 0,
          'average_rating': data['averageRating'],
          'rating_count': data['ratingCount'] ?? 0,
          'user_interactions': userInteractions,
          'unique_viewers': userInteractions.length,
          'completion_rate': userInteractions.isEmpty
              ? 0
              : (userInteractions
                            .where((u) => u['status'] == 'completed')
                            .length /
                        userInteractions.length) *
                    100,
        });
      }

      return {
        'materials': materialStats,
        'total_materials': materialStats.length,
        'total_views': materialStats.fold<int>(
          0,
          (total, material) => total + (material['view_count'] as int),
        ),
        'total_downloads': materialStats.fold<int>(
          0,
          (total, material) => total + (material['download_count'] as int),
        ),
      };
    } catch (e) {
      print('Error getting training material statistics: $e');
      return {};
    }
  }
}
