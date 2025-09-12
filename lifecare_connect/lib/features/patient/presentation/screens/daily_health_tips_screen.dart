// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DailyHealthTipsScreen extends StatefulWidget {
  const DailyHealthTipsScreen({super.key});

  @override
  State<DailyHealthTipsScreen> createState() => _DailyHealthTipsScreenState();
}

class _DailyHealthTipsScreenState extends State<DailyHealthTipsScreen> {
  List<String> tips = [];
  Set<int> bookmarkedTips = {};
  bool notificationsEnabled = false;
  bool isLoading = true;
  String? error;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadTipsAndUserData();
  }

  Future<void> _loadTipsAndUserData() async {
    if (user == null) {
      setState(() {
        error = 'User not authenticated.';
        isLoading = false;
      });
      return;
    }

    try {
      final tipsSnapshot = await FirebaseFirestore.instance
          .collection('daily_tips')
          .orderBy('created_at', descending: false)
          .get();

      final loadedTips = tipsSnapshot.docs.map((doc) => doc['text'] as String).toList();

      final bookmarksSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid ?? '')
          .collection('bookmarked_tips')
          .get();

      final bookmarks = bookmarksSnapshot.docs.map((doc) => doc['index'] as int).toSet();

      final settingsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      final enabled = settingsSnapshot.data()?['settings']?['daily_tip_notifications'] ?? false;

      setState(() {
        tips = loadedTips;
        bookmarkedTips = bookmarks;
        notificationsEnabled = enabled;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load data: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _toggleBookmark(int index, String text) async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
  .doc(user?.uid ?? '')
        .collection('bookmarked_tips')
        .doc(index.toString());

    final isBookmarked = bookmarkedTips.contains(index);

    setState(() {
      if (isBookmarked) {
        bookmarkedTips.remove(index);
      } else {
        bookmarkedTips.add(index);
      }
    });

    if (isBookmarked) {
      await docRef.delete();
    } else {
      await docRef.set({
        'index': index,
        'text': text,
        'bookmarked_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _toggleNotification(bool value) async {
    setState(() {
      notificationsEnabled = value;
    });

    if (user?.uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set(
        {'settings': {'daily_tip_notifications': value}},
        SetOptions(merge: true),
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(value ? "Notifications enabled" : "Notifications disabled"),
        duration: const Duration(seconds: 1),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found. Cannot save health tips.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Center(child: Text(error!, style: const TextStyle(color: Colors.red)));
    }

    if (tips.isEmpty) {
      return const Center(child: Text("No health tips available at the moment."));
    }

    final tipOfTheDay = tips[DateTime.now().day % tips.length];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 🌞 Tip of the Day
        Card(
          color: Colors.green.shade100,
          child: ListTile(
            leading: Icon(Icons.wb_sunny_outlined, color: Colors.green.shade800),
            title: const Text('Tip of the Day'),
            subtitle: Text(tipOfTheDay),
          ),
        ),
        const SizedBox(height: 20),

        // 🔔 Notification Toggle
        SwitchListTile(
          title: const Text("Daily Tip Notifications"),
          subtitle: const Text("Receive a daily notification for new health tips."),
          secondary: const Icon(Icons.notifications_active_outlined, color: Colors.green),
          value: notificationsEnabled,
          onChanged: _toggleNotification,
        ),
        const SizedBox(height: 16),

        // 📋 All Tips
        Text("All Tips", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),

        ...List.generate(tips.length, (index) {
          final tip = tips[index];
          final isBookmarked = bookmarkedTips.contains(index);

          return Card(
            child: ListTile(
              leading: Icon(Icons.lightbulb_outline, color: Colors.green.shade700),
              title: Text('Tip #${index + 1}'),
              subtitle: Text(tip),
              trailing: IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                  color: isBookmarked ? Colors.green.shade800 : Colors.grey,
                ),
                onPressed: () => _toggleBookmark(index, tip),
                tooltip: isBookmarked ? 'Remove Bookmark' : 'Bookmark',
              ),
            ),
          );
        }),
      ],
    );
  }
}
