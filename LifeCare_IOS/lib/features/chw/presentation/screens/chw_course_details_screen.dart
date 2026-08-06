// ignore_for_file: prefer_const_constructors, avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/course_model.dart';
import 'chw_course_slides_screen.dart';

class CHWCourseDetailsScreen extends StatefulWidget {
  final Course course;
  final String? initialSlideId;

  const CHWCourseDetailsScreen({
    super.key,
    required this.course,
    this.initialSlideId,
  });

  @override
  State<CHWCourseDetailsScreen> createState() => _CHWCourseDetailsScreenState();
}

class _CHWCourseDetailsScreenState extends State<CHWCourseDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late CourseProgress _courseProgress;
  List<CourseSlide> _slides = [];
  Quiz? _finalQuiz;
  String _selectedLanguage = 'en';
  bool _isEnrolled = false;
  bool _isLoading = true;
  bool _openedInitialSlide = false;

  @override
  void initState() {
    super.initState();
    _loadCourseData();
  }

  Future<void> _loadCourseData() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final progressSnapshot = await _firestore
          .collection('courseProgress')
          .where('userId', isEqualTo: userId)
          .where('courseId', isEqualTo: widget.course.id)
          .limit(1)
          .get();

      if (progressSnapshot.docs.isNotEmpty) {
        _courseProgress = CourseProgress.fromFirestore(
          progressSnapshot.docs.first,
        );
        _selectedLanguage = _courseProgress.selectedLanguage;
        _isEnrolled = true;
      } else {
        _courseProgress = CourseProgress(
          id: _firestore.collection('courseProgress').doc().id,
          userId: userId,
          courseId: widget.course.id,
          completedSlideIds: [],
          quizAttempts: {},
          assignmentAnswers: {},
          courseCompleted: false,
          startedAt: DateTime.now(),
          progressPercentage: 0,
          selectedLanguage: _selectedLanguage,
        );
      }

      final slidesSnapshot = await _firestore
          .collection('courseSlides')
          .where('courseId', isEqualTo: widget.course.id)
          .orderBy('orderIndex')
          .get();

      _slides = slidesSnapshot.docs
          .map((doc) => CourseSlide.fromFirestore(doc))
          .toList();

      final finalQuizSnapshot = await _firestore
          .collection('quizzes')
          .where('courseId', isEqualTo: widget.course.id)
          .where('isFinal', isEqualTo: true)
          .limit(1)
          .get();

      if (finalQuizSnapshot.docs.isNotEmpty) {
        _finalQuiz = Quiz.fromFirestore(finalQuizSnapshot.docs.first);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load course data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        if (widget.initialSlideId != null &&
            _isEnrolled &&
            !_openedInitialSlide) {
          _openedInitialSlide = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _startCourse();
          });
        }
      }
    }
  }

  Future<bool> _enrollCourse() async {
    try {
      await _firestore
          .collection('courseProgress')
          .doc(_courseProgress.id)
          .set(_courseProgress.toMap());

      if (!mounted) return false;
      setState(() {
        _isEnrolled = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully enrolled in course!')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Enroll failed: $e')));
      return false;
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (!_isEnrolled) {
      final enrolled = await _enrollCourse();
      if (!enrolled) return;
    }
    await _startCourse();
  }

  Future<void> _startCourse() async {
    if (_slides.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No slides have been added for this course yet.'),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CHWCourseSlidesScreen(
          course: widget.course,
          courseProgress: _courseProgress,
          slides: _slides,
          finalQuiz: _finalQuiz,
          selectedLanguage: _selectedLanguage,
          initialSlideId: widget.initialSlideId,
          onProgressUpdated: (updatedProgress) {
            setState(() {
              _courseProgress = updatedProgress;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Course Details'),
          backgroundColor: Colors.teal,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final progressPercent = CourseProgress.calculateProgressPercentage(
      _courseProgress.completedSlideIds.length,
      _slides.isNotEmpty ? _slides.length : widget.course.totalLessons,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Details'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.course.imageUrl != null)
              Image.network(
                widget.course.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              )
            else
              const SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.course.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                      _formatCategoryName(widget.course.category),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: Colors.teal,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.course.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildProgressCard(progressPercent),
                  const SizedBox(height: 24),
                  _buildCourseInfoCard(),
                  const SizedBox(height: 24),
                  _buildLearningPathCard(),
                  const SizedBox(height: 24),
                  const Text(
                    'Course Outline',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.teal.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.course.courseOutline.isEmpty
                          ? _buildGeneratedOutline()
                          : widget.course.courseOutline,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Available Languages',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLanguageSelection(),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _handlePrimaryAction,
                      child: Text(
                        _isEnrolled
                            ? 'Continue Course'
                            : 'Enroll & Start Course',
                        style: const TextStyle(
                          fontSize: 16,
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
      ),
    );
  }

  Widget _buildProgressCard(int progressPercent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Slides Completed',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                Text(
                  '${_courseProgress.completedSlideIds.length}/${_slides.isNotEmpty ? _slides.length : widget.course.totalLessons}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressPercent / 100,
                minHeight: 8,
                backgroundColor: Colors.teal.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$progressPercent% Complete',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildInfoColumn(
              icon: Icons.slideshow,
              value:
                  '${_slides.isNotEmpty ? _slides.length : widget.course.totalLessons}',
              label: 'Slides',
            ),
            _buildInfoColumn(
              icon: Icons.access_time,
              value: '${widget.course.durationWeeks}',
              label: 'Weeks',
            ),
            _buildInfoColumn(
              icon: Icons.language,
              value: '${widget.course.availableLanguages.length}',
              label: 'Languages',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningPathCard() {
    final modules = _groupSlidesByModule();
    if (modules.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Learning Path',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ...modules.asMap().entries.map((moduleEntry) {
              final module = moduleEntry.value;
              final lessons = module['lessons'] as List<Map<String, dynamic>>;
              final moduleSlides = lessons.fold<int>(
                0,
                (sum, lesson) => sum + (lesson['slides'] as List).length,
              );
              final completedSlides = lessons.fold<int>(0, (sum, lesson) {
                final slides = lesson['slides'] as List<CourseSlide>;
                return sum +
                    slides
                        .where(
                          (slide) => _courseProgress.completedSlideIds.contains(
                            slide.id,
                          ),
                        )
                        .length;
              });

              return ExpansionTile(
                initiallyExpanded: moduleEntry.key == 0,
                tilePadding: EdgeInsets.zero,
                title: Text(module['title'] as String),
                subtitle: Text(
                  '$completedSlides/$moduleSlides slides completed',
                ),
                children: lessons.map((lesson) {
                  final slides = lesson['slides'] as List<CourseSlide>;
                  final lessonCompleted = slides
                      .where(
                        (slide) => _courseProgress.completedSlideIds.contains(
                          slide.id,
                        ),
                      )
                      .length;
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 16, right: 8),
                    leading: Icon(
                      lessonCompleted == slides.length && slides.isNotEmpty
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color:
                          lessonCompleted == slides.length && slides.isNotEmpty
                          ? Colors.teal
                          : Colors.grey,
                    ),
                    title: Text(lesson['title'] as String),
                    subtitle: Text('$lessonCompleted/${slides.length} slides'),
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.teal, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildLanguageSelection() {
    return Wrap(
      spacing: 8,
      children: widget.course.availableLanguages.map((lang) {
        return ChoiceChip(
          label: Text(_getLanguageName(lang)),
          selected: _selectedLanguage == lang,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedLanguage = lang;
              });
              _updateLanguagePreference(lang);
            }
          },
          selectedColor: Colors.teal,
          labelStyle: TextStyle(
            color: _selectedLanguage == lang ? Colors.white : Colors.black87,
          ),
        );
      }).toList(),
    );
  }

  Future<void> _updateLanguagePreference(String language) async {
    try {
      if (!_isEnrolled) {
        _courseProgress = _courseProgress.copyWith(selectedLanguage: language);
        return;
      }
      await _firestore
          .collection('courseProgress')
          .doc(_courseProgress.id)
          .update({'selectedLanguage': language});
    } catch (e) {
      print('Error updating language: $e');
    }
  }

  String _getLanguageName(String langCode) {
    const languages = {
      'en': '🇬🇧 English',
      'es': '🇪🇸 Spanish',
      'fr': '🇫🇷 French',
      'pt': '🇵🇹 Portuguese',
      'sw': '🇹🇿 Swahili',
      'ar': '🇸🇦 Arabic',
    };
    return languages[langCode] ?? langCode;
  }

  String _formatCategoryName(String category) {
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  List<Map<String, dynamic>> _groupSlidesByModule() {
    final modules = <String, Map<String, dynamic>>{};
    for (final slide in _slides) {
      final module = modules.putIfAbsent(slide.moduleId, () {
        return {
          'title': slide.moduleTitle,
          'orderIndex': slide.moduleOrderIndex,
          'lessons': <String, Map<String, dynamic>>{},
        };
      });
      final lessons = module['lessons'] as Map<String, Map<String, dynamic>>;
      final lesson = lessons.putIfAbsent(slide.lessonId, () {
        return {
          'title': slide.lessonTitle,
          'orderIndex': slide.lessonOrderIndex,
          'slides': <CourseSlide>[],
        };
      });
      (lesson['slides'] as List<CourseSlide>).add(slide);
    }

    final moduleList = modules.values.toList()
      ..sort(
        (a, b) => (a['orderIndex'] as int).compareTo(b['orderIndex'] as int),
      );
    return moduleList.map((module) {
      final lessonsMap = module['lessons'] as Map<String, Map<String, dynamic>>;
      final lessons = lessonsMap.values.toList()
        ..sort(
          (a, b) => (a['orderIndex'] as int).compareTo(b['orderIndex'] as int),
        );
      return {
        'title': module['title'],
        'orderIndex': module['orderIndex'],
        'lessons': lessons,
      };
    }).toList();
  }

  String _buildGeneratedOutline() {
    final modules = _groupSlidesByModule();
    if (modules.isEmpty) return 'No outline available yet.';
    return modules
        .asMap()
        .entries
        .map((moduleEntry) {
          final lessons =
              moduleEntry.value['lessons'] as List<Map<String, dynamic>>;
          final lessonLines = lessons
              .asMap()
              .entries
              .map((lessonEntry) {
                final slides = lessonEntry.value['slides'] as List<CourseSlide>;
                return '  Lesson ${moduleEntry.key + 1}.${lessonEntry.key + 1}: ${lessonEntry.value['title']} (${slides.length} slides)';
              })
              .join('\n');
          return 'Module ${moduleEntry.key + 1}: ${moduleEntry.value['title']}\n$lessonLines';
        })
        .join('\n');
  }
}
