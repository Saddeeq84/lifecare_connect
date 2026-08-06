import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PharmacyDispensingScreen extends StatefulWidget {
  final String facilityId;
  final String pharmacistId;
  final String pharmacistName;

  const PharmacyDispensingScreen({
    super.key,
    required this.facilityId,
    required this.pharmacistId,
    required this.pharmacistName,
  });

  @override
  State<PharmacyDispensingScreen> createState() =>
      _PharmacyDispensingScreenState();
}

class _PharmacyDispensingScreenState extends State<PharmacyDispensingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _pendingSearchController = TextEditingController();
  final _directDispensingSearchController = TextEditingController();
  String _pendingSearchQuery = '';
  String _directDispensingSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pendingSearchController.dispose();
    _directDispensingSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy Dispensing'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending Prescriptions'),
            Tab(text: 'Dispensed'),
            Tab(text: 'Direct Dispensing'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingPrescriptionsView(),
          _buildDispensedPrescriptionsView(),
          _buildDirectDispensingView(),
        ],
      ),
    );
  }

  // Dispensed prescriptions view (from dispensing_history)
  Widget _buildDispensedPrescriptionsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dispensing_history')
          .where('facilityId', isEqualTo: widget.facilityId)
          .orderBy('dispensedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.medical_services_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No dispensed prescriptions',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final medications = data['medications'] as List<dynamic>?;
            final dispensedAt = data['dispensedAt'] as Timestamp?;
            final patientId = data['patientId'] as String?;

            // If no patientId, display immediately with fallback name
            if (patientId == null || patientId.isEmpty) {
              return _buildDispensedCard(
                data,
                'Unknown Patient',
                medications,
                dispensedAt,
              );
            }

            // Fetch patient name from facility_patients collection
            return FutureBuilder<DocumentSnapshot?>(
              future: FirebaseFirestore.instance
                  .collection('facility_patients')
                  .doc(patientId)
                  .get(),
              builder: (context, patientSnapshot) {
                String patientName = 'Unknown Patient';
                if (patientSnapshot.hasData && patientSnapshot.data != null) {
                  final patientData =
                      patientSnapshot.data!.data() as Map<String, dynamic>?;
                  patientName = patientData?['fullName'] ?? 'Unknown Patient';
                }
                return _buildDispensedCard(
                  data,
                  patientName,
                  medications,
                  dispensedAt,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDispensedCard(
    Map<String, dynamic> data,
    String patientName,
    List<dynamic>? medications,
    Timestamp? dispensedAt,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  patientName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'DISPENSED',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Dispensed by: ${data['pharmacistName'] ?? 'Unknown'}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (dispensedAt != null)
              Text(
                'Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(dispensedAt.toDate())}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            const SizedBox(height: 12),
            const Text(
              'Medications:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (medications != null)
              ...medications.map((med) {
                if (med is! Map<String, dynamic>) {
                  return const SizedBox.shrink();
                }
                final name = med['name'] as String? ?? 'Unknown';
                final dosage = med['dosage'] as String? ?? '';
                final quantity = med['quantity'] as int? ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text('• $name - $dosage (Qty: $quantity)'),
                );
              }),
            const SizedBox(height: 12),
            Text(
              'Total: ₦${(data['totalCost'] ?? 0).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // Direct dispensing view for over-the-counter items
  Widget _buildDirectDispensingView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _directDispensingSearchController,
                decoration: InputDecoration(
                  hintText: 'Search by patient name...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: _directDispensingSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _directDispensingSearchController.clear();
                              _directDispensingSearchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _directDispensingSearchQuery = value.toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DirectDispensingDetailsScreen(
                        facilityId: widget.facilityId,
                        pharmacistId: widget.pharmacistId,
                        pharmacistName: widget.pharmacistName,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Start Direct Dispensing'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('facility_patients')
                .where('facilityId', isEqualTo: widget.facilityId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No patients registered',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              final allPatients = snapshot.data!.docs;
              final filteredPatients = allPatients.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final patientName = (data['fullName'] as String? ?? '')
                    .toLowerCase();
                return _directDispensingSearchQuery.isEmpty ||
                    patientName.contains(_directDispensingSearchQuery);
              }).toList();
              if (filteredPatients.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No patients found for "$_directDispensingSearchQuery"',
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
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (data['fullName'] as String? ?? 'P')[0].toUpperCase(),
                        ),
                      ),
                      title: Text(data['fullName'] ?? 'Unknown Patient'),
                      subtitle: Text(data['phoneNumber'] ?? 'No phone'),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DirectDispensingDetailsScreen(
                              facilityId: widget.facilityId,
                              pharmacistId: widget.pharmacistId,
                              pharmacistName: widget.pharmacistName,
                              patientId: doc.id,
                              patientName: data['fullName'] ?? 'Unknown',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Pending prescriptions view (original)
  Widget _buildPendingPrescriptionsView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _pendingSearchController,
            decoration: InputDecoration(
              hintText: 'Search by patient name...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: _pendingSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _pendingSearchController.clear();
                          _pendingSearchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {
                _pendingSearchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('pending_prescriptions')
                .where('facilityId', isEqualTo: widget.facilityId)
                .where('status', isEqualTo: 'pending')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.medical_services_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No pending prescriptions',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              final allDocs = snapshot.data!.docs;
              final filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final patientName = (data['patientName'] as String? ?? '')
                    .toLowerCase();

                // Check if prescription matches search query
                final matchesSearch =
                    _pendingSearchQuery.isEmpty ||
                    patientName.contains(_pendingSearchQuery);

                // Check if all medications are dispensed
                final prescriptions =
                    data['prescriptions'] as List<dynamic>? ?? [];
                final allDispensed =
                    prescriptions.isNotEmpty &&
                    prescriptions.every((rx) {
                      if (rx is! Map<String, dynamic>) return false;
                      return (rx['dispensed'] as bool?) == true;
                    });

                // Include only if search matches AND not all medications are dispensed
                return matchesSearch && !allDispensed;
              }).toList();
              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No prescriptions found for "$_pendingSearchQuery"',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final prescriptions = data['prescriptions'] as List<dynamic>;
                  final timestamp = data['createdAt'] as Timestamp?;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DispenseDetailsScreen(
                              prescriptionId: doc.id,
                              prescriptionData: data,
                              pharmacistId: widget.pharmacistId,
                              pharmacistName: widget.pharmacistName,
                              patientId: data['patientId'] ?? '',
                              facilityId: widget.facilityId,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    data['patientName'] ?? 'Unknown Patient',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'PENDING',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Prescribed by: ${data['clinicianName'] ?? 'Unknown'}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            if (timestamp != null)
                              Text(
                                'Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate())}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            const Divider(height: 16),
                            Text(
                              '${prescriptions.length} medication(s)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (data['partiallyDispensed'] == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Partially dispensed',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            ...prescriptions.take(3).map((rx) {
                              if (rx is! Map<String, dynamic>) {
                                return const SizedBox.shrink();
                              }
                              final isDispensed =
                                  (rx['dispensed'] as bool?) == true;
                              final medication =
                                  rx['medication'] as String? ?? 'Unknown';
                              final strength = rx['strength'] as String? ?? '';
                              final dosage = rx['dosage'] as String? ?? '';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.medication,
                                      size: 16,
                                      color: isDispensed
                                          ? Colors.green
                                          : Colors.blue,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '$medication $strength - $dosage',
                                        style: TextStyle(
                                          fontSize: 14,
                                          decoration: isDispensed
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: isDispensed
                                              ? Colors.grey
                                              : null,
                                        ),
                                      ),
                                    ),
                                    if (isDispensed)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Text(
                                          'Dispensed',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                            if (prescriptions.length > 3) ...[
                              const SizedBox(height: 4),
                              Text(
                                '  +${prescriptions.length - 3} more...',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
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
    );
  }
}

class DispenseDetailsScreen extends StatefulWidget {
  final String prescriptionId;
  final Map<String, dynamic> prescriptionData;
  final String pharmacistId;
  final String pharmacistName;
  final String patientId;
  final String facilityId;

  const DispenseDetailsScreen({
    super.key,
    required this.prescriptionId,
    required this.prescriptionData,
    required this.pharmacistId,
    required this.pharmacistName,
    required this.patientId,
    required this.facilityId,
  });

  @override
  State<DispenseDetailsScreen> createState() => _DispenseDetailsScreenState();
}

class _DispenseDetailsScreenState extends State<DispenseDetailsScreen> {
  final Map<int, TextEditingController> _priceControllers = {};
  final Map<int, bool> _dispensedItems = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final prescriptions =
        widget.prescriptionData['prescriptions'] as List<dynamic>;
    final dispensedItems =
        widget.prescriptionData['dispensedItems'] as List<dynamic>? ?? [];

    for (int i = 0; i < prescriptions.length; i++) {
      _priceControllers[i] = TextEditingController();
      // Check if item has already been dispensed by comparing with dispensedItems
      final prescription = prescriptions[i] as Map<String, dynamic>;
      final medicationName = prescription['medication'] as String;
      final dosage = prescription['dosage'] as String;

      // Check if this medication/dosage combination has been dispensed
      bool alreadyDispensed = dispensedItems.any((dispensed) {
        return dispensed['medication'] == medicationName &&
            dispensed['dosage'] == dosage;
      });

      _dispensedItems[i] =
          !alreadyDispensed; // Only allow dispensing if not already dispensed
    }
  }

  @override
  void dispose() {
    _priceControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  double _calculateTotalCost() {
    double total = 0.0;
    _priceControllers.forEach((index, controller) {
      if (_dispensedItems[index] == true) {
        final price = double.tryParse(controller.text) ?? 0.0;
        total += price;
      }
    });
    return total;
  }

  Future<void> _dispenseAndDeduct() async {
    // Validate that at least one item is selected for dispensing
    bool hasDispensedItems = _dispensedItems.values.any(
      (dispensed) => dispensed,
    );
    if (!hasDispensedItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item to dispense'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate that all dispensed items have prices
    for (var entry in _dispensedItems.entries) {
      if (entry.value && (_priceControllers[entry.key]?.text.isEmpty ?? true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter price for all dispensed items'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final totalCost = _calculateTotalCost();
    if (totalCost == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Total cost cannot be zero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final patientId = widget.prescriptionData['patientId'];
      final patientName = widget.prescriptionData['patientName'];

      // Get patient document
      final patientDoc = await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(patientId)
          .get();

      final patientData = patientDoc.data();
      if (patientData == null) {
        throw Exception('Patient not found');
      }

      // Check patient registration type to determine wallet type
      final registrationType =
          patientData['registrationType']
              as String?; // 'household' or 'individual'

      double walletBalance = 0.0;
      String? householdId;
      String?
      actualWalletUserId; // Track the actual wallet userId for deduction
      bool useHouseholdWallet = false;

      if (registrationType == 'household') {
        // For household members, use household wallet
        useHouseholdWallet = true;
        householdId = patientData['householdId'] as String?;
        if (householdId == null || householdId.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Patient not assigned to a household. Please assign to household first.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        // Get household wallet balance
        final householdDoc = await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(householdId)
            .get();

        walletBalance =
            (householdDoc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      } else {
        // For individual patients, use individual wallet from wallets collection
        // Try multiple strategies to find the correct wallet
        String? walletUserId = patientId;

        // Strategy 1: Try patientId directly
        var individualWalletDoc = await FirebaseFirestore.instance
            .collection('wallets')
            .doc(walletUserId)
            .get();

        if (individualWalletDoc.exists && individualWalletDoc.data() != null) {
          walletBalance =
              (individualWalletDoc.data()!['balance'] as num?)?.toDouble() ??
              0.0;
          actualWalletUserId = walletUserId;
        } else {
          // Strategy 2: Try other user IDs from patient data
          final alternateUserId =
              patientData['userId'] ??
              patientData['uid'] ??
              patientData['patientId'];
          if (alternateUserId != null && alternateUserId != walletUserId) {
            individualWalletDoc = await FirebaseFirestore.instance
                .collection('wallets')
                .doc(alternateUserId)
                .get();

            if (individualWalletDoc.exists &&
                individualWalletDoc.data() != null) {
              walletBalance =
                  (individualWalletDoc.data()!['balance'] as num?)
                      ?.toDouble() ??
                  0.0;
              walletUserId = alternateUserId;
              actualWalletUserId = alternateUserId;
            }
          }

          // Strategy 3: Try facility_patients wallet if available
          if (walletBalance == 0.0) {
            final facilityWalletDoc = await FirebaseFirestore.instance
                .collection('facility_patients')
                .doc(patientId)
                .collection('wallet')
                .doc('main')
                .get();

            if (facilityWalletDoc.exists && facilityWalletDoc.data() != null) {
              walletBalance =
                  (facilityWalletDoc.data()!['balance'] as num?)?.toDouble() ??
                  0.0;
              // Note: This is a subcollection, deduction will need special handling
            }
          }
        }
      }

      if (walletBalance < totalCost) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient ${useHouseholdWallet ? "household" : "patient"} wallet balance. Required: ₦${totalCost.toStringAsFixed(2)}, Available: ₦${walletBalance.toStringAsFixed(2)}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Prepare dispensed items
      final prescriptions =
          widget.prescriptionData['prescriptions'] as List<dynamic>;
      final dispensedMedications = <Map<String, dynamic>>[];

      _dispensedItems.forEach((index, isDispensed) {
        if (isDispensed) {
          final rx = prescriptions[index] as Map<String, dynamic>;
          dispensedMedications.add({
            ...rx,
            'price': double.parse(_priceControllers[index]!.text),
          });
        }
      });

      // Check if all items are being dispensed
      final allItemsDispensed = _dispensedItems.values.every(
        (dispensed) => dispensed,
      );
      final prescriptionStatus = allItemsDispensed ? 'dispensed' : 'pending';

      // Prepare dispensing record
      final now = DateTime.now();
      final dispensingRecord = {
        'dispensingId': FirebaseFirestore.instance
            .collection('dispensing_history')
            .doc()
            .id,
        'dispensedBy': widget.pharmacistName,
        'dispensedById': widget.pharmacistId,
        'dispensedAt': Timestamp.fromDate(
          now,
        ), // Use Timestamp instead of FieldValue for storage
        'totalCost': totalCost,
        'dispensedItems': dispensedMedications,
        'paymentMethod': useHouseholdWallet
            ? 'household_wallet'
            : 'individual_wallet',
      };

      // Update prescription status and details (split into separate operations)

      // If not all items are dispensed, keep track of what has been dispensed
      if (!allItemsDispensed) {
        // For partial dispensing, we need to merge with existing data
        final existingDispensedItems =
            widget.prescriptionData['dispensedItems'] as List<dynamic>? ?? [];
        final existingHistory =
            widget.prescriptionData['dispensingHistory'] as List<dynamic>? ??
            [];
        final existingCost =
            widget.prescriptionData['totalDispensedCost'] as num? ?? 0.0;

        final updatedDispensedItems = [
          ...existingDispensedItems,
          ...dispensedMedications,
        ];
        final updatedHistory = [...existingHistory, dispensingRecord];
        final updatedCost = existingCost + totalCost;

        await FirebaseFirestore.instance
            .collection('pending_prescriptions')
            .doc(widget.prescriptionId)
            .update({
              'dispensingHistory': updatedHistory,
              'partiallyDispensed': true,
              'lastDispensingAt': FieldValue.serverTimestamp(),
              'dispensedItems': updatedDispensedItems,
              'totalDispensedCost': updatedCost,
            });
      } else {
        // All items dispensed - mark as fully dispensed
        await FirebaseFirestore.instance
            .collection('pending_prescriptions')
            .doc(widget.prescriptionId)
            .update({
              'dispensedBy': widget.pharmacistName,
              'dispensedById': widget.pharmacistId,
              'dispensedAt': FieldValue.serverTimestamp(),
              'totalCost': totalCost,
              'dispensedItems': dispensedMedications,
              'totalDispensedCost': totalCost,
            });
      }

      // Create dispensing history record
      await FirebaseFirestore.instance
          .collection('dispensing_history')
          .doc(dispensingRecord['dispensingId'] as String)
          .set({
            ...dispensingRecord,
            'prescriptionId': widget.prescriptionId,
            'patientId': widget.patientId,
            'facilityId': widget.facilityId,
            'isPartialDispensing': !allItemsDispensed,
          });

      // AUTOMATIC INVENTORY UPDATE: Deduct dispensed medications from inventory
      final batch = FirebaseFirestore.instance.batch();
      final List<String> inventoryWarnings = [];

      for (var medication in dispensedMedications) {
        final medicationName = medication['medication'] as String;
        final strength = medication['strength'] as String? ?? '';

        // Query inventory for matching medication (case-insensitive)
        final inventoryQuery = await FirebaseFirestore.instance
            .collection('pharmacy_inventory')
            .where('facilityId', isEqualTo: widget.facilityId)
            .get();

        // Find matching inventory item by name and strength
        DocumentSnapshot? matchingItem;
        for (var doc in inventoryQuery.docs) {
          final data = doc.data();
          final inventoryName = (data['medicationName'] as String? ?? '')
              .toLowerCase();
          final inventoryStrength = (data['strength'] as String? ?? '')
              .toLowerCase();

          if (inventoryName == medicationName.toLowerCase() &&
              inventoryStrength == strength.toLowerCase()) {
            matchingItem = doc;
            break;
          }
        }

        if (matchingItem != null) {
          final currentQuantity =
              (matchingItem.data() as Map<String, dynamic>)['quantity']
                  as int? ??
              0;
          final reorderLevel =
              (matchingItem.data() as Map<String, dynamic>)['reorderLevel']
                  as int? ??
              10;

          // Deduct 1 unit from inventory (assuming each prescription item = 1 unit)
          // In real implementation, you might want to track actual quantities dispensed
          final newQuantity = currentQuantity - 1;

          if (currentQuantity <= 0) {
            inventoryWarnings.add(
              '⚠️ $medicationName $strength is out of stock in inventory!',
            );
          } else if (newQuantity <= reorderLevel) {
            inventoryWarnings.add(
              '⚠️ $medicationName $strength is now at low stock level!',
            );
          }

          // Update inventory quantity
          batch.update(matchingItem.reference, {
            'quantity': FieldValue.increment(-1),
            'lastDispensedAt': FieldValue.serverTimestamp(),
            'lastDispensedBy': widget.pharmacistName,
          });
        } else {
          inventoryWarnings.add(
            '⚠️ $medicationName $strength not found in inventory system',
          );
        }
      }

      // Commit inventory updates
      await batch.commit();

      // Update prescription status and details (split into separate operations)
      await FirebaseFirestore.instance
          .collection('pending_prescriptions')
          .doc(widget.prescriptionId)
          .update({
            'status': prescriptionStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Additional updates based on dispensing type
      if (!allItemsDispensed) {
        final existingDispensedItems =
            widget.prescriptionData['dispensedItems'] as List<dynamic>? ?? [];
        final existingHistory =
            widget.prescriptionData['dispensingHistory'] as List<dynamic>? ??
            [];
        final existingCost =
            widget.prescriptionData['totalDispensedCost'] as num? ?? 0.0;

        final updatedDispensedItems = [
          ...existingDispensedItems,
          ...dispensedMedications,
        ];
        final updatedHistory = [...existingHistory, dispensingRecord];
        final updatedCost = existingCost + totalCost;

        await FirebaseFirestore.instance
            .collection('pending_prescriptions')
            .doc(widget.prescriptionId)
            .update({
              'dispensingHistory': updatedHistory,
              'partiallyDispensed': true,
              'lastDispensingAt': FieldValue.serverTimestamp(),
              'dispensedItems': updatedDispensedItems,
              'totalDispensedCost': updatedCost,
            });
      } else {
        await FirebaseFirestore.instance
            .collection('pending_prescriptions')
            .doc(widget.prescriptionId)
            .update({
              'dispensedBy': widget.pharmacistName,
              'dispensedById': widget.pharmacistId,
              'dispensedAt': FieldValue.serverTimestamp(),
              'totalCost': totalCost,
              'dispensedItems': dispensedMedications,
              'totalDispensedCost': totalCost,
            });
      }

      // Deduct from appropriate wallet
      if (useHouseholdWallet && householdId != null) {
        // Deduct from household wallet for household members
        await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(householdId)
            .update({'balance': FieldValue.increment(-totalCost)});

        // Record transaction in household
        await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(householdId)
            .collection('transactions')
            .add({
              'type': 'debit',
              'amount': totalCost,
              'description':
                  'Pharmacy - Medication dispensing for $patientName',
              'patientId': patientId,
              'patientName': patientName,
              'dispensedBy': widget.pharmacistName,
              'timestamp': FieldValue.serverTimestamp(),
            });
      } else {
        // Deduct from individual patient wallet
        if (actualWalletUserId != null) {
          await FirebaseFirestore.instance
              .collection('wallets')
              .doc(actualWalletUserId)
              .update({'balance': FieldValue.increment(-totalCost)});

          // Record transaction for patient
          await FirebaseFirestore.instance
              .collection('wallets')
              .doc(actualWalletUserId)
              .collection('transactions')
              .add({
                'type': 'debit',
                'amount': totalCost,
                'description': 'Pharmacy - Medication dispensing',
                'dispensedBy': widget.pharmacistName,
                'timestamp': FieldValue.serverTimestamp(),
              });
        }
      }

      // Credit the facility wallet
      final facilityId = widget.prescriptionData['facilityId'];
      if (facilityId != null) {
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(facilityId)
            .update({
              'balance': FieldValue.increment(totalCost),
              'updatedAt': FieldValue.serverTimestamp(),
            });

        // Record transaction in facility wallet
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(facilityId)
            .collection('transactions')
            .add({
              'type': 'credit',
              'amount': totalCost,
              'description':
                  'Pharmacy revenue - Medication dispensing for $patientName',
              'patientId': patientId,
              'patientName': patientName,
              'pharmacistId': widget.pharmacistId,
              'pharmacistName': widget.pharmacistName,
              'timestamp': FieldValue.serverTimestamp(),
              'status': 'completed',
            });
      }

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Medications dispensed. ₦${totalCost.toStringAsFixed(2)} deducted from wallet.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Show inventory warnings if any
        if (inventoryWarnings.isNotEmpty) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Inventory Alerts'),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: inventoryWarnings
                          .map(
                            (warning) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(warning),
                            ),
                          )
                          .toList(),
                    ),
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
          });
        }

        Navigator.pop(context);
        Navigator.pop(context); // Go back to main list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error dispensing medications: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prescriptions =
        widget.prescriptionData['prescriptions'] as List<dynamic>;
    final timestamp = widget.prescriptionData['createdAt'] as Timestamp?;

    return Scaffold(
      appBar: AppBar(title: const Text('Dispense Medications')),
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
                    'Patient: ${widget.prescriptionData['patientName']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Prescribed by: ${widget.prescriptionData['clinicianName']}',
                  ),
                  if (timestamp != null)
                    Text(
                      'Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate())}',
                    ),
                ],
              ),
            ),
          ),

          // Medications List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: prescriptions.length,
              itemBuilder: (context, index) {
                final rx = prescriptions[index] as Map<String, dynamic>;
                final medicationName = rx['medication'] as String;
                final dosage = rx['dosage'] as String;
                final dispensedItems =
                    widget.prescriptionData['dispensedItems']
                        as List<dynamic>? ??
                    [];

                // Check if this medication/dosage combination has been dispensed
                final isAlreadyDispensed = dispensedItems.any((dispensed) {
                  return dispensed['medication'] == medicationName &&
                      dispensed['dosage'] == dosage;
                });

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: isAlreadyDispensed ? Colors.grey[100] : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _dispensedItems[index],
                              onChanged: isAlreadyDispensed
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _dispensedItems[index] = value ?? false;
                                      });
                                    },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${rx['medication']} ${rx['strength']}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            decoration: isAlreadyDispensed
                                                ? TextDecoration.lineThrough
                                                : null,
                                            color: isAlreadyDispensed
                                                ? Colors.grey
                                                : null,
                                          ),
                                        ),
                                      ),
                                      if (isAlreadyDispensed)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green[100],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Text(
                                            'Already Dispensed',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    'Dosage: ${rx['dosage']}',
                                    style: TextStyle(
                                      color: isAlreadyDispensed
                                          ? Colors.grey
                                          : null,
                                    ),
                                  ),
                                  Text(
                                    'Duration: ${rx['duration']}',
                                    style: TextStyle(
                                      color: isAlreadyDispensed
                                          ? Colors.grey
                                          : null,
                                    ),
                                  ),
                                  if (rx['instructions']
                                          ?.toString()
                                          .isNotEmpty ??
                                      false)
                                    Text(
                                      'Instructions: ${rx['instructions']}',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: isAlreadyDispensed
                                            ? Colors.grey[500]
                                            : Colors.grey[700],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_dispensedItems[index] == true &&
                            !isAlreadyDispensed) ...[
                          const Divider(height: 16),
                          TextField(
                            controller: _priceControllers[index],
                            decoration: const InputDecoration(
                              labelText: 'Price (₦)',
                              hintText: 'Enter price',
                              border: OutlineInputBorder(),
                              prefixText: '₦ ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                        if (isAlreadyDispensed) ...[
                          const Divider(height: 16),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Previously dispensed price:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  '₦${dispensedItems.firstWhere((dispensed) => dispensed['medication'] == medicationName && dispensed['dosage'] == dosage)['price']?.toStringAsFixed(2) ?? 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Cost Summary and Dispense Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Cost:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₦${_calculateTotalCost().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _dispenseAndDeduct,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Dispense Selected Items',
                              style: TextStyle(fontSize: 16),
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
  }
}

class DirectDispensingDetailsScreen extends StatefulWidget {
  final String facilityId;
  final String pharmacistId;
  final String pharmacistName;
  final String? patientId;
  final String? patientName;

  const DirectDispensingDetailsScreen({
    super.key,
    required this.facilityId,
    required this.pharmacistId,
    required this.pharmacistName,
    this.patientId,
    this.patientName,
  });

  @override
  State<DirectDispensingDetailsScreen> createState() =>
      _DirectDispensingDetailsScreenState();
}

class _DirectDispensingDetailsScreenState
    extends State<DirectDispensingDetailsScreen> {
  final _patientNameController = TextEditingController();
  final _notesController = TextEditingController();
  final _patientSearchController = TextEditingController();
  String _patientSearchQuery = '';
  final List<Map<String, dynamic>> _selectedItems = [];
  bool _isLoading = false;

  String? _selectedPatientId;
  String? _selectedPatientName;
  double _patientWalletBalance = 0.0;
  bool _isWalkInPatient = true; // Default to walk-in

  @override
  void initState() {
    super.initState();
    // If patientId and patientName were passed, initialize them
    if (widget.patientId != null && widget.patientName != null) {
      _selectedPatientId = widget.patientId;
      _selectedPatientName = widget.patientName;
      _patientNameController.text = widget.patientName ?? '';
      _isWalkInPatient = false;
    }
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _notesController.dispose();
    _patientSearchController.dispose();
    super.dispose();
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => _InventorySelectionDialog(
        facilityId: widget.facilityId,
        onItemSelected: (item) {
          setState(() {
            final itemName =
                item['medicationName'] ??
                item['name'] ??
                item['itemName'] ??
                'Unknown Item';
            final strength = item['strength'] ?? '';
            final stock = item['currentStock'] ?? item['quantity'] ?? 0;
            final price = (item['price'] ?? item['cost'] ?? 0).toDouble();

            _selectedItems.add({
              'itemId': item['itemId'],
              'medicationName': itemName,
              'name': itemName,
              'itemName': itemName,
              'strength': strength,
              'quantity': 1,
              'price': price,
              'availableStock': stock,
              'currentStock': stock,
              ...item, // Include all original fields for reference
            });
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
  }

  double _calculateTotalCost() {
    return _selectedItems.fold(
      0.0,
      (sum, item) => sum + (item['price'] * item['quantity']),
    );
  }

  Future<void> _dispenseItems() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items selected'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate patient selection for registered patients
    if (!_isWalkInPatient && _selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a registered patient'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate quantities and prices
    for (var item in _selectedItems) {
      if (item['quantity'] <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All quantities must be greater than 0'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (item['price'] < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prices cannot be negative'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (item['quantity'] > item['availableStock']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient stock for ${item['medicationName']}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final totalCost = _calculateTotalCost();

    // Check wallet balance for registered patients
    if (!_isWalkInPatient && _selectedPatientId != null) {
      if (_patientWalletBalance < totalCost) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient wallet balance. Required: ₦${totalCost.toStringAsFixed(2)}, Available: ₦${_patientWalletBalance.toStringAsFixed(2)}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Deduct from patient wallet if registered patient
      if (!_isWalkInPatient && _selectedPatientId != null) {
        // Get patient data to determine wallet type
        final patientDoc = await FirebaseFirestore.instance
            .collection('facility_patients')
            .doc(_selectedPatientId)
            .get();

        if (!patientDoc.exists) {
          throw Exception('Patient not found');
        }

        final patientData = patientDoc.data()!;
        final registrationType = patientData['registrationType'] as String?;
        String? walletUserId = _selectedPatientId;
        String? householdId;

        if (registrationType == 'household') {
          householdId = patientData['householdId'] as String?;
          if (householdId == null || householdId.isEmpty) {
            throw Exception('Patient not assigned to a household');
          }
          // Deduct from household wallet
          final householdWalletRef = FirebaseFirestore.instance
              .collection('household_wallets')
              .doc(householdId);
          batch.update(householdWalletRef, {
            'balance': FieldValue.increment(-totalCost),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // For individual patients, find the correct wallet
          var individualWalletDoc = await FirebaseFirestore.instance
              .collection('wallets')
              .doc(walletUserId)
              .get();

          if (!individualWalletDoc.exists ||
              individualWalletDoc.data() == null) {
            // Try alternate user IDs
            final alternateUserId =
                patientData['userId'] ??
                patientData['uid'] ??
                patientData['patientId'];
            if (alternateUserId != null && alternateUserId != walletUserId) {
              individualWalletDoc = await FirebaseFirestore.instance
                  .collection('wallets')
                  .doc(alternateUserId)
                  .get();
              if (individualWalletDoc.exists &&
                  individualWalletDoc.data() != null) {
                walletUserId = alternateUserId;
              }
            }
          }

          if (individualWalletDoc.exists &&
              individualWalletDoc.data() != null) {
            // Deduct from individual wallet
            final walletRef = FirebaseFirestore.instance
                .collection('wallets')
                .doc(walletUserId);
            batch.update(walletRef, {
              'balance': FieldValue.increment(-totalCost),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            throw Exception('Patient wallet not found');
          }
        }
      }

      // Update inventory for each item
      for (var item in _selectedItems) {
        final itemRef = FirebaseFirestore.instance
            .collection('pharmacy_inventory')
            .doc(item['itemId']);
        batch.update(itemRef, {
          'currentStock': FieldValue.increment(-item['quantity']),
          'lastUpdated': FieldValue.serverTimestamp(),
          'transactions': FieldValue.arrayUnion([
            {
              'type': 'direct_dispensing',
              'quantity': -item['quantity'],
              'timestamp': Timestamp.now(),
              'performedBy': widget.pharmacistName,
              'reason': 'Direct dispensing',
              'previousStock': item['availableStock'],
              'newStock': item['availableStock'] - item['quantity'],
            },
          ]),
        });
      }

      // Create dispensing history record
      final dispensingRef = FirebaseFirestore.instance
          .collection('dispensing_history')
          .doc();
      batch.set(dispensingRef, {
        'dispensingId': dispensingRef.id,
        'facilityId': widget.facilityId,
        'facilityName': '', // Could add facility name if needed
        'patientId': _isWalkInPatient ? null : _selectedPatientId,
        'patientName': _isWalkInPatient
            ? (_patientNameController.text.trim().isEmpty
                  ? 'Walk-in Patient'
                  : _patientNameController.text.trim())
            : _selectedPatientName,
        'dispensedBy': widget.pharmacistId,
        'dispensedByName': widget.pharmacistName,
        'dispensedAt': FieldValue.serverTimestamp(),
        'medications': _selectedItems
            .map(
              (item) => {
                'name': item['medicationName'],
                'strength': item['strength'],
                'dosage': 'N/A',
                'quantity': item['quantity'],
                'price': item['price'],
              },
            )
            .toList(),
        'totalCost': totalCost,
        'type': 'direct_dispensing',
        'notes': _notesController.text.trim(),
        'status': 'completed',
        'walletDeducted': !_isWalkInPatient && _selectedPatientId != null,
        'walletDeductionAmount': !_isWalkInPatient && _selectedPatientId != null
            ? totalCost
            : 0.0,
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isWalkInPatient
                  ? 'Items dispensed successfully'
                  : 'Items dispensed and charged to patient wallet',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error dispensing items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Direct Dispensing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addItem,
            tooltip: 'Add Item',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Patient type selection
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Walk-in Patient'),
                        value: true,
                        groupValue: _isWalkInPatient,
                        onChanged: (value) {
                          setState(() {
                            _isWalkInPatient = value!;
                            if (_isWalkInPatient) {
                              _selectedPatientId = null;
                              _selectedPatientName = null;
                              _patientWalletBalance = 0.0;
                            }
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Registered Patient'),
                        value: false,
                        groupValue: _isWalkInPatient,
                        onChanged: (value) {
                          setState(() {
                            _isWalkInPatient = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Patient selection or name input
                if (_isWalkInPatient)
                  TextField(
                    controller: _patientNameController,
                    decoration: const InputDecoration(
                      labelText: 'Patient Name (Optional)',
                      border: OutlineInputBorder(),
                      hintText: 'Walk-in patient if empty',
                    ),
                  )
                else
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('facility_patients')
                        .where('facilityId', isEqualTo: widget.facilityId)
                        .orderBy('fullName')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }

                      final allPatients = snapshot.data!.docs;

                      // Filter patients based on search query
                      final filteredPatients = allPatients.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final fullName = (data['fullName'] as String? ?? '')
                            .toLowerCase();
                        final registrationNumber =
                            (data['registrationNumber'] as String? ?? '')
                                .toLowerCase();
                        return _patientSearchQuery.isEmpty ||
                            fullName.contains(_patientSearchQuery) ||
                            registrationNumber.contains(_patientSearchQuery);
                      }).toList();

                      return Column(
                        children: [
                          // Search field
                          TextField(
                            controller: _patientSearchController,
                            decoration: InputDecoration(
                              labelText: 'Search Patient',
                              hintText: 'By name or registration number...',
                              prefixIcon: const Icon(Icons.search),
                              border: const OutlineInputBorder(),
                              suffixIcon:
                                  _patientSearchController.text.isNotEmpty
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
                          const SizedBox(height: 8),
                          // Patient dropdown with filtered results
                          DropdownButtonFormField<String>(
                            value: _selectedPatientId,
                            decoration: const InputDecoration(
                              labelText: 'Select Patient',
                              border: OutlineInputBorder(),
                            ),
                            items: filteredPatients.isEmpty
                                ? [
                                    DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(
                                        _patientSearchQuery.isNotEmpty
                                            ? 'No patients found'
                                            : 'No patients available',
                                      ),
                                    ),
                                  ]
                                : filteredPatients.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    return DropdownMenuItem<String>(
                                      value: doc.id,
                                      child: Text(
                                        '${data['fullName'] ?? 'Unknown'} (${data['registrationNumber'] ?? doc.id})',
                                      ),
                                    );
                                  }).toList(),
                            onChanged: (value) async {
                              if (value != null) {
                                final patientDoc = await FirebaseFirestore
                                    .instance
                                    .collection('facility_patients')
                                    .doc(value)
                                    .get();
                                final patientData = patientDoc.data()!;
                                final patientName =
                                    patientData['fullName'] ?? 'Unknown';

                                // Get wallet balance
                                double walletBalance = 0.0;
                                final registrationType =
                                    patientData['registrationType'] as String?;

                                if (registrationType == 'household') {
                                  final householdId =
                                      patientData['householdId'] as String?;
                                  if (householdId != null) {
                                    final householdDoc = await FirebaseFirestore
                                        .instance
                                        .collection('household_wallets')
                                        .doc(householdId)
                                        .get();
                                    walletBalance =
                                        (householdDoc.data()?['balance']
                                                as num?)
                                            ?.toDouble() ??
                                        0.0;
                                  }
                                } else {
                                  // Try individual wallet
                                  String? walletUserId = value;
                                  var walletDoc = await FirebaseFirestore
                                      .instance
                                      .collection('wallets')
                                      .doc(walletUserId)
                                      .get();

                                  if (!walletDoc.exists ||
                                      walletDoc.data() == null) {
                                    final alternateUserId =
                                        patientData['userId'] ??
                                        patientData['uid'] ??
                                        patientData['patientId'];
                                    if (alternateUserId != null &&
                                        alternateUserId != walletUserId) {
                                      walletDoc = await FirebaseFirestore
                                          .instance
                                          .collection('wallets')
                                          .doc(alternateUserId)
                                          .get();
                                    }
                                  }

                                  walletBalance =
                                      (walletDoc.data()?['balance'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                                }

                                setState(() {
                                  _selectedPatientId = value;
                                  _selectedPatientName = patientName;
                                  _patientWalletBalance = walletBalance;
                                });
                              }
                            },
                            validator: (value) {
                              if (!_isWalkInPatient && value == null) {
                                return 'Please select a patient';
                              }
                              return null;
                            },
                          ),
                        ],
                      );
                    },
                  ),

                // Show wallet balance for registered patients
                if (!_isWalkInPatient && _selectedPatientId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Wallet Balance: ₦${_patientWalletBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: _patientWalletBalance > 0
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                    hintText: 'Additional notes',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedItems.isEmpty
                ? const Center(
                    child: Text('No items selected. Tap + to add items.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _selectedItems.length,
                    itemBuilder: (context, index) {
                      final item = _selectedItems[index];
                      final itemName =
                          item['medicationName'] ??
                          item['name'] ??
                          item['itemName'] ??
                          'Unknown Item';
                      final strength = item['strength'] ?? '';
                      final availableStock =
                          item['currentStock'] ??
                          item['quantity'] ??
                          item['availableStock'] ??
                          0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$itemName${strength.isNotEmpty ? ' $strength' : ''}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _removeItem(index),
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Available: $availableStock'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Quantity',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        final qty = int.tryParse(value) ?? 1;
                                        setState(() {
                                          item['quantity'] = qty;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextField(
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Price (₦)',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        final price =
                                            double.tryParse(value) ?? 0.0;
                                        setState(() {
                                          item['price'] = price;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Cost:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₦${_calculateTotalCost().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _dispenseItems,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Dispense Items'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventorySelectionDialog extends StatefulWidget {
  final String facilityId;
  final Function(Map<String, dynamic>) onItemSelected;

  const _InventorySelectionDialog({
    required this.facilityId,
    required this.onItemSelected,
  });

  @override
  State<_InventorySelectionDialog> createState() =>
      _InventorySelectionDialogState();
}

class _InventorySelectionDialogState extends State<_InventorySelectionDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Item from Inventory'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search items...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('pharmacy_inventory')
                    .where('facilityId', isEqualTo: widget.facilityId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name =
                        (data['medicationName'] ??
                                data['name'] ??
                                data['itemName'] ??
                                '')
                            .toString()
                            .toLowerCase();
                    final quantity =
                        (data['currentStock'] ?? data['quantity'] ?? 0) as num;
                    return name.contains(_searchQuery) && quantity > 0;
                  }).toList();

                  if (items.isEmpty) {
                    return const Center(child: Text('No items found'));
                  }

                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final doc = items[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final itemName =
                          data['medicationName'] ??
                          data['name'] ??
                          data['itemName'] ??
                          'Unknown Item';
                      final strength = data['strength'] ?? '';
                      final quantity =
                          data['currentStock'] ?? data['quantity'] ?? 0;
                      return ListTile(
                        title: Text(
                          '$itemName${strength.isNotEmpty ? ' $strength' : ''}',
                        ),
                        subtitle: Text('Stock: $quantity'),
                        onTap: () {
                          // Normalize the data before passing to ensure item name is always available
                          final normalizedItem = {
                            'itemId': doc.id,
                            'medicationName': itemName,
                            'name': itemName,
                            'itemName': itemName,
                            'strength': strength,
                            'currentStock': quantity,
                            'quantity': quantity,
                            ...data,
                          };
                          widget.onItemSelected(normalizedItem);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
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
      ],
    );
  }
}
