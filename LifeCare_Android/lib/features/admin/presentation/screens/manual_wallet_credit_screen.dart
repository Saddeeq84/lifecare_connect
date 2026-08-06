import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManualWalletCreditScreen extends StatefulWidget {
  const ManualWalletCreditScreen({super.key});

  @override
  State<ManualWalletCreditScreen> createState() =>
      _ManualWalletCreditScreenState();
}

class _ManualWalletCreditScreenState extends State<ManualWalletCreditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailPhoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _isSearching = false;
  bool _isProcessing = false;
  Map<String, dynamic>? _foundUser;
  String? _userId;
  double? _currentBalance;
  String _searchType = 'phone'; // 'phone', 'email', or 'userId'

  @override
  void dispose() {
    _emailPhoneController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  // Normalize phone number to consistent format
  String _normalizePhone(String phone) {
    // Remove all non-digit characters
    String digits = phone.replaceAll(RegExp(r'\D'), '');

    // If starts with country code, keep it
    if (digits.startsWith('234')) {
      return '+$digits';
    }
    // If starts with 0, replace with +234
    if (digits.startsWith('0')) {
      return '+234${digits.substring(1)}';
    }
    // If no country code, add +234
    return '+234$digits';
  }

  Future<void> _searchUser() async {
    if (_emailPhoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email or phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _foundUser = null;
      _userId = null;
      _currentBalance = null;
    });

    try {
      final searchTerm = _emailPhoneController.text.trim();

      DocumentSnapshot? userDoc;
      QuerySnapshot? userQuery;

      // Search by user ID directly
      if (_searchType == 'userId') {
        userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(searchTerm)
            .get();

        if (!userDoc.exists || userDoc.data() == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User not found'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() => _isSearching = false);
          return;
        }
      } else if (_searchType == 'email') {
        userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: searchTerm)
            .where('role', isEqualTo: 'patient')
            .get();
      } else {
        // Search by phone number - try both normalized and original
        final normalizedPhone = _normalizePhone(searchTerm);

        userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', whereIn: [searchTerm, normalizedPhone])
            .where('role', isEqualTo: 'patient')
            .get();
      }

      if (userQuery != null && userQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient not found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isSearching = false);
        return;
      }

      // Check for duplicates
      if (userQuery != null && userQuery.docs.length > 1) {
        if (mounted) {
          // Show dialog with all duplicates
          final duplicates = userQuery.docs;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('⚠️ Multiple Accounts Found'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Found ${duplicates.length} accounts with this $_searchType:',
                    ),
                    const SizedBox(height: 16),
                    ...duplicates.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(data['name'] ?? 'No name'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: ${doc.id}'),
                              Text('Phone: ${data['phone'] ?? 'N/A'}'),
                              Text('Email: ${data['email'] ?? 'N/A'}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: () {
                              Navigator.pop(context);
                              _selectUser(doc);
                            },
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );
        }
        setState(() => _isSearching = false);
        return;
      }

      // Get user document (either from direct lookup or query)
      final DocumentSnapshot finalUserDoc = userDoc ?? userQuery!.docs.first;
      await _selectUser(finalUserDoc);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isSearching = false);
    }
  }

  Future<void> _selectUser(DocumentSnapshot userDoc) async {
    try {
      final userId = userDoc.id;
      final userData = userDoc.data() as Map<String, dynamic>;

      print('🔍 Admin search found user ID: $userId');

      // Get current wallet balance
      final walletDoc = await FirebaseFirestore.instance
          .collection('wallets')
          .doc(userId)
          .get();

      print(
        '💰 Admin screen wallet balance: ₦${walletDoc.exists ? (walletDoc.data()?['balance'] ?? 0.0) : 0.0}',
      );

      final currentBalance = walletDoc.exists
          ? (walletDoc.data()?['balance'] ?? 0.0).toDouble()
          : 0.0;

      setState(() {
        _foundUser = userData;
        _userId = userId;
        _currentBalance = currentBalance;
        _isSearching = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isSearching = false);
    }
  }

  Future<void> _creditWallet() async {
    if (!_formKey.currentState!.validate()) return;
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please search for a patient first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Wallet Credit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient: ${_foundUser!['firstName']} ${_foundUser!['lastName']}',
            ),
            Text('Email: ${_foundUser!['email']}'),
            Text('Phone: ${_foundUser!['phone'] ?? 'N/A'}'),
            const SizedBox(height: 12),
            Text('Current Balance: ₦${_currentBalance!.toStringAsFixed(2)}'),
            Text(
              'New Balance: ₦${(_currentBalance! + double.parse(_amountController.text)).toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            Text('Amount to Credit: ₦${_amountController.text}'),
            Text('Reference: ${_referenceController.text}'),
            Text('Reason: ${_reasonController.text}'),
            const SizedBox(height: 12),
            const Text(
              'Are you sure you want to credit this wallet?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm Credit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final amount = double.parse(_amountController.text);
      final reference = _referenceController.text.trim();
      final reason = _reasonController.text.trim();
      final adminUser = FirebaseAuth.instance.currentUser!;

      final walletRef = FirebaseFirestore.instance
          .collection('wallets')
          .doc(_userId);

      // Use a transaction to ensure atomic update
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final walletSnapshot = await transaction.get(walletRef);

        double currentBalance = 0.0;
        if (walletSnapshot.exists && walletSnapshot.data() != null) {
          final balanceValue = walletSnapshot.data()!['balance'];
          if (balanceValue is num) {
            currentBalance = balanceValue.toDouble();
          }
        }

        final newBalance = currentBalance + amount;

        // Update wallet balance
        transaction.set(walletRef, {
          'balance': newBalance,
          'currency': 'NGN',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      // Add transaction to wallet subcollection
      await walletRef.collection('transactions').add({
        'type': 'credit',
        'amount': amount,
        'description': 'Manual wallet credit by admin',
        'reference': reference,
        'reason': reason,
        'status': 'completed',
        'method': 'admin_manual_credit',
        'timestamp': FieldValue.serverTimestamp(),
        'creditedBy': adminUser.uid,
        'creditedByEmail': adminUser.email,
      });

      // Add to top-level wallet_transactions collection
      await FirebaseFirestore.instance.collection('wallet_transactions').add({
        'walletId': _userId,
        'userId': _userId,
        'type': 'credit',
        'amount': amount,
        'description': 'Manual wallet credit by admin',
        'reference': reference,
        'reason': reason,
        'status': 'completed',
        'method': 'admin_manual_credit',
        'timestamp': FieldValue.serverTimestamp(),
        'creditedBy': adminUser.uid,
        'creditedByEmail': adminUser.email,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully credited ₦${amount.toStringAsFixed(2)} to patient wallet',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Clear form and search again to refresh balance
      _amountController.clear();
      _referenceController.clear();
      _reasonController.clear();
      await _searchUser();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error crediting wallet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Wallet Credit'),
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Search Patient',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _searchType,
                        decoration: const InputDecoration(
                          labelText: 'Search By',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.filter_list),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'phone',
                            child: Text('Phone Number'),
                          ),
                          DropdownMenuItem(
                            value: 'email',
                            child: Text('Email'),
                          ),
                          DropdownMenuItem(
                            value: 'userId',
                            child: Text('User ID'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _searchType = value!;
                            _foundUser = null;
                            _userId = null;
                            _currentBalance = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailPhoneController,
                        decoration: InputDecoration(
                          labelText: _searchType == 'phone'
                              ? 'Phone Number'
                              : _searchType == 'email'
                              ? 'Email'
                              : 'User ID',
                          hintText: _searchType == 'phone'
                              ? 'Enter patient phone'
                              : _searchType == 'email'
                              ? 'Enter patient email'
                              : 'Enter patient user ID',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _isSearching ? null : _searchUser,
                        icon: _isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: Text(
                          _isSearching ? 'Searching...' : 'Search Patient',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_foundUser != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            const Text(
                              'Patient Found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        _buildDetailRow(
                          'Name',
                          '${_foundUser!['firstName']} ${_foundUser!['lastName']}',
                        ),
                        _buildDetailRow('Email', _foundUser!['email'] ?? 'N/A'),
                        _buildDetailRow('Phone', _foundUser!['phone'] ?? 'N/A'),
                        _buildDetailRow('User ID', _userId!),
                        const Divider(),
                        _buildDetailRow(
                          'Current Balance',
                          '₦${_currentBalance!.toStringAsFixed(2)}',
                          valueStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Credit Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Amount (₦)',
                            hintText: 'Enter amount to credit',
                            prefixIcon: Icon(Icons.money),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter amount';
                            }
                            final amount = double.tryParse(value);
                            if (amount == null || amount <= 0) {
                              return 'Please enter a valid amount';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _referenceController,
                          decoration: const InputDecoration(
                            labelText: 'Transaction Reference',
                            hintText:
                                'e.g., Paystack reference or bank transaction ID',
                            prefixIcon: Icon(Icons.receipt_long),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter transaction reference';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _reasonController,
                          decoration: const InputDecoration(
                            labelText: 'Reason',
                            hintText:
                                'e.g., Failed payment verification - manual credit',
                            prefixIcon: Icon(Icons.note),
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter reason for credit';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _creditWallet,
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add_card),
                            label: Text(
                              _isProcessing ? 'Processing...' : 'Credit Wallet',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value, style: valueStyle)),
        ],
      ),
    );
  }
}
