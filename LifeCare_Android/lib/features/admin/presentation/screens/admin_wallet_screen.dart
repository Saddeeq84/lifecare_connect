import '../../../shared/data/services/withdrawal_service.dart';
import '../../../shared/data/services/otp_service.dart';
import '../../../shared/presentation/widgets/otp_verification_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/data/services/wallet_service.dart';
import '../../../../core/utils/nigerian_banks.dart';

class AdminWalletScreen extends StatefulWidget {
  const AdminWalletScreen({super.key});

  @override
  State<AdminWalletScreen> createState() => _AdminWalletScreenState();
}

class _AdminWalletScreenState extends State<AdminWalletScreen> {
  // State variables - declare at the top
  double _balance = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _withdrawals = [];
  bool _loading = true;
  final String _adminWalletId = 'admin_wallet';
  bool _expandedTransactions = false;
  bool _expandedWithdrawals = false;

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _loadWithdrawals();
  }

  Future<void> _loadWallet() async {
    final balance = await WalletService.getBalance(userId: _adminWalletId);
    final txs = await WalletService.getTransactions(userId: _adminWalletId);
    setState(() {
      _balance = balance;
      _transactions = txs;
      _loading = false;
    });
  }

  Future<void> _loadWithdrawals() async {
    final withdrawals = await WithdrawalService.getWithdrawals(_adminWalletId);
    setState(() {
      _withdrawals = withdrawals;
    });
  }

  Future<Map<String, dynamic>?> _showWithdrawalConfirmationDialog(
    double amount,
    String bankName,
    String accountNumber,
    String accountName,
    String userPhone,
    String userName,
    String userId,
  ) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Confirm Withdrawal'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please confirm your withdrawal details:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.money, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text('Amount: ₦${amount.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Bank: $bankName')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.numbers, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text('Account: $accountNumber'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.purple, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Name: $accountName')),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: Colors.amber.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This action cannot be undone. Please verify your details carefully.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSending
                    ? null
                    : () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSending
                    ? null
                    : () async {
                        setState(() => isSending = true);
                        try {
                          final result = await OTPService.sendWithdrawalOTP(
                            userId: userId,
                            userName: userName,
                            phone: userPhone,
                            amount: amount,
                            accountName: accountName,
                            accountNumber: accountNumber,
                            bankName: bankName,
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop(result);
                          }
                        } catch (e) {
                          setState(() => isSending = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to send OTP: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Send OTP Code'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _requestWithdrawal() async {
    if (_balance <= 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Insufficient Funds'),
          content: const Text('You do not have enough funds to withdraw.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final amountController = TextEditingController();
    String? selectedBank;
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (NGN)',
                      prefixIcon: Icon(Icons.money),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedBank,
                    decoration: const InputDecoration(
                      labelText: 'Select Bank',
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                    items: NigerianBanks.getBankNames()
                        .map(
                          (bank) =>
                              DropdownMenuItem(value: bank, child: Text(bank)),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => selectedBank = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: accountNumberController,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Account Number',
                      prefixIcon: Icon(Icons.numbers),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: accountNameController,
                    decoration: const InputDecoration(
                      labelText: 'Account Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amt = double.tryParse(amountController.text);
                  if (amt == null || amt <= 0) {
                    setState(() => errorText = 'Enter a valid amount');
                  } else if (amt > _balance) {
                    setState(() => errorText = 'Amount exceeds wallet balance');
                  } else if (selectedBank == null ||
                      accountNumberController.text.isEmpty ||
                      accountNameController.text.isEmpty) {
                    setState(() => errorText = 'All fields are required');
                  } else if (accountNumberController.text.length != 10) {
                    setState(
                      () => errorText = 'Account number must be 10 digits',
                    );
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
    if (result == true && selectedBank != null) {
      final amt = double.tryParse(amountController.text)!;
      final bankCode = NigerianBanks.getBankCode(selectedBank!);

      if (bankCode == null || bankCode.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid bank selection'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get user's phone for Firebase Phone Auth OTP (do this BEFORE showing confirmation)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String userPhone = '';
      String userName = accountNameController.text;

      try {
        // Get the currently logged-in admin's info instead of the wallet ID
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          userPhone = userData['phone'] ?? userData['phoneNumber'] ?? '';
          userName =
              userData['fullName'] ??
              userData['name'] ??
              accountNameController.text;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to fetch user data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (userPhone.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Phone number not found. Please update your profile.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show confirmation dialog with OTP sending
      final otpResult = await _showWithdrawalConfirmationDialog(
        amt,
        selectedBank!,
        accountNameController.text,
        accountNumberController.text,
        userPhone,
        userName,
        _adminWalletId,
      );

      if (otpResult == null) return; // User cancelled

      // Show OTP verification dialog with verificationId
      if (!mounted) return;
      final otpVerified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => OTPVerificationDialog(
          otpId: otpResult['otpId'],
          verificationId: otpResult['verificationId'],
          amount: amt,
          accountName: accountNameController.text,
          accountNumber: accountNumberController.text,
          bankName: selectedBank!,
          phoneNumber: userPhone,
          onVerify: (otpId, code, [verificationId]) =>
              OTPService.verifyWithdrawalOTP(
                otpId: otpId,
                otp: code,
                verificationId: verificationId ?? otpResult['verificationId'],
              ),
          onResend: (otpId) => OTPService.resendWithdrawalOTP(otpId: otpId),
        ),
      );

      if (otpVerified != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Withdrawal cancelled - OTP verification failed'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // OTP verified, proceed with withdrawal
      // Show processing dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing withdrawal...'),
                SizedBox(height: 8),
                Text(
                  'Auto-approving and initiating payment',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }

      try {
        print('🔄 [ADMIN WITHDRAWAL] Starting withdrawal request...');
        print('   Amount: ₦$amt');
        print('   Bank: $selectedBank ($bankCode)');
        print('   Account: ${accountNumberController.text}');

        await WithdrawalService.requestWithdrawal(
          userId: _adminWalletId,
          amount: amt,
          bankName: selectedBank!,
          bankCode: bankCode,
          accountNumber: accountNumberController.text,
          accountName: accountNameController.text,
          role: 'admin',
        );

        print('✅ [ADMIN WITHDRAWAL] Withdrawal request completed successfully');

        // For admin, auto-process the withdrawal immediately
        // Get the newly created withdrawal ID
        final withdrawals = await WithdrawalService.getWithdrawals(
          _adminWalletId,
        );
        if (withdrawals.isNotEmpty) {
          final latestWithdrawal = withdrawals.first;
          final withdrawalId = latestWithdrawal['id'] ?? '';

          // Trigger payout immediately for admin
          final payoutResult = await WithdrawalService.payoutWithdrawal(
            withdrawalId: withdrawalId,
            userId: _adminWalletId,
            amount: amt,
            accountNumber: accountNumberController.text,
            bankCode: bankCode,
            accountName: accountNameController.text,
          );

          if (mounted) {
            Navigator.of(context).pop(); // Close processing dialog

            if (payoutResult['success'] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '✅ Withdrawal processed and wallet debited successfully!',
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 5),
                ),
              );
            } else {
              final error = payoutResult['error'] ?? 'Unknown error';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '❌ Withdrawal created but payout failed: $error',
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 8),
                ),
              );
            }
          }
        } else {
          if (mounted) {
            Navigator.of(context).pop(); // Close processing dialog
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Withdrawal created but ID not found'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e, stackTrace) {
        print('❌ [ADMIN WITHDRAWAL] Withdrawal failed: $e');
        print('   Stack trace: $stackTrace');

        String errorMessage = 'Withdrawal failed';
        if (e.toString().contains('Insufficient') ||
            e.toString().contains('balance')) {
          errorMessage =
              'Insufficient Paystack balance. Please fund your Paystack account.';
        } else if (e.toString().contains('bank') ||
            e.toString().contains('account')) {
          errorMessage =
              'Invalid bank account details. Please verify your account information.';
        } else if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          errorMessage =
              'Network error. Please check your connection and try again.';
        } else if (e.toString().contains('firebase') ||
            e.toString().contains('functions')) {
          errorMessage =
              'Service error. Please try again later or contact support.';
        } else {
          errorMessage = 'Withdrawal failed: ${e.toString()}';
        }

        if (mounted) {
          Navigator.of(context).pop(); // Close processing dialog

          // Show error in a dialog for better visibility
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  const Text('Withdrawal Failed'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(errorMessage),
                  const SizedBox(height: 16),
                  const Text(
                    'What to do:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Check your Paystack balance\n'
                    '2. Verify your bank account details\n'
                    '3. Ensure you have stable internet\n'
                    '4. Try again in a few minutes',
                    style: TextStyle(fontSize: 13),
                  ),
                  if (e.toString().length < 200) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Technical details:\n${e.toString()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
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
      }

      if (mounted) {
        await _loadWallet(); // Reload to show updated balance
        await _loadWithdrawals(); // Reload withdrawal history
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _requestWithdrawal,
              icon: const Icon(Icons.account_balance),
              label: const Text('Withdraw'),
              backgroundColor: Colors.indigo,
            ),
            body: ListView(
              children: [
                // Balance Card
                Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade600, Colors.indigo.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin Wallet Balance',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₦${_balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_transactions.length} transactions',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Transactions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                _transactions.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: Text('No transactions yet.')),
                      )
                    : Column(
                        children: [
                          ...(_expandedTransactions
                                  ? _transactions
                                  : (_transactions.length > 10
                                        ? _transactions.take(10)
                                        : _transactions))
                              .map((tx) {
                                final ts = tx['timestamp'];
                                final date = ts is DateTime
                                    ? ts
                                    : ts is Timestamp
                                    ? ts.toDate()
                                    : null;
                                return ListTile(
                                  leading: Icon(
                                    tx['type'] == 'fund' ||
                                            tx['type'] == 'admin_commission'
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color:
                                        tx['type'] == 'fund' ||
                                            tx['type'] == 'admin_commission'
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  title: Text(tx['description'] ?? ''),
                                  subtitle: Text(
                                    date != null
                                        ? date.toString().substring(0, 16)
                                        : '',
                                  ),
                                  trailing: Text(
                                    '${tx['type'] == 'fund' || tx['type'] == 'admin_commission' ? '+' : '-'}₦${tx['amount'].toString()}',
                                    style: TextStyle(
                                      color:
                                          tx['type'] == 'fund' ||
                                              tx['type'] == 'admin_commission'
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }),
                          if (_transactions.length > 10)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _expandedTransactions =
                                        !_expandedTransactions;
                                  });
                                },
                                child: Text(
                                  _expandedTransactions
                                      ? 'View Less'
                                      : 'View More',
                                ),
                              ),
                            ),
                        ],
                      ),
                const Divider(height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Withdrawal History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                _withdrawals.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                'No withdrawal history yet.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          ...(_expandedWithdrawals
                                  ? _withdrawals
                                  : _withdrawals.take(10))
                              .map((wd) {
                                final amount = wd['amount'] is int
                                    ? (wd['amount'] as int).toDouble()
                                    : (wd['amount'] as double);
                                final status = wd['status'] ?? 'approved';
                                final requestedAt = wd['requestedAt'];
                                final completedAt = wd['completedAt'];
                                final approvedAt = wd['approvedAt'];

                                // For admin: status is either 'approved' or 'completed' (show as processed)
                                // Rejected shouldn't happen for admin
                                Color statusColor;
                                String statusText;
                                IconData statusIcon;

                                if (status == 'completed') {
                                  statusColor = Colors.green;
                                  statusText = 'Processed';
                                  statusIcon = Icons.check_circle;
                                } else if (status == 'approved') {
                                  // Admin withdrawals are auto-approved, show as processed
                                  statusColor = Colors.green;
                                  statusText = 'Processed';
                                  statusIcon = Icons.check_circle;
                                } else {
                                  // Fallback for any other status
                                  statusColor = Colors.grey;
                                  statusText = status.toUpperCase();
                                  statusIcon = Icons.info;
                                }

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header: Amount and Status
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '₦${amount.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.indigo,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: statusColor,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    statusIcon,
                                                    size: 16,
                                                    color: statusColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    statusText,
                                                    style: TextStyle(
                                                      color: statusColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Divider(height: 1),
                                        const SizedBox(height: 12),

                                        // Bank Details
                                        _buildInfoRow(
                                          icon: Icons.account_balance,
                                          label: 'Bank',
                                          value: wd['bankName'] ?? 'N/A',
                                        ),
                                        const SizedBox(height: 8),
                                        _buildInfoRow(
                                          icon: Icons.numbers,
                                          label: 'Account',
                                          value: wd['accountNumber'] ?? 'N/A',
                                        ),
                                        const SizedBox(height: 8),
                                        _buildInfoRow(
                                          icon: Icons.person,
                                          label: 'Name',
                                          value: wd['accountName'] ?? 'N/A',
                                        ),
                                        const SizedBox(height: 8),
                                        _buildInfoRow(
                                          icon: Icons.calendar_today,
                                          label: 'Requested',
                                          value: requestedAt != null
                                              ? _formatDate(
                                                  requestedAt.toDate(),
                                                )
                                              : (approvedAt != null
                                                    ? _formatDate(
                                                        approvedAt.toDate(),
                                                      )
                                                    : 'N/A'),
                                        ),

                                        // Show completion date
                                        if (completedAt != null) ...[
                                          const SizedBox(height: 8),
                                          _buildInfoRow(
                                            icon: Icons.check,
                                            label: 'Processed',
                                            value: _formatDate(
                                              completedAt.toDate(),
                                            ),
                                            valueColor: Colors.green,
                                          ),
                                        ] else if (approvedAt != null) ...[
                                          const SizedBox(height: 8),
                                          _buildInfoRow(
                                            icon: Icons.check,
                                            label: 'Processed',
                                            value: _formatDate(
                                              approvedAt.toDate(),
                                            ),
                                            valueColor: Colors.green,
                                          ),
                                        ],

                                        // Show wallet deduction confirmation
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.green.shade200,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.account_balance_wallet,
                                                color: Colors.green.shade700,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Wallet debited successfully',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        Colors.green.shade900,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          if (_withdrawals.length > 10)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _expandedWithdrawals =
                                        !_expandedWithdrawals;
                                  });
                                },
                                child: Text(
                                  _expandedWithdrawals
                                      ? 'View Less'
                                      : 'View More',
                                ),
                              ),
                            ),
                        ],
                      ),
              ],
            ),
          );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
