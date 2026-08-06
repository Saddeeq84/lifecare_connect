import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../utils/print_utils.dart';
import '../../../shared/services/ai_validation_service.dart';
import '../../../shared/widgets/ai_validation_dialog.dart';

class LabResultsEntryScreen extends StatefulWidget {
  final String facilityId;
  final String laboratoryStaffId;
  final String laboratoryStaffName;

  const LabResultsEntryScreen({
    super.key,
    required this.facilityId,
    required this.laboratoryStaffId,
    required this.laboratoryStaffName,
  });

  @override
  State<LabResultsEntryScreen> createState() => _LabResultsEntryScreenState();
}

class _LabResultsEntryScreenState extends State<LabResultsEntryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('Laboratory Tests & Results'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending Tests'),
            Tab(text: 'Completed Results'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPendingTestsTab(), _buildCompletedResultsTab()],
      ),
    );
  }

  Widget _buildPendingTestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pending_lab_tests')
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
                Icon(Icons.science_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending lab tests',
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
            final timestamp = data['createdAt'] as Timestamp?;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () => _viewPendingTestDetails(doc.id, data),
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
                              data['testName'] ?? 'Unknown Test',
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
                              borderRadius: BorderRadius.circular(20),
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
                      const Divider(height: 16),
                      Text(
                        'Patient: ${data['patientName'] ?? 'Unknown'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Requested by: ${data['clinicianName'] ?? 'Unknown'}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      if (timestamp != null)
                        Text(
                          'Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate())}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Cost: ₦${(data['cost'] as num).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _viewPendingTestDetails(doc.id, data),
                          icon: const Icon(Icons.visibility),
                          label: const Text('View'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompletedResultsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pending_lab_tests')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'completed')
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
                Icon(Icons.assignment_turned_in, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No completed lab results',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Completed test results will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
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
            final completedAt = data['completedAt'] as Timestamp?;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Status Icon
                    CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Patient Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['patientName'] ?? 'Unknown Patient',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['testType'] ?? 'Unknown Test',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                          if (completedAt != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              DateFormat(
                                'MMM dd, yyyy',
                              ).format(completedAt.toDate()),
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // View Results Button
                    ElevatedButton.icon(
                      onPressed: () =>
                          _viewCompletedResultDetails(doc.id, data),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Results'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _viewPendingTestDetails(String testId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.science_outlined, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Test Request Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoBox('Patient Information', [
                _buildDetailRow('Name', data['patientName'] ?? 'Unknown'),
                if (data['patientId'] != null)
                  _buildDetailRow('Patient ID', data['patientId']),
              ]),
              const SizedBox(height: 12),
              _buildInfoBox('Test Information', [
                _buildDetailRow('Test Name', data['testName'] ?? 'Unknown'),
                if (data['testCategory'] != null)
                  _buildDetailRow('Category', data['testCategory']),
                if (data['cost'] != null)
                  _buildDetailRow('Cost', '₦${data['cost']}'),
              ]),
              const SizedBox(height: 12),
              _buildInfoBox('Request Information', [
                if (data['clinicianName'] != null)
                  _buildDetailRow('Requested By', data['clinicianName']),
                if (data['createdAt'] != null)
                  _buildDetailRow(
                    'Requested At',
                    DateFormat(
                      'MMM dd, yyyy HH:mm',
                    ).format((data['createdAt'] as Timestamp).toDate()),
                  ),
                if (data['notes'] != null)
                  _buildDetailRow('Notes', data['notes']),
              ]),
              const SizedBox(height: 12),
              Container(
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
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Results should be entered in the Sample Collection screen under the Processing tab.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _viewCompletedResultDetails(String resultId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 900),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Print Button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Laboratory Test Results',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _printResults(data),
                      icon: const Icon(Icons.print, color: Colors.white),
                      tooltip: 'Print Results',
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.green.shade300,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                color: Colors.green.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'COMPLETED',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Patient Information
                      _buildEnhancedSection(
                        'Patient Information',
                        Icons.person,
                        Colors.blue,
                        [
                          _buildEnhancedDetailRow(
                            'Patient Name',
                            data['patientName'] ?? 'Unknown',
                            isBold: true,
                          ),
                          if (data['patientId'] != null)
                            _buildEnhancedDetailRow(
                              'Patient ID',
                              data['patientId'],
                            ),
                          if (data['sampleId'] != null)
                            _buildEnhancedDetailRow(
                              'Sample ID',
                              data['sampleId'],
                              highlight: true,
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Test Information
                      _buildEnhancedSection(
                        'Test Information',
                        Icons.science,
                        Colors.purple,
                        [
                          _buildEnhancedDetailRow(
                            'Test Type',
                            data['testType'] ?? 'Unknown',
                            isBold: true,
                          ),
                          if (data['sampleType'] != null)
                            _buildEnhancedDetailRow(
                              'Sample Type',
                              data['sampleType'],
                            ),
                          if (data['cost'] != null)
                            _buildEnhancedDetailRow('Cost', '₦${data['cost']}'),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Test Results - Enhanced Display
                      _buildEnhancedSection(
                        'Test Results',
                        Icons.analytics,
                        Colors.green,
                        [
                          if (data['result'] != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.favorite,
                                        color: Colors.red.shade400,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'RESULT',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    data['result'],
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          if (data['interpretation'] != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.shade200,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.lightbulb,
                                        color: Colors.orange.shade400,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'CLINICAL INTERPRETATION',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    data['interpretation'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.6,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          if (data['normalRange'] != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.straighten,
                                    color: Colors.grey.shade600,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Normal Range: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      data['normalRange'],
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Additional Notes
                      if (data['notes'] != null &&
                          data['notes'].toString().isNotEmpty) ...[
                        _buildEnhancedSection(
                          'Additional Notes',
                          Icons.notes,
                          Colors.orange,
                          [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Text(
                                data['notes'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Completion Information
                      _buildEnhancedSection(
                        'Completion Information',
                        Icons.check_circle_outline,
                        Colors.teal,
                        [
                          if (data['completedBy'] != null)
                            _buildEnhancedDetailRow(
                              'Completed By',
                              data['completedBy'],
                            ),
                          if (data['completedAt'] != null)
                            _buildEnhancedDetailRow(
                              'Completion Date & Time',
                              DateFormat('MMMM dd, yyyy • hh:mm a').format(
                                (data['completedAt'] as Timestamp).toDate(),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Footer
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.verified_user,
                              color: Colors.grey.shade600,
                              size: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This is an official laboratory result',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            Text(
                              'Generated on ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _printResults(data),
                      icon: const Icon(Icons.print),
                      label: const Text('Print'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedDetailRow(
    String label,
    String value, {
    bool isBold = false,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: highlight
                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                  : null,
              decoration: highlight
                  ? BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: highlight ? Colors.blue.shade900 : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _printResults(Map<String, dynamic> data) async {
    final completedAt = data['completedAt'] as Timestamp?;

    // Fetch facility details for email
    String facilityEmail = 'N/A';
    try {
      final facilityDoc = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(widget.facilityId)
          .get();

      if (facilityDoc.exists) {
        facilityEmail = facilityDoc.data()?['email'] ?? 'N/A';
      }
    } catch (e) {
      print('Error fetching facility email: $e');
    }

    final printContent =
        '''
      <!DOCTYPE html>
      <html>
      <head>
        <title>Laboratory Test Results - LifeCare Connect</title>
        <style>
          @media print {
            @page {
              margin: 1cm;
              size: A4;
            }
          }
          
          body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            color: #333;
            line-height: 1.6;
          }
          
          .header {
            text-align: center;
            padding: 20px 0;
            border-bottom: 3px solid #2e7d32;
            margin-bottom: 30px;
          }
          
          .doc-title {
            color: #2e7d32;
            font-size: 28px;
            font-weight: bold;
            margin: 0 0 10px 0;
          }
          
          .doc-subtitle {
            color: #666;
            font-size: 14px;
            margin-bottom: 15px;
          }
          
          .status-badge {
            display: inline-block;
            background: #e8f5e9;
            color: #2e7d32;
            padding: 8px 20px;
            border-radius: 20px;
            font-weight: bold;
            margin: 20px 0;
            border: 2px solid #2e7d32;
          }
          
          .section {
            margin-bottom: 25px;
            border: 1px solid #ddd;
            border-radius: 8px;
            overflow: hidden;
          }
          
          .section-header {
            background: #f5f5f5;
            padding: 12px 16px;
            font-weight: bold;
            font-size: 16px;
            color: #444;
            border-bottom: 1px solid #ddd;
          }
          
          .section-content {
            padding: 16px;
          }
          
          .detail-row {
            display: flex;
            padding: 8px 0;
            border-bottom: 1px solid #f0f0f0;
          }
          
          .detail-row:last-child {
            border-bottom: none;
          }
          
          .detail-label {
            font-weight: 600;
            min-width: 180px;
            color: #555;
          }
          
          .detail-value {
            flex: 1;
            color: #333;
          }
          
          .result-box {
            background: #e8f5e9;
            padding: 16px;
            border-radius: 8px;
            border: 2px solid #4caf50;
            margin: 10px 0;
          }
          
          .result-box .title {
            font-weight: bold;
            color: #2e7d32;
            margin-bottom: 8px;
            font-size: 14px;
          }
          
          .result-box .content {
            color: #333;
            white-space: pre-wrap;
            font-size: 14px;
            line-height: 1.8;
          }
          
          .interpretation-box {
            background: #e3f2fd;
            padding: 16px;
            border-radius: 8px;
            border: 2px solid #2196f3;
            margin: 10px 0;
          }
          
          .interpretation-box .title {
            font-weight: bold;
            color: #1565c0;
            margin-bottom: 8px;
            font-size: 14px;
          }
          
          .interpretation-box .content {
            color: #0d47a1;
            white-space: pre-wrap;
            font-size: 13px;
            line-height: 1.7;
          }
          
          .normal-range {
            background: #f5f5f5;
            padding: 10px;
            border-radius: 6px;
            margin: 10px 0;
            border-left: 4px solid #757575;
          }
          
          .footer {
            text-align: center;
            margin-top: 50px;
            padding: 25px 20px;
            border-top: 3px solid #2e7d32;
            background: #f9f9f9;
          }
          
          .footer-content {
            max-width: 600px;
            margin: 0 auto;
          }
          
          .footer-contact {
            color: #2e7d32;
            font-size: 14px;
            font-weight: 600;
            margin: 10px 0;
          }
          
          .footer-verification {
            color: #666;
            font-size: 11px;
            margin-top: 15px;
            padding-top: 15px;
            border-top: 1px solid #ddd;
          }
          
          .print-date {
            color: #999;
            font-size: 10px;
            margin-top: 8px;
          }
        </style>
      </head>
      <body>
        <div class="header">
          <div class="doc-title">LABORATORY TEST RESULTS</div>
          <div class="doc-subtitle">Official Medical Laboratory Report</div>
          <div class="status-badge">COMPLETED</div>
        </div>
        
        <div class="section">
          <div class="section-header">Patient Information</div>
          <div class="section-content">
            <div class="detail-row">
              <div class="detail-label">Patient Name:</div>
              <div class="detail-value"><strong>${data['patientName'] ?? 'Unknown'}</strong></div>
            </div>
            ${data['patientId'] != null ? '''
            <div class="detail-row">
              <div class="detail-label">Patient ID:</div>
              <div class="detail-value">${data['patientId']}</div>
            </div>
            ''' : ''}
            ${data['sampleId'] != null ? '''
            <div class="detail-row">
              <div class="detail-label">Sample ID:</div>
              <div class="detail-value" style="background: #e3f2fd; padding: 4px 8px; border-radius: 4px;"><strong>${data['sampleId']}</strong></div>
            </div>
            ''' : ''}
          </div>
        </div>
        
        <div class="section">
          <div class="section-header">Test Information</div>
          <div class="section-content">
            <div class="detail-row">
              <div class="detail-label">Test Type:</div>
              <div class="detail-value"><strong>${data['testType'] ?? 'Unknown'}</strong></div>
            </div>
            ${data['sampleType'] != null ? '''
            <div class="detail-row">
              <div class="detail-label">Sample Type:</div>
              <div class="detail-value">${data['sampleType']}</div>
            </div>
            ''' : ''}
            ${data['cost'] != null ? '''
            <div class="detail-row">
              <div class="detail-label">Cost:</div>
              <div class="detail-value">₦${data['cost']}</div>
            </div>
            ''' : ''}
          </div>
        </div>
        
        <div class="section">
          <div class="section-header">Test Results</div>
          <div class="section-content">
            ${data['result'] != null ? '''
            <div class="result-box">
              <div class="title">RESULT</div>
              <div class="content">${data['result']}</div>
            </div>
            ''' : '<p>No result available</p>'}
            
            ${data['interpretation'] != null ? '''
            <div class="interpretation-box">
              <div class="title">CLINICAL INTERPRETATION</div>
              <div class="content">${data['interpretation']}</div>
            </div>
            ''' : ''}
            
            ${data['normalRange'] != null ? '''
            <div class="normal-range">
              <strong>Normal Range:</strong> ${data['normalRange']}
            </div>
            ''' : ''}
          </div>
        </div>
        
        ${data['notes'] != null && data['notes'].toString().isNotEmpty ? '''
        <div class="section">
          <div class="section-header">Additional Notes</div>
          <div class="section-content">
            <div style="background: #fff3e0; padding: 12px; border-radius: 6px; border-left: 4px solid #ff9800;">
              ${data['notes']}
            </div>
          </div>
        </div>
        ''' : ''}
        
        <div class="section">
          <div class="section-header">Completion Information</div>
          <div class="section-content">
            ${data['completedBy'] != null ? '''
            <div class="detail-row">
              <div class="detail-label">Completed By:</div>
              <div class="detail-value">${data['completedBy']}</div>
            </div>
            ''' : ''}
            ${completedAt != null ? '''
            <div class="detail-row">
              <div class="detail-label">Completion Date & Time:</div>
              <div class="detail-value">${DateFormat('MMMM dd, yyyy • hh:mm a').format(completedAt.toDate())}</div>
            </div>
            ''' : ''}
          </div>
        </div>
        
        <div class="footer">
          <div class="footer-content">
            <div class="footer-contact">
              For inquiries, contact: $facilityEmail
            </div>
            <div class="footer-verification">
              This is an official laboratory result document.
              For verification purposes, please contact our facility directly.
            </div>
            <div class="print-date">
              Document printed on: ${DateFormat('MMMM dd, yyyy • hh:mm a').format(DateTime.now())}
            </div>
          </div>
        </div>
        <script>
          // Auto-print when page loads
          setTimeout(function() {
            window.print();
          }, 500);
        </script>
      </body>
      </html>
    ''';

    try {
      // Print HTML content using platform-aware utility
      await printHtmlContent(printContent);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Opening print preview... Please allow popups if blocked.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildInfoBox(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          const Divider(),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class EnterLabResultScreen extends StatefulWidget {
  final String testId;
  final Map<String, dynamic> testData;
  final String laboratoryStaffId;
  final String laboratoryStaffName;

  const EnterLabResultScreen({
    super.key,
    required this.testId,
    required this.testData,
    required this.laboratoryStaffId,
    required this.laboratoryStaffName,
  });

  @override
  State<EnterLabResultScreen> createState() => _EnterLabResultScreenState();
}

class _EnterLabResultScreenState extends State<EnterLabResultScreen> {
  final _formKey = GlobalKey<FormState>();
  final _resultsController = TextEditingController();
  final _commentsController = TextEditingController();
  bool _isLoading = false;
  final Map<String, ValidationResult?> _validationResults = {};

  // Result templates for common tests
  final Map<String, Map<String, dynamic>> _testTemplates = {
    'Full Blood Count (FBC)': {
      'parameters': [
        {
          'name': 'Hemoglobin',
          'unit': 'g/dL',
          'reference': '13.0-17.0 (M), 12.0-15.0 (F)',
        },
        {'name': 'WBC Count', 'unit': '×10⁹/L', 'reference': '4.0-11.0'},
        {'name': 'Platelets', 'unit': '×10⁹/L', 'reference': '150-450'},
        {'name': 'PCV/HCT', 'unit': '%', 'reference': '40-50 (M), 36-44 (F)'},
        {'name': 'MCV', 'unit': 'fL', 'reference': '80-100'},
        {'name': 'MCH', 'unit': 'pg', 'reference': '27-32'},
        {'name': 'MCHC', 'unit': 'g/dL', 'reference': '32-36'},
        {'name': 'Neutrophils', 'unit': '%', 'reference': '40-75'},
        {'name': 'Lymphocytes', 'unit': '%', 'reference': '20-45'},
        {'name': 'Monocytes', 'unit': '%', 'reference': '2-10'},
        {'name': 'Eosinophils', 'unit': '%', 'reference': '1-6'},
      ],
    },
    'Malaria Parasite (MP/RDT)': {
      'parameters': [
        {'name': 'Result', 'unit': '', 'reference': 'Negative'},
        {'name': 'Parasites Seen', 'unit': '', 'reference': 'None'},
        {'name': 'Parasite Density', 'unit': '/µL', 'reference': '0'},
      ],
    },
    'Blood Sugar (Random)': {
      'parameters': [
        {'name': 'Blood Glucose', 'unit': 'mmol/L', 'reference': '< 11.1'},
      ],
    },
    'Blood Sugar (Fasting)': {
      'parameters': [
        {
          'name': 'Fasting Blood Glucose',
          'unit': 'mmol/L',
          'reference': '3.9-6.1',
        },
      ],
    },
    'Urinalysis': {
      'parameters': [
        {'name': 'Color', 'unit': '', 'reference': 'Straw/Yellow'},
        {'name': 'Appearance', 'unit': '', 'reference': 'Clear'},
        {'name': 'pH', 'unit': '', 'reference': '5.0-7.0'},
        {'name': 'Specific Gravity', 'unit': '', 'reference': '1.010-1.025'},
        {'name': 'Protein', 'unit': '', 'reference': 'Negative'},
        {'name': 'Glucose', 'unit': '', 'reference': 'Negative'},
        {'name': 'Ketones', 'unit': '', 'reference': 'Negative'},
        {'name': 'Blood', 'unit': '', 'reference': 'Negative'},
        {'name': 'Bilirubin', 'unit': '', 'reference': 'Negative'},
        {'name': 'Urobilinogen', 'unit': '', 'reference': 'Normal'},
        {'name': 'Nitrite', 'unit': '', 'reference': 'Negative'},
        {'name': 'Leukocytes', 'unit': '', 'reference': 'Negative'},
        {'name': 'WBC', 'unit': '/hpf', 'reference': '0-5'},
        {'name': 'RBC', 'unit': '/hpf', 'reference': '0-3'},
        {'name': 'Epithelial Cells', 'unit': '/hpf', 'reference': 'Few'},
        {'name': 'Casts', 'unit': '', 'reference': 'None'},
        {'name': 'Crystals', 'unit': '', 'reference': 'None'},
      ],
    },
    'Lipid Profile': {
      'parameters': [
        {'name': 'Total Cholesterol', 'unit': 'mmol/L', 'reference': '< 5.2'},
        {'name': 'HDL Cholesterol', 'unit': 'mmol/L', 'reference': '> 1.0'},
        {'name': 'LDL Cholesterol', 'unit': 'mmol/L', 'reference': '< 3.4'},
        {'name': 'Triglycerides', 'unit': 'mmol/L', 'reference': '< 1.7'},
      ],
    },
    'Liver Function Test (LFT)': {
      'parameters': [
        {'name': 'Total Bilirubin', 'unit': 'µmol/L', 'reference': '3-20'},
        {'name': 'Direct Bilirubin', 'unit': 'µmol/L', 'reference': '0-5'},
        {'name': 'ALT', 'unit': 'U/L', 'reference': '7-56'},
        {'name': 'AST', 'unit': 'U/L', 'reference': '10-40'},
        {'name': 'ALP', 'unit': 'U/L', 'reference': '40-150'},
        {'name': 'Total Protein', 'unit': 'g/L', 'reference': '60-80'},
        {'name': 'Albumin', 'unit': 'g/L', 'reference': '35-50'},
      ],
    },
    'Kidney Function Test (RFT)': {
      'parameters': [
        {'name': 'Urea', 'unit': 'mmol/L', 'reference': '2.5-7.8'},
        {'name': 'Creatinine', 'unit': 'µmol/L', 'reference': '60-120'},
        {'name': 'eGFR', 'unit': 'mL/min/1.73m²', 'reference': '> 90'},
      ],
    },
    'Electrolytes/Urea/Creatinine (E/U/Cr)': {
      'parameters': [
        {'name': 'Sodium (Na+)', 'unit': 'mmol/L', 'reference': '135-145'},
        {'name': 'Potassium (K+)', 'unit': 'mmol/L', 'reference': '3.5-5.0'},
        {'name': 'Chloride (Cl-)', 'unit': 'mmol/L', 'reference': '95-105'},
        {'name': 'Bicarbonate (HCO3-)', 'unit': 'mmol/L', 'reference': '22-28'},
        {'name': 'Urea', 'unit': 'mmol/L', 'reference': '2.5-7.8'},
        {'name': 'Creatinine', 'unit': 'µmol/L', 'reference': '60-120'},
      ],
    },
  };

  final Map<String, TextEditingController> _parameterControllers = {};

  @override
  void initState() {
    super.initState();
    final testName = widget.testData['testName'] as String;
    if (_testTemplates.containsKey(testName)) {
      final parameters = _testTemplates[testName]!['parameters'] as List;
      for (var param in parameters) {
        final controller = TextEditingController();
        _parameterControllers[param['name']] = controller;

        // Add real-time AI validation listener
        controller.addListener(
          () => _validateParameter(param['name'], param['unit']),
        );
      }
    }
  }

  Future<void> _validateParameter(String paramName, String unit) async {
    final value = _parameterControllers[paramName]!.text.trim();
    if (value.isEmpty) {
      setState(() => _validationResults[paramName] = null);
      return;
    }

    final result = await AIValidationService.validateLabResult(
      testName: paramName,
      result: value,
      unit: unit,
    );

    setState(() => _validationResults[paramName] = result);
  }

  @override
  void dispose() {
    _resultsController.dispose();
    _commentsController.dispose();
    _parameterControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _saveResults() async {
    if (!_formKey.currentState!.validate()) return;

    final testName = widget.testData['testName'] as String;

    // AI Validation: Check critical lab values and impossible readings
    List<ValidationResult> validationResults = [];

    if (_testTemplates.containsKey(testName)) {
      final parameters = _testTemplates[testName]!['parameters'] as List;
      for (var param in parameters) {
        final value = _parameterControllers[param['name']]!.text.trim();
        if (value.isNotEmpty) {
          final result = await AIValidationService.validateLabResult(
            testName: param['name'],
            result: value,
            unit: param['unit'],
          );

          if (result.hasWarnings || result.hasSuggestions) {
            validationResults.add(result);
          }
        }
      }
    }

    // Show AI validation warnings if any critical issues detected (advisory only)
    if (validationResults.any(
      (r) => r.severity == ValidationSeverity.critical,
    )) {
      await AIValidationDialog.show(
        context: context,
        result: ValidationResult(
          isValid: true,
          severity: ValidationSeverity.critical,
          warnings: validationResults.expand((r) => r.warnings).toList(),
          suggestions: validationResults.expand((r) => r.suggestions).toList(),
          aiRecommendation:
              '⚠️ CRITICAL VALUES DETECTED - Please review all warnings. These values may indicate life-threatening conditions requiring immediate physician notification. You may proceed if clinically appropriate.',
        ),
        title: 'AI Lab Validation Advisory',
      );
    }

    setState(() => _isLoading = true);

    try {
      final cost = (widget.testData['cost'] as num).toDouble();
      final patientId = widget.testData['patientId'];

      // Get patient data
      final patientDoc = await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(patientId)
          .get();

      if (!patientDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final patientData = patientDoc.data()!;
      final registrationType = patientData['registrationType'] as String?;

      // Get wallet balance based on registration type
      double walletBalance;
      String? householdId;
      String?
      actualWalletUserId; // Track the actual wallet userId for individual patients
      bool useHouseholdWallet = false;

      if (registrationType == 'household') {
        // For household members, use household wallet
        useHouseholdWallet = true;
        householdId = patientData['householdId'] as String?;

        if (householdId == null || householdId.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Patient is not assigned to a household'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        final householdDoc = await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(householdId)
            .get();

        walletBalance =
            (householdDoc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      } else {
        // For individual patients, use wallets collection
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
              actualWalletUserId = alternateUserId;
            } else {
              walletBalance = 0.0;
            }
          } else {
            walletBalance = 0.0;
          }
        }
      }

      if (walletBalance < cost) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient ${useHouseholdWallet ? 'household' : 'patient'} wallet balance. Required: ₦${cost.toStringAsFixed(2)}, Available: ₦${walletBalance.toStringAsFixed(2)}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Prepare results data
      Map<String, dynamic> resultsData = {};
      if (_testTemplates.containsKey(testName)) {
        final parameters = _testTemplates[testName]!['parameters'] as List;
        for (var param in parameters) {
          resultsData[param['name']] = {
            'value': _parameterControllers[param['name']]!.text,
            'unit': param['unit'],
            'reference': param['reference'],
          };
        }
      } else {
        resultsData['results'] = _resultsController.text.trim();
      }

      // Update test status
      await FirebaseFirestore.instance
          .collection('pending_lab_tests')
          .doc(widget.testId)
          .update({
            'status': 'completed',
            'results': resultsData,
            'comments': _commentsController.text.trim(),
            'performedBy': widget.laboratoryStaffName,
            'performedById': widget.laboratoryStaffId,
            'completedAt': FieldValue.serverTimestamp(),
          });

      // Save to patient's lab results
      await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(patientId)
          .collection('lab_results')
          .add({
            'testId': widget.testId,
            'testName': testName,
            'results': resultsData,
            'comments': _commentsController.text.trim(),
            'cost': cost,
            'performedBy': widget.laboratoryStaffName,
            'clinicianName': widget.testData['clinicianName'],
            'completedAt': FieldValue.serverTimestamp(),
          });

      // Save to health_records for centralized access across departments
      await FirebaseFirestore.instance.collection('health_records').add({
        'patientId': patientId,
        'facilityId': widget.testData['facilityId'],
        'appointmentId': widget.testData['appointmentId'],
        'recordType': 'laboratory',
        'testId': widget.testId,
        'testName': testName,
        'results': resultsData,
        'comments': _commentsController.text.trim(),
        'cost': cost,
        'status': 'completed',
        'performedBy': widget.laboratoryStaffName,
        'performedById': widget.laboratoryStaffId,
        'clinicianName': widget.testData['clinicianName'],
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Deduct from wallet based on registration type
      if (useHouseholdWallet && householdId != null) {
        // Deduct from household wallet for household members
        await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(householdId)
            .update({'balance': FieldValue.increment(-cost)});

        // Record transaction in household
        await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(householdId)
            .collection('transactions')
            .add({
              'type': 'debit',
              'amount': cost,
              'description':
                  'Lab Test: $testName for ${patientData['fullName']}',
              'patientId': patientId,
              'patientName': patientData['fullName'],
              'timestamp': FieldValue.serverTimestamp(),
            });
      } else {
        // Deduct from individual patient wallet using wallets collection
        if (actualWalletUserId != null) {
          await FirebaseFirestore.instance
              .collection('wallets')
              .doc(actualWalletUserId)
              .update({'balance': FieldValue.increment(-cost)});

          // Record transaction
          await FirebaseFirestore.instance
              .collection('wallets')
              .doc(actualWalletUserId)
              .collection('transactions')
              .add({
                'type': 'debit',
                'amount': cost,
                'description': 'Laboratory - $testName',
                'performedBy': widget.laboratoryStaffName,
                'timestamp': FieldValue.serverTimestamp(),
              });
        }
      }

      // Credit the facility wallet
      final facilityId = widget.testData['facilityId'];
      if (facilityId != null) {
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(facilityId)
            .update({
              'balance': FieldValue.increment(cost),
              'updatedAt': FieldValue.serverTimestamp(),
            });

        // Record transaction in facility wallet
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(facilityId)
            .collection('transactions')
            .add({
              'type': 'credit',
              'amount': cost,
              'description':
                  'Laboratory revenue - $testName for ${patientData['fullName']}',
              'patientId': patientId,
              'patientName': patientData['fullName'],
              'performedBy': widget.laboratoryStaffName,
              'performedById': widget.laboratoryStaffId,
              'timestamp': FieldValue.serverTimestamp(),
              'status': 'completed',
            });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Results saved. ₦${cost.toStringAsFixed(2)} deducted from wallet.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving results: $e'),
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
    final testName = widget.testData['testName'] as String;
    final hasTemplate = _testTemplates.containsKey(testName);
    final timestamp = widget.testData['createdAt'] as Timestamp?;

    return Scaffold(
      appBar: AppBar(title: const Text('Enter Lab Results')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Test Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      testName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 16),
                    Text('Patient: ${widget.testData['patientName']}'),
                    Text('Requested by: ${widget.testData['clinicianName']}'),
                    if (timestamp != null)
                      Text(
                        'Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate())}',
                      ),
                    Text(
                      'Cost: ₦${(widget.testData['cost'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Results Entry
            if (hasTemplate) ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Enter Test Results',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...(_testTemplates[testName]!['parameters'] as List).map((param) {
                final paramName = param['name'];
                final validationResult = _validationResults[paramName];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paramName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _parameterControllers[paramName],
                          decoration: InputDecoration(
                            hintText: 'Enter value',
                            border: const OutlineInputBorder(),
                            suffixText: param['unit'],
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter value';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reference: ${param['reference']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        // AI Validation Inline Display
                        if (validationResult != null)
                          InlineValidationWidget(result: validationResult),
                      ],
                    ),
                  ),
                );
              }),
            ] else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _resultsController,
                    decoration: const InputDecoration(
                      labelText: 'Test Results',
                      hintText: 'Enter detailed results...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 10,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter test results';
                      }
                      return null;
                    },
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Comments
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _commentsController,
                  decoration: const InputDecoration(
                    labelText: 'Comments/Interpretation',
                    hintText: 'Additional comments...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveResults,
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
                      'Save Results & Deduct from Wallet',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
