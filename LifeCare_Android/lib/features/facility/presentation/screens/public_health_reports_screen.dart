import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class PublicHealthReportsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final bool showAppBar;

  const PublicHealthReportsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    this.showAppBar = true,
  });

  @override
  State<PublicHealthReportsScreen> createState() =>
      _PublicHealthReportsScreenState();
}

class _PublicHealthReportsScreenState extends State<PublicHealthReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _reports = [
    _PublicHealthReportConfig(
      title: 'Immunization Reports',
      collection: 'immunizations',
      dateField: 'scheduledDate',
      icon: Icons.vaccines,
      color: Colors.blue,
      fields: ['patientName', 'vaccineName', 'status', 'scheduledDate'],
    ),
    _PublicHealthReportConfig(
      title: 'Environmental Surveillance',
      collection: 'environmental_inspections',
      dateField: 'inspectionDate',
      icon: Icons.eco,
      color: Colors.green,
      fields: ['inspectionType', 'department', 'status', 'inspectionDate'],
      sourceField: 'dashboardSource',
      sourceValue: 'public_health',
    ),
    _PublicHealthReportConfig(
      title: 'Disease Surveillance',
      collection: 'disease_surveillance_cases',
      dateField: 'reportedDate',
      icon: Icons.monitor_heart,
      color: Colors.orange,
      fields: ['diseaseName', 'caseClassification', 'status', 'reportedDate'],
    ),
    _PublicHealthReportConfig(
      title: 'Outbreak Investigation',
      collection: 'outbreak_investigations',
      dateField: 'reportedDate',
      icon: Icons.crisis_alert,
      color: Colors.purple,
      fields: ['infectionType', 'numberOfCases', 'status', 'reportedDate'],
    ),
    _PublicHealthReportConfig(
      title: 'Health Education',
      collection: 'health_education_sessions',
      dateField: 'sessionDate',
      icon: Icons.school,
      color: Colors.teal,
      fields: ['topic', 'targetAudience', 'participants', 'sessionDate'],
    ),
    _PublicHealthReportConfig(
      title: 'Health Outreach',
      collection: 'health_outreach_activities',
      dateField: 'activityDate',
      icon: Icons.groups,
      color: Colors.indigo,
      fields: ['activityType', 'location', 'participants', 'activityDate'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _reports.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabBar = TabBar(
      controller: _tabController,
      isScrollable: true,
      labelColor: widget.showAppBar ? Colors.white : Colors.green.shade800,
      unselectedLabelColor: widget.showAppBar ? Colors.white70 : Colors.black54,
      indicatorColor: widget.showAppBar ? Colors.white : Colors.green.shade700,
      tabs: _reports
          .map((report) => Tab(icon: Icon(report.icon), text: report.title))
          .toList(),
    );

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Public Health Reports'),
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              bottom: tabBar,
            )
          : null,
      body: Column(
        children: [
          if (!widget.showAppBar) Material(color: Colors.white, child: tabBar),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _reports
                  .map(
                    (report) => _PublicHealthReportTab(
                      config: report,
                      facilityId: widget.facilityId,
                      facilityName: widget.facilityName,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicHealthReportTab extends StatelessWidget {
  final _PublicHealthReportConfig config;
  final String facilityId;
  final String facilityName;

  const _PublicHealthReportTab({
    required this.config,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection(config.collection)
        .where('facilityId', isEqualTo: facilityId);
    if (config.sourceField != null && config.sourceValue != null) {
      query = query.where(config.sourceField!, isEqualTo: config.sourceValue);
    }
    final stream = query.snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading report: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data?.docs ?? [];
        final rows =
            records
                .map(
                  (doc) => {
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  },
                )
                .toList()
              ..sort(
                (a, b) => _asDate(
                  b[config.dateField],
                ).compareTo(_asDate(a[config.dateField])),
              );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(context, rows),
            const SizedBox(height: 16),
            _buildSummary(rows),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No submitted surveillance data found.'),
                ),
              )
            else
              ...rows.map((row) => _buildRecordCard(row)),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, List<Map<String, dynamic>> rows) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: config.color.withValues(alpha: 0.14),
          child: Icon(config.icon, color: config.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            config.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          tooltip: 'Export Excel',
          onPressed: rows.isEmpty ? null : () => _exportCsv(context, rows),
          icon: const Icon(Icons.table_chart),
        ),
        IconButton(
          tooltip: 'Export PDF',
          onPressed: rows.isEmpty ? null : () => _exportPdf(rows),
          icon: const Icon(Icons.picture_as_pdf),
        ),
      ],
    );
  }

  Widget _buildSummary(List<Map<String, dynamic>> rows) {
    final thisMonth = rows.where((row) {
      final date = _asDate(row[config.dateField]);
      final now = DateTime.now();
      return date.year == now.year && date.month == now.month;
    }).length;

    return Row(
      children: [
        Expanded(child: _statCard('Total Records', rows.length.toString())),
        const SizedBox(width: 12),
        Expanded(child: _statCard('This Month', thisMonth.toString())),
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: config.color,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> row) {
    final title = _firstValue(row, [
      'patientName',
      'diseaseName',
      'infectionType',
      'inspectionType',
      'topic',
      'activityType',
      'vaccineName',
    ]);
    final date = _asDate(row[config.dateField]);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          title.isEmpty ? 'Submitted report' : title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          config.fields
              .where((field) => row[field] != null)
              .map((field) => '${_label(field)}: ${_formatValue(row[field])}')
              .join('\n'),
        ),
        trailing: Text(DateFormat('MMM d, y').format(date)),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    List<Map<String, dynamic>> rows,
  ) async {
    final headers = ['id', ...config.fields];
    final csv = StringBuffer()..writeln(headers.map(_csvCell).join(','));
    for (final row in rows) {
      csv.writeln(
        headers.map((header) => _csvCell(_formatValue(row[header]))).join(','),
      );
    }

    await Share.shareXFiles([
      XFile.fromData(
        Uint8List.fromList(utf8.encode(csv.toString())),
        mimeType: 'text/csv',
        name: '${_fileSlug(config.title)}.csv',
      ),
    ], subject: '${config.title} - $facilityName');
  }

  Future<void> _exportPdf(List<Map<String, dynamic>> rows) async {
    final pdf = pw.Document();
    final headers = config.fields.map(_label).toList();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            '$facilityName - ${config.title}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated: ${DateFormat('MMM d, y HH:mm').format(DateTime.now())}',
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows
                .map(
                  (row) => config.fields
                      .map((field) => _formatValue(row[field]))
                      .toList(),
                )
                .toList(),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${_fileSlug(config.title)}.pdf',
    );
  }

  static String _csvCell(Object? value) {
    final text = (value ?? '').toString().replaceAll('"', '""');
    return '"$text"';
  }

  static String _fileSlug(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static String _firstValue(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return _formatValue(value);
      }
    }
    return '';
  }

  static DateTime _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _formatValue(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) {
      return DateFormat('MMM d, y').format(value.toDate());
    }
    if (value is DateTime) return DateFormat('MMM d, y').format(value);
    if (value is bool) return value ? 'Yes' : 'No';
    return value.toString();
  }

  static String _label(String field) {
    final spaced = field.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

class _PublicHealthReportConfig {
  final String title;
  final String collection;
  final String dateField;
  final IconData icon;
  final Color color;
  final List<String> fields;
  final String? sourceField;
  final String? sourceValue;

  const _PublicHealthReportConfig({
    required this.title,
    required this.collection,
    required this.dateField,
    required this.icon,
    required this.color,
    required this.fields,
    this.sourceField,
    this.sourceValue,
  });
}
