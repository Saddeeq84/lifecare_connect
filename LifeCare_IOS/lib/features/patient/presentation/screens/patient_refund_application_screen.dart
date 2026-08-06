// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

/// Screen for independent/remote patients to apply for wallet refunds
/// Use cases: Patient wants to withdraw funds, patient relocating, or next of kin claiming deceased patient's wallet
class PatientRefundApplicationScreen extends StatefulWidget {
  const PatientRefundApplicationScreen({super.key});

  @override
  State<PatientRefundApplicationScreen> createState() =>
      _PatientRefundApplicationScreenState();
}

class _PatientRefundApplicationScreenState
    extends State<PatientRefundApplicationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('Wallet Refund'),
        backgroundColor: Colors.teal,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Apply Refund', icon: Icon(Icons.add_card)),
            Tab(text: 'My Applications', icon: Icon(Icons.receipt_long)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_ApplyRefundTab(), _MyApplicationsTab()],
      ),
    );
  }
}

/// Tab for applying new refund
class _ApplyRefundTab extends StatefulWidget {
  const _ApplyRefundTab();

  @override
  State<_ApplyRefundTab> createState() => _ApplyRefundTabState();
}

class _ApplyRefundTabState extends State<_ApplyRefundTab> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  String _selectedReason = 'withdrawal';
  String _selectedBankCode = '';
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();

  // Next of kin fields (for deceased case)
  final _nokNameController = TextEditingController();
  final _nokRelationshipController = TextEditingController();
  final _nokPhoneController = TextEditingController();

  // State variables
  double _walletBalance = 0.0;
  bool _loading = false;
  bool _verifyingAccount = false;
  bool _accountVerified = false;
  String? _verifiedAccountName;

  @override
  void initState() {
    super.initState();
    _loadWalletBalance();
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    _nokNameController.dispose();
    _nokRelationshipController.dispose();
    _nokPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletBalance() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final walletDoc = await FirebaseFirestore.instance
          .collection('wallets')
          .doc(user.uid)
          .get();

      if (walletDoc.exists) {
        setState(() {
          _walletBalance = (walletDoc.data()?['balance'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading wallet: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyBankAccount() async {
    if (_accountNumberController.text.length != 10 ||
        _selectedBankCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid account number and select a bank'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _verifyingAccount = true;
      _accountVerified = false;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'verifyBankAccountName',
      );
      final result = await callable.call({
        'accountNumber': _accountNumberController.text,
        'bankCode': _selectedBankCode,
      });

      if (result.data['success'] == true) {
        final accountName = result.data['accountName'] as String;
        final similarity = result.data['nameSimilarity'] as double;

        setState(() {
          _verifiedAccountName = accountName;
          _accountNameController.text = accountName;
          _accountVerified = similarity >= 0.7;
        });

        if (_accountVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Account verified: $accountName'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Show warning but allow to proceed
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Name Mismatch'),
              content: Text(
                'The bank account name "$accountName" does not closely match your registered name.\n\n'
                'Similarity: ${(similarity * 100).toStringAsFixed(1)}%\n\n'
                'Your application will require additional verification.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(result.data['message'] ?? 'Verification failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _verifyingAccount = false);
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_accountVerified && _verifiedAccountName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your bank account first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (amount > _walletBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient wallet balance'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Get patient name from users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final patientName = userDoc.data()?['name'] ?? 'Unknown';
      final patientEmail = userDoc.data()?['email'] ?? user.email ?? '';
      final patientPhone = userDoc.data()?['phone'] ?? '';

      // Create refund application
      final applicationData = {
        'patientId': user.uid,
        'patientName': patientName,
        'patientEmail': patientEmail,
        'patientPhone': patientPhone,
        'applicationType': 'patient', // vs 'facility'
        'reason': _selectedReason,
        'amount': amount,
        'bankCode': _selectedBankCode,
        'bankName': _nigerianBanks[_selectedBankCode] ?? '',
        'accountNumber': _accountNumberController.text,
        'accountName': _verifiedAccountName ?? _accountNameController.text,
        'remarks': _remarksController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
      };

      // Add next of kin info if deceased
      if (_selectedReason == 'deceased') {
        applicationData['nextOfKin'] = {
          'name': _nokNameController.text.trim(),
          'relationship': _nokRelationshipController.text.trim(),
          'phone': _nokPhoneController.text.trim(),
        };
      }

      await FirebaseFirestore.instance
          .collection('patient_refund_applications')
          .add(applicationData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Refund application submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _formKey.currentState!.reset();
        _accountNumberController.clear();
        _accountNameController.clear();
        _amountController.clear();
        _remarksController.clear();
        _nokNameController.clear();
        _nokRelationshipController.clear();
        _nokPhoneController.clear();
        setState(() {
          _accountVerified = false;
          _verifiedAccountName = null;
          _selectedBankCode = '';
        });

        // Switch to applications tab
        DefaultTabController.of(context).animateTo(1);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet Balance Card
            Card(
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.teal,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Balance',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          '₦${NumberFormat('#,##0.00').format(_walletBalance)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Reason
            const Text(
              'Refund Reason *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedReason,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.help_outline),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'withdrawal',
                  child: Text('Withdraw Funds'),
                ),
                DropdownMenuItem(
                  value: 'relocating',
                  child: Text('Relocating'),
                ),
                DropdownMenuItem(
                  value: 'deceased',
                  child: Text('Deceased (Next of Kin Claim)'),
                ),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) {
                setState(() => _selectedReason = value!);
              },
            ),
            const SizedBox(height: 16),

            // Next of Kin Section (only for deceased)
            if (_selectedReason == 'deceased') ...[
              const Divider(),
              const Text(
                'Next of Kin Information *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nokNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nokRelationshipController,
                decoration: const InputDecoration(
                  labelText: 'Relationship to Patient',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.family_restroom),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nokPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const Divider(),
              const SizedBox(height: 16),
            ],

            // Amount
            const Text(
              'Refund Amount (₦) *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money),
                hintText: 'Enter amount',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final amount = double.tryParse(v);
                if (amount == null || amount <= 0) return 'Enter valid amount';
                if (amount > _walletBalance) return 'Exceeds wallet balance';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Bank Selection
            const Text('Bank *', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedBankCode.isEmpty ? null : _selectedBankCode,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance),
                hintText: 'Select bank',
              ),
              items: _nigerianBanks.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBankCode = value!;
                  _accountVerified = false;
                  _verifiedAccountName = null;
                });
              },
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please select a bank' : null,
            ),
            const SizedBox(height: 16),

            // Account Number
            const Text(
              'Account Number *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _accountNumberController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.credit_card),
                      hintText: '10-digit account number',
                      suffixIcon: _accountVerified
                          ? const Icon(Icons.verified, color: Colors.green)
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (v.length != 10) return '10 digits required';
                      return null;
                    },
                    onChanged: (_) {
                      setState(() {
                        _accountVerified = false;
                        _verifiedAccountName = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _verifyingAccount ? null : _verifyBankAccount,
                  icon: _verifyingAccount
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.verified_user),
                  label: const Text('Verify'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Account Name (auto-filled after verification)
            const Text(
              'Account Name',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _accountNameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
                hintText: 'Verify account to auto-fill',
              ),
              readOnly: true,
            ),
            const SizedBox(height: 16),

            // Remarks
            const Text(
              'Additional Remarks (Optional)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _remarksController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Add any additional information',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submitApplication,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _loading ? 'Submitting...' : 'Submit Refund Application',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Information Card
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your refund application will be reviewed by the admin. '
                        'Processing typically takes 1-3 business days. You will be notified once approved.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Nigerian Banks mapping
  static const Map<String, String> _nigerianBanks = {
    '044': 'Access Bank',
    '023': 'Citibank Nigeria',
    '063': 'Diamond Bank',
    '050': 'Ecobank Nigeria',
    '070': 'Fidelity Bank',
    '011': 'First Bank of Nigeria',
    '214': 'First City Monument Bank',
    '058': 'Guaranty Trust Bank',
    '030': 'Heritage Bank',
    '301': 'Jaiz Bank',
    '082': 'Keystone Bank',
    '526': 'Parallex Bank',
    '076': 'Polaris Bank',
    '101': 'Providus Bank',
    '221': 'Stanbic IBTC Bank',
    '068': 'Standard Chartered Bank',
    '232': 'Sterling Bank',
    '100': 'Suntrust Bank',
    '032': 'Union Bank of Nigeria',
    '033': 'United Bank for Africa',
    '215': 'Unity Bank',
    '035': 'Wema Bank',
    '057': 'Zenith Bank',
  };
}

/// Tab for viewing refund applications
class _MyApplicationsTab extends StatelessWidget {
  const _MyApplicationsTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patient_refund_applications')
          .where('patientId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final applications = snapshot.data?.docs ?? [];

        if (applications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No refund applications yet',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final doc = applications[index];
            final data = doc.data() as Map<String, dynamic>;

            return _ApplicationCard(applicationId: doc.id, data: data);
          },
        );
      },
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final String applicationId;
  final Map<String, dynamic> data;

  const _ApplicationCard({required this.applicationId, required this.data});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'pending';
    final amount = (data['amount'] ?? 0.0).toDouble();
    final reason = data['reason'] ?? 'N/A';
    final bankName = data['bankName'] ?? 'N/A';
    final accountNumber = data['accountNumber'] ?? 'N/A';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final rejectionReason = data['rejectionReason'];

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.pending;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          '₦${NumberFormat('#,##0.00').format(amount)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(
          'Status: ${status.toUpperCase()}',
          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Application ID', applicationId),
                _buildInfoRow('Reason', _formatReason(reason)),
                _buildInfoRow(
                  'Amount',
                  '₦${NumberFormat('#,##0.00').format(amount)}',
                ),
                _buildInfoRow('Bank', bankName),
                _buildInfoRow('Account Number', accountNumber),
                _buildInfoRow('Account Name', data['accountName'] ?? 'N/A'),
                if (createdAt != null)
                  _buildInfoRow(
                    'Applied On',
                    DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt),
                  ),
                if (data['approvedAt'] != null)
                  _buildInfoRow(
                    'Approved On',
                    DateFormat(
                      'MMM dd, yyyy • hh:mm a',
                    ).format((data['approvedAt'] as Timestamp).toDate()),
                  ),
                if (rejectionReason != null) ...[
                  const Divider(),
                  const Text(
                    'Rejection Reason:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rejectionReason,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                if (data['remarks'] != null &&
                    data['remarks'].toString().isNotEmpty) ...[
                  const Divider(),
                  const Text(
                    'Remarks:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(data['remarks']),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatReason(String reason) {
    switch (reason) {
      case 'withdrawal':
        return 'Withdraw Funds';
      case 'relocating':
        return 'Relocating';
      case 'deceased':
        return 'Deceased (Next of Kin)';
      default:
        return 'Other';
    }
  }
}
