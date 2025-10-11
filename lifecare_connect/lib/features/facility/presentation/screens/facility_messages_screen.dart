// ignore_for_file: sort_child_properties_last, prefer_const_declarations, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:lifecare_connect/features/shared/data/services/message_service.dart';

// Top-level dialog function for user selection (only one definition)
void showUserSelectionDialog(BuildContext context, String role) {
  TextEditingController searchController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Select ${role[0].toUpperCase()}${role.substring(1)}'),
            content: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search $role...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: role)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final users = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['fullName'] ?? data['name'] ?? '')
                            .toString()
                            .toLowerCase();
                        final email = (data['email'] ?? '')
                            .toString()
                            .toLowerCase();
                        final query = searchController.text.toLowerCase();
                        return name.contains(query) || email.contains(query);
                      }).toList();
                      if (users.isEmpty) {
                        return const Text('No users found');
                      }
                      return SizedBox(
                        height: 250,
                        child: ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user =
                                users[index].data() as Map<String, dynamic>;
                            final userId = users[index].id;
                            final userName =
                                user['fullName'] ?? user['name'] ?? 'Unknown';
                            final userEmail = user['email'] ?? '';
                            return ListTile(
                              leading: CircleAvatar(child: Text(userName[0])),
                              title: Text(userName),
                              subtitle: Text(userEmail),
                              onTap: () async {
                                Navigator.pop(context);
                                final facilityId =
                                    FirebaseAuth.instance.currentUser?.uid ??
                                    '';
                                final facilityName = 'Facility';
                                if (role == 'patient') {
                                  // Create conversation in 'conversations' with correct patient info
                                  final conversationDoc =
                                      await FirebaseFirestore.instance
                                          .collection('conversations')
                                          .add({
                                            'participants': [
                                              facilityId,
                                              userId,
                                            ],
                                            'type': 'patient_facility',
                                            'patientId': userId,
                                            'patientName': userName,
                                            'facilityId': facilityId,
                                            'facilityName': facilityName,
                                            'lastMessage': '',
                                            'lastMessageTime':
                                                FieldValue.serverTimestamp(),
                                          });
                                  if (context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            FacilityConversationScreen(
                                              conversationId:
                                                  conversationDoc.id,
                                              conversationData: {
                                                'participantNames': {
                                                  facilityId: facilityName,
                                                  userId: userName,
                                                },
                                                'type': 'patient_facility',
                                                'patientName': userName,
                                              },
                                              currentUserId: facilityId,
                                            ),
                                      ),
                                    );
                                  }
                                } else {
                                  // ...existing code for doctor/chw...
                                  final conversationId =
                                      await MessageService.createOrGetConversation(
                                        user1Id: facilityId,
                                        user1Name: facilityName,
                                        user1Role: 'facility',
                                        user2Id: userId,
                                        user2Name: userName,
                                        user2Role: role,
                                        title: 'Private Chat',
                                        type: 'direct',
                                      );
                                  if (context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            FacilityConversationScreen(
                                              conversationId: conversationId,
                                              conversationData: {
                                                'participantNames': {
                                                  facilityId: facilityName,
                                                  userId: userName,
                                                },
                                                'type': 'direct',
                                              },
                                              currentUserId: facilityId,
                                            ),
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    },
  );
}

class FacilityMessagesScreen extends StatefulWidget {
  const FacilityMessagesScreen({super.key});

  @override
  State<FacilityMessagesScreen> createState() => _FacilityMessagesScreenState();
}

class _FacilityMessagesScreenState extends State<FacilityMessagesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

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
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showNewMessageDialog(context),
          ),
        ],
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
            color: Colors.purple.shade700,
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
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                FacilityBroadcastMessagesTab(currentUserId: currentUserId),
                FacilityDoctorMessagesTab(currentUserId: currentUserId),
                FacilityCHWMessagesTab(currentUserId: currentUserId),
                FacilityPatientMessagesTab(currentUserId: currentUserId),
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

  void _showNewMessageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Message'),
        content: const Text(
          'Select a tab to compose a new message to the specific group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Facility Broadcast Messages Tab
class FacilityBroadcastMessagesTab extends StatelessWidget {
  final String currentUserId;

  const FacilityBroadcastMessagesTab({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where(
            'type',
            whereIn: ['broadcast', 'broadcast_message', 'personal_message'],
          )
          .orderBy('createdAt', descending: true)
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

        // Manual filter for receiverId or participants
        final filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final receiverId = data['receiverId'];
          final participants = data['participants'] as List<dynamic>?;
          return receiverId == currentUserId ||
              (participants != null && participants.contains(currentUserId));
        }).toList();

        if (filteredDocs.isEmpty) {
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
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
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
                  _getPersonalizedSubject(data, currentUserId),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      _getBroadcastContent(data, currentUserId),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by admin • ${_formatTimestamp(data['timestamp'])}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                isThreeLine: true,
                onTap: () => _openMessage(context, doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  String _getBroadcastContent(Map<String, dynamic> data, String userId) {
    // Prefer 'message', fallback to 'content', fallback to 'content' for older messages
    String message = data['message'] ?? '';
    if (message.isEmpty && data['content'] != null) {
      message = data['content'];
    }
    if (message.isEmpty && data['content'] == null && data['content'] != null) {
      message = data['content'];
    }
    String userName =
        data['recipientNames'] != null && data['recipientNames'][userId] != null
        ? data['recipientNames'][userId]
        : '';
    if (userName.isNotEmpty) {
      message = message.replaceAll('{name}', userName);
    }
    return message.isNotEmpty
        ? message
        : (data['content'] ?? 'No message content');
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

  void _openMessage(
    BuildContext context,
    String messageId,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityMessageDetailScreen(
          messageId: messageId,
          messageData: data,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  String _getPersonalizedSubject(Map<String, dynamic> data, String userId) {
    // If subject contains a placeholder for name, replace it
    String subject = data['subject'] ?? 'No Subject';
    String userName =
        data['recipientNames'] != null && data['recipientNames'][userId] != null
        ? data['recipientNames'][userId]
        : '';
    if (userName.isNotEmpty) {
      subject = subject.replaceAll('{name}', userName);
    }
    return subject;
  }
}

// Facility Doctor Messages Tab
class FacilityDoctorMessagesTab extends StatelessWidget {
  final String currentUserId;

  const FacilityDoctorMessagesTab({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('participants', arrayContains: currentUserId)
          .where('type', isEqualTo: 'doctor_facility')
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_hospital, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No doctor conversations yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Messages with doctors will appear here',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New Message'),
                  onPressed: () => _showDoctorSelectionDialog(context),
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
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.local_hospital, color: Colors.blue),
                ),
                title: Text(
                  data['doctorName'] ?? 'Doctor',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      data['lastMessage'] ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(data['lastMessageTime']),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: data['unreadCount'] != null && data['unreadCount'] > 0
                    ? CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Text(
                          '${data['unreadCount']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
                isThreeLine: true,
                onTap: () => _openConversation(context, doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No messages';
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

  void _showDoctorSelectionDialog(BuildContext context) {
    showUserSelectionDialog(context, 'doctor');
  }

  void _openConversation(
    BuildContext context,
    String conversationId,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityConversationScreen(
          conversationId: conversationId,
          conversationData: data,
          currentUserId: currentUserId,
        ),
      ),
    );
  }
}

// Facility CHW Messages Tab
class FacilityCHWMessagesTab extends StatelessWidget {
  final String currentUserId;

  const FacilityCHWMessagesTab({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('participants', arrayContains: currentUserId)
          .where('type', isEqualTo: 'chw_facility')
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.health_and_safety,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No CHW conversations yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Messages with Community Health Workers will appear here',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New Message'),
                  onPressed: () => _showCHWSelectionDialog(context),
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
                  backgroundColor: Colors.teal.shade100,
                  child: const Icon(
                    Icons.health_and_safety,
                    color: Colors.teal,
                  ),
                ),
                title: Text(
                  data['chwName'] ?? 'CHW',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      data['lastMessage'] ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(data['lastMessageTime']),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: data['unreadCount'] != null && data['unreadCount'] > 0
                    ? CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Text(
                          '${data['unreadCount']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
                isThreeLine: true,
                onTap: () => _openConversation(context, doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No messages';
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

  void _showCHWSelectionDialog(BuildContext context) {
    showUserSelectionDialog(context, 'chw');
  }

  void _openConversation(
    BuildContext context,
    String conversationId,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityConversationScreen(
          conversationId: conversationId,
          conversationData: data,
          currentUserId: currentUserId,
        ),
      ),
    );
  }
}

// Facility Patient Messages Tab
class FacilityPatientMessagesTab extends StatelessWidget {
  final String currentUserId;

  const FacilityPatientMessagesTab({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .where('type', isEqualTo: 'patient_facility')
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No patient conversations yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Messages with patients will appear here',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New Message'),
                  onPressed: () => _showPatientSelectionDialog(context),
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
                  backgroundColor: Colors.green.shade100,
                  child: const Icon(Icons.person, color: Colors.green),
                ),
                title: Text(
                  data['patientName'] ?? 'Patient',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      data['lastMessage'] ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(data['lastMessageTime']),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: data['unreadCount'] != null && data['unreadCount'] > 0
                    ? CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Text(
                          '${data['unreadCount']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
                isThreeLine: true,
                onTap: () => _openConversation(context, doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No messages';
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

  void _showPatientSelectionDialog(BuildContext context) {
    showUserSelectionDialog(context, 'patient');
  }

  void _openConversation(
    BuildContext context,
    String conversationId,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityConversationScreen(
          conversationId: conversationId,
          conversationData: data,
          currentUserId: currentUserId,
        ),
      ),
    );
  }
}

// Facility Message Detail Screen for broadcast messages
class FacilityMessageDetailScreen extends StatefulWidget {
  final String messageId;
  final Map<String, dynamic> messageData;
  final String currentUserId;

  const FacilityMessageDetailScreen({
    super.key,
    required this.messageId,
    required this.messageData,
    required this.currentUserId,
  });

  @override
  State<FacilityMessageDetailScreen> createState() =>
      _FacilityMessageDetailScreenState();
}

class _FacilityMessageDetailScreenState
    extends State<FacilityMessageDetailScreen> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.messageData['subject'] ?? 'Message'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Original Message
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.orange.shade100,
                                child: const Icon(
                                  Icons.admin_panel_settings,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Admin',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _formatTimestamp(
                                        widget.messageData['timestamp'],
                                      ),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.messageData['subject'] ?? 'No Subject',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            (widget.messageData['message'] ?? '').isNotEmpty
                                ? widget.messageData['message']
                                : (widget.messageData['content'] ??
                                      'No message content'),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Replies Section
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('messages')
                        .doc(widget.messageId)
                        .collection('replies')
                        .orderBy('timestamp', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Replies',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...snapshot.data!.docs.map((doc) {
                            final replyData =
                                doc.data() as Map<String, dynamic>;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor:
                                              Colors.purple.shade100,
                                          child: const Icon(
                                            Icons.business,
                                            size: 16,
                                            color: Colors.purple,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          replyData['senderName'] ?? 'Facility',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatTimestamp(
                                            replyData['timestamp'],
                                          ),
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(replyData['message'] ?? ''),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Reply Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: InputDecoration(
                      hintText: 'Type your reply...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.purple,
                  child: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendReply,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _sendReply() {
    if (_replyController.text.trim().isEmpty) return;

    FirebaseFirestore.instance
        .collection('messages')
        .doc(widget.messageId)
        .collection('replies')
        .add({
          'message': _replyController.text.trim(),
          'senderId': widget.currentUserId,
          'senderName':
              'Facility User', // You might want to get this from user profile
          'timestamp': FieldValue.serverTimestamp(),
        });

    _replyController.clear();

    // Scroll to bottom to show new reply
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }
}

// Facility Conversation Screen for direct messages
class FacilityConversationScreen extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic> conversationData;
  final String currentUserId;

  const FacilityConversationScreen({
    super.key,
    required this.conversationId,
    required this.conversationData,
    required this.currentUserId,
  });

  @override
  State<FacilityConversationScreen> createState() =>
      _FacilityConversationScreenState();
}

class _FacilityConversationScreenState
    extends State<FacilityConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getConversationTitle()),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(widget.conversationId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isCurrentUser =
                        data['senderId'] == widget.currentUserId;

                    return Align(
                      alignment: isCurrentUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrentUser
                              ? Colors.purple
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data['message'] ?? '',
                              style: TextStyle(
                                color: isCurrentUser
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(data['timestamp']),
                              style: TextStyle(
                                fontSize: 10,
                                color: isCurrentUser
                                    ? Colors.white70
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.purple,
                  child: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getConversationTitle() {
    final type = widget.conversationData['type'] ?? '';
    switch (type) {
      case 'doctor_facility':
        return widget.conversationData['doctorName'] ?? 'Doctor';
      case 'chw_facility':
        return widget.conversationData['chwName'] ?? 'CHW';
      case 'patient_facility':
        return widget.conversationData['patientName'] ?? 'Patient';
      default:
        return 'Conversation';
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (now.difference(date).inDays == 0) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    // Add message to conversation
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .add({
          'message': message,
          'senderId': widget.currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });

    // Update conversation metadata
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .update({
          'lastMessage': message,
          'lastMessageTime': FieldValue.serverTimestamp(),
        });

    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }
}
