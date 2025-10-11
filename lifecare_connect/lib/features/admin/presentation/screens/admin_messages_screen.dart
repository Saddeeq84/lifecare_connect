// ignore_for_file: deprecated_member_use, prefer_const_constructors, no_leading_underscores_for_local_identifiers, unnecessary_import, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/admin_individual_messages_tab.dart';

class AdminMessagesScreen extends StatefulWidget {
  final String adminUserId;
  const AdminMessagesScreen({super.key, required this.adminUserId});

  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        leading: Icon(Icons.message),
      ),
      body: Column(
        children: [
          // Quick Action Cards
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    'Broadcast',
                    Icons.campaign,
                    Colors.orange,
                    () => _tabController.animateTo(0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    'Doctors',
                    Icons.local_hospital,
                    Colors.blue,
                    () => _tabController.animateTo(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    'CHWs',
                    Icons.health_and_safety,
                    Colors.teal,
                    () => _tabController.animateTo(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    'Patients',
                    Icons.people,
                    Colors.green,
                    () => _tabController.animateTo(3),
                  ),
                ),
              ],
            ),
          ),
          // Tab Bar
          Container(
            color: Colors.deepPurple.shade700,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.campaign), text: "Broadcast"),
                Tab(icon: Icon(Icons.local_hospital), text: "Doctors"),
                Tab(icon: Icon(Icons.health_and_safety), text: "CHWs"),
                Tab(icon: Icon(Icons.people), text: "Patients"),
                Tab(icon: Icon(Icons.business), text: "Facilities"),
              ],
            ),
          ),
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AdminBroadcastMessagesTab(adminUserId: widget.adminUserId),
                AdminIndividualMessagesTab(
                  role: 'doctor',
                  adminUserId: widget.adminUserId,
                ),
                AdminIndividualMessagesTab(
                  role: 'chw',
                  adminUserId: widget.adminUserId,
                ),
                AdminIndividualMessagesTab(
                  role: 'patient',
                  adminUserId: widget.adminUserId,
                ),
                AdminIndividualMessagesTab(
                  role: 'facility',
                  adminUserId: widget.adminUserId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminBroadcastMessagesTab extends StatelessWidget {
  final String adminUserId;
  const _AdminBroadcastMessagesTab({required this.adminUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('type', isEqualTo: 'broadcast')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No broadcast messages yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  'Important announcements will appear here',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: const Icon(Icons.campaign, color: Colors.orange),
                ),
                title: Text(
                  data['subject'] ?? 'No Subject',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      data['message'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From: Admin • ${_formatTimestamp(data['timestamp'])}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                isThreeLine: true,
                // onTap: () => _openMessage(context, doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
