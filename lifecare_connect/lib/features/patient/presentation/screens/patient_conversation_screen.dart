// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PatientConversationScreen extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic> conversationData;
  final String currentUserId;

  const PatientConversationScreen({
    super.key,
    required this.conversationId,
    required this.conversationData,
    required this.currentUserId,
  });

  @override
  State<PatientConversationScreen> createState() =>
      _PatientConversationScreenState();
}

class _PatientConversationScreenState extends State<PatientConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otherPartyName = _getOtherPartyName();
    final conversationType = widget.conversationData['type'] ?? '';
    final themeColor = _getThemeColor(conversationType);

    return Scaffold(
      appBar: AppBar(
        title: Text(otherPartyName),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .doc(widget.conversationId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
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
                        Icon(Icons.chat, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isMyMessage =
                        data['senderId'] == widget.currentUserId;

                    return _buildMessageBubble(data, isMyMessage, themeColor);
                  },
                );
              },
            ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
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
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: themeColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _isSending ? null : _sendMessage,
                  backgroundColor: themeColor,
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> data,
    bool isMyMessage,
    Color themeColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMyMessage
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: themeColor.withOpacity(0.2),
              child: Icon(
                _getIconForType(widget.conversationData['type']),
                size: 16,
                color: themeColor,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isMyMessage ? themeColor : Colors.grey.shade200,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMyMessage ? 16 : 4),
                bottomRight: Radius.circular(isMyMessage ? 4 : 16),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMyMessage && data['senderName'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      data['senderName'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                  ),
                Text(
                  data['message'] ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    color: isMyMessage ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(data['timestamp']),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMyMessage
                        ? Colors.white.withOpacity(0.8)
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (isMyMessage) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green.withOpacity(0.2),
              child: const Icon(Icons.person, size: 16, color: Colors.green),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      // Get patient name from user profile
      final currentUser = FirebaseAuth.instance.currentUser;
      String patientName = 'Patient User'; // Default fallback

      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          patientName =
              userData['name'] ?? userData['displayName'] ?? 'Patient User';
        }
      }

      final message = _messageController.text.trim();
      _messageController.clear();

      // Add message to conversation
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(widget.conversationId)
          .collection('messages')
          .add({
            'message': message,
            'senderId': widget.currentUserId,
            'senderName': patientName, // Get from user profile
            'timestamp': FieldValue.serverTimestamp(),
          });

      // Update conversation metadata
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(widget.conversationId)
          .update({
            'lastMessage': message,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastMessageSender': widget.currentUserId,
          });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    } finally {
      setState(() => _isSending = false);
    }
  }

  String _getOtherPartyName() {
    final type = widget.conversationData['type'] ?? '';
    switch (type) {
      case 'doctor_patient':
        return widget.conversationData['doctorName'] ?? 'Doctor';
      case 'chw_patient':
        return widget.conversationData['chwName'] ?? 'CHW';
      case 'facility_patient':
        return widget.conversationData['facilityName'] ?? 'Facility';
      default:
        return 'Conversation';
    }
  }

  Color _getThemeColor(String conversationType) {
    switch (conversationType) {
      case 'doctor_patient':
        return Colors.blue;
      case 'chw_patient':
        return Colors.teal;
      case 'facility_patient':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'doctor_patient':
        return Icons.local_hospital;
      case 'chw_patient':
        return Icons.health_and_safety;
      case 'facility_patient':
        return Icons.business;
      default:
        return Icons.person;
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
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
