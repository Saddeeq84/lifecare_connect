// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/services/message_service.dart';

class ComposeMessageScreen extends StatefulWidget {
  const ComposeMessageScreen({super.key});

  @override
  _ComposeMessageScreenState createState() => _ComposeMessageScreenState();
}

class _ComposeMessageScreenState extends State<ComposeMessageScreen> {
  final _messageController = TextEditingController();
  final _subjectController = TextEditingController();
  String? _selectedUserId;
  String? _selectedUserName;
  String? _selectedUserRole;
  String _filterRole = 'all';
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compose Message'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipient Selection Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Color(0xFF4285F4)),
                        const SizedBox(width: 8),
                        const Text(
                          'Select Recipient',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        DropdownButton<String>(
                          value: _filterRole,
                          onChanged: (value) {
                            setState(() {
                              _filterRole = value!;
                              _selectedUserId = null;
                              _selectedUserName = null;
                              _selectedUserRole = null;
                            });
                          },
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(
                              value: 'patient',
                              child: Text('Patients'),
                            ),
                            DropdownMenuItem(value: 'CHW', child: Text('CHWs')),
                            DropdownMenuItem(
                              value: 'doctor',
                              child: Text('Doctors'),
                            ),
                            DropdownMenuItem(
                              value: 'facility_admin',
                              child: Text('Facilities'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_selectedUserId != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4285F4).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF4285F4)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getRoleIcon(_selectedUserRole),
                              color: const Color(0xFF4285F4),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedUserName!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _getRoleDisplayName(_selectedUserRole),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _selectedUserId = null;
                                  _selectedUserName = null;
                                  _selectedUserRole = null;
                                });
                              },
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _buildUserList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Message Composition Section
            Expanded(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.message, color: Color(0xFF4285F4)),
                          SizedBox(width: 8),
                          Text(
                            'Message Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.subject),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(bottom: 60),
                              child: Icon(Icons.edit),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Send Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSendMessage() ? _sendMessage : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSending
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Sending...'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send),
                          SizedBox(width: 8),
                          Text('Send Message'),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        final users = snapshot.data!.docs;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        // Filter out current user
        final filteredUsers = users
            .where((doc) => doc.id != currentUserId)
            .toList();

        if (filteredUsers.isEmpty) {
          return const Center(child: Text('No other users found'));
        }

        return ListView.builder(
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final userDoc = filteredUsers[index];
            final userData = userDoc.data() as Map<String, dynamic>;
            final firstName = userData['firstName'] ?? '';
            final lastName = userData['lastName'] ?? '';
            final fullName = '$firstName $lastName'.trim();
            final role = userData['role'] ?? 'user';
            final email = userData['email'] ?? '';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF4285F4),
                child: Icon(_getRoleIcon(role), color: Colors.white),
              ),
              title: Text(
                fullName.isNotEmpty ? fullName : email,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(_getRoleDisplayName(role)),
              onTap: () {
                setState(() {
                  _selectedUserId = userDoc.id;
                  _selectedUserName = fullName.isNotEmpty ? fullName : email;
                  _selectedUserRole = role;
                });
              },
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getUsersStream() {
    Query query = FirebaseFirestore.instance.collection('users');

    if (_filterRole != 'all') {
      query = query.where('role', isEqualTo: _filterRole);
    }

    return query.snapshots();
  }

  IconData _getRoleIcon(String? role) {
    switch (role?.toLowerCase()) {
      case 'patient':
        return Icons.person;
      case 'chw':
        return Icons.health_and_safety;
      case 'doctor':
        return Icons.medical_services;
      case 'facility_admin':
        return Icons.local_hospital;
      default:
        return Icons.person_outline;
    }
  }

  String _getRoleDisplayName(String? role) {
    switch (role?.toLowerCase()) {
      case 'patient':
        return 'Patient';
      case 'chw':
        return 'Community Health Worker';
      case 'doctor':
        return 'Doctor';
      case 'facility_admin':
        return 'Facility Administrator';
      default:
        return 'User';
    }
  }

  bool _canSendMessage() {
    return _selectedUserId != null &&
        _subjectController.text.trim().isNotEmpty &&
        _messageController.text.trim().isNotEmpty &&
        !_isSending;
  }

  Future<void> _sendMessage() async {
    if (!_canSendMessage()) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Get current user details
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!currentUserDoc.exists) {
        throw Exception('Current user data not found');
      }

      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      final senderFirstName = currentUserData['firstName'] ?? '';
      final senderLastName = currentUserData['lastName'] ?? '';
      final senderName = '$senderFirstName $senderLastName'.trim();
      final senderRole = currentUserData['role'] ?? 'user';

      // Format the message with subject
      final messageContent =
          '''
📧 Subject: ${_subjectController.text.trim()}

${_messageController.text.trim()}

---
Sent from LifeCare Connect
''';

      // Create or get conversation
      final conversationId = await MessageService.createOrGetConversation(
        user1Id: currentUser.uid,
        user1Name: senderName.isNotEmpty
            ? senderName
            : currentUser.email ?? 'User',
        user1Role: senderRole,
        user2Id: _selectedUserId!,
        user2Name: _selectedUserName!,
        user2Role: _selectedUserRole!,
        type: 'personal_message',
        title: _subjectController.text.trim(),
      );

      // Send message
      await MessageService.sendMessage(
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderName: senderName.isNotEmpty
            ? senderName
            : currentUser.email ?? 'User',
        senderRole: senderRole,
        receiverId: _selectedUserId!,
        receiverName: _selectedUserName!,
        receiverRole: _selectedUserRole!,
        content: messageContent,
        type: 'personal_message',
        priority: 'normal',
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message sent to $_selectedUserName successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      _messageController.clear();
      _subjectController.clear();
      setState(() {
        _selectedUserId = null;
        _selectedUserName = null;
        _selectedUserRole = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }
}
