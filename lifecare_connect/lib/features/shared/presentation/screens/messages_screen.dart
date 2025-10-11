// ignore_for_file: prefer_const_constructors, deprecated_member_use, avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/data/models/message.dart';
import '../../../shared/data/services/message_service.dart';
import 'chat_screen.dart';
import 'new_conversation_screen.dart';
import 'messaging/compose_message_screen.dart';
import 'messaging/broadcast_message_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  String? _currentUserId;
  final _searchController = TextEditingController();
  List<Conversation> _filteredConversations = [];
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final route = ModalRoute.of(context);
      if (route != null && route.settings.arguments != null) {
        final args = route.settings.arguments as Map<String, dynamic>?;
        final recipientId = args?['recipientId'] as String?;
        final recipientName = args?['recipientName'] as String?;
        if (recipientId != null && recipientId.isNotEmpty) {
          final conversation = await MessageService.findOrCreateConversation(
            userId: _currentUserId!,
            otherUserId: recipientId,
            otherUserName: recipientName ?? 'Health Worker',
          );
          if (conversation != null) {
            _openChat(conversation);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Unable to open chat with provider.')),
            );
          }
        }
      }
    });
    _loadConversations();
    _checkAdminRole();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminRole() async {
    if (_currentUserId == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final role = userData['role'] ?? '';
        setState(() {
          _isAdmin = role == 'admin' || role == 'facility_admin';
        });
      }
    } catch (e) {
      print('Error checking admin role: $e');
    }
  }

  void _loadConversations() {
    if (_currentUserId == null) return;

    setState(() {
      _isLoading = true;
    });

    MessageService.getUserConversations(userId: _currentUserId!).listen(
      (snapshot) {
        final conversations = snapshot.docs
            .map((doc) => Conversation.fromFirestore(doc))
            .toList();
        setState(() {
          _conversations = conversations;
          _filteredConversations = conversations;
          _isLoading = false;
        });
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading conversations: $error')),
          );
        }
      },
    );
  }

  void _filterConversations(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredConversations = _conversations;
      } else {
        _filteredConversations = _conversations.where((conversation) {
          final otherParticipantName = conversation.getOtherParticipantName(
            _currentUserId!,
          );
          return otherParticipantName.toLowerCase().contains(
                query.toLowerCase(),
              ) ||
              (conversation.title?.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ??
                  false) ||
              (conversation.lastMessage?.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ??
                  false);
        }).toList();
      }
    });
  }

  void _openChat(Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversation.id,
          otherParticipantName: conversation.getOtherParticipantName(
            _currentUserId!,
          ),
          otherParticipantRole: conversation.getOtherParticipantRole(
            _currentUserId!,
          ),
        ),
      ),
    );
  }

  void _startNewConversation() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewConversationScreen()),
    );
  }

  void _composeMessage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ComposeMessageScreen()),
    );
  }

  void _sendBroadcastMessage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BroadcastMessageScreen()),
    );
  }

  void _showMessagingOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Messaging Options',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chat, color: Colors.teal),
              ),
              title: const Text('Start Conversation'),
              subtitle: const Text('Chat with someone directly'),
              onTap: () {
                Navigator.pop(context);
                _startNewConversation();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_search,
                  color: Color(0xFF4285F4),
                ),
              ),
              title: const Text('Compose Message'),
              subtitle: const Text('Send message to specific user'),
              onTap: () {
                Navigator.pop(context);
                _composeMessage();
              },
            ),
            if (_isAdmin)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.campaign, color: Color(0xFFE53935)),
                ),
                title: const Text('Broadcast Message'),
                subtitle: const Text('Send message to multiple users'),
                onTap: () {
                  Navigator.pop(context);
                  _sendBroadcastMessage();
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(Conversation conversation) {
    final otherParticipantName = conversation.getOtherParticipantName(
      _currentUserId!,
    );
    final otherParticipantRole = conversation.getOtherParticipantRole(
      _currentUserId!,
    );
    final unreadCount = conversation.getUnreadCount(_currentUserId!);
    final hasUnread = unreadCount > 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getRoleColor(otherParticipantRole),
        child: Text(
          otherParticipantName.isNotEmpty
              ? otherParticipantName[0].toUpperCase()
              : '?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.title ?? otherParticipantName,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (hasUnread)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            otherParticipantRole.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: _getRoleColor(otherParticipantRole),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2),
          Text(
            conversation.lastMessage ?? 'No messages yet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
              color: hasUnread ? Colors.black87 : Colors.grey[600],
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            conversation.lastMessageTime != null
                ? _formatTime(conversation.lastMessageTime!)
                : '',
            style: TextStyle(
              fontSize: 12,
              color: hasUnread ? Colors.teal : Colors.grey[500],
              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (conversation.type != 'direct')
            Container(
              margin: EdgeInsets.only(top: 4),
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getTypeColor(conversation.type).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                conversation.type.toUpperCase(),
                style: TextStyle(
                  fontSize: 8,
                  color: _getTypeColor(conversation.type),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () => _openChat(conversation),
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

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'consultation':
        return Colors.teal;
      case 'referral':
        return Colors.deepPurple;
      case 'group':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(Duration(days: 1))) {
      return 'Yesterday';
    } else if (dateTime.isAfter(today.subtract(Duration(days: 7)))) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dateTime.weekday - 1];
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: ConversationSearchDelegate(
                  conversations: _conversations,
                  currentUserId: _currentUserId!,
                  onConversationSelected: _openChat,
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'compose':
                  _composeMessage();
                  break;
                case 'broadcast':
                  _sendBroadcastMessage();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'compose',
                child: Row(
                  children: [
                    Icon(Icons.person_search, color: Color(0xFF4285F4)),
                    SizedBox(width: 8),
                    Text('Compose Message'),
                  ],
                ),
              ),
              if (_isAdmin)
                const PopupMenuItem(
                  value: 'broadcast',
                  child: Row(
                    children: [
                      Icon(Icons.campaign, color: Color(0xFFE53935)),
                      SizedBox(width: 8),
                      Text('Broadcast Message'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _filterConversations,
            ),
          ),

          // Conversations list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredConversations.isEmpty
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
                          _searchController.text.isNotEmpty
                              ? 'No conversations found'
                              : 'No messages yet',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'Try a different search term'
                              : 'Start a conversation with your healthcare team',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredConversations.length,
                    separatorBuilder: (context, index) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      return _buildConversationTile(
                        _filteredConversations[index],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showMessagingOptions,
        backgroundColor: Colors.teal,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// Search delegate for conversations
class ConversationSearchDelegate extends SearchDelegate<Conversation?> {
  final List<Conversation> conversations;
  final String currentUserId;
  final Function(Conversation) onConversationSelected;

  ConversationSearchDelegate({
    required this.conversations,
    required this.currentUserId,
    required this.onConversationSelected,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filteredConversations = conversations.where((conversation) {
      final otherParticipantName = conversation.getOtherParticipantName(
        currentUserId,
      );
      return otherParticipantName.toLowerCase().contains(query.toLowerCase()) ||
          (conversation.title?.toLowerCase().contains(query.toLowerCase()) ??
              false) ||
          (conversation.lastMessage?.toLowerCase().contains(
                query.toLowerCase(),
              ) ??
              false);
    }).toList();

    return ListView.builder(
      itemCount: filteredConversations.length,
      itemBuilder: (context, index) {
        final conversation = filteredConversations[index];
        final otherParticipantName = conversation.getOtherParticipantName(
          currentUserId,
        );

        return ListTile(
          leading: CircleAvatar(
            child: Text(
              otherParticipantName.isNotEmpty ? otherParticipantName[0] : '?',
            ),
          ),
          title: Text(conversation.title ?? otherParticipantName),
          subtitle: Text(conversation.lastMessage ?? 'No messages yet'),
          onTap: () {
            close(context, conversation);
            onConversationSelected(conversation);
          },
        );
      },
    );
  }
}
