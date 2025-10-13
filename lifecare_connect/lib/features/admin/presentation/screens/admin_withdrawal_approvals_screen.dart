import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lifecare_connect/features/shared/data/services/withdrawal_service.dart';

class AdminWithdrawalApprovalsScreen extends StatefulWidget {
  const AdminWithdrawalApprovalsScreen({super.key});

  @override
  State<AdminWithdrawalApprovalsScreen> createState() => _AdminWithdrawalApprovalsScreenState();
}

class _AdminWithdrawalApprovalsScreenState extends State<AdminWithdrawalApprovalsScreen> {
  final _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    final query = await _firestore.collection('withdrawals').where('status', isEqualTo: 'pending').orderBy('requestedAt', descending: true).get();
    setState(() {
      _pending = query.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      _loading = false;
    });
  }

  Future<void> _approve(String id) async {
    final wd = _pending.firstWhere((w) => w['id'] == id);
    // Mark as approved in Firestore
    await _firestore.collection('withdrawals').doc(id).update({'status': 'approved', 'approvedAt': FieldValue.serverTimestamp()});
    // Trigger payout
    try {
      final payoutResult = await WithdrawalService.payoutWithdrawal(
        withdrawalId: id,
        userId: wd['userId'],
        amount: wd['amount'] is int ? (wd['amount'] as int).toDouble() : wd['amount'],
        accountNumber: wd['accountNumber'],
        bankCode: wd['bankCode'] ?? '',
        accountName: wd['accountName'],
      );
      if (payoutResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout successful')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payout failed: \\${payoutResult['error'] ?? 'Unknown error'}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payout error: \\${e.toString()}')));
    }
    await _loadPending();
  }

  Future<void> _reject(String id) async {
    await _firestore.collection('withdrawals').doc(id).update({'status': 'rejected', 'rejectedAt': FieldValue.serverTimestamp()});
    await _loadPending();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Withdrawal Approvals'), backgroundColor: Colors.indigo),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pending.isEmpty
              ? const Center(child: Text('No pending withdrawal requests.'))
              : ListView.builder(
                  itemCount: _pending.length,
                  itemBuilder: (context, i) {
                    final wd = _pending[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.account_balance),
                        title: Text('₦${wd['amount']} to ${wd['bankName']}'),
                        subtitle: Text('Acct: ${wd['accountNumber']} (${wd['accountName']})\nRequested by: ${wd['userId']}\nRole: ${wd['role']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => _approve(wd['id']),
                              tooltip: 'Approve',
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _reject(wd['id']),
                              tooltip: 'Reject',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
