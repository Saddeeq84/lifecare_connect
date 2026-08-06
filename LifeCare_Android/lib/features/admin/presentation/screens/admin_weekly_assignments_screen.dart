// ignore_for_file: prefer_const_constructors

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminWeeklyAssignmentsScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const AdminWeeklyAssignmentsScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<AdminWeeklyAssignmentsScreen> createState() =>
      _AdminWeeklyAssignmentsScreenState();
}

class _AdminWeeklyAssignmentsScreenState
    extends State<AdminWeeklyAssignmentsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<_AssignmentReviewData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_AssignmentReviewData> _loadData() async {
    final assignmentSnapshot = await _firestore
        .collection('courseSlides')
        .where('courseId', isEqualTo: widget.courseId)
        .where('type', isEqualTo: 'assignment')
        .get();
    final progressSnapshot = await _firestore
        .collection('courseProgress')
        .where('courseId', isEqualTo: widget.courseId)
        .get();
    final usersSnapshot = await _firestore.collection('users').get();

    final assignments =
        assignmentSnapshot.docs.map((doc) {
          final data = doc.data();
          return _AssignmentInfo(
            id: doc.id,
            title: (data['title'] ?? 'Weekly Assignment').toString(),
            question:
                (data['assignmentQuestion'] ??
                        data['content'] ??
                        data['description'] ??
                        '')
                    .toString(),
            moduleTitle: (data['moduleTitle'] ?? 'Module').toString(),
            moduleOrderIndex: (data['moduleOrderIndex'] is num)
                ? (data['moduleOrderIndex'] as num).toInt()
                : 0,
            orderIndex: (data['orderIndex'] is num)
                ? (data['orderIndex'] as num).toInt()
                : 0,
          );
        }).toList()..sort((a, b) {
          final moduleCompare = a.moduleOrderIndex.compareTo(
            b.moduleOrderIndex,
          );
          if (moduleCompare != 0) return moduleCompare;
          return a.orderIndex.compareTo(b.orderIndex);
        });

    final usersById = <String, Map<String, dynamic>>{};
    for (final userDoc in usersSnapshot.docs) {
      usersById[userDoc.id] = userDoc.data();
    }

    final submissions = <_AssignmentSubmission>[];
    final assignmentsById = {for (final item in assignments) item.id: item};
    for (final progressDoc in progressSnapshot.docs) {
      final progress = progressDoc.data();
      final userId = progress['userId']?.toString() ?? '';
      final answers = progress['assignmentAnswers'];
      if (answers is! Map || answers.isEmpty) continue;

      final feedback = progress['assignmentFeedback'] is Map
          ? Map<String, dynamic>.from(progress['assignmentFeedback'] as Map)
          : <String, dynamic>{};
      final comments = progress['assignmentAdminComments'] is Map
          ? Map<String, dynamic>.from(
              progress['assignmentAdminComments'] as Map,
            )
          : <String, dynamic>{};

      for (final entry in answers.entries) {
        final assignmentId = entry.key.toString();
        final answer = entry.value?.toString().trim() ?? '';
        if (answer.isEmpty) continue;

        submissions.add(
          _AssignmentSubmission(
            progressId: progressDoc.id,
            userId: userId,
            learnerName: _displayUserName(usersById[userId] ?? {}, userId),
            assignment:
                assignmentsById[assignmentId] ??
                _AssignmentInfo(
                  id: assignmentId,
                  title: 'Weekly Assignment',
                  question: '',
                  moduleTitle: 'Module',
                  moduleOrderIndex: 0,
                  orderIndex: 0,
                ),
            answer: answer,
            aiFeedback: feedback[assignmentId]?.toString() ?? '',
            adminComment: comments[assignmentId]?.toString() ?? '',
            submittedAt:
                _readDate(progress['updatedAt']) ??
                _readDate(progress['startedAt']),
          ),
        );
      }
    }

    submissions.sort((a, b) {
      final moduleCompare = a.assignment.moduleOrderIndex.compareTo(
        b.assignment.moduleOrderIndex,
      );
      if (moduleCompare != 0) return moduleCompare;
      final assignmentCompare = a.assignment.orderIndex.compareTo(
        b.assignment.orderIndex,
      );
      if (assignmentCompare != 0) return assignmentCompare;
      return a.learnerName.toLowerCase().compareTo(b.learnerName.toLowerCase());
    });

    return _AssignmentReviewData(
      assignments: assignments,
      submissions: submissions,
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _displayUserName(Map<String, dynamic> user, String userId) {
    final fullName = (user['fullName'] ?? user['name'])?.toString();
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }
    final first = user['firstName']?.toString() ?? '';
    final last = user['lastName']?.toString() ?? '';
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;
    return userId.length > 8
        ? 'User ${userId.substring(0, 8)}'
        : 'Unknown User';
  }

  void _refresh() {
    setState(() => _dataFuture = _loadData());
  }

  Future<void> _editComment(_AssignmentSubmission submission) async {
    final controller = TextEditingController(text: submission.adminComment);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Comment for ${submission.learnerName}'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This comment is saved only for this learner and this assignment.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Comment for learner',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null) return;
    try {
      final progressRef = _firestore
          .collection('courseProgress')
          .doc(submission.progressId);
      final progressDoc = await progressRef.get();
      final data = progressDoc.data() ?? {};
      final comments = data['assignmentAdminComments'] is Map
          ? Map<String, dynamic>.from(data['assignmentAdminComments'] as Map)
          : <String, dynamic>{};
      final trimmedComment = result.trim();
      final previousComment = submission.adminComment.trim();
      if (trimmedComment.isEmpty) {
        comments.remove(submission.assignment.id);
      } else {
        comments[submission.assignment.id] = trimmedComment;
      }
      await progressRef.update({
        'assignmentAdminComments': comments,
        'assignmentAdminCommentsUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (trimmedComment.isNotEmpty && trimmedComment != previousComment) {
        await _notifyLearnerOfComment(submission, trimmedComment);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trimmedComment.isEmpty
                ? 'Comment cleared for learner.'
                : 'Comment saved and learner notified.',
          ),
        ),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save comment: $e')));
    }
  }

  Future<void> _notifyLearnerOfComment(
    _AssignmentSubmission submission,
    String comment,
  ) async {
    await _firestore.collection('notifications').add({
      'userId': submission.userId,
      'title': 'Assignment Comment Added',
      'message':
          'Facilitator commented on "${submission.assignment.title}" in ${widget.courseTitle}.',
      'type': 'assignment_comment',
      'courseId': widget.courseId,
      'courseTitle': widget.courseTitle,
      'assignmentId': submission.assignment.id,
      'assignmentTitle': submission.assignment.title,
      'progressId': submission.progressId,
      'commentPreview': comment.length > 140
          ? '${comment.substring(0, 140)}...'
          : comment,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Weekly Assignments'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<_AssignmentReviewData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data;
          if (data == null || data.assignments.isEmpty) {
            return const Center(
              child: Text('No weekly assignments have been added yet.'),
            );
          }
          if (data.submissions.isEmpty) {
            return const Center(
              child: Text('No weekly assignment submissions yet.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.courseTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.submissions.length} submitted assignment${data.submissions.length == 1 ? '' : 's'}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              ...data.submissions.map(_buildSubmissionCard),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubmissionCard(_AssignmentSubmission submission) {
    final submittedDate = submission.submittedAt == null
        ? null
        : DateFormat('MMM d, yyyy').format(submission.submittedAt!);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(child: Text(_initials(submission.learnerName))),
        title: Text(submission.learnerName),
        subtitle: Text(
          '${submission.assignment.moduleTitle} • ${submission.assignment.title}${submittedDate == null ? '' : ' • $submittedDate'}',
        ),
        trailing: Icon(
          submission.adminComment.trim().isEmpty
              ? Icons.mode_comment_outlined
              : Icons.check_circle,
          color: submission.adminComment.trim().isEmpty
              ? Colors.grey
              : Colors.teal,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (submission.assignment.question.trim().isNotEmpty) ...[
            _sectionTitle('Question'),
            Text(submission.assignment.question),
            const SizedBox(height: 12),
          ],
          _sectionTitle('Learner Answer'),
          Text(submission.answer, style: const TextStyle(height: 1.5)),
          if (submission.aiFeedback.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionTitle('AI Feedback'),
            Text(submission.aiFeedback, style: const TextStyle(height: 1.5)),
          ],
          const SizedBox(height: 12),
          _sectionTitle("Facilitator's Comment"),
          Text(
            submission.adminComment.trim().isEmpty
                ? 'No comment added yet.'
                : submission.adminComment,
            style: TextStyle(
              height: 1.5,
              color: submission.adminComment.trim().isEmpty
                  ? Colors.grey.shade700
                  : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _editComment(submission),
              icon: const Icon(Icons.edit_note),
              label: Text(
                submission.adminComment.trim().isEmpty
                    ? 'Add Comment'
                    : 'Edit Comment',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
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
}

class _AssignmentReviewData {
  final List<_AssignmentInfo> assignments;
  final List<_AssignmentSubmission> submissions;

  _AssignmentReviewData({required this.assignments, required this.submissions});
}

class _AssignmentInfo {
  final String id;
  final String title;
  final String question;
  final String moduleTitle;
  final int moduleOrderIndex;
  final int orderIndex;

  _AssignmentInfo({
    required this.id,
    required this.title,
    required this.question,
    required this.moduleTitle,
    required this.moduleOrderIndex,
    required this.orderIndex,
  });
}

class _AssignmentSubmission {
  final String progressId;
  final String userId;
  final String learnerName;
  final _AssignmentInfo assignment;
  final String answer;
  final String aiFeedback;
  final String adminComment;
  final DateTime? submittedAt;

  _AssignmentSubmission({
    required this.progressId,
    required this.userId,
    required this.learnerName,
    required this.assignment,
    required this.answer,
    required this.aiFeedback,
    required this.adminComment,
    required this.submittedAt,
  });
}
