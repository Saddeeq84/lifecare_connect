// Household Wallet Screen
// Manages household wallet with fund feature and transaction history

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class HouseholdWalletScreen extends StatefulWidget {
  final String householdId;
  final String householdName;

  const HouseholdWalletScreen({
    super.key,
    required this.householdId,
    required this.householdName,
  });

  @override
  State<HouseholdWalletScreen> createState() => _HouseholdWalletScreenState();
}

class _HouseholdWalletScreenState extends State<HouseholdWalletScreen> {
  double _balance = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  bool _showAllTransactions = false;

  // Payment state variables
  String? _lastPaymentRef;
  double? _lastPaymentAmount;
  String? _lastPaymentDescription;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() => _isLoading = true);
    try {
      // Load wallet balance
      final walletDoc = await FirebaseFirestore.instance
          .collection('household_wallets')
          .doc(widget.householdId)
          .get();

      if (walletDoc.exists) {
        final data = walletDoc.data()!;
        _balance = (data['balance'] ?? 0).toDouble();

        // Load transactions from subcollection (new approach)
        // Note: We don't use .orderBy() to avoid requiring a composite index
        // We'll sort in memory instead
        final transactionsSnapshot = await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(widget.householdId)
            .collection('transactions')
            .limit(100) // Get last 100 transactions
            .get();

        _transactions = transactionsSnapshot.docs.map((doc) {
          final tx = doc.data();
          return {
            'id': doc.id,
            'type': tx['type'] ?? 'unknown',
            'amount': (tx['amount'] ?? 0).toDouble(),
            'description': tx['description'] ?? 'No description',
            'timestamp': tx['timestamp'],
            'fundedBy': tx['fundedBy'],
            'patientName': tx['patientName'],
            'processedBy': tx['processedBy'],
            'status': tx['status'],
          };
        }).toList();

        // Sort transactions by timestamp in memory (descending - newest first)
        _transactions.sort((a, b) {
          final tsA = a['timestamp'];
          final tsB = b['timestamp'];
          if (tsA == null && tsB == null) return 0;
          if (tsA == null) return 1;
          if (tsB == null) return -1;
          if (tsA is Timestamp && tsB is Timestamp) {
            return tsB.compareTo(tsA); // Descending order
          }
          return 0;
        });

        // Also check for legacy transactions stored in array (backward compatibility)
        final legacyTxList = data['transactions'] as List<dynamic>? ?? [];
        if (legacyTxList.isNotEmpty) {
          final legacyTransactions = legacyTxList.map((tx) {
            return {
              'type': tx['type'] ?? 'unknown',
              'amount': (tx['amount'] ?? 0).toDouble(),
              'description': tx['description'] ?? 'No description',
              'timestamp': tx['timestamp'],
              'fundedBy': tx['fundedBy'],
            };
          }).toList();

          // Merge legacy transactions
          _transactions.addAll(legacyTransactions);

          // Sort by timestamp descending
          _transactions.sort((a, b) {
            final tsA = a['timestamp'];
            final tsB = b['timestamp'];
            if (tsA == null && tsB == null) return 0;
            if (tsA == null) return 1;
            if (tsB == null) return -1;
            if (tsA is Timestamp && tsB is Timestamp) {
              return tsB.compareTo(tsA);
            }
            return 0;
          });
        }

        setState(() => _isLoading = false);
      } else {
        // Create wallet if doesn't exist
        await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(widget.householdId)
            .set({
              'balance': 0.0,
              'householdName': widget.householdName,
              'createdAt': FieldValue.serverTimestamp(),
            });

        setState(() {
          _balance = 0.0;
          _transactions = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading wallet: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fundWallet() async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fund Household Wallet'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add funds to ${widget.householdName} wallet via Paystack',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (NGN)',
                  prefixIcon: Icon(Icons.money),
                  border: OutlineInputBorder(),
                  helperText: 'Payment will open in browser',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, {
                'amount': amount,
                'description': descriptionController.text.trim().isEmpty
                    ? 'Household wallet top-up'
                    : descriptionController.text.trim(),
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade800,
              foregroundColor: Colors.white,
            ),
            child: const Text('Proceed to Payment'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _initializePaystackPayment(result['amount'], result['description']);
    }
  }

  Future<void> _initializePaystackPayment(
    double amount,
    String description,
  ) async {
    print('💳 [Paystack] Initializing payment for household wallet...');
    print('   Household ID: ${widget.householdId}');
    print('   Household Name: ${widget.householdName}');
    print('   Amount: ₦${amount.toStringAsFixed(2)}');
    print('   Description: $description');

    final facilityEmail =
        'facility@lifecare.com'; // Default email for household funding
    final ref = DateTime.now().millisecondsSinceEpoch.toString();

    print('   Email: $facilityEmail');
    print('   Reference: $ref');

    _lastPaymentRef = ref;
    _lastPaymentAmount = amount;
    _lastPaymentDescription = description;

    try {
      final url = Uri.parse(
        'https://us-central1-lifecare-connect.cloudfunctions.net/paystackInitialize',
      );
      print('🌐 [Paystack] Calling Cloud Function: $url');

      final requestBody = {
        'email': facilityEmail,
        'amount': (amount * 100).toInt(), // Convert to kobo
        'reference': ref,
      };
      print('📤 [Paystack] Request body: $requestBody');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('📥 [Paystack] Response status: ${response.statusCode}');
      print('📥 [Paystack] Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        final authUrl = data['data']['authorization_url'];
        print('✅ [Paystack] Payment initialized successfully');
        print('🔗 [Paystack] Authorization URL: $authUrl');

        final uri = Uri.parse(authUrl);

        if (await canLaunchUrl(uri)) {
          print('🚀 [Paystack] Launching payment URL...');
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          print('✅ [Paystack] Payment URL launched');

          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Complete Payment'),
                content: const Text(
                  'Payment page has opened in your browser. After completing payment, click "Verify Payment" to credit the household wallet.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _verifyPaymentAndCreditWallet();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Verify Payment'),
                  ),
                ],
              ),
            );
          }
        } else {
          print('❌ [Paystack] Cannot launch URL: $authUrl');
          throw Exception('Could not launch payment URL');
        }
      } else {
        print('❌ [Paystack] Payment initialization failed');
        print('   Status: ${data['status']}');
        print('   Message: ${data['message']}');
        throw Exception(data['message'] ?? 'Failed to initialize payment');
      }
    } catch (e, stackTrace) {
      print('❌ [Paystack] Error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment initialization error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _verifyPaymentAndCreditWallet() async {
    if (_lastPaymentRef == null || _lastPaymentAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pending payment to verify'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final url = Uri.parse(
        'https://us-central1-lifecare-connect.cloudfunctions.net/paystackVerify',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'reference': _lastPaymentRef}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          data['status'] == true &&
          data['data']['status'] == 'success') {
        // Payment verified, now credit the household wallet
        await _creditHouseholdWallet(
          _lastPaymentAmount!,
          _lastPaymentDescription ?? 'Household wallet top-up',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment verified! ₦${_lastPaymentAmount!.toStringAsFixed(2)} credited to household wallet',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Clear payment state
        _lastPaymentRef = null;
        _lastPaymentAmount = null;
        _lastPaymentDescription = null;

        // Reload wallet
        await _loadWallet();
      } else {
        throw Exception('Payment verification failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment verification error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _creditHouseholdWallet(double amount, String description) async {
    final walletRef = FirebaseFirestore.instance
        .collection('household_wallets')
        .doc(widget.householdId);

    await walletRef.set({
      'balance': FieldValue.increment(amount),
      'householdName': widget.householdName,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Record transaction
    await walletRef.collection('transactions').add({
      'type': 'credit',
      'amount': amount,
      'description': description,
      'paymentMethod': 'paystack',
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'completed',
    });
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      return DateFormat('MMM dd, yyyy HH:mm').format(timestamp.toDate());
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final displayedTransactions = _showAllTransactions
        ? _transactions
        : _transactions.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Household Wallet'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWallet,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Card
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.teal.shade700,
                              Colors.teal.shade900,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.home,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.householdName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Available Balance',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'NGN ${_balance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Fund Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _fundWallet,
                        icon: const Icon(Icons.add_circle),
                        label: const Text(
                          'Fund Wallet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Transactions Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Transaction History',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_transactions.length > 5)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showAllTransactions = !_showAllTransactions;
                              });
                            },
                            child: Text(
                              _showAllTransactions ? 'Show Less' : 'View All',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_transactions.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No transactions yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayedTransactions.length,
                        itemBuilder: (context, index) {
                          final tx = displayedTransactions[index];
                          final isCredit = tx['type'] == 'credit';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: isCredit
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                                child: Icon(
                                  isCredit
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: isCredit
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                              title: Text(
                                tx['description'] ?? 'Transaction',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(_formatDate(tx['timestamp'])),
                                  if (tx['fundedBy'] != null)
                                    Text(
                                      'Funded by: ${tx['fundedBy']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  if (tx['patientName'] != null)
                                    Text(
                                      'Patient: ${tx['patientName']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  if (tx['processedBy'] != null)
                                    Text(
                                      'Processed by: ${tx['processedBy']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Text(
                                '${isCredit ? '+' : '-'}NGN ${tx['amount'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isCredit
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
