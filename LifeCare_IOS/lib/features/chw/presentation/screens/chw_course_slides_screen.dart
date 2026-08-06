// ignore_for_file: avoid_print, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/services/gemini_service.dart';
import '../../data/models/course_model.dart';

class CHWCourseSlidesScreen extends StatefulWidget {
  final Course course;
  final CourseProgress courseProgress;
  final List<CourseSlide> slides;
  final Quiz? finalQuiz;
  final String selectedLanguage;
  final void Function(CourseProgress updatedProgress) onProgressUpdated;
  final bool isAdminPreview;
  final String? initialSlideId;

  const CHWCourseSlidesScreen({
    super.key,
    required this.course,
    required this.courseProgress,
    required this.slides,
    required this.finalQuiz,
    required this.selectedLanguage,
    required this.onProgressUpdated,
    this.isAdminPreview = false,
    this.initialSlideId,
  });

  @override
  State<CHWCourseSlidesScreen> createState() => _CHWCourseSlidesScreenState();
}

class _CHWCourseSlidesScreenState extends State<CHWCourseSlidesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Duration _minimumSlideTime = Duration(minutes: 2);
  int _currentIndex = 0;
  final Map<String, String> _selectedAnswers = {};
  final Set<String> _quizResultVisible = {};
  final TextEditingController _assignmentController = TextEditingController();
  bool _isSubmitting = false;
  bool _isVideoLoading = false;
  bool _isMarkingVideoWatched = false;
  String? _videoError;
  String? _activeVideoUrl;
  DateTime _slideEnteredAt = DateTime.now();
  DateTime? _lastVideoProgressAt;
  Duration _videoWatchTime = Duration.zero;
  VideoPlayerController? _videoController;
  late CourseProgress _courseProgress;

  CourseSlide get _currentSlide => widget.slides[_currentIndex];
  bool get _hasFinalQuiz => widget.finalQuiz != null;

  @override
  void initState() {
    super.initState();
    _courseProgress = widget.courseProgress;
    _currentIndex = _resolveInitialIndex();
    _loadCurrentSlideState();
    _markSlideEntered();
    _resetVideoPlayer();
    if (!widget.isAdminPreview) {
      Future.microtask(_saveCurrentLocation);
    }
  }

  @override
  void didUpdateWidget(CHWCourseSlidesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldVideoUrl = _currentIndex < oldWidget.slides.length
        ? oldWidget.slides[_currentIndex].videoUrl
        : null;
    if (oldVideoUrl != _currentSlide.videoUrl) {
      _resetVideoPlayer();
    }
  }

  void _resetVideoPlayer() {
    _videoController?.dispose();
    _videoController = null;
    _activeVideoUrl = null;
    _videoError = null;
    _isVideoLoading = false;
    _lastVideoProgressAt = null;
    _videoWatchTime = Duration.zero;
  }

  Future<void> _initializeVideoPlayer() async {
    final videoUrl = _currentSlide.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) return;
    if (_activeVideoUrl == videoUrl &&
        _videoController?.value.isInitialized == true) {
      return;
    }

    _videoController?.dispose();
    setState(() {
      _videoController = null;
      _activeVideoUrl = videoUrl;
      _videoError = null;
      _isVideoLoading = true;
    });

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize().timeout(const Duration(seconds: 18));
      if (!mounted || _activeVideoUrl != videoUrl) {
        await controller.dispose();
        return;
      }
      controller.addListener(_handleVideoProgress);
      setState(() {
        _videoController = controller;
        _isVideoLoading = false;
      });
    } catch (e) {
      await controller.dispose();
      if (!mounted || _activeVideoUrl != videoUrl) return;
      setState(() {
        _videoController = null;
        _isVideoLoading = false;
        _videoError =
            'Video could not load on this connection. Please retry when the signal improves.';
      });
    }
  }

  void _handleVideoProgress() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (_isMarkingVideoWatched) return;
    if (_courseProgress.videoWatchedSlideIds.contains(_currentSlide.id)) {
      return;
    }

    final duration = controller.value.duration;
    final position = controller.value.position;
    if (duration == Duration.zero) return;

    final now = DateTime.now();
    if (controller.value.isPlaying) {
      final lastProgressAt = _lastVideoProgressAt;
      if (lastProgressAt != null) {
        final elapsed = now.difference(lastProgressAt);
        if (elapsed > Duration.zero) {
          _videoWatchTime += elapsed > const Duration(seconds: 2)
              ? const Duration(seconds: 2)
              : elapsed;
        }
      }
      _lastVideoProgressAt = now;
    } else {
      _lastVideoProgressAt = null;
    }

    final isNearEnd =
        duration > const Duration(seconds: 2) &&
        position >= duration - const Duration(seconds: 2);
    final requiredWatchTime = Duration(
      milliseconds: (duration.inMilliseconds * 0.9).round(),
    );
    final watchedToEnd =
        _videoWatchTime >= requiredWatchTime &&
        (isNearEnd ||
            (duration.inMilliseconds > 0 &&
                position.inMilliseconds / duration.inMilliseconds >= 0.95));
    if (watchedToEnd) {
      _markCurrentVideoWatched();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _assignmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = CourseProgress.calculateProgressPercentage(
      _courseProgress.completedSlideIds.length,
      widget.slides.length,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.title),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                '${_currentIndex + 1}/${widget.slides.length}',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
          if (widget.isAdminPreview)
            IconButton(
              tooltip: 'Admin preview',
              onPressed: () {},
              icon: const Icon(Icons.visibility),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.teal.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_currentSlide.moduleTitle} • ${_currentSlide.lessonTitle}',
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentSlide.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.isAdminPreview
                      ? 'Preview'
                      : '$progressPercent% complete',
                  style: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: progressPercent / 100,
            backgroundColor: Colors.teal.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade700),
            minHeight: 6,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSlideContent(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousSlide,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal,
                        side: BorderSide(color: Colors.teal),
                      ),
                      child: const Text('Previous'),
                    ),
                  )
                else
                  const SizedBox(width: 1),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _nextSlide,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(_nextButtonLabel()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideContent() {
    if (_currentSlide.type == SlideType.quiz) {
      return _buildQuizSlide();
    }
    if (_currentSlide.type == SlideType.assignment) {
      return _buildAssignmentSlide();
    }

    final rawContent = widget.selectedLanguage == 'en'
        ? (_currentSlide.content ?? _currentSlide.contentByLanguage['en'] ?? '')
        : (_currentSlide.contentByLanguage[widget.selectedLanguage] ??
              _currentSlide.content ??
              '');
    final content = _cleanSlideContent(rawContent);
    final description = _cleanSlideContent(_currentSlide.description);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentSlide.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (description.isNotEmpty) ...[
            Text(
              description,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
          ],
          if (_currentSlide.videoUrl != null &&
              _currentSlide.videoUrl!.isNotEmpty)
            _buildVideoSlidePlayer(),
          if (_currentSlide.videoUrl != null &&
              _currentSlide.videoUrl!.isNotEmpty)
            const SizedBox(height: 20),
          if (content.isNotEmpty) ...[
            Text(content, style: const TextStyle(fontSize: 16, height: 1.7)),
            const SizedBox(height: 24),
          ],
          if (_currentSlide.imageUrl != null &&
              _currentSlide.imageUrl!.isNotEmpty)
            _buildSlideImage(_currentSlide.imageUrl!),
          if (_currentSlide.imageUrl != null &&
              _currentSlide.imageUrl!.isNotEmpty)
            const SizedBox(height: 20),
          Text(
            'Estimated ${_currentSlide.estimatedDurationMinutes} minutes',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideImage(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        cacheKey: imageUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 120),
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.shade100),
          ),
          child: Row(
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.teal.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Loading image. You can continue reading while it loads.',
                  style: TextStyle(color: Colors.teal.shade900, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.image_not_supported, color: Colors.grey.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Image could not load on this connection. The lesson text is still available.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoSlidePlayer() {
    final controller = _videoController;
    final isReady = controller?.value.isInitialized == true;
    final isWatched = _courseProgress.videoWatchedSlideIds.contains(
      _currentSlide.id,
    );

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: isReady
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: controller!.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                  FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        controller.value.isPlaying
                            ? controller.pause()
                            : controller.play();
                      });
                    },
                    backgroundColor: Colors.teal.withValues(alpha: 0.78),
                    child: Icon(
                      controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),
                  if (isWatched)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Video watched',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_outline, size: 44, color: Colors.teal),
                  const SizedBox(height: 10),
                  Text(
                    isWatched
                        ? 'Video watched. You can replay it if you need to review.'
                        : _videoError ??
                              'Video is ready to load when your connection is stable.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _isVideoLoading ? null : _initializeVideoPlayer,
                    icon: _isVideoLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text(_isVideoLoading ? 'Loading...' : 'Load Video'),
                  ),
                ],
              ),
            ),
    );
  }

  String _cleanSlideContent(String content) {
    final cleanedLines = content
        .split(RegExp(r'\r?\n'))
        .where((line) => !_isPlaceholderSlideContent(line))
        .join('\n')
        .trim();
    return cleanedLines;
  }

  bool _isPlaceholderSlideContent(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    return normalized == 'enter your slide content here' ||
        normalized == 'enter your slide contents here';
  }

  Widget _buildAssignmentSlide() {
    final savedAnswer = _courseProgress.assignmentAnswers[_currentSlide.id];
    final rawSavedFeedback =
        _courseProgress.assignmentFeedback[_currentSlide.id];
    final savedFeedback = rawSavedFeedback == null
        ? null
        : _cleanAssignmentFeedback(rawSavedFeedback);
    final adminComment =
        _courseProgress.assignmentAdminComments[_currentSlide.id];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentSlide.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _currentSlide.assignmentQuestion ??
                _currentSlide.content ??
                _currentSlide.description,
            style: const TextStyle(fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 20),
          Text(
            'Minimum: ${_currentSlide.assignmentMinWords} words',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _assignmentController,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: 'Your Answer',
              border: const OutlineInputBorder(),
              suffixIcon: savedAnswer != null && savedAnswer.trim().isNotEmpty
                  ? const Icon(Icons.check_circle, color: Colors.teal)
                  : null,
            ),
          ),
          if (savedFeedback != null && savedFeedback.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Feedback',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(savedFeedback, style: const TextStyle(height: 1.5)),
                ],
              ),
            ),
          ],
          if (adminComment != null && adminComment.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admin Comment',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(adminComment, style: const TextStyle(height: 1.5)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizSlide() {
    final quiz = Quiz(
      id: _currentSlide.id,
      courseId: widget.course.id,
      title: _currentSlide.title,
      description: _currentSlide.description,
      totalQuestions: _currentSlide.questions.length,
      passingScore: 70,
      questions: _currentSlide.questions,
      estimatedDurationMinutes: _currentSlide.estimatedDurationMinutes,
      createdAt: DateTime.now(),
    );
    final attempt = _courseProgress.quizAttempts[quiz.id];
    final showResult = _quizResultVisible.contains(quiz.id);
    final passed = attempt?.passed == true;
    final needsRetake = showResult && attempt != null && !passed;

    return ListView(
      children: [
        Text(
          quiz.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          quiz.description,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.teal.shade100),
          ),
          child: Text(
            showResult && attempt != null
                ? 'Score: ${attempt.score}%. ${attempt.passed ? 'Passed' : 'You need 70% to proceed. You can try again.'}'
                : 'You need 70% to proceed. You have unlimited attempts.',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
        const SizedBox(height: 20),
        ...quiz.questions.map((question) {
          final selectedValue = _selectedAnswers[question.id];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.questionText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...question.options.map((option) {
                    final isSelected = selectedValue == option;
                    final isCorrect = question.correctAnswer == option;
                    final showCorrect = showResult && isCorrect;
                    final showWrong = showResult && isSelected && !isCorrect;
                    return RadioListTile<String>(
                      title: Text(option),
                      subtitle: showCorrect || showWrong
                          ? Text(
                              showCorrect ? 'Correct answer' : 'Your answer',
                              style: TextStyle(
                                color: showCorrect ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                      secondary: showCorrect || showWrong
                          ? Icon(
                              showCorrect ? Icons.check_circle : Icons.cancel,
                              color: showCorrect ? Colors.green : Colors.red,
                            )
                          : null,
                      value: option,
                      groupValue: selectedValue,
                      onChanged: passed || showResult
                          ? null
                          : (value) {
                              setState(() {
                                if (value != null) {
                                  _selectedAnswers[question.id] = value;
                                  _quizResultVisible.remove(quiz.id);
                                }
                              });
                            },
                    );
                  }),
                ],
              ),
            ),
          );
        }),
        if (needsRetake) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _retakeQuizSlide,
            icon: const Icon(Icons.refresh),
            label: const Text('Retake Quiz'),
          ),
        ],
      ],
    );
  }

  String _nextButtonLabel() {
    if (widget.isAdminPreview) {
      return _currentIndex == widget.slides.length - 1
          ? 'Finish Preview'
          : 'Next';
    }
    if (_currentSlide.type == SlideType.assignment &&
        !_courseProgress.completedSlideIds.contains(_currentSlide.id)) {
      return 'Submit Assignment';
    }
    if (_currentSlide.type == SlideType.quiz) {
      final attempt = _courseProgress.quizAttempts[_currentSlide.id];
      if (attempt != null &&
          attempt.passed != true &&
          _quizResultVisible.contains(_currentSlide.id)) {
        return 'Retake Quiz';
      }
      if (attempt?.passed != true ||
          !_quizResultVisible.contains(_currentSlide.id)) {
        return 'Submit Quiz';
      }
    }
    if (_currentIndex == widget.slides.length - 1) {
      return _hasFinalQuiz ? 'Take Final Quiz' : 'Finish Course';
    }
    return 'Next';
  }

  void _markSlideEntered() {
    _slideEnteredAt = DateTime.now();
  }

  void _previousSlide() {
    setState(() {
      _currentIndex = _currentIndex - 1;
      _loadCurrentSlideState();
      _markSlideEntered();
      _resetVideoPlayer();
    });
    _saveCurrentLocation();
  }

  Future<void> _nextSlide() async {
    if (widget.isAdminPreview) {
      await _advanceAdminPreview();
      return;
    }

    final isQuizRetakeAction =
        _currentSlide.type == SlideType.quiz &&
        _courseProgress.quizAttempts[_currentSlide.id] != null &&
        _courseProgress.quizAttempts[_currentSlide.id]?.passed != true &&
        _quizResultVisible.contains(_currentSlide.id);

    if (!isQuizRetakeAction && !_canLeaveCurrentSlide()) {
      return;
    }

    if (_currentSlide.type == SlideType.quiz) {
      final existingAttempt = _courseProgress.quizAttempts[_currentSlide.id];
      if (existingAttempt != null &&
          existingAttempt.passed != true &&
          _quizResultVisible.contains(_currentSlide.id)) {
        await _retakeQuizSlide();
        return;
      }
      if (existingAttempt?.passed == true &&
          _quizResultVisible.contains(_currentSlide.id)) {
        await _completeCurrentSlideAndAdvance();
        return;
      }
      if (!_validateQuizAnswers()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please answer all quiz questions.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      await _submitQuizSlide();
      return;
    }

    if (_currentSlide.type == SlideType.assignment) {
      final answer = _assignmentController.text.trim();
      if (answer.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your answer before continuing.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final wordCount = _wordCount(answer);
      if (wordCount < _currentSlide.assignmentMinWords) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please write at least ${_currentSlide.assignmentMinWords} words before submitting.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      await _submitAssignment(answer);
      return;
    }

    await _completeCurrentSlideAndAdvance();
  }

  Future<void> _advanceAdminPreview() async {
    if (_currentIndex == widget.slides.length - 1) {
      if (_hasFinalQuiz) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CHWFinalQuizScreen(
              quiz: widget.finalQuiz!,
              course: widget.course,
              courseProgress: _courseProgress,
              isAdminPreview: true,
            ),
          ),
        );
        if (!mounted) return;
      }
      Navigator.pop(context);
      return;
    }
    setState(() {
      _currentIndex += 1;
      _loadCurrentSlideState();
      _markSlideEntered();
      _resetVideoPlayer();
    });
  }

  Future<void> _completeCurrentSlideAndAdvance() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final updatedSlideIds = List<String>.from(
        _courseProgress.completedSlideIds,
      );
      if (!updatedSlideIds.contains(_currentSlide.id)) {
        updatedSlideIds.add(_currentSlide.id);
      }

      var updatedProgress = _courseProgress.copyWith(
        completedSlideIds: updatedSlideIds,
        progressPercentage: CourseProgress.calculateProgressPercentage(
          updatedSlideIds.length,
          widget.slides.length,
        ),
      );

      if (!widget.isAdminPreview) {
        await _firestore
            .collection('courseProgress')
            .doc(updatedProgress.id)
            .update(updatedProgress.toMap());
      }

      _courseProgress = updatedProgress;
      widget.onProgressUpdated(updatedProgress);

      if (_currentIndex == widget.slides.length - 1) {
        if (_hasFinalQuiz) {
          await _openFinalQuiz();
        } else {
          await _finishCourse(updatedProgress, 100, true);
        }
      } else {
        setState(() {
          _currentIndex += 1;
          _loadCurrentSlideState();
          _markSlideEntered();
          _resetVideoPlayer();
        });
        await _saveCurrentLocation();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating progress: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  bool _canLeaveCurrentSlide() {
    if (widget.isAdminPreview) return true;
    if (_courseProgress.completedSlideIds.contains(_currentSlide.id)) {
      return true;
    }

    if (_currentSlideHasVideo &&
        !_courseProgress.videoWatchedSlideIds.contains(_currentSlide.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please load and watch the video before continuing.'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    if (!_canSkipMinimumSlideTime &&
        DateTime.now().difference(_slideEnteredAt) < _minimumSlideTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please read this slide for at least 2 minutes.'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    return true;
  }

  bool get _canSkipMinimumSlideTime {
    if (_currentSlide.type != SlideType.content) return false;
    if (_currentSlideHasVideo) return false;

    final markers = [
      _currentSlide.title,
      _currentSlide.description,
    ].map(_normalizeSlideMarker);

    return markers.any(
      (marker) =>
          marker == 'references' ||
          marker == 'reference' ||
          marker == 'learning objectives' ||
          marker == 'learning objective' ||
          marker == 'objectives' ||
          marker == 'objectives of the lesson',
    );
  }

  String _normalizeSlideMarker(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool get _currentSlideHasVideo =>
      _currentSlide.videoUrl != null && _currentSlide.videoUrl!.isNotEmpty;

  Future<void> _markCurrentVideoWatched() async {
    final slideId = _currentSlide.id;
    final watchedSlideIds = List<String>.from(
      _courseProgress.videoWatchedSlideIds,
    );
    if (watchedSlideIds.contains(slideId)) return;

    _isMarkingVideoWatched = true;
    watchedSlideIds.add(slideId);
    final updatedProgress = _courseProgress.copyWith(
      videoWatchedSlideIds: watchedSlideIds,
    );

    if (widget.isAdminPreview) {
      setState(() => _courseProgress = updatedProgress);
      widget.onProgressUpdated(updatedProgress);
      _isMarkingVideoWatched = false;
      return;
    }

    try {
      await _firestore.collection('courseProgress').doc(updatedProgress.id).set(
        {
          'videoWatchedSlideIds': watchedSlideIds,
          'lastAccessedAt': DateTime.now(),
        },
        SetOptions(merge: true),
      );
      if (!mounted) return;
      setState(() => _courseProgress = updatedProgress);
      widget.onProgressUpdated(updatedProgress);
    } catch (e) {
      debugPrint('Error marking video watched: $e');
    } finally {
      _isMarkingVideoWatched = false;
    }
  }

  Future<void> _submitQuizSlide() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentSlide = _currentSlide;
      final totalPoints = currentSlide.questions.fold<int>(
        0,
        (sum, question) => sum + question.points,
      );
      final earnedPoints = currentSlide.questions.fold<int>(
        0,
        (sum, question) =>
            sum +
            (question.correctAnswer == _selectedAnswers[question.id]
                ? question.points
                : 0),
      );
      final score = totalPoints == 0
          ? 0
          : ((earnedPoints / totalPoints) * 100).round();
      final passed = score >= 70;
      final attempt = QuizAttempt(
        quizId: currentSlide.id,
        answers: Map<String, String>.from(_selectedAnswers),
        score: score,
        totalPoints: totalPoints,
        earnedPoints: earnedPoints,
        passed: passed,
        attemptedAt: DateTime.now(),
        durationSeconds: 0,
        feedback: passed
            ? 'Great work. You scored $score% and can continue.'
            : 'You scored $score%. You need 70% to continue.',
      );

      final completedSlideIds = List<String>.from(
        _courseProgress.completedSlideIds,
      );
      if (passed && !completedSlideIds.contains(currentSlide.id)) {
        completedSlideIds.add(currentSlide.id);
      }

      final updatedProgress = _courseProgress.copyWith(
        completedSlideIds: completedSlideIds,
        quizAttempts: {
          ..._courseProgress.quizAttempts,
          currentSlide.id: attempt,
        },
        progressPercentage: CourseProgress.calculateProgressPercentage(
          completedSlideIds.length,
          widget.slides.length,
        ),
      );

      await _firestore
          .collection('courseProgress')
          .doc(updatedProgress.id)
          .update(updatedProgress.toMap());

      if (!mounted) return;
      setState(() {
        _courseProgress = updatedProgress;
        _quizResultVisible.add(currentSlide.id);
      });
      widget.onProgressUpdated(updatedProgress);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error submitting quiz: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _retakeQuizSlide() async {
    setState(() => _isSubmitting = true);
    try {
      final quizAttempts = Map<String, QuizAttempt>.from(
        _courseProgress.quizAttempts,
      )..remove(_currentSlide.id);
      final updatedProgress = _courseProgress.copyWith(
        quizAttempts: quizAttempts,
      );
      await _firestore
          .collection('courseProgress')
          .doc(updatedProgress.id)
          .update(updatedProgress.toMap());

      if (!mounted) return;
      setState(() {
        _courseProgress = updatedProgress;
        _selectedAnswers.clear();
        _quizResultVisible.remove(_currentSlide.id);
      });
      widget.onProgressUpdated(updatedProgress);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error resetting quiz: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitAssignment(String answer) async {
    setState(() => _isSubmitting = true);
    try {
      String feedback;
      try {
        feedback = _cleanAssignmentFeedback(
          await _generateAssignmentFeedback(answer),
        );
      } catch (e) {
        debugPrint('Assignment AI feedback failed: $e');
        feedback =
            'Your assignment has been submitted. AI feedback is temporarily unavailable.';
      }

      final answers = Map<String, String>.from(
        _courseProgress.assignmentAnswers,
      );
      answers[_currentSlide.id] = answer;
      final feedbackMap = Map<String, String>.from(
        _courseProgress.assignmentFeedback,
      );
      feedbackMap[_currentSlide.id] = feedback;

      final updatedProgress = _courseProgress.copyWith(
        assignmentAnswers: answers,
        assignmentFeedback: feedbackMap,
      );

      await _firestore
          .collection('courseProgress')
          .doc(updatedProgress.id)
          .update(updatedProgress.toMap());

      _courseProgress = updatedProgress;
      widget.onProgressUpdated(updatedProgress);
      if (mounted) setState(() => _isSubmitting = false);
      await _showAssignmentFeedback(feedback);
      await _completeCurrentSlideAndAdvance();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Assignment submit failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  int _wordCount(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
  }

  Future<String> _generateAssignmentFeedback(String answer) async {
    await GeminiService.initialize();
    final service = GeminiService.instance;
    if (!service.isConfigured) {
      throw Exception('Gemini is not configured.');
    }

    final prompt =
        '''
Assess this CHW course weekly assignment response and give concise, constructive learner feedback.

Assignment question:
${_currentSlide.assignmentQuestion ?? _currentSlide.content ?? _currentSlide.description}

Learner response:
$answer

Use these criteria:
- Relevance to the question
- Accuracy and safe community-health reasoning
- Completeness and practical examples
- Organization and clarity
- Evidence of reflection or local context

Return:
1. Overall feedback in 2-3 short paragraphs.
2. Strengths.
3. Areas to improve.
4. One practical next step.

Write in clean plain text only. Do not use Markdown, asterisks, bold text, bullet symbols, tables, emojis, or decorative formatting. Keep the full feedback concise and easy to read on a mobile screen.

Do not invent facts. If the answer is weak or unsafe, say so respectfully and suggest improvement.
''';

    return service.getChatResponse(
      userMessage: prompt,
      userRole: 'chw',
      conversationHistory: const [],
    );
  }

  String _cleanAssignmentFeedback(String feedback) {
    var cleaned = feedback
        .replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (match) {
          return match.group(1) ?? '';
        })
        .replaceAllMapped(RegExp(r'\*([^*\n]+)\*'), (match) {
          return match.group(1) ?? '';
        })
        .replaceAll(RegExp(r'^\s*[*\-•]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'#{1,6}\s*'), '')
        .replaceAll(RegExp(r'`{1,3}'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    cleaned = cleaned.split('\n').map((line) => line.trim()).join('\n').trim();

    return cleaned.isEmpty
        ? 'Your assignment has been submitted. Thank you for your response.'
        : cleaned;
  }

  Future<void> _showAssignmentFeedback(String feedback) {
    final cleanFeedback = _cleanAssignmentFeedback(feedback);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assignment Feedback'),
        content: SingleChildScrollView(child: Text(cleanFeedback)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  bool _validateQuizAnswers() {
    return widget.slides[_currentIndex].questions.every(
      (question) => _selectedAnswers.containsKey(question.id),
    );
  }

  void _loadCurrentSlideState() {
    _selectedAnswers.clear();
    if (_currentSlide.type == SlideType.quiz) {
      final attempt = _courseProgress.quizAttempts[_currentSlide.id];
      if (attempt != null) {
        _selectedAnswers.addAll(attempt.answers);
        _quizResultVisible.add(_currentSlide.id);
      }
    }
    if (_currentSlide.type == SlideType.assignment) {
      _assignmentController.text =
          _courseProgress.assignmentAnswers[_currentSlide.id] ?? '';
    } else {
      _assignmentController.clear();
    }
  }

  int _resolveInitialIndex() {
    final requestedSlideId = widget.initialSlideId;
    if (requestedSlideId != null && requestedSlideId.isNotEmpty) {
      final requestedIndex = widget.slides.indexWhere(
        (slide) => slide.id == requestedSlideId,
      );
      if (requestedIndex >= 0) return requestedIndex;
    }

    final savedSlideId = _courseProgress.currentSlideId;
    if (savedSlideId != null && savedSlideId.isNotEmpty) {
      final savedIndex = widget.slides.indexWhere(
        (slide) => slide.id == savedSlideId,
      );
      if (savedIndex >= 0) return savedIndex;
    }

    final savedIndex = _courseProgress.currentSlideIndex;
    if (savedIndex >= 0 && savedIndex < widget.slides.length) {
      return savedIndex;
    }

    final firstIncompleteIndex = widget.slides.indexWhere(
      (slide) => !_courseProgress.completedSlideIds.contains(slide.id),
    );
    return firstIncompleteIndex >= 0 ? firstIncompleteIndex : 0;
  }

  Future<void> _saveCurrentLocation() async {
    if (widget.slides.isEmpty) return;
    final updatedProgress = _courseProgress.copyWith(
      currentSlideId: _currentSlide.id,
      currentSlideIndex: _currentIndex,
    );
    _courseProgress = updatedProgress;
    widget.onProgressUpdated(updatedProgress);
    await _firestore.collection('courseProgress').doc(updatedProgress.id).set({
      'currentSlideId': _currentSlide.id,
      'currentSlideIndex': _currentIndex,
      'lastAccessedAt': DateTime.now(),
    }, SetOptions(merge: true));
  }

  Future<void> _openFinalQuiz() async {
    if (widget.finalQuiz == null) return;
    final attempt = await Navigator.push<QuizAttempt>(
      context,
      MaterialPageRoute(
        builder: (context) => CHWFinalQuizScreen(
          quiz: widget.finalQuiz!,
          course: widget.course,
          courseProgress: _courseProgress,
        ),
      ),
    );

    if (attempt == null) return;

    final updatedProgress = _courseProgress.copyWith(
      quizAttempts: {..._courseProgress.quizAttempts, attempt.quizId: attempt},
    );

    await _firestore
        .collection('courseProgress')
        .doc(updatedProgress.id)
        .update(updatedProgress.toMap());

    _courseProgress = updatedProgress;
    widget.onProgressUpdated(updatedProgress);

    if (attempt.passed) {
      await _finishCourse(updatedProgress, attempt.score, true);
    }
  }

  Future<void> _finishCourse(
    CourseProgress progress,
    int score,
    bool passed,
  ) async {
    final updatedProgress = progress.copyWith(
      courseCompleted: passed,
      completedAt: DateTime.now(),
      progressPercentage: 100,
    );
    await _firestore
        .collection('courseProgress')
        .doc(updatedProgress.id)
        .update(updatedProgress.toMap());

    _courseProgress = updatedProgress;
    widget.onProgressUpdated(updatedProgress);

    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Course Completed'),
          content: Text(
            'Congratulations! You have completed ${widget.course.title}.\nYour score: $score%.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    }
  }
}

class CHWFinalQuizScreen extends StatefulWidget {
  final Quiz quiz;
  final Course course;
  final CourseProgress courseProgress;
  final bool isAdminPreview;

  const CHWFinalQuizScreen({
    super.key,
    required this.quiz,
    required this.course,
    required this.courseProgress,
    this.isAdminPreview = false,
  });

  @override
  State<CHWFinalQuizScreen> createState() => _CHWFinalQuizScreenState();
}

class _CHWFinalQuizScreenState extends State<CHWFinalQuizScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _answers = {};
  late CourseProgress _courseProgress;
  QuizAttempt? _lastAttempt;
  bool _resultVisible = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _courseProgress = widget.courseProgress;
    _lastAttempt = _courseProgress.quizAttempts[widget.quiz.id];
    if (_lastAttempt != null) {
      _answers.addAll(_lastAttempt!.answers);
      _resultVisible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Final Quiz'),
        backgroundColor: Colors.teal,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.quiz.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            widget.quiz.description,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal.shade100),
            ),
            child: Text(
              _resultVisible && _lastAttempt != null
                  ? 'Score: ${_lastAttempt!.score}%. ${_lastAttempt!.passed ? 'Passed' : 'You need ${widget.quiz.passingScore}% to pass. You can try again.'}'
                  : 'You need ${widget.quiz.passingScore}% to pass. You have unlimited attempts.',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 20),
          ...widget.quiz.questions.map((question) {
            final selectedValue = _answers[question.id];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.questionText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...question.options.map((option) {
                      final isSelected = selectedValue == option;
                      final isCorrect = question.correctAnswer == option;
                      final showCorrect = _resultVisible && isCorrect;
                      final showWrong =
                          _resultVisible && isSelected && !isCorrect;
                      return RadioListTile<String>(
                        title: Text(option),
                        subtitle: showCorrect || showWrong
                            ? Text(
                                showCorrect ? 'Correct answer' : 'Your answer',
                                style: TextStyle(
                                  color: showCorrect
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                        secondary: showCorrect || showWrong
                            ? Icon(
                                showCorrect ? Icons.check_circle : Icons.cancel,
                                color: showCorrect ? Colors.green : Colors.red,
                              )
                            : null,
                        value: option,
                        groupValue: selectedValue,
                        onChanged:
                            _lastAttempt?.passed == true || _resultVisible
                            ? null
                            : (value) {
                                setState(() {
                                  if (value != null) {
                                    _answers[question.id] = value;
                                    _resultVisible = false;
                                  }
                                });
                              },
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
          if (_resultVisible && _lastAttempt?.passed != true) ...[
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _retakeFinalQuiz,
              icon: const Icon(Icons.refresh),
              label: const Text('Retake Final Quiz'),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitting
                ? null
                : (_resultVisible && _lastAttempt?.passed != true)
                ? _retakeFinalQuiz
                : _submitFinalQuiz,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _submitting
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    widget.isAdminPreview
                        ? 'Close Preview'
                        : _resultVisible && _lastAttempt?.passed != true
                        ? 'Retake Final Quiz'
                        : _lastAttempt?.passed == true && _resultVisible
                        ? 'Finish Course'
                        : 'Submit Final Quiz',
                  ),
          ),
        ],
      ),
    );
  }

  bool _validateAnswers() {
    return widget.quiz.questions.every(
      (question) => _answers.containsKey(question.id),
    );
  }

  Future<void> _submitFinalQuiz() async {
    if (widget.isAdminPreview) {
      Navigator.pop(context);
      return;
    }

    if (_lastAttempt?.passed == true && _resultVisible) {
      Navigator.pop(context, _lastAttempt);
      return;
    }

    if (_resultVisible && _lastAttempt?.passed != true) {
      await _retakeFinalQuiz();
      return;
    }

    if (!_validateAnswers()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    final totalPoints = widget.quiz.questions.fold<int>(
      0,
      (sum, question) => sum + question.points,
    );
    final earnedPoints = widget.quiz.questions.fold<int>(
      0,
      (sum, question) =>
          sum +
          (question.correctAnswer == _answers[question.id]
              ? question.points
              : 0),
    );
    final score = totalPoints == 0
        ? 0
        : ((earnedPoints / totalPoints) * 100).round();
    final passed = score >= widget.quiz.passingScore;

    final attempt = QuizAttempt(
      quizId: widget.quiz.id,
      answers: Map<String, String>.from(_answers),
      score: score,
      totalPoints: totalPoints,
      earnedPoints: earnedPoints,
      passed: passed,
      attemptedAt: DateTime.now(),
      durationSeconds: 0,
      feedback: passed
          ? 'Great work! You passed the final quiz.'
          : 'Review the course and try the final quiz again.',
    );

    final updatedProgress = _courseProgress.copyWith(
      quizAttempts: {..._courseProgress.quizAttempts, widget.quiz.id: attempt},
    );
    await _firestore
        .collection('courseProgress')
        .doc(updatedProgress.id)
        .update(updatedProgress.toMap());

    if (!mounted) return;
    setState(() {
      _courseProgress = updatedProgress;
      _lastAttempt = attempt;
      _resultVisible = true;
      _submitting = false;
    });

    if (!passed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You scored $score%. You need at least ${widget.quiz.passingScore}% to pass.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
  }

  Future<void> _retakeFinalQuiz() async {
    setState(() => _submitting = true);
    try {
      final quizAttempts = Map<String, QuizAttempt>.from(
        _courseProgress.quizAttempts,
      )..remove(widget.quiz.id);
      final updatedProgress = _courseProgress.copyWith(
        quizAttempts: quizAttempts,
      );
      await _firestore
          .collection('courseProgress')
          .doc(updatedProgress.id)
          .update(updatedProgress.toMap());
      if (!mounted) return;
      setState(() {
        _courseProgress = updatedProgress;
        _lastAttempt = null;
        _resultVisible = false;
        _answers.clear();
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error resetting quiz: $e')));
    }
  }
}
