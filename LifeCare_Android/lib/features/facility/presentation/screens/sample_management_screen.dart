// Sample Management Screen
// For laboratory staff to manage samples collection, tracking, and processing

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SampleManagementScreen extends StatefulWidget {
  final String facilityId;
  final String staffId;
  final String staffName;

  const SampleManagementScreen({
    super.key,
    required this.facilityId,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<SampleManagementScreen> createState() => _SampleManagementScreenState();
}

class _SampleManagementScreenState extends State<SampleManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sample Management'),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending Collection'),
            Tab(text: 'Collected'),
            Tab(text: 'Processing'),
            Tab(text: 'Completed'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddSampleDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by patient name or sample ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSamplesList('pending_collection'),
                _buildSamplesList('collected'),
                _buildSamplesList('processing'),
                _buildSamplesList('completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSamplesList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lab_samples')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.biotech, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No ${status.replaceAll('_', ' ')} samples',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Filter samples based on search
        final filteredDocs = snapshot.data!.docs.where((doc) {
          if (_searchQuery.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          final patientName =
              data['patientName']?.toString().toLowerCase() ?? '';
          final sampleId = doc.id.toLowerCase();
          return patientName.contains(_searchQuery) ||
              sampleId.contains(_searchQuery);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = data['createdAt'] as Timestamp?;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                onTap: () => _showSampleDetails(doc.id, data),
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(status).withOpacity(0.2),
                  child: Icon(
                    _getStatusIcon(status),
                    color: _getStatusColor(status),
                  ),
                ),
                title: Text(
                  data['patientName'] ?? 'Unknown Patient',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Sample ID: ${doc.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                    if (data['registrationNumber'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Reg. No: ${data['registrationNumber']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'Type: ${data['sampleType'] ?? 'Unknown'}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Test: ${data['testType'] ?? 'Unknown'}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    if (data['isWalkInPatient'] == true) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Walk-in',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Created: ${_formatDate(createdAt)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: _buildActionButtons(status, doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButtons(
    String status,
    String sampleId,
    Map<String, dynamic> data,
  ) {
    switch (status) {
      case 'pending_collection':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => _viewTestDetails(sampleId, data),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('View Test', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _markAsCollected(sampleId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Collected', style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      case 'collected':
        return ElevatedButton(
          onPressed: () => _startProcessing(sampleId),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade600,
            foregroundColor: Colors.white,
            minimumSize: const Size(80, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('Start Processing', style: TextStyle(fontSize: 12)),
        );
      case 'processing':
        return ElevatedButton(
          onPressed: () => _showResultForm(sampleId, data),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade600,
            foregroundColor: Colors.white,
            minimumSize: const Size(80, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('Enter Result', style: TextStyle(fontSize: 12)),
        );
      case 'completed':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => _viewResults(sampleId, data),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('View Results', style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_collection':
        return Colors.orange;
      case 'collected':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending_collection':
        return Icons.pending_actions;
      case 'collected':
        return Icons.inventory;
      case 'processing':
        return Icons.science;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.biotech;
    }
  }

  void _viewTestDetails(String sampleId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.science, color: Colors.blue),
            SizedBox(width: 8),
            Text('Lab Test Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Patient', data['patientName'] ?? 'Unknown'),
              _buildDetailRow('Sample ID', sampleId),
              if (data['registrationNumber'] != null)
                _buildDetailRow('Reg. Number', data['registrationNumber']),
              _buildDetailRow('Sample Type', data['sampleType'] ?? 'Unknown'),
              _buildDetailRow('Test Type', data['testType'] ?? 'Unknown'),
              if (data['notes'] != null)
                _buildDetailRow('Special Instructions', data['notes']),
              if (data['doctorRequested'] != null)
                _buildDetailRow('Requested by Doctor', data['doctorRequested']),
              if (data['createdAt'] != null)
                _buildDetailRow(
                  'Request Date',
                  _formatDate(data['createdAt'] as Timestamp),
                ),

              // Additional test information
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sample required: ${data['sampleType'] ?? 'Not specified'}',
                    ),
                    Text(
                      'Test procedure: ${data['testType'] ?? 'Not specified'}',
                    ),
                    if (data['urgency'] != null)
                      Text('Urgency: ${data['urgency']}'),
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markAsCollected(sampleId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Mark as Collected'),
          ),
        ],
      ),
    );
  }

  void _markAsCollected(String sampleId) async {
    try {
      await FirebaseFirestore.instance
          .collection('lab_samples')
          .doc(sampleId)
          .update({
            'status': 'collected',
            'collectedAt': FieldValue.serverTimestamp(),
            'collectedBy': widget.staffName,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sample marked as collected'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating sample: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startProcessing(String sampleId) async {
    try {
      await FirebaseFirestore.instance
          .collection('lab_samples')
          .doc(sampleId)
          .update({
            'status': 'processing',
            'processingStartedAt': FieldValue.serverTimestamp(),
            'processedBy': widget.staffName,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sample processing started'),
          backgroundColor: Colors.purple,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating sample: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Laboratory test templates with normal ranges
  final Map<String, dynamic> _labTestTemplates = {
    // === HEMATOLOGY ===
    'Full Blood Count (FBC)': {
      'parameters': [
        {
          'name': 'Hemoglobin',
          'unit': 'g/dL',
          'normalMale': '13.0-17.0',
          'normalFemale': '12.0-15.0',
        },
        {'name': 'WBC Count', 'unit': '×10⁹/L', 'normal': '4.0-11.0'},
        {'name': 'Platelets', 'unit': '×10⁹/L', 'normal': '150-450'},
        {
          'name': 'PCV/HCT',
          'unit': '%',
          'normalMale': '40-50',
          'normalFemale': '36-44',
        },
        {'name': 'MCV', 'unit': 'fL', 'normal': '80-100'},
        {'name': 'MCH', 'unit': 'pg', 'normal': '27-32'},
        {'name': 'MCHC', 'unit': 'g/dL', 'normal': '32-36'},
        {'name': 'Neutrophils', 'unit': '%', 'normal': '40-75'},
        {'name': 'Lymphocytes', 'unit': '%', 'normal': '20-45'},
        {'name': 'Monocytes', 'unit': '%', 'normal': '2-10'},
        {'name': 'Eosinophils', 'unit': '%', 'normal': '1-6'},
        {'name': 'Basophils', 'unit': '%', 'normal': '0-1'},
      ],
    },
    'Basic Blood Test': {
      'parameters': [
        {
          'name': 'Hemoglobin',
          'unit': 'g/dL',
          'normalMale': '13.0-17.0',
          'normalFemale': '12.0-15.0',
        },
        {'name': 'WBC Count', 'unit': '×10⁹/L', 'normal': '4.0-11.0'},
        {
          'name': 'PCV',
          'unit': '%',
          'normalMale': '40-50',
          'normalFemale': '36-44',
        },
        {
          'name': 'ESR',
          'unit': 'mm/hr',
          'normalMale': '0-15',
          'normalFemale': '0-20',
        },
      ],
    },

    // === BIOCHEMISTRY ===
    'Blood Sugar (Glucose)': {
      'parameters': [
        {'name': 'Fasting Blood Sugar', 'unit': 'mg/dL', 'normal': '70-100'},
        {'name': 'Random Blood Sugar', 'unit': 'mg/dL', 'normal': '<140'},
        {'name': '2hr Post-Prandial', 'unit': 'mg/dL', 'normal': '<140'},
      ],
    },
    'Blood Sugar': {
      'parameters': [
        {'name': 'Fasting Blood Sugar', 'unit': 'mg/dL', 'normal': '70-100'},
        {'name': 'Random Blood Sugar', 'unit': 'mg/dL', 'normal': '<140'},
      ],
    },
    'Cholesterol Test': {
      'parameters': [
        {'name': 'Total Cholesterol', 'unit': 'mg/dL', 'normal': '<200'},
        {'name': 'HDL Cholesterol', 'unit': 'mg/dL', 'normal': '>40'},
        {'name': 'LDL Cholesterol', 'unit': 'mg/dL', 'normal': '<100'},
        {'name': 'Triglycerides', 'unit': 'mg/dL', 'normal': '<150'},
        {'name': 'VLDL', 'unit': 'mg/dL', 'normal': '5-40'},
      ],
    },
    'Lipid Profile': {
      'parameters': [
        {'name': 'Total Cholesterol', 'unit': 'mg/dL', 'normal': '<200'},
        {'name': 'HDL Cholesterol', 'unit': 'mg/dL', 'normal': '>40'},
        {'name': 'LDL Cholesterol', 'unit': 'mg/dL', 'normal': '<100'},
        {'name': 'Triglycerides', 'unit': 'mg/dL', 'normal': '<150'},
        {'name': 'VLDL', 'unit': 'mg/dL', 'normal': '5-40'},
      ],
    },
    'Liver Function Test': {
      'parameters': [
        {'name': 'Total Bilirubin', 'unit': 'mg/dL', 'normal': '0.3-1.2'},
        {'name': 'Direct Bilirubin', 'unit': 'mg/dL', 'normal': '0.0-0.3'},
        {'name': 'Indirect Bilirubin', 'unit': 'mg/dL', 'normal': '0.2-0.9'},
        {'name': 'SGOT/AST', 'unit': 'U/L', 'normal': '5-40'},
        {'name': 'SGPT/ALT', 'unit': 'U/L', 'normal': '7-56'},
        {'name': 'ALP', 'unit': 'U/L', 'normal': '44-147'},
        {'name': 'Total Protein', 'unit': 'g/dL', 'normal': '6.0-8.3'},
        {'name': 'Albumin', 'unit': 'g/dL', 'normal': '3.5-5.0'},
        {'name': 'Globulin', 'unit': 'g/dL', 'normal': '2.0-3.5'},
      ],
    },
    'Kidney Function Test': {
      'parameters': [
        {'name': 'Urea', 'unit': 'mg/dL', 'normal': '15-40'},
        {'name': 'Creatinine', 'unit': 'mg/dL', 'normal': '0.6-1.2'},
        {
          'name': 'Uric Acid',
          'unit': 'mg/dL',
          'normalMale': '3.4-7.0',
          'normalFemale': '2.4-6.0',
        },
        {'name': 'Sodium', 'unit': 'mEq/L', 'normal': '135-145'},
        {'name': 'Potassium', 'unit': 'mEq/L', 'normal': '3.5-5.0'},
        {'name': 'Chloride', 'unit': 'mEq/L', 'normal': '96-106'},
        {'name': 'Bicarbonate', 'unit': 'mEq/L', 'normal': '22-29'},
      ],
    },
    'Thyroid Function Test': {
      'parameters': [
        {'name': 'TSH', 'unit': 'μIU/mL', 'normal': '0.4-4.0'},
        {'name': 'T3', 'unit': 'ng/dL', 'normal': '80-200'},
        {'name': 'T4', 'unit': 'μg/dL', 'normal': '5.0-12.0'},
        {'name': 'Free T3', 'unit': 'pg/mL', 'normal': '2.0-4.4'},
        {'name': 'Free T4', 'unit': 'ng/dL', 'normal': '0.8-1.8'},
      ],
    },

    // === MICROBIOLOGY & SEROLOGY ===
    'Malaria Test': {
      'parameters': [
        {'name': 'Malaria Parasite (MP)', 'normal': 'Not Seen'},
        {'name': 'Parasite Species', 'normal': 'N/A'},
        {'name': 'Parasite Density', 'unit': '/μL', 'normal': '0'},
        {'name': 'Trophozoites', 'normal': 'Not Seen'},
        {'name': 'Schizonts', 'normal': 'Not Seen'},
        {'name': 'Gametocytes', 'normal': 'Not Seen'},
      ],
    },
    'Typhoid Test': {
      'parameters': [
        {'name': 'Widal Test - TO (O antigen)', 'normal': '<1:80'},
        {'name': 'Widal Test - TH (H antigen)', 'normal': '<1:80'},
        {'name': 'Widal Test - AO (Paratyphi A)', 'normal': '<1:80'},
        {'name': 'Widal Test - BH (Paratyphi B)', 'normal': '<1:80'},
        {'name': 'Interpretation', 'normal': 'Negative'},
      ],
    },
    'Widal Test (Typhoid)': {
      'parameters': [
        {'name': 'TO (O antigen)', 'normal': '<1:80'},
        {'name': 'TH (H antigen)', 'normal': '<1:80'},
        {'name': 'AO (Paratyphi A)', 'normal': '<1:80'},
        {'name': 'BH (Paratyphi B)', 'normal': '<1:80'},
        {'name': 'Overall Result', 'normal': 'Negative'},
      ],
    },
    'HIV Test': {
      'parameters': [
        {'name': 'HIV 1/2 Antibodies', 'normal': 'Non-Reactive'},
        {'name': 'Screening Test', 'normal': 'Non-Reactive'},
        {'name': 'Confirmatory Test', 'normal': 'Non-Reactive'},
      ],
    },
    'HIV Screening': {
      'parameters': [
        {'name': 'HIV 1/2 Antibodies', 'normal': 'Non-Reactive'},
        {'name': 'Test Method', 'normal': 'Rapid Test/ELISA'},
      ],
    },
    'Hepatitis B/C Test': {
      'parameters': [
        {
          'name': 'HBsAg (Hepatitis B Surface Antigen)',
          'normal': 'Non-Reactive',
        },
        {'name': 'Anti-HBs (Hepatitis B Antibody)', 'normal': 'Non-Reactive'},
        {'name': 'Anti-HCV (Hepatitis C Antibody)', 'normal': 'Non-Reactive'},
      ],
    },
    'Hepatitis Test': {
      'parameters': [
        {'name': 'HBsAg', 'normal': 'Non-Reactive'},
        {'name': 'Anti-HCV', 'normal': 'Non-Reactive'},
      ],
    },

    // === URINALYSIS & STOOL ANALYSIS ===
    'Urinalysis': {
      'parameters': [
        {'name': 'Color', 'normal': 'Yellow/Amber'},
        {'name': 'Appearance', 'normal': 'Clear'},
        {'name': 'pH', 'normal': '4.5-8.0'},
        {'name': 'Specific Gravity', 'normal': '1.005-1.030'},
        {'name': 'Protein', 'normal': 'Negative'},
        {'name': 'Glucose', 'normal': 'Negative'},
        {'name': 'Ketones', 'normal': 'Negative'},
        {'name': 'Blood', 'normal': 'Negative'},
        {'name': 'Bilirubin', 'normal': 'Negative'},
        {'name': 'Urobilinogen', 'normal': 'Normal'},
        {'name': 'Nitrite', 'normal': 'Negative'},
        {'name': 'Leukocytes', 'normal': 'Negative'},
        {'name': 'Pus Cells', 'unit': '/HPF', 'normal': '0-5'},
        {'name': 'RBCs', 'unit': '/HPF', 'normal': '0-3'},
        {'name': 'Epithelial Cells', 'normal': 'Few'},
        {'name': 'Casts', 'normal': 'None'},
        {'name': 'Crystals', 'normal': 'None'},
        {'name': 'Bacteria', 'normal': 'None'},
      ],
    },
    'Urine Test': {
      'parameters': [
        {'name': 'Color', 'normal': 'Yellow/Amber'},
        {'name': 'Appearance', 'normal': 'Clear'},
        {'name': 'pH', 'normal': '4.5-8.0'},
        {'name': 'Specific Gravity', 'normal': '1.005-1.030'},
        {'name': 'Protein', 'normal': 'Negative'},
        {'name': 'Glucose', 'normal': 'Negative'},
        {'name': 'Blood', 'normal': 'Negative'},
        {'name': 'Pus Cells', 'unit': '/HPF', 'normal': '0-5'},
        {'name': 'RBCs', 'unit': '/HPF', 'normal': '0-3'},
      ],
    },
    'Stool Analysis': {
      'parameters': [
        {'name': 'Consistency', 'normal': 'Formed'},
        {'name': 'Color', 'normal': 'Brown'},
        {'name': 'Occult Blood', 'normal': 'Negative'},
        {'name': 'Ova/Parasites', 'normal': 'Not Seen'},
        {'name': 'Pus Cells', 'normal': 'Nil'},
        {'name': 'RBCs', 'normal': 'Nil'},
        {'name': 'Mucus', 'normal': 'Absent'},
        {'name': 'Fat Globules', 'normal': 'Absent'},
        {'name': 'Cysts', 'normal': 'Not Seen'},
        {'name': 'Trophozoites', 'normal': 'Not Seen'},
      ],
    },
    'Stool Test': {
      'parameters': [
        {'name': 'Consistency', 'normal': 'Formed'},
        {'name': 'Color', 'normal': 'Brown'},
        {'name': 'Occult Blood', 'normal': 'Negative'},
        {'name': 'Ova/Parasites', 'normal': 'Not Seen'},
        {'name': 'Pus Cells', 'normal': 'Nil'},
      ],
    },

    // === PREGNANCY & HORMONES ===
    'Pregnancy Test': {
      'parameters': [
        {'name': 'hCG (Urine)', 'normal': 'Negative'},
        {'name': 'Result', 'normal': 'Negative/Positive'},
      ],
    },
    'Blood Group': {
      'parameters': [
        {'name': 'ABO Group', 'normal': 'A/B/AB/O'},
        {'name': 'Rh Factor', 'normal': 'Positive/Negative'},
        {'name': 'Full Blood Group', 'normal': 'e.g., A+, B-, O+'},
      ],
    },

    // === CARDIAC & IMAGING ===
    'ECG/EKG': {
      'parameters': [
        {'name': 'Heart Rate', 'unit': 'bpm', 'normal': '60-100'},
        {'name': 'Rhythm', 'normal': 'Sinus Rhythm'},
        {'name': 'PR Interval', 'unit': 'ms', 'normal': '120-200'},
        {'name': 'QRS Duration', 'unit': 'ms', 'normal': '80-120'},
        {'name': 'QT Interval', 'unit': 'ms', 'normal': '350-450'},
        {'name': 'Axis', 'normal': 'Normal'},
        {'name': 'ST Segment', 'normal': 'No Deviation'},
        {'name': 'T Wave', 'normal': 'Normal'},
        {'name': 'Interpretation', 'normal': 'Normal ECG'},
      ],
    },
    'X-Ray (Chest)': {
      'parameters': [
        {'name': 'Heart Size', 'normal': 'Normal'},
        {'name': 'Lung Fields', 'normal': 'Clear'},
        {'name': 'Costophrenic Angles', 'normal': 'Sharp'},
        {'name': 'Diaphragm', 'normal': 'Normal'},
        {'name': 'Mediastinum', 'normal': 'Not Widened'},
        {'name': 'Bones', 'normal': 'Intact'},
        {'name': 'Impression', 'normal': 'Normal Chest X-Ray'},
      ],
    },
    'X-Ray (Other)': {
      'parameters': [
        {'name': 'Area Examined', 'normal': 'Specify'},
        {'name': 'Bone Alignment', 'normal': 'Normal'},
        {'name': 'Fracture', 'normal': 'None'},
        {'name': 'Soft Tissue', 'normal': 'Normal'},
        {'name': 'Joint Spaces', 'normal': 'Preserved'},
        {'name': 'Impression', 'normal': 'Describe findings'},
      ],
    },
    'Ultrasound Scan': {
      'parameters': [
        {'name': 'Area Scanned', 'normal': 'Specify'},
        {'name': 'Organ(s) Visualized', 'normal': 'List organs'},
        {'name': 'Size/Dimensions', 'normal': 'Within normal limits'},
        {'name': 'Echogenicity', 'normal': 'Normal'},
        {'name': 'Masses/Lesions', 'normal': 'None'},
        {'name': 'Free Fluid', 'normal': 'None'},
        {'name': 'Impression', 'normal': 'Normal ultrasound'},
      ],
    },
  };

  void _showResultForm(String sampleId, Map<String, dynamic> data) {
    final testType = data['testType'] ?? '';
    final template = _labTestTemplates[testType];
    final hasTemplate = template != null;

    // For templated tests, use structured form
    if (hasTemplate) {
      _showStructuredResultForm(sampleId, data, template);
    } else {
      _showSimpleResultForm(sampleId, data);
    }
  }

  void _showStructuredResultForm(
    String sampleId,
    Map<String, dynamic> data,
    Map<String, dynamic> template,
  ) {
    final List<Map<String, dynamic>> parameters =
        List<Map<String, dynamic>>.from(template['parameters']);
    final Map<int, TextEditingController> resultControllers = {};
    final notesController = TextEditingController();

    // Initialize controllers for each parameter
    for (int i = 0; i < parameters.length; i++) {
      resultControllers[i] = TextEditingController();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.assignment, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Expanded(child: Text('Enter Test Results')),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sample Info Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Patient: ${data['patientName'] ?? 'Unknown'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.science,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text('Test: ${data['testType'] ?? 'Unknown'}'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.qr_code,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Sample ID: $sampleId',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Parameter entry fields
                  ...parameters.asMap().entries.map((entry) {
                    final index = entry.key;
                    final param = entry.value;
                    final normalRange =
                        param['normal'] ??
                        (param['normalMale'] != null
                            ? '${param['normalMale']} (M), ${param['normalFemale']} (F)'
                            : '');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                            param['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: resultControllers[index],
                            decoration: InputDecoration(
                              labelText:
                                  'Result${param['unit'] != null ? ' (${param['unit']})' : ''}',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              hintText: 'Enter value',
                              suffixIcon:
                                  resultControllers[index]!.text.isNotEmpty
                                  ? Icon(
                                      _isValueNormal(
                                            resultControllers[index]!.text,
                                            normalRange,
                                          )
                                          ? Icons.check_circle
                                          : Icons.warning,
                                      color:
                                          _isValueNormal(
                                            resultControllers[index]!.text,
                                            normalRange,
                                          )
                                          ? Colors.green
                                          : Colors.orange,
                                    )
                                  : null,
                            ),
                            onChanged: (value) => setState(() {}),
                          ),
                          if (normalRange.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Normal Range: $normalRange',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 8),

                  // Additional Notes
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Additional Notes/Comments',
                      border: OutlineInputBorder(),
                      hintText: 'Any additional observations or comments',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Compile results
                final List<Map<String, String>> results = [];
                bool hasResults = false;

                for (int i = 0; i < parameters.length; i++) {
                  final value = resultControllers[i]!.text.trim();
                  if (value.isNotEmpty) {
                    hasResults = true;
                    final param = parameters[i];
                    final normalRange =
                        param['normal'] ??
                        (param['normalMale'] != null
                            ? '${param['normalMale']} (M), ${param['normalFemale']} (F)'
                            : '');

                    results.add({
                      'parameter': param['name'],
                      'value': value,
                      'unit': param['unit'] ?? '',
                      'normalRange': normalRange,
                    });
                  }
                }

                if (!hasResults) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter at least one test result'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Generate formatted result and interpretation
                final formattedResult = _formatStructuredResults(results);
                final interpretation = _generateInterpretation(
                  results,
                  data['testType'],
                );

                await _saveTestResult(
                  sampleId,
                  data,
                  formattedResult,
                  '', // Normal range already included in formatted result
                  interpretation,
                  notesController.text.trim(),
                );

                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Save Results'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSimpleResultForm(String sampleId, Map<String, dynamic> data) {
    final resultController = TextEditingController();
    final normalRangeController = TextEditingController();
    final interpretationController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment, color: Colors.orange),
            SizedBox(width: 8),
            Text('Enter Test Results'),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sample Info Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Patient: ${data['patientName'] ?? 'Unknown'}'),
                      Text('Test: ${data['testType'] ?? 'Unknown'}'),
                      Text('Sample ID: $sampleId'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Result Fields
                TextField(
                  controller: resultController,
                  decoration: const InputDecoration(
                    labelText: 'Test Result *',
                    border: OutlineInputBorder(),
                    hintText: 'Enter the test result value',
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: normalRangeController,
                  decoration: const InputDecoration(
                    labelText: 'Normal Range',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 10-20 mg/dL',
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: interpretationController,
                  decoration: const InputDecoration(
                    labelText: 'Interpretation',
                    border: OutlineInputBorder(),
                    hintText: 'Normal, Abnormal, etc.',
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Notes',
                    border: OutlineInputBorder(),
                    hintText: 'Any additional observations',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (resultController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter test result'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              await _saveTestResult(
                sampleId,
                data,
                resultController.text.trim(),
                normalRangeController.text.trim(),
                interpretationController.text.trim(),
                notesController.text.trim(),
              );

              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Save Result'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTestResult(
    String sampleId,
    Map<String, dynamic> sampleData,
    String result,
    String normalRange,
    String interpretation,
    String notes,
  ) async {
    try {
      final resultData = {
        'sampleId': sampleId,
        'facilityId': widget.facilityId,
        'patientId': sampleData['patientId'],
        'patientName': sampleData['patientName'],
        'testType': sampleData['testType'],
        'sampleType': sampleData['sampleType'],
        'result': result,
        'normalRange': normalRange.isEmpty ? null : normalRange,
        'interpretation': interpretation.isEmpty ? null : interpretation,
        'notes': notes.isEmpty ? null : notes,
        'completedAt': FieldValue.serverTimestamp(),
        'completedBy': widget.staffName,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to lab_results collection
      await FirebaseFirestore.instance
          .collection('lab_results')
          .add(resultData);

      // Update sample status to completed
      await FirebaseFirestore.instance
          .collection('lab_samples')
          .doc(sampleId)
          .update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
            'completedBy': widget.staffName,
            'result': result,
            'interpretation': interpretation,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Update the pending_lab_tests to mark as completed
      if (sampleData['testRequestId'] != null) {
        await FirebaseFirestore.instance
            .collection('pending_lab_tests')
            .doc(sampleData['testRequestId'])
            .update({
              'status': 'completed',
              'completedAt': FieldValue.serverTimestamp(),
              'completedBy': widget.staffName,
              'result': result,
              'interpretation': interpretation,
            });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test result saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving result: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewResults(String sampleId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in, color: Colors.teal),
            SizedBox(width: 8),
            Text('Test Results'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Patient', data['patientName'] ?? 'Unknown'),
              _buildDetailRow('Test', data['testType'] ?? 'Unknown'),
              _buildDetailRow('Sample ID', sampleId),
              if (data['result'] != null)
                _buildDetailRow('Result', data['result']),
              if (data['interpretation'] != null)
                _buildDetailRow('Interpretation', data['interpretation']),
              if (data['completedBy'] != null)
                _buildDetailRow('Completed By', data['completedBy']),
              if (data['completedAt'] != null)
                _buildDetailRow(
                  'Completed',
                  _formatDate(data['completedAt'] as Timestamp),
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

  void _showSampleDetails(String sampleId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sample Details - $sampleId'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Patient', data['patientName'] ?? 'Unknown'),
              if (data['registrationNumber'] != null)
                _buildDetailRow('Reg. Number', data['registrationNumber']),
              if (data['isWalkInPatient'] == true)
                _buildDetailRow('Patient Type', 'Walk-in Patient')
              else
                _buildDetailRow('Patient Type', 'Registered Patient'),
              _buildDetailRow('Sample Type', data['sampleType'] ?? 'Unknown'),
              _buildDetailRow('Test Type', data['testType'] ?? 'Unknown'),
              _buildDetailRow('Status', data['status'] ?? 'Unknown'),
              if (data['notes'] != null)
                _buildDetailRow('Notes', data['notes']),
              if (data['collectedBy'] != null)
                _buildDetailRow('Collected By', data['collectedBy']),
              if (data['processedBy'] != null)
                _buildDetailRow('Processed By', data['processedBy']),
              if (data['createdAt'] != null)
                _buildDetailRow(
                  'Created',
                  _formatDate(data['createdAt'] as Timestamp),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showAddSampleDialog() {
    final customSampleTypeController = TextEditingController();
    final notesController = TextEditingController();

    String? selectedTestRequestId;
    Map<String, dynamic>? selectedTestData;
    String? selectedSampleType;

    // Sample types based on best practices
    final List<String> sampleTypes = [
      'Blood (Whole)',
      'Blood (Serum)',
      'Blood (Plasma)',
      'Urine',
      'Stool',
      'Sputum',
      'CSF (Cerebrospinal Fluid)',
      'Swab (Throat)',
      'Swab (Nasal)',
      'Swab (Wound)',
      'Swab (Vaginal)',
      'Tissue Biopsy',
      'Bone Marrow',
      'Synovial Fluid',
      'Pleural Fluid',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Sample for Lab Test'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Information box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Select a pending lab test request. Patient details and test type will be auto-filled.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Pending Lab Tests Dropdown
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('pending_lab_tests')
                      .where('facilityId', isEqualTo: widget.facilityId)
                      .where('status', isEqualTo: 'pending')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Error loading test requests: ${snapshot.error}',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      );
                    }

                    // Filter out tests that already have samples collected
                    final allTests = snapshot.data?.docs ?? [];
                    final pendingTests = allTests.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final sampleInitiated =
                          data['sampleCollectionInitiated'] ?? false;
                      return !sampleInitiated;
                    }).toList();

                    if (pendingTests.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.science_outlined,
                              size: 48,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No pending lab test requests',
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lab tests must be requested by doctors first',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return DropdownButtonFormField<String>(
                      value: selectedTestRequestId,
                      decoration: const InputDecoration(
                        labelText: 'Select Lab Test Request *',
                        border: OutlineInputBorder(),
                        helperText: 'Required - Choose from pending requests',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Select a test request...'),
                        ),
                        ...pendingTests.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final patientName =
                              data['patientName'] ?? 'Unknown Patient';
                          final testName = data['testName'] ?? 'Unknown Test';
                          final timestamp = data['createdAt'] as Timestamp?;
                          final dateStr = timestamp != null
                              ? ' (${timestamp.toDate().day}/${timestamp.toDate().month})'
                              : '';

                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text('$patientName - $testName$dateStr'),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedTestRequestId = value;
                          if (value != null) {
                            try {
                              final selectedDoc = pendingTests.firstWhere(
                                (doc) => doc.id == value,
                              );
                              selectedTestData =
                                  selectedDoc.data() as Map<String, dynamic>;
                            } catch (e) {
                              selectedTestData = null;
                            }
                          } else {
                            selectedTestData = null;
                          }
                        });
                      },
                    );
                  },
                ),

                if (selectedTestData != null) ...[
                  const SizedBox(height: 16),

                  // Display auto-filled information
                  Container(
                    padding: const EdgeInsets.all(16),
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
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Test Request Details',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        _buildInfoRow(
                          'Patient',
                          selectedTestData!['patientName'] ?? 'N/A',
                        ),
                        _buildInfoRow(
                          'Test Type',
                          selectedTestData!['testName'] ?? 'N/A',
                        ),
                        if (selectedTestData!['clinicianName'] != null)
                          _buildInfoRow(
                            'Requested by',
                            selectedTestData!['clinicianName'],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sample Type Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedSampleType,
                    decoration: const InputDecoration(
                      labelText: 'Sample Type *',
                      border: OutlineInputBorder(),
                      helperText: 'Required - Select type of sample to collect',
                    ),
                    items: sampleTypes
                        .map(
                          (type) => DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedSampleType = value;
                        if (value != 'Other') {
                          customSampleTypeController.clear();
                        }
                      });
                    },
                  ),

                  // Custom Sample Type Field (shown when 'Other' is selected)
                  if (selectedSampleType == 'Other') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: customSampleTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Specify Sample Type *',
                        border: OutlineInputBorder(),
                        hintText: 'Enter custom sample type',
                        helperText: 'Required when "Other" is selected',
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Notes
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(),
                      hintText: 'Additional notes about sample collection',
                    ),
                    maxLines: 3,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedTestData == null
                  ? null
                  : () {
                      // Validation
                      if (selectedTestRequestId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a lab test request'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedSampleType == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select sample type'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Determine final sample type
                      final finalSampleType = selectedSampleType == 'Other'
                          ? customSampleTypeController.text.trim()
                          : selectedSampleType!;

                      // Validate custom type when "Other" is selected
                      if (selectedSampleType == 'Other' &&
                          customSampleTypeController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please specify the custom sample type',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      _addSample(
                        selectedTestRequestId!,
                        selectedTestData!,
                        finalSampleType,
                        notesController.text.trim(),
                      );
                      Navigator.pop(context);
                    },
              child: const Text('Add Sample'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  Future<void> _addSample(
    String testRequestId,
    Map<String, dynamic> testData,
    String sampleType,
    String notes,
  ) async {
    try {
      // Create sample document
      await FirebaseFirestore.instance.collection('lab_samples').add({
        'facilityId': widget.facilityId,
        'testRequestId': testRequestId, // Link to the lab test request
        'patientId': testData['patientId'],
        'patientName': testData['patientName'],
        'testType': testData['testName'],
        'sampleType': sampleType.trim(),
        'notes': notes.isEmpty ? null : notes,
        'cost': testData['cost'], // Carry over the cost
        'clinicianName': testData['clinicianName'],
        'status': 'pending_collection',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.staffName,
      });

      // Update the lab test request to indicate sample collection initiated
      await FirebaseFirestore.instance
          .collection('pending_lab_tests')
          .doc(testRequestId)
          .update({
            'sampleCollectionInitiated': true,
            'sampleCollectionInitiatedAt': FieldValue.serverTimestamp(),
            'sampleCollectionInitiatedBy': widget.staffName,
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sample added successfully and linked to test request'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding sample: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  // Helper method to format structured results
  String _formatStructuredResults(List<Map<String, String>> results) {
    final buffer = StringBuffer();
    for (final result in results) {
      buffer.writeln(
        '${result['parameter']}: ${result['value']}${result['unit']!.isNotEmpty ? ' ${result['unit']}' : ''}',
      );
      if (result['normalRange']!.isNotEmpty) {
        buffer.writeln('  (Normal: ${result['normalRange']})');
      }
    }
    return buffer.toString().trim();
  }

  // AI-powered interpretation generator
  String _generateInterpretation(
    List<Map<String, String>> results,
    String testType,
  ) {
    final abnormalResults = <String>[];
    final normalResults = <String>[];

    for (final result in results) {
      final value = result['value']!;
      final normalRange = result['normalRange']!;
      final parameter = result['parameter']!;

      if (normalRange.isNotEmpty && !_isValueNormal(value, normalRange)) {
        // Analyze if high or low
        final status = _analyzeValueStatus(value, normalRange);
        abnormalResults.add('$parameter is $status');
      } else if (normalRange.isNotEmpty) {
        normalResults.add(parameter);
      }
    }

    if (abnormalResults.isEmpty) {
      return 'All parameters within normal range. No significant abnormalities detected.';
    }

    // Generate intelligent interpretation based on test type and abnormal values
    final buffer = StringBuffer();

    if (abnormalResults.length == 1) {
      buffer.write('Abnormal finding: ${abnormalResults[0]}. ');
    } else {
      buffer.write('Abnormal findings detected:\n');
      for (final finding in abnormalResults) {
        buffer.writeln('• $finding');
      }
    }

    // Add test-specific clinical interpretations
    buffer.write(
      '\n${_getTestSpecificInterpretation(testType, abnormalResults)}',
    );

    return buffer.toString().trim();
  }

  String _getTestSpecificInterpretation(
    String testType,
    List<String> abnormalResults,
  ) {
    final abnormalString = abnormalResults.join(', ').toLowerCase();

    switch (testType) {
      // === HEMATOLOGY ===
      case 'Full Blood Count (FBC)':
      case 'Basic Blood Test':
        if (abnormalString.contains('hemoglobin') &&
            abnormalString.contains('low')) {
          return 'Low hemoglobin suggests anemia. Consider iron studies, B12/folate levels, and peripheral blood smear for further evaluation.';
        }
        if (abnormalString.contains('wbc') && abnormalString.contains('high')) {
          return 'Elevated WBC may indicate infection, inflammation, stress response, or hematologic disorder. Review differential count and clinical correlation.';
        }
        if (abnormalString.contains('wbc') && abnormalString.contains('low')) {
          return 'Leukopenia noted. Consider viral infection, bone marrow suppression, or autoimmune causes. Monitor closely.';
        }
        if (abnormalString.contains('platelets') &&
            abnormalString.contains('low')) {
          return 'Thrombocytopenia detected. Assess bleeding risk. Investigate for ITP, bone marrow disorder, or medication effect.';
        }
        if (abnormalString.contains('platelets') &&
            abnormalString.contains('high')) {
          return 'Thrombocytosis noted. Consider reactive process vs. myeloproliferative disorder. Clinical correlation needed.';
        }
        if (abnormalString.contains('mcv') && abnormalString.contains('high')) {
          return 'Macrocytic anemia. Consider B12/folate deficiency, alcohol use, or hypothyroidism.';
        }
        if (abnormalString.contains('mcv') && abnormalString.contains('low')) {
          return 'Microcytic anemia. Suggestive of iron deficiency or thalassemia. Iron studies recommended.';
        }
        if (abnormalString.contains('neutrophils') &&
            abnormalString.contains('high')) {
          return 'Neutrophilia detected. Suggests bacterial infection or inflammatory process.';
        }
        if (abnormalString.contains('lymphocytes') &&
            abnormalString.contains('high')) {
          return 'Lymphocytosis noted. Consider viral infection or lymphoproliferative disorder.';
        }
        if (abnormalString.contains('eosinophils') &&
            abnormalString.contains('high')) {
          return 'Eosinophilia detected. Evaluate for parasitic infection, allergic conditions, or drug reaction.';
        }
        return 'Abnormal CBC findings. Clinical correlation and further hematologic assessment recommended.';

      // === BIOCHEMISTRY ===
      case 'Blood Sugar (Glucose)':
      case 'Blood Sugar':
        if (abnormalString.contains('fasting') &&
            abnormalString.contains('high')) {
          return 'Elevated fasting glucose. If ≥126 mg/dL on repeat testing, confirms diabetes mellitus. HbA1c recommended for glycemic control assessment.';
        }
        if (abnormalString.contains('random') &&
            abnormalString.contains('high')) {
          return 'Hyperglycemia noted. If ≥200 mg/dL with symptoms, diagnostic of diabetes. Lifestyle modification and possible medication indicated.';
        }
        if (abnormalString.contains('low')) {
          return 'Hypoglycemia detected. Immediate assessment and treatment required. Investigate cause (medication, insulinoma, adrenal insufficiency).';
        }
        if (abnormalString.contains('2hr') && abnormalString.contains('high')) {
          return 'Impaired glucose tolerance. Pre-diabetic state. Lifestyle intervention crucial to prevent progression.';
        }
        return 'Abnormal glucose levels detected. Diabetes screening and management review recommended.';

      case 'Cholesterol Test':
      case 'Lipid Profile':
        if (abnormalString.contains('ldl') && abnormalString.contains('high')) {
          return 'Elevated LDL cholesterol increases cardiovascular risk. Statin therapy and lifestyle modifications (diet, exercise) recommended.';
        }
        if (abnormalString.contains('hdl') && abnormalString.contains('low')) {
          return 'Low HDL cholesterol is a cardiovascular risk factor. Exercise and smoking cessation can help improve levels.';
        }
        if (abnormalString.contains('triglycerides') &&
            abnormalString.contains('high')) {
          return 'Hypertriglyceridemia noted. If severe (>500 mg/dL), risk of pancreatitis. Consider fibrates, omega-3, and dietary fat restriction.';
        }
        if (abnormalString.contains('total cholesterol') &&
            abnormalString.contains('high')) {
          return 'Hypercholesterolemia detected. Cardiovascular risk assessment (ASCVD score) recommended. Lifestyle modification and possible statin therapy.';
        }
        return 'Dyslipidemia detected. Comprehensive cardiovascular risk assessment and lipid-lowering therapy consideration recommended.';

      case 'Liver Function Test':
        if (abnormalString.contains('bilirubin') &&
            abnormalString.contains('high')) {
          return 'Hyperbilirubinemia noted. Differentiate conjugated vs unconjugated. Consider hepatocellular injury, cholestasis, or hemolysis.';
        }
        if (abnormalString.contains('alt') || abnormalString.contains('sgpt')) {
          if (abnormalString.contains('high')) {
            return 'Elevated ALT suggests hepatocellular injury. Consider viral hepatitis, NAFLD, drug-induced liver injury, or autoimmune hepatitis. Viral serology recommended.';
          }
        }
        if (abnormalString.contains('ast') || abnormalString.contains('sgot')) {
          if (abnormalString.contains('high')) {
            return 'Elevated AST. If AST:ALT >2, consider alcoholic liver disease. Also seen in muscle injury and cardiac conditions.';
          }
        }
        if (abnormalString.contains('alp') && abnormalString.contains('high')) {
          return 'Elevated alkaline phosphatase. Suggests cholestasis or bone disease. Check GGT to confirm hepatobiliary origin.';
        }
        if (abnormalString.contains('albumin') &&
            abnormalString.contains('low')) {
          return 'Hypoalbuminemia noted. May indicate chronic liver disease, malnutrition, or protein-losing conditions.';
        }
        return 'Abnormal liver function tests. Hepatobiliary evaluation and possibly imaging (ultrasound) recommended.';

      case 'Kidney Function Test':
        if (abnormalString.contains('creatinine') &&
            abnormalString.contains('high')) {
          return 'Elevated creatinine indicates impaired renal function. Calculate eGFR to stage CKD. Consider nephrology referral if eGFR <30. Evaluate for reversible causes.';
        }
        if (abnormalString.contains('urea') &&
            abnormalString.contains('high')) {
          return 'Elevated urea. Assess for prerenal (dehydration), renal, or postrenal causes. Check creatinine ratio and hydration status.';
        }
        if (abnormalString.contains('potassium') &&
            abnormalString.contains('high')) {
          return 'Hyperkalemia detected. Cardiac monitoring essential. Risk of arrhythmia. Evaluate cause (renal failure, medications, hemolysis). Treatment may include calcium gluconate, insulin-glucose, diuretics.';
        }
        if (abnormalString.contains('potassium') &&
            abnormalString.contains('low')) {
          return 'Hypokalemia noted. Can cause cardiac arrhythmias and muscle weakness. Replace potassium and investigate cause (diuretics, diarrhea, vomiting).';
        }
        if (abnormalString.contains('sodium') &&
            abnormalString.contains('high')) {
          return 'Hypernatremia. Assess hydration status and free water deficit. Correct slowly to avoid cerebral edema.';
        }
        if (abnormalString.contains('sodium') &&
            abnormalString.contains('low')) {
          return 'Hyponatremia. Classify as hypovolemic, euvolemic, or hypervolemic. Correct cautiously to avoid osmotic demyelination syndrome.';
        }
        if (abnormalString.contains('uric acid') &&
            abnormalString.contains('high')) {
          return 'Hyperuricemia noted. Risk factor for gout and kidney stones. Consider uric acid-lowering therapy if symptomatic.';
        }
        return 'Abnormal kidney function markers. Comprehensive renal assessment, eGFR calculation, and nephrology consultation recommended.';

      case 'Thyroid Function Test':
        if (abnormalString.contains('tsh') && abnormalString.contains('high')) {
          return 'Elevated TSH suggests primary hypothyroidism. Check Free T4. If TSH >10 μIU/mL, levothyroxine replacement indicated. Monitor thyroid function in 6-8 weeks.';
        }
        if (abnormalString.contains('tsh') && abnormalString.contains('low')) {
          return 'Suppressed TSH suggests hyperthyroidism. Check Free T4/T3 levels. Consider Graves\' disease, toxic nodular goiter, or thyroiditis. Anti-thyroid drugs or radioiodine may be needed.';
        }
        if (abnormalString.contains('t4') && abnormalString.contains('high')) {
          return 'Elevated T4. With low TSH suggests primary hyperthyroidism. With normal/high TSH, consider pituitary adenoma or thyroid hormone resistance.';
        }
        if (abnormalString.contains('t4') && abnormalString.contains('low')) {
          return 'Low T4. With high TSH confirms primary hypothyroidism. With low TSH, consider secondary hypothyroidism (pituitary/hypothalamic dysfunction).';
        }
        if (abnormalString.contains('t3') && abnormalString.contains('high')) {
          return 'Elevated T3. May indicate T3 toxicosis. Common in early Graves\' disease or toxic adenoma.';
        }
        return 'Thyroid dysfunction detected. Comprehensive thyroid assessment and endocrine evaluation recommended.';

      // === MICROBIOLOGY & SEROLOGY ===
      case 'Malaria Test':
        if (abnormalString.contains('parasite') ||
            abnormalString.contains('malaria')) {
          return 'Malaria parasite detected. Immediate antimalarial therapy indicated (Artemisinin-based combination therapy preferred). Assess severity and consider hospitalization if complicated malaria.';
        }
        if (abnormalString.contains('density') &&
            abnormalString.contains('high')) {
          return 'High parasite density (>10,000/μL) indicates severe malaria. Urgent treatment and hospitalization required. Monitor for complications (cerebral malaria, renal failure, ARDS).';
        }
        return 'Positive malaria test. Species-specific antimalarial treatment required. Monitor clinical response.';

      case 'Typhoid Test':
      case 'Widal Test (Typhoid)':
        if (abnormalString.contains('high') ||
            abnormalString.contains('positive')) {
          return 'Widal test suggestive of typhoid infection (significant if titers ≥1:160 or 4-fold rise in paired samples). Clinical correlation essential. Consider blood culture for confirmation. Treatment: fluoroquinolones or ceftriaxone.';
        }
        return 'Widal test positive. Correlate with clinical presentation (fever, abdominal pain). False positives common in endemic areas. Blood culture confirmatory.';

      case 'HIV Test':
      case 'HIV Screening':
        if (abnormalString.contains('reactive') ||
            abnormalString.contains('positive')) {
          return 'HIV antibodies detected (Reactive). MANDATORY confirmatory testing with Western blot or HIV RNA PCR. Pre- and post-test counseling required. Initiate ART if confirmed. CD4 count and viral load needed.';
        }
        return 'HIV test reactive. Confirmatory testing and comprehensive counseling essential. Refer to HIV treatment center.';

      case 'Hepatitis B/C Test':
      case 'Hepatitis Test':
        if (abnormalString.contains('hbsag') &&
            abnormalString.contains('reactive')) {
          return 'HBsAg positive indicates active Hepatitis B infection (acute or chronic). Check HBeAg, Anti-HBe, and HBV DNA viral load. Assess liver function. Consider antiviral therapy (tenofovir, entecavir) if chronic.';
        }
        if (abnormalString.contains('hcv') &&
            abnormalString.contains('reactive')) {
          return 'Anti-HCV positive suggests Hepatitis C exposure. Confirm with HCV RNA PCR. If positive, genotyping and treatment with direct-acting antivirals (DAAs) indicated. Monitor liver function.';
        }
        return 'Viral hepatitis detected. Comprehensive liver assessment, viral load testing, and antiviral therapy consideration recommended.';

      // === URINALYSIS & STOOL ===
      case 'Urinalysis':
      case 'Urine Test':
        if (abnormalString.contains('protein')) {
          return 'Proteinuria detected. Quantify with spot protein:creatinine ratio or 24-hour urine. Evaluate for diabetic nephropathy, glomerulonephritis, or hypertensive nephropathy.';
        }
        if (abnormalString.contains('glucose')) {
          return 'Glycosuria noted. Usually indicates hyperglycemia (renal threshold ~180 mg/dL). Screen for diabetes mellitus with fasting glucose or HbA1c.';
        }
        if (abnormalString.contains('blood') ||
            abnormalString.contains('rbcs')) {
          return 'Hematuria detected. Differentiate glomerular vs non-glomerular. Consider UTI, kidney stones, malignancy, or glomerulonephritis. Further urological evaluation needed.';
        }
        if (abnormalString.contains('leukocytes') ||
            abnormalString.contains('pus') ||
            abnormalString.contains('nitrite')) {
          return 'Pyuria/positive nitrite suggests urinary tract infection. Urine culture and sensitivity recommended. Empirical antibiotic therapy (nitrofurantoin, trimethoprim-sulfamethoxazole) may be started.';
        }
        if (abnormalString.contains('ketones')) {
          return 'Ketonuria detected. Suggests diabetic ketoacidosis, starvation, or alcoholic ketoacidosis. Check blood glucose and pH urgently.';
        }
        if (abnormalString.contains('bilirubin')) {
          return 'Bilirubinuria indicates conjugated hyperbilirubinemia. Suggests hepatobiliary disease. Check liver function tests and consider imaging.';
        }
        return 'Abnormal urinalysis findings. Clinical correlation and further urological/renal assessment recommended.';

      case 'Stool Analysis':
      case 'Stool Test':
        if (abnormalString.contains('ova') ||
            abnormalString.contains('parasites')) {
          return 'Intestinal parasites detected. Initiate appropriate antiparasitic therapy: Albendazole (roundworms), Praziquantel (flukes/tapeworms), Metronidazole (Giardia/Entamoeba). Repeat stool examination after treatment.';
        }
        if (abnormalString.contains('blood') ||
            abnormalString.contains('occult blood')) {
          return 'Occult blood positive. Investigate for GI bleeding, peptic ulcer, inflammatory bowel disease, or colorectal malignancy. Upper GI endoscopy or colonoscopy may be indicated.';
        }
        if (abnormalString.contains('pus') ||
            abnormalString.contains('leukocytes')) {
          return 'Fecal leukocytes present. Suggests invasive bacterial diarrhea (Shigella, Salmonella, Campylobacter) or inflammatory bowel disease. Stool culture recommended.';
        }
        if (abnormalString.contains('fat')) {
          return 'Fat globules detected. Indicates malabsorption (celiac disease, chronic pancreatitis, bile salt deficiency). Further GI workup needed.';
        }
        return 'Abnormal stool findings. Gastrointestinal assessment and possible stool culture/imaging recommended.';

      // === PREGNANCY & BLOOD GROUP ===
      case 'Pregnancy Test':
        if (abnormalString.contains('positive')) {
          return 'Pregnancy test positive (hCG detected). Confirm pregnancy viability with serum β-hCG quantification and transvaginal ultrasound. Initiate prenatal care.';
        }
        return 'Pregnancy confirmed. Initiate antenatal care and folic acid supplementation.';

      case 'Blood Group':
        // Informational only
        return 'Blood group documented. Critical for transfusion compatibility, pregnancy (Rh incompatibility screening), and organ transplantation.';

      // === CARDIAC & IMAGING ===
      case 'ECG/EKG':
        if (abnormalString.contains('heart rate') ||
            abnormalString.contains('rhythm')) {
          return 'Cardiac rhythm abnormality detected. Consider arrhythmia workup. Holter monitoring or electrophysiology study may be needed.';
        }
        if (abnormalString.contains('st segment')) {
          return 'ST segment changes noted. Evaluate for myocardial ischemia or infarction. Troponin and cardiology consultation recommended.';
        }
        if (abnormalString.contains('qt interval')) {
          return 'QT interval abnormality. Assess for long QT syndrome (risk of torsades de pointes) or short QT syndrome. Review medications.';
        }
        return 'ECG abnormality detected. Cardiology evaluation recommended.';

      case 'X-Ray (Chest)':
      case 'X-Ray (Other)':
        if (abnormalString.contains('fracture')) {
          return 'Fracture identified. Orthopedic evaluation for management (casting, fixation, or surgical intervention).';
        }
        if (abnormalString.contains('lung')) {
          return 'Pulmonary abnormality detected. Consider pneumonia, tuberculosis, malignancy, or interstitial lung disease. Further evaluation with CT chest may be needed.';
        }
        return 'Radiological abnormality detected. Clinical correlation and possible additional imaging recommended.';

      case 'Ultrasound Scan':
        if (abnormalString.contains('mass') ||
            abnormalString.contains('lesion')) {
          return 'Mass/lesion detected on ultrasound. Characterization needed. Consider CT/MRI for better evaluation. Biopsy may be required if malignancy suspected.';
        }
        if (abnormalString.contains('fluid')) {
          return 'Free fluid/effusion detected. Investigate cause (infection, malignancy, heart failure, liver disease). Diagnostic aspiration may be indicated.';
        }
        return 'Ultrasound abnormality detected. Clinical correlation and further imaging/intervention recommended.';

      default:
        return 'Clinical correlation and further assessment recommended based on findings.';
    }
  }

  bool _isValueNormal(String value, String normalRange) {
    if (normalRange.isEmpty || value.isEmpty) return true;

    // Handle non-numeric values (e.g., Negative, Positive, etc.)
    if (!_isNumeric(value)) {
      return normalRange.toLowerCase().contains(value.toLowerCase());
    }

    // Parse numeric value
    final numValue = double.tryParse(value);
    if (numValue == null) return true;

    // Handle ranges like "10-20" or "<20" or ">10"
    if (normalRange.contains('-')) {
      final parts = normalRange.split('-');
      if (parts.length == 2) {
        final min = double.tryParse(parts[0].trim());
        final max = double.tryParse(
          parts[1].trim().split(' ')[0],
        ); // Handle "(M)" suffix
        if (min != null && max != null) {
          return numValue >= min && numValue <= max;
        }
      }
    } else if (normalRange.startsWith('<')) {
      final max = double.tryParse(normalRange.substring(1).trim());
      if (max != null) return numValue < max;
    } else if (normalRange.startsWith('>')) {
      final min = double.tryParse(normalRange.substring(1).trim());
      if (min != null) return numValue > min;
    }

    return true;
  }

  String _analyzeValueStatus(String value, String normalRange) {
    if (!_isNumeric(value)) {
      return 'abnormal';
    }

    final numValue = double.tryParse(value);
    if (numValue == null) return 'abnormal';

    if (normalRange.contains('-')) {
      final parts = normalRange.split('-');
      if (parts.length == 2) {
        final min = double.tryParse(parts[0].trim());
        final max = double.tryParse(parts[1].trim().split(' ')[0]);
        if (min != null && max != null) {
          if (numValue < min) return 'LOW';
          if (numValue > max) return 'HIGH';
        }
      }
    } else if (normalRange.startsWith('<')) {
      final max = double.tryParse(normalRange.substring(1).trim());
      if (max != null && numValue >= max) return 'HIGH';
    } else if (normalRange.startsWith('>')) {
      final min = double.tryParse(normalRange.substring(1).trim());
      if (min != null && numValue <= min) return 'LOW';
    }

    return 'abnormal';
  }

  bool _isNumeric(String str) {
    return double.tryParse(str) != null;
  }
}
