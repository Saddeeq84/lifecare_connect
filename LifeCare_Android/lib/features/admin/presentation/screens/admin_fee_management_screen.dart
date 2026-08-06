import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminFeeManagementScreen extends StatefulWidget {
  const AdminFeeManagementScreen({super.key});

  @override
  State<AdminFeeManagementScreen> createState() =>
      _AdminFeeManagementScreenState();
}

class _AdminFeeManagementScreenState extends State<AdminFeeManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _feeConfig = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadFeeConfiguration();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFeeConfiguration() async {
    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_configuration')
          .doc('fee_structure')
          .get();

      if (doc.exists) {
        setState(() {
          _feeConfig = doc.data() ?? {};
          _isLoading = false;
        });
      } else {
        // Create default configuration if doesn't exist
        await _createDefaultConfiguration();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load fee configuration: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createDefaultConfiguration() async {
    final defaultConfig = {
      // Appointment Fees (Doctor)
      'doctorFollowUp': 1500.0,
      'doctorGeneralConsultation': 3000.0,
      'doctorMentalHealth': 3000.0,
      'doctorEmergency': 5000.0,
      'doctorSpecialist': 5000.0,

      // Appointment Fees (CHW)
      'chwDoctorBooking': 2000.0,
      'patientCHWBooking': 1000.0,
      'chwFreeAppointmentQuota': 3,

      // Revenue Share Percentages
      'providerSharePercentage': 70.0,
      'adminSharePercentage': 30.0,

      // Remote Consultation Revenue Split
      'remoteDoctorSharePercentage': 70.0,
      'remoteFacilitySharePercentage': 30.0,

      // Currency
      'currency': 'NGN',
      'currencySymbol': '₦',

      // Metadata
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'version': 1,
    };

    await FirebaseFirestore.instance
        .collection('app_configuration')
        .doc('fee_structure')
        .set(defaultConfig);

    // Reload the data to get the actual Timestamp values instead of FieldValue
    await _loadFeeConfiguration();
  }

  Future<void> _updateFeeValue(String key, dynamic value) async {
    try {
      await FirebaseFirestore.instance
          .collection('app_configuration')
          .doc('fee_structure')
          .update({key: value, 'updatedAt': FieldValue.serverTimestamp()});

      // Reload the configuration to get the actual Timestamp value
      final doc = await FirebaseFirestore.instance
          .collection('app_configuration')
          .doc('fee_structure')
          .get();

      if (doc.exists) {
        setState(() {
          _feeConfig = doc.data() ?? {};
        });
      }

      _showSuccessSnackBar('Fee updated successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to update fee: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Management'),
        backgroundColor: Colors.deepPurple.shade800,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.attach_money), text: 'Appointment Fees'),
            Tab(icon: Icon(Icons.pie_chart), text: 'Revenue Share'),
            Tab(icon: Icon(Icons.cloud), text: 'Remote Revenue'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAppointmentFeesTab(),
                _buildRevenueShareTab(),
                _buildRemoteRevenueTab(),
                _buildSettingsTab(),
              ],
            ),
    );
  }

  Widget _buildAppointmentFeesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          'Doctor Consultation Fees',
          Icons.medical_services,
          Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildFeeCard(
          title: 'Follow-up Appointment',
          description: 'For returning patients within 30 days',
          feeKey: 'doctorFollowUp',
          icon: Icons.replay,
          color: Colors.green,
        ),
        _buildFeeCard(
          title: 'General Consultation',
          description: 'Standard doctor consultation',
          feeKey: 'doctorGeneralConsultation',
          icon: Icons.health_and_safety,
          color: Colors.blue,
        ),
        _buildFeeCard(
          title: 'Mental Health Consultation',
          description: 'Psychiatry and counseling services',
          feeKey: 'doctorMentalHealth',
          icon: Icons.psychology,
          color: Colors.purple,
        ),
        _buildFeeCard(
          title: 'Emergency Consultation',
          description: 'Urgent medical attention',
          feeKey: 'doctorEmergency',
          icon: Icons.emergency,
          color: Colors.red,
        ),
        _buildFeeCard(
          title: 'Specialist Consultation',
          description: 'Cardiology, neurology, etc.',
          feeKey: 'doctorSpecialist',
          icon: Icons.star,
          color: Colors.orange,
        ),
        const SizedBox(height: 24),
        _buildSectionHeader(
          'CHW & Community Health',
          Icons.people,
          Colors.teal,
        ),
        const SizedBox(height: 12),
        _buildFeeCard(
          title: 'Patient-CHW Booking',
          description: 'Patients booking with community health workers',
          feeKey: 'patientCHWBooking',
          icon: Icons.person,
          color: Colors.teal,
        ),
        _buildFeeCard(
          title: 'CHW-Doctor Referral',
          description: 'CHW booking doctor appointment (after free quota)',
          feeKey: 'chwDoctorBooking',
          icon: Icons.medical_information,
          color: Colors.indigo,
        ),
        const SizedBox(height: 12),
        _buildQuotaCard(),
      ],
    );
  }

  Widget _buildRevenueShareTab() {
    final providerShare =
        (_feeConfig['providerSharePercentage'] is int
            ? (_feeConfig['providerSharePercentage'] as int).toDouble()
            : _feeConfig['providerSharePercentage'] as double?) ??
        70.0;
    final adminShare =
        (_feeConfig['adminSharePercentage'] is int
            ? (_feeConfig['adminSharePercentage'] as int).toDouble()
            : _feeConfig['adminSharePercentage'] as double?) ??
        30.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 4,
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Revenue Split Configuration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Configure how appointment fees are distributed between service providers (Doctors/CHWs) and the platform admin.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Visual representation
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Current Revenue Distribution',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        flex: providerShare.toInt(),
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.green.shade400,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(8),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${providerShare.toStringAsFixed(0)}%\nProvider',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: adminShare.toInt(),
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.purple.shade400,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(8),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${adminShare.toStringAsFixed(0)}%\nAdmin',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Example calculation
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Example: ₦3,000 Consultation Fee',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.person, color: Colors.green),
                            const SizedBox(width: 8),
                            const Text('Provider receives: '),
                            Text(
                              '₦${(3000 * providerShare / 100).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.business, color: Colors.purple),
                            const SizedBox(width: 8),
                            const Text('Admin receives: '),
                            Text(
                              '₦${(3000 * adminShare / 100).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Provider Share Slider
          _buildPercentageCard(
            title: 'Provider Share',
            description: 'Percentage paid to doctors/CHWs',
            percentageKey: 'providerSharePercentage',
            currentValue: providerShare,
            color: Colors.green,
            icon: Icons.medical_services,
          ),

          // Admin Share Slider
          _buildPercentageCard(
            title: 'Admin Commission',
            description: 'Platform fee percentage',
            percentageKey: 'adminSharePercentage',
            currentValue: adminShare,
            color: Colors.purple,
            icon: Icons.business_center,
          ),

          const SizedBox(height: 16),

          // Warning card
          if (providerShare + adminShare != 100)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Warning: Provider share + Admin share must equal 100%\nCurrent total: ${(providerShare + adminShare).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
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

  Widget _buildRemoteRevenueTab() {
    final remoteDoctorShare =
        (_feeConfig['remoteDoctorSharePercentage'] is int
            ? (_feeConfig['remoteDoctorSharePercentage'] as int).toDouble()
            : _feeConfig['remoteDoctorSharePercentage'] as double?) ??
        70.0;
    final remoteFacilityShare =
        (_feeConfig['remoteFacilitySharePercentage'] is int
            ? (_feeConfig['remoteFacilitySharePercentage'] as int).toDouble()
            : _feeConfig['remoteFacilitySharePercentage'] as double?) ??
        30.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 4,
            color: Colors.indigo.shade50,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud,
                        color: Colors.indigo.shade700,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remote Consultation Revenue Split',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Configure how remote consultation fees are distributed between remote doctors and facilities.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Note: Admin commission is removed since facilities already pay subscription fees',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Visual representation
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Current Distribution',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        flex: remoteDoctorShare.toInt(),
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade400,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(8),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.medical_services,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Doctor',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${remoteDoctorShare.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: remoteFacilityShare.toInt(),
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.teal.shade400,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(8),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.local_hospital,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Facility',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${remoteFacilityShare.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Example calculation
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Example: ₦3,000 Remote Consultation Fee',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.medical_services,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            const Text('Remote Doctor receives: '),
                            Text(
                              '₦${(3000 * remoteDoctorShare / 100).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.local_hospital,
                              color: Colors.teal,
                            ),
                            const SizedBox(width: 8),
                            const Text('Facility receives: '),
                            Text(
                              '₦${(3000 * remoteFacilityShare / 100).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Remote Doctor Share Slider
          _buildPercentageCard(
            title: 'Remote Doctor Share',
            description: 'Percentage paid to remote doctors',
            percentageKey: 'remoteDoctorSharePercentage',
            currentValue: remoteDoctorShare,
            color: Colors.blue,
            icon: Icons.medical_services,
          ),

          // Facility Share Slider
          _buildPercentageCard(
            title: 'Facility Share',
            description: 'Percentage paid to hosting facility',
            percentageKey: 'remoteFacilitySharePercentage',
            currentValue: remoteFacilityShare,
            color: Colors.teal,
            icon: Icons.local_hospital,
          ),

          const SizedBox(height: 16),

          // Warning card
          if (remoteDoctorShare + remoteFacilityShare != 100)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Warning: Doctor share + Facility share must equal 100%\nCurrent total: ${(remoteDoctorShare + remoteFacilityShare).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
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

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.currency_exchange, color: Colors.green),
            title: const Text('Currency'),
            subtitle: Text(_feeConfig['currency'] ?? 'NGN'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Currency change dialog could be added here
            },
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fee Configuration Version',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Version: ${_feeConfig['version'] ?? 1}'),
                const SizedBox(height: 4),
                if (_feeConfig['updatedAt'] != null &&
                    _feeConfig['updatedAt'] is Timestamp)
                  Text(
                    'Last updated: ${_formatTimestamp(_feeConfig['updatedAt'] as Timestamp)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _resetToDefaults,
          icon: const Icon(Icons.restore),
          label: const Text('Reset to Default Values'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFeeCard({
    required String title,
    required String description,
    required String feeKey,
    required IconData icon,
    required Color color,
  }) {
    final currentFee =
        (_feeConfig[feeKey] is int
            ? (_feeConfig[feeKey] as int).toDouble()
            : _feeConfig[feeKey] as double?) ??
        0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        description,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '₦${NumberFormat('#,##0').format(currentFee)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showEditFeeDialog(title, feeKey, currentFee),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotaCard() {
    final quota = _feeConfig['chwFreeAppointmentQuota'] as int? ?? 3;

    return Card(
      elevation: 4,
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard, color: Colors.amber.shade700),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'CHW Free Appointment Quota',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Number of free appointments CHWs can book before fees apply',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$quota free appointments',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showEditQuotaDialog(quota),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPercentageCard({
    required String title,
    required String description,
    required String percentageKey,
    required double currentValue,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${currentValue.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Slider(
              value: currentValue,
              min: 0,
              max: 100,
              divisions: 100,
              activeColor: color,
              label: '${currentValue.toStringAsFixed(1)}%',
              onChanged: (value) {
                setState(() {
                  _feeConfig[percentageKey] = value;
                  // Auto-adjust the other percentage to maintain 100% total
                  if (percentageKey == 'providerSharePercentage') {
                    _feeConfig['adminSharePercentage'] = 100 - value;
                  } else if (percentageKey == 'adminSharePercentage') {
                    _feeConfig['providerSharePercentage'] = 100 - value;
                  } else if (percentageKey == 'remoteDoctorSharePercentage') {
                    _feeConfig['remoteFacilitySharePercentage'] = 100 - value;
                  } else if (percentageKey == 'remoteFacilitySharePercentage') {
                    _feeConfig['remoteDoctorSharePercentage'] = 100 - value;
                  }
                });
              },
              onChangeEnd: (value) {
                // Save both percentages
                _updateFeeValue(percentageKey, value);
                if (percentageKey == 'providerSharePercentage') {
                  _updateFeeValue('adminSharePercentage', 100 - value);
                } else if (percentageKey == 'adminSharePercentage') {
                  _updateFeeValue('providerSharePercentage', 100 - value);
                } else if (percentageKey == 'remoteDoctorSharePercentage') {
                  _updateFeeValue('remoteFacilitySharePercentage', 100 - value);
                } else if (percentageKey == 'remoteFacilitySharePercentage') {
                  _updateFeeValue('remoteDoctorSharePercentage', 100 - value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditFeeDialog(String title, String feeKey, double currentValue) {
    final controller = TextEditingController(
      text: currentValue.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Fee Amount (₦)',
                border: OutlineInputBorder(),
                prefixText: '₦',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newValue = double.tryParse(controller.text);
              if (newValue != null && newValue >= 0) {
                _updateFeeValue(feeKey, newValue);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditQuotaDialog(int currentValue) {
    final controller = TextEditingController(text: currentValue.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit CHW Free Quota'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Number of Free Appointments',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newValue = int.tryParse(controller.text);
              if (newValue != null && newValue >= 0) {
                _updateFeeValue('chwFreeAppointmentQuota', newValue);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'Are you sure you want to reset all fees to default values? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('app_configuration')
          .doc('fee_structure')
          .delete();

      await _createDefaultConfiguration();
      _showSuccessSnackBar('Fees reset to default values');
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('MMM dd, yyyy hh:mm a').format(date);
  }
}
