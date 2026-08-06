import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DuplicateAccountsScreen extends StatefulWidget {
  const DuplicateAccountsScreen({super.key});

  @override
  State<DuplicateAccountsScreen> createState() =>
      _DuplicateAccountsScreenState();
}

class _DuplicateAccountsScreenState extends State<DuplicateAccountsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _duplicates = [];

  @override
  void initState() {
    super.initState();
    _findDuplicates();
  }

  Future<void> _findDuplicates() async {
    setState(() => _isLoading = true);

    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .get();

      // Group users by normalized phone number
      Map<String, List<Map<String, dynamic>>> phoneGroups = {};

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final phone = data['phone'] as String?;
        if (phone == null || phone.isEmpty) continue;

        // Normalize phone
        String normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');
        if (normalizedPhone.startsWith('234')) {
          normalizedPhone = '+$normalizedPhone';
        } else if (normalizedPhone.startsWith('0')) {
          normalizedPhone = '+234${normalizedPhone.substring(1)}';
        } else {
          normalizedPhone = '+234$normalizedPhone';
        }

        if (!phoneGroups.containsKey(normalizedPhone)) {
          phoneGroups[normalizedPhone] = [];
        }
        phoneGroups[normalizedPhone]!.add({'id': doc.id, 'data': data});
      }

      // Find duplicates (phone numbers with more than 1 account)
      List<Map<String, dynamic>> duplicates = [];
      phoneGroups.forEach((phone, users) {
        if (users.length > 1) {
          duplicates.add({
            'phone': phone,
            'count': users.length,
            'users': users,
          });
        }
      });

      setState(() {
        _duplicates = duplicates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finding duplicates: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Delete Account'),
        content: Text(
          'Are you sure you want to delete the account for $userName?\n\n'
          'User ID: $userId\n\n'
          'This action cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete user document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();

        // Delete wallet if exists
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(userId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Refresh list
        _findDuplicates();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting account: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicate Patient Accounts'),
        backgroundColor: Colors.orange.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _findDuplicates,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _duplicates.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'No duplicate phone numbers found',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _duplicates.length,
              itemBuilder: (context, index) {
                final duplicate = _duplicates[index];
                final phone = duplicate['phone'] as String;
                final count = duplicate['count'] as int;
                final users = duplicate['users'] as List;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    leading: const Icon(Icons.warning, color: Colors.orange),
                    title: Text(
                      phone,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('$count duplicate accounts'),
                    children: users.map<Widget>((user) {
                      final userId = user['id'] as String;
                      final userData = user['data'] as Map<String, dynamic>;
                      final name =
                          userData['fullName'] ?? userData['name'] ?? 'No name';
                      final email = userData['email'] ?? 'No email';

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(name[0].toUpperCase()),
                        ),
                        title: Text(name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: $userId'),
                            Text('Email: $email'),
                            Text(
                              'Created: ${userData['createdAt'] != null ? (userData['createdAt'] as Timestamp).toDate().toString().split('.')[0] : 'Unknown'}',
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteAccount(userId, name),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }
}
