import '../../../shared/data/services/withdrawal_service.dart';
import '../../../shared/data/services/otp_service.dart';
import '../../../shared/presentation/widgets/otp_verification_dialog.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/data/services/wallet_service.dart';
import '../../../../core/utils/nigerian_banks.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lifecare_connect/utils/web_utils.dart';

class ChwWalletScreen extends StatefulWidget {
  const ChwWalletScreen({super.key});

  @override
  State<ChwWalletScreen> createState() => _ChwWalletScreenState();
}

class _ChwWalletScreenState extends State<ChwWalletScreen> {
  // State variables - declare at the top
  double _balance = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _withdrawals = [];
  bool _loading = true;
  bool _expandedTransactions = false;
  bool _expandedWithdrawals = false;
  String? _lastPaymentRef;
  double? _lastPaymentAmount;

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

  Future<void> _loadWithdrawals() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final withdrawals = await WithdrawalService.getWithdrawals(user.uid);
    setState(() {
      _withdrawals = withdrawals;
    });
  }

  Future<void> _fundWallet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add money to your wallet to book consultations with doctors.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (NGN)',
                prefixIcon: Icon(Icons.money),
                border: OutlineInputBorder(),
              ),
            ),
          ],
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
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (amount == null) return;

    final email = user.email ?? 'noemail@example.com';
    final ref = DateTime.now().millisecondsSinceEpoch.toString();
    _lastPaymentRef = ref;
    _lastPaymentAmount = amount;

    try {
      // Call your backend endpoint to initialize payment
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
          if (mounted) {
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
                    child: const Text('I have paid'),
                  ),
                ],
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to open payment page: ${e.toString()}'),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: () async {
                    try {
                      await openWebTab(authUrl);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payment page opened successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (retryError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Still failed: $retryError'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          }
          return; // Don't continue if opening URL failed
        }

        if (mounted) {
          // Automatically verify and credit wallet
          await _verifyPayment();
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
        // Credit wallet using WalletService
        try {
          await WalletService.fundWallet(
            amount,
            description: 'Wallet funded via Paystack',
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Payment verified and wallet credited with ₦${amount.toStringAsFixed(2)}!',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
          await _loadWallet(); // Reload wallet balance
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
              content: Text('Payment verification failed: ${data['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                        // Send OTP directly from user button press (maintains user interaction context for reCAPTCHA)
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
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
      String userPhone = '';
      String userName = accountNameController.text;

      try {
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
        accountNumberController.text,
        accountNameController.text,
        userPhone,
        userName,
        user.uid,
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
      try {
        print('🔄 [CHW WITHDRAWAL] Starting withdrawal request...');
        print('   User ID: ${user.uid}');
        print('   Amount: ₦$amt');
        print('   Bank: $selectedBank ($bankCode)');
        print('   Account: ${accountNumberController.text}');

        await WithdrawalService.requestWithdrawal(
          userId: user.uid,
          amount: amt,
          bankName: selectedBank!,
          bankCode: bankCode,
          accountNumber: accountNumberController.text,
          accountName: accountNameController.text,
          role: 'chw',
        );

        print('✅ [CHW WITHDRAWAL] Withdrawal request completed successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Withdrawal request submitted successfully! Pending admin approval.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
          // Reload wallet data to reflect the deduction
          _loadWallet();
          _loadWithdrawals();
        }
      } catch (e, stackTrace) {
        print('❌ [CHW WITHDRAWAL] Withdrawal failed: $e');
        print('   Stack trace: $stackTrace');

        String errorMessage = 'Withdrawal request failed';
        if (e.toString().contains('Insufficient')) {
          errorMessage = 'Insufficient balance in wallet';
        } else if (e.toString().contains('bank')) {
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
                    '1. Check your wallet balance\n'
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHW Wallet'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: _fundWallet,
              icon: const Icon(Icons.add_circle, size: 20),
              label: const Text('Fund Wallet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.teal.shade700,
                elevation: 2,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ],
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
                      const Text(
                        'Wallet Balance',
                        style: TextStyle(fontSize: 18, color: Colors.teal),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₦${_balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Transactions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _transactions.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: Text('No transactions yet.'),
                              ),
                            )
                          : Column(
                              children: [
                                ...(_expandedTransactions
                                        ? _transactions
                                        : _transactions.take(10))
                                    .map((tx) {
                                      final type = tx['type']?.toString() ?? '';
                                      final isCredit =
                                          type == 'fund' ||
                                          type.contains('earning');
                                      final ts = tx['timestamp'];
                                      final date = ts is DateTime
                                          ? ts
                                          : ts is Timestamp
                                          ? ts.toDate()
                                          : null;
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
                                          tx['description']?.toString() ?? '',
                                        ),
                                        subtitle: Text(
                                          date != null
                                              ? date.toString().substring(0, 16)
                                              : '',
                                        ),
                                        trailing: Text(
                                          '${isCredit ? '+' : '-'}₦${tx['amount']?.toString() ?? '0'}',
                                          style: TextStyle(
                                            color: isCredit
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
                          'Withdrawal Requests',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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
                                    Icon(
                                      Icons.history,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'No withdrawal requests yet.',
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
                                      final status = wd['status'] ?? 'pending';
                                      final requestedAt = wd['requestedAt'];
                                      final completedAt = wd['completedAt'];
                                      final approvedAt = wd['approvedAt'];

                                      // Determine status display
                                      Color statusColor;
                                      String statusText;
                                      IconData statusIcon;

                                      switch (status) {
                                        case 'pending':
                                          statusColor = Colors.orange;
                                          statusText = 'Pending';
                                          statusIcon = Icons.hourglass_empty;
                                          break;
                                        case 'approved':
                                          statusColor = Colors.blue;
                                          statusText = 'Approved';
                                          statusIcon =
                                              Icons.check_circle_outline;
                                          break;
                                        case 'completed':
                                          statusColor = Colors.green;
                                          statusText = 'Processed';
                                          statusIcon = Icons.check_circle;
                                          break;
                                        case 'rejected':
                                          statusColor = Colors.red;
                                          statusText = 'Rejected';
                                          statusIcon = Icons.cancel;
                                          break;
                                        default:
                                          statusColor = Colors.grey;
                                          statusText = status.toUpperCase();
                                          statusIcon = Icons.info;
                                      }

                                      return Card(
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
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
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    '₦${amount.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.teal,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: statusColor
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      border: Border.all(
                                                        color: statusColor,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          statusIcon,
                                                          size: 16,
                                                          color: statusColor,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
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
                                                value:
                                                    wd['accountNumber'] ??
                                                    'N/A',
                                              ),
                                              const SizedBox(height: 8),
                                              _buildInfoRow(
                                                icon: Icons.person,
                                                label: 'Name',
                                                value:
                                                    wd['accountName'] ?? 'N/A',
                                              ),
                                              const SizedBox(height: 8),
                                              _buildInfoRow(
                                                icon: Icons.calendar_today,
                                                label: 'Requested',
                                                value: requestedAt != null
                                                    ? _formatDate(
                                                        requestedAt.toDate(),
                                                      )
                                                    : 'N/A',
                                              ),

                                              // Show completion/approval date if applicable
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
                                              ] else if (approvedAt != null &&
                                                  status == 'approved') ...[
                                                const SizedBox(height: 8),
                                                _buildInfoRow(
                                                  icon: Icons.thumb_up,
                                                  label: 'Approved',
                                                  value: _formatDate(
                                                    approvedAt.toDate(),
                                                  ),
                                                  valueColor: Colors.blue,
                                                ),
                                              ],
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
