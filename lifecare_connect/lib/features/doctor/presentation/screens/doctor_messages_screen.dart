import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class DoctorMessagesScreen extends StatefulWidget {
  const DoctorMessagesScreen({super.key});

  @override
  State<DoctorMessagesScreen> createState() => _DoctorMessagesScreenState();
}

class _DoctorMessagesScreenState extends State<DoctorMessagesScreen>
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
        title: const Text("Doctor Messages"),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showComposeDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickActionCard(
                    'Broadcast',
                    Icons.campaign,
                    Colors.orange,
                    () => _tabController.animateTo(0),
                  ),
                  const SizedBox(width: 12),
                  _buildQuickActionCard(
                    'CHWs',
                    Icons.health_and_safety,
                    Colors.teal,
                    () => _tabController.animateTo(1),
                  ),
                  const SizedBox(width: 12),
                  _buildQuickActionCard(
                    'Patients',
                    Icons.people,
                    Colors.green,
                    () => _tabController.animateTo(2),
                  ),
                  const SizedBox(width: 12),
                  _buildQuickActionCard(
                    'Facilities',
                    Icons.business,
                    Colors.purple,
                    () => _tabController.animateTo(3),
                  ),
                ],
              ),
            ),
          ),

          Container(
            color: Colors.indigo.shade700,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.campaign), text: "Broadcast"),
                Tab(icon: Icon(Icons.health_and_safety), text: "CHWs"),
                Tab(icon: Icon(Icons.people), text: "Patients"),
                Tab(icon: Icon(Icons.business), text: "Facilities"),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                DoctorMessagesTab(
                  currentUserId: currentUserId,
                  messageType: 'broadcast',
                  targetRole: 'all',
                ),
                DoctorMessagesTab(
                  currentUserId: currentUserId,
                  messageType: 'direct',
                  targetRole: 'chw',
                ),
                DoctorMessagesTab(
                  currentUserId: currentUserId,
                  messageType: 'direct',
                  targetRole: 'patient',
                ),
                DoctorMessagesTab(
                  currentUserId: currentUserId,
                  messageType: 'direct',
                  targetRole: 'facility',
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

  void _showComposeDialog(BuildContext context) {
    final messageController = TextEditingController();
    final subjectController = TextEditingController();
    String selectedType = 'broadcast';
    String selectedTarget = 'all';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Compose Message'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Message Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'broadcast',
                      child: Text('Broadcast'),
                    ),
                    DropdownMenuItem(
                      value: 'direct',
                      child: Text('Direct Message'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedType = value!;
                      if (selectedType == 'broadcast') {
                        selectedTarget = 'all';
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (selectedType == 'direct')
                  DropdownButtonFormField<String>(
                    initialValue: selectedTarget,
                    decoration: const InputDecoration(labelText: 'Send To'),
                    items: const [
                      DropdownMenuItem(value: 'chw', child: Text('CHWs')),
                      DropdownMenuItem(
                        value: 'patient',
                        child: Text('Patients'),
                      ),
                      DropdownMenuItem(
                        value: 'facility',
                        child: Text('Facilities'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedTarget = value!;
                      });
                    },
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _sendMessage(
                context,
                selectedType,
                selectedTarget,
                subjectController.text,
                messageController.text,
              ),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage(
    BuildContext context,
    String type,
    String target,
    String subject,
    String message,
  ) async {
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': currentUserId,
        'senderRole': 'doctor',
        'type': type,
        'targetRole': target,
        'subject': subject,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'priority': 'normal',
      });

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }
}

class DoctorMessagesTab extends StatelessWidget {
  final String currentUserId;
  final String messageType;
  final String targetRole;

  const DoctorMessagesTab({
    super.key,
    required this.currentUserId,
    required this.messageType,
    required this.targetRole,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getMessagesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildMessageCard(data, doc.id);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getMessagesStream() {
    Query query = FirebaseFirestore.instance
        .collection('messages')
        .where('type', isEqualTo: messageType);

    if (messageType == 'direct') {
      query = query.where('targetRole', isEqualTo: targetRole);
    }

    return query.orderBy('timestamp', descending: true).snapshots();
  }

  Widget _buildEmptyState() {
    String emptyMessage;
    IconData emptyIcon;

    switch (targetRole) {
      case 'chw':
        emptyMessage = 'No messages with CHWs';
        emptyIcon = Icons.health_and_safety;
        break;
      case 'patient':
        emptyMessage = 'No messages with patients';
        emptyIcon = Icons.people;
        break;
      case 'facility':
        emptyMessage = 'No messages with facilities';
        emptyIcon = Icons.business;
        break;
      default:
        emptyMessage = 'No broadcast messages';
        emptyIcon = Icons.campaign;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(emptyIcon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            emptyMessage,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Messages will appear here',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> data, String messageId) {
    final subject = data['subject'] ?? 'No Subject';
    final message = data['message'] ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final senderRole = data['senderRole'] ?? 'unknown';
    final isRead = data['isRead'] ?? false;
    final senderId = data['senderId'] ?? '';
    final priority = data['priority'] ?? 'normal';

    final isOutgoing = senderId == currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 1 : 3,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(senderRole),
          child: Icon(_getRoleIcon(senderRole), color: Colors.white, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                subject,
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
            if (priority == 'high')
              const Icon(Icons.priority_high, color: Colors.red, size: 16),
            if (isOutgoing)
              const Icon(Icons.send, color: Colors.blue, size: 16),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${isOutgoing ? 'To' : 'From'}: ${_formatSenderRole(senderRole)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const Spacer(),
                if (timestamp != null)
                  Text(
                    _formatTimestamp(timestamp.toDate()),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () => _showMessageDetails(data, messageId),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.deepPurple;
      case 'doctor':
        return Colors.indigo;
      case 'chw':
        return Colors.teal;
      case 'patient':
        return Colors.green;
      case 'facility':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'doctor':
        return Icons.local_hospital;
      case 'chw':
        return Icons.health_and_safety;
      case 'patient':
        return Icons.person;
      case 'facility':
        return Icons.business;
      default:
        return Icons.person;
    }
  }

  String _formatSenderRole(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'doctor':
        return 'Doctor';
      case 'chw':
        return 'CHW';
      case 'patient':
        return 'Patient';
      case 'facility':
        return 'Facility';
      default:
        return role.toUpperCase();
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

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

  void _showMessageDetails(Map<String, dynamic> data, String messageId) {}
}
