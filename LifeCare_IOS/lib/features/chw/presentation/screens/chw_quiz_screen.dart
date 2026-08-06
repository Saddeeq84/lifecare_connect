// ignore_for_file: prefer_const_constructors, avoid_print, avoid_function_literals_in_foreach_calls

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/course_model.dart';

class CHWQuizScreen extends StatefulWidget {
  final Quiz quiz;
  final String courseId;
  final CourseProgress courseProgress;
  final void Function(CourseProgress) onQuizCompleted;

  const CHWQuizScreen({
    super.key,
    required this.quiz,
    required this.courseId,
    required this.courseProgress,
    required this.onQuizCompleted,
  });

  @override
  State<CHWQuizScreen> createState() => _CHWQuizScreenState();
}

class _CHWQuizScreenState extends State<CHWQuizScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _answers = {};
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz'), backgroundColor: Colors.teal),
      body: widget.quiz.questions.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.quiz_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This quiz has no questions yet.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.quiz.questions.length + 1,
              itemBuilder: (context, index) {
                if (index == widget.quiz.questions.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _submitting ? null : _submitQuiz,
                        child: _submitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Submit Quiz',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  );
                }

                final question = widget.quiz.questions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Question ${index + 1}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          question.questionText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...question.options.map((option) {
                          final selectedAnswer = _answers[question.id];
                          final isSelected = selectedAnswer == option;
                          final isCorrect = question.correctAnswer == option;
                          return RadioListTile<String>(
                            value: option,
                            groupValue: selectedAnswer,
                            title: Text(option),
                            subtitle: isSelected
                                ? Text(
                                    isCorrect
                                        ? 'Correct answer'
                                        : 'Wrong answer',
                                    style: TextStyle(
                                      color: isCorrect
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                            secondary: isSelected
                                ? Icon(
                                    isCorrect
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: isCorrect
                                        ? Colors.green
                                        : Colors.red,
                                  )
                                : null,
                            onChanged: (value) {
                              setState(() {
                                if (value != null) {
                                  _answers[question.id] = value;
                                }
                              });
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _submitQuiz() async {
    if (_answers.length < widget.quiz.questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all quiz questions.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
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

      final newAttempt = QuizAttempt(
        quizId: widget.quiz.id,
        answers: Map<String, String>.from(_answers),
        score: score,
        totalPoints: totalPoints,
        earnedPoints: earnedPoints,
        passed: passed,
        attemptedAt: DateTime.now(),
        durationSeconds: 0,
        feedback: passed
            ? 'Great work! You passed the quiz.'
            : 'You did not pass. Review the course and try again.',
      );

      final updatedProgress = widget.courseProgress.copyWith(
        quizAttempts: {
          ...widget.courseProgress.quizAttempts,
          widget.quiz.id: newAttempt,
        },
      );

      await _firestore
          .collection('courseProgress')
          .doc(updatedProgress.id)
          .update(updatedProgress.toMap());

      if (passed) {
        final completedProgress = updatedProgress.copyWith(
          courseCompleted: true,
          completedAt: DateTime.now(),
        );
        await _firestore
            .collection('courseProgress')
            .doc(completedProgress.id)
            .update({'courseCompleted': true, 'completedAt': DateTime.now()});

        widget.onQuizCompleted(completedProgress);
      } else {
        widget.onQuizCompleted(updatedProgress);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              passed
                  ? 'Quiz completed. You scored $score% and passed!'
                  : 'Quiz completed. You scored $score%. Try again to improve.',
            ),
            backgroundColor: passed ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting quiz: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}
