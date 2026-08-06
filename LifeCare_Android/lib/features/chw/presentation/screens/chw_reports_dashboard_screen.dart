import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../data/services/chw_export_service.dart';

class CHWReportsDashboardScreen extends StatefulWidget {
  final String chwId;
  final String chwName;

  const CHWReportsDashboardScreen({
    super.key,
    required this.chwId,
    required this.chwName,
  });

  @override
  State<CHWReportsDashboardScreen> createState() =>
      _CHWReportsDashboardScreenState();
}

class _CHWReportsDashboardScreenState extends State<CHWReportsDashboardScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CHWExportService _exportService = CHWExportService();
  late TabController _tabController;

  DateTimeRange? _selectedDateRange;
  final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    // Default to current month
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.deepPurple,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Future<void> _handleExport(String exportType) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Generating export...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      File? file;

      switch (exportType) {
        case 'earnings_pdf':
          file = await _exportService.exportEarningsPDF(
            chwId: widget.chwId,
            chwName: widget.chwName,
            startDate: _selectedDateRange?.start,
            endDate: _selectedDateRange?.end,
          );
          break;
        case 'analytics_pdf':
          file = await _exportService.exportServiceAnalyticsPDF(
            chwId: widget.chwId,
            chwName: widget.chwName,
            startDate: _selectedDateRange?.start,
            endDate: _selectedDateRange?.end,
          );
          break;
        case 'transactions_csv':
          file = await _exportService.exportTransactionsCSV(
            chwId: widget.chwId,
            chwName: widget.chwName,
            startDate: _selectedDateRange?.start,
            endDate: _selectedDateRange?.end,
          );
          break;
        case 'patients_csv':
          file = await _exportService.exportPatientsCSV(
            chwId: widget.chwId,
            chwName: widget.chwName,
          );
          break;
      }

      if (file != null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export generated successfully!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'SHARE',
              textColor: Colors.white,
              onPressed: () => _exportService.shareFile(file!),
            ),
          ),
        );

        // Auto-share the file
        await _exportService.shareFile(file);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports & Analytics'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.download),
            tooltip: 'Export Data',
            onSelected: _handleExport,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'earnings_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Earnings Report (PDF)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'analytics_pdf',
                child: Row(
                  children: [
                    Icon(Icons.bar_chart, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Service Analytics (PDF)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'transactions_csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Transactions (CSV)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'patients_csv',
                child: Row(
                  children: [
                    Icon(Icons.people, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Patient List (CSV)'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.favorite), text: 'Health Impact'),
            Tab(icon: Icon(Icons.people_outline), text: 'Community'),
            Tab(icon: Icon(Icons.assignment), text: 'Referrals'),
            Tab(icon: Icon(Icons.monetization_on), text: 'Financial'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date Range Display
          Container(
            padding: EdgeInsets.all(12),
            color: Colors.deepPurple.shade50,
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text(
                  _selectedDateRange != null
                      ? '${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}'
                      : 'Select date range',
                  style: TextStyle(
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacer(),
                TextButton.icon(
                  onPressed: _selectDateRange,
                  icon: Icon(Icons.edit, size: 16),
                  label: Text('Change'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildHealthImpactTab(),
                _buildCommunityReachTab(),
                _buildReferralsTab(),
                _buildFinancialTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for data filtering
  List<DocumentSnapshot> _filterByDateRange(
    List<DocumentSnapshot> docs,
    String timestampField,
  ) {
    if (_selectedDateRange == null) return docs;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      dynamic timestamp = data[timestampField];

      DateTime? date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.tryParse(timestamp);
      }

      if (date == null) return false;

      return date.isAfter(
            _selectedDateRange!.start.subtract(Duration(days: 1)),
          ) &&
          date.isBefore(_selectedDateRange!.end.add(Duration(days: 1)));
    }).toList();
  }

  //==========================================================================
  // TAB 1: OVERVIEW - Key metrics summary
  //==========================================================================
  Widget _buildOverviewTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('health_records')
          .where('chwId', isEqualTo: widget.chwId)
          .snapshots(),
      builder: (context, healthSnapshot) {
        if (healthSnapshot.hasError) {
          return Center(child: Text('Error loading data'));
        }

        if (!healthSnapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('appointments')
              .where('providerId', isEqualTo: widget.chwId)
              .snapshots(),
          builder: (context, apptSnapshot) {
            if (!apptSnapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('referrals')
                  .where('referredById', isEqualTo: widget.chwId)
                  .snapshots(),
              builder: (context, refSnapshot) {
                if (!refSnapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('chw_patients')
                      .where('chwId', isEqualTo: widget.chwId)
                      .snapshots(),
                  builder: (context, patSnapshot) {
                    if (!patSnapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final healthRecords = _filterByDateRange(
                      healthSnapshot.data!.docs,
                      'createdAt',
                    );
                    final appointments = _filterByDateRange(
                      apptSnapshot.data!.docs,
                      'appointmentDate',
                    );
                    final referrals = _filterByDateRange(
                      refSnapshot.data!.docs,
                      'createdAt',
                    );
                    final allPatients = patSnapshot.data!.docs;

                    // Calculate metrics
                    Set<String> uniquePatients = {};
                    for (var doc in healthRecords) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['patientId'] != null) {
                        uniquePatients.add(data['patientId']);
                      }
                    }

                    int ancVisits = healthRecords.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final type = (data['type'] ?? '')
                          .toString()
                          .toUpperCase();
                      final consultType = (data['consultationType'] ?? '')
                          .toString()
                          .toUpperCase();
                      return type.contains('ANC') ||
                          consultType.contains('ANC');
                    }).length;

                    int pncVisits = healthRecords.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final type = (data['type'] ?? '')
                          .toString()
                          .toUpperCase();
                      final consultType = (data['consultationType'] ?? '')
                          .toString()
                          .toUpperCase();
                      return type.contains('PNC') ||
                          consultType.contains('PNC');
                    }).length;

                    return SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Impact Summary',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                          SizedBox(height: 16),

                          // Key Metrics Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  'Patients Served',
                                  uniquePatients.length.toString(),
                                  Icons.people,
                                  Colors.blue,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'Total Registered',
                                  allPatients.length.toString(),
                                  Icons.person_add,
                                  Colors.green,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  'Consultations',
                                  healthRecords.length.toString(),
                                  Icons.medical_services,
                                  Colors.orange,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'Referrals Made',
                                  referrals.length.toString(),
                                  Icons.assignment,
                                  Colors.purple,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  'Appointments',
                                  appointments.length.toString(),
                                  Icons.calendar_today,
                                  Colors.teal,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'ANC Visits',
                                  ancVisits.toString(),
                                  Icons.pregnant_woman,
                                  Colors.pink,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 24),

                          // Quick Stats
                          Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.trending_up,
                                        color: Colors.deepPurple,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Activity Highlights',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Divider(height: 24),
                                  _buildStatRow(
                                    'Maternal Care (ANC)',
                                    ancVisits.toString(),
                                    Colors.pink,
                                  ),
                                  _buildStatRow(
                                    'Postnatal Care (PNC)',
                                    pncVisits.toString(),
                                    Colors.purple,
                                  ),
                                  _buildStatRow(
                                    'Active Patients This Period',
                                    uniquePatients.length.toString(),
                                    Colors.blue,
                                  ),
                                  _buildStatRow(
                                    'Appointments Booked',
                                    appointments.length.toString(),
                                    Colors.teal,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14))),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  //===========================================================================
  // TAB 2: HEALTH IMPACT - Health services delivered
  //===========================================================================
  Widget _buildHealthImpactTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('health_records')
          .where('chwId', isEqualTo: widget.chwId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final records = _filterByDateRange(snapshot.data!.docs, 'createdAt');

        // Categorize health records
        Map<String, int> recordTypes = {};
        int vitalsRecorded = 0;
        int healthEducationDelivered = 0;

        for (var doc in records) {
          final data = doc.data() as Map<String, dynamic>;
          final type = (data['type'] ?? 'Other').toString();

          recordTypes[type] = (recordTypes[type] ?? 0) + 1;

          // Check for vitals
          if (data['vitals'] != null || data['vitalSigns'] != null) {
            vitalsRecorded++;
          }

          // Check for health education
          if (data['healthEducation'] != null || data['counseling'] != null) {
            healthEducationDelivered++;
          }
        }

        return ListView(
          padding: EdgeInsets.all(16),
          children: [
            Text(
              'Health Services Delivered',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade700,
              ),
            ),
            SizedBox(height: 16),

            // Quick stats
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Records',
                    records.length.toString(),
                    Icons.description,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Vitals Recorded',
                    vitalsRecorded.toString(),
                    Icons.monitor_heart,
                    Colors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Health Education',
                    healthEducationDelivered.toString(),
                    Icons.school,
                    Colors.green,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Record Types',
                    recordTypes.length.toString(),
                    Icons.category,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            SizedBox(height: 24),
            Text(
              'Service Types Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),

            if (recordTypes.isEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No health records in this period'),
                  ),
                ),
              )
            else
              ...recordTypes.entries.map((entry) {
                final percentage = (entry.value / records.length * 100)
                    .toStringAsFixed(1);
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getHealthRecordColor(
                        entry.key,
                      ).withOpacity(0.2),
                      child: Icon(
                        _getHealthRecordIcon(entry.key),
                        color: _getHealthRecordColor(entry.key),
                      ),
                    ),
                    title: Text(_formatHealthRecordType(entry.key)),
                    subtitle: Text('$percentage% of health services'),
                    trailing: Text(
                      '${entry.value}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getHealthRecordColor(entry.key),
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  //===========================================================================
  // TAB 3: COMMUNITY REACH - Patient registration and engagement
  //===========================================================================
  Widget _buildCommunityReachTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('health_records')
          .where('chwId', isEqualTo: widget.chwId)
          .snapshots(),
      builder: (context, healthSnapshot) {
        if (!healthSnapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('appointments')
              .where('providerId', isEqualTo: widget.chwId)
              .snapshots(),
          builder: (context, apptSnapshot) {
            if (!apptSnapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chw_patients')
                  .where('chwId', isEqualTo: widget.chwId)
                  .snapshots(),
              builder: (context, patSnapshot) {
                if (!patSnapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final healthRecords = _filterByDateRange(
                  healthSnapshot.data!.docs,
                  'createdAt',
                );
                final appointments = _filterByDateRange(
                  apptSnapshot.data!.docs,
                  'appointmentDate',
                );
                final allPatients = patSnapshot.data!.docs;

                // Calculate community metrics
                Set<String> uniquePatientsServed = {};
                for (var doc in healthRecords) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['patientId'] != null) {
                    uniquePatientsServed.add(data['patientId']);
                  }
                }

                // New registrations in period
                int newRegistrations = allPatients.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final createdAt = data['createdAt'] as Timestamp?;
                  if (createdAt == null) return false;
                  final date = createdAt.toDate();
                  return date.isAfter(
                        _selectedDateRange!.start.subtract(Duration(days: 1)),
                      ) &&
                      date.isBefore(
                        _selectedDateRange!.end.add(Duration(days: 1)),
                      );
                }).length;

                return ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    Text(
                      'Community Engagement',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                    SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Total Registered',
                            allPatients.length.toString(),
                            Icons.people,
                            Colors.blue,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'New This Period',
                            newRegistrations.toString(),
                            Icons.person_add,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Patients Served',
                            uniquePatientsServed.length.toString(),
                            Icons.medical_services,
                            Colors.orange,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'Appointments',
                            appointments.length.toString(),
                            Icons.calendar_today,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.insights, color: Colors.deepPurple),
                                SizedBox(width: 8),
                                Text(
                                  'Engagement Metrics',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Divider(height: 24),
                            _buildStatRow(
                              'Active Patient Rate',
                              '${allPatients.isEmpty ? 0 : ((uniquePatientsServed.length / allPatients.length) * 100).toStringAsFixed(1)}%',
                              Colors.blue,
                            ),
                            _buildStatRow(
                              'Avg Visits per Patient',
                              uniquePatientsServed.isEmpty
                                  ? '0'
                                  : (healthRecords.length /
                                            uniquePatientsServed.length)
                                        .toStringAsFixed(1),
                              Colors.green,
                            ),
                            _buildStatRow(
                              'Appointment Completion',
                              appointments.isEmpty
                                  ? '0%'
                                  : '${((appointments.where((doc) => (doc.data() as Map)['status'] == 'completed').length / appointments.length) * 100).toStringAsFixed(1)}%',
                              Colors.orange,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  //===========================================================================
  // TAB 4: REFERRALS - Referral management and tracking
  //===========================================================================
  Widget _buildReferralsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('referrals')
          .where('referredById', isEqualTo: widget.chwId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final referrals = _filterByDateRange(snapshot.data!.docs, 'createdAt');

        // Categorize referrals
        Map<String, int> statusCounts = {};
        Map<String, int> urgencyCounts = {};

        for (var doc in referrals) {
          final data = doc.data() as Map<String, dynamic>;

          final status = data['status'] ?? 'Unknown';
          statusCounts[status] = (statusCounts[status] ?? 0) + 1;

          final urgency = data['urgency'] ?? 'normal';
          urgencyCounts[urgency] = (urgencyCounts[urgency] ?? 0) + 1;
        }

        return ListView(
          padding: EdgeInsets.all(16),
          children: [
            Text(
              'Referral Management',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade700,
              ),
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Referrals',
                    referrals.length.toString(),
                    Icons.assignment,
                    Colors.purple,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Urgent',
                    (urgencyCounts['high'] ?? 0).toString(),
                    Icons.priority_high,
                    Colors.red,
                  ),
                ),
              ],
            ),

            SizedBox(height: 24),
            Text(
              'Referral Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),

            if (statusCounts.isEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No referrals in this period')),
                ),
              )
            else
              ...statusCounts.entries.map((entry) {
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getReferralStatusColor(
                        entry.key,
                      ).withOpacity(0.2),
                      child: Icon(
                        _getReferralStatusIcon(entry.key),
                        color: _getReferralStatusColor(entry.key),
                      ),
                    ),
                    title: Text(entry.key.toUpperCase()),
                    trailing: Text(
                      '${entry.value}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getReferralStatusColor(entry.key),
                      ),
                    ),
                  ),
                );
              }),

            if (urgencyCounts.isNotEmpty) ...[
              SizedBox(height: 24),
              Text(
                'Urgency Levels',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: urgencyCounts.entries.map((entry) {
                      return _buildStatRow(
                        entry.key.toUpperCase(),
                        entry.value.toString(),
                        _getUrgencyColor(entry.key),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  //===========================================================================
  // TAB 5: FINANCIAL - Earnings and transactions
  //===========================================================================
  Widget _buildFinancialTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chw_transactions')
          .where('chwId', isEqualTo: widget.chwId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading financial data'));
        }

        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        var transactions = _filterByDateRange(snapshot.data!.docs, 'timestamp');

        double totalEarnings = 0;
        Map<String, double> earningsByService = {};

        for (var doc in transactions) {
          final data = doc.data() as Map<String, dynamic>;
          final chwAmount = (data['chwAmount'] as num?)?.toDouble() ?? 0;
          final serviceType = data['serviceType'] as String? ?? 'Unknown';

          totalEarnings += chwAmount;
          earningsByService[serviceType] =
              (earningsByService[serviceType] ?? 0) + chwAmount;
        }

        return ListView(
          padding: EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: 48,
                      color: Colors.green,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Total Earnings (70%)',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green.shade700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      currencyFormat.format(totalEarnings),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),
            Text(
              'Earnings by Service',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),

            if (earningsByService.isEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No earnings in this period')),
                ),
              )
            else
              ...earningsByService.entries.map((entry) {
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      _getServiceIcon(entry.key),
                      color: _getServiceColor(entry.key),
                    ),
                    title: Text(_formatServiceName(entry.key)),
                    trailing: Text(
                      currencyFormat.format(entry.value),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  //===========================================================================
  // Helper methods for colors and icons
  //===========================================================================
  Color _getHealthRecordColor(String type) {
    if (type.toUpperCase().contains('ANC')) return Colors.pink;
    if (type.toUpperCase().contains('PNC')) return Colors.purple;
    if (type.toUpperCase().contains('CONSULTATION')) return Colors.blue;
    if (type.toUpperCase().contains('CHECKLIST')) return Colors.orange;
    return Colors.grey;
  }

  IconData _getHealthRecordIcon(String type) {
    if (type.toUpperCase().contains('ANC')) return Icons.pregnant_woman;
    if (type.toUpperCase().contains('PNC')) return Icons.child_care;
    if (type.toUpperCase().contains('CONSULTATION')) {
      return Icons.medical_services;
    }
    if (type.toUpperCase().contains('CHECKLIST')) return Icons.checklist;
    return Icons.folder;
  }

  String _formatHealthRecordType(String type) {
    if (type.toUpperCase().contains('ANC')) return 'Antenatal Care';
    if (type.toUpperCase().contains('PNC')) return 'Postnatal Care';
    if (type.toUpperCase().contains('CONSULTATION')) {
      return 'Medical Consultation';
    }
    if (type.toUpperCase().contains('CHECKLIST')) return 'Health Checklist';
    return type;
  }

  Color _getReferralStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getReferralStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'completed':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'high':
      case 'urgent':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
      case 'normal':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getServiceColor(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'consultation':
        return Colors.blue;
      case 'anc':
        return Colors.pink;
      case 'pnc':
        return Colors.purple;
      case 'home_visit':
        return Colors.orange;
      case 'immunization':
        return Colors.teal;
      case 'appointment':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getServiceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'consultation':
        return Icons.medical_services;
      case 'anc':
        return Icons.pregnant_woman;
      case 'pnc':
        return Icons.child_care;
      case 'home_visit':
        return Icons.home;
      case 'immunization':
        return Icons.vaccines;
      case 'appointment':
        return Icons.calendar_today;
      default:
        return Icons.receipt;
    }
  }

  String _formatServiceName(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'consultation':
        return 'Consultation';
      case 'anc':
        return 'Antenatal Care';
      case 'pnc':
        return 'Postnatal Care';
      case 'home_visit':
        return 'Home Visit';
      case 'immunization':
        return 'Immunization';
      case 'appointment':
        return 'Appointment Booking';
      default:
        return serviceType;
    }
  }
}
