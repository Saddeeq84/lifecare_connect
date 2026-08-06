// ignore_for_file: prefer_const_constructors, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import '../../../chw/data/models/course_model.dart';
import '../../../chw/data/services/course_certificate_pdf_service.dart';
import '../../../chw/presentation/screens/chw_course_slides_screen.dart';
import 'admin_chw_course_detail_editor_screen.dart';
import 'admin_weekly_assignments_screen.dart';

class AdminCHWCourseEditorScreen extends StatefulWidget {
  const AdminCHWCourseEditorScreen({super.key});

  @override
  State<AdminCHWCourseEditorScreen> createState() =>
      _AdminCHWCourseEditorScreenState();
}

class _AdminCHWCourseEditorScreenState
    extends State<AdminCHWCourseEditorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        onPressed: _createNewCourse,
        tooltip: 'Create New Course',
        child: Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search courses...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Courses list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('courses')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final courses = snapshot.data?.docs ?? [];

                if (courses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.school, size: 80, color: Colors.grey),
                        SizedBox(height: 24),
                        Text(
                          'No Courses Created',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create your first course by tapping the + button',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Filter courses based on search
                final filteredCourses = courses.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final description = (data['description'] ?? '')
                      .toString()
                      .toLowerCase();
                  return title.contains(_searchQuery) ||
                      description.contains(_searchQuery);
                }).toList();

                if (filteredCourses.isEmpty) {
                  return Center(child: Text('No courses match your search'));
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: filteredCourses.length,
                  itemBuilder: (context, index) {
                    final courseDoc = filteredCourses[index];
                    final courseData = courseDoc.data() as Map<String, dynamic>;
                    final courseId = courseDoc.id;
                    final title = courseData['title'] ?? 'Untitled Course';
                    final description =
                        courseData['description'] ?? 'No description';
                    final category = courseData['category'] ?? 'general';
                    final durationWeeks = courseData['durationWeeks'] ?? 0;
                    final isVisible = courseData['status'] == 'active';

                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.school,
                              color: Colors.teal,
                              size: 28,
                            ),
                          ),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(
                              description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _formatCategoryName(category),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.schedule,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${durationWeeks}w',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: isVisible,
                              activeColor: Colors.teal,
                              onChanged: (value) =>
                                  _setCourseVisibility(courseId, value),
                            ),
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: Row(
                                    children: [
                                      Icon(Icons.visibility, size: 18),
                                      SizedBox(width: 8),
                                      Text('Preview Course'),
                                    ],
                                  ),
                                  onTap: () {
                                    _previewCourse(courseDoc);
                                  },
                                ),
                                PopupMenuItem(
                                  child: Row(
                                    children: [
                                      Icon(Icons.workspace_premium, size: 18),
                                      SizedBox(width: 8),
                                      Text('Sample Certificate'),
                                    ],
                                  ),
                                  onTap: () {
                                    _previewSampleCertificate(courseDoc);
                                  },
                                ),
                                PopupMenuItem(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.assignment_turned_in,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Weekly Assignments'),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AdminWeeklyAssignmentsScreen(
                                              courseId: courseId,
                                              courseTitle: title.toString(),
                                            ),
                                      ),
                                    );
                                  },
                                ),
                                PopupMenuItem(
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AdminCHWCourseDetailEditorScreen(
                                              courseId: courseId,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                                PopupMenuItem(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    _deleteCourse(courseId, title);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AdminCHWCourseDetailEditorScreen(
                                    courseId: courseId,
                                  ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _createNewCourse() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminCHWCourseDetailEditorScreen(),
      ),
    );
  }

  Future<void> _setCourseVisibility(String courseId, bool isVisible) async {
    try {
      await _firestore.collection('courses').doc(courseId).update({
        'status': isVisible ? 'active' : 'archived',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update course visibility: $e')),
      );
    }
  }

  void _deleteCourse(String courseId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Course?'),
        content: Text(
          'Are you sure you want to delete "$title"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Delete course and all its slides
                final slidesQuery = await _firestore
                    .collection('courseSlides')
                    .where('courseId', isEqualTo: courseId)
                    .get();

                // Delete all slides
                for (final slide in slidesQuery.docs) {
                  await slide.reference.delete();
                }

                // Delete the course
                await _firestore.collection('courses').doc(courseId).delete();

                // Delete all course progress records
                final progressQuery = await _firestore
                    .collection('courseProgress')
                    .where('courseId', isEqualTo: courseId)
                    .get();

                for (final progress in progressQuery.docs) {
                  await progress.reference.delete();
                }

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Course deleted successfully')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting course: $e')),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _previewCourse(QueryDocumentSnapshot courseDoc) async {
    try {
      final course = Course.fromFirestore(courseDoc);
      final slidesSnapshot = await _firestore
          .collection('courseSlides')
          .where('courseId', isEqualTo: course.id)
          .orderBy('orderIndex')
          .get();
      final slides = slidesSnapshot.docs
          .map((doc) => CourseSlide.fromFirestore(doc))
          .toList();

      if (slides.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No slides found for this course.')),
        );
        return;
      }

      final finalQuizSnapshot = await _firestore
          .collection('quizzes')
          .where('courseId', isEqualTo: course.id)
          .where('isFinal', isEqualTo: true)
          .limit(1)
          .get();
      final finalQuiz = finalQuizSnapshot.docs.isEmpty
          ? null
          : Quiz.fromFirestore(finalQuizSnapshot.docs.first);

      final previewProgress = CourseProgress(
        id: 'admin_preview_${course.id}',
        userId: 'admin_preview',
        courseId: course.id,
        completedSlideIds: const [],
        quizAttempts: const {},
        assignmentAnswers: const {},
        courseCompleted: false,
        startedAt: DateTime.now(),
        progressPercentage: 0,
        selectedLanguage: 'en',
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CHWCourseSlidesScreen(
            course: course,
            courseProgress: previewProgress,
            slides: slides,
            finalQuiz: finalQuiz,
            selectedLanguage: 'en',
            isAdminPreview: true,
            onProgressUpdated: (_) {},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Preview failed: $e')));
    }
  }

  Future<void> _previewSampleCertificate(
    QueryDocumentSnapshot courseDoc,
  ) async {
    try {
      final course = Course.fromFirestore(courseDoc);
      final pdf = await CourseCertificatePdfService.buildCertificate(
        learnerName: 'Sample Learner Name',
        courseTitle: course.title,
        issuedDate: DateTime.now(),
        certificateId:
            'SAMPLE-${course.id.substring(0, course.id.length < 8 ? course.id.length : 8)}',
        signatureUrl: course.certificateSignatureUrl,
      );

      await Printing.layoutPdf(
        name: 'Sample_Certificate_${course.title}.pdf',
        onLayout: (format) => pdf.save(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Certificate preview failed: $e')));
    }
  }

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
