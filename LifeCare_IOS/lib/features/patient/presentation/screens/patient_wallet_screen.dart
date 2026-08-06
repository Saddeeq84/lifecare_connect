import 'package:flutter/material.dart';
import 'package:lifecare_connect/features/shared/data/services/wallet_service.dart';
// import 'dart:html' as html; // Not needed for inline payment
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:lifecare_connect/utils/web_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lifecare_connect/features/shared/presentation/widgets/offline_mode_indicator.dart';
import 'patient_refund_application_screen.dart';

class PatientWalletScreen extends StatefulWidget {
  const PatientWalletScreen({super.key});

  @override
  State<PatientWalletScreen> createState() => _PatientWalletScreenState();
}

class _PatientWalletScreenState extends State<PatientWalletScreen> {
  String _currentUserId = '';
  bool get _isLoggedIn => _currentUserId.isNotEmpty;
  String? _lastPaymentRef;
  double? _lastPaymentAmount;
  double? _balance;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _transactions = [];
  bool _showAllTransactions = false; // For "View More" functionality

  // Connectivity monitoring
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initializeUserId();
    _checkConnectivity();
    _listenToConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline =
            connectivity.isNotEmpty &&
            !connectivity.contains(ConnectivityResult.none);
      });
    }
  }

  void _listenToConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (mounted) {
        setState(() {
          _isOnline =
              results.isNotEmpty && !results.contains(ConnectivityResult.none);
        });
      }
    });
  }

  Future<void> _initializeUserId() async {
    final userId = await WalletService.getCurrentUserId();
    setState(() {
      _currentUserId = userId;
    });
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    if (_currentUserId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Please log in to view your wallet';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      print('🔍 Loading wallet for user ID: $_currentUserId');
      final bal = await WalletService.getBalance(userId: _currentUserId);
      print('💰 Balance loaded: ₦$bal');
      final txs = await WalletService.getTransactions(userId: _currentUserId);
      print('📋 Transactions loaded: ${txs.length} transactions');
      setState(() {
        _balance = bal;
        _transactions = txs;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading wallet: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fundWallet() async {
    // Check connectivity first
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment requires internet connection. Please connect and try again.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!_isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to fund your wallet.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // Show dialog to enter amount
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fund Wallet'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (NGN)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (amount == null) return;

    // Get user email from Firebase Auth or Firestore
    String email = FirebaseAuth.instance.currentUser?.email ?? '';

    if (email.isEmpty && _currentUserId.isNotEmpty) {
      // For Termii login users, get email from Firestore
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .get();
        email = userDoc.data()?['email'] ?? 'noemail@example.com';
      } catch (e) {
        email = 'noemail@example.com';
      }
    }

    if (email.isEmpty) {
      email = 'noemail@example.com';
    }

    final ref = DateTime.now().millisecondsSinceEpoch.toString();
    _lastPaymentRef = ref;
    _lastPaymentAmount = amount;
    try {
      // Call your backend endpoint instead of Paystack directly
      final url = Uri.parse(
        'https://us-central1-lifecare-connect.cloudfunctions.net/paystackInitialize',
      );
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'email': email,
        'amount': (amount * 100).toInt(),
        'reference': ref,
      });
      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        final authUrl = data['data']['authorization_url'];
        try {
          await openWebTab(authUrl);
          // Show dialog to prompt user to confirm after payment
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Complete Payment'),
              content: const Text(
                'The Paystack payment page has opened in your browser. After completing the payment, click the button below to verify and credit your wallet.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('I have paid'),
                ),
              ],
            ),
          );
          // Automatically verify and credit wallet
          await _verifyPayment();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to open payment page: ${e.toString()}'),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Copy URL',
                  onPressed: () {
                    // Option to copy URL manually if launching fails
                  },
                ),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to initialize payment: ${data['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _verifyPayment() async {
    // Check connectivity first
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment verification requires internet connection.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_lastPaymentRef == null || _lastPaymentAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No payment to verify.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final ref = _lastPaymentRef!;
    final amount = _lastPaymentAmount!;
    final url = Uri.parse(
      'https://us-central1-lifecare-connect.cloudfunctions.net/paystackVerify',
    );
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'reference': ref});
    try {
      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 &&
          data['status'] == true &&
          data['data']['status'] == 'success') {
        // Optionally check amount, currency, etc.
        try {
          await WalletService.fundWallet(amount);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment verified and wallet credited!'),
                backgroundColor: Colors.green,
              ),
            );
          }
          await _loadWallet();
          _lastPaymentRef = null;
          _lastPaymentAmount = null;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error crediting wallet: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment not successful: \\${data['data']?['gateway_response'] ?? data['message']}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: \\${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.monetization_on),
            tooltip: 'Apply Refund',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PatientRefundApplicationScreen(),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isOnline ? _fundWallet : null,
        icon: Icon(_isOnline ? Icons.add_card : Icons.wifi_off),
        label: Text(_isOnline ? 'Fund Wallet' : 'Offline'),
        backgroundColor: _isOnline ? Colors.teal : Colors.grey,
        tooltip: _isOnline
            ? 'Paystack web payment will open in a new tab. After payment, contact support to credit your wallet.'
            : 'Internet connection required for payments',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Offline Mode Indicator
                const OfflineModeIndicator(),

                if (_lastPaymentRef != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.verified, color: Colors.white),
                      label: const Text('Verify Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: _verifyPayment,
                    ),
                  ),
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wallet Balance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _balance == null
                              ? '--'
                              : '₦${_balance!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: Icon(
                            _isOnline ? Icons.add_circle : Icons.wifi_off,
                          ),
                          label: Text(_isOnline ? 'Fund Wallet' : 'Offline'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isOnline
                                ? Colors.teal
                                : Colors.grey.shade400,
                          ),
                          onPressed: _isOnline ? _fundWallet : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Recent Transactions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: _transactions.isEmpty
                      ? const Center(child: Text('No transactions yet.'))
                      : Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                itemCount: _showAllTransactions
                                    ? _transactions.length
                                    : (_transactions.length > 10
                                          ? 10
                                          : _transactions.length),
                                itemBuilder: (context, i) {
                                  final tx = _transactions[i];
                                  final ts = tx['timestamp'];
                                  final date = ts is DateTime
                                      ? ts
                                      : ts is Timestamp
                                      ? ts.toDate()
                                      : null;
                                  // Determine if transaction is credit (incoming) or debit (outgoing)
                                  final isCredit =
                                      tx['type'] == 'fund' ||
                                      tx['type'] == 'credit';

                                  String displayType;
                                  if (tx['type'] == 'fund') {
                                    displayType = 'Funded';
                                  } else if (tx['type'] == 'credit') {
                                    displayType = 'Refund';
                                  } else if (tx['type'] == 'deduct') {
                                    displayType = 'Deducted';
                                  } else {
                                    displayType = tx['type'].toString();
                                  }

                                  // Format date properly
                                  String dateStr = '';
                                  if (date != null) {
                                    dateStr = DateFormat(
                                      'dd/MM/yyyy HH:mm',
                                    ).format(date);
                                  }

                                  return ListTile(
                                    leading: Icon(
                                      isCredit
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                      color: isCredit
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    title: Text(
                                      '$displayType ₦${tx['amount']}',
                                    ),
                                    subtitle: Text(
                                      '$dateStr\n${tx['description'] ?? ''}',
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (_transactions.length > 10 &&
                                !_showAllTransactions)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showAllTransactions = true;
                                    });
                                  },
                                  icon: const Icon(Icons.expand_more),
                                  label: Text(
                                    'View More (${_transactions.length - 10} more)',
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.teal,
                                  ),
                                ),
                              ),
                            if (_showAllTransactions &&
                                _transactions.length > 10)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showAllTransactions = false;
                                    });
                                  },
                                  icon: const Icon(Icons.expand_less),
                                  label: const Text('View Less'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.teal,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
