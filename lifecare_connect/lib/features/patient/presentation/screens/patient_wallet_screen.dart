import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lifecare_connect/features/shared/data/services/wallet_service.dart';
// import 'dart:html' as html; // Not needed for inline payment
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientWalletScreen extends StatefulWidget {
  const PatientWalletScreen({super.key});

  @override
  State<PatientWalletScreen> createState() => _PatientWalletScreenState();
}

class _PatientWalletScreenState extends State<PatientWalletScreen> {
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
      final bal = await WalletService.getBalance();
      final txs = await WalletService.getTransactions();
      setState(() {
        _balance = bal;
        _transactions = txs;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _fundWallet() async {
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
    final email = 'user@email.com'; // TODO: Use real user email
    final ref = DateTime.now().millisecondsSinceEpoch.toString();
    _lastPaymentRef = ref;
    _lastPaymentAmount = amount;
    try {
      final url = Uri.parse('https://api.paystack.co/transaction/initialize');
      final headers = {
        'Authorization': 'Bearer ${dotenv.env['PAYSTACK_SECRET_KEY']}',
        'Content-Type': 'application/json',
      };
      final body = jsonEncode({
        'email': email,
        'amount': (amount * 100).toInt(),
        'reference': ref,
        // Optionally add 'callback_url': 'https://your-callback-url.com',
      });
      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        final authUrl = data['data']['authorization_url'];
        html.window.open(authUrl, '_blank');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Complete payment in the new tab. After success, contact support to credit your wallet.'), backgroundColor: Colors.orange),
          );
        }
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
    final url = Uri.parse('https://api.paystack.co/transaction/verify/$ref');
    final headers = {
      'Authorization': 'Bearer ${dotenv.env['PAYSTACK_SECRET_KEY']}',
      'Content-Type': 'application/json',
    };
    try {
      final response = await http.get(url, headers: headers);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true && data['data']['status'] == 'success') {
        // Optionally check amount, currency, etc.
        await WalletService.fundWallet(amount);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment verified and wallet credited!'), backgroundColor: Colors.green),
          );
        }
        _loadWallet();
        _lastPaymentRef = null;
        _lastPaymentAmount = null;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment not successful: ${data['data']?['gateway_response'] ?? data['message']}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification error: ${e.toString()}'), backgroundColor: Colors.red),
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
                              label: const Text('Fund Wallet (Test)'),
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
