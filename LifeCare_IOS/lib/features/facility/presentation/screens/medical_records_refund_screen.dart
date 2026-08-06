import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class MedicalRecordsRefundScreen extends StatefulWidget {
  final String facilityId;
  final String staffId;
  final String staffName;
  final String department;

  const MedicalRecordsRefundScreen({
    super.key,
    required this.facilityId,
    required this.staffId,
    required this.staffName,
    required this.department,
  });

  @override
  State<MedicalRecordsRefundScreen> createState() =>
      _MedicalRecordsRefundScreenState();
}

class _MedicalRecordsRefundScreenState extends State<MedicalRecordsRefundScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Refund Applications'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle), text: 'Apply'),
            Tab(icon: Icon(Icons.pending_actions), text: 'Pending'),
            Tab(icon: Icon(Icons.check_circle), text: 'Approved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ApplyRefundTab(
            facilityId: widget.facilityId,
            staffId: widget.staffId,
            staffName: widget.staffName,
            tabController: _tabController, // Pass TabController to child
          ),
          _PendingRefundsTab(facilityId: widget.facilityId),
          _ApprovedRefundsTab(facilityId: widget.facilityId),
        ],
      ),
    );
  }
}

// ==================== APPLY REFUND TAB ====================
class _ApplyRefundTab extends StatefulWidget {
  final String facilityId;
  final String staffId;
  final String staffName;
  final TabController tabController; // Add TabController parameter

  const _ApplyRefundTab({
    required this.facilityId,
    required this.staffId,
    required this.staffName,
    required this.tabController, // Required TabController
  });

  @override
  State<_ApplyRefundTab> createState() => _ApplyRefundTabState();
}

class _ApplyRefundTabState extends State<_ApplyRefundTab> {
  final _formKey = GlobalKey<FormState>();
  final _patientSearchController = TextEditingController();
  final _refundAmountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _beneficiaryNameController = TextEditingController();
  final _beneficiaryPhoneController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  Map<String, dynamic>? _selectedPatient;
  String? _selectedRefundReason;
  String? _selectedBank;
  Map<String, dynamic>? _walletInfo;
  bool _isVerifyingAccount = false;
  bool _accountVerified = false;
  String? _verifiedAccountName;

  // Wallet transfer options
  String _transferType =
      'bank_transfer'; // 'bank_transfer' or 'wallet_transfer'
  final _recipientSearchController = TextEditingController();
  Map<String, dynamic>? _selectedRecipient;
  Map<String, dynamic>? _recipientWalletInfo;

  final List<String> _refundReasons = [
    'Patient Deceased - Next of Kin Claim',
    'Patient Relocating',
    'Patient Dissatisfied with Service',
    'Duplicate Payment',
    'Service Not Rendered',
    'Other (Specify)',
  ];

  final Map<String, String> _nigerianBanks = {
    '044': 'Access Bank',
    '063': 'Access Bank (Diamond)',
    '035': 'Wema Bank',
    '050': 'Ecobank Nigeria',
    '070': 'Fidelity Bank',
    '011': 'First Bank of Nigeria',
    '214': 'First City Monument Bank',
    '058': 'Guaranty Trust Bank',
    '030': 'Heritage Bank',
    '301': 'Jaiz Bank',
    '082': 'Keystone Bank',
    '526': 'Parallex Bank',
    '076': 'Polaris Bank',
    '101': 'Providus Bank',
    '221': 'Stanbic IBTC Bank',
    '068': 'Standard Chartered Bank',
    '232': 'Sterling Bank',
    '100': 'Suntrust Bank',
    '032': 'Union Bank of Nigeria',
    '033': 'United Bank For Africa',
    '215': 'Unity Bank',
    '057': 'Zenith Bank',
  };

  @override
  void dispose() {
    _patientSearchController.dispose();
    _refundAmountController.dispose();
    _reasonController.dispose();
    _beneficiaryNameController.dispose();
    _beneficiaryPhoneController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _searchPatient() async {
    final searchTerm = _patientSearchController.text.trim();
    if (searchTerm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter patient name or ID')),
      );
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('facility_patients')
          .where('facilityId', isEqualTo: widget.facilityId)
          .get();

      final patients = querySnapshot.docs.where((doc) {
        final data = doc.data();
        final name = (data['fullName'] ?? '').toString().toLowerCase();
        final id = (data['patientId'] ?? '').toString().toLowerCase();
        return name.contains(searchTerm.toLowerCase()) ||
            id.contains(searchTerm.toLowerCase());
      }).toList();

      if (patients.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No patient found')));
        }
        return;
      }

      if (patients.length == 1) {
        await _selectPatient(patients.first.data(), patients.first.id);
      } else {
        // Show selection dialog
        if (mounted) {
          _showPatientSelectionDialog(patients);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching patient: $e')));
      }
    }
  }

  void _showPatientSelectionDialog(List<QueryDocumentSnapshot> patients) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Patient'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final patient = patients[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(patient['fullName'] ?? 'Unknown'),
                subtitle: Text('ID: ${patient['patientId'] ?? 'N/A'}'),
                onTap: () {
                  Navigator.pop(context);
                  _selectPatient(patient, patients[index].id);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _selectPatient(
    Map<String, dynamic> patient,
    String docId,
  ) async {
    // Check if patient is a household member
    if (patient['householdId'] != null &&
        patient['householdId'].toString().isNotEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Household Member'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This patient is a household member and does not have an individual wallet.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 12),
                Text(
                  'Only patients with individual wallets can apply for wallet refund.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Please contact the household administrator for refund requests.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
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
      return;
    }

    setState(() {
      _selectedPatient = patient;
      _selectedPatient!['docId'] = docId;
    });

    // Fetch wallet info for individual patient
    try {
      final walletDoc = await FirebaseFirestore.instance
          .collection('wallets')
          .doc(patient['patientId'])
          .get();

      if (walletDoc.exists) {
        setState(() {
          _walletInfo = walletDoc.data();
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Patient wallet not found. Please ensure the patient has an individual wallet.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Clear selection since wallet doesn't exist
        setState(() {
          _selectedPatient = null;
          _walletInfo = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching wallet: $e')));
      }
      // Clear selection on error
      setState(() {
        _selectedPatient = null;
        _walletInfo = null;
      });
    }
  }

  Future<void> _verifyBankAccount() async {
    if (_accountNumberController.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account number must be 10 digits')),
      );
      return;
    }

    if (_selectedBank == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a bank')));
      return;
    }

    setState(() {
      _isVerifyingAccount = true;
      _accountVerified = false;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'verifyBankAccountName',
      );
      final result = await callable.call({
        'accountNumber': _accountNumberController.text.trim(),
        'bankCode': _selectedBank,
        'expectedName': _accountNameController.text.trim(),
        'refundApplicationId': null,
      });

      final data = result.data as Map<String, dynamic>;

      setState(() {
        _isVerifyingAccount = false;
        _accountVerified = data['isMatch'] ?? false;
        _verifiedAccountName = data['accountName'];
      });

      if (_accountVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Account verified: ${data['accountName']}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Name Mismatch'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Expected: ${_accountNameController.text}'),
                const SizedBox(height: 8),
                Text('Bank Account: ${data['accountName']}'),
                const SizedBox(height: 16),
                const Text(
                  'The account name does not match. Please verify the details.',
                  style: TextStyle(color: Colors.orange),
                ),
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
    } catch (e) {
      setState(() {
        _isVerifyingAccount = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _searchRecipientPatient() async {
    final query = _recipientSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a search term')),
      );
      return;
    }

    // Search in facility_patients collection
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.search, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Select Recipient Patient',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('facility_patients')
                      .where('facilityId', isEqualTo: widget.facilityId)
                      .where('isActive', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No patients found'));
                    }

                    final patients = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final fullName = (data['fullName'] ?? '')
                          .toString()
                          .toLowerCase();
                      final phone = (data['phone'] ?? '')
                          .toString()
                          .toLowerCase();
                      return fullName.contains(query) || phone.contains(query);
                    }).toList();

                    if (patients.isEmpty) {
                      return const Center(child: Text('No matching patients'));
                    }

                    return ListView.builder(
                      itemCount: patients.length,
                      itemBuilder: (context, index) {
                        final patient = patients[index];
                        final data = patient.data() as Map<String, dynamic>;
                        final isHouseholdMember =
                            data['householdId'] != null &&
                            data['householdId'].toString().isNotEmpty;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isHouseholdMember
                                ? Colors.grey.shade300
                                : Colors.green.shade100,
                            child: Icon(
                              Icons.person,
                              color: isHouseholdMember
                                  ? Colors.grey
                                  : Colors.green,
                            ),
                          ),
                          title: Text(data['fullName'] ?? 'Unknown'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['phone'] ?? 'No phone'),
                              if (isHouseholdMember)
                                const Text(
                                  'Household Member - No Individual Wallet',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                          enabled: !isHouseholdMember,
                          onTap: isHouseholdMember
                              ? null
                              : () => _selectRecipient(data, patient.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectRecipient(
    Map<String, dynamic> patient,
    String docId,
  ) async {
    Navigator.pop(context); // Close search dialog

    // Check if recipient is same as refund applicant
    if (patient['patientId'] == _selectedPatient?['patientId']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot transfer refund to the same patient'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _selectedRecipient = patient;
      _selectedRecipient!['docId'] = docId;
    });

    // Fetch recipient's wallet info
    try {
      final walletDoc = await FirebaseFirestore.instance
          .collection('wallets')
          .doc(patient['patientId'])
          .get();

      if (walletDoc.exists) {
        setState(() {
          _recipientWalletInfo = walletDoc.data();
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Recipient wallet not found. Please select another patient.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _selectedRecipient = null;
          _recipientWalletInfo = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching recipient wallet: $e')),
        );
      }
      setState(() {
        _selectedRecipient = null;
        _recipientWalletInfo = null;
      });
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPatient == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a patient')));
      return;
    }

    // Validate based on transfer type
    if (_transferType == 'bank_transfer') {
      if (!_accountVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please verify the bank account first'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } else {
      // wallet_transfer
      if (_selectedRecipient == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a recipient patient'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    final refundAmount = double.tryParse(_refundAmountController.text) ?? 0;
    final walletBalance = (_walletInfo?['balance'] ?? 0).toDouble();

    if (refundAmount > walletBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Refund amount (₦${refundAmount.toStringAsFixed(2)}) exceeds wallet balance (₦${walletBalance.toStringAsFixed(2)})',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Refund Application'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient: ${_selectedPatient!['fullName']}'),
              Text('Refund Amount: ₦${refundAmount.toStringAsFixed(2)}'),
              Text('Reason: $_selectedRefundReason'),
              const Divider(),
              if (_transferType == 'bank_transfer') ...[
                const Text(
                  'Bank Details:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Bank: ${_nigerianBanks[_selectedBank]}'),
                Text('Account: ${_accountNumberController.text}'),
                Text('Name: $_verifiedAccountName'),
              ] else ...[
                const Text(
                  'Wallet Transfer:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Recipient: ${_selectedRecipient!['fullName']}'),
                Text('Phone: ${_selectedRecipient!['phone']}'),
              ],
              const Divider(),
              const Text(
                'This application will be sent to facility admin for approval.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Create application in Firestore
      final applicationRef = FirebaseFirestore.instance
          .collection('refund_applications')
          .doc();

      // Build common data
      final Map<String, dynamic> applicationData = {
        'applicationId': applicationRef.id,
        'facilityId': widget.facilityId,
        'patientId': _selectedPatient!['patientId'],
        'patientName': _selectedPatient!['fullName'],
        'patientDocId': _selectedPatient!['docId'],
        'refundAmount': refundAmount,
        'walletBalanceAtApplication': walletBalance,
        'refundReason': _selectedRefundReason,
        'reasonDetails': _reasonController.text.trim(),
        'beneficiaryName': _beneficiaryNameController.text.trim(),
        'beneficiaryPhone': _beneficiaryPhoneController.text.trim(),
        'transferType': _transferType,
        'status': 'pending_verification',
        'applicantId': widget.staffId,
        'applicantName': widget.staffName,
        'applicantDepartment': 'Medical Records',
        'appliedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add transfer-specific data
      if (_transferType == 'bank_transfer') {
        applicationData.addAll({
          'bankCode': _selectedBank,
          'bankName': _nigerianBanks[_selectedBank],
          'accountNumber': _accountNumberController.text.trim(),
          'accountName': _verifiedAccountName,
          'accountVerified': true,
        });
      } else {
        // wallet_transfer
        applicationData.addAll({
          'recipientPatientId': _selectedRecipient!['patientId'],
          'recipientPatientName': _selectedRecipient!['fullName'],
          'recipientPatientDocId': _selectedRecipient!['docId'],
          'recipientWalletId': _selectedRecipient!['patientId'],
        });
      }

      await applicationRef.set(applicationData);

      // Create transfer recipient only for bank transfers
      if (_transferType == 'bank_transfer') {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'createTransferRecipient',
        );
        await callable.call({
          'refundApplicationId': applicationRef.id,
          'accountNumber': _accountNumberController.text.trim(),
          'bankCode': _selectedBank,
          'accountName': _verifiedAccountName,
        });
      } else {
        // For wallet transfers, update status directly to pending_admin_approval
        await applicationRef.update({'status': 'pending_admin_approval'});
      }

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Refund application submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _formKey.currentState!.reset();
        setState(() {
          _selectedPatient = null;
          _walletInfo = null;
          _accountVerified = false;
          _selectedBank = null;
          _selectedRefundReason = null;
          _transferType = 'bank_transfer';
          _selectedRecipient = null;
          _recipientWalletInfo = null;
        });
        _patientSearchController.clear();
        _refundAmountController.clear();
        _reasonController.clear();
        _beneficiaryNameController.clear();
        _beneficiaryPhoneController.clear();
        _accountNumberController.clear();
        _accountNameController.clear();
        _recipientSearchController.clear();

        // Switch to pending tab
        widget.tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Search
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. Search Patient',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _patientSearchController,
                            decoration: const InputDecoration(
                              labelText: 'Patient Name or ID',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _searchPatient,
                          child: const Text('Search'),
                        ),
                      ],
                    ),
                    if (_selectedPatient != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedPatient!['fullName'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${_selectedPatient!['patientId'] ?? 'N/A'}',
                            ),
                            if (_walletInfo != null) ...[
                              const Divider(),
                              Text(
                                'Wallet Balance: ₦${(_walletInfo!['balance'] ?? 0).toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Refund Details
            if (_selectedPatient != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2. Refund Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _refundAmountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Refund Amount (₦) *',
                          prefixIcon: const Icon(Icons.money),
                          border: const OutlineInputBorder(),
                          helperText:
                              'Max: ₦${(_walletInfo?['balance'] ?? 0).toStringAsFixed(2)}',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Invalid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedRefundReason,
                        decoration: const InputDecoration(
                          labelText: 'Refund Reason *',
                          prefixIcon: Icon(Icons.info),
                          border: OutlineInputBorder(),
                        ),
                        items: _refundReasons.map((reason) {
                          return DropdownMenuItem(
                            value: reason,
                            child: Text(reason),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRefundReason = value;
                          });
                        },
                        validator: (value) => value == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Additional Details *',
                          hintText: 'Provide detailed explanation...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (value.trim().length < 20) {
                            return 'Please provide detailed explanation (min 20 characters)';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Beneficiary Details
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '3. Beneficiary Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Person who will receive the refund (patient or next of kin)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _beneficiaryNameController,
                        decoration: const InputDecoration(
                          labelText: 'Beneficiary Full Name *',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _beneficiaryPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Beneficiary Phone *',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Transfer Type Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '4. Refund Destination',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose where to send the refund',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Bank Transfer'),
                              subtitle: const Text('Send to bank account'),
                              value: 'bank_transfer',
                              groupValue: _transferType,
                              onChanged: (value) {
                                setState(() {
                                  _transferType = value!;
                                  // Clear recipient when switching to bank transfer
                                  _selectedRecipient = null;
                                  _recipientWalletInfo = null;
                                  _recipientSearchController.clear();
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Wallet Transfer'),
                              subtitle: const Text('Send to patient wallet'),
                              value: 'wallet_transfer',
                              groupValue: _transferType,
                              onChanged: (value) {
                                setState(() {
                                  _transferType = value!;
                                  // Clear bank details when switching to wallet transfer
                                  _selectedBank = null;
                                  _accountVerified = false;
                                  _verifiedAccountName = null;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bank Details (only show if bank_transfer selected)
              if (_transferType == 'bank_transfer')
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '5. Bank Account Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedBank,
                          decoration: const InputDecoration(
                            labelText: 'Select Bank *',
                            prefixIcon: Icon(Icons.account_balance),
                            border: OutlineInputBorder(),
                          ),
                          items: _nigerianBanks.entries.map((entry) {
                            return DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBank = value;
                              _accountVerified = false;
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _accountNumberController,
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          decoration: const InputDecoration(
                            labelText: 'Account Number *',
                            prefixIcon: Icon(Icons.credit_card),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (value.length != 10) {
                              return 'Must be 10 digits';
                            }
                            return null;
                          },
                          onChanged: (_) {
                            setState(() {
                              _accountVerified = false;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _accountNameController,
                          decoration: const InputDecoration(
                            labelText: 'Expected Account Name *',
                            prefixIcon: Icon(Icons.badge),
                            border: OutlineInputBorder(),
                            helperText:
                                'Enter the name that should match the bank account',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Required'
                              : null,
                          onChanged: (_) {
                            setState(() {
                              _accountVerified = false;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isVerifyingAccount
                                ? null
                                : _verifyBankAccount,
                            icon: _isVerifyingAccount
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _accountVerified
                                        ? Icons.check_circle
                                        : Icons.verified_user,
                                  ),
                            label: Text(
                              _isVerifyingAccount
                                  ? 'Verifying...'
                                  : _accountVerified
                                  ? 'Verified ✓'
                                  : 'Verify Account',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accountVerified
                                  ? Colors.green
                                  : null,
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                        if (_accountVerified &&
                            _verifiedAccountName != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Verified: $_verifiedAccountName',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // Wallet Transfer Recipient (only show if wallet_transfer selected)
              if (_transferType == 'wallet_transfer')
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '5. Select Recipient Patient',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Search and select the patient who will receive this refund',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _recipientSearchController,
                                decoration: const InputDecoration(
                                  labelText: 'Search Recipient Patient',
                                  hintText: 'Name or phone number',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _searchRecipientPatient(),
                              icon: const Icon(Icons.search),
                              tooltip: 'Search',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (_selectedRecipient != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedRecipient!['fullName'] ??
                                            'Unknown',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        _selectedRecipient!['phone'] ??
                                            'No phone',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      if (_recipientWalletInfo != null)
                                        Text(
                                          'Wallet Balance: ₦${(_recipientWalletInfo!['balance'] ?? 0).toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setState(() {
                                      _selectedRecipient = null;
                                      _recipientWalletInfo = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitApplication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text(
                    'Submit Refund Application',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== PENDING REFUNDS TAB ====================
class _PendingRefundsTab extends StatelessWidget {
  final String facilityId;

  const _PendingRefundsTab({required this.facilityId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('refund_applications')
          .where('facilityId', isEqualTo: facilityId)
          .where(
            'status',
            whereIn: ['pending_verification', 'pending_admin_approval'],
          )
          .orderBy('appliedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No pending refund applications'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final refund = doc.data() as Map<String, dynamic>;
            return _RefundCard(refund: refund);
          },
        );
      },
    );
  }
}

// ==================== APPROVED REFUNDS TAB ====================
class _ApprovedRefundsTab extends StatelessWidget {
  final String facilityId;

  const _ApprovedRefundsTab({required this.facilityId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('refund_applications')
          .where('facilityId', isEqualTo: facilityId)
          .where('status', whereIn: ['approved', 'rejected'])
          .orderBy('completedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No completed refund applications'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final refund = doc.data() as Map<String, dynamic>;
            return _RefundCard(refund: refund);
          },
        );
      },
    );
  }
}

// ==================== REFUND CARD WIDGET ====================
class _RefundCard extends StatelessWidget {
  final Map<String, dynamic> refund;

  const _RefundCard({required this.refund});

  @override
  Widget build(BuildContext context) {
    final status = refund['status'] ?? '';
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.pending;

    switch (status) {
      case 'pending_verification':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case 'pending_admin_approval':
        statusColor = Colors.blue;
        statusIcon = Icons.pending_actions;
        break;
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(
          refund['patientName'] ?? 'Unknown Patient',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '₦${(refund['refundAmount'] ?? 0).toStringAsFixed(2)} - ${_formatStatus(status)}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow('Patient ID:', refund['patientId'] ?? 'N/A'),
                _DetailRow('Reason:', refund['refundReason'] ?? 'N/A'),
                _DetailRow('Details:', refund['reasonDetails'] ?? 'N/A'),
                const Divider(),
                _DetailRow('Beneficiary:', refund['beneficiaryName'] ?? 'N/A'),
                _DetailRow('Phone:', refund['beneficiaryPhone'] ?? 'N/A'),
                const Divider(),
                _DetailRow('Bank:', refund['bankName'] ?? 'N/A'),
                _DetailRow('Account:', refund['accountNumber'] ?? 'N/A'),
                _DetailRow('Account Name:', refund['accountName'] ?? 'N/A'),
                const Divider(),
                _DetailRow('Applied By:', refund['applicantName'] ?? 'N/A'),
                _DetailRow('Applied At:', _formatDate(refund['appliedAt'])),
                if (refund['approvedBy'] != null) ...[
                  const Divider(),
                  _DetailRow('Approved By:', refund['approvedByName'] ?? 'N/A'),
                  _DetailRow('Approved At:', _formatDate(refund['approvedAt'])),
                ],
                if (refund['rejectedBy'] != null) ...[
                  const Divider(),
                  _DetailRow('Rejected By:', refund['rejectedByName'] ?? 'N/A'),
                  _DetailRow('Reason:', refund['rejectionReason'] ?? 'N/A'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _DetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'pending_verification':
        return 'Pending Verification';
      case 'pending_admin_approval':
        return 'Pending Admin Approval';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      return timestamp.toDate().toString().substring(0, 16);
    }
    return 'N/A';
  }
}
