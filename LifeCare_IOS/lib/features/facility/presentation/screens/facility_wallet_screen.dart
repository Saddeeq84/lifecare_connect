import 'package:flutter/material.dart';
import 'package:lifecare_connect/features/shared/data/services/wallet_service.dart';
import 'package:lifecare_connect/features/shared/data/services/withdrawal_service.dart';
import '../../../shared/data/services/otp_service.dart';
import '../../../shared/presentation/widgets/otp_verification_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:lifecare_connect/utils/web_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lifecare_connect/features/shared/presentation/widgets/offline_mode_indicator.dart';
import '../../../../core/utils/nigerian_banks.dart';
import 'facility_admin_refund_management_screen.dart';

class FacilityWalletScreen extends StatefulWidget {
  const FacilityWalletScreen({super.key});

  @override
  State<FacilityWalletScreen> createState() => _FacilityWalletScreenState();
}

class _FacilityWalletScreenState extends State<FacilityWalletScreen> {
  bool get _isLoggedIn => WalletService.currentUserId.isNotEmpty;
  String? _lastPaymentRef;
  double? _lastPaymentAmount;
  double? _balance;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _transactions = [];
  bool _showAllTransactions = false;
  String? _facilityType;

  // Connectivity monitoring
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool get _isLifecareInsurance {
    return _facilityType != null &&
        _facilityType!.toLowerCase().trim() == 'lifecare insurance';
  }

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _loadFacilityType();
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

  Future<void> _loadFacilityType() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (mounted) {
          setState(() {
            _facilityType = data?['type'] as String?;
          });
        }
      }
    } catch (e) {
      // Silently fail - facility type will remain null
    }
  }

  Future<void> _loadWallet() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bal = await WalletService.getBalance();
      final txs = await WalletService.getTransactions();
      setState(() {
        _balance = bal;
        _transactions = txs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fundOwnWallet() async {
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
        title: const Text('Top Up Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter amount to add to your facility wallet'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (NGN)',
                prefixText: '₦',
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
                if (value < 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Minimum funding amount is ₦100'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, value);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (amount == null) return;

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'noemail@example.com';
    final ref = 'FWALLET_${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _lastPaymentRef = ref;
      _lastPaymentAmount = amount;
    });

    try {
      // Call backend endpoint to initialize Paystack payment
      final url = Uri.parse(
        'https://us-central1-lifecare-connect.cloudfunctions.net/paystackInitialize',
      );
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'email': email,
        'amount': (amount * 100).toInt(), // Convert to kobo
        'reference': ref,
        'metadata': {'userId': user?.uid, 'purpose': 'Facility Wallet Funding'},
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
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Payment of ₦${amount.toStringAsFixed(2)} initiated.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'The Paystack payment page has opened in your browser. After completing the payment, click "Verify Payment" button below or use the checkmark icon in the app bar.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Reference: $ref',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                      Navigator.pop(context);
                      _verifyPayment();
                    },
                    child: const Text('Verify Payment'),
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
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to initialize payment: ${data['message'] ?? 'Unknown error'}',
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
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final ref = _lastPaymentRef!;
    final amount = _lastPaymentAmount!;

    try {
      final url = Uri.parse(
        'https://us-central1-lifecare-connect.cloudfunctions.net/paystackVerify',
      );
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({'reference': ref});

      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          data['status'] == true &&
          data['data']['status'] == 'success') {
        try {
          await WalletService.fundWallet(
            amount,
            description: 'Funded via Paystack',
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Payment verified! ₦${amount.toStringAsFixed(2)} added to your wallet.',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }

          setState(() {
            _lastPaymentRef = null;
            _lastPaymentAmount = null;
          });

          await _loadWallet();
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
                'Payment not successful: ${data['data']?['gateway_response'] ?? data['message']}',
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
            content: Text('Verification error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fundHousehold() async {
    // Check connectivity first
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Household funding requires internet connection.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    try {
      final householdsSnapshot = await FirebaseFirestore.instance
          .collection('households')
          .get();

      if (householdsSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No households found. Please create a household first.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final households = householdsSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      String? selectedHouseholdId;
      final amountController = TextEditingController();
      final descriptionController = TextEditingController();

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Fund Household Wallet'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select household and enter amount to fund'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedHouseholdId,
                    decoration: const InputDecoration(
                      labelText: 'Select Household',
                      border: OutlineInputBorder(),
                    ),
                    items: households.map((household) {
                      return DropdownMenuItem<String>(
                        value: household['id'],
                        child: Text(household['householdName'] ?? 'Unknown'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedHouseholdId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (NGN)',
                      prefixText: '₦',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Funded by facility admin',
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
                  if (selectedHouseholdId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a household'),
                      ),
                    );
                    return;
                  }

                  final amountText = amountController.text.trim();
                  if (amountText.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter an amount')),
                    );
                    return;
                  }

                  final amount = double.tryParse(amountText);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid amount'),
                      ),
                    );
                    return;
                  }

                  final household = households.firstWhere(
                    (h) => h['id'] == selectedHouseholdId,
                  );

                  Navigator.pop(context, {
                    'householdId': selectedHouseholdId,
                    'householdName': household['householdName'],
                    'amount': amount,
                    'description': descriptionController.text.trim().isEmpty
                        ? 'Funded by facility admin'
                        : descriptionController.text.trim(),
                  });
                },
                child: const Text('Fund Household'),
              ),
            ],
          ),
        ),
      );

      if (result == null) return;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final householdWalletRef = FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(result['householdId']);

        final snapshot = await transaction.get(householdWalletRef);

        double currentBalance = 0.0;
        if (snapshot.exists) {
          currentBalance = (snapshot.data()?['balance'] ?? 0).toDouble();
        }

        final newBalance = currentBalance + result['amount'];

        final newTransaction = {
          'type': 'credit',
          'amount': result['amount'],
          'description': result['description'],
          'fundedBy': 'Facility Admin',
          'timestamp': FieldValue.serverTimestamp(),
        };

        transaction.set(householdWalletRef, {
          'balance': newBalance,
          'householdName': result['householdName'],
          'updatedAt': FieldValue.serverTimestamp(),
          'transactions': FieldValue.arrayUnion([newTransaction]),
        }, SetOptions(merge: true));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully funded ${result['householdName']} with ₦${result['amount'].toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error funding household: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _requestWithdrawal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }

    final balance = _balance ?? 0.0;
    if (balance <= 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Insufficient Funds'),
          content: Text(
            'Wallet Balance: ₦${balance.toStringAsFixed(2)}\n\nYou need funds in your wallet to request a withdrawal.',
          ),
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

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Withdraw Funds'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Balance: ₦${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Withdrawal Amount',
                      prefixText: '₦',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedBank,
                    decoration: const InputDecoration(
                      labelText: 'Select Bank',
                      border: OutlineInputBorder(),
                    ),
                    items: NigerianBanks.banks.map((bank) {
                      return DropdownMenuItem(
                        value: bank['code'],
                        child: Text(bank['name']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedBank = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: accountNumberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Account Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: accountNameController,
                    decoration: const InputDecoration(
                      labelText: 'Account Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'As a facility, your withdrawal will be processed immediately and funds transferred to your account.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
                  if (amountController.text.isEmpty ||
                      selectedBank == null ||
                      accountNumberController.text.isEmpty ||
                      accountNameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all fields')),
                    );
                    return;
                  }

                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid amount')),
                    );
                    return;
                  }

                  if (amount > balance) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Insufficient balance')),
                    );
                    return;
                  }

                  Navigator.pop(context, {
                    'amount': amount,
                    'bankCode': selectedBank,
                    'accountNumber': accountNumberController.text.trim(),
                    'accountName': accountNameController.text.trim(),
                  });
                },
                child: const Text('Request Withdrawal'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      // Get bank name from bank code
      final bank = NigerianBanks.banks.firstWhere(
        (b) => b['code'] == result['bankCode'],
        orElse: () => {'name': 'Unknown Bank', 'code': result['bankCode']},
      );

      // Get user's phone for Firebase Phone Auth OTP
      String userPhone = '';
      String userName = result['accountName'];

      try {
        print('📋 [FACILITY WITHDRAWAL] Fetching user data for ${user.uid}');
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          userPhone = userData['phone'] ?? userData['phoneNumber'] ?? '';
          userName =
              userData['fullName'] ?? userData['name'] ?? result['accountName'];
          print(
            '✅ [FACILITY WITHDRAWAL] User data retrieved: $userName, Phone: ${userPhone.isEmpty ? "NOT FOUND" : userPhone}',
          );
        } else {
          print(
            '⚠️ [FACILITY WITHDRAWAL] User document not found in Firestore',
          );
        }
      } catch (e) {
        print('❌ [FACILITY WITHDRAWAL] Failed to fetch user data: $e');
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  const Text('Error'),
                ],
              ),
              content: Text(
                'Failed to fetch user data: ${e.toString()}\n\nPlease try again or contact support.',
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
        return;
      }

      if (userPhone.isEmpty) {
        print(
          '❌ [FACILITY WITHDRAWAL] Phone number not found for user ${user.uid}',
        );
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.phone_disabled, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  const Text('Phone Number Required'),
                ],
              ),
              content: const Text(
                'Your phone number is not found in your profile. '
                'A phone number is required for OTP verification during withdrawals.\n\n'
                'Please update your profile with your phone number and try again.',
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
        return;
      }

      // Show OTP sending dialog with button press
      if (!mounted) return;
      final otpResult = await showDialog<Map<String, dynamic>>(
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
                      Text('Amount: ₦${result['amount'].toStringAsFixed(2)}'),
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
                      Expanded(child: Text('Bank: ${bank['name']}')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.numbers, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text('Account: ${result['accountNumber']}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.purple, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Name: ${result['accountName']}')),
                    ],
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
                            print(
                              '📱 [FACILITY WITHDRAWAL] Sending OTP to $userPhone',
                            );
                            final otpRes = await OTPService.sendWithdrawalOTP(
                              userId: user.uid,
                              userName: userName,
                              phone: userPhone,
                              amount: result['amount'],
                              accountName: result['accountName'],
                              accountNumber: result['accountNumber'],
                              bankName: bank['name']!,
                            );
                            print(
                              '✅ [FACILITY WITHDRAWAL] OTP sent successfully: ${otpRes['otpId']}',
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop(otpRes);
                            }
                          } catch (e, stackTrace) {
                            print(
                              '❌ [FACILITY WITHDRAWAL] OTP sending failed: $e',
                            );
                            print('   Stack trace: $stackTrace');
                            setState(() => isSending = false);
                            if (context.mounted) {
                              String errorMessage = 'Failed to send OTP';
                              if (e.toString().contains('network') ||
                                  e.toString().contains('connection')) {
                                errorMessage =
                                    'Network error. Please check your internet connection.';
                              } else if (e.toString().contains('phone')) {
                                errorMessage =
                                    'Invalid phone number. Please update your profile.';
                              } else if (e.toString().contains('firebase') ||
                                  e.toString().contains('functions')) {
                                errorMessage =
                                    'Service temporarily unavailable. Please try again.';
                              } else {
                                errorMessage =
                                    'Failed to send OTP: ${e.toString()}';
                              }

                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('OTP Error'),
                                    ],
                                  ),
                                  content: Text(errorMessage),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
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

      if (otpResult == null) return; // User cancelled

      // Show OTP verification dialog with verificationId
      if (!mounted) return;
      final otpVerified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => OTPVerificationDialog(
          otpId: otpResult['otpId'],
          verificationId: otpResult['verificationId'],
          amount: result['amount'],
          accountName: result['accountName'],
          accountNumber: result['accountNumber'],
          bankName: bank['name']!,
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
        print('🔄 [FACILITY WITHDRAWAL] Starting withdrawal request...');
        print('   User ID: ${user.uid}');
        print('   Amount: ₦${result['amount']}');
        print('   Bank: ${bank['name']} (${result['bankCode']})');
        print('   Account: ${result['accountNumber']}');
        print('   Account Name: ${result['accountName']}');

        await WithdrawalService.requestWithdrawal(
          userId: user.uid,
          amount: result['amount'],
          bankCode: result['bankCode'],
          bankName: bank['name']!,
          accountNumber: result['accountNumber'],
          accountName: result['accountName'],
          role: 'facility',
        );

        print(
          '✅ [FACILITY WITHDRAWAL] Withdrawal request completed successfully',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Withdrawal processed successfully! Funds are being transferred to your bank account.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
          await _loadWallet();
        }
      } catch (e, stackTrace) {
        print('❌ [FACILITY WITHDRAWAL] Withdrawal failed: $e');
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

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facility Wallet'),
        backgroundColor: Colors.teal,
        actions: [
          if (_lastPaymentRef != null)
            IconButton(
              icon: const Icon(Icons.verified),
              tooltip: 'Verify Payment',
              onPressed: _verifyPayment,
            ),
          IconButton(
            icon: const Icon(Icons.approval),
            tooltip: 'Refund Approvals',
            onPressed: () async {
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User not logged in')),
                );
                return;
              }

              try {
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get();

                final adminName = userDoc.data()?['name'] ?? 'Admin';

                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FacilityAdminRefundManagementScreen(
                        facilityId: user.uid,
                        adminId: user.uid,
                        adminName: adminName,
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: _isOnline ? _fundOwnWallet : null,
            heroTag: 'fundWallet',
            icon: Icon(_isOnline ? Icons.add_card : Icons.wifi_off),
            label: Text(_isOnline ? 'Top Up Wallet' : 'Offline'),
            backgroundColor: _isOnline ? Colors.blue.shade700 : Colors.grey,
            tooltip: _isOnline
                ? 'Add money to facility wallet'
                : 'Internet connection required for payments',
          ),
          const SizedBox(height: 12),
          if (_isLifecareInsurance) ...[
            FloatingActionButton.extended(
              onPressed: _isOnline ? _fundHousehold : null,
              heroTag: 'fundHousehold',
              icon: Icon(_isOnline ? Icons.home_work : Icons.wifi_off),
              label: Text(_isOnline ? 'Fund Household' : 'Offline'),
              backgroundColor: _isOnline ? Colors.orange.shade700 : Colors.grey,
              tooltip: _isOnline
                  ? 'Fund a household wallet'
                  : 'Internet connection required',
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.extended(
            onPressed: _requestWithdrawal,
            heroTag: 'withdrawFunds',
            icon: const Icon(Icons.money_off),
            label: const Text('Withdraw'),
            backgroundColor: Colors.green.shade700,
            tooltip: 'Withdraw funds from wallet',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadWallet,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadWallet,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Offline Mode Indicator
                  const OfflineModeIndicator(),

                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text(
                            'Wallet Balance',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₦${_balance?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(
                          fontSize: 18,
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
                            _showAllTransactions ? 'Show Less' : 'Show All',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_transactions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No transactions yet'),
                      ),
                    )
                  else
                    ..._transactions
                        .take(_showAllTransactions ? _transactions.length : 5)
                        .map((tx) {
                          final isCredit = tx['type'] == 'credit';
                          final ts = tx['timestamp'];
                          final date = ts is DateTime
                              ? ts
                              : ts is Timestamp
                              ? ts.toDate()
                              : null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isCredit
                                    ? Colors.green
                                    : Colors.red,
                                child: Icon(
                                  isCredit ? Icons.add : Icons.remove,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                tx['description'] ?? 'No description',
                              ),
                              subtitle: Text(
                                date != null
                                    ? date.toString().substring(0, 16)
                                    : 'Unknown date',
                              ),
                              trailing: Text(
                                '₦${(tx['amount'] ?? 0).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isCredit ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          );
                        }),
                ],
              ),
            ),
    );
  }
}
