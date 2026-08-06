import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a course available for CHWs
class Course {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String? certificateSignatureUrl;
  final double certificateFee;
  final String category; // e.g., 'maternal_health', 'child_health', 'nutrition'
  final String targetRole; // e.g., 'chw', 'doctor', 'patient'
  final int totalLessons;
  final int durationWeeks;
  final int estimatedDurationMinutes;
  final List<String> availableLanguages; // e.g., ['en', 'es', 'fr']
  final String status; // 'active', 'archived'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String courseOutline; // Detailed outline of the course

  Course({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.certificateSignatureUrl,
    this.certificateFee = 1000.0,
    required this.category,
    required this.targetRole,
    required this.totalLessons,
    required this.durationWeeks,
    required this.estimatedDurationMinutes,
    required this.availableLanguages,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    required this.courseOutline,
  });

  /// Convert Course to JSON
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'certificateSignatureUrl': certificateSignatureUrl,
      'certificateFee': certificateFee,
      'category': category,
      'targetRole': targetRole,
      'totalLessons': totalLessons,
      'durationWeeks': durationWeeks,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'availableLanguages': availableLanguages,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'courseOutline': courseOutline,
    };
  }

  /// Create Course from Firestore document
  factory Course.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Course(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      certificateSignatureUrl: data['certificateSignatureUrl'],
      certificateFee: _safeDouble(data['certificateFee'], fallback: 1000.0),
      category: data['category'] ?? 'general',
      targetRole: data['targetRole'] ?? 'chw',
      totalLessons: data['totalLessons'] ?? 0,
      durationWeeks:
          data['durationWeeks'] ??
          _weeksFromMinutes(data['estimatedDurationMinutes']),
      estimatedDurationMinutes: data['estimatedDurationMinutes'] ?? 0,
      availableLanguages: List<String>.from(
        data['availableLanguages'] ?? ['en'],
      ),
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      courseOutline: data['courseOutline'] ?? '',
    );
  }

  /// Create Course from Map
  factory Course.fromMap(Map<String, dynamic> map, String id) {
    return Course(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      certificateSignatureUrl: map['certificateSignatureUrl'],
      certificateFee: _safeDouble(map['certificateFee'], fallback: 1000.0),
      category: map['category'] ?? 'general',
      targetRole: map['targetRole'] ?? 'chw',
      totalLessons: map['totalLessons'] ?? 0,
      durationWeeks:
          map['durationWeeks'] ??
          _weeksFromMinutes(map['estimatedDurationMinutes']),
      estimatedDurationMinutes: map['estimatedDurationMinutes'] ?? 0,
      availableLanguages: List<String>.from(
        map['availableLanguages'] ?? ['en'],
      ),
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : (map['updatedAt'] != null
                ? DateTime.parse(map['updatedAt'])
                : null),
      courseOutline: map['courseOutline'] ?? '',
    );
  }

  /// Copy with method
  Course copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? certificateSignatureUrl,
    double? certificateFee,
    String? category,
    String? targetRole,
    int? totalLessons,
    int? durationWeeks,
    int? estimatedDurationMinutes,
    List<String>? availableLanguages,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? courseOutline,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      certificateSignatureUrl:
          certificateSignatureUrl ?? this.certificateSignatureUrl,
      certificateFee: certificateFee ?? this.certificateFee,
      category: category ?? this.category,
      targetRole: targetRole ?? this.targetRole,
      totalLessons: totalLessons ?? this.totalLessons,
      durationWeeks: durationWeeks ?? this.durationWeeks,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      availableLanguages: availableLanguages ?? this.availableLanguages,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      courseOutline: courseOutline ?? this.courseOutline,
    );
  }

  static int _weeksFromMinutes(dynamic minutesValue) {
    final minutes = minutesValue is num ? minutesValue.toInt() : 0;
    if (minutes <= 0) return 0;
    return (minutes / 10080).ceil();
  }

  static double _safeDouble(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}

/// Represents a lesson within a course
class Lesson {
  final String id;
  final String courseId;
  final String title;
  final String content;
  final String? videoUrl;
  final int orderIndex;
  final int estimatedDurationMinutes;
  final Map<String, String> contentByLanguage; // 'en', 'es', etc.
  final DateTime createdAt;

  Lesson({
    required this.id,
    required this.courseId,
    required this.title,
    required this.content,
    this.videoUrl,
    required this.orderIndex,
    required this.estimatedDurationMinutes,
    required this.contentByLanguage,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'title': title,
      'content': content,
      'videoUrl': videoUrl,
      'orderIndex': orderIndex,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'contentByLanguage': contentByLanguage,
      'createdAt': createdAt,
    };
  }

  factory Lesson.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Lesson(
      id: doc.id,
      courseId: data['courseId'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      videoUrl: data['videoUrl'],
      orderIndex: data['orderIndex'] ?? 0,
      estimatedDurationMinutes: data['estimatedDurationMinutes'] ?? 0,
      contentByLanguage: Map<String, String>.from(
        data['contentByLanguage'] ?? {},
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory Lesson.fromMap(Map<String, dynamic> map, String id) {
    return Lesson(
      id: id,
      courseId: map['courseId'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      videoUrl: map['videoUrl'],
      orderIndex: map['orderIndex'] ?? 0,
      estimatedDurationMinutes: map['estimatedDurationMinutes'] ?? 0,
      contentByLanguage: Map<String, String>.from(
        map['contentByLanguage'] ?? {},
      ),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(map['createdAt']),
    );
  }
}

enum SlideType { content, quiz, assignment }

/// Represents a slide within a course. A slide can be a topic or a quiz.
class CourseSlide {
  final String id;
  final String courseId;
  final String moduleId;
  final String moduleTitle;
  final int moduleOrderIndex;
  final String lessonId;
  final String lessonTitle;
  final int lessonOrderIndex;
  final String title;
  final String description;
  final SlideType type;
  final String? content;
  final String? videoUrl;
  final String? imageUrl;
  final String? assignmentQuestion;
  final int assignmentMinWords;
  final Map<String, String> contentByLanguage;
  final List<QuizQuestion> questions;
  final int orderIndex;
  final int estimatedDurationMinutes;
  final DateTime createdAt;

  CourseSlide({
    required this.id,
    required this.courseId,
    required this.moduleId,
    required this.moduleTitle,
    required this.moduleOrderIndex,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonOrderIndex,
    required this.title,
    required this.description,
    required this.type,
    this.content,
    this.videoUrl,
    this.imageUrl,
    this.assignmentQuestion,
    this.assignmentMinWords = 50,
    required this.contentByLanguage,
    required this.questions,
    required this.orderIndex,
    required this.estimatedDurationMinutes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'moduleId': moduleId,
      'moduleTitle': moduleTitle,
      'moduleOrderIndex': moduleOrderIndex,
      'lessonId': lessonId,
      'lessonTitle': lessonTitle,
      'lessonOrderIndex': lessonOrderIndex,
      'title': title,
      'description': description,
      'type': type.name,
      'content': content,
      'videoUrl': videoUrl,
      'imageUrl': imageUrl,
      'assignmentQuestion': assignmentQuestion,
      'assignmentMinWords': assignmentMinWords,
      'contentByLanguage': contentByLanguage,
      'questions': questions.map((q) => q.toMap()).toList(),
      'orderIndex': orderIndex,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'createdAt': createdAt,
    };
  }

  factory CourseSlide.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final questionsData = data['questions'] as List<dynamic>? ?? [];
    return CourseSlide(
      id: doc.id,
      courseId: data['courseId'] ?? '',
      moduleId: data['moduleId'] ?? 'module_1',
      moduleTitle: data['moduleTitle'] ?? 'Module 1',
      moduleOrderIndex: data['moduleOrderIndex'] ?? 0,
      lessonId: data['lessonId'] ?? 'lesson_1_1',
      lessonTitle: data['lessonTitle'] ?? 'Lesson 1.1',
      lessonOrderIndex: data['lessonOrderIndex'] ?? 0,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: SlideType.values.firstWhere(
        (type) => type.name == (data['type'] ?? 'content'),
        orElse: () => SlideType.content,
      ),
      content: data['content'],
      videoUrl: data['videoUrl'],
      imageUrl: data['imageUrl'],
      assignmentQuestion: data['assignmentQuestion'],
      assignmentMinWords: data['assignmentMinWords'] ?? 50,
      contentByLanguage: Map<String, String>.from(
        data['contentByLanguage'] ?? {},
      ),
      questions: questionsData
          .map(
            (question) =>
                QuizQuestion.fromMap(question as Map<String, dynamic>),
          )
          .toList(),
      orderIndex: data['orderIndex'] ?? 0,
      estimatedDurationMinutes: data['estimatedDurationMinutes'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory CourseSlide.fromMap(Map<String, dynamic> map, String id) {
    final questionsData = map['questions'] as List<dynamic>? ?? [];
    return CourseSlide(
      id: id,
      courseId: map['courseId'] ?? '',
      moduleId: map['moduleId'] ?? 'module_1',
      moduleTitle: map['moduleTitle'] ?? 'Module 1',
      moduleOrderIndex: map['moduleOrderIndex'] ?? 0,
      lessonId: map['lessonId'] ?? 'lesson_1_1',
      lessonTitle: map['lessonTitle'] ?? 'Lesson 1.1',
      lessonOrderIndex: map['lessonOrderIndex'] ?? 0,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: SlideType.values.firstWhere(
        (type) => type.name == (map['type'] ?? 'content'),
        orElse: () => SlideType.content,
      ),
      content: map['content'],
      videoUrl: map['videoUrl'],
      imageUrl: map['imageUrl'],
      assignmentQuestion: map['assignmentQuestion'],
      assignmentMinWords: map['assignmentMinWords'] ?? 50,
      contentByLanguage: Map<String, String>.from(
        map['contentByLanguage'] ?? {},
      ),
      questions: questionsData
          .map(
            (question) =>
                QuizQuestion.fromMap(question as Map<String, dynamic>),
          )
          .toList(),
      orderIndex: map['orderIndex'] ?? 0,
      estimatedDurationMinutes: map['estimatedDurationMinutes'] ?? 0,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(map['createdAt']),
    );
  }
}

/// Represents a single question in a quiz
class QuizQuestion {
  final String id;
  final String questionText;
  final String questionType; // 'multiple_choice', 'true_false', 'short_answer'
  final List<String> options; // For multiple choice
  final String correctAnswer;
  final String? explanation;
  final int points;

  QuizQuestion({
    required this.id,
    required this.questionText,
    required this.questionType,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    required this.points,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionText': questionText,
      'questionType': questionType,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'points': points,
    };
  }

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      id: map['id'] ?? '',
      questionText: map['questionText'] ?? '',
      questionType: map['questionType'] ?? 'multiple_choice',
      options: List<String>.from(map['options'] ?? []),
      correctAnswer: map['correctAnswer'] ?? '',
      explanation: map['explanation'],
      points: map['points'] ?? 1,
    );
  }
}

/// Represents a quiz for a course
class Quiz {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final int totalQuestions;
  final int passingScore; // percentage (0-100)
  final List<QuizQuestion> questions;
  final int estimatedDurationMinutes;
  final DateTime createdAt;

  Quiz({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.totalQuestions,
    required this.passingScore,
    required this.questions,
    required this.estimatedDurationMinutes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'title': title,
      'description': description,
      'totalQuestions': totalQuestions,
      'passingScore': passingScore,
      'questions': questions.map((q) => q.toMap()).toList(),
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'createdAt': createdAt,
    };
  }

  factory Quiz.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final questionsData = data['questions'] as List<dynamic>? ?? [];
    return Quiz(
      id: doc.id,
      courseId: data['courseId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      totalQuestions: data['totalQuestions'] ?? 0,
      passingScore: data['passingScore'] ?? 70,
      questions: questionsData
          .map((q) => QuizQuestion.fromMap(q as Map<String, dynamic>))
          .toList(),
      estimatedDurationMinutes: data['estimatedDurationMinutes'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Tracks user progress in a course
class CourseProgress {
  final String id;
  final String userId;
  final String courseId;
  final List<String> completedSlideIds;
  final List<String> videoWatchedSlideIds;
  final Map<String, QuizAttempt> quizAttempts; // quizId -> QuizAttempt
  final Map<String, String> assignmentAnswers; // assignment slideId -> answer
  final Map<String, String>
  assignmentFeedback; // assignment slideId -> AI feedback
  final Map<String, String>
  assignmentAdminComments; // assignment slideId -> admin comment
  final bool courseCompleted;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int progressPercentage;
  final String selectedLanguage; // The language selected by the user
  final String? currentSlideId;
  final int currentSlideIndex;

  CourseProgress({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.completedSlideIds,
    this.videoWatchedSlideIds = const [],
    required this.quizAttempts,
    required this.assignmentAnswers,
    this.assignmentFeedback = const {},
    this.assignmentAdminComments = const {},
    required this.courseCompleted,
    required this.startedAt,
    this.completedAt,
    required this.progressPercentage,
    required this.selectedLanguage,
    this.currentSlideId,
    this.currentSlideIndex = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'courseId': courseId,
      'completedSlideIds': completedSlideIds,
      'videoWatchedSlideIds': videoWatchedSlideIds,
      'quizAttempts': quizAttempts.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'assignmentAnswers': assignmentAnswers,
      'assignmentFeedback': assignmentFeedback,
      'assignmentAdminComments': assignmentAdminComments,
      'courseCompleted': courseCompleted,
      'startedAt': startedAt,
      'completedAt': completedAt,
      'progressPercentage': progressPercentage,
      'selectedLanguage': selectedLanguage,
      'currentSlideId': currentSlideId,
      'currentSlideIndex': currentSlideIndex,
    };
  }

  factory CourseProgress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final quizAttemptsData =
        data['quizAttempts'] as Map<String, dynamic>? ?? {};
    final assignmentAnswersData =
        data['assignmentAnswers'] as Map<String, dynamic>? ?? {};
    final assignmentFeedbackData =
        data['assignmentFeedback'] as Map<String, dynamic>? ?? {};
    final assignmentAdminCommentsData =
        data['assignmentAdminComments'] as Map<String, dynamic>? ?? {};
    return CourseProgress(
      id: doc.id,
      userId: data['userId'] ?? '',
      courseId: data['courseId'] ?? '',
      completedSlideIds: List<String>.from(
        data['completedSlideIds'] ?? data['completedLessonIds'] ?? [],
      ),
      videoWatchedSlideIds: List<String>.from(
        data['videoWatchedSlideIds'] ?? [],
      ),
      quizAttempts: quizAttemptsData.map(
        (key, value) =>
            MapEntry(key, QuizAttempt.fromMap(value as Map<String, dynamic>)),
      ),
      assignmentAnswers: assignmentAnswersData.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
      assignmentFeedback: assignmentFeedbackData.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
      assignmentAdminComments: assignmentAdminCommentsData.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
      courseCompleted: data['courseCompleted'] ?? false,
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      progressPercentage: data['progressPercentage'] ?? 0,
      selectedLanguage: data['selectedLanguage'] ?? 'en',
      currentSlideId: data['currentSlideId'],
      currentSlideIndex: data['currentSlideIndex'] ?? 0,
    );
  }

  factory CourseProgress.fromMap(Map<String, dynamic> map, String id) {
    final quizAttemptsData = map['quizAttempts'] as Map<String, dynamic>? ?? {};
    final assignmentAnswersData =
        map['assignmentAnswers'] as Map<String, dynamic>? ?? {};
    final assignmentFeedbackData =
        map['assignmentFeedback'] as Map<String, dynamic>? ?? {};
    final assignmentAdminCommentsData =
        map['assignmentAdminComments'] as Map<String, dynamic>? ?? {};
    return CourseProgress(
      id: id,
      userId: map['userId'] ?? '',
      courseId: map['courseId'] ?? '',
      completedSlideIds: List<String>.from(
        map['completedSlideIds'] ?? map['completedLessonIds'] ?? [],
      ),
      videoWatchedSlideIds: List<String>.from(
        map['videoWatchedSlideIds'] ?? [],
      ),
      quizAttempts: quizAttemptsData.map(
        (key, value) =>
            MapEntry(key, QuizAttempt.fromMap(value as Map<String, dynamic>)),
      ),
      assignmentAnswers: assignmentAnswersData.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
      assignmentFeedback: assignmentFeedbackData.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
      assignmentAdminComments: assignmentAdminCommentsData.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
      courseCompleted: map['courseCompleted'] ?? false,
      startedAt: map['startedAt'] is Timestamp
          ? (map['startedAt'] as Timestamp).toDate()
          : DateTime.parse(map['startedAt']),
      completedAt: map['completedAt'] is Timestamp
          ? (map['completedAt'] as Timestamp).toDate()
          : (map['completedAt'] != null
                ? DateTime.parse(map['completedAt'])
                : null),
      progressPercentage: map['progressPercentage'] ?? 0,
      selectedLanguage: map['selectedLanguage'] ?? 'en',
      currentSlideId: map['currentSlideId'],
      currentSlideIndex: map['currentSlideIndex'] ?? 0,
    );
  }

  /// Copy with method
  CourseProgress copyWith({
    String? id,
    String? userId,
    String? courseId,
    List<String>? completedSlideIds,
    List<String>? videoWatchedSlideIds,
    Map<String, QuizAttempt>? quizAttempts,
    Map<String, String>? assignmentAnswers,
    Map<String, String>? assignmentFeedback,
    Map<String, String>? assignmentAdminComments,
    bool? courseCompleted,
    DateTime? startedAt,
    DateTime? completedAt,
    int? progressPercentage,
    String? selectedLanguage,
    String? currentSlideId,
    int? currentSlideIndex,
  }) {
    return CourseProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      completedSlideIds: completedSlideIds ?? this.completedSlideIds,
      videoWatchedSlideIds: videoWatchedSlideIds ?? this.videoWatchedSlideIds,
      quizAttempts: quizAttempts ?? this.quizAttempts,
      assignmentAnswers: assignmentAnswers ?? this.assignmentAnswers,
      assignmentFeedback: assignmentFeedback ?? this.assignmentFeedback,
      assignmentAdminComments:
          assignmentAdminComments ?? this.assignmentAdminComments,
      courseCompleted: courseCompleted ?? this.courseCompleted,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      currentSlideId: currentSlideId ?? this.currentSlideId,
      currentSlideIndex: currentSlideIndex ?? this.currentSlideIndex,
    );
  }

  /// Calculate progress percentage based on slides completed
  static int calculateProgressPercentage(int completedSlides, int totalSlides) {
    if (totalSlides == 0) return 0;
    return ((completedSlides / totalSlides) * 100).round();
  }
}

/// Represents a quiz attempt with answers and score
class QuizAttempt {
  final String quizId;
  final Map<String, String> answers; // questionId -> userAnswer
  final int score; // percentage (0-100)
  final int totalPoints;
  final int earnedPoints;
  final bool passed;
  final DateTime attemptedAt;
  final int durationSeconds;
  final String feedback; // Generated feedback for the user

  QuizAttempt({
    required this.quizId,
    required this.answers,
    required this.score,
    required this.totalPoints,
    required this.earnedPoints,
    required this.passed,
    required this.attemptedAt,
    required this.durationSeconds,
    required this.feedback,
  });

  Map<String, dynamic> toMap() {
    return {
      'quizId': quizId,
      'answers': answers,
      'score': score,
      'totalPoints': totalPoints,
      'earnedPoints': earnedPoints,
      'passed': passed,
      'attemptedAt': attemptedAt,
      'durationSeconds': durationSeconds,
      'feedback': feedback,
    };
  }

  factory QuizAttempt.fromMap(Map<String, dynamic> map) {
    return QuizAttempt(
      quizId: map['quizId'] ?? '',
      answers: Map<String, String>.from(map['answers'] ?? {}),
      score: map['score'] ?? 0,
      totalPoints: map['totalPoints'] ?? 0,
      earnedPoints: map['earnedPoints'] ?? 0,
      passed: map['passed'] ?? false,
      attemptedAt: map['attemptedAt'] is Timestamp
          ? (map['attemptedAt'] as Timestamp).toDate()
          : DateTime.parse(map['attemptedAt']),
      durationSeconds: map['durationSeconds'] ?? 0,
      feedback: map['feedback'] ?? '',
    );
  }
}

/// Completion certificate for a user
class CourseCertificate {
  final String id;
  final String certificateId;
  final String userId;
  final String courseId;
  final String courseName;
  final int finalScore;
  final DateTime issuedAt;
  final String certificateUrl;

  CourseCertificate({
    required this.id,
    required this.certificateId,
    required this.userId,
    required this.courseId,
    required this.courseName,
    required this.finalScore,
    required this.issuedAt,
    required this.certificateUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'certificateId': certificateId,
      'userId': userId,
      'courseId': courseId,
      'courseName': courseName,
      'finalScore': finalScore,
      'issuedAt': issuedAt,
      'certificateUrl': certificateUrl,
    };
  }

  factory CourseCertificate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CourseCertificate(
      id: doc.id,
      certificateId: data['certificateId'] ?? doc.id,
      userId: data['userId'] ?? '',
      courseId: data['courseId'] ?? '',
      courseName: data['courseName'] ?? '',
      finalScore: data['finalScore'] ?? 0,
      issuedAt: (data['issuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      certificateUrl: data['certificateUrl'] ?? '',
    );
  }
}
