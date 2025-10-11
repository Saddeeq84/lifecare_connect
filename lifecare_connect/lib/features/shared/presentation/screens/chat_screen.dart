// ignore_for_file: prefer_const_constructors, deprecated_member_use, avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/data/models/message.dart';
import '../../../shared/data/services/message_service.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherParticipantName;
  final String otherParticipantRole;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherParticipantName,
    required this.otherParticipantRole,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadUserInfo();
    _loadMessages();
    _markConversationAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    if (_currentUserId == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId!)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentUserName = '${userData['firstName']} ${userData['lastName']}';
          _currentUserRole = userData['role'];
        });
      }
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  void _loadMessages() {
    MessageService.getConversationMessages(
      conversationId: widget.conversationId,
      limit: 50,
    ).listen(
      (snapshot) {
        final messages = snapshot.docs
            .map((doc) => Message.fromFirestore(doc))
            .toList();

        messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        setState(() {
          _messages = messages;
          _isLoading = false;
        });

        // Auto-scroll to bottom when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading messages: $error')),
          );
        }
      },
    );
  }

  Future<void> _markConversationAsRead() async {
    if (_currentUserId == null) return;

    try {
      await MessageService.markConversationAsRead(
        conversationId: widget.conversationId,
        userId: _currentUserId!,
      );
    } catch (e) {
      print('Error marking conversation as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message cannot be empty.')));
      return;
    }
    if (_isSending || _currentUserId == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Get conversation to find receiver details
      final conversation = await MessageService.getConversationById(
        widget.conversationId,
      );
      if (conversation == null || conversation.participantIds.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation not found or participants missing.'),
            ),
          );
        }
        return;
      }

      final receiverId = conversation.participantIds.firstWhere(
        (id) => id != _currentUserId,
        orElse: () => '',
      );
      if (receiverId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Receiver not found.')));
        }
        return;
      }
      final receiverName = conversation.participantNames[receiverId] ?? '';
      final receiverRole = conversation.participantRoles[receiverId] ?? '';

      await MessageService.sendMessage(
        conversationId: widget.conversationId,
        senderId: _currentUserId!,
        senderName: _currentUserName ?? '',
        senderRole: _currentUserRole ?? '',
        receiverId: receiverId,
        receiverName: receiverName,
        receiverRole: receiverRole,
        content: content,
      );

      _messageController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message sent.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Widget _buildMessageBubble(Message message) {
    final isMe = message.senderId == _currentUserId;
    final isSystemMessage = message.type == 'system';

    if (isSystemMessage) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 2, horizontal: 16),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: _getRoleColor(message.senderRole),
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Colors.teal : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && message.senderName.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getRoleColor(message.senderRole),
                        ),
                      ),
                    ),
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.formattedTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      if (isMe) ...[
                        SizedBox(width: 4),
                        Icon(
                          message.isRead
                              ? Icons.done_all
                              : message.isDelivered
                              ? Icons.done_all
                              : Icons.done,
                          size: 14,
                          color: message.isRead
                              ? Colors.blue[200]
                              : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: _getRoleColor(_currentUserRole ?? ''),
              child: Text(
                (_currentUserName?.isNotEmpty == true)
                    ? _currentUserName![0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
        return Colors.blue;
      case 'chw':
        return Colors.green;
      case 'patient':
        return Colors.purple;
      case 'facility':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherParticipantName),
            Text(
              widget.otherParticipantRole.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'archive':
                  _archiveConversation();
                  break;
                case 'clear':
                  _showClearChatDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'archive', child: Text('Archive Chat')),
              PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // Message input
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  offset: Offset(0, -2),
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.1),
                ),
              ],
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
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _archiveConversation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive Chat'),
        content: Text('Are you sure you want to archive this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await MessageService.archiveConversation(
                  conversationId: widget.conversationId,
                );
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Conversation archived')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to archive conversation')),
                );
              }
            },
            child: Text('Archive'),
          ),
        ],
      ),
    );
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Chat'),
        content: Text(
          'This will clear all messages in this chat. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement clear chat functionality if needed
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Clear chat feature coming soon')),
              );
            },
            child: Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
