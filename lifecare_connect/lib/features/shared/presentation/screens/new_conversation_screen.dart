// ignore_for_file: prefer_const_constructors, deprecated_member_use, avoid_print, sized_box_for_whitespace

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/data/services/message_service.dart';
import 'chat_screen.dart';

class NewConversationScreen extends StatefulWidget {
  const NewConversationScreen({super.key});

  @override
  State<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<NewConversationScreen> {
  String _selectedRoleFilter = 'all';
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadCurrentUserInfo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserInfo() async {
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

  Future<void> _searchUsers() async {
    final searchTerm = _searchController.text.trim();
    if (_currentUserId == null) {
      setState(() {
        _users = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final users = await MessageService.searchUsers(
        searchTerm: searchTerm,
        currentUserId: _currentUserId!,
        roleFilter: _selectedRoleFilter == 'all' ? null : [_selectedRoleFilter],
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
    if (_currentUserId == null ||
        _currentUserName == null ||
        _currentUserRole == null) {
      return;
    }

    try {
      final conversationId = await MessageService.createOrGetConversation(
        user1Id: _currentUserId!,
        user1Name: _currentUserName!,
        user1Role: _currentUserRole!,
        user2Id: user['id'],
        user2Name: user['name'],
        user2Role: user['role'],
      );

      if (mounted) {
        Navigator.pushReplacement(
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

  Widget _buildUserTile(Map<String, dynamic> user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getRoleColor(user['role']),
        child: Text(
          user['name'].isNotEmpty ? user['name'][0].toUpperCase() : '?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(user['name'], style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getRoleColor(user['role']).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  user['role'].toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: _getRoleColor(user['role']),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (user['isOnline'] == true) ...[
                SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          if (user['specialization'] != null)
            Text(
              user['specialization'],
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          if (user['facilityName'] != null)
            Text(
              user['facilityName'],
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
        ],
      ),
      trailing: Icon(Icons.chat_bubble_outline),
      onTap: () => _startConversation(user),
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
        title: Text('New Conversation'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search healthcare team members...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (_) => _searchUsers(),
              textCapitalization: TextCapitalization.words,
            ),
          ),

          // Quick access filters
          if (_currentUserRole != null)
            Container(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildQuickFilter('All', 'all'),
                  SizedBox(width: 8),
                  _buildQuickFilter('Doctors', 'doctor'),
                  SizedBox(width: 8),
                  _buildQuickFilter('CHWs', 'chw'),
                  SizedBox(width: 8),
                  if (_currentUserRole!.toLowerCase() != 'patient')
                    _buildQuickFilter('Patients', 'patient'),
                  SizedBox(width: 8),
                  _buildQuickFilter('Facilities', 'facility'),
                ],
              ),
            ),

          SizedBox(height: 16),

          // Search results
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Search for healthcare team members'
                              : 'No users found',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Type a name or role to find someone to chat with'
                              : 'Try a different search term',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (context, index) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      return _buildUserTile(_users[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilter(String label, String role) {
    final isSelected = _selectedRoleFilter == role;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRoleFilter = role;
        });
        _searchUsers();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _getRoleColor(role).withOpacity(0.3)
              : _getRoleColor(role).withOpacity(0.1),
          border: Border.all(
            color: _getRoleColor(role),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _getRoleColor(role),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
