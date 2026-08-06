// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import '../../../shared/data/services/message_service.dart';
import '../../../shared/presentation/screens/chat_screen.dart';

class AdminIndividualMessagesTab extends StatefulWidget {
  final String role;
  final String adminUserId;
  const AdminIndividualMessagesTab({
    required this.role,
    required this.adminUserId,
    super.key,
  });

  @override
  State<AdminIndividualMessagesTab> createState() =>
      _AdminIndividualMessagesTabState();
}

class _AdminIndividualMessagesTabState
    extends State<AdminIndividualMessagesTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchUsers();
  }

  Future<void> _searchUsers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final users = await MessageService.searchUsers(
        searchTerm: _searchController.text.trim(),
        currentUserId: widget.adminUserId,
        roleFilter: [widget.role],
      );
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching users: $e')));
      }
    }
  }

  Future<void> _startConversation(Map<String, dynamic> user) async {
    try {
      final conversationId = await MessageService.createOrGetConversation(
        user1Id: widget.adminUserId,
        user1Name: 'Admin',
        user1Role: 'admin',
        user2Id: user['id'],
        user2Name: user['name'],
        user2Role: user['role'],
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversationId,
              otherParticipantName: user['name'],
              otherParticipantRole: user['role'],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start conversation: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText:
                  'Search {widget.role[0].toUpperCase()}${widget.role.substring(1)}s...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) => _searchUsers(),
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _users.isEmpty
              ? Center(child: Text('No ${widget.role}s found.'))
              : ListView.separated(
                  itemCount: _users.length,
                  separatorBuilder: (context, index) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          user['name'].isNotEmpty
                              ? user['name'][0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(user['name']),
                      subtitle: Text(user['role'].toString().toUpperCase()),
                      trailing: Icon(Icons.chat_bubble_outline),
                      onTap: () => _startConversation(user),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
