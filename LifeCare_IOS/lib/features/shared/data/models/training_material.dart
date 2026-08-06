import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingMaterial {
  final String id;
  final String title;
  final String description;
  final String? content; // Text content for articles
  final String? fileUrl; // URL for downloadable files (PDFs, videos, etc.)
  final String? thumbnailUrl; // Thumbnail image URL
  final String type; // 'video', 'pdf', 'article', 'interactive', 'quiz'
  final String
  category; // 'maternal-health', 'child-health', 'general-health', 'emergency-care', 'nutrition'
  final List<String> targetRoles; // ['chw', 'patient', 'doctor', 'facility']
  final String difficulty; // 'beginner', 'intermediate', 'advanced'
  final int estimatedDurationMinutes;
  final List<String> tags;
  final String status; // 'draft', 'published', 'archived'
  final int version;
  final String language; // 'en', 'sw', 'fr', etc.
  final Map<String, dynamic>? metadata; // Additional metadata
  final DateTime createdAt;

  /// Safe conversion of dynamic values to double
  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  final DateTime? updatedAt;
  final String createdBy;
  final String? updatedBy;
  final int downloadCount;
  final int viewCount;
  final double? averageRating;
  final int? ratingCount;
  final bool isRequired; // Required training for role
  final DateTime? expirationDate; // For time-sensitive materials
  final List<String>? prerequisites; // IDs of prerequisite materials

  const TrainingMaterial({
    required this.id,
    required this.title,
    required this.description,
    this.content,
    this.fileUrl,
    this.thumbnailUrl,
    required this.type,
    required this.category,
    required this.targetRoles,
    required this.difficulty,
    required this.estimatedDurationMinutes,
    required this.tags,
    required this.status,
    required this.version,
    required this.language,
    this.metadata,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    this.updatedBy,
    required this.downloadCount,
    required this.viewCount,
    this.averageRating,
    this.ratingCount,
    required this.isRequired,
    this.expirationDate,
    this.prerequisites,
  });

  factory TrainingMaterial.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TrainingMaterial(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      content: data['content'],
      fileUrl: data['fileUrl'],
      thumbnailUrl: data['thumbnailUrl'],
      type: data['type'] ?? 'article',
      category: data['category'] ?? 'general-health',
      targetRoles: data['targetRoles'] != null
          ? List<String>.from(data['targetRoles'])
          : ['chw'],
      difficulty: data['difficulty'] ?? 'beginner',
      estimatedDurationMinutes: data['estimatedDurationMinutes'] ?? 15,
      tags: data['tags'] != null ? List<String>.from(data['tags']) : [],
      status: data['status'] ?? 'draft',
      version: data['version'] ?? 1,
      language: data['language'] ?? 'en',
      metadata: data['metadata'] as Map<String, dynamic>?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] ?? '',
      updatedBy: data['updatedBy'],
      downloadCount: data['downloadCount'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      averageRating: _safeToDouble(data['averageRating']),
      ratingCount: data['ratingCount'] ?? 0,
      isRequired: data['isRequired'] ?? false,
      expirationDate: (data['expirationDate'] as Timestamp?)?.toDate(),
      prerequisites: data['prerequisites'] != null
          ? List<String>.from(data['prerequisites'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'content': content,
      'fileUrl': fileUrl,
      'thumbnailUrl': thumbnailUrl,
      'type': type,
      'category': category,
      'targetRoles': targetRoles,
      'difficulty': difficulty,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'tags': tags,
      'status': status,
      'version': version,
      'language': language,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'downloadCount': downloadCount,
      'viewCount': viewCount,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'isRequired': isRequired,
      'expirationDate': expirationDate != null
          ? Timestamp.fromDate(expirationDate!)
          : null,
      'prerequisites': prerequisites,
    };
  }

  // Helper getters
  String get typeDisplayText {
    switch (type.toLowerCase()) {
      case 'video':
        return 'Video';
      case 'pdf':
        return 'PDF Document';
      case 'article':
        return 'Article';
      case 'interactive':
        return 'Interactive';
      case 'quiz':
        return 'Quiz';
      default:
        return 'Material';
    }
  }

  String get categoryDisplayText {
    switch (category.toLowerCase()) {
      case 'maternal-health':
        return 'Maternal Health';
      case 'child-health':
        return 'Child Health';
      case 'general-health':
        return 'General Health';
      case 'emergency-care':
        return 'Emergency Care';
      case 'nutrition':
        return 'Nutrition';
      default:
        return 'General';
    }
  }

  String get difficultyDisplayText {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return 'Beginner';
      case 'intermediate':
        return 'Intermediate';
      case 'advanced':
        return 'Advanced';
      default:
        return 'Beginner';
    }
  }

  String get formattedDuration {
    if (estimatedDurationMinutes < 60) {
      return '$estimatedDurationMinutes min';
    } else {
      final hours = estimatedDurationMinutes ~/ 60;
      final minutes = estimatedDurationMinutes % 60;
      if (minutes == 0) {
        return '$hours hr';
      } else {
        return '$hours hr $minutes min';
      }
    }
  }

  bool get isExpired {
    if (expirationDate == null) return false;
    return DateTime.now().isAfter(expirationDate!);
  }

  bool isTargetedFor(String userRole) {
    return targetRoles.contains(userRole.toLowerCase());
  }
}

class UserProgress {
  final String id;
  final String userId;
  final String materialId;
  final String status; // 'not-started', 'in-progress', 'completed', 'skipped'
  final double progressPercentage; // 0-100
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? lastAccessedAt;
  final int timeSpentMinutes;
  final Map<String, dynamic>?
  data; // Additional progress data (quiz scores, etc.)
  final double? userRating;
  final String? userReview;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Safe conversion of dynamic values to double
  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  const UserProgress({
    required this.id,
    required this.userId,
    required this.materialId,
    required this.status,
    required this.progressPercentage,
    this.startedAt,
    this.completedAt,
    this.lastAccessedAt,
    required this.timeSpentMinutes,
    this.data,
    this.userRating,
    this.userReview,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserProgress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProgress(
      id: doc.id,
      userId: data['userId'] ?? '',
      materialId: data['materialId'] ?? '',
      status: data['status'] ?? 'not-started',
      progressPercentage: _safeToDouble(data['progressPercentage']),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      lastAccessedAt: (data['lastAccessedAt'] as Timestamp?)?.toDate(),
      timeSpentMinutes: data['timeSpentMinutes'] ?? 0,
      data: data['data'] as Map<String, dynamic>?,
      userRating: _safeToDouble(data['userRating']),
      userReview: data['userReview'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'materialId': materialId,
      'status': status,
      'progressPercentage': progressPercentage,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'lastAccessedAt': lastAccessedAt != null
          ? Timestamp.fromDate(lastAccessedAt!)
          : null,
      'timeSpentMinutes': timeSpentMinutes,
      'data': data,
      'userRating': userRating,
      'userReview': userReview,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in-progress';
  bool get isNotStarted => status == 'not-started';
}
