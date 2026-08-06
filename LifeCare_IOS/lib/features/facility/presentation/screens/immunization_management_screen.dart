// Immunization Management Screen
// Follows Nigeria's National Routine Immunization Schedule and WHO Guidelines
// Reference: Nigeria National Routine Immunization Schedule (2023)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ImmunizationManagementScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const ImmunizationManagementScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<ImmunizationManagementScreen> createState() =>
      _ImmunizationManagementScreenState();
}

class _ImmunizationManagementScreenState
    extends State<ImmunizationManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _todayCount = 0;
  int _weekCount = 0;
  int _monthCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(const Duration(days: 7));
      final monthStart = DateTime(now.year, now.month, 1);

      final todaySnap = await FirebaseFirestore.instance
          .collection('immunization_records')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('dateAdministered', isGreaterThanOrEqualTo: todayStart)
          .get();

      final weekSnap = await FirebaseFirestore.instance
          .collection('immunization_records')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('dateAdministered', isGreaterThanOrEqualTo: weekStart)
          .get();

      final monthSnap = await FirebaseFirestore.instance
          .collection('immunization_records')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('dateAdministered', isGreaterThanOrEqualTo: monthStart)
          .get();

      if (mounted) {
        setState(() {
          _todayCount = todaySnap.docs.length;
          _weekCount = weekSnap.docs.length;
          _monthCount = monthSnap.docs.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading immunization statistics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Immunization Management'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Record'),
            Tab(text: 'Schedule'),
            Tab(text: 'Vaccines'),
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
                colors: [Colors.blue.shade700, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Expanded(child: _buildStatChip('Today', _todayCount)),
                Expanded(child: _buildStatChip('This Week', _weekCount)),
                Expanded(child: _buildStatChip('This Month', _monthCount)),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecordTab(),
                _buildScheduleTab(),
                _buildVaccinesTab(),
                _buildReportsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewImmunizationForm(context),
        backgroundColor: Colors.blue.shade700,
        icon: const Icon(Icons.add),
        label: const Text('New Record'),
      ),
    );
  }

  Widget _buildStatChip(String label, int count) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
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

  Widget _buildRecordTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('immunization_records')
          .where('facilityId', isEqualTo: widget.facilityId)
          .orderBy('dateAdministered', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data?.docs ?? [];

        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.vaccines, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No immunization records yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + to add a new record',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index].data() as Map<String, dynamic>;
            return _buildRecordCard(record);
          },
        );
      },
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final date = (record['dateAdministered'] as Timestamp?)?.toDate();
    final patientName = record['patientName'] ?? 'Unknown';
    final vaccine = record['vaccineName'] ?? 'Unknown vaccine';
    final age = record['patientAge'] ?? 'Unknown age';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(Icons.vaccines, color: Colors.blue.shade700),
        ),
        title: Text(
          patientName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Vaccine: $vaccine'),
            Text('Age: $age'),
            if (date != null)
              Text('Date: ${DateFormat('MMM d, y').format(date)}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            // Show options menu
          },
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildScheduleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nigeria National Routine Immunization Schedule',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildScheduleCard(
            age: 'At Birth',
            vaccines: [
              'BCG - 1 dose',
              'OPV-0 (Oral Polio Vaccine)',
              'HepB-0 (Hepatitis B)',
            ],
            color: Colors.pink,
          ),
          _buildScheduleCard(
            age: '6 Weeks',
            vaccines: [
              'OPV-1',
              'Pentavalent-1 (DPT-HepB-Hib)',
              'PCV-1 (Pneumococcal Conjugate)',
              'Rota-1 (Rotavirus)',
            ],
            color: Colors.purple,
          ),
          _buildScheduleCard(
            age: '10 Weeks',
            vaccines: [
              'OPV-2',
              'Pentavalent-2 (DPT-HepB-Hib)',
              'PCV-2',
              'Rota-2',
            ],
            color: Colors.indigo,
          ),
          _buildScheduleCard(
            age: '14 Weeks',
            vaccines: [
              'OPV-3',
              'Pentavalent-3 (DPT-HepB-Hib)',
              'PCV-3',
              'IPV (Inactivated Polio Vaccine)',
            ],
            color: Colors.blue,
          ),
          _buildScheduleCard(
            age: '6 Months',
            vaccines: ['Vitamin A - 100,000 IU'],
            color: Colors.orange,
          ),
          _buildScheduleCard(
            age: '9 Months',
            vaccines: ['Measles-1', 'Yellow Fever', 'MenA (Meningococcal A)'],
            color: Colors.teal,
          ),
          _buildScheduleCard(
            age: '12 Months',
            vaccines: ['Vitamin A - 200,000 IU (every 6 months until 5 years)'],
            color: Colors.orange,
          ),
          _buildScheduleCard(
            age: '15 Months',
            vaccines: ['Measles-2'],
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Text(
                      'Additional Notes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• HPV vaccine for girls at 9 years (2 doses, 6 months apart)\n'
                  '• Td (Tetanus-diphtheria) for pregnant women\n'
                  '• COVID-19 vaccines as per national guidelines\n'
                  '• Follow WHO recommendations for catch-up immunization',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard({
    required String age,
    required List<String> vaccines,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.schedule, color: color),
        ),
        title: Text(age, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${vaccines.length} vaccine(s)'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: vaccines.map((vaccine) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: color),
                      const SizedBox(width: 8),
                      Expanded(child: Text(vaccine)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaccinesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vaccine_inventory')
          .where('facilityId', isEqualTo: widget.facilityId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final vaccines = snapshot.data?.docs ?? [];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vaccines.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildVaccineStockHeader();
            }

            final vaccine = vaccines[index - 1].data() as Map<String, dynamic>;
            return _buildVaccineCard(vaccine);
          },
        );
      },
    );
  }

  Widget _buildVaccineStockHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
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
              Icon(Icons.inventory, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'Vaccine Stock Management',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Monitor vaccine stock levels, expiry dates, and cold chain compliance. '
            'Maintain proper storage conditions (2-8°C for most vaccines).',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildVaccineCard(Map<String, dynamic> vaccine) {
    final name = vaccine['name'] ?? 'Unknown';
    final stock = vaccine['stockLevel'] ?? 0;
    final expiry = (vaccine['expiryDate'] as Timestamp?)?.toDate();
    final isLowStock = stock < 10;
    final isExpiringSoon =
        expiry != null && expiry.difference(DateTime.now()).inDays < 30;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLowStock || isExpiringSoon
              ? Colors.red.shade100
              : Colors.green.shade100,
          child: Icon(
            Icons.medication,
            color: isLowStock || isExpiringSoon
                ? Colors.red.shade700
                : Colors.green.shade700,
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Stock: $stock doses'),
            if (expiry != null)
              Text('Expires: ${DateFormat('MMM d, y').format(expiry)}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLowStock)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'LOW',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (isExpiringSoon)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'EXPIRING',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Immunization Reports & Analytics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildReportCard(
            title: 'Coverage Report',
            description:
                'View immunization coverage by vaccine type and age group',
            icon: Icons.pie_chart,
            color: Colors.blue,
            onTap: () {
              _showCoverageReport(context);
            },
          ),
          _buildReportCard(
            title: 'Defaulters List',
            description: 'Children due or overdue for immunization',
            icon: Icons.warning_amber,
            color: Colors.orange,
            onTap: () {
              _showDefaultersList(context);
            },
          ),
          _buildReportCard(
            title: 'Monthly Summary',
            description: 'Total immunizations administered this month',
            icon: Icons.calendar_month,
            color: Colors.green,
            onTap: () {
              _showMonthlySummary(context);
            },
          ),
          _buildReportCard(
            title: 'Cold Chain Monitoring',
            description: 'Temperature logs and cold chain compliance',
            icon: Icons.thermostat,
            color: Colors.purple,
            onTap: () {
              _showColdChainMonitoring(context);
            },
          ),
          _buildReportCard(
            title: 'Adverse Events',
            description:
                'Report and track adverse events following immunization (AEFI)',
            icon: Icons.health_and_safety,
            color: Colors.red,
            onTap: () {
              _showAdverseEvents(context);
            },
          ),
          _buildReportCard(
            title: 'Stock Reports',
            description: 'Vaccine stock levels, consumption, and wastage',
            icon: Icons.inventory_2,
            color: Colors.teal,
            onTap: () {
              _showStockReports(context);
            },
          ),
        ],
      ),
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

  void _showNewImmunizationForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ImmunizationForm(
        facilityId: widget.facilityId,
        facilityName: widget.facilityName,
        staffId: widget.staffId,
        staffName: widget.staffName,
      ),
    );
  }

  // Report Methods
  void _showCoverageReport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _CoverageReportView(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showDefaultersList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _DefaultersListView(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showMonthlySummary(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _MonthlySummaryView(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showColdChainMonitoring(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _ColdChainMonitoringView(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showAdverseEvents(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _AdverseEventsView(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showStockReports(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _StockReportsView(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

// Immunization Form Widget
class _ImmunizationForm extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const _ImmunizationForm({
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<_ImmunizationForm> createState() => _ImmunizationFormState();
}

class _ImmunizationFormState extends State<_ImmunizationForm> {
  final _formKey = GlobalKey<FormState>();
  final _patientNameController = TextEditingController();
  final _patientIdController = TextEditingController();
  final _caregiverNameController = TextEditingController();
  final _caregiverPhoneController = TextEditingController();

  String? _selectedVaccine;
  String? _selectedAgeGroup;
  DateTime? _dateOfBirth;
  final DateTime _dateAdministered = DateTime.now();
  String? _batchNumber;
  String? _manufacturer;
  String? _administrationSite;
  String? _routeOfAdministration;
  bool _isSubmitting = false;

  final List<String> _vaccines = [
    'BCG',
    'OPV (Oral Polio)',
    'IPV (Inactivated Polio)',
    'Pentavalent (DPT-HepB-Hib)',
    'PCV (Pneumococcal)',
    'Rotavirus',
    'Measles',
    'Yellow Fever',
    'MenA (Meningococcal)',
    'Hepatitis B',
    'Vitamin A',
    'HPV',
    'Td (Tetanus-diphtheria)',
  ];

  final List<String> _ageGroups = [
    'At Birth',
    '6 Weeks',
    '10 Weeks',
    '14 Weeks',
    '6 Months',
    '9 Months',
    '12 Months',
    '15 Months',
    'Other',
  ];

  final List<String> _administrationSites = [
    'Left arm (deltoid)',
    'Right arm (deltoid)',
    'Left thigh (anterolateral)',
    'Right thigh (anterolateral)',
    'Oral',
  ];

  final List<String> _routes = [
    'Intramuscular (IM)',
    'Subcutaneous (SC)',
    'Intradermal (ID)',
    'Oral',
  ];

  @override
  void dispose() {
    _patientNameController.dispose();
    _patientIdController.dispose();
    _caregiverNameController.dispose();
    _caregiverPhoneController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('immunization_records').add({
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityName,
        'staffId': widget.staffId,
        'staffName': widget.staffName,
        'patientName': _patientNameController.text.trim(),
        'patientId': _patientIdController.text.trim(),
        'patientAge': _selectedAgeGroup,
        'dateOfBirth': _dateOfBirth,
        'caregiverName': _caregiverNameController.text.trim(),
        'caregiverPhone': _caregiverPhoneController.text.trim(),
        'vaccineName': _selectedVaccine,
        'dateAdministered': _dateAdministered,
        'batchNumber': _batchNumber,
        'manufacturer': _manufacturer,
        'administrationSite': _administrationSite,
        'routeOfAdministration': _routeOfAdministration,
        'recordedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Immunization record saved successfully'),
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
                  color: Colors.blue.shade700,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.vaccines, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'New Immunization Record',
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
                      TextFormField(
                        controller: _patientIdController,
                        decoration: const InputDecoration(
                          labelText: 'Patient ID / Card Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedAgeGroup,
                        decoration: const InputDecoration(
                          labelText: 'Age Group *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.cake),
                        ),
                        items: _ageGroups.map((age) {
                          return DropdownMenuItem(value: age, child: Text(age));
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedAgeGroup = value);
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select age group';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _caregiverNameController,
                        decoration: const InputDecoration(
                          labelText: 'Caregiver/Parent Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.family_restroom),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _caregiverPhoneController,
                        decoration: const InputDecoration(
                          labelText: 'Caregiver Phone Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Vaccination Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedVaccine,
                        decoration: const InputDecoration(
                          labelText: 'Vaccine *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.vaccines),
                        ),
                        items: _vaccines.map((vaccine) {
                          return DropdownMenuItem(
                            value: vaccine,
                            child: Text(vaccine),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedVaccine = value);
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select vaccine';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _administrationSite,
                        decoration: const InputDecoration(
                          labelText: 'Administration Site *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        items: _administrationSites.map((site) {
                          return DropdownMenuItem(
                            value: site,
                            child: Text(site),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _administrationSite = value);
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select administration site';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _routeOfAdministration,
                        decoration: const InputDecoration(
                          labelText: 'Route of Administration *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.route),
                        ),
                        items: _routes.map((route) {
                          return DropdownMenuItem(
                            value: route,
                            child: Text(route),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _routeOfAdministration = value);
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select route';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Additional Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _batchNumber,
                        decoration: const InputDecoration(
                          labelText: 'Batch/Lot Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.qr_code),
                        ),
                        onChanged: (value) => _batchNumber = value,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _manufacturer,
                        decoration: const InputDecoration(
                          labelText: 'Manufacturer',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                        onChanged: (value) => _manufacturer = value,
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
                              : const Icon(Icons.save),
                          label: Text(
                            _isSubmitting ? 'Saving...' : 'Save Record',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
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

// Coverage Report View
class _CoverageReportView extends StatelessWidget {
  final String facilityId;
  final String facilityName;
  final ScrollController scrollController;

  const _CoverageReportView({
    required this.facilityId,
    required this.facilityName,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: Colors.blue.shade700, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Immunization Coverage Report',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  .collection('immunization_records')
                  .where('facilityId', isEqualTo: facilityId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final records = snapshot.data?.docs ?? [];

                // Calculate coverage by vaccine
                final Map<String, int> vaccineCounts = {};
                for (var doc in records) {
                  final data = doc.data() as Map<String, dynamic>;
                  final vaccine = data['vaccineName'] as String? ?? 'Unknown';
                  vaccineCounts[vaccine] = (vaccineCounts[vaccine] ?? 0) + 1;
                }

                final sortedVaccines = vaccineCounts.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                return ListView(
                  controller: scrollController,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Immunizations: ${records.length}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Facility: $facilityName',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Coverage by Vaccine Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...sortedVaccines.map((entry) {
                      final percentage = (entry.value / records.length * 100)
                          .toStringAsFixed(1);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              '${entry.value}',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(entry.key),
                          trailing: Text(
                            '$percentage%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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
}

// Defaulters List View
class _DefaultersListView extends StatelessWidget {
  final String facilityId;
  final String facilityName;
  final ScrollController scrollController;

  const _DefaultersListView({
    required this.facilityId,
    required this.facilityName,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber,
                color: Colors.orange.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Immunization Defaulters',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  .collection('immunizations')
                  .where('facilityId', isEqualTo: facilityId)
                  .where('status', isEqualTo: 'scheduled')
                  .where('scheduledDate', isLessThan: now)
                  .orderBy('scheduledDate')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final defaulters = snapshot.data?.docs ?? [];

                if (defaulters.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 64, color: Colors.green),
                        SizedBox(height: 16),
                        Text(
                          'No defaulters found!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'All children are up to date with their immunizations.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  controller: scrollController,
                  children: [
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${defaulters.length} children are overdue for immunization',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...defaulters.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final childName =
                          data['childName'] as String? ?? 'Unknown';
                      final vaccineName =
                          data['vaccineName'] as String? ?? 'Unknown';
                      final scheduledDate =
                          (data['scheduledDate'] as Timestamp?)?.toDate();
                      final daysOverdue = scheduledDate != null
                          ? now.difference(scheduledDate).inDays
                          : 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.shade100,
                            child: Text(
                              '$daysOverdue',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(childName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Vaccine: $vaccineName'),
                              Text(
                                'Due: ${scheduledDate != null ? DateFormat('MMM dd, yyyy').format(scheduledDate) : 'Unknown'}',
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ],
                          ),
                          trailing: Text(
                            '$daysOverdue\ndays',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          isThreeLine: true,
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
}

// Monthly Summary View
class _MonthlySummaryView extends StatelessWidget {
  final String facilityId;
  final String facilityName;
  final ScrollController scrollController;

  const _MonthlySummaryView({
    required this.facilityId,
    required this.facilityName,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month,
                color: Colors.green.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Monthly Summary - ${DateFormat('MMMM yyyy').format(now)}',
                  style: const TextStyle(
                    fontSize: 20,
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
                  .collection('immunization_records')
                  .where('facilityId', isEqualTo: facilityId)
                  .where('dateAdministered', isGreaterThanOrEqualTo: monthStart)
                  .where('dateAdministered', isLessThanOrEqualTo: monthEnd)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final records = snapshot.data?.docs ?? [];

                // Group by date
                final Map<String, int> dailyCounts = {};
                for (var doc in records) {
                  final data = doc.data() as Map<String, dynamic>;
                  final date = (data['dateAdministered'] as Timestamp?)
                      ?.toDate();
                  if (date != null) {
                    final dateKey = DateFormat('yyyy-MM-dd').format(date);
                    dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
                  }
                }

                return ListView(
                  controller: scrollController,
                  children: [
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              '${records.length}',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const Text(
                              'Total Immunizations This Month',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Daily Breakdown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...dailyCounts.entries.map((entry) {
                      final date = DateTime.parse(entry.key);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: Text(
                              '${entry.value}',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(DateFormat('EEEE, MMM dd').format(date)),
                          trailing: Text(
                            '${entry.value} doses',
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
}

// Cold Chain Monitoring View
class _ColdChainMonitoringView extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final ScrollController scrollController;

  const _ColdChainMonitoringView({
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.scrollController,
  });

  @override
  State<_ColdChainMonitoringView> createState() =>
      _ColdChainMonitoringViewState();
}

class _ColdChainMonitoringViewState extends State<_ColdChainMonitoringView> {
  final _formKey = GlobalKey<FormState>();
  double _temperature = 4.0;
  String _location = 'Main Refrigerator';
  bool _isSubmitting = false;

  Future<void> _logTemperature() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('cold_chain_logs').add({
        'facilityId': widget.facilityId,
        'temperature': _temperature,
        'location': _location,
        'recordedBy': widget.staffId,
        'recordedAt': FieldValue.serverTimestamp(),
        'isCompliant': _temperature >= 2.0 && _temperature <= 8.0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Temperature logged successfully')),
        );
        _formKey.currentState!.reset();
        setState(() => _temperature = 4.0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.thermostat, color: Colors.purple.shade700, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Cold Chain Monitoring',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          Form(
            key: _formKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Log Temperature',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _temperature.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Temperature (°C)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.thermostat),
                        helperText: 'Recommended: 2°C - 8°C',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter temperature';
                        }
                        final temp = double.tryParse(value);
                        if (temp == null) return 'Invalid temperature';
                        return null;
                      },
                      onChanged: (value) {
                        final temp = double.tryParse(value);
                        if (temp != null) setState(() => _temperature = temp);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _location,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Main Refrigerator',
                          child: Text('Main Refrigerator'),
                        ),
                        DropdownMenuItem(
                          value: 'Backup Refrigerator',
                          child: Text('Backup Refrigerator'),
                        ),
                        DropdownMenuItem(
                          value: 'Cold Box',
                          child: Text('Cold Box'),
                        ),
                        DropdownMenuItem(
                          value: 'Vaccine Carrier',
                          child: Text('Vaccine Carrier'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _location = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _logTemperature,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _isSubmitting ? 'Logging...' : 'Log Temperature',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recent Logs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cold_chain_logs')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .orderBy('recordedAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final logs = snapshot.data?.docs ?? [];

                if (logs.isEmpty) {
                  return const Center(child: Text('No temperature logs yet'));
                }

                return ListView.builder(
                  controller: widget.scrollController,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final data = logs[index].data() as Map<String, dynamic>;
                    final temperature = data['temperature'] as double? ?? 0.0;
                    final location = data['location'] as String? ?? 'Unknown';
                    final isCompliant = data['isCompliant'] as bool? ?? false;
                    final recordedAt = (data['recordedAt'] as Timestamp?)
                        ?.toDate();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCompliant
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          child: Icon(
                            isCompliant ? Icons.check : Icons.warning,
                            color: isCompliant
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                        title: Text('$temperature°C'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(location),
                            if (recordedAt != null)
                              Text(
                                DateFormat(
                                  'MMM dd, yyyy HH:mm',
                                ).format(recordedAt),
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Text(
                          isCompliant ? 'OK' : 'Alert',
                          style: TextStyle(
                            color: isCompliant ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        isThreeLine: true,
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
}

// Adverse Events View
class _AdverseEventsView extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final ScrollController scrollController;

  const _AdverseEventsView({
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.scrollController,
  });

  @override
  State<_AdverseEventsView> createState() => _AdverseEventsViewState();
}

class _AdverseEventsViewState extends State<_AdverseEventsView> {
  final _formKey = GlobalKey<FormState>();
  String _childName = '';
  String _vaccineName = '';
  String _eventType = 'Mild';
  String _description = '';
  bool _isSubmitting = false;

  Future<void> _reportEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('adverse_events').add({
        'facilityId': widget.facilityId,
        'childName': _childName,
        'vaccineName': _vaccineName,
        'eventType': _eventType,
        'description': _description,
        'reportedBy': widget.staffId,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'reported',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adverse event reported successfully')),
        );
        _formKey.currentState!.reset();
        setState(() {
          _childName = '';
          _vaccineName = '';
          _eventType = 'Mild';
          _description = '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.health_and_safety,
                color: Colors.red.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Adverse Events (AEFI)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          Form(
            key: _formKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report Adverse Event',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Child Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required' : null,
                      onChanged: (value) => _childName = value,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Vaccine Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.vaccines),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required' : null,
                      onChanged: (value) => _vaccineName = value,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _eventType,
                      decoration: const InputDecoration(
                        labelText: 'Severity',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.priority_high),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Mild', child: Text('Mild')),
                        DropdownMenuItem(
                          value: 'Moderate',
                          child: Text('Moderate'),
                        ),
                        DropdownMenuItem(
                          value: 'Severe',
                          child: Text('Severe'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _eventType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required' : null,
                      onChanged: (value) => _description = value,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _reportEvent,
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
                          _isSubmitting ? 'Reporting...' : 'Report Event',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recent Reports',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('adverse_events')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .orderBy('reportedAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final events = snapshot.data?.docs ?? [];

                if (events.isEmpty) {
                  return const Center(
                    child: Text('No adverse events reported'),
                  );
                }

                return ListView.builder(
                  controller: widget.scrollController,
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final data = events[index].data() as Map<String, dynamic>;
                    final childName = data['childName'] as String? ?? 'Unknown';
                    final vaccineName =
                        data['vaccineName'] as String? ?? 'Unknown';
                    final eventType = data['eventType'] as String? ?? 'Unknown';
                    final description = data['description'] as String? ?? '';
                    final reportedAt = (data['reportedAt'] as Timestamp?)
                        ?.toDate();

                    Color severityColor = Colors.grey;
                    if (eventType == 'Mild') {
                      severityColor = Colors.yellow.shade700;
                    }
                    if (eventType == 'Moderate') {
                      severityColor = Colors.orange.shade700;
                    }
                    if (eventType == 'Severe') {
                      severityColor = Colors.red.shade700;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: severityColor.withOpacity(0.2),
                          child: Icon(Icons.warning, color: severityColor),
                        ),
                        title: Text(childName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Vaccine: $vaccineName'),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (reportedAt != null)
                              Text(
                                DateFormat('MMM dd, yyyy').format(reportedAt),
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Chip(
                          label: Text(eventType),
                          backgroundColor: severityColor.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: severityColor,
                            fontSize: 12,
                          ),
                        ),
                        isThreeLine: true,
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
}

// Stock Reports View
class _StockReportsView extends StatelessWidget {
  final String facilityId;
  final String facilityName;
  final ScrollController scrollController;

  const _StockReportsView({
    required this.facilityId,
    required this.facilityName,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2, color: Colors.teal.shade700, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Vaccine Stock Reports',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  .collection('vaccine_stock')
                  .where('facilityId', isEqualTo: facilityId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final stocks = snapshot.data?.docs ?? [];

                if (stocks.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No stock data available',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                int lowStock = 0;

                for (var doc in stocks) {
                  final data = doc.data() as Map<String, dynamic>;
                  final quantity = data['quantity'] as int? ?? 0;
                  final minQuantity = data['minQuantity'] as int? ?? 10;
                  if (quantity < minQuantity) lowStock++;
                }

                return ListView(
                  controller: scrollController,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: Colors.teal.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    '${stocks.length}',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal.shade700,
                                    ),
                                  ),
                                  const Text('Vaccine Types'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Card(
                            color: lowStock > 0
                                ? Colors.orange.shade50
                                : Colors.green.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    '$lowStock',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: lowStock > 0
                                          ? Colors.orange.shade700
                                          : Colors.green.shade700,
                                    ),
                                  ),
                                  const Text('Low Stock'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Stock Levels',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...stocks.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final vaccineName =
                          data['vaccineName'] as String? ?? 'Unknown';
                      final quantity = data['quantity'] as int? ?? 0;
                      final minQuantity = data['minQuantity'] as int? ?? 10;
                      final isLowStock = quantity < minQuantity;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isLowStock
                                ? Colors.orange.shade100
                                : Colors.green.shade100,
                            child: Icon(
                              isLowStock ? Icons.warning : Icons.check,
                              color: isLowStock
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                          title: Text(vaccineName),
                          subtitle: Text('Minimum: $minQuantity doses'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$quantity',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isLowStock
                                      ? Colors.orange
                                      : Colors.black,
                                ),
                              ),
                              const Text(
                                'doses',
                                style: TextStyle(fontSize: 12),
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
}
