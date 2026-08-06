import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EmergencyCasesScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const EmergencyCasesScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<EmergencyCasesScreen> createState() => _EmergencyCasesScreenState();
}

class _EmergencyCasesScreenState extends State<EmergencyCasesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        title: const Text('Emergency Cases'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Critical'),
            Tab(text: 'Urgent'),
            Tab(text: 'Moderate'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCasesList('critical'),
          _buildCasesList('urgent'),
          _buildCasesList('moderate'),
          _buildCasesList(null), // All cases
        ],
      ),
    );
  }

  Widget _buildCasesList(String? severity) {
    Query query = FirebaseFirestore.instance
        .collection('admissions')
        .where('facilityId', isEqualTo: widget.facilityId)
        .where('admissionType', isEqualTo: 'emergency')
        .where('isActive', isEqualTo: true);

    if (severity != null) {
      query = query.where('severity', isEqualTo: severity);
    }

    query = query.orderBy('admittedAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Error loading emergency cases',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emergency, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  severity == null
                      ? 'No emergency cases found'
                      : 'No ${severity.toUpperCase()} cases',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
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
            return _buildCaseCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildCaseCard(String admissionId, Map<String, dynamic> data) {
    final severity = (data['severity'] ?? 'moderate').toString().toLowerCase();
    final patientStatus = (data['patientStatus'] ?? 'stable').toString();
    final admittedAt = (data['admittedAt'] as Timestamp?)?.toDate();

    Color severityColor;
    IconData severityIcon;

    switch (severity) {
      case 'critical':
        severityColor = Colors.red;
        severityIcon = Icons.warning;
        break;
      case 'urgent':
        severityColor = Colors.orange;
        severityIcon = Icons.priority_high;
        break;
      default:
        severityColor = Colors.yellow.shade700;
        severityIcon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: severityColor.withOpacity(0.3), width: 2),
      ),
      child: InkWell(
        onTap: () => _showCaseDetails(admissionId, data),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(severityIcon, color: severityColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['patientName'] ?? 'Unknown Patient',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: severityColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            severity.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Details
              _buildDetailRow(
                Icons.medical_services,
                'Diagnosis',
                data['admissionDiagnosis'] ?? 'Not specified',
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.person,
                'Admitted By',
                data['admittedBy'] ?? data['admittingDoctorName'] ?? 'Unknown',
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.local_hotel,
                'Ward',
                data['wardName'] ?? 'Not assigned',
              ),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.favorite, 'Patient Status', patientStatus),
              if (admittedAt != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.access_time,
                  'Admitted',
                  DateFormat('MMM dd, yyyy - hh:mm a').format(admittedAt),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCaseDetails(String admissionId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Text(
                'Emergency Case Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 24),

              // Patient Information
              _buildSectionTitle('Patient Information'),
              _buildInfoCard([
                {
                  'label': 'Patient Name',
                  'value': data['patientName'] ?? 'Unknown',
                },
                {'label': 'Patient ID', 'value': data['patientId'] ?? 'N/A'},
                {
                  'label': 'Severity',
                  'value': (data['severity'] ?? 'moderate')
                      .toString()
                      .toUpperCase(),
                },
                {
                  'label': 'Patient Status',
                  'value': data['patientStatus'] ?? 'stable',
                },
              ]),

              const SizedBox(height: 24),

              // Medical Information
              _buildSectionTitle('Medical Information'),
              _buildInfoCard([
                {
                  'label': 'Admission Diagnosis',
                  'value': data['admissionDiagnosis'] ?? 'Not specified',
                },
                {
                  'label': 'Admission Notes',
                  'value': data['admissionNotes'] ?? 'None',
                },
                {
                  'label': 'Department',
                  'value': data['department'] ?? 'Emergency',
                },
              ]),

              const SizedBox(height: 24),

              // Admission Details
              _buildSectionTitle('Admission Details'),
              _buildInfoCard([
                {
                  'label': 'Admitted By',
                  'value':
                      data['admittedBy'] ??
                      data['admittingDoctorName'] ??
                      'Unknown',
                },
                {'label': 'Ward', 'value': data['wardName'] ?? 'Not assigned'},
                {'label': 'Bed', 'value': data['bedNumber'] ?? 'Not assigned'},
                {'label': 'Admission Type', 'value': 'Emergency'},
                {
                  'label': 'Admitted At',
                  'value': data['admittedAt'] != null
                      ? DateFormat(
                          'MMM dd, yyyy - hh:mm a',
                        ).format((data['admittedAt'] as Timestamp).toDate())
                      : 'Unknown',
                },
              ]),

              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updatePatientStatus(admissionId, data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.edit),
                      label: const Text('Update Status'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateSeverity(admissionId, data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.priority_high),
                      label: const Text('Update Severity'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Map<String, String>> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: items.map((item) {
          final isLast = item == items.last;
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      item['label']!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      item['value']!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isLast) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade300),
                const SizedBox(height: 12),
              ],
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _updatePatientStatus(
    String admissionId,
    Map<String, dynamic> data,
  ) async {
    final currentStatus = data['patientStatus'] ?? 'stable';
    final statuses = ['stable', 'improving', 'critical', 'deteriorating'];

    final selectedStatus = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Patient Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: statuses.map((status) {
            return RadioListTile<String>(
              title: Text(status.toUpperCase()),
              value: status,
              groupValue: currentStatus,
              onChanged: (value) => Navigator.pop(context, value),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedStatus != null && selectedStatus != currentStatus) {
      try {
        await FirebaseFirestore.instance
            .collection('admissions')
            .doc(admissionId)
            .update({
              'patientStatus': selectedStatus,
              'lastUpdatedBy': widget.staffName,
              'lastUpdatedAt': FieldValue.serverTimestamp(),
            });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient status updated successfully'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
        }
      }
    }
  }

  Future<void> _updateSeverity(
    String admissionId,
    Map<String, dynamic> data,
  ) async {
    final currentSeverity = data['severity'] ?? 'moderate';
    final severities = ['critical', 'urgent', 'moderate'];

    final selectedSeverity = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Case Severity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: severities.map((severity) {
            Color color;
            IconData icon;

            switch (severity) {
              case 'critical':
                color = Colors.red;
                icon = Icons.warning;
                break;
              case 'urgent':
                color = Colors.orange;
                icon = Icons.priority_high;
                break;
              default:
                color = Colors.yellow.shade700;
                icon = Icons.info;
            }

            return RadioListTile<String>(
              title: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(severity.toUpperCase()),
                ],
              ),
              value: severity,
              groupValue: currentSeverity,
              onChanged: (value) => Navigator.pop(context, value),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedSeverity != null && selectedSeverity != currentSeverity) {
      try {
        await FirebaseFirestore.instance
            .collection('admissions')
            .doc(admissionId)
            .update({
              'severity': selectedSeverity,
              'lastUpdatedBy': widget.staffName,
              'lastUpdatedAt': FieldValue.serverTimestamp(),
            });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Case severity updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating severity: $e')),
          );
        }
      }
    }
  }
}
