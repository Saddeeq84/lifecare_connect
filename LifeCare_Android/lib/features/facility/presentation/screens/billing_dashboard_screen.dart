import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class BillingDashboardScreen extends StatefulWidget {
  final String facilityId;
  final String staffId;
  final String staffName;

  const BillingDashboardScreen({
    super.key,
    required this.facilityId,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<BillingDashboardScreen> createState() => _BillingDashboardScreenState();
}

class _BillingDashboardScreenState extends State<BillingDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _topUpController = TextEditingController();
  final _patientSearchController = TextEditingController();
  String _patientSearchQuery = '';
  String? _lastPaymentRef;
  double? _lastPaymentAmount;
  String? _lastPatientId;
  String? _lastPatientName;
  String? _lastPatientType; // 'individual' or 'household'
  String? _lastHouseholdId;
  String _facilityName = 'Facility'; // Default value

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFacilityName();
  }

  Future<void> _loadFacilityName() async {
    try {
      final facilityDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.facilityId)
          .get();
      if (facilityDoc.exists && mounted) {
        setState(() {
          _facilityName = facilityDoc.data()?['name'] ?? 'Facility';
        });
      }
    } catch (e) {
      print('Error loading facility name: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _topUpController.dispose();
    _patientSearchController.dispose();
    super.dispose();
  }

  Future<void> _showTopUpDialog(
    String patientId,
    String patientName,
    double currentBalance,
  ) async {
    // Get patient details to determine wallet type
    final patientDoc = await FirebaseFirestore.instance
        .collection('facility_patients')
        .doc(patientId)
        .get();

    if (!patientDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final patientData = patientDoc.data()!;
    final patientType = patientData['patientType'] as String?;
    final householdId = patientData['householdId'] as String?;

    _topUpController.clear();

    // Determine if patient is household member
    final isHouseholdMember =
        (patientType == 'household_member' || patientType == 'household') &&
        householdId != null;

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Top Up Wallet - $patientName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHouseholdMember
                  ? 'LifeCare Member (Household)'
                  : 'Individual Patient',
              style: TextStyle(
                color: isHouseholdMember ? Colors.blue : Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text('Current Balance: ₦${currentBalance.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: _topUpController,
              decoration: const InputDecoration(
                labelText: 'Amount to Add',
                prefixText: '₦ ',
                border: OutlineInputBorder(),
                helperText: 'Payment via Paystack',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment will open in browser via Paystack',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
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
              final amount = double.tryParse(_topUpController.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context, amount);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue to Payment'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _initializePaystackPayment(
        patientId,
        patientName,
        patientType,
        householdId,
        result,
      );
    }
  }

  Future<void> _initializePaystackPayment(
    String patientId,
    String patientName,
    String? patientType,
    String? householdId,
    double amount,
  ) async {
    print('💳 [Paystack] Initializing payment...');
    print('   Patient ID: $patientId');
    print('   Patient Name: $patientName');
    print('   Patient Type: $patientType');
    print('   Household ID: $householdId');
    print('   Amount: ₦${amount.toStringAsFixed(2)}');

    final staffEmail =
        '${widget.staffName.toLowerCase().replaceAll(' ', '.')}@lifecare.com';
    final ref = DateTime.now().millisecondsSinceEpoch.toString();

    print('   Staff Email: $staffEmail');
    print('   Reference: $ref');

    _lastPaymentRef = ref;
    _lastPaymentAmount = amount;
    _lastPatientId = patientId;
    _lastPatientName = patientName;
    _lastPatientType = patientType;
    _lastHouseholdId = householdId;

    try {
      final url = Uri.parse(
        'https://us-central1-lifecare-connect.cloudfunctions.net/paystackInitialize',
      );
      print('🌐 [Paystack] Calling Cloud Function: $url');

      final requestBody = {
        'email': staffEmail,
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
                  'Payment page has opened in your browser. After completing payment, click "Verify Payment" to credit the wallet.',
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
    if (_lastPaymentRef == null ||
        _lastPaymentAmount == null ||
        _lastPatientId == null) {
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
        // Payment verified, now credit the appropriate wallet
        await _creditWallet(
          _lastPatientId!,
          _lastPatientName!,
          _lastPatientType,
          _lastHouseholdId,
          _lastPaymentAmount!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment verified! ₦${_lastPaymentAmount!.toStringAsFixed(2)} credited to wallet',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Clear payment data
        _lastPaymentRef = null;
        _lastPaymentAmount = null;
        _lastPatientId = null;
        _lastPatientName = null;
        _lastPatientType = null;
        _lastHouseholdId = null;
      } else {
        throw Exception(
          data['data']?['gateway_response'] ??
              data['message'] ??
              'Payment not successful',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _creditWallet(
    String patientId,
    String patientName,
    String? patientType,
    String? householdId,
    double amount,
  ) async {
    // Check if patient is part of a household (LifeCare member)
    if ((patientType == 'household_member' || patientType == 'household') &&
        householdId != null) {
      // Credit household wallet
      await FirebaseFirestore.instance
          .collection('household_wallets')
          .doc(householdId)
          .set({
            'balance': FieldValue.increment(amount),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Record transaction in household wallet
      await FirebaseFirestore.instance
          .collection('household_wallets')
          .doc(householdId)
          .collection('transactions')
          .add({
            'type': 'credit',
            'amount': amount,
            'description': 'Wallet top-up via Paystack for $patientName',
            'patientId': patientId,
            'patientName': patientName,
            'facilityId': widget.facilityId,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'completed',
            'processedBy': widget.staffName,
            'paymentMethod': 'paystack',
          });
    } else {
      // Credit individual wallet (auto-create if doesn't exist)
      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(patientId)
          .set({
            'patientId': patientId,
            'patientName': patientName,
            'balance': FieldValue.increment(amount),
            'facilityId': widget.facilityId,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Record transaction in individual wallet
      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(patientId)
          .collection('transactions')
          .add({
            'type': 'credit',
            'amount': amount,
            'description': 'Wallet top-up via Paystack',
            'facilityId': widget.facilityId,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'completed',
            'processedBy': widget.staffName,
            'paymentMethod': 'paystack',
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_facilityName - Billing'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_wallet), text: 'Patients'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Transactions'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Summary'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPatientsTab(),
          _buildTransactionsTab(),
          _buildSummaryTab(),
        ],
      ),
    );
  }

  Widget _buildPatientsTab() {
    return Column(
      children: [
        // Search field
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _patientSearchController,
            decoration: InputDecoration(
              hintText: 'Search by name or registration number...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              suffixIcon: _patientSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _patientSearchController.clear();
                          _patientSearchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {
                _patientSearchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        // Patient list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('facility_patients')
                .where('facilityId', isEqualTo: widget.facilityId)
                .orderBy('fullName')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No patients found'));
              }

              // Filter patients based on search query
              final allPatients = snapshot.data!.docs;
              final filteredPatients = allPatients.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final fullName = (data['fullName'] as String? ?? '')
                    .toLowerCase();
                final registrationNumber =
                    (data['registrationNumber'] as String? ?? '').toLowerCase();

                return _patientSearchQuery.isEmpty ||
                    fullName.contains(_patientSearchQuery) ||
                    registrationNumber.contains(_patientSearchQuery);
              }).toList();

              if (filteredPatients.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_search,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No patients found matching "$_patientSearchQuery"',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredPatients.length,
                itemBuilder: (context, index) {
                  final doc = filteredPatients[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final patientId = doc.id;
                  final patientType = data['patientType'] as String?;
                  final householdId = data['householdId'] as String?;

                  return _buildPatientWalletCard(
                    patientId,
                    data,
                    patientType,
                    householdId,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPatientWalletCard(
    String patientId,
    Map<String, dynamic> data,
    String? patientType,
    String? householdId,
  ) {
    // Determine if this is a household member
    final isHouseholdMember =
        (patientType == 'household_member' || patientType == 'household') &&
        householdId != null;

    // Get wallet balance based on patient type
    return FutureBuilder<DocumentSnapshot>(
      future: isHouseholdMember
          ? FirebaseFirestore.instance
                .collection('household_wallets')
                .doc(householdId)
                .get()
          : FirebaseFirestore.instance
                .collection('wallets')
                .doc(patientId)
                .get(),
      builder: (context, walletSnapshot) {
        double balance = 0.0;

        if (walletSnapshot.hasData && walletSnapshot.data!.exists) {
          balance =
              (walletSnapshot.data!.data() as Map<String, dynamic>?)?['balance']
                  ?.toDouble() ??
              0.0;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: balance < 0
                      ? Colors.red
                      : balance < 5000
                      ? Colors.orange
                      : Colors.green,
                  child: Icon(
                    isHouseholdMember ? Icons.family_restroom : Icons.person,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  data['fullName'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registration: ${data['registrationNumber'] ?? 'N/A'}',
                    ),
                    if (isHouseholdMember)
                      Text(
                        'Household: ${data['householdName'] ?? 'N/A'}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      const Text(
                        'Individual Patient',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₦${balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: balance < 0 ? Colors.red : Colors.green,
                      ),
                    ),
                    Text(
                      balance < 0 ? 'Overdrawn' : 'Balance',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PatientBillingDetailsScreen(
                        patientId: patientId,
                        patientData: data,
                      ),
                    ),
                  );
                },
              ),
              // Only show Fund Wallet button for individual patients, not household members
              if (!isHouseholdMember)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showTopUpDialog(
                          patientId,
                          data['fullName'] ?? 'Patient',
                          balance,
                        );
                      },
                      icon: const Icon(Icons.account_balance_wallet),
                      label: const Text('Fund Wallet'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Services charged to household wallet',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('transactions')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No transactions found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final type = data['type'] as String;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: type == 'credit' ? Colors.green : Colors.red,
                  child: Icon(
                    type == 'credit' ? Icons.add : Icons.remove,
                    color: Colors.white,
                  ),
                ),
                title: Text(data['description'] ?? 'Transaction'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (timestamp != null)
                      Text(
                        DateFormat(
                          'MMM dd, yyyy - hh:mm a',
                        ).format(timestamp.toDate()),
                      ),
                    if (data['processedBy'] != null)
                      Text('By: ${data['processedBy']}'),
                    if (data['dispensedBy'] != null)
                      Text('By: ${data['dispensedBy']}'),
                    if (data['performedBy'] != null)
                      Text('By: ${data['performedBy']}'),
                    if (data['reportedBy'] != null)
                      Text('By: ${data['reportedBy']}'),
                  ],
                ),
                trailing: Text(
                  '₦${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: type == 'credit' ? Colors.green : Colors.red,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('transactions')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        double totalCredits = 0;
        double totalDebits = 0;
        int creditCount = 0;
        int debitCount = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final type = data['type'] as String;

            if (type == 'credit') {
              totalCredits += amount;
              creditCount++;
            } else {
              totalDebits += amount;
              debitCount++;
            }
          }
        }

        final netFlow = totalCredits - totalDebits;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Financial Overview',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Transaction summary and insights',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),

              // Main Stats in Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive: 2 columns on mobile, 3 columns on tablet/desktop
                  final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                  final childAspectRatio = constraints.maxWidth > 600
                      ? 1.3
                      : 1.1;

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: childAspectRatio,
                    children: [
                      _buildStatCard(
                        icon: Icons.arrow_downward,
                        iconColor: Colors.green,
                        backgroundColor: Colors.green.shade50,
                        title: 'Total Credits',
                        amount: totalCredits,
                        count: creditCount,
                        countLabel: 'transactions',
                      ),
                      _buildStatCard(
                        icon: Icons.arrow_upward,
                        iconColor: Colors.red,
                        backgroundColor: Colors.red.shade50,
                        title: 'Total Debits',
                        amount: totalDebits,
                        count: debitCount,
                        countLabel: 'transactions',
                      ),
                      _buildStatCard(
                        icon: Icons.account_balance_wallet,
                        iconColor: netFlow >= 0 ? Colors.blue : Colors.orange,
                        backgroundColor: netFlow >= 0
                            ? Colors.blue.shade50
                            : Colors.orange.shade50,
                        title: 'Net Flow',
                        amount: netFlow,
                        count: creditCount + debitCount,
                        countLabel: 'total transactions',
                        isNetFlow: true,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Additional Insights Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.insights, color: Colors.teal.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Quick Insights',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInsightRow(
                        'Average Credit',
                        creditCount > 0 ? totalCredits / creditCount : 0,
                        Icons.trending_up,
                        Colors.green,
                      ),
                      const SizedBox(height: 12),
                      _buildInsightRow(
                        'Average Debit',
                        debitCount > 0 ? totalDebits / debitCount : 0,
                        Icons.trending_down,
                        Colors.red,
                      ),
                      const SizedBox(height: 12),
                      _buildInsightRow(
                        'Transaction Ratio',
                        creditCount + debitCount > 0
                            ? (creditCount / (creditCount + debitCount)) * 100
                            : 0,
                        Icons.pie_chart,
                        Colors.blue,
                        isPercentage: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String title,
    required double amount,
    required int count,
    required String countLabel,
    bool isNetFlow = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: iconColor.withOpacity(0.2), width: 1),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [backgroundColor, Colors.white],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                if (isNetFlow)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: amount >= 0
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      amount >= 0 ? 'Positive' : 'Negative',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: amount >= 0
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                      ),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '₦${amount.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isNetFlow
                          ? (amount >= 0
                                ? Colors.green.shade700
                                : Colors.red.shade700)
                          : Colors.grey[900],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count $countLabel',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightRow(
    String label,
    double value,
    IconData icon,
    Color color, {
    bool isPercentage = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          isPercentage
              ? '${value.toStringAsFixed(1)}%'
              : '₦${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// Patient Billing Details Screen
class PatientBillingDetailsScreen extends StatelessWidget {
  final String patientId;
  final Map<String, dynamic> patientData;

  const PatientBillingDetailsScreen({
    super.key,
    required this.patientId,
    required this.patientData,
  });

  @override
  Widget build(BuildContext context) {
    final balance = (patientData['walletBalance'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: Text(patientData['fullName'] ?? 'Patient Billing')),
      body: Column(
        children: [
          // Patient Info Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patientData['fullName'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 16),
                  _buildInfoRow(
                    'Registration',
                    patientData['registrationNumber'],
                  ),
                  _buildInfoRow('Household', patientData['householdName']),
                  _buildInfoRow('Phone', patientData['phone']),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Wallet Balance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₦${balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: balance < 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Transactions List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('facility_patients')
                  .doc(patientId)
                  .collection('transactions')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No transactions found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp = data['timestamp'] as Timestamp?;
                    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                    final type = data['type'] as String;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: type == 'credit'
                              ? Colors.green
                              : Colors.red,
                          child: Icon(
                            type == 'credit' ? Icons.add : Icons.remove,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(data['description'] ?? 'Transaction'),
                        subtitle: timestamp != null
                            ? Text(
                                DateFormat(
                                  'MMM dd, yyyy - hh:mm a',
                                ).format(timestamp.toDate()),
                              )
                            : null,
                        trailing: Text(
                          '₦${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: type == 'credit' ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value?.toString() ?? 'N/A'),
        ],
      ),
    );
  }
}
