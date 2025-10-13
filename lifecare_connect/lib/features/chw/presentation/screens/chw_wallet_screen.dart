import '../../../shared/data/services/withdrawal_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/data/services/wallet_service.dart';

class ChwWalletScreen extends StatefulWidget {
  const ChwWalletScreen({super.key});

  @override
  State<ChwWalletScreen> createState() => _ChwWalletScreenState();
}

class _ChwWalletScreenState extends State<ChwWalletScreen> {
  List<Map<String, dynamic>> _withdrawals = [];

  Future<void> _loadWithdrawals() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final withdrawals = await WithdrawalService.getWithdrawals(user.uid);
    setState(() {
      _withdrawals = withdrawals;
    });
  }
  Future<void> _requestWithdrawal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_balance <= 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Insufficient Funds'),
          content: const Text('You do not have enough funds to withdraw.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    final amountController = TextEditingController();
    final bankController = TextEditingController();
    final accountNumberController = TextEditingController();
    final accountNameController = TextEditingController();
    String? errorText;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Withdraw Funds'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (NGN)'),
                  ),
                  TextField(
                    controller: bankController,
                    decoration: const InputDecoration(labelText: 'Bank Name'),
                  ),
                  TextField(
                    controller: accountNumberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Account Number'),
                  ),
                  TextField(
                    controller: accountNameController,
                    decoration: const InputDecoration(labelText: 'Account Name'),
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(errorText!, style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final amt = double.tryParse(amountController.text);
                  if (amt == null || amt <= 0) {
                    setState(() => errorText = 'Enter a valid amount');
                  } else if (amt > _balance) {
                    setState(() => errorText = 'Amount exceeds wallet balance');
                  } else if (bankController.text.isEmpty || accountNumberController.text.isEmpty || accountNameController.text.isEmpty) {
                    setState(() => errorText = 'All fields are required');
                  } else {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('Request Withdrawal'),
              ),
            ],
          ),
        );
      },
    );
    if (result == true) {
      final amt = double.tryParse(amountController.text)!;
      await WithdrawalService.requestWithdrawal(
        userId: user.uid,
        amount: amt,
        bankName: bankController.text,
        accountNumber: accountNumberController.text,
        accountName: accountNameController.text,
        role: 'chw',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Withdrawal request submitted!'), backgroundColor: Colors.green),
        );
      }
    }
  }
  double _balance = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  _loadWithdrawals();
  }

  Future<void> _loadWallet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final balance = await WalletService.getBalance(userId: user.uid);
    final txs = await WalletService.getTransactions(userId: user.uid);
    setState(() {
      _balance = balance;
      _transactions = txs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _requestWithdrawal,
        icon: const Icon(Icons.account_balance),
        label: const Text('Withdraw'),
        backgroundColor: Colors.teal,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.teal.shade50,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Wallet Balance', style: TextStyle(fontSize: 18, color: Colors.teal)),
                      const SizedBox(height: 8),
                      Text('₦${_balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _transactions.isEmpty
                      ? const Center(child: Text('No transactions yet.'))
                      : ListView.builder(
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final tx = _transactions[index];
                            return ListTile(
                              leading: Icon(
                                tx['type'] == 'fund' || tx['type'].toString().contains('earning')
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: tx['type'] == 'fund' || tx['type'].toString().contains('earning')
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              title: Text(tx['description'] ?? ''),
                              subtitle: Text(tx['timestamp'] != null ? tx['timestamp'].toDate().toString() : ''),
                              trailing: Text(
                                '${tx['type'] == 'fund' || tx['type'].toString().contains('earning') ? '+' : '-'}₦${tx['amount'].toString()}',
                                style: TextStyle(
                                  color: tx['type'] == 'fund' || tx['type'].toString().contains('earning') ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const Divider(height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Withdrawal Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: _withdrawals.isEmpty
                      ? const Center(child: Text('No withdrawal requests yet.'))
                      : ListView.builder(
                          itemCount: _withdrawals.length,
                          itemBuilder: (context, index) {
                            final wd = _withdrawals[index];
                            return ListTile(
                              leading: const Icon(Icons.account_balance),
                              title: Text('₦${wd['amount']} to ${wd['bankName']}'),
                              subtitle: Text('Acct: ${wd['accountNumber']} (${wd['accountName']})\nStatus: ${wd['status']}'),
                              trailing: wd['requestedAt'] != null ? Text(wd['requestedAt'].toDate().toString(), style: const TextStyle(fontSize: 12)) : null,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
