// Infection Prevention and Control Screen
// Healthcare-Associated Infection (HAI) Surveillance
// Hand Hygiene Monitoring
// Hospital Outbreak Investigation
// Following WHO IPC Guidelines and Best Practices

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class InfectionPreventionControlScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const InfectionPreventionControlScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<InfectionPreventionControlScreen> createState() =>
      _InfectionPreventionControlScreenState();
}

class _InfectionPreventionControlScreenState
    extends State<InfectionPreventionControlScreen>
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
        title: const Text('Infection Prevention & Control'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'HAI Surveillance'),
            Tab(text: 'Hand Hygiene'),
            Tab(text: 'Outbreak Investigation'),
            Tab(text: 'IPC Guidelines'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHAISurveillanceTab(),
          _buildHandHygieneTab(),
          _buildOutbreakInvestigationTab(),
          _buildIPCGuidelinesTab(),
        ],
      ),
    );
  }

  // Healthcare-Associated Infection Surveillance Tab
  Widget _buildHAISurveillanceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // HAI Statistics Dashboard
        _buildStatisticsCard(),
        const SizedBox(height: 16),

        const Text(
          'Common Healthcare-Associated Infections',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        _buildHAITypeCard(
          infection: 'Central Line-Associated Bloodstream Infection (CLABSI)',
          description:
              'Bloodstream infection in patients with central venous catheter',
          icon: Icons.bloodtype,
          color: Colors.red,
          onReport: () => _showHAIReportForm(context, 'CLABSI'),
        ),
        _buildHAITypeCard(
          infection: 'Catheter-Associated Urinary Tract Infection (CAUTI)',
          description: 'UTI in patients with urinary catheter',
          icon: Icons.local_hospital,
          color: Colors.orange,
          onReport: () => _showHAIReportForm(context, 'CAUTI'),
        ),
        _buildHAITypeCard(
          infection: 'Surgical Site Infection (SSI)',
          description: 'Infection occurring after surgery',
          icon: Icons.healing,
          color: Colors.purple,
          onReport: () => _showHAIReportForm(context, 'SSI'),
        ),
        _buildHAITypeCard(
          infection: 'Ventilator-Associated Pneumonia (VAP)',
          description: 'Pneumonia in mechanically ventilated patients',
          icon: Icons.air,
          color: Colors.blue,
          onReport: () => _showHAIReportForm(context, 'VAP'),
        ),
        _buildHAITypeCard(
          infection: 'Clostridioides difficile Infection (CDI)',
          description: 'C. diff infection causing diarrhea',
          icon: Icons.coronavirus,
          color: Colors.brown,
          onReport: () => _showHAIReportForm(context, 'CDI'),
        ),
        _buildHAITypeCard(
          infection: 'Multidrug-Resistant Organism (MDRO)',
          description: 'Infections with antibiotic-resistant bacteria',
          icon: Icons.bug_report,
          color: Colors.red.shade900,
          onReport: () => _showHAIReportForm(context, 'MDRO'),
        ),

        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('hai_surveillance')
              .where('facilityId', isEqualTo: widget.facilityId)
              .orderBy('reportedDate', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final records = snapshot.data?.docs ?? [];

            if (records.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No HAI cases reported'),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent HAI Cases',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...records.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildHAICaseCard(data);
                }),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'HAI Surveillance Statistics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatItem('This Month', '0', Colors.blue)),
                Expanded(
                  child: _buildStatItem('This Quarter', '0', Colors.orange),
                ),
                Expanded(child: _buildStatItem('This Year', '0', Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildHAITypeCard({
    required String infection,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onReport,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          infection,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        trailing: IconButton(
          icon: Icon(Icons.add_circle, color: color),
          onPressed: onReport,
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildHAICaseCard(Map<String, dynamic> data) {
    final infection = data['infectionType'] ?? 'Unknown';
    final date = (data['reportedDate'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          infection,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          date != null ? DateFormat('MMM d, y').format(date) : 'Unknown date',
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  // Hand Hygiene Surveillance Tab
  Widget _buildHandHygieneTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
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
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'WHO 5 Moments for Hand Hygiene',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMomentItem('1. Before touching a patient'),
              _buildMomentItem('2. Before clean/aseptic procedures'),
              _buildMomentItem('3. After body fluid exposure risk'),
              _buildMomentItem('4. After touching a patient'),
              _buildMomentItem('5. After touching patient surroundings'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: () => _showHandHygieneObservationForm(context),
          icon: const Icon(Icons.add),
          label: const Text('New Hand Hygiene Observation'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),

        const SizedBox(height: 20),
        const Text(
          'Hand Hygiene Compliance',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildComplianceRow('Today', '0%', Colors.grey),
                const Divider(),
                _buildComplianceRow('This Week', '0%', Colors.grey),
                const Divider(),
                _buildComplianceRow('This Month', '0%', Colors.grey),
                const Divider(),
                _buildComplianceRow('Target', '95%', Colors.green),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('hand_hygiene_observations')
              .where('facilityId', isEqualTo: widget.facilityId)
              .orderBy('observationDate', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final observations = snapshot.data?.docs ?? [];

            if (observations.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No observations recorded'),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Observations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...observations.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final compliant = data['compliant'] as bool? ?? false;
                  final moment = data['moment'] ?? 'Unknown';
                  final date = (data['observationDate'] as Timestamp?)
                      ?.toDate();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        compliant ? Icons.check_circle : Icons.cancel,
                        color: compliant ? Colors.green : Colors.red,
                      ),
                      title: Text(moment),
                      subtitle: Text(
                        date != null
                            ? DateFormat('MMM d, y HH:mm').format(date)
                            : 'Unknown',
                      ),
                      trailing: Text(
                        compliant ? 'Compliant' : 'Non-compliant',
                        style: TextStyle(
                          color: compliant ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMomentItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildComplianceRow(String period, String percentage, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(period, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(
          percentage,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
      ],
    );
  }

  // Outbreak Investigation Tab
  Widget _buildOutbreakInvestigationTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.purple.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Hospital Outbreak Investigation',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Investigation of unusual increase in infections within the facility',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Outbreak Investigation Steps',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        _buildOutbreakStepCard(
          step: '1',
          title: 'Verify Outbreak',
          description: 'Confirm increase above baseline',
          icon: Icons.check_circle_outline,
          color: Colors.blue,
        ),
        _buildOutbreakStepCard(
          step: '2',
          title: 'Define Cases',
          description: 'Establish case definition',
          icon: Icons.description,
          color: Colors.green,
        ),
        _buildOutbreakStepCard(
          step: '3',
          title: 'Case Finding',
          description: 'Active surveillance for cases',
          icon: Icons.search,
          color: Colors.orange,
        ),
        _buildOutbreakStepCard(
          step: '4',
          title: 'Describe Outbreak',
          description: 'Time, place, and person',
          icon: Icons.analytics,
          color: Colors.purple,
        ),
        _buildOutbreakStepCard(
          step: '5',
          title: 'Develop Hypothesis',
          description: 'Identify source and mode of transmission',
          icon: Icons.lightbulb,
          color: Colors.amber,
        ),
        _buildOutbreakStepCard(
          step: '6',
          title: 'Control Measures',
          description: 'Implement infection control',
          icon: Icons.shield,
          color: Colors.red,
        ),
        _buildOutbreakStepCard(
          step: '7',
          title: 'Communicate',
          description: 'Report findings and recommendations',
          icon: Icons.campaign,
          color: Colors.teal,
        ),

        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => _showOutbreakReportForm(context),
          icon: const Icon(Icons.warning),
          label: const Text('Report Outbreak'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade700,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),

        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('outbreak_investigations')
              .where('facilityId', isEqualTo: widget.facilityId)
              .orderBy('reportedDate', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final outbreaks = snapshot.data?.docs ?? [];

            if (outbreaks.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No outbreaks reported'),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Outbreak Reports',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...outbreaks.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final infection = data['infectionType'] ?? 'Unknown';
                  final cases = data['numberOfCases'] ?? 0;
                  final status = data['status'] ?? 'Active';
                  final date = (data['reportedDate'] as Timestamp?)?.toDate();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        Icons.warning,
                        color: status == 'Active' ? Colors.red : Colors.grey,
                      ),
                      title: Text(
                        infection,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cases: $cases'),
                          if (date != null)
                            Text(DateFormat('MMM d, y').format(date)),
                        ],
                      ),
                      trailing: Chip(
                        label: Text(
                          status,
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: status == 'Active'
                            ? Colors.red.shade100
                            : Colors.grey.shade200,
                      ),
                      isThreeLine: true,
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildOutbreakStepCard({
    required String step,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Text(
            step,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: Icon(icon, color: color),
      ),
    );
  }

  // IPC Guidelines Tab
  Widget _buildIPCGuidelinesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'WHO IPC Core Components',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        _buildGuidelineCard(
          title: '1. IPC Programs',
          description: 'Dedicated IPC team with clear objectives',
          icon: Icons.groups,
          color: Colors.blue,
        ),
        _buildGuidelineCard(
          title: '2. IPC Guidelines',
          description: 'Evidence-based standards and protocols',
          icon: Icons.description,
          color: Colors.green,
        ),
        _buildGuidelineCard(
          title: '3. Education & Training',
          description: 'Regular training for all healthcare workers',
          icon: Icons.school,
          color: Colors.orange,
        ),
        _buildGuidelineCard(
          title: '4. Surveillance',
          description: 'Systematic collection and analysis of HAI data',
          icon: Icons.analytics,
          color: Colors.purple,
        ),
        _buildGuidelineCard(
          title: '5. Multimodal Strategies',
          description: 'Bundle approach to IPC implementation',
          icon: Icons.grid_view,
          color: Colors.red,
        ),
        _buildGuidelineCard(
          title: '6. Monitoring & Feedback',
          description: 'Regular audit and feedback mechanisms',
          icon: Icons.feedback,
          color: Colors.teal,
        ),
        _buildGuidelineCard(
          title: '7. Workload & Staffing',
          description: 'Adequate staff-to-patient ratios',
          icon: Icons.people,
          color: Colors.indigo,
        ),
        _buildGuidelineCard(
          title: '8. Built Environment',
          description: 'Proper facility design and equipment',
          icon: Icons.business,
          color: Colors.brown,
        ),

        const SizedBox(height: 24),
        const Text(
          'Standard Precautions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        _buildPrecautionCard(
          title: 'Hand Hygiene',
          description: 'Most important measure to prevent transmission',
          icon: Icons.wash,
        ),
        _buildPrecautionCard(
          title: 'Personal Protective Equipment (PPE)',
          description: 'Gloves, gowns, masks, eye protection',
          icon: Icons.shield,
        ),
        _buildPrecautionCard(
          title: 'Respiratory Hygiene',
          description: 'Cough etiquette and source control',
          icon: Icons.air,
        ),
        _buildPrecautionCard(
          title: 'Environmental Cleaning',
          description: 'Regular cleaning and disinfection',
          icon: Icons.cleaning_services,
        ),
        _buildPrecautionCard(
          title: 'Injection Safety',
          description: 'Safe practices for injections',
          icon: Icons.medication,
        ),
        _buildPrecautionCard(
          title: 'Waste Management',
          description: 'Proper segregation and disposal',
          icon: Icons.delete,
        ),
      ],
    );
  }

  Widget _buildGuidelineCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
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
        isThreeLine: true,
      ),
    );
  }

  Widget _buildPrecautionCard({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue.shade700),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  // Form methods
  void _showHAIReportForm(BuildContext context, String infectionType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _HAIReportFormScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          staffName: widget.staffName,
          infectionType: infectionType,
        ),
      ),
    );
  }

  void _showHandHygieneObservationForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _HandHygieneObservationFormScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          staffName: widget.staffName,
        ),
      ),
    );
  }

  void _showOutbreakReportForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _OutbreakReportFormScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          staffName: widget.staffName,
        ),
      ),
    );
  }
}

// ===================== HAI REPORT FORM =====================

class _HAIReportFormScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final String infectionType;

  const _HAIReportFormScreen({
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    required this.infectionType,
  });

  @override
  State<_HAIReportFormScreen> createState() => _HAIReportFormScreenState();
}

class _HAIReportFormScreenState extends State<_HAIReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientIdController = TextEditingController();
  final _patientNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _symptomsController = TextEditingController();
  final _riskFactorsController = TextEditingController();
  final _interventionsController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedGender;
  String? _selectedDepartment;
  String? _selectedSeverity;
  DateTime? _onsetDate;
  DateTime? _admissionDate;
  String? _selectedDeviceType;
  int? _daysSinceAdmission;
  bool _labConfirmed = false;
  String? _organism;
  bool _isSubmitting = false;

  final List<String> _departments = [
    'Intensive Care Unit (ICU)',
    'Surgery Department',
    'Medical Ward',
    'Pediatric Ward',
    'Maternity Ward',
    'Emergency Department',
    'Dialysis Unit',
    'Burns Unit',
    'Oncology Unit',
  ];

  final List<String> _severityLevels = [
    'Mild',
    'Moderate',
    'Severe',
    'Critical',
  ];

  final Map<String, List<String>> _deviceTypes = {
    'CLABSI': [
      'Central Venous Catheter',
      'PICC Line',
      'Port-a-Cath',
      'Umbilical Catheter',
    ],
    'CAUTI': [
      'Indwelling Urinary Catheter',
      'Suprapubic Catheter',
      'Nephrostomy Tube',
    ],
    'VAP': ['Endotracheal Tube', 'Tracheostomy'],
    'SSI': [
      'Clean Surgery',
      'Clean-Contaminated',
      'Contaminated',
      'Dirty/Infected',
    ],
    'CDI': ['Recent Antibiotics', 'Immunosuppression', 'Advanced Age'],
    'MDRO': [
      'MRSA',
      'VRE',
      'ESBL',
      'CRE',
      'MDR Acinetobacter',
      'MDR Pseudomonas',
    ],
  };

  @override
  void dispose() {
    _patientIdController.dispose();
    _patientNameController.dispose();
    _ageController.dispose();
    _diagnosisController.dispose();
    _symptomsController.dispose();
    _riskFactorsController.dispose();
    _interventionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitHAIReport() async {
    if (!_formKey.currentState!.validate()) return;

    if (_onsetDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select onset date')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('hai_surveillance').add({
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityName,
        'infectionType': widget.infectionType,
        'patientId': _patientIdController.text.trim(),
        'patientName': _patientNameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()),
        'gender': _selectedGender,
        'department': _selectedDepartment,
        'severity': _selectedSeverity,
        'onsetDate': Timestamp.fromDate(_onsetDate!),
        'admissionDate': _admissionDate != null
            ? Timestamp.fromDate(_admissionDate!)
            : null,
        'daysSinceAdmission': _daysSinceAdmission,
        'deviceType': _selectedDeviceType,
        'diagnosis': _diagnosisController.text.trim(),
        'symptoms': _symptomsController.text.trim(),
        'riskFactors': _riskFactorsController.text.trim(),
        'labConfirmed': _labConfirmed,
        'organism': _organism,
        'interventions': _interventionsController.text.trim(),
        'notes': _notesController.text.trim(),
        'reportedBy': widget.staffName,
        'reportedById': widget.staffId,
        'reportedDate': FieldValue.serverTimestamp(),
        'status': 'Active',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('HAI case reported successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report ${widget.infectionType}'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Patient Information
            const Text(
              'Patient Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _patientIdController,
              decoration: const InputDecoration(
                labelText: 'Patient ID *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _patientNameController,
              decoration: const InputDecoration(
                labelText: 'Patient Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
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
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
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
                    items: ['Male', 'Female'].map((gender) {
                      return DropdownMenuItem(
                        value: gender,
                        child: Text(gender),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedGender = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _selectedDepartment,
              decoration: const InputDecoration(
                labelText: 'Department *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_hospital),
              ),
              items: _departments.map((dept) {
                return DropdownMenuItem(value: dept, child: Text(dept));
              }).toList(),
              onChanged: (value) => setState(() => _selectedDepartment = value),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            // Infection Details
            const Text(
              'Infection Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ListTile(
              title: const Text('Onset Date *'),
              subtitle: Text(
                _onsetDate != null
                    ? DateFormat('MMM d, y').format(_onsetDate!)
                    : 'Not selected',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _onsetDate = date);
              },
              tileColor: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 12),

            ListTile(
              title: const Text('Admission Date'),
              subtitle: Text(
                _admissionDate != null
                    ? DateFormat('MMM d, y').format(_admissionDate!)
                    : 'Not selected',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _onsetDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _admissionDate = date;
                    if (_onsetDate != null) {
                      _daysSinceAdmission = _onsetDate!.difference(date).inDays;
                    }
                  });
                }
              },
              tileColor: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 12),

            if (_daysSinceAdmission != null)
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Days since admission: $_daysSinceAdmission',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),

            if (_deviceTypes.containsKey(widget.infectionType))
              DropdownButtonFormField<String>(
                value: _selectedDeviceType,
                decoration: InputDecoration(
                  labelText: widget.infectionType == 'SSI'
                      ? 'Surgical Category *'
                      : widget.infectionType == 'CDI'
                      ? 'Risk Factor *'
                      : widget.infectionType == 'MDRO'
                      ? 'Organism Type *'
                      : 'Device Type *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.medical_services),
                ),
                items: _deviceTypes[widget.infectionType]!.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedDeviceType = value),
                validator: (value) => value == null ? 'Required' : null,
              ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _selectedSeverity,
              decoration: const InputDecoration(
                labelText: 'Severity *',
                border: OutlineInputBorder(),
              ),
              items: _severityLevels.map((severity) {
                return DropdownMenuItem(value: severity, child: Text(severity));
              }).toList(),
              onChanged: (value) => setState(() => _selectedSeverity = value),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _diagnosisController,
              decoration: const InputDecoration(
                labelText: 'Clinical Diagnosis *',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _symptomsController,
              decoration: const InputDecoration(
                labelText: 'Symptoms *',
                border: OutlineInputBorder(),
                hintText: 'Fever, chills, redness, swelling, etc.',
              ),
              maxLines: 3,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _riskFactorsController,
              decoration: const InputDecoration(
                labelText: 'Risk Factors',
                border: OutlineInputBorder(),
                hintText: 'Diabetes, immunosuppression, etc.',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Laboratory Confirmation
            const Text(
              'Laboratory Confirmation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Lab Confirmed'),
              subtitle: const Text('Culture or PCR positive'),
              value: _labConfirmed,
              onChanged: (value) => setState(() => _labConfirmed = value),
              tileColor: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 12),

            if (_labConfirmed)
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Organism Isolated *',
                  border: OutlineInputBorder(),
                  hintText: 'E.g., Staphylococcus aureus',
                ),
                onChanged: (value) => _organism = value,
                validator: (value) => _labConfirmed && (value?.isEmpty ?? true)
                    ? 'Required'
                    : null,
              ),
            const SizedBox(height: 24),

            // Management
            const Text(
              'Management',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _interventionsController,
              decoration: const InputDecoration(
                labelText: 'Interventions Taken',
                border: OutlineInputBorder(),
                hintText: 'Antibiotics, device removal, isolation, etc.',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitHAIReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Submit HAI Report',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== HAND HYGIENE OBSERVATION FORM =====================

class _HandHygieneObservationFormScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const _HandHygieneObservationFormScreen({
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<_HandHygieneObservationFormScreen> createState() =>
      _HandHygieneObservationFormScreenState();
}

class _HandHygieneObservationFormScreenState
    extends State<_HandHygieneObservationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _observedStaffController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedMoment;
  String? _selectedDepartment;
  String? _selectedStaffCategory;
  bool _compliant = false;
  String? _method;
  bool _isSubmitting = false;

  final List<String> _moments = [
    '1. Before touching a patient',
    '2. Before clean/aseptic procedures',
    '3. After body fluid exposure risk',
    '4. After touching a patient',
    '5. After touching patient surroundings',
  ];

  final List<String> _departments = [
    'Intensive Care Unit (ICU)',
    'Surgery Department',
    'Medical Ward',
    'Pediatric Ward',
    'Maternity Ward',
    'Emergency Department',
    'Outpatient Department',
  ];

  final List<String> _staffCategories = [
    'Doctor',
    'Nurse',
    'Lab Technician',
    'Pharmacist',
    'Support Staff',
  ];

  final List<String> _methods = [
    'Handwashing with soap and water',
    'Alcohol-based hand rub',
    'Not performed',
  ];

  @override
  void dispose() {
    _observedStaffController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitObservation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance
          .collection('hand_hygiene_observations')
          .add({
            'facilityId': widget.facilityId,
            'facilityName': widget.facilityName,
            'moment': _selectedMoment,
            'department': _selectedDepartment,
            'observedStaff': _observedStaffController.text.trim(),
            'staffCategory': _selectedStaffCategory,
            'compliant': _compliant,
            'method': _method,
            'notes': _notesController.text.trim(),
            'observedBy': widget.staffName,
            'observedById': widget.staffId,
            'observationDate': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Observation recorded successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hand Hygiene Observation'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Observe healthcare worker hand hygiene compliance at one of the 5 moments',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: _selectedMoment,
              decoration: const InputDecoration(
                labelText: 'WHO 5 Moment *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer),
              ),
              items: _moments.map((moment) {
                return DropdownMenuItem(value: moment, child: Text(moment));
              }).toList(),
              onChanged: (value) => setState(() => _selectedMoment = value),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _selectedDepartment,
              decoration: const InputDecoration(
                labelText: 'Department *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_hospital),
              ),
              items: _departments.map((dept) {
                return DropdownMenuItem(value: dept, child: Text(dept));
              }).toList(),
              onChanged: (value) => setState(() => _selectedDepartment = value),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _observedStaffController,
              decoration: const InputDecoration(
                labelText: 'Observed Staff Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _selectedStaffCategory,
              decoration: const InputDecoration(
                labelText: 'Staff Category *',
                border: OutlineInputBorder(),
              ),
              items: _staffCategories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: (value) =>
                  setState(() => _selectedStaffCategory = value),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 20),

            const Text(
              'Compliance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _method,
              decoration: const InputDecoration(
                labelText: 'Hand Hygiene Method *',
                border: OutlineInputBorder(),
              ),
              items: _methods.map((method) {
                return DropdownMenuItem(value: method, child: Text(method));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _method = value;
                  _compliant = value != 'Not performed';
                });
              },
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            Card(
              color: _compliant ? Colors.green.shade50 : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _compliant ? Icons.check_circle : Icons.cancel,
                      color: _compliant ? Colors.green : Colors.red,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _compliant ? 'COMPLIANT' : 'NON-COMPLIANT',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _compliant
                            ? Colors.green.shade900
                            : Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                hintText: 'Additional observations',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitObservation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Submit Observation',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== OUTBREAK REPORT FORM =====================

class _OutbreakReportFormScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const _OutbreakReportFormScreen({
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<_OutbreakReportFormScreen> createState() =>
      _OutbreakReportFormScreenState();
}

class _OutbreakReportFormScreenState extends State<_OutbreakReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberOfCasesController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _affectedAreasController = TextEditingController();
  final _riskFactorsController = TextEditingController();
  final _controlMeasuresController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedInfectionType;
  String? _selectedDepartment;
  DateTime? _outbreakStartDate;
  bool _isSubmitting = false;

  final List<String> _infectionTypes = [
    'CLABSI',
    'CAUTI',
    'VAP',
    'SSI',
    'Clostridioides difficile',
    'MRSA',
    'VRE',
    'Other MDRO',
    'Norovirus',
    'Influenza',
    'COVID-19',
    'Other',
  ];

  final List<String> _departments = [
    'Intensive Care Unit (ICU)',
    'Surgery Department',
    'Medical Ward',
    'Pediatric Ward',
    'Maternity Ward',
    'Emergency Department',
    'Multiple Departments',
  ];

  @override
  void dispose() {
    _numberOfCasesController.dispose();
    _descriptionController.dispose();
    _affectedAreasController.dispose();
    _riskFactorsController.dispose();
    _controlMeasuresController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitOutbreakReport() async {
    if (!_formKey.currentState!.validate()) return;

    if (_outbreakStartDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select outbreak start date')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance
          .collection('outbreak_investigations')
          .add({
            'facilityId': widget.facilityId,
            'facilityName': widget.facilityName,
            'infectionType': _selectedInfectionType,
            'department': _selectedDepartment,
            'numberOfCases': int.tryParse(_numberOfCasesController.text.trim()),
            'outbreakStartDate': Timestamp.fromDate(_outbreakStartDate!),
            'description': _descriptionController.text.trim(),
            'affectedAreas': _affectedAreasController.text.trim(),
            'riskFactors': _riskFactorsController.text.trim(),
            'controlMeasures': _controlMeasuresController.text.trim(),
            'notes': _notesController.text.trim(),
            'reportedBy': widget.staffName,
            'reportedById': widget.staffId,
            'reportedDate': FieldValue.serverTimestamp(),
            'status': 'Active',
            'investigationStep': 'Verification',
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Outbreak reported successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Outbreak'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.purple.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Report when there is an unusual increase in infections above baseline',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: _selectedInfectionType,
              decoration: const InputDecoration(
                labelText: 'Infection Type *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.coronavirus),
              ),
              items: _infectionTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) =>
                  setState(() => _selectedInfectionType = value),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _selectedDepartment,
              decoration: const InputDecoration(
                labelText: 'Primary Department Affected *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_hospital),
              ),
              items: _departments.map((dept) {
                return DropdownMenuItem(value: dept, child: Text(dept));
              }).toList(),
              onChanged: (value) => setState(() => _selectedDepartment = value),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _numberOfCasesController,
              decoration: const InputDecoration(
                labelText: 'Number of Cases *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            ListTile(
              title: const Text('Outbreak Start Date *'),
              subtitle: Text(
                _outbreakStartDate != null
                    ? DateFormat('MMM d, y').format(_outbreakStartDate!)
                    : 'Not selected',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _outbreakStartDate = date);
              },
              tileColor: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Outbreak Description *',
                border: OutlineInputBorder(),
                hintText: 'Describe the outbreak pattern and timeline',
              ),
              maxLines: 3,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _affectedAreasController,
              decoration: const InputDecoration(
                labelText: 'Affected Areas',
                border: OutlineInputBorder(),
                hintText: 'Wards, rooms, or units affected',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _riskFactorsController,
              decoration: const InputDecoration(
                labelText: 'Identified Risk Factors',
                border: OutlineInputBorder(),
                hintText:
                    'Common exposures, procedures, or environmental factors',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _controlMeasuresController,
              decoration: const InputDecoration(
                labelText: 'Control Measures Implemented',
                border: OutlineInputBorder(),
                hintText: 'Actions taken to control the outbreak',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitOutbreakReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Submit Outbreak Report',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
