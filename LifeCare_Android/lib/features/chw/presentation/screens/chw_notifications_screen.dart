// ignore_for_file: prefer_const_constructors

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/course_model.dart';
import 'chw_course_details_screen.dart';

class CHWNotificationsScreen extends StatelessWidget {
  const CHWNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.teal,
        ),
        body: const Center(child: Text('Please log in to view notifications.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data?.docs.toList() ?? [];
          notifications.sort((a, b) {
            final aDate = _readDate(a.data()['createdAt']);
            final bDate = _readDate(b.data()['createdAt']);
            return (bDate ?? DateTime(0)).compareTo(aDate ?? DateTime(0));
          });

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text('No notifications yet'),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = notifications[index];
              return _NotificationTile(notification: doc);
            },
          );
        },
      ),
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class _NotificationTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final data = notification.data();
    final read = data['read'] == true;
    final title = data['title']?.toString() ?? 'Notification';
    final message = data['message']?.toString() ?? '';
    final createdAt = _readDate(data['createdAt']);

    return Card(
      elevation: read ? 0 : 2,
      color: read ? Colors.white : Colors.teal.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: read ? Colors.grey.shade200 : Colors.teal,
          child: Icon(
            _iconForType(data['type']?.toString()),
            color: read ? Colors.grey.shade700 : Colors.white,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: read ? FontWeight.w500 : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isNotEmpty) Text(message),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM d, yyyy • h:mm a').format(createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
        trailing: read
            ? const Icon(Icons.chevron_right)
            : const Icon(Icons.circle, color: Colors.teal, size: 12),
        onTap: () => _openNotification(context, data),
      ),
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    await notification.reference.set({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!context.mounted) return;
    if (data['type'] == 'assignment_comment') {
      await _openAssignmentComment(context, data);
    }
  }

  Future<void> _openAssignmentComment(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final courseId = data['courseId']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    final courseDoc = await FirebaseFirestore.instance
        .collection('courses')
        .doc(courseId)
        .get();
    if (!context.mounted) return;
    if (!courseDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course could not be found.')),
      );
      return;
    }

    final course = Course.fromFirestore(courseDoc);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CHWCourseDetailsScreen(
          course: course,
          initialSlideId: data['assignmentId']?.toString(),
        ),
      ),
    );
  }

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'assignment_comment':
        return Icons.assignment_turned_in;
      default:
        return Icons.notifications;
    }
  }
}
