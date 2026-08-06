// Disease Surveillance Screen
// Notifiable Diseases Reporting following WHO IDSR Guidelines and Nigeria CDC
// Reference: WHO Integrated Disease Surveillance and Response (IDSR) in African Region

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DiseaseSurveillanceScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const DiseaseSurveillanceScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<DiseaseSurveillanceScreen> createState() =>
      _DiseaseSurveillanceScreenState();
}

class _DiseaseSurveillanceScreenState extends State<DiseaseSurveillanceScreen>
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
        title: const Text('Disease Surveillance'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Report Case'),
            Tab(text: 'Notifiable Diseases'),
            Tab(text: 'Active Cases'),
            Tab(text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportCaseTab(),
          _buildNotifiableDiseasesTab(),
          _buildActiveCasesTab(),
          _buildReportsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewCaseReportForm(context),
        backgroundColor: Colors.orange.shade700,
        icon: const Icon(Icons.add),
        label: const Text('Report Case'),
      ),
    );
  }

  Widget _buildReportCaseTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('disease_surveillance_cases')
          .where('facilityId', isEqualTo: widget.facilityId)
          .orderBy('reportedDate', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final cases = snapshot.data?.docs ?? [];

        if (cases.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.health_and_safety,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No cases reported yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + to report a new case',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cases.length,
          itemBuilder: (context, index) {
            final caseData = cases[index].data() as Map<String, dynamic>;
            return _buildCaseCard(caseData);
          },
        );
      },
    );
  }

  Widget _buildCaseCard(Map<String, dynamic> caseData) {
    final disease = caseData['disease'] ?? 'Unknown';
    final patientAge = caseData['patientAge'] ?? 'Unknown';
    final status = caseData['status'] ?? 'Reported';
    final date = (caseData['reportedDate'] as Timestamp?)?.toDate();
    final isUrgent = caseData['priority'] == 'Immediate';

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'confirmed':
        statusColor = Colors.red;
        break;
      case 'suspected':
        statusColor = Colors.orange;
        break;
      case 'investigated':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isUrgent
              ? Colors.red.shade100
              : Colors.orange.shade100,
          child: Icon(
            isUrgent ? Icons.warning : Icons.report,
            color: isUrgent ? Colors.red.shade700 : Colors.orange.shade700,
          ),
        ),
        title: Text(
          disease,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Age: $patientAge'),
            if (date != null)
              Text('Date: ${DateFormat('MMM d, y').format(date)}'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            // Show case details
          },
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildNotifiableDiseasesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'WHO IDSR Guidelines',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'All notifiable diseases must be reported within the specified timeframes. '
                  'Immediate reporting for epidemic-prone diseases.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Immediately Notifiable (Within 24 hours)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          _buildDiseaseCard(
            disease: 'Cholera',
            description: 'Acute watery diarrhea with severe dehydration',
            priority: 'Immediate',
            color: Colors.red,
            icon: Icons.water_damage,
          ),
          _buildDiseaseCard(
            disease: 'Measles',
            description: 'Fever with maculopapular rash',
            priority: 'Immediate',
            color: Colors.red,
            icon: Icons.coronavirus,
          ),
          _buildDiseaseCard(
            disease: 'Yellow Fever',
            description: 'Acute viral hemorrhagic disease',
            priority: 'Immediate',
            color: Colors.red,
            icon: Icons.bug_report,
          ),
          _buildDiseaseCard(
            disease: 'Viral Hemorrhagic Fevers (Lassa, Ebola)',
            description: 'Fever with bleeding manifestations',
            priority: 'Immediate',
            color: Colors.red,
            icon: Icons.bloodtype,
          ),
          _buildDiseaseCard(
            disease: 'Meningococcal Meningitis',
            description: 'Bacterial infection of the meninges',
            priority: 'Immediate',
            color: Colors.red,
            icon: Icons.health_and_safety,
          ),
          _buildDiseaseCard(
            disease: 'Poliomyelitis (Acute Flaccid Paralysis)',
            description: 'Sudden onset of paralysis',
            priority: 'Immediate',
            color: Colors.red,
            icon: Icons.accessible,
          ),
          _buildDiseaseCard(
            disease: 'COVID-19',
            description: 'SARS-CoV-2 infection',
            priority: 'Immediate',
            color: Colors.red,
            icon: Icons.masks,
          ),
          const SizedBox(height: 20),
          const Text(
            'Weekly Notifiable Diseases',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 12),
          _buildDiseaseCard(
            disease: 'Malaria',
            description: 'Fever with parasitemia',
            priority: 'Weekly',
            color: Colors.orange,
            icon: Icons.pest_control,
          ),
          _buildDiseaseCard(
            disease: 'Tuberculosis',
            description: 'Chronic cough with sputum',
            priority: 'Weekly',
            color: Colors.orange,
            icon: Icons.air,
          ),
          _buildDiseaseCard(
            disease: 'HIV/AIDS',
            description: 'Human Immunodeficiency Virus',
            priority: 'Weekly',
            color: Colors.orange,
            icon: Icons.medical_services,
          ),
          _buildDiseaseCard(
            disease: 'Typhoid Fever',
            description: 'Sustained fever with headache',
            priority: 'Weekly',
            color: Colors.orange,
            icon: Icons.sick,
          ),
          _buildDiseaseCard(
            disease: 'Hepatitis B & C',
            description: 'Viral hepatitis infections',
            priority: 'Weekly',
            color: Colors.orange,
            icon: Icons.biotech,
          ),
          _buildDiseaseCard(
            disease: 'Diarrheal Diseases',
            description: 'Non-cholera acute diarrhea',
            priority: 'Weekly',
            color: Colors.orange,
            icon: Icons.sick,
          ),
          const SizedBox(height: 20),
          const Text(
            'Monthly Notifiable Diseases',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 12),
          _buildDiseaseCard(
            disease: 'Hypertension',
            description: 'Non-communicable disease surveillance',
            priority: 'Monthly',
            color: Colors.blue,
            icon: Icons.monitor_heart,
          ),
          _buildDiseaseCard(
            disease: 'Diabetes',
            description: 'Non-communicable disease surveillance',
            priority: 'Monthly',
            color: Colors.blue,
            icon: Icons.bloodtype,
          ),
          _buildDiseaseCard(
            disease: 'Mental Health Disorders',
            description: 'Mental health surveillance',
            priority: 'Monthly',
            color: Colors.blue,
            icon: Icons.psychology,
          ),
        ],
      ),
    );
  }

  Widget _buildDiseaseCard({
    required String disease,
    required String description,
    required String priority,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          disease,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Report: $priority',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.report, color: color),
          onPressed: () =>
              _showNewCaseReportForm(context, preSelectedDisease: disease),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildActiveCasesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('disease_surveillance_cases')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where(
            'status',
            whereIn: ['Suspected', 'Confirmed', 'Under Investigation'],
          )
          .orderBy('reportedDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final cases = snapshot.data?.docs ?? [];

        if (cases.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.green.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No active cases',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cases.length,
          itemBuilder: (context, index) {
            final caseData = cases[index].data() as Map<String, dynamic>;
            return _buildCaseCard(caseData);
          },
        );
      },
    );
  }

  Widget _buildReportsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Disease Surveillance Reports',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildReportCard(
          title: 'Weekly Epidemiological Report',
          description: 'Summary of cases reported this week',
          icon: Icons.calendar_view_week,
          color: Colors.blue,
          onTap: () => _showWeeklyEpidemiologicalReport(context),
        ),
        _buildReportCard(
          title: 'Monthly Disease Trends',
          description: 'Disease incidence and trends',
          icon: Icons.trending_up,
          color: Colors.green,
          onTap: () => _showMonthlyDiseaseTrends(context),
        ),
        _buildReportCard(
          title: 'Outbreak Alerts',
          description: 'Active outbreak notifications',
          icon: Icons.warning,
          color: Colors.red,
          onTap: () => _showOutbreakAlerts(context),
        ),
        _buildReportCard(
          title: 'Case Investigation Reports',
          description: 'Detailed case investigations',
          icon: Icons.search,
          color: Colors.purple,
          onTap: () => _showCaseInvestigationReports(context),
        ),
        _buildReportCard(
          title: 'Laboratory Results',
          description: 'Lab confirmation of cases',
          icon: Icons.science,
          color: Colors.teal,
          onTap: () => _showLaboratoryResults(context),
        ),
        _buildReportCard(
          title: 'Contact Tracing',
          description: 'Contacts identified and followed up',
          icon: Icons.people,
          color: Colors.orange,
          onTap: () => _showContactTracingReport(context),
        ),
      ],
    );
  }

  Widget _buildReportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showWeeklyEpidemiologicalReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _WeeklyEpidemiologicalReportView(facilityId: widget.facilityId),
      ),
    );
  }

  void _showMonthlyDiseaseTrends(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _MonthlyDiseaseTrendsView(facilityId: widget.facilityId),
      ),
    );
  }

  void _showOutbreakAlerts(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _OutbreakAlertsView(facilityId: widget.facilityId),
      ),
    );
  }

  void _showCaseInvestigationReports(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _CaseInvestigationReportsView(facilityId: widget.facilityId),
      ),
    );
  }

  void _showLaboratoryResults(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _LaboratoryResultsView(facilityId: widget.facilityId),
      ),
    );
  }

  void _showContactTracingReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _ContactTracingReportView(facilityId: widget.facilityId),
      ),
    );
  }

  void _showNewCaseReportForm(
    BuildContext context, {
    String? preSelectedDisease,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CaseReportForm(
        facilityId: widget.facilityId,
        facilityName: widget.facilityName,
        staffId: widget.staffId,
        staffName: widget.staffName,
        preSelectedDisease: preSelectedDisease,
      ),
    );
  }
}

// Case Report Form Widget
class _CaseReportForm extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final String? preSelectedDisease;

  const _CaseReportForm({
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    this.preSelectedDisease,
  });

  @override
  State<_CaseReportForm> createState() => _CaseReportFormState();
}

class _CaseReportFormState extends State<_CaseReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _patientNameController = TextEditingController();
  final _patientIdController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _symptomsController = TextEditingController();

  String? _selectedDisease;
  String? _selectedGender;
  String? _selectedStatus;
  String? _selectedPriority;
  final DateTime _onsetDate = DateTime.now();
  final DateTime _reportDate = DateTime.now();
  bool _isSubmitting = false;

  final List<String> _diseases = [
    'Cholera',
    'Measles',
    'Yellow Fever',
    'Lassa Fever',
    'Ebola',
    'Meningococcal Meningitis',
    'Poliomyelitis',
    'COVID-19',
    'Malaria',
    'Tuberculosis',
    'HIV/AIDS',
    'Typhoid Fever',
    'Hepatitis B',
    'Hepatitis C',
    'Diarrheal Disease',
    'Other',
  ];

  final List<String> _statuses = [
    'Suspected',
    'Probable',
    'Confirmed',
    'Under Investigation',
  ];

  final List<String> _priorities = ['Immediate', 'Weekly', 'Monthly'];

  @override
  void initState() {
    super.initState();
    _selectedDisease = widget.preSelectedDisease;
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _patientIdController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _symptomsController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance
          .collection('disease_surveillance_cases')
          .add({
            'facilityId': widget.facilityId,
            'facilityName': widget.facilityName,
            'reportedBy': widget.staffName,
            'reportedById': widget.staffId,
            'disease': _selectedDisease,
            'patientName': _patientNameController.text.trim(),
            'patientId': _patientIdController.text.trim(),
            'patientAge': _ageController.text.trim(),
            'patientGender': _selectedGender,
            'patientAddress': _addressController.text.trim(),
            'patientPhone': _phoneController.text.trim(),
            'symptoms': _symptomsController.text.trim(),
            'onsetDate': _onsetDate,
            'reportedDate': _reportDate,
            'status': _selectedStatus,
            'priority': _selectedPriority,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Case reported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.report, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Disease Case Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedDisease,
                        decoration: const InputDecoration(
                          labelText: 'Disease *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.coronavirus),
                        ),
                        items: _diseases.map((disease) {
                          return DropdownMenuItem(
                            value: disease,
                            child: Text(disease),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedDisease = value);
                        },
                        validator: (value) {
                          if (value == null) return 'Please select disease';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Case Status *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.info),
                        ),
                        items: _statuses.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedStatus = value);
                        },
                        validator: (value) {
                          if (value == null) return 'Please select status';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedPriority,
                        decoration: const InputDecoration(
                          labelText: 'Reporting Priority *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.priority_high),
                        ),
                        items: _priorities.map((priority) {
                          return DropdownMenuItem(
                            value: priority,
                            child: Text(priority),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedPriority = value);
                        },
                        validator: (value) {
                          if (value == null) return 'Please select priority';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Patient Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _patientNameController,
                        decoration: const InputDecoration(
                          labelText: 'Patient Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter patient name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ageController,
                              decoration: const InputDecoration(
                                labelText: 'Age *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.cake),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: const InputDecoration(
                                labelText: 'Gender *',
                                border: OutlineInputBorder(),
                              ),
                              items: ['Male', 'Female', 'Other'].map((gender) {
                                return DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedGender = value);
                              },
                              validator: (value) {
                                if (value == null) return 'Required';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.home),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _symptomsController,
                        decoration: const InputDecoration(
                          labelText: 'Clinical Symptoms *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.medical_services),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please describe symptoms';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitForm,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            _isSubmitting ? 'Reporting...' : 'Submit Report',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ===================== REPORT VIEW CLASSES =====================

/// 1. Weekly Epidemiological Report
class _WeeklyEpidemiologicalReportView extends StatefulWidget {
  final String facilityId;

  const _WeeklyEpidemiologicalReportView({required this.facilityId});

  @override
  State<_WeeklyEpidemiologicalReportView> createState() =>
      _WeeklyEpidemiologicalReportViewState();
}

class _WeeklyEpidemiologicalReportViewState
    extends State<_WeeklyEpidemiologicalReportView> {
  late DateTime startDate;
  late DateTime endDate;

  @override
  void initState() {
    super.initState();
    // Current week (Monday to Sunday)
    final now = DateTime.now();
    final weekday = now.weekday;
    startDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: weekday - 1));
    endDate = startDate.add(const Duration(days: 6, hours: 23, minutes: 59));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Epidemiological Report'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // Export functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export feature coming soon')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Range Selector
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Week Range',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '${startDate.day}/${startDate.month} - ${endDate.day}/${endDate.month}/${endDate.year}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.navigate_before),
                  onPressed: () {
                    setState(() {
                      startDate = startDate.subtract(const Duration(days: 7));
                      endDate = endDate.subtract(const Duration(days: 7));
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.navigate_next),
                  onPressed: () {
                    setState(() {
                      startDate = startDate.add(const Duration(days: 7));
                      endDate = endDate.add(const Duration(days: 7));
                    });
                  },
                ),
              ],
            ),
          ),

          // Report Content
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('disease_surveillance_cases')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .orderBy('reportedDate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allCases = snapshot.data?.docs ?? [];

                // Filter by date range
                final weekCases = allCases.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final reportedDate = (data['reportedDate'] as Timestamp?)
                      ?.toDate();
                  if (reportedDate == null) return false;
                  return reportedDate.isAfter(startDate) &&
                      reportedDate.isBefore(endDate);
                }).toList();

                if (weekCases.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No cases reported this week',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Aggregate data by disease
                final Map<String, Map<String, dynamic>> diseaseStats = {};
                for (var doc in weekCases) {
                  final data = doc.data() as Map<String, dynamic>;
                  final disease = data['disease'] as String? ?? 'Unknown';
                  final status = data['status'] as String? ?? 'Unknown';

                  if (!diseaseStats.containsKey(disease)) {
                    diseaseStats[disease] = {
                      'total': 0,
                      'suspected': 0,
                      'probable': 0,
                      'confirmed': 0,
                      'underInvestigation': 0,
                    };
                  }

                  diseaseStats[disease]!['total']++;
                  if (status == 'Suspected') {
                    diseaseStats[disease]!['suspected']++;
                  }
                  if (status == 'Probable') {
                    diseaseStats[disease]!['probable']++;
                  }
                  if (status == 'Confirmed') {
                    diseaseStats[disease]!['confirmed']++;
                  }
                  if (status == 'Under Investigation') {
                    diseaseStats[disease]!['underInvestigation']++;
                  }
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Cases',
                            weekCases.length.toString(),
                            Icons.medical_services,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            'Diseases',
                            diseaseStats.length.toString(),
                            Icons.coronavirus,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Disease Breakdown
                    const Text(
                      'Cases by Disease',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...diseaseStats.entries.map((entry) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      '${entry.value['total']} cases',
                                    ),
                                    backgroundColor: Colors.blue.shade100,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatusChip(
                                    'Suspected',
                                    entry.value['suspected'],
                                    Colors.yellow,
                                  ),
                                  _buildStatusChip(
                                    'Probable',
                                    entry.value['probable'],
                                    Colors.orange,
                                  ),
                                  _buildStatusChip(
                                    'Confirmed',
                                    entry.value['confirmed'],
                                    Colors.red,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

/// 2. Monthly Disease Trends
class _MonthlyDiseaseTrendsView extends StatefulWidget {
  final String facilityId;

  const _MonthlyDiseaseTrendsView({required this.facilityId});

  @override
  State<_MonthlyDiseaseTrendsView> createState() =>
      _MonthlyDiseaseTrendsViewState();
}

class _MonthlyDiseaseTrendsViewState extends State<_MonthlyDiseaseTrendsView> {
  late DateTime selectedMonth;

  @override
  void initState() {
    super.initState();
    selectedMonth = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final startDate = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final endDate = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
      23,
      59,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Disease Trends'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Month',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '${_monthName(selectedMonth.month)} ${selectedMonth.year}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.navigate_before),
                  onPressed: () {
                    setState(() {
                      selectedMonth = DateTime(
                        selectedMonth.year,
                        selectedMonth.month - 1,
                      );
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.navigate_next),
                  onPressed: () {
                    setState(() {
                      selectedMonth = DateTime(
                        selectedMonth.year,
                        selectedMonth.month + 1,
                      );
                    });
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('disease_surveillance_cases')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .orderBy('reportedDate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allCases = snapshot.data?.docs ?? [];
                final monthCases = allCases.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final reportedDate = (data['reportedDate'] as Timestamp?)
                      ?.toDate();
                  if (reportedDate == null) return false;
                  return reportedDate.isAfter(startDate) &&
                      reportedDate.isBefore(endDate);
                }).toList();

                if (monthCases.isEmpty) {
                  return const Center(child: Text('No cases this month'));
                }

                // Group by disease
                final Map<String, List<Map<String, dynamic>>> diseaseGroups =
                    {};
                for (var doc in monthCases) {
                  final data = doc.data() as Map<String, dynamic>;
                  final disease = data['disease'] as String? ?? 'Unknown';
                  diseaseGroups.putIfAbsent(disease, () => []);
                  diseaseGroups[disease]!.add(data);
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Total Cases: ${monthCases.length}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ...diseaseGroups.entries.map((entry) {
                      final diseaseCount = entry.value.length;
                      final confirmedCount = entry.value
                          .where((c) => c['status'] == 'Confirmed')
                          .length;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: Text(diseaseCount.toString()),
                          ),
                          title: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('$confirmedCount confirmed cases'),
                          trailing: Icon(
                            diseaseCount > 5
                                ? Icons.trending_up
                                : Icons.trending_flat,
                            color: diseaseCount > 5 ? Colors.red : Colors.grey,
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

/// 3. Outbreak Alerts
class _OutbreakAlertsView extends StatelessWidget {
  final String facilityId;

  const _OutbreakAlertsView({required this.facilityId});

  @override
  Widget build(BuildContext context) {
    // Outbreak threshold: 3+ confirmed cases of same disease in last 7 days
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Outbreak Alerts'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('disease_surveillance_cases')
            .where('facilityId', isEqualTo: facilityId)
            .orderBy('reportedDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allCases = snapshot.data?.docs ?? [];
          final recentCases = allCases.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final reportedDate = (data['reportedDate'] as Timestamp?)?.toDate();
            if (reportedDate == null) return false;
            return reportedDate.isAfter(sevenDaysAgo);
          }).toList();

          // Group by disease and check for outbreaks
          final Map<String, int> confirmedCounts = {};
          for (var doc in recentCases) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['status'] == 'Confirmed') {
              final disease = data['disease'] as String? ?? 'Unknown';
              confirmedCounts[disease] = (confirmedCounts[disease] ?? 0) + 1;
            }
          }

          final outbreaks = confirmedCounts.entries
              .where((e) => e.value >= 3)
              .toList();

          if (outbreaks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Colors.green.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No active outbreaks detected',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${outbreaks.length} potential outbreak(s) detected',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              ...outbreaks.map((entry) {
                return Card(
                  color: Colors.red.shade50,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red,
                      child: Text(
                        entry.value.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${entry.value} confirmed cases in last 7 days',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

/// 4. Case Investigation Reports
class _CaseInvestigationReportsView extends StatelessWidget {
  final String facilityId;

  const _CaseInvestigationReportsView({required this.facilityId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Case Investigation Reports'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('disease_surveillance_cases')
            .where('facilityId', isEqualTo: facilityId)
            .orderBy('reportedDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final cases = snapshot.data?.docs ?? [];

          if (cases.isEmpty) {
            return const Center(child: Text('No cases to investigate'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cases.length,
            itemBuilder: (context, index) {
              final data = cases[index].data() as Map<String, dynamic>;
              final disease = data['disease'] as String? ?? 'Unknown';
              final patientName = data['patientName'] as String? ?? 'N/A';
              final status = data['status'] as String? ?? 'Unknown';
              final priority = data['priority'] as String? ?? 'Unknown';
              final reportedDate = (data['reportedDate'] as Timestamp?)
                  ?.toDate();

              Color statusColor = Colors.grey;
              if (status == 'Confirmed') {
                statusColor = Colors.red;
              } else if (status == 'Probable')
                statusColor = Colors.orange;
              else if (status == 'Suspected')
                statusColor = Colors.yellow.shade700;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.2),
                    child: Icon(Icons.person, color: statusColor),
                  ),
                  title: Text(
                    disease,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Patient: $patientName • Priority: $priority'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Status', status, statusColor),
                          _buildDetailRow(
                            'Patient Age',
                            '${data['patientAge'] ?? 'N/A'}',
                          ),
                          _buildDetailRow(
                            'Gender',
                            data['patientGender'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            'Symptoms',
                            data['symptoms'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            'Onset Date',
                            data['onsetDate'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            'Reported',
                            reportedDate != null
                                ? '${reportedDate.day}/${reportedDate.month}/${reportedDate.year}'
                                : 'N/A',
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              // View full case details
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('View Full Details'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade700,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// 5. Laboratory Results
class _LaboratoryResultsView extends StatelessWidget {
  final String facilityId;

  const _LaboratoryResultsView({required this.facilityId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laboratory Results'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('disease_surveillance_cases')
            .where('facilityId', isEqualTo: facilityId)
            .orderBy('reportedDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final cases = snapshot.data?.docs ?? [];

          if (cases.isEmpty) {
            return const Center(child: Text('No laboratory data available'));
          }

          // Categorize by status (Confirmed = lab confirmed, others = pending)
          final confirmed = cases
              .where((d) => (d.data() as Map)['status'] == 'Confirmed')
              .length;
          final pending = cases.length - confirmed;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              confirmed.toString(),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const Text(
                              'Confirmed',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              pending.toString(),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            const Text(
                              'Pending',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'Recent Laboratory Tests',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              ...cases.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final disease = data['disease'] as String? ?? 'Unknown';
                final status = data['status'] as String? ?? 'Unknown';
                final reportedDate = (data['reportedDate'] as Timestamp?)
                    ?.toDate();

                final isConfirmed = status == 'Confirmed';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      isConfirmed ? Icons.check_circle : Icons.pending,
                      color: isConfirmed ? Colors.green : Colors.orange,
                    ),
                    title: Text(disease),
                    subtitle: Text(
                      reportedDate != null
                          ? '${reportedDate.day}/${reportedDate.month}/${reportedDate.year}'
                          : 'N/A',
                    ),
                    trailing: Chip(
                      label: Text(status),
                      backgroundColor: isConfirmed
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

/// 6. Contact Tracing Report
class _ContactTracingReportView extends StatelessWidget {
  final String facilityId;

  const _ContactTracingReportView({required this.facilityId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Tracing'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('disease_surveillance_cases')
            .where('facilityId', isEqualTo: facilityId)
            .where('status', whereIn: ['Confirmed', 'Probable'])
            .orderBy('reportedDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final cases = snapshot.data?.docs ?? [];

          if (cases.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No cases requiring contact tracing',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${cases.length} case(s) requiring contact tracing',
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              ...cases.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final disease = data['disease'] as String? ?? 'Unknown';
                final patientName = data['patientName'] as String? ?? 'N/A';
                final status = data['status'] as String? ?? 'Unknown';
                final patientPhone = data['patientPhone'] as String? ?? 'N/A';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: const Icon(
                        Icons.person_search,
                        color: Colors.orange,
                      ),
                    ),
                    title: Text(
                      disease,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Patient: $patientName'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status: $status',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Contact: $patientPhone'),
                            const SizedBox(height: 8),
                            Text('Address: ${data['patientAddress'] ?? 'N/A'}'),
                            const SizedBox(height: 16),
                            const Text(
                              'Contact Tracing Actions:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text('• Identify household contacts'),
                            const Text('• Identify workplace contacts'),
                            const Text('• Schedule follow-up visits'),
                            const Text('• Monitor for symptoms'),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Start contact tracing
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Contacts'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
