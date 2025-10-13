import 'package:flutter/material.dart';
import 'package:lifecare_connect/features/shared/data/services/wallet_service.dart';
// import 'dart:html' as html; // Not needed for inline payment
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lifecare_connect/utils/web_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PatientWalletScreen extends StatefulWidget {
  const PatientWalletScreen({super.key});

  @override
  State<PatientWalletScreen> createState() => _PatientWalletScreenState();
}

class _PatientWalletScreenState extends State<PatientWalletScreen> {
  bool get _isLoggedIn => WalletService.currentUserId.isNotEmpty;
  String? _lastPaymentRef;
  double? _lastPaymentAmount;
  double? _balance;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _transactions = [];


  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() { _loading = true; _error = null; });
    try {
      debugPrint('Loading wallet for user...');
      final bal = await WalletService.getBalance();
      debugPrint('Wallet balance: $bal');
      final txs = await WalletService.getTransactions();
      debugPrint('Wallet transactions: $txs');
      setState(() {
        _balance = bal;
        _transactions = txs;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Error loading wallet: $e\n$st');
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _fundWallet() async {
    if (!_isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to fund your wallet.'), backgroundColor: Colors.red),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
    final email = FirebaseAuth.instance.currentUser?.email ?? 'noemail@example.com';
    final ref = DateTime.now().millisecondsSinceEpoch.toString();
    _lastPaymentRef = ref;
    _lastPaymentAmount = amount;
    try {
      // Call your backend endpoint instead of Paystack directly
      final url = Uri.parse('https://us-central1-lifecare-connect.cloudfunctions.net/paystackInitialize');
      final headers = {
        'Content-Type': 'application/json',
      };
      final body = jsonEncode({
        'email': email,
        'amount': (amount * 100).toInt(),
        'reference': ref,
      });
      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        final authUrl = data['data']['authorization_url'];
        openWebTab(authUrl);
        // Show dialog to prompt user to confirm after payment
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Complete Payment'),
            content: const Text('After completing the payment in the new tab, click the button below to verify and credit your wallet.'),
            actions: [
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to initialize payment: ${data['message']}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _verifyPayment() async {
    if (_lastPaymentRef == null || _lastPaymentAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payment to verify.'), backgroundColor: Colors.red),
      );
      return;
    }
    final ref = _lastPaymentRef!;
    final amount = _lastPaymentAmount!;
    final url = Uri.parse('https://us-central1-lifecare-connect.cloudfunctions.net/paystackVerify');
    final headers = {
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({'reference': ref});
    try {
      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true && data['data']['status'] == 'success') {
        // Optionally check amount, currency, etc.
        try {
          debugPrint('Funding wallet with amount: $amount');
          await WalletService.fundWallet(amount);
          debugPrint('Wallet funded successfully.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment verified and wallet credited!'), backgroundColor: Colors.green),
            );
          }
          await _loadWallet();
          _lastPaymentRef = null;
          _lastPaymentAmount = null;
        } catch (e, st) {
          debugPrint('Error funding wallet: $e\n$st');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error crediting wallet: $e'), backgroundColor: Colors.red),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment not successful: \\${data['data']?['gateway_response'] ?? data['message']}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification error: \\${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Wallet'), backgroundColor: Colors.teal),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _fundWallet,
        icon: const Icon(Icons.add_card),
        label: const Text('Fund Wallet'),
        backgroundColor: Colors.teal,
        tooltip: 'Paystack web payment will open in a new tab. After payment, contact support to credit your wallet.',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_lastPaymentRef != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.verified, color: Colors.white),
                          label: const Text('Verify Payment'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
                            const Text('Wallet Balance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              _balance == null ? '--' : '₦${_balance!.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add_circle),
                              label: const Text('Fund Wallet'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                              onPressed: _fundWallet,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: _transactions.isEmpty
                          ? const Center(child: Text('No transactions yet.'))
                          : ListView.builder(
                              itemCount: _transactions.length,
                              itemBuilder: (context, i) {
                                final tx = _transactions[i];
                                final ts = tx['timestamp'];
                                final date = ts is DateTime
                                    ? ts
                                    : ts is Timestamp
                                        ? ts.toDate()
                                        : null;
                                return ListTile(
                                  leading: Icon(
                                    tx['type'] == 'fund' ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: tx['type'] == 'fund' ? Colors.green : Colors.red,
                                  ),
                                  title: Text('${tx['type'] == 'fund' ? 'Funded' : 'Deducted'} ₦${tx['amount']}'),
                                  subtitle: Text('${date != null ? date.toString().substring(0, 16) : ''}\n${tx['description'] ?? ''}'),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
