import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

class WardAdmissionBillingScreen extends StatefulWidget {
  final String admissionId;
  final String facilityId;
  final String facilityName;

  const WardAdmissionBillingScreen({
    super.key,
    required this.admissionId,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<WardAdmissionBillingScreen> createState() =>
      _WardAdmissionBillingScreenState();
}

class _WardAdmissionBillingScreenState
    extends State<WardAdmissionBillingScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _billingSummary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBillingSummary();
  }

  Future<void> _loadBillingSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Query Firestore directly instead of using Cloud Function
      // This allows non-authenticated facility staff to view billing
      final admissionRef = FirebaseFirestore.instance
          .collection('inpatients')
          .doc(widget.admissionId);

      final admissionDoc = await admissionRef.get();

      if (!admissionDoc.exists) {
        setState(() {
          _error = 'Admission not found';
          _isLoading = false;
        });
        return;
      }

      final admissionData = admissionDoc.data() as Map<String, dynamic>;

      // Get billing history
      final billingHistorySnapshot = await admissionRef
          .collection('billing_history')
          .orderBy('createdAt', descending: true)
          .get();

      final billingHistory = billingHistorySnapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();

      // Calculate summary
      final totalCharged =
          (admissionData['totalChargedAmount'] as num?)?.toDouble() ?? 0.0;
      final chargeCount = admissionData['chargeCount'] as int? ?? 0;
      final chargePerNight =
          (admissionData['chargePerNight'] as num?)?.toDouble() ?? 0.0;

      // Calculate days admitted
      final admissionDate =
          (admissionData['admittedAt'] as Timestamp?)?.toDate() ??
          (admissionData['admissionDate'] as Timestamp?)?.toDate() ??
          DateTime.now();
      final now = DateTime.now();
      final daysAdmitted = now.difference(admissionDate).inDays;

      final expectedCharges = daysAdmitted * chargePerNight;
      final unpaidAmount = expectedCharges - totalCharged;

      setState(() {
        _billingSummary = {
          'success': true,
          'admissionId': widget.admissionId,
          'patientName': admissionData['patientName'] ?? 'Unknown',
          'status': admissionData['status'] ?? 'admitted',
          'admissionDate': admissionDate.toIso8601String(),
          'daysAdmitted': daysAdmitted,
          'chargePerNight': chargePerNight,
          'totalCharged': totalCharged,
          'chargeCount': chargeCount,
          'expectedCharges': expectedCharges,
          'unpaidAmount': unpaidAmount,
          'hasPaymentIssue': admissionData['paymentIssue'] ?? false,
          'billingHistory': billingHistory,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading billing summary: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _chargeNow() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Charge Now'),
        content: Text(
          'Charge ₦${(_billingSummary?['chargePerNight'] ?? 0).toStringAsFixed(2)} for today\'s ward stay?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Charge'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'chargeAdmissionNow',
      );
      final result = await callable.call({'admissionId': widget.admissionId});

      if (result.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully charged ₦${result.data['chargeAmount'].toStringAsFixed(2)}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadBillingSummary();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.data['error'] ?? 'Failed to process charge'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ward Admission Billing'),
        backgroundColor: Colors.purple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadBillingSummary,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  _buildHeaderCard(),
                  const SizedBox(height: 16),

                  // Billing Summary Card
                  _buildBillingSummaryCard(),
                  const SizedBox(height: 16),

                  // Payment Issue Alert (if any)
                  if (_billingSummary?['hasPaymentIssue'] == true)
                    _buildPaymentIssueAlert(),

                  const SizedBox(height: 16),

                  // Billing History
                  _buildBillingHistory(),
                ],
              ),
            ),
      floatingActionButton:
          !_isLoading &&
              _error == null &&
              _billingSummary?['status'] == 'admitted'
          ? FloatingActionButton.extended(
              onPressed: _chargeNow,
              backgroundColor: Colors.orange,
              icon: const Icon(Icons.payment),
              label: const Text('Charge Now'),
            )
          : null,
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade400, Colors.purple.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _billingSummary?['patientName'] ?? 'Patient',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        widget.facilityName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_billingSummary?['status']),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    (_billingSummary?['status'] ?? 'Unknown').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white30),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Days Admitted',
                    '${_billingSummary?['daysAdmitted'] ?? 0} days',
                    Icons.calendar_today,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Per Night',
                    '₦${(_billingSummary?['chargePerNight'] ?? 0).toStringAsFixed(2)}',
                    Icons.hotel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildBillingSummaryCard() {
    final totalCharged = (_billingSummary?['totalCharged'] ?? 0).toDouble();
    final expectedCharges = (_billingSummary?['expectedCharges'] ?? 0)
        .toDouble();
    final unpaidAmount = (_billingSummary?['unpaidAmount'] ?? 0).toDouble();
    final chargeCount = _billingSummary?['chargeCount'] ?? 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Billing Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(
              'Total Charges',
              '₦${totalCharged.toStringAsFixed(2)}',
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Expected Charges',
              '₦${expectedCharges.toStringAsFixed(2)}',
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Unpaid Amount',
              '₦${unpaidAmount.toStringAsFixed(2)}',
              unpaidAmount > 0 ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow('Number of Charges', '$chargeCount', Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentIssueAlert() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red.shade700, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Issue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Patient has insufficient balance for ward charges. Please top up wallet or contact patient.',
                    style: TextStyle(fontSize: 14, color: Colors.red.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingHistory() {
    final billingHistory = _billingSummary?['billingHistory'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Billing History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (billingHistory.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No billing history yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ...billingHistory.map((billing) => _buildBillingHistoryCard(billing)),
      ],
    );
  }

  Widget _buildBillingHistoryCard(Map<String, dynamic> billing) {
    final status = billing['status'] ?? 'unknown';
    final amount = (billing['chargeAmount'] ?? 0).toDouble();
    final description = billing['description'] ?? 'Ward charge';
    final chargeDate = billing['chargeDate'];

    DateTime? dateTime;
    if (chargeDate != null) {
      if (chargeDate is Timestamp) {
        dateTime = chargeDate.toDate();
      } else if (chargeDate is String) {
        dateTime = DateTime.tryParse(chargeDate);
      }
    }

    final dateStr = dateTime != null
        ? DateFormat('MMM dd, yyyy hh:mm a').format(dateTime)
        : 'N/A';

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'successful':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'insufficient_balance':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          description,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(dateStr, style: const TextStyle(fontSize: 12)),
            Text(
              status.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: Text(
          '₦${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: status == 'successful' ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'admitted':
        return Colors.blue;
      case 'discharged':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
