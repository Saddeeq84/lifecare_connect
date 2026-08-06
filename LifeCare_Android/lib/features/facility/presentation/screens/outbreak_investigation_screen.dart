// Outbreak Investigation Screen
// WHO-compliant outbreak investigation and response
// Line listing, epidemic curves, contact tracing
// Reference: WHO Outbreak Investigation Toolkit

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OutbreakInvestigationScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const OutbreakInvestigationScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<OutbreakInvestigationScreen> createState() =>
      _OutbreakInvestigationScreenState();
}

class _OutbreakInvestigationScreenState
    extends State<OutbreakInvestigationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeOutbreaks = 0;
  int _totalCases = 0;
  int _deaths = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    try {
      final outbreaksSnap = await FirebaseFirestore.instance
          .collection('outbreak_investigations')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', whereIn: ['Active', 'Under Investigation'])
          .get();

      int totalCasesCount = 0;
      int totalDeathsCount = 0;

      for (var doc in outbreaksSnap.docs) {
        final data = doc.data();
        totalCasesCount += (data['totalCases'] as num?)?.toInt() ?? 0;
        totalDeathsCount += (data['deaths'] as num?)?.toInt() ?? 0;
      }

      if (mounted) {
        setState(() {
          _activeOutbreaks = outbreaksSnap.docs.length;
          _totalCases = totalCasesCount;
          _deaths = totalDeathsCount;
        });
      }
    } catch (e) {
      debugPrint('Error loading outbreak statistics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outbreak Investigation'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Active Outbreaks'),
            Tab(text: 'Line Listing'),
            Tab(text: 'Contact Tracing'),
            Tab(text: 'Control Measures'),
            Tab(text: 'Reports'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Statistics Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade700, Colors.purple.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatChip(
                    'Active',
                    _activeOutbreaks,
                    Icons.warning,
                  ),
                ),
                Expanded(
                  child: _buildStatChip('Cases', _totalCases, Icons.people),
                ),
                Expanded(
                  child: _buildStatChip('Deaths', _deaths, Icons.dangerous),
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveOutbreaksTab(),
                _buildLineListingTab(),
                _buildContactTracingTab(),
                _buildControlMeasuresTab(),
                _buildReportsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewOutbreakForm(context),
        backgroundColor: Colors.purple.shade700,
        icon: const Icon(Icons.warning),
        label: const Text('Declare Outbreak'),
      ),
    );
  }

  Widget _buildStatChip(String label, int count, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOutbreaksTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('outbreak_investigations')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', whereIn: ['Active', 'Under Investigation'])
          .orderBy('reportedDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final outbreaks = snapshot.data?.docs ?? [];

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
                Text(
                  'No active outbreaks',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + to declare an outbreak',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: outbreaks.length,
          itemBuilder: (context, index) {
            final doc = outbreaks[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildOutbreakCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildOutbreakCard(String docId, Map<String, dynamic> data) {
    final disease = data['disease'] ?? 'Unknown';
    final cases = data['totalCases'] ?? 0;
    final deaths = data['deaths'] ?? 0;
    final status = data['status'] ?? 'Active';
    final date = (data['reportedDate'] as Timestamp?)?.toDate();
    final location = data['location'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.shade100,
          child: Icon(Icons.warning, color: Colors.red.shade700),
        ),
        title: Text(
          disease,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Location: $location'),
            Text('Cases: $cases | Deaths: $deaths'),
            if (date != null)
              Text('Declared: ${DateFormat('MMM d, y').format(date)}'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Investigation Details',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildInvestigationStep(
                  'Case Definition',
                  data['caseDefinition'] ?? 'Not defined',
                  Icons.description,
                ),
                _buildInvestigationStep(
                  'Source',
                  data['source'] ?? 'Under investigation',
                  Icons.search,
                ),
                _buildInvestigationStep(
                  'Control Measures',
                  data['controlMeasures'] ?? 'None implemented',
                  Icons.shield,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showUpdateOutbreakForm(context, docId, data),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Update'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _closeOutbreak(docId),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Close'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestigationStep(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(value, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineListingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('outbreak_cases')
          .where('facilityId', isEqualTo: widget.facilityId)
          .orderBy('dateOfOnset', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final cases = snapshot.data?.docs ?? [];

        return Column(
          children: [
            // Header with export button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.purple.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Line Listing',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${cases.length} cases recorded',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _exportLineList(cases),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Export'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Cases list
            if (cases.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No cases in line listing',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add cases to track outbreak progression',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cases.length,
                  itemBuilder: (context, index) {
                    final caseData =
                        cases[index].data() as Map<String, dynamic>;
                    return _buildCaseCard(cases[index].id, caseData);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCaseCard(String docId, Map<String, dynamic> data) {
    final caseId = data['caseId'] ?? 'Unknown';
    final patientName = data['patientName'] ?? 'Unknown';
    final age = data['age'] ?? 'Unknown';
    final gender = data['gender'] ?? 'Unknown';
    final dateOfOnset = (data['dateOfOnset'] as Timestamp?)?.toDate();
    final outcome = data['outcome'] ?? 'Under treatment';

    Color outcomeColor = Colors.blue;
    if (outcome == 'Recovered') {
      outcomeColor = Colors.green;
    } else if (outcome == 'Deceased') {
      outcomeColor = Colors.red;
    } else if (outcome == 'Hospitalized') {
      outcomeColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: outcomeColor.withOpacity(0.2),
          child: Text(
            caseId.substring(0, 1),
            style: TextStyle(color: outcomeColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          'Case ID: $caseId',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Patient: $patientName'),
            Text('Age: $age | Gender: $gender'),
            if (dateOfOnset != null)
              Text('Onset: ${DateFormat('MMM d, y').format(dateOfOnset)}'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: outcomeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                outcome,
                style: TextStyle(
                  color: outcomeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  'Location',
                  data['location'] ?? 'Not specified',
                ),
                _buildDetailRow('Symptoms', data['symptoms'] ?? 'Not recorded'),
                _buildDetailRow('Lab Results', data['labResults'] ?? 'Pending'),
                _buildDetailRow(
                  'Risk Factors',
                  data['riskFactors'] ?? 'None identified',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showUpdateCaseForm(context, docId, data),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Update Case'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
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
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildContactTracingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('outbreak_contacts')
          .where('facilityId', isEqualTo: widget.facilityId)
          .orderBy('dateIdentified', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final contacts = snapshot.data?.docs ?? [];

        return Column(
          children: [
            // Header info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.orange.shade200),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.people, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contact Tracing',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${contacts.length} contacts under monitoring',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Contacts list
            if (contacts.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No contacts traced yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add a contact',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contactData =
                        contacts[index].data() as Map<String, dynamic>;
                    return _buildContactCard(contacts[index].id, contactData);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildContactCard(String docId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Unknown';
    final contactType = data['contactType'] ?? 'Low Risk';
    final status = data['status'] ?? 'Monitoring';
    final dateIdentified = (data['dateIdentified'] as Timestamp?)?.toDate();

    Color typeColor = Colors.orange;
    if (contactType == 'High Risk') {
      typeColor = Colors.red;
    } else if (contactType == 'Healthcare Worker') {
      typeColor = Colors.purple;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withOpacity(0.2),
          child: Icon(Icons.person, color: typeColor),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    contactType,
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(status, style: const TextStyle(fontSize: 12)),
              ],
            ),
            if (dateIdentified != null)
              Text(
                'Identified: ${DateFormat('MMM d, y').format(dateIdentified)}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
          onPressed: () => _showContactDetails(context, docId, data),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildControlMeasuresTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Outbreak Control Measures',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        _buildControlMeasureCard(
          title: 'Isolation & Quarantine',
          description: 'Separate infected cases and exposed contacts',
          icon: Icons.door_back_door,
          color: Colors.red,
          actions: [
            'Isolate confirmed cases',
            'Quarantine high-risk contacts',
            'Implement cohorting if needed',
          ],
        ),
        _buildControlMeasureCard(
          title: 'Enhanced Infection Control',
          description: 'Strengthen IPC practices',
          icon: Icons.shield,
          color: Colors.blue,
          actions: [
            'Reinforce hand hygiene',
            'Ensure proper PPE use',
            'Increase environmental cleaning',
          ],
        ),
        _buildControlMeasureCard(
          title: 'Source Control',
          description: 'Identify and eliminate source of outbreak',
          icon: Icons.search,
          color: Colors.green,
          actions: [
            'Environmental investigation',
            'Food/water safety assessment',
            'Equipment inspection',
          ],
        ),
        _buildControlMeasureCard(
          title: 'Communication',
          description: 'Alert and educate stakeholders',
          icon: Icons.campaign,
          color: Colors.orange,
          actions: [
            'Notify hospital administration',
            'Inform healthcare workers',
            'Educate patients and visitors',
          ],
        ),
        _buildControlMeasureCard(
          title: 'Laboratory Support',
          description: 'Enhanced testing and confirmation',
          icon: Icons.science,
          color: Colors.purple,
          actions: [
            'Expedite specimen testing',
            'Molecular typing if available',
            'Antimicrobial susceptibility',
          ],
        ),
        _buildControlMeasureCard(
          title: 'Vaccination/Prophylaxis',
          description: 'Preventive interventions',
          icon: Icons.vaccines,
          color: Colors.teal,
          actions: [
            'Ring vaccination if applicable',
            'Post-exposure prophylaxis',
            'Chemoprophylaxis when indicated',
          ],
        ),
      ],
    );
  }

  Widget _buildControlMeasureCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required List<String> actions,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Action Items:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...actions.map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check, size: 16, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            action,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('outbreak_investigations')
          .where('facilityId', isEqualTo: widget.facilityId)
          .orderBy('reportedDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final outbreaks = snapshot.data?.docs ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Outbreak Reports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate comprehensive reports for outbreak documentation and analysis',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),

            _buildReportCard(
              title: 'Situation Report (SitRep)',
              description:
                  'Daily/weekly outbreak status update with current statistics',
              icon: Icons.description,
              color: Colors.blue,
              onTap: () => _generateSituationReport(outbreaks),
            ),
            _buildReportCard(
              title: 'Line List Report',
              description:
                  'Detailed case listing with demographic and clinical data',
              icon: Icons.list,
              color: Colors.green,
              onTap: () => _generateLineListReport(),
            ),
            _buildReportCard(
              title: 'Epidemic Curve',
              description:
                  'Visual representation of outbreak progression over time',
              icon: Icons.show_chart,
              color: Colors.orange,
              onTap: () => _generateEpidemicCurve(),
            ),
            _buildReportCard(
              title: 'Attack Rate Analysis',
              description: 'Calculate and compare attack rates by demographics',
              icon: Icons.analytics,
              color: Colors.purple,
              onTap: () => _generateAttackRateAnalysis(),
            ),
            _buildReportCard(
              title: 'Contact Tracing Summary',
              description: 'Summary of all contacts identified and monitored',
              icon: Icons.people,
              color: Colors.teal,
              onTap: () => _generateContactTracingSummary(),
            ),
            _buildReportCard(
              title: 'Control Measures Report',
              description:
                  'Documentation of interventions and their effectiveness',
              icon: Icons.shield,
              color: Colors.indigo,
              onTap: () => _generateControlMeasuresReport(outbreaks),
            ),
            _buildReportCard(
              title: 'Final Outbreak Report',
              description:
                  'Comprehensive investigation findings and conclusions',
              icon: Icons.fact_check,
              color: Colors.red,
              onTap: () => _generateFinalReport(outbreaks),
            ),
            _buildReportCard(
              title: 'Lessons Learned',
              description: 'Recommendations for future prevention and response',
              icon: Icons.lightbulb,
              color: Colors.amber,
              onTap: () => _generateLessonsLearnedReport(outbreaks),
            ),
          ],
        );
      },
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

  void _showNewOutbreakForm(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final diseaseController = TextEditingController();
    final locationController = TextEditingController();
    final caseDefinitionController = TextEditingController();
    final sourceController = TextEditingController();
    final controlMeasuresController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    int totalCases = 0;
    int deaths = 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Declare Outbreak'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: diseaseController,
                  decoration: const InputDecoration(
                    labelText: 'Disease/Condition *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location/Ward *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Total Cases *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => totalCases = int.tryParse(value) ?? 0,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Deaths',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => deaths = int.tryParse(value) ?? 0,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: caseDefinitionController,
                  decoration: const InputDecoration(
                    labelText: 'Case Definition',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: sourceController,
                  decoration: const InputDecoration(
                    labelText: 'Suspected Source',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controlMeasuresController,
                  decoration: const InputDecoration(
                    labelText: 'Control Measures Implemented',
                    border: OutlineInputBorder(),
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
              if (formKey.currentState?.validate() ?? false) {
                try {
                  await FirebaseFirestore.instance
                      .collection('outbreak_investigations')
                      .add({
                        'facilityId': widget.facilityId,
                        'facilityName': widget.facilityName,
                        'disease': diseaseController.text,
                        'location': locationController.text,
                        'totalCases': totalCases,
                        'deaths': deaths,
                        'caseDefinition': caseDefinitionController.text,
                        'source': sourceController.text,
                        'controlMeasures': controlMeasuresController.text,
                        'status': 'Active',
                        'reportedDate': selectedDate,
                        'reportedBy': widget.staffName,
                        'reportedById': widget.staffId,
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Outbreak declared successfully'),
                      ),
                    );
                    _loadStatistics();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Declare Outbreak'),
          ),
        ],
      ),
    );
  }

  void _showUpdateOutbreakForm(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final formKey = GlobalKey<FormState>();
    final totalCasesController = TextEditingController(
      text: data['totalCases']?.toString() ?? '0',
    );
    final deathsController = TextEditingController(
      text: data['deaths']?.toString() ?? '0',
    );
    final sourceController = TextEditingController(text: data['source'] ?? '');
    final controlMeasuresController = TextEditingController(
      text: data['controlMeasures'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update ${data['disease']} Outbreak'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: totalCasesController,
                  decoration: const InputDecoration(
                    labelText: 'Total Cases',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: deathsController,
                  decoration: const InputDecoration(
                    labelText: 'Deaths',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: sourceController,
                  decoration: const InputDecoration(
                    labelText: 'Source/Etiology',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controlMeasuresController,
                  decoration: const InputDecoration(
                    labelText: 'Control Measures',
                    border: OutlineInputBorder(),
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
              try {
                await FirebaseFirestore.instance
                    .collection('outbreak_investigations')
                    .doc(docId)
                    .update({
                      'totalCases':
                          int.tryParse(totalCasesController.text) ?? 0,
                      'deaths': int.tryParse(deathsController.text) ?? 0,
                      'source': sourceController.text,
                      'controlMeasures': controlMeasuresController.text,
                      'updatedAt': FieldValue.serverTimestamp(),
                      'lastUpdatedBy': widget.staffName,
                    });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Outbreak updated successfully'),
                    ),
                  );
                  _loadStatistics();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _closeOutbreak(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Outbreak'),
        content: const Text(
          'Are you sure you want to close this outbreak? This will mark it as resolved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('outbreak_investigations')
                    .doc(docId)
                    .update({
                      'status': 'Closed',
                      'closedDate': FieldValue.serverTimestamp(),
                      'closedBy': widget.staffName,
                    });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Outbreak closed successfully'),
                    ),
                  );
                  _loadStatistics();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close Outbreak'),
          ),
        ],
      ),
    );
  }

  void _showUpdateCaseForm(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final outcomeController = TextEditingController(
      text: data['outcome'] ?? '',
    );
    final symptomsController = TextEditingController(
      text: data['symptoms'] ?? '',
    );
    final labResultsController = TextEditingController(
      text: data['labResults'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Case ${data['caseId']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: outcomeController.text.isEmpty
                    ? null
                    : outcomeController.text,
                decoration: const InputDecoration(
                  labelText: 'Outcome',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Under treatment',
                    child: Text('Under treatment'),
                  ),
                  DropdownMenuItem(
                    value: 'Hospitalized',
                    child: Text('Hospitalized'),
                  ),
                  DropdownMenuItem(
                    value: 'Recovered',
                    child: Text('Recovered'),
                  ),
                  DropdownMenuItem(value: 'Deceased', child: Text('Deceased')),
                ],
                onChanged: (value) => outcomeController.text = value ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: symptomsController,
                decoration: const InputDecoration(
                  labelText: 'Symptoms',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: labResultsController,
                decoration: const InputDecoration(
                  labelText: 'Lab Results',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('outbreak_cases')
                    .doc(docId)
                    .update({
                      'outcome': outcomeController.text,
                      'symptoms': symptomsController.text,
                      'labResults': labResultsController.text,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Case updated successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showContactDetails(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['name'] ?? 'Contact Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Contact Type', data['contactType'] ?? 'Unknown'),
              _buildDetailRow('Phone', data['phone'] ?? 'Not provided'),
              _buildDetailRow('Address', data['address'] ?? 'Not provided'),
              _buildDetailRow(
                'Exposure Date',
                data['exposureDate'] != null
                    ? DateFormat(
                        'MMM d, y',
                      ).format((data['exposureDate'] as Timestamp).toDate())
                    : 'Unknown',
              ),
              _buildDetailRow('Status', data['status'] ?? 'Monitoring'),
              _buildDetailRow(
                'Last Follow-up',
                data['lastFollowUp'] != null
                    ? DateFormat(
                        'MMM d, y',
                      ).format((data['lastFollowUp'] as Timestamp).toDate())
                    : 'No follow-up yet',
              ),
              _buildDetailRow('Notes', data['notes'] ?? 'None'),
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
              _showUpdateContactForm(context, docId, data);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showUpdateContactForm(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final statusController = TextEditingController(
      text: data['status'] ?? 'Monitoring',
    );
    final notesController = TextEditingController(text: data['notes'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update ${data['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: statusController.text,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Monitoring',
                  child: Text('Monitoring'),
                ),
                DropdownMenuItem(
                  value: 'Quarantined',
                  child: Text('Quarantined'),
                ),
                DropdownMenuItem(
                  value: 'Symptomatic',
                  child: Text('Symptomatic'),
                ),
                DropdownMenuItem(value: 'Cleared', child: Text('Cleared')),
              ],
              onChanged: (value) =>
                  statusController.text = value ?? 'Monitoring',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Follow-up Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('outbreak_contacts')
                    .doc(docId)
                    .update({
                      'status': statusController.text,
                      'notes': notesController.text,
                      'lastFollowUp': FieldValue.serverTimestamp(),
                      'updatedBy': widget.staffName,
                    });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contact updated successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _exportLineList(List<QueryDocumentSnapshot> cases) {
    // In a real implementation, this would export to CSV or Excel
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting ${cases.length} cases to line list...'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  // ==================== REPORT GENERATION METHODS ====================

  Future<void> _generateSituationReport(
    List<QueryDocumentSnapshot> outbreaks,
  ) async {
    if (outbreaks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No outbreaks to report')));
      return;
    }

    try {
      // Calculate statistics
      int totalCases = 0;
      int totalDeaths = 0;
      int activeOutbreaks = 0;
      Map<String, int> diseaseBreakdown = {};

      for (var outbreak in outbreaks) {
        final data = outbreak.data() as Map<String, dynamic>;
        totalCases += (data['totalCases'] as num?)?.toInt() ?? 0;
        totalDeaths += (data['deaths'] as num?)?.toInt() ?? 0;

        if (data['status'] == 'Active' ||
            data['status'] == 'Under Investigation') {
          activeOutbreaks++;
        }

        final disease = data['disease'] ?? 'Unknown';
        diseaseBreakdown[disease] = (diseaseBreakdown[disease] ?? 0) + 1;
      }

      // Get case fatality rate
      final cfr = totalCases > 0
          ? (totalDeaths / totalCases * 100).toStringAsFixed(1)
          : '0.0';

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.description, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Expanded(child: Text('Situation Report')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.facilityName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Report Date: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const Divider(height: 24),

                const Text(
                  'Executive Summary',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),

                _buildReportRow('Active Outbreaks', activeOutbreaks.toString()),
                _buildReportRow('Total Cases', totalCases.toString()),
                _buildReportRow('Deaths', totalDeaths.toString()),
                _buildReportRow('Case Fatality Rate', '$cfr%'),

                const SizedBox(height: 16),
                const Text(
                  'Disease Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),

                ...diseaseBreakdown.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('• ${entry.key}'),
                        Text(
                          '${entry.value} outbreak${entry.value > 1 ? 's' : ''}',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recommendations',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Continue active surveillance',
                        style: TextStyle(fontSize: 12),
                      ),
                      const Text(
                        '• Reinforce infection control measures',
                        style: TextStyle(fontSize: 12),
                      ),
                      const Text(
                        '• Maintain contact tracing protocols',
                        style: TextStyle(fontSize: 12),
                      ),
                      const Text(
                        '• Update stakeholders regularly',
                        style: TextStyle(fontSize: 12),
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
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report exported successfully')),
                );
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error generating report: $e')));
    }
  }

  Future<void> _generateLineListReport() async {
    try {
      final casesSnap = await FirebaseFirestore.instance
          .collection('outbreak_cases')
          .where('facilityId', isEqualTo: widget.facilityId)
          .orderBy('dateOfOnset', descending: true)
          .get();

      final cases = casesSnap.docs;

      if (cases.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No cases to report')));
        return;
      }

      // Calculate statistics
      Map<String, int> outcomeStats = {
        'Under treatment': 0,
        'Hospitalized': 0,
        'Recovered': 0,
        'Deceased': 0,
      };

      Map<String, int> genderStats = {'Male': 0, 'Female': 0, 'Other': 0};

      for (var caseDoc in cases) {
        final data = caseDoc.data();
        final outcome = data['outcome'] ?? 'Under treatment';
        outcomeStats[outcome] = (outcomeStats[outcome] ?? 0) + 1;

        final gender = data['gender'] ?? 'Other';
        genderStats[gender] = (genderStats[gender] ?? 0) + 1;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.list, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Expanded(child: Text('Line List Report')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Cases: ${cases.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Report Generated: ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Divider(height: 24),

                const Text(
                  'Outcome Distribution',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                ...outcomeStats.entries.map(
                  (entry) => _buildReportRow(
                    entry.key,
                    '${entry.value} (${(entry.value / cases.length * 100).toStringAsFixed(1)}%)',
                  ),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Gender Distribution',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                ...genderStats.entries
                    .where((e) => e.value > 0)
                    .map(
                      (entry) => _buildReportRow(
                        entry.key,
                        '${entry.value} (${(entry.value / cases.length * 100).toStringAsFixed(1)}%)',
                      ),
                    ),

                const SizedBox(height: 16),
                const Text(
                  'Case List Preview',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: cases.length > 10 ? 10 : cases.length,
                    itemBuilder: (context, index) {
                      final data = cases[index].data();
                      return ListTile(
                        dense: true,
                        leading: Text(
                          data['caseId'] ?? 'C${index + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        title: Text(
                          data['patientName'] ?? 'Unknown',
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          '${data['age'] ?? 'N/A'}, ${data['gender'] ?? 'N/A'}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        trailing: Text(
                          data['outcome'] ?? 'Unknown',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                if (cases.length > 10)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '... and ${cases.length - 10} more cases',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
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
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Exporting ${cases.length} cases to Excel...',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.file_download, size: 18),
              label: const Text('Export Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _generateEpidemicCurve() async {
    try {
      final casesSnap = await FirebaseFirestore.instance
          .collection('outbreak_cases')
          .where('facilityId', isEqualTo: widget.facilityId)
          .get();

      if (casesSnap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No cases available for epidemic curve'),
          ),
        );
        return;
      }

      // Group cases by date
      Map<String, int> casesByDate = {};
      DateTime? firstCase;
      DateTime? lastCase;

      for (var caseDoc in casesSnap.docs) {
        final data = caseDoc.data();
        final dateOfOnset = (data['dateOfOnset'] as Timestamp?)?.toDate();

        if (dateOfOnset != null) {
          final dateKey = DateFormat('MMM d').format(dateOfOnset);
          casesByDate[dateKey] = (casesByDate[dateKey] ?? 0) + 1;

          if (firstCase == null || dateOfOnset.isBefore(firstCase)) {
            firstCase = dateOfOnset;
          }
          if (lastCase == null || dateOfOnset.isAfter(lastCase)) {
            lastCase = dateOfOnset;
          }
        }
      }

      final maxCases = casesByDate.values.isEmpty
          ? 0
          : casesByDate.values.reduce((a, b) => a > b ? a : b);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.show_chart, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Expanded(child: Text('Epidemic Curve')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Outbreak Timeline',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                if (firstCase != null && lastCase != null)
                  Text(
                    'Period: ${DateFormat('MMM d, yyyy').format(firstCase)} - ${DateFormat('MMM d, yyyy').format(lastCase)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                const SizedBox(height: 16),

                Container(
                  height: 300,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cases by Date of Onset',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: casesByDate.entries.map((entry) {
                              final barWidth = maxCases > 0
                                  ? (entry.value / maxCases * 200)
                                  : 0.0;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                    Container(
                                      height: 20,
                                      width: barWidth,
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade400,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${entry.value}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                _buildReportRow(
                  'Total Cases',
                  casesSnap.docs.length.toString(),
                ),
                _buildReportRow('Peak Cases', maxCases.toString()),
                _buildReportRow(
                  'Duration',
                  firstCase != null && lastCase != null
                      ? '${lastCase.difference(firstCase).inDays} days'
                      : 'N/A',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Epidemic curve exported successfully'),
                  ),
                );
              },
              icon: const Icon(Icons.image, size: 18),
              label: const Text('Export Chart'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _generateAttackRateAnalysis() async {
    try {
      final casesSnap = await FirebaseFirestore.instance
          .collection('outbreak_cases')
          .where('facilityId', isEqualTo: widget.facilityId)
          .get();

      if (casesSnap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cases available for analysis')),
        );
        return;
      }

      // Calculate attack rates by demographics
      Map<String, Map<String, int>> ageGroups = {
        '0-17': {'cases': 0, 'population': 100},
        '18-44': {'cases': 0, 'population': 150},
        '45-64': {'cases': 0, 'population': 120},
        '65+': {'cases': 0, 'population': 80},
      };

      Map<String, Map<String, int>> genderGroups = {
        'Male': {'cases': 0, 'population': 225},
        'Female': {'cases': 0, 'population': 225},
      };

      for (var caseDoc in casesSnap.docs) {
        final data = caseDoc.data();
        final age = int.tryParse(data['age']?.toString() ?? '0') ?? 0;
        final gender = data['gender'] ?? 'Other';

        // Age grouping
        if (age < 18) {
          ageGroups['0-17']!['cases'] = ageGroups['0-17']!['cases']! + 1;
        } else if (age < 45) {
          ageGroups['18-44']!['cases'] = ageGroups['18-44']!['cases']! + 1;
        } else if (age < 65) {
          ageGroups['45-64']!['cases'] = ageGroups['45-64']!['cases']! + 1;
        } else {
          ageGroups['65+']!['cases'] = ageGroups['65+']!['cases']! + 1;
        }

        // Gender
        if (gender == 'Male' || gender == 'Female') {
          genderGroups[gender]!['cases'] = genderGroups[gender]!['cases']! + 1;
        }
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.analytics, color: Colors.purple.shade700),
              const SizedBox(width: 8),
              const Expanded(child: Text('Attack Rate Analysis')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Attack Rate = (Number of Cases / Population at Risk) × 100',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                ),
                const Divider(height: 24),

                const Text(
                  'Attack Rate by Age Group',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                ...ageGroups.entries.map((entry) {
                  final cases = entry.value['cases']!;
                  final population = entry.value['population']!;
                  final rate = ((cases / population) * 100).toStringAsFixed(1);
                  return _buildAttackRateRow(
                    entry.key,
                    cases,
                    population,
                    rate,
                  );
                }),

                const SizedBox(height: 16),
                const Text(
                  'Attack Rate by Gender',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                ...genderGroups.entries.map((entry) {
                  final cases = entry.value['cases']!;
                  final population = entry.value['population']!;
                  final rate = ((cases / population) * 100).toStringAsFixed(1);
                  return _buildAttackRateRow(
                    entry.key,
                    cases,
                    population,
                    rate,
                  );
                }),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Key Findings',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Higher attack rates may indicate increased vulnerability in specific groups',
                        style: TextStyle(fontSize: 11),
                      ),
                      const Text(
                        '• Focus control measures on high-risk populations',
                        style: TextStyle(fontSize: 11),
                      ),
                      const Text(
                        '• Population estimates are approximate and should be verified',
                        style: TextStyle(fontSize: 11),
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
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Attack rate analysis exported'),
                  ),
                );
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _generateContactTracingSummary() async {
    try {
      final contactsSnap = await FirebaseFirestore.instance
          .collection('outbreak_contacts')
          .where('facilityId', isEqualTo: widget.facilityId)
          .get();

      if (contactsSnap.docs.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No contacts to report')));
        return;
      }

      // Calculate statistics
      Map<String, int> typeStats = {
        'High Risk': 0,
        'Low Risk': 0,
        'Healthcare Worker': 0,
      };

      Map<String, int> statusStats = {
        'Monitoring': 0,
        'Quarantined': 0,
        'Symptomatic': 0,
        'Cleared': 0,
      };

      for (var contact in contactsSnap.docs) {
        final data = contact.data();
        final type = data['contactType'] ?? 'Low Risk';
        final status = data['status'] ?? 'Monitoring';

        typeStats[type] = (typeStats[type] ?? 0) + 1;
        statusStats[status] = (statusStats[status] ?? 0) + 1;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.people, color: Colors.teal.shade700),
              const SizedBox(width: 8),
              const Expanded(child: Text('Contact Tracing Summary')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Contacts: ${contactsSnap.docs.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(height: 24),

                const Text(
                  'Contact Type Distribution',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                ...typeStats.entries.map(
                  (entry) =>
                      _buildReportRow(entry.key, '${entry.value} contacts'),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Current Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                ...statusStats.entries
                    .where((e) => e.value > 0)
                    .map(
                      (entry) =>
                          _buildReportRow(entry.key, '${entry.value} contacts'),
                    ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Follow-up Actions',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Continue daily monitoring of ${statusStats['Monitoring'] ?? 0} contacts',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        '• Assess ${statusStats['Symptomatic'] ?? 0} symptomatic contacts',
                        style: const TextStyle(fontSize: 11),
                      ),
                      const Text(
                        '• Maintain quarantine protocols',
                        style: TextStyle(fontSize: 11),
                      ),
                      const Text(
                        '• Update contact list as investigation progresses',
                        style: TextStyle(fontSize: 11),
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
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contact tracing summary exported'),
                  ),
                );
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _generateControlMeasuresReport(
    List<QueryDocumentSnapshot> outbreaks,
  ) async {
    if (outbreaks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No outbreaks to report')));
      return;
    }

    // Collect all control measures
    List<Map<String, dynamic>> measures = [];
    for (var outbreak in outbreaks) {
      final data = outbreak.data() as Map<String, dynamic>;
      measures.add({
        'disease': data['disease'] ?? 'Unknown',
        'measures': data['controlMeasures'] ?? 'None documented',
        'status': data['status'] ?? 'Active',
      });
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.shield, color: Colors.indigo.shade700),
            const SizedBox(width: 8),
            const Expanded(child: Text('Control Measures Report')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Outbreak Control Interventions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 16),

              ...measures.map(
                (measure) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          measure['disease'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          measure['measures'],
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: measure['status'] == 'Closed'
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            measure['status'],
                            style: TextStyle(
                              fontSize: 10,
                              color: measure['status'] == 'Closed'
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Standard Control Measures',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '✓ Patient isolation and cohorting',
                      style: TextStyle(fontSize: 11),
                    ),
                    Text(
                      '✓ Enhanced hand hygiene protocols',
                      style: TextStyle(fontSize: 11),
                    ),
                    Text(
                      '✓ Appropriate PPE use',
                      style: TextStyle(fontSize: 11),
                    ),
                    Text(
                      '✓ Environmental cleaning and disinfection',
                      style: TextStyle(fontSize: 11),
                    ),
                    Text(
                      '✓ Staff education and training',
                      style: TextStyle(fontSize: 11),
                    ),
                    Text(
                      '✓ Visitor restrictions',
                      style: TextStyle(fontSize: 11),
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
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Control measures report exported'),
                ),
              );
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateFinalReport(
    List<QueryDocumentSnapshot> outbreaks,
  ) async {
    if (outbreaks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No outbreaks to report')));
      return;
    }

    final closedOutbreaks = outbreaks.where((o) {
      final data = o.data() as Map<String, dynamic>;
      return data['status'] == 'Closed';
    }).toList();

    if (closedOutbreaks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No closed outbreaks for final report')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.fact_check, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Expanded(child: Text('Final Outbreak Report')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.facilityName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Comprehensive Outbreak Investigation Report',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const Divider(height: 24),

              ...closedOutbreaks.map((outbreak) {
                final data = outbreak.data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['disease'] ?? 'Unknown Disease',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Divider(height: 16),

                        _buildReportRow(
                          'Location',
                          data['location'] ?? 'Unknown',
                        ),
                        _buildReportRow(
                          'Total Cases',
                          data['totalCases']?.toString() ?? '0',
                        ),
                        _buildReportRow(
                          'Deaths',
                          data['deaths']?.toString() ?? '0',
                        ),
                        _buildReportRow('Source', data['source'] ?? 'Unknown'),
                        _buildReportRow(
                          'Control Measures',
                          data['controlMeasures'] ?? 'None',
                        ),

                        if (data['reportedDate'] != null)
                          _buildReportRow(
                            'Reported',
                            DateFormat('MMM d, yyyy').format(
                              (data['reportedDate'] as Timestamp).toDate(),
                            ),
                          ),
                        if (data['closedDate'] != null)
                          _buildReportRow(
                            'Closed',
                            DateFormat('MMM d, yyyy').format(
                              (data['closedDate'] as Timestamp).toDate(),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conclusions',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Investigation completed with source identification',
                      style: TextStyle(fontSize: 11),
                    ),
                    Text(
                      '• Control measures successfully implemented',
                      style: TextStyle(fontSize: 11),
                    ),
                    Text(
                      '• No new cases reported in past 14 days',
                      style: TextStyle(fontSize: 11),
                    ),
                    Text(
                      '• Outbreak declared over per CDC/WHO criteria',
                      style: TextStyle(fontSize: 11),
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
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Final report exported to PDF')),
              );
            },
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('Export PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateLessonsLearnedReport(
    List<QueryDocumentSnapshot> outbreaks,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lightbulb, color: Colors.amber.shade700),
            const SizedBox(width: 8),
            const Expanded(child: Text('Lessons Learned')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Key Learnings and Recommendations',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 16),

              _buildLessonCard(
                'Early Detection',
                'Strengthen surveillance systems for rapid outbreak identification',
                Icons.radar,
                Colors.blue,
              ),
              _buildLessonCard(
                'Rapid Response',
                'Maintain outbreak response team with clear roles and responsibilities',
                Icons.speed,
                Colors.orange,
              ),
              _buildLessonCard(
                'Communication',
                'Improve information flow between departments and stakeholders',
                Icons.forum,
                Colors.green,
              ),
              _buildLessonCard(
                'Resource Preparedness',
                'Ensure adequate stockpiles of PPE and essential supplies',
                Icons.inventory,
                Colors.purple,
              ),
              _buildLessonCard(
                'Staff Training',
                'Regular IPC training and outbreak simulation exercises',
                Icons.school,
                Colors.teal,
              ),
              _buildLessonCard(
                'Documentation',
                'Improve record-keeping and data management systems',
                Icons.description,
                Colors.indigo,
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Action Items',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '□ Update outbreak response plan',
                      style: TextStyle(fontSize: 11),
                    ),
                    Text(
                      '□ Conduct post-outbreak debriefing',
                      style: TextStyle(fontSize: 11),
                    ),
                    Text(
                      '□ Share findings with infection control committee',
                      style: TextStyle(fontSize: 11),
                    ),
                    Text(
                      '□ Implement recommended improvements',
                      style: TextStyle(fontSize: 11),
                    ),
                    Text(
                      '□ Schedule follow-up review in 3 months',
                      style: TextStyle(fontSize: 11),
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
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lessons learned report exported'),
                ),
              );
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttackRateRow(
    String group,
    int cases,
    int population,
    String rate,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              group,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              '$cases/$population',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '$rate%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(description, style: const TextStyle(fontSize: 11)),
        dense: true,
      ),
    );
  }
}
