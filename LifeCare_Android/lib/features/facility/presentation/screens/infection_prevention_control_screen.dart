// Infection Prevention and Control Screen
// Healthcare-Associated Infection (HAI) Surveillance
// Hand Hygiene Monitoring
// Hospital Outbreak Investigation
// Following WHO IPC Guidelines and Best Practices

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../shared/presentation/screens/ai_assistant_screen.dart';
import '../../../shared/presentation/widgets/resource_popup_button.dart';
import '../../data/services/surveillance_form_id_service.dart';
import '../models/environmental_health_questionnaire.dart';
import '../models/hai_questionnaire.dart';
import '../models/water_quality_questionnaire.dart';
import '../models/ward_denominator_questionnaire.dart';
import '../widgets/staff_password_change_dialog.dart';
import 'environmental_surveillance_screen.dart';

String _cleanIpcAiText(String value) {
  final withoutMarkdown = value
      .replaceAll(RegExp(r'[#*_`~>]'), '')
      .replaceAll(RegExp(r'^\s*[-•]\s*', multiLine: true), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return withoutMarkdown
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .take(6)
      .join('\n');
}

String _haiRowLabel(Map<String, dynamic> row, String fieldName) {
  final labels = row['haiQuestionnaireResponseLabels'] is Map
      ? Map<String, dynamic>.from(row['haiQuestionnaireResponseLabels'] as Map)
      : const <String, dynamic>{};
  final responses = row['haiQuestionnaireResponses'] is Map
      ? Map<String, dynamic>.from(row['haiQuestionnaireResponses'] as Map)
      : const <String, dynamic>{};
  final value = labels[fieldName] ?? responses[fieldName] ?? 'Unknown';
  return '$value'.isEmpty ? 'Unknown' : '$value';
}

bool _isFinalSurveillanceSubmission(Map<String, dynamic> data) {
  final submissionStatus = '${data['submissionStatus'] ?? ''}'
      .trim()
      .toLowerCase();
  if (submissionStatus.isNotEmpty) return submissionStatus == 'final';

  final submissionState = '${data['submissionState'] ?? ''}'
      .trim()
      .toLowerCase();
  if (submissionState.isNotEmpty) return submissionState == 'final';

  if (data.containsKey('isFinal')) return data['isFinal'] == true;

  final status = '${data['status'] ?? ''}'.trim().toLowerCase();
  if (status == 'draft' || status == 'pending' || status == 'in-progress') {
    return false;
  }
  if (status == 'submitted' || status == 'active' || status == 'final') {
    return true;
  }

  return true;
}

Future<void> _printStoredHaiReport(Map<String, dynamic> approvalData) async {
  final report = approvalData['reportData'] is Map
      ? Map<String, dynamic>.from(approvalData['reportData'] as Map)
      : approvalData;
  final doc = pw.Document();
  pw.ImageProvider? logo;
  final logoUrl = '${report['logoUrl'] ?? ''}'.trim();
  if (logoUrl.isNotEmpty) {
    try {
      logo = await networkImage(logoUrl);
    } catch (_) {
      logo = null;
    }
  }
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}'),
      ),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) pw.Image(logo, width: 52, height: 52),
            if (logo != null) pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${report['facilityName'] ?? approvalData['facilityName'] ?? ''}',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text('Infection prevention and control Committee'),
                  pw.Text(
                    '${report['title'] ?? approvalData['title'] ?? 'HAI report'}',
                  ),
                  pw.Text(
                    'Status: ${approvalData['status'] ?? 'Approved'} • Generated: ${DateFormat('MMM d, y').format(DateTime.now())}',
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Overall HAI rate: ${_storedNumber(report['overallRate']).toStringAsFixed(2)} per 1,000 patient-days',
        ),
        pw.Text(
          'Overall HAI percentage: ${_storedNumber(report['overallPercentage']).toStringAsFixed(1)}%',
        ),
        pw.Text(
          'Records: ${report['totalRecords'] ?? approvalData['recordCount'] ?? 0}',
        ),
        pw.SizedBox(height: 12),
        _storedPdfTable(
          'HAI by Ward and Infection Type',
          const [
            'Ward',
            'No. Discharges',
            'No. Culture Request',
            'No. of HAIs',
            'Overall % of HAIs in the Hospital',
            '% of HAIs per Ward/Unit',
            'Surgical Site',
            'Skin & Soft Tissue',
            'HAP',
            'BSI',
            'UTI',
            'Others',
            'No. of infected patients',
          ],
          _storedHaiLabWardTableRows(_storedList(report['labWardRows'])),
        ),
        pw.NewPage(),
        _storedPdfTable(
          'Device-Associated Infection Surveillance',
          const [
            'Ward',
            'CAUTI',
            'CLABSI',
            'PLABSI',
            'VAP',
            'Cath days',
            'CVC days',
            'PVC days',
            'Vent days',
          ],
          _storedList(report['deviceIncidenceRows']).map((row) {
            final map = Map<String, dynamic>.from(row as Map);
            return [
              map['ward'] ?? '',
              map['cauti'] ?? 0,
              map['cvcHai'] ?? 0,
              map['pvcHai'] ?? 0,
              map['invHai'] ?? 0,
              map['urinaryCatheter'] ?? 0,
              map['cvc'] ?? 0,
              map['pvc'] ?? 0,
              map['inv'] ?? 0,
            ];
          }).toList(),
        ),
        _storedPdfTable(
          'Microbiology Profile',
          const [
            'Pathogens',
            'Surgical site',
            'Skin & Soft Tissue',
            'HAP',
            'BSI',
            'UTI',
            'Others',
            'Total',
            'Percentage',
          ],
          _storedHaiMicrobiologyTableRows(
            _storedList(report['microbiologyRows']).isNotEmpty
                ? _storedList(report['microbiologyRows'])
                : _storedList(report['pathogenSiteRows']),
          ),
        ),
        pw.NewPage(),
        _storedPdfTable(
          'Patient Outcomes',
          const ['Outcome', 'Patients'],
          _storedMap(
            report['outcomeCounts'],
          ).entries.map((entry) => [entry.key, entry.value]).toList(),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Summary / remarks',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          constraints: const pw.BoxConstraints(minHeight: 100),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600),
          ),
          child: pw.Text('${report['remarks'] ?? ''}'),
        ),
        pw.SizedBox(height: 36),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _storedSignatureField('IPC Doctor'),
            _storedSignatureField('IPC Manager'),
          ],
        ),
      ],
    ),
  );
  await Printing.sharePdf(
    bytes: await doc.save(),
    filename:
        'approved_hai_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
  );
}

List<dynamic> _storedList(Object? value) => value is List ? value : const [];

Map<String, dynamic> _storedMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

double _storedNumber(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

List<List<Object?>> _storedHaiLabWardTableRows(List<dynamic> rows) {
  final dataRows = rows.map((row) {
    final map = Map<String, dynamic>.from(row as Map);
    final discharges = _storedNumber(map['discharges']).round();
    final cultureRequests = _storedNumber(map['cultureRequests']).round();
    final haiCount = _storedNumber(map['haiCount']).round();
    final ssi = _storedNumber(map['ssi']).round();
    final sst = _storedNumber(map['sst']).round();
    final rti = _storedNumber(map['rti']).round();
    final bsi = _storedNumber(map['bsi']).round();
    final uti = _storedNumber(map['uti']).round();
    final others =
        _storedNumber(map['git']).round() +
        _storedNumber(map['neonatalSepsis']).round() +
        _storedNumber(map['others']).round();
    final infectedPatients = _storedNumber(map['infectedPatients']).round();
    return [
      map['ward'] ?? '',
      discharges,
      cultureRequests,
      haiCount,
      '',
      '',
      ssi,
      sst,
      rti,
      bsi,
      uti,
      others,
      infectedPatients,
    ];
  }).toList();
  int sumAt(int index) => dataRows.fold<int>(
    0,
    (sum, row) => sum + ((row[index] as num?)?.round() ?? 0),
  );
  final totalDischarges = sumAt(1);
  final totalCultureRequests = sumAt(2);
  final totalHai = sumAt(3);
  final totalSsi = sumAt(6);
  final totalSst = sumAt(7);
  final totalRti = sumAt(8);
  final totalBsi = sumAt(9);
  final totalUti = sumAt(10);
  final totalOthers = sumAt(11);
  final totalInfected = sumAt(12);
  String percent(int numerator, int denominator) => denominator == 0
      ? '0.0'
      : ((numerator / denominator) * 100).toStringAsFixed(1);
  final populatedRows = dataRows.map((row) {
    final discharges = (row[1] as num).round();
    final haiCount = (row[3] as num).round();
    return [
      ...row.take(4),
      percent(haiCount, totalDischarges),
      percent(haiCount, discharges),
      ...row.skip(6),
    ];
  }).toList();
  return [
    ...populatedRows,
    [
      'Total',
      totalDischarges,
      totalCultureRequests,
      totalHai,
      percent(totalHai, totalDischarges),
      '',
      totalSsi,
      totalSst,
      totalRti,
      totalBsi,
      totalUti,
      totalOthers,
      totalInfected,
    ],
    [
      'Percentage',
      '',
      '',
      '',
      percent(totalHai, totalDischarges),
      '',
      percent(totalSsi, totalHai),
      percent(totalSst, totalHai),
      percent(totalRti, totalHai),
      percent(totalBsi, totalHai),
      percent(totalUti, totalHai),
      percent(totalOthers, totalHai),
      '',
    ],
  ];
}

List<List<Object?>> _storedHaiMicrobiologyTableRows(List<dynamic> rows) {
  final dataRows = rows.map((row) {
    final map = Map<String, dynamic>.from(row as Map);
    final ssi = _storedNumber(map['ssi']).round();
    final sst = _storedNumber(map['sst']).round();
    final rti = _storedNumber(map['rti']).round();
    final bsi = _storedNumber(map['bsi']).round();
    final uti = _storedNumber(map['uti']).round();
    final others =
        _storedNumber(map['git']).round() +
        _storedNumber(map['others']).round();
    final total = map.containsKey('total')
        ? _storedNumber(map['total']).round()
        : _storedNumber(map['isolates']).round();
    return [
      map['organism'] ?? map['pathogen'] ?? '',
      ssi,
      sst,
      rti,
      bsi,
      uti,
      others,
      total,
      _storedNumber(map['percentage']).toStringAsFixed(1),
    ];
  }).toList();
  int sumAt(int index) => dataRows.fold<int>(
    0,
    (sum, row) => sum + ((row[index] as num?)?.round() ?? 0),
  );
  final totals = [sumAt(1), sumAt(2), sumAt(3), sumAt(4), sumAt(5), sumAt(6)];
  final grandTotal = sumAt(7);
  String percent(int value) =>
      grandTotal == 0 ? '0.0' : ((value / grandTotal) * 100).toStringAsFixed(1);
  return [
    ...dataRows,
    ['Total', ...totals, grandTotal, ''],
    ['Percentage', ...totals.map(percent), '', ''],
  ];
}

pw.Widget _storedPdfTable(
  String title,
  List<String> headers,
  List<List<Object?>> rows,
) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(headers: headers, data: rows),
      pw.SizedBox(height: 14),
    ],
  );
}

pw.Widget _storedSignatureField(String label) {
  return pw.SizedBox(
    width: 180,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(height: 1, color: PdfColors.black),
        pw.SizedBox(height: 6),
        pw.Text(label),
      ],
    ),
  );
}

DateTime _startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _endOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

class InfectionPreventionControlScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final int initialTabIndex;

  const InfectionPreventionControlScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    this.initialTabIndex = 0,
  });

  @override
  State<InfectionPreventionControlScreen> createState() =>
      _InfectionPreventionControlScreenState();
}

class _InfectionPreventionControlScreenState
    extends State<InfectionPreventionControlScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedHAISurveillanceType = 'Routine HAI Surveillance';
  bool _showTargetedSurveillanceTypes = false;
  bool _isLoadingTabAccess = true;
  List<String> _allowedTabIds = [];
  final Map<String, String> _customFormTabLabels = {};
  bool _customFormLabelsLoaded = false;
  String _pendingHaiSearch = '';
  String _pendingHaiSearchInput = '';
  String _pendingHaiSearchField = 'hospitalNumber';
  bool _showAllPendingHai = false;
  String _pendingHandHygieneSearch = '';
  String _pendingHandHygieneSearchInput = '';
  String _pendingHandHygieneSearchField = 'formId';
  bool _showAllPendingHandHygiene = false;
  String _pendingOutbreakSearch = '';
  String _pendingOutbreakSearchInput = '';
  String _pendingOutbreakSearchField = 'formId';
  bool _showAllPendingOutbreak = false;
  String _pendingWardDenominatorSearch = '';
  String _pendingWardDenominatorSearchInput = '';
  String _pendingWardDenominatorSearchField = 'formId';
  bool _showAllPendingWardDenominator = false;
  String _pendingIpcAssessmentSearch = '';
  String _pendingIpcAssessmentSearchInput = '';
  String _pendingIpcAssessmentSearchField = 'formId';
  bool _showAllPendingIpcAssessments = false;

  static const _allTabIds = [
    'hai_surveillance',
    'hand_hygiene',
    'outbreak_investigation',
    'environmental_surveillance',
    'ward_denominator',
    'ipc_assessment_tools',
    'surveillance_data',
  ];

  static const _tabLabels = {
    'hai_surveillance': 'HAI Surveillance',
    'hand_hygiene': 'Hand Hygiene',
    'outbreak_investigation': 'Outbreak Investigation',
    'environmental_surveillance': 'Environmental Surveillance',
    'ward_denominator': 'Ward Denominator',
    'ipc_assessment_tools': 'IPC Assessment tools',
    'surveillance_data': 'Surveillance Data',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _allTabIds.length,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _allTabIds.length - 1),
    );
    _loadTabAccess();
  }

  Future<void> _loadTabAccess() async {
    final prefs = await SharedPreferences.getInstance();
    await _refreshCustomFormTabLabels();
    final cached = _normalizeTabAccess(
      prefs.getStringList('ipc_tab_access') ?? const [],
    );

    if (cached.isNotEmpty) {
      _applyTabAccess(cached, isLoading: false);
    }

    try {
      final staffId = (prefs.getString('staff_id') ?? widget.staffId).trim();
      final staffDocumentId = prefs.getString('staff_document_id')?.trim();
      final staffEmail = prefs.getString('staff_email')?.trim();
      final savedCollection = prefs.getString('staff_collection')?.trim();
      final collection = savedCollection?.isNotEmpty == true
          ? savedCollection!
          : '${widget.facilityName.toLowerCase().replaceAll(' ', '_')}_users';

      if (staffId.isEmpty &&
          (staffDocumentId == null || staffDocumentId.isEmpty) &&
          (staffEmail == null || staffEmail.isEmpty)) {
        if (cached.isEmpty) {
          _applyTabAccess(const [], isLoading: false);
        }
        return;
      }

      Map<String, dynamic>? data;
      final staffCollection = FirebaseFirestore.instance.collection(collection);
      if (staffDocumentId != null && staffDocumentId.isNotEmpty) {
        final document = await staffCollection
            .doc(staffDocumentId)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 5));
        data = document.data();
      }
      if (data == null && staffId.isNotEmpty) {
        final snapshot = await staffCollection
            .where('staffId', isEqualTo: staffId)
            .limit(1)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 5));
        data = snapshot.docs.isEmpty ? null : snapshot.docs.first.data();
      }
      if (data == null && staffEmail != null && staffEmail.isNotEmpty) {
        final snapshot = await staffCollection
            .where('email', isEqualTo: staffEmail)
            .limit(1)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 5));
        data = snapshot.docs.isEmpty ? null : snapshot.docs.first.data();
      }

      if (data == null) {
        _applyTabAccess(cached, isLoading: false);
        return;
      }

      final allowed = _normalizeTabAccess(data['ipcTabAccess']);
      await prefs.setStringList('ipc_tab_access', allowed);
      await prefs.setBool('ipc_tab_access_cached', true);
      _applyTabAccess(allowed, isLoading: false);
    } catch (_) {
      if (cached.isEmpty) {
        _applyTabAccess(const [], isLoading: false);
      }
    }
  }

  Future<void> _refreshCustomFormTabLabels() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('ipc_custom_forms')
          .where('isActive', isEqualTo: true)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
      final forms = snapshot.docs.where(
        (doc) => _isSameIpcTemplateFacility(
          doc.data(),
          widget.facilityId,
          widget.facilityName,
        ),
      );
      _customFormTabLabels
        ..clear()
        ..addEntries(
          forms.map((doc) {
            final title = '${doc.data()['title'] ?? 'Custom Surveillance'}';
            return MapEntry('custom_form:${doc.id}', title);
          }),
        );
      _customFormLabelsLoaded = true;
    } catch (_) {
      _customFormLabelsLoaded = false;
    }
  }

  List<String> _normalizeTabAccess(Object? value) {
    final saved = value is List
        ? value.map((item) => item.toString()).toSet()
        : <String>{};
    final normalized = <String>[
      ..._allTabIds.where(saved.contains),
      ...saved.where(
        (item) =>
            item.startsWith('custom_form:') &&
            (!_customFormLabelsLoaded ||
                _customFormTabLabels.containsKey(item)),
      ),
    ];
    return normalized.toSet().toList();
  }

  void _applyTabAccess(List<String> allowed, {required bool isLoading}) {
    if (!mounted) return;
    _tabController.dispose();
    _allowedTabIds = allowed;
    _tabController = TabController(
      length: allowed.isEmpty ? 1 : allowed.length,
      vsync: this,
      initialIndex: allowed.isEmpty
          ? 0
          : widget.initialTabIndex.clamp(0, allowed.length - 1),
    );
    setState(() => _isLoadingTabAccess = isLoading);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await FirebaseAuth.instance
          .signOut()
          .timeout(const Duration(seconds: 3), onTimeout: () {})
          .catchError((_) {});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTabAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_allowedTabIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Infection Prevention & Control'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 56,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Administrator permission required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your facility administrator must assign IPC dashboard tabs to your account before you can view this dashboard.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Infection Prevention & Control'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          const ResourcePopupButton(assistantType: AIAssistantType.doctor),
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: 'IPC Guidelines',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => DraggableScrollableSheet(
                  initialChildSize: 0.9,
                  expand: false,
                  builder: (context, controller) =>
                      _buildIPCGuidelinesTab(controller: controller),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SizedBox()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Account Settings',
            onPressed: () => StaffPasswordChangeDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: _allowedTabIds.map((id) => Tab(text: _tabLabel(id))).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _allowedTabIds.map(_buildTabContent).toList(),
      ),
    );
  }

  Widget _buildTabContent(String tabId) {
    if (tabId.startsWith('custom_form:')) {
      return _buildCustomSurveillanceTab(tabId.split(':').last);
    }
    switch (tabId) {
      case 'hai_surveillance':
        return _buildHAISurveillanceTab();
      case 'hand_hygiene':
        return _buildHandHygieneTab();
      case 'outbreak_investigation':
        return _buildOutbreakInvestigationTab();
      case 'environmental_surveillance':
        return _buildEnvironmentalSurveillanceTab();
      case 'ward_denominator':
        return _buildWardDenominatorTab();
      case 'ipc_assessment_tools':
        return _buildIpcAssessmentToolsTab();
      case 'surveillance_data':
        return _buildReportsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  String _tabLabel(String id) {
    if (id.startsWith('custom_form:')) {
      return _customFormTabLabels[id] ?? 'Custom Form';
    }
    return _tabLabels[id] ?? id;
  }

  Widget _buildCustomSurveillanceTab(String formId) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ipc_custom_forms')
          .doc(formId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load form: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data?.data();
        if (data == null || data['isActive'] == false) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final tabId = 'custom_form:$formId';
            if (!mounted || !_allowedTabIds.contains(tabId)) return;
            _customFormTabLabels.remove(tabId);
            _applyTabAccess(
              _allowedTabIds.where((id) => id != tabId).toList(),
              isLoading: false,
            );
          });
          return const Center(child: CircularProgressIndicator());
        }
        final title = '${data['title'] ?? 'Custom Surveillance'}';
        _customFormTabLabels['custom_form:$formId'] = title;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if ('${data['description'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('${data['description']}'),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _CustomSurveillanceEntryScreen(
                    facilityId: widget.facilityId,
                    facilityName: widget.facilityName,
                    staffId: widget.staffId,
                    staffName: widget.staffName,
                    formId: formId,
                    formData: data,
                  ),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add new'),
            ),
          ],
        );
      },
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
          'Healthcare-Associated Infection Surveillance',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          value: _selectedHAISurveillanceType,
          decoration: const InputDecoration(
            labelText: 'Surveillance Type',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.track_changes),
          ),
          items: const [
            DropdownMenuItem(
              value: 'Routine HAI Surveillance',
              child: Text('Routine HAI Surveillance'),
            ),
            DropdownMenuItem(
              value: 'Targeted HAI Surveillance',
              child: Text('Targeted HAI Surveillance'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedHAISurveillanceType = value;
              _showTargetedSurveillanceTypes = false;
            });
          },
        ),
        const SizedBox(height: 12),

        if (_selectedHAISurveillanceType == 'Routine HAI Surveillance')
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openHAIForm(
                infectionType: 'Routine HAI',
                surveillanceType: 'Routine HAI Surveillance',
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add new'),
            ),
          )
        else if (!_showTargetedSurveillanceTypes)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _showTargetedSurveillanceTypes = true),
              icon: const Icon(Icons.add),
              label: const Text('Add new'),
            ),
          )
        else ...[
          ..._buildTargetedHAISurveillanceCards(),
          TextButton(
            onPressed: () =>
                setState(() => _showTargetedSurveillanceTypes = false),
            child: const Text('Hide surveillance types'),
          ),
        ],
        const SizedBox(height: 20),
        _buildPendingHAIForms(),
      ],
    );
  }

  Widget _buildPendingHAIForms() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('hai_surveillance')
          .where('facilityId', isEqualTo: widget.facilityId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Unable to load pending HAI forms: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final pendingDocs =
            [...?snapshot.data?.docs].where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['isFinal'] != true &&
                  data['submissionStatus'] != 'Final';
            }).toList()..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aDate =
                  (aData['updatedAt'] ?? aData['reportedDate']) as Timestamp?;
              final bDate =
                  (bData['updatedAt'] ?? bData['reportedDate']) as Timestamp?;
              return (bDate?.millisecondsSinceEpoch ?? 0).compareTo(
                aDate?.millisecondsSinceEpoch ?? 0,
              );
            });
        final docs = pendingDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final responses = data['haiQuestionnaireResponses'] is Map
              ? Map<String, dynamic>.from(
                  data['haiQuestionnaireResponses'] as Map,
                )
              : data['responses'] is Map
              ? Map<String, dynamic>.from(data['responses'] as Map)
              : const <String, dynamic>{};
          final haystack = _pendingHaiSearchValue(
            data,
            responses,
          ).toLowerCase();
          return _pendingHaiSearch.isEmpty ||
              haystack.contains(_pendingHaiSearch.toLowerCase());
        }).toList();
        final visibleDocs = _showAllPendingHai ? docs : docs.take(5).toList();
        if (pendingDocs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pending HAI forms',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    value: _pendingHaiSearchField,
                    decoration: const InputDecoration(
                      labelText: 'Search by',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'hospitalNumber',
                        child: Text('Hospital number'),
                      ),
                      DropdownMenuItem(value: 'formId', child: Text('Form ID')),
                      DropdownMenuItem(
                        value: 'infectionType',
                        child: Text('Subtype'),
                      ),
                      DropdownMenuItem(
                        value: 'staffId',
                        child: Text('Staff ID'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _pendingHaiSearchField = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Enter search value',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _pendingHaiSearchInput = value.trim(),
                    onSubmitted: (_) => setState(() {
                      _pendingHaiSearch = _pendingHaiSearchInput;
                      _showAllPendingHai = false;
                    }),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Search',
                  onPressed: () => setState(() {
                    _pendingHaiSearch = _pendingHaiSearchInput;
                    _showAllPendingHai = false;
                  }),
                  icon: const Icon(Icons.search),
                ),
                if (_pendingHaiSearch.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() {
                      _pendingHaiSearch = '';
                      _pendingHaiSearchInput = '';
                      _showAllPendingHai = false;
                    }),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (docs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Data does not exist for this search'),
                ),
              )
            else
              ...visibleDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final responses = data['haiQuestionnaireResponses'] is Map
                    ? Map<String, dynamic>.from(
                        data['haiQuestionnaireResponses'] as Map,
                      )
                    : data['responses'] is Map
                    ? Map<String, dynamic>.from(data['responses'] as Map)
                    : const <String, dynamic>{};
                final formId = '${data['formId'] ?? data['infectionType']}';
                final hospitalNumber =
                    '${data['patientId'] ?? responses['_9_Hospital_number'] ?? '-'}';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.pending_actions),
                    title: Text('Form ID: $formId'),
                    subtitle: Text(
                      'Hospital number: $hospitalNumber • ${data['infectionType'] ?? 'HAI'} • Last edited by ${data['lastUpdatedById'] ?? data['reportedById'] ?? '-'}',
                    ),
                    trailing: TextButton(
                      child: const Text('Continue'),
                      onPressed: () => _openHAIForm(
                        infectionType:
                            data['infectionType'] as String? ?? 'Routine HAI',
                        surveillanceType:
                            data['surveillanceType'] as String? ??
                            'Routine HAI Surveillance',
                        documentId: doc.id,
                        initialData: data,
                      ),
                    ),
                  ),
                );
              }),
            if (docs.length > 5)
              TextButton.icon(
                onPressed: () =>
                    setState(() => _showAllPendingHai = !_showAllPendingHai),
                icon: Icon(
                  _showAllPendingHai ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(
                  _showAllPendingHai
                      ? 'Show less'
                      : 'View more (${docs.length - 5})',
                ),
              ),
          ],
        );
      },
    );
  }

  String _pendingHaiSearchValue(
    Map<String, dynamic> data,
    Map<String, dynamic> responses,
  ) {
    switch (_pendingHaiSearchField) {
      case 'formId':
        return '${data['formId'] ?? ''}';
      case 'infectionType':
        return '${data['infectionType'] ?? data['surveillanceType'] ?? ''}';
      case 'staffId':
        return '${data['lastUpdatedById'] ?? data['reportedById'] ?? ''}';
      case 'hospitalNumber':
      default:
        return '${data['patientId'] ?? responses['_9_Hospital_number'] ?? ''}';
    }
  }

  String _pendingHandHygieneSearchValue(Map<String, dynamic> data) {
    switch (_pendingHandHygieneSearchField) {
      case 'session':
        return '${data['sessionNumber'] ?? ''}';
      case 'department':
        return '${data['department'] ?? data['ward'] ?? data['unit'] ?? ''}';
      case 'staffId':
        return '${data['lastUpdatedById'] ?? data['observerId'] ?? ''}';
      case 'formId':
      default:
        return '${data['formId'] ?? ''}';
    }
  }

  String _pendingOutbreakSearchValue(Map<String, dynamic> data) {
    switch (_pendingOutbreakSearchField) {
      case 'affectedArea':
        return '${data['affectedAreas'] ?? ''}';
      case 'description':
        return '${data['description'] ?? data['suspectedCause'] ?? ''}';
      case 'staffId':
        return '${data['lastUpdatedById'] ?? data['reportedById'] ?? ''}';
      case 'formId':
      default:
        return '${data['formId'] ?? ''}';
    }
  }

  String _pendingWardDenominatorSearchValue(Map<String, dynamic> data) {
    switch (_pendingWardDenominatorSearchField) {
      case 'department':
        return '${data['department'] ?? data['ward'] ?? data['unit'] ?? ''}';
      case 'period':
        return '${data['month'] ?? ''} ${data['year'] ?? ''}';
      case 'staffId':
        return '${data['lastUpdatedById'] ?? data['reportedById'] ?? ''}';
      case 'formId':
      default:
        return '${data['formId'] ?? ''}';
    }
  }

  void _openHAIForm({
    required String infectionType,
    required String surveillanceType,
    String? documentId,
    Map<String, dynamic>? initialData,
    bool allowFinalEdit = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _HAIReportFormScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          staffName: widget.staffName,
          infectionType: infectionType,
          surveillanceType: surveillanceType,
          documentId: documentId,
          initialData: initialData,
          allowFinalEdit: allowFinalEdit,
        ),
      ),
    );
  }

  List<Widget> _buildTargetedHAISurveillanceCards() {
    return [
      _buildHAITypeCard(
        infection: 'Central Line-Associated Bloodstream Infection (CLABSI)',
        description:
            'Bloodstream infection in patients with central venous catheter',
        icon: Icons.bloodtype,
        color: Colors.red,
        onReport: () => _openHAIForm(
          infectionType: 'CLABSI',
          surveillanceType: 'Targeted HAI Surveillance',
        ),
      ),
      _buildHAITypeCard(
        infection: 'Catheter-Associated Urinary Tract Infection (CAUTI)',
        description: 'UTI in patients with urinary catheter',
        icon: Icons.local_hospital,
        color: Colors.orange,
        onReport: () => _openHAIForm(
          infectionType: 'CAUTI',
          surveillanceType: 'Targeted HAI Surveillance',
        ),
      ),
      _buildHAITypeCard(
        infection: 'Surgical Site Infection (SSI)',
        description: 'Infection occurring after surgery',
        icon: Icons.healing,
        color: Colors.purple,
        onReport: () => _openHAIForm(
          infectionType: 'SSI',
          surveillanceType: 'Targeted HAI Surveillance',
        ),
      ),
      _buildHAITypeCard(
        infection: 'Ventilator-Associated Pneumonia (VAP)',
        description: 'Pneumonia in mechanically ventilated patients',
        icon: Icons.air,
        color: Colors.blue,
        onReport: () => _openHAIForm(
          infectionType: 'VAP',
          surveillanceType: 'Targeted HAI Surveillance',
        ),
      ),
      _buildHAITypeCard(
        infection: 'Clostridioides difficile Infection (CDI)',
        description: 'C. diff infection causing diarrhea',
        icon: Icons.coronavirus,
        color: Colors.brown,
        onReport: () => _openHAIForm(
          infectionType: 'CDI',
          surveillanceType: 'Targeted HAI Surveillance',
        ),
      ),
      _buildHAITypeCard(
        infection: 'Multidrug-Resistant Organism (MDRO)',
        description: 'Infections with antibiotic-resistant bacteria',
        icon: Icons.bug_report,
        color: Colors.red.shade900,
        onReport: () => _openHAIForm(
          infectionType: 'MDRO',
          surveillanceType: 'Targeted HAI Surveillance',
        ),
      ),
    ];
  }

  Widget _buildStatisticsCard() {
    return Card(
      color: Colors.red.shade50,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Infection Prevention Control',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade900,
              ),
            ),
            const SizedBox(height: 12),
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
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(
          infection,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
        trailing: TextButton(onPressed: onReport, child: const Text('Add')),
      ),
    );
  }

  // Hand Hygiene Surveillance Tab
  Widget _buildHandHygieneTab() {
    final query = FirebaseFirestore.instance
        .collection('hand_hygiene_observations')
        .where('facilityId', isEqualTo: widget.facilityId)
        .where('submissionStatus', isEqualTo: 'Draft');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final pendingDocs = [...?snapshot.data?.docs]
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['updatedAt'] as Timestamp?;
            final bDate = bData['updatedAt'] as Timestamp?;
            return (bDate?.millisecondsSinceEpoch ?? 0).compareTo(
              aDate?.millisecondsSinceEpoch ?? 0,
            );
          });
        final docs = pendingDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final haystack = _pendingHandHygieneSearchValue(data).toLowerCase();
          return _pendingHandHygieneSearch.isEmpty ||
              haystack.contains(_pendingHandHygieneSearch.toLowerCase());
        }).toList();
        final visibleDocs = _showAllPendingHandHygiene
            ? docs
            : docs.take(5).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ElevatedButton.icon(
              onPressed: () {
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
              },
              icon: const Icon(Icons.add),
              label: const Text('New Hand Hygiene Observation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),
            if (snapshot.hasError)
              Text(
                'Unable to load pending hand hygiene observations: ${snapshot.error}',
              )
            else if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (pendingDocs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No pending hand hygiene observations'),
                ),
              )
            else ...[
              const Text(
                'Pending hand hygiene observations',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      value: _pendingHandHygieneSearchField,
                      decoration: const InputDecoration(
                        labelText: 'Search by',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'formId',
                          child: Text('Form ID'),
                        ),
                        DropdownMenuItem(
                          value: 'session',
                          child: Text('Session'),
                        ),
                        DropdownMenuItem(
                          value: 'department',
                          child: Text('Department/Ward'),
                        ),
                        DropdownMenuItem(
                          value: 'staffId',
                          child: Text('Staff ID'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _pendingHandHygieneSearchField = value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Enter search value',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) =>
                          _pendingHandHygieneSearchInput = value.trim(),
                      onSubmitted: (_) => setState(() {
                        _pendingHandHygieneSearch =
                            _pendingHandHygieneSearchInput;
                        _showAllPendingHandHygiene = false;
                      }),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Search',
                    onPressed: () => setState(() {
                      _pendingHandHygieneSearch =
                          _pendingHandHygieneSearchInput;
                      _showAllPendingHandHygiene = false;
                    }),
                    icon: const Icon(Icons.search),
                  ),
                  if (_pendingHandHygieneSearch.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() {
                        _pendingHandHygieneSearch = '';
                        _pendingHandHygieneSearchInput = '';
                        _showAllPendingHandHygiene = false;
                      }),
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (docs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Data does not exist for this search'),
                  ),
                )
              else
                ...visibleDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.wash_outlined),
                      title: Text('${data['formId'] ?? 'Hand hygiene'}'),
                      subtitle: Text(
                        '${data['department'] ?? '-'} • ${data['ward'] ?? '-'} • Last edited by ${data['lastUpdatedById'] ?? '-'}',
                      ),
                      trailing: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _HandHygieneObservationFormScreen(
                              facilityId: widget.facilityId,
                              facilityName: widget.facilityName,
                              staffId: widget.staffId,
                              staffName: widget.staffName,
                              documentId: doc.id,
                              initialData: data,
                            ),
                          ),
                        ),
                        child: const Text('Continue'),
                      ),
                    ),
                  );
                }),
              if (docs.length > 5)
                TextButton.icon(
                  onPressed: () => setState(
                    () => _showAllPendingHandHygiene =
                        !_showAllPendingHandHygiene,
                  ),
                  icon: Icon(
                    _showAllPendingHandHygiene
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  label: Text(
                    _showAllPendingHandHygiene
                        ? 'Show less'
                        : 'View more (${docs.length - 5})',
                  ),
                ),
            ],
          ],
        );
      },
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('outbreak_investigations')
          .where('facilityId', isEqualTo: widget.facilityId)
          .snapshots(),
      builder: (context, snapshot) {
        final pendingDocs =
            [...?snapshot.data?.docs].where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['isFinal'] != true &&
                  data['submissionStatus'] != 'Final';
            }).toList()..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aDate =
                  (aData['updatedAt'] ?? aData['reportedDate']) as Timestamp?;
              final bDate =
                  (bData['updatedAt'] ?? bData['reportedDate']) as Timestamp?;
              return (bDate?.millisecondsSinceEpoch ?? 0).compareTo(
                aDate?.millisecondsSinceEpoch ?? 0,
              );
            });
        final docs = pendingDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final haystack = _pendingOutbreakSearchValue(data).toLowerCase();
          return _pendingOutbreakSearch.isEmpty ||
              haystack.contains(_pendingOutbreakSearch.toLowerCase());
        }).toList();
        final visibleDocs = _showAllPendingOutbreak
            ? docs
            : docs.take(5).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ElevatedButton.icon(
              onPressed: () {
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
              },
              icon: const Icon(Icons.warning),
              label: const Text('Report Outbreak'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),
            if (snapshot.hasError)
              Text(
                'Unable to load pending outbreak investigations: ${snapshot.error}',
              )
            else if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (pendingDocs.isNotEmpty) ...[
              const Text(
                'Pending outbreak investigations',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      value: _pendingOutbreakSearchField,
                      decoration: const InputDecoration(
                        labelText: 'Search by',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'formId',
                          child: Text('Form ID'),
                        ),
                        DropdownMenuItem(
                          value: 'affectedArea',
                          child: Text('Affected area'),
                        ),
                        DropdownMenuItem(
                          value: 'description',
                          child: Text('Description'),
                        ),
                        DropdownMenuItem(
                          value: 'staffId',
                          child: Text('Staff ID'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _pendingOutbreakSearchField = value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Enter search value',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) =>
                          _pendingOutbreakSearchInput = value.trim(),
                      onSubmitted: (_) => setState(() {
                        _pendingOutbreakSearch = _pendingOutbreakSearchInput;
                        _showAllPendingOutbreak = false;
                      }),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Search',
                    onPressed: () => setState(() {
                      _pendingOutbreakSearch = _pendingOutbreakSearchInput;
                      _showAllPendingOutbreak = false;
                    }),
                    icon: const Icon(Icons.search),
                  ),
                  if (_pendingOutbreakSearch.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() {
                        _pendingOutbreakSearch = '';
                        _pendingOutbreakSearchInput = '';
                        _showAllPendingOutbreak = false;
                      }),
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (docs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Data does not exist for this search'),
                  ),
                )
              else
                ...visibleDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.pending_actions),
                      title: Text('${data['formId'] ?? 'Outbreak'}'),
                      subtitle: Text(
                        '${data['affectedAreas'] ?? data['description'] ?? 'Outbreak investigation'} • Last edited by ${data['lastUpdatedById'] ?? data['reportedById'] ?? '-'}',
                      ),
                      trailing: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _OutbreakReportFormScreen(
                              facilityId: widget.facilityId,
                              facilityName: widget.facilityName,
                              staffId: widget.staffId,
                              staffName: widget.staffName,
                              documentId: doc.id,
                              initialData: data,
                            ),
                          ),
                        ),
                        child: const Text('Continue'),
                      ),
                    ),
                  );
                }),
              if (docs.length > 5)
                TextButton.icon(
                  onPressed: () => setState(
                    () => _showAllPendingOutbreak = !_showAllPendingOutbreak,
                  ),
                  icon: Icon(
                    _showAllPendingOutbreak
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  label: Text(
                    _showAllPendingOutbreak
                        ? 'Show less'
                        : 'View more (${docs.length - 5})',
                  ),
                ),
            ],
          ],
        );
      },
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

  // Environmental Surveillance Tab
  Widget _buildEnvironmentalSurveillanceTab() {
    return EnvironmentalSurveillanceLauncher(
      facilityId: widget.facilityId,
      facilityName: widget.facilityName,
      staffId: widget.staffId,
      staffName: widget.staffName,
      dashboardSource: 'ipc',
    );
  }

  Widget _buildWardDenominatorTab() {
    final query = FirebaseFirestore.instance
        .collection('ward_denominators')
        .where('facilityId', isEqualTo: widget.facilityId)
        .where('submissionStatus', isEqualTo: 'Draft');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final pendingDocs = [...?snapshot.data?.docs]
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['updatedAt'] as Timestamp?;
            final bDate = bData['updatedAt'] as Timestamp?;
            return (bDate?.millisecondsSinceEpoch ?? 0).compareTo(
              aDate?.millisecondsSinceEpoch ?? 0,
            );
          });
        final docs = pendingDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final haystack = _pendingWardDenominatorSearchValue(
            data,
          ).toLowerCase();
          return _pendingWardDenominatorSearch.isEmpty ||
              haystack.contains(_pendingWardDenominatorSearch.toLowerCase());
        }).toList();
        final visibleDocs = _showAllPendingWardDenominator
            ? docs
            : docs.take(5).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            OutlinedButton.icon(
              onPressed: () => _openWardDenominatorForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add new denominator'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: 16),
            if (snapshot.hasError)
              Text(
                'Unable to load pending denominator forms: ${snapshot.error}',
              )
            else if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (pendingDocs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No pending ward denominator forms'),
                ),
              )
            else ...[
              const Text(
                'Pending ward denominator forms',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      value: _pendingWardDenominatorSearchField,
                      decoration: const InputDecoration(
                        labelText: 'Search by',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'formId',
                          child: Text('Form ID'),
                        ),
                        DropdownMenuItem(
                          value: 'department',
                          child: Text('Department/Ward'),
                        ),
                        DropdownMenuItem(
                          value: 'period',
                          child: Text('Month/Year'),
                        ),
                        DropdownMenuItem(
                          value: 'staffId',
                          child: Text('Staff ID'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(
                          () => _pendingWardDenominatorSearchField = value,
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Enter search value',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) =>
                          _pendingWardDenominatorSearchInput = value.trim(),
                      onSubmitted: (_) => setState(() {
                        _pendingWardDenominatorSearch =
                            _pendingWardDenominatorSearchInput;
                        _showAllPendingWardDenominator = false;
                      }),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Search',
                    onPressed: () => setState(() {
                      _pendingWardDenominatorSearch =
                          _pendingWardDenominatorSearchInput;
                      _showAllPendingWardDenominator = false;
                    }),
                    icon: const Icon(Icons.search),
                  ),
                  if (_pendingWardDenominatorSearch.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() {
                        _pendingWardDenominatorSearch = '';
                        _pendingWardDenominatorSearchInput = '';
                        _showAllPendingWardDenominator = false;
                      }),
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (docs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Data does not exist for this search'),
                  ),
                )
              else
                ...visibleDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.hotel_outlined),
                      title: Text('${data['formId'] ?? 'Ward denominator'}'),
                      subtitle: Text(
                        '${data['department'] ?? '-'} • ${data['ward'] ?? '-'} • Last edited by ${data['lastUpdatedById'] ?? '-'}',
                      ),
                      trailing: TextButton(
                        onPressed: () => _openWardDenominatorForm(
                          documentId: doc.id,
                          initialData: data,
                        ),
                        child: const Text('Continue'),
                      ),
                    ),
                  );
                }),
              if (docs.length > 5)
                TextButton.icon(
                  onPressed: () => setState(
                    () => _showAllPendingWardDenominator =
                        !_showAllPendingWardDenominator,
                  ),
                  icon: Icon(
                    _showAllPendingWardDenominator
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  label: Text(
                    _showAllPendingWardDenominator
                        ? 'Show less'
                        : 'View more (${docs.length - 5})',
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  void _openWardDenominatorForm({
    String? documentId,
    Map<String, dynamic>? initialData,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _WardDenominatorFormScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          staffName: widget.staffName,
          documentId: documentId,
          initialData: initialData,
        ),
      ),
    );
  }

  Widget _buildIpcAssessmentToolsTab() {
    final query = FirebaseFirestore.instance
        .collection('ipc_assessments')
        .where('facilityId', isEqualTo: widget.facilityId)
        .where('submissionStatus', isEqualTo: 'Draft');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final pendingDocs = [...?snapshot.data?.docs]
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['updatedAt'] as Timestamp?;
            final bDate = bData['updatedAt'] as Timestamp?;
            return (bDate?.millisecondsSinceEpoch ?? 0).compareTo(
              aDate?.millisecondsSinceEpoch ?? 0,
            );
          });
        final docs = pendingDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final haystack = _pendingIpcAssessmentSearchValue(data).toLowerCase();
          return _pendingIpcAssessmentSearch.isEmpty ||
              haystack.contains(_pendingIpcAssessmentSearch.toLowerCase());
        }).toList();
        final visibleDocs = _showAllPendingIpcAssessments
            ? docs
            : docs.take(5).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'IPC Assessment tools',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildAssessmentToolCard(
              title: 'WHO IPCAF Tool',
              subtitle:
                  'Assess IPC programme implementation using the WHO core components.',
              icon: Icons.assignment_turned_in_outlined,
              onTap: () => _openIpcAssessmentForm('WHO IPCAF Tool'),
            ),
            _buildAssessmentToolCard(
              title: 'WASH FIT Tool',
              subtitle:
                  'Assess water, sanitation, hygiene, waste and facility improvement priorities.',
              icon: Icons.water_drop_outlined,
              onTap: () => _openIpcAssessmentForm('WASH FIT Tool'),
            ),
            _buildAssessmentToolCard(
              title: 'HHSAF Tool',
              subtitle:
                  'Assess hand hygiene promotion and practice using the WHO HHSAF components.',
              icon: Icons.back_hand_outlined,
              onTap: () => _openIpcAssessmentForm('HHSAF Tool'),
            ),
            const SizedBox(height: 16),
            if (snapshot.hasError)
              Text('Unable to load pending IPC assessments: ${snapshot.error}')
            else if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (pendingDocs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No pending IPC assessment forms'),
                ),
              )
            else ...[
              const Text(
                'Pending IPC assessments',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      value: _pendingIpcAssessmentSearchField,
                      decoration: const InputDecoration(
                        labelText: 'Search by',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'formId',
                          child: Text('Form ID'),
                        ),
                        DropdownMenuItem(value: 'tool', child: Text('Tool')),
                        DropdownMenuItem(
                          value: 'department',
                          child: Text('Department/Unit'),
                        ),
                        DropdownMenuItem(
                          value: 'staffId',
                          child: Text('Staff ID'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(
                          () => _pendingIpcAssessmentSearchField = value,
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Enter search value',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) =>
                          _pendingIpcAssessmentSearchInput = value.trim(),
                      onSubmitted: (_) => setState(() {
                        _pendingIpcAssessmentSearch =
                            _pendingIpcAssessmentSearchInput;
                        _showAllPendingIpcAssessments = false;
                      }),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Search',
                    onPressed: () => setState(() {
                      _pendingIpcAssessmentSearch =
                          _pendingIpcAssessmentSearchInput;
                      _showAllPendingIpcAssessments = false;
                    }),
                    icon: const Icon(Icons.search),
                  ),
                  if (_pendingIpcAssessmentSearch.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() {
                        _pendingIpcAssessmentSearch = '';
                        _pendingIpcAssessmentSearchInput = '';
                        _showAllPendingIpcAssessments = false;
                      }),
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (docs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Data does not exist for this search'),
                  ),
                )
              else
                ...visibleDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.assignment_outlined),
                      title: Text('${data['formId'] ?? 'IPC assessment'}'),
                      subtitle: Text(
                        '${data['assessmentTool'] ?? data['assessmentType'] ?? '-'} • ${data['department'] ?? '-'} • Last edited by ${data['lastUpdatedById'] ?? '-'}',
                      ),
                      trailing: TextButton(
                        onPressed: () => _openIpcAssessmentForm(
                          '${data['assessmentTool'] ?? data['assessmentType'] ?? 'WHO IPCAF Tool'}',
                          documentId: doc.id,
                          initialData: data,
                        ),
                        child: const Text('Continue'),
                      ),
                    ),
                  );
                }),
              if (docs.length > 5)
                TextButton.icon(
                  onPressed: () => setState(
                    () => _showAllPendingIpcAssessments =
                        !_showAllPendingIpcAssessments,
                  ),
                  icon: Icon(
                    _showAllPendingIpcAssessments
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  label: Text(
                    _showAllPendingIpcAssessments
                        ? 'Show less'
                        : 'View more (${docs.length - 5})',
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAssessmentToolCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.teal.shade800),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _openIpcAssessmentForm(
    String toolType, {
    String? documentId,
    Map<String, dynamic>? initialData,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _IpcAssessmentToolFormScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          staffName: widget.staffName,
          toolType: toolType,
          documentId: documentId,
          initialData: initialData,
        ),
      ),
    );
  }

  String _pendingIpcAssessmentSearchValue(Map<String, dynamic> data) {
    switch (_pendingIpcAssessmentSearchField) {
      case 'tool':
        return '${data['assessmentTool'] ?? data['assessmentType'] ?? ''}';
      case 'department':
        return '${data['department'] ?? ''} ${data['unit'] ?? ''}';
      case 'staffId':
        return '${data['createdById'] ?? ''} ${data['lastUpdatedById'] ?? ''}';
      case 'formId':
      default:
        return '${data['formId'] ?? ''}';
    }
  }

  Widget _buildReportsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Surveillance Data',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildReportLink('HAI Surveillance', Icons.analytics, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _HAISurveillanceDataScreen(
                facilityId: widget.facilityId,
                facilityName: widget.facilityName,
                staffId: widget.staffId,
                staffName: widget.staffName,
              ),
            ),
          );
        }),
        _buildReportLink('Hand Hygiene', Icons.wash, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _ReportsListScreen(
                title: 'Hand Hygiene Surveillance Data',
                collection: 'hand_hygiene_observations',
                facilityId: widget.facilityId,
                facilityName: widget.facilityName,
                staffId: widget.staffId,
                staffName: widget.staffName,
              ),
            ),
          );
        }),
        _buildReportLink('Outbreak Investigation', Icons.bug_report, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _ReportsListScreen(
                title: 'Outbreak Investigation Data',
                collection: 'outbreak_investigations',
                facilityId: widget.facilityId,
                facilityName: widget.facilityName,
                staffId: widget.staffId,
                staffName: widget.staffName,
              ),
            ),
          );
        }),
        _buildReportLink('Environmental Surveillance', Icons.eco, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _ReportsListScreen(
                title: 'Environmental Surveillance Data',
                collection: 'environmental_inspections',
                facilityId: widget.facilityId,
                facilityName: widget.facilityName,
                staffId: widget.staffId,
                staffName: widget.staffName,
                sourceField: 'dashboardSource',
                sourceValue: 'ipc',
              ),
            ),
          );
        }),
        _buildReportLink('Ward Denominator', Icons.hotel_outlined, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _ReportsListScreen(
                title: 'Ward Denominator Data',
                collection: 'ward_denominators',
                facilityId: widget.facilityId,
                facilityName: widget.facilityName,
                staffId: widget.staffId,
                staffName: widget.staffName,
              ),
            ),
          );
        }),
        _buildReportLink(
          'IPC Assessment Tools',
          Icons.assignment_turned_in,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => _ReportsListScreen(
                  title: 'IPC Assessment Tools Data',
                  collection: 'ipc_assessments',
                  facilityId: widget.facilityId,
                  facilityName: widget.facilityName,
                  staffId: widget.staffId,
                  staffName: widget.staffName,
                ),
              ),
            );
          },
        ),
        _buildReportLink(
          'Custom Surveillance Forms',
          Icons.dynamic_form_outlined,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => _ReportsListScreen(
                  title: 'Custom Surveillance Form Data',
                  collection: 'ipc_custom_form_submissions',
                  facilityId: widget.facilityId,
                  facilityName: widget.facilityName,
                  staffId: widget.staffId,
                  staffName: widget.staffName,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReportLink(String title, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade100,
          child: Icon(icon, color: Colors.grey.shade700),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildIPCGuidelinesTab({ScrollController? controller}) {
    return ListView(
      controller: controller,
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
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMomentItem('1. Before touching a patient'),
              _buildMomentItem('2. Before clean/aseptic procedures'),
              _buildMomentItem('3. After body fluid exposure risk'),
              _buildMomentItem('4. After touching a patient'),
              _buildMomentItem('5. After touching patient surroundings'),
            ],
          ),
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
        const SizedBox(height: 16),
        const Text(
          'Outbreak Investigation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
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

class _HaiReportApprovalTab extends StatelessWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const _HaiReportApprovalTab({
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  Future<void> _approveReport(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final warnings =
        (doc.data()['denominatorWarnings'] as List?)
            ?.map((item) => '$item')
            .where((item) => item.trim().isNotEmpty)
            .toList() ??
        const <String>[];
    if (warnings.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Essential denominator data required'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Text(
                'This report cannot be finally approved until these denominator issues are resolved:\n\n${warnings.join('\n')}',
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve HAI report'),
        content: Text(
          'Approve "${doc.data()['title'] ?? 'this HAI report'}"? The initiator will see the report as approved and may print it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await doc.reference.update({
      'reportStatus': 'approved',
      'status': 'Approved',
      'approvedById': staffId,
      'approvedByName': staffName,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'auditTrail': FieldValue.arrayUnion([
        {
          'action': 'approved',
          'staffId': staffId,
          'staffName': staffName,
          'at': Timestamp.now(),
        },
      ]),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('HAI report approved')));
    }
  }

  void _viewReport(BuildContext context, Map<String, dynamic> data) {
    final report = _storedMap(data['reportData']);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${data['title'] ?? 'HAI report'}'),
        content: SizedBox(
          width: 760,
          child: ListView(
            shrinkWrap: true,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _approvalMetric('Status', '${data['status'] ?? 'Submitted'}'),
                  _approvalMetric(
                    'Records',
                    '${data['recordCount'] ?? report['totalRecords'] ?? 0}',
                  ),
                  _approvalMetric(
                    'HAI rate',
                    '${_storedNumber(report['overallRate']).toStringAsFixed(2)} / 1,000',
                  ),
                  _approvalMetric(
                    'HAI percentage',
                    '${_storedNumber(report['overallPercentage']).toStringAsFixed(1)}%',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Initiated by: ${data['initiatedByName'] ?? '-'}'),
              Text('Report basis: ${data['reportBasis'] ?? '-'}'),
              Text('Period: ${data['reportPeriod'] ?? '-'}'),
              const SizedBox(height: 16),
              const Text(
                'Summary / remarks',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '${report['remarks'] ?? ''}'.trim().isEmpty
                    ? 'No remarks entered.'
                    : '${report['remarks']}',
              ),
              const SizedBox(height: 16),
              const Text(
                'This approval uses the calculated report package submitted by the initiator.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton.icon(
            onPressed: () => _printStoredHaiReport(data),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print preview'),
          ),
        ],
      ),
    );
  }

  Widget _approvalMetric(String label, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hai_report_approvals')
          .where('facilityId', isEqualTo: facilityId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Unable to load HAI reports: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs
          ..sort((a, b) {
            final aDate = a.data()['submittedAt'];
            final bDate = b.data()['submittedAt'];
            final aMs = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
            final bMs = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;
            return bMs.compareTo(aMs);
          });
        if (docs.isEmpty) {
          return const Center(
            child: Text('No HAI reports have been submitted for approval.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Approve HAI Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Review submitted HAI reports. Any staff assigned to this tab by the facility admin may approve.',
            ),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final data = doc.data();
              final status = '${data['status'] ?? 'Submitted'}';
              final approved = status.toLowerCase() == 'approved';
              return Card(
                child: ListTile(
                  leading: Icon(
                    approved
                        ? Icons.verified_outlined
                        : Icons.pending_actions_outlined,
                    color: approved ? Colors.green : Colors.orange,
                  ),
                  title: Text('${data['title'] ?? 'HAI report'}'),
                  subtitle: Text(
                    'Status: $status • Initiated by ${data['initiatedByName'] ?? '-'} • Records: ${data['recordCount'] ?? 0}',
                  ),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      TextButton(
                        onPressed: () => _viewReport(context, data),
                        child: const Text('View'),
                      ),
                      if (approved)
                        TextButton.icon(
                          onPressed: () => _printStoredHaiReport(data),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Print'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: () => _approveReport(context, doc),
                          icon: const Icon(Icons.verified_outlined),
                          label: const Text('Approve'),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _HAISurveillanceDataScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const _HAISurveillanceDataScreen({
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<_HAISurveillanceDataScreen> createState() =>
      _HAISurveillanceDataScreenState();
}

class _HAISurveillanceDataScreenState
    extends State<_HAISurveillanceDataScreen> {
  String _targetedSubtype = 'All';
  String _haiSearch = '';
  String _haiSearchInput = '';
  String _haiSearchField = 'formId';
  String _haiDepartmentFilter = 'All';
  String _haiWardFilter = 'All';
  String _selectedDataStatus = 'Raw Data';
  String _haiDateRangeBasis = 'admission';
  DateTime? _haiStartDate;
  DateTime? _haiEndDate;
  final Set<String> _selectedHaiRecordIds = {};
  final List<_DownloadedReport> _haiDownloads = [];
  bool _showAllRoutineHaiData = false;
  bool _showAllTargetedHaiData = false;

  static const _targetedTypes = [
    'All',
    'CLABSI',
    'CAUTI',
    'SSI',
    'VAP',
    'CDI',
    'MDRO',
  ];

  static const _dataStatuses = [
    'Raw Data',
    'Approved',
    'Not Approved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _loadHaiDownloads();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('HAI Surveillance Data'),
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Routine HAI'),
              Tab(text: 'Targeted HAI'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDataTable(routine: true),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: DropdownButtonFormField<String>(
                    value: _targetedSubtype,
                    decoration: const InputDecoration(
                      labelText: 'Targeted surveillance subtype',
                      border: OutlineInputBorder(),
                    ),
                    items: _targetedTypes
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _targetedSubtype = value);
                      }
                    },
                  ),
                ),
                Expanded(child: _buildDataTable(routine: false)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable({required bool routine}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('hai_surveillance')
          .where('facilityId', isEqualTo: widget.facilityId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs =
            [...?snapshot.data?.docs].where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              if (!_isFinalSurveillanceSubmission(data)) return false;
              final type = data['surveillanceType'] as String?;
              final infectionType = data['infectionType'] as String? ?? '';
              final isRoutine =
                  type == 'Routine HAI Surveillance' ||
                  infectionType == 'Routine HAI';
              if (routine != isRoutine) return false;
              final matchesSubtype =
                  routine ||
                  _targetedSubtype == 'All' ||
                  infectionType == _targetedSubtype;
              final responses = data['haiQuestionnaireResponses'] is Map
                  ? Map<String, dynamic>.from(
                      data['haiQuestionnaireResponses'] as Map,
                    )
                  : const <String, dynamic>{};
              final searchValue = _haiSearchField == 'hospitalNumber'
                  ? '${data['patientId'] ?? responses['_9_Hospital_number'] ?? ''}'
                  : '${data['formId'] ?? ''}';
              final matchesSearch =
                  _haiSearch.isEmpty ||
                  searchValue.toLowerCase().contains(_haiSearch.toLowerCase());
              final department = _haiDepartmentOf(data).toLowerCase();
              final ward = _haiWardOf(data).toLowerCase();
              final matchesDepartment =
                  _haiDepartmentFilter == 'All' ||
                  department == _haiDepartmentFilter.toLowerCase();
              final matchesWard =
                  _haiWardFilter == 'All' ||
                  ward == _haiWardFilter.toLowerCase();
              final matchesDate = _matchesHaiDateRange(data);
              return matchesSubtype &&
                  matchesSearch &&
                  matchesDepartment &&
                  matchesWard &&
                  matchesDate;
            }).toList()..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aDate =
                  (aData['updatedAt'] ?? aData['reportedDate']) as Timestamp?;
              final bDate =
                  (bData['updatedAt'] ?? bData['reportedDate']) as Timestamp?;
              return (bDate?.millisecondsSinceEpoch ?? 0).compareTo(
                aDate?.millisecondsSinceEpoch ?? 0,
              );
            });

        if (docs.isEmpty && _haiSearch.isEmpty) {
          return Center(
            child: Text(
              routine
                  ? 'No routine HAI surveillance data'
                  : 'No targeted HAI surveillance data',
            ),
          );
        }
        final showAll = routine
            ? _showAllRoutineHaiData
            : _showAllTargetedHaiData;
        final visibleDocs = showAll ? docs : docs.take(5).toList();
        final finalDocs = [...?snapshot.data?.docs].where((doc) {
          return _isFinalSurveillanceSubmission(
            doc.data() as Map<String, dynamic>,
          );
        }).toList();
        final departmentOptions = _haiFilterOptions(
          finalDocs,
          _haiDepartmentOf,
        );
        final wardOptions = _haiFilterOptions(finalDocs, _haiWardOf);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    value: _haiSearchField,
                    decoration: const InputDecoration(
                      labelText: 'Search by',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'formId', child: Text('Form ID')),
                      DropdownMenuItem(
                        value: 'hospitalNumber',
                        child: Text('Hospital number'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _haiSearchField = value);
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Enter search value',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _haiSearchInput = value.trim(),
                    onSubmitted: (_) => setState(() {
                      _haiSearch = _haiSearchInput;
                      _showAllRoutineHaiData = false;
                      _showAllTargetedHaiData = false;
                    }),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Search',
                  onPressed: () => setState(() {
                    _haiSearch = _haiSearchInput;
                    _showAllRoutineHaiData = false;
                    _showAllTargetedHaiData = false;
                  }),
                  icon: const Icon(Icons.search),
                ),
                if (_haiSearch.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() {
                      _haiSearch = '';
                      _haiSearchInput = '';
                      _showAllRoutineHaiData = false;
                      _showAllTargetedHaiData = false;
                    }),
                    child: const Text('Clear'),
                  ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value:
                        departmentOptions.contains(_haiDepartmentFilter)
                        ? _haiDepartmentFilter
                        : 'All',
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                    items: departmentOptions
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _haiDepartmentFilter = value;
                          _showAllRoutineHaiData = false;
                          _showAllTargetedHaiData = false;
                        });
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: wardOptions.contains(_haiWardFilter)
                        ? _haiWardFilter
                        : 'All',
                    decoration: const InputDecoration(
                      labelText: 'Ward/Unit',
                      border: OutlineInputBorder(),
                    ),
                    items: wardOptions
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _haiWardFilter = value;
                          _showAllRoutineHaiData = false;
                          _showAllTargetedHaiData = false;
                        });
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 270,
                  child: DropdownButtonFormField<String>(
                    value: _haiDateRangeBasis,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Date range reads',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'admission',
                        child: Text('Admission date'),
                      ),
                      DropdownMenuItem(
                        value: 'sample',
                        child: Text('Sample collection date'),
                      ),
                      DropdownMenuItem(
                        value: 'both',
                        child: Text('Admission or sample date'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _haiDateRangeBasis = value;
                          _showAllRoutineHaiData = false;
                          _showAllTargetedHaiData = false;
                        });
                      }
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickHaiDateRange,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(_haiDateRangeLabel()),
                ),
                if (_haiStartDate != null ||
                    _haiEndDate != null ||
                    _haiDepartmentFilter != 'All' ||
                    _haiWardFilter != 'All')
                  TextButton(
                    onPressed: () => setState(() {
                      _haiStartDate = null;
                      _haiEndDate = null;
                      _haiDateRangeBasis = 'admission';
                      _haiDepartmentFilter = 'All';
                      _haiWardFilter = 'All';
                      _showAllRoutineHaiData = false;
                      _showAllTargetedHaiData = false;
                    }),
                    child: const Text('Clear filters'),
                  ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _selectedDataStatus,
                    decoration: const InputDecoration(
                      labelText: 'Data status',
                      border: OutlineInputBorder(),
                    ),
                    items: _dataStatuses
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedDataStatus = value);
                      }
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _selectedHaiRecordIds.isEmpty
                      ? null
                      : () => _updateSelectedHaiStatus(),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Apply status'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    final allSelected = docs.every(
                      (doc) => _selectedHaiRecordIds.contains(doc.id),
                    );
                    setState(() {
                      if (allSelected) {
                        _selectedHaiRecordIds.removeAll(
                          docs.map((doc) => doc.id),
                        );
                      } else {
                        _selectedHaiRecordIds.addAll(docs.map((doc) => doc.id));
                      }
                    });
                  },
                  icon: const Icon(Icons.select_all),
                  label: const Text('Select all'),
                ),
                OutlinedButton.icon(
                  onPressed: _selectedHaiRecordIds.isEmpty
                      ? null
                      : () => _openHaiExportDialog(docs),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Export'),
                ),
                OutlinedButton.icon(
                  onPressed: _selectedHaiRecordIds.isEmpty
                      ? null
                      : () => _openGenerateHaiReportDialog(docs),
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('HAI Dashboard'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Approve HAI Report'),
                            backgroundColor: Colors.teal.shade800,
                            foregroundColor: Colors.white,
                          ),
                          body: _HaiReportApprovalTab(
                            facilityId: widget.facilityId,
                            facilityName: widget.facilityName,
                            staffId: widget.staffId,
                            staffName: widget.staffName,
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Approve HAI Report'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Data does not exist for this search'),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Select')),
                    DataColumn(label: Text('Form ID')),
                    DataColumn(label: Text('Hospital number')),
                    DataColumn(label: Text('Age')),
                    DataColumn(label: Text('Gender')),
                    DataColumn(label: Text('Department')),
                    DataColumn(label: Text('Clinical diagnosis')),
                    DataColumn(label: Text('Data status')),
                    DataColumn(label: Text('Last editor ID')),
                    DataColumn(label: Text('Last updated')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: visibleDocs.map((doc) {
                    final docIndex = docs.indexWhere(
                      (item) => item.id == doc.id,
                    );
                    final data = doc.data() as Map<String, dynamic>;
                    final responses = data['haiQuestionnaireResponses'] is Map
                        ? Map<String, dynamic>.from(
                            data['haiQuestionnaireResponses'] as Map,
                          )
                        : const <String, dynamic>{};
                    final labels = data['haiQuestionnaireResponseLabels'] is Map
                        ? Map<String, dynamic>.from(
                            data['haiQuestionnaireResponseLabels'] as Map,
                          )
                        : const <String, dynamic>{};
                    final timestamp =
                        (data['updatedAt'] ?? data['reportedDate'])
                            as Timestamp?;
                    final rowStatus = '${data['dataStatus'] ?? 'Raw Data'}';
                    final readmissionGroupId =
                        '${data['readmissionGroupId'] ?? ''}'.trim();
                    final readmissionColor = _readmissionGroupColor(
                      readmissionGroupId,
                    );
                    return DataRow(
                      selected: _selectedHaiRecordIds.contains(doc.id),
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (readmissionColor != null) {
                          return readmissionColor.withValues(
                            alpha: states.contains(WidgetState.selected)
                                ? 0.30
                                : 0.16,
                          );
                        }
                        if (states.contains(WidgetState.selected)) {
                          return _dataStatusColor(rowStatus).withOpacity(0.24);
                        }
                        return _dataStatusColor(rowStatus).withOpacity(0.10);
                      }),
                      cells: [
                        DataCell(
                          Checkbox(
                            value: _selectedHaiRecordIds.contains(doc.id),
                            onChanged: (checked) {
                              setState(() {
                                if (checked ?? false) {
                                  _selectedHaiRecordIds.add(doc.id);
                                } else {
                                  _selectedHaiRecordIds.remove(doc.id);
                                }
                              });
                            },
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${data['formId'] ?? '-'}'),
                              if (readmissionColor != null) ...[
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Linked readmission record',
                                  child: Icon(
                                    Icons.link,
                                    size: 16,
                                    color: readmissionColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            '${data['patientId'] ?? responses['_9_Hospital_number'] ?? '-'}',
                          ),
                        ),
                        DataCell(
                          Text('${responses['_10_Patient_Age'] ?? '-'}'),
                        ),
                        DataCell(
                          Text(
                            '${labels['_11_Patient_Gender'] ?? responses['_11_Patient_Gender'] ?? '-'}',
                          ),
                        ),
                        DataCell(
                          Text(
                            '${labels['Department'] ?? responses['Department'] ?? '-'}',
                          ),
                        ),
                        DataCell(
                          Text(
                            '${responses['_13_Clinical_diagnosis'] ?? data['diagnosis'] ?? '-'}',
                          ),
                        ),
                        DataCell(
                          Chip(
                            label: Text(rowStatus),
                            backgroundColor: _dataStatusColor(
                              rowStatus,
                            ).withOpacity(0.18),
                          ),
                        ),
                        DataCell(Text('${data['lastUpdatedById'] ?? '-'}')),
                        DataCell(
                          Text(
                            timestamp == null
                                ? '-'
                                : DateFormat(
                                    'MMM d, y HH:mm',
                                  ).format(timestamp.toDate()),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'View',
                                icon: const Icon(Icons.visibility_outlined),
                                onPressed: () => _viewRecord(docs, docIndex),
                              ),
                              IconButton(
                                tooltip: data['submissionStatus'] == 'Draft'
                                    ? 'Edit'
                                    : 'Update',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editRecord(doc.id, data),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteHaiRecord(doc.id),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            if (docs.length > 5)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    if (routine) {
                      _showAllRoutineHaiData = !_showAllRoutineHaiData;
                    } else {
                      _showAllTargetedHaiData = !_showAllTargetedHaiData;
                    }
                  }),
                  icon: Icon(showAll ? Icons.expand_less : Icons.expand_more),
                  label: Text(
                    showAll ? 'Show less' : 'View more (${docs.length - 5})',
                  ),
                ),
              ),
            if (_haiDownloads.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Downloaded Excel files',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ..._haiDownloads.map(
                (download) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.table_chart_outlined),
                  title: Text(download.name),
                  subtitle: Text(
                    DateFormat('MMM d, y HH:mm').format(download.downloadedAt),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Download again',
                        icon: const Icon(Icons.download_outlined),
                        onPressed: () => _downloadSavedHaiExcel(download),
                      ),
                      IconButton(
                        tooltip: 'Delete from list',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteSavedHaiDownload(download),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildSubmittedHaiReports(),
          ],
        );
      },
    );
  }

  Widget _buildSubmittedHaiReports() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hai_report_approvals')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('initiatedById', isEqualTo: widget.staffId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Unable to load submitted HAI reports: ${snapshot.error}',
          );
        }
        if (!snapshot.hasData) return const SizedBox.shrink();
        final docs = snapshot.data!.docs
          ..sort((a, b) {
            final aDate = a.data()['submittedAt'];
            final bDate = b.data()['submittedAt'];
            final aMs = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
            final bMs = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;
            return bMs.compareTo(aMs);
          });
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Submitted HAI reports',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...docs.take(5).map((doc) {
              final data = doc.data();
              final status = '${data['status'] ?? 'Submitted'}';
              final approved = status.toLowerCase() == 'approved';
              return Card(
                child: ListTile(
                  leading: Icon(
                    approved
                        ? Icons.verified_outlined
                        : Icons.pending_actions_outlined,
                    color: approved ? Colors.green : Colors.orange,
                  ),
                  title: Text('${data['title'] ?? 'HAI report'}'),
                  subtitle: Text(
                    'Status: $status • Records: ${data['recordCount'] ?? 0}',
                  ),
                  trailing: approved
                      ? TextButton.icon(
                          onPressed: () => _printStoredHaiReport(data),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Print'),
                        )
                      : const Text('Awaiting approval'),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _viewRecord(List<QueryDocumentSnapshot> docs, int initialIndex) {
    if (docs.isEmpty) return;
    final safeInitialIndex = initialIndex < 0 ? 0 : initialIndex;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var currentIndex = safeInitialIndex.clamp(0, docs.length - 1);
        var statusOverride = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final doc = docs[currentIndex];
            final data = Map<String, dynamic>.from(
              doc.data() as Map<String, dynamic>,
            );
            if (statusOverride.isNotEmpty) {
              data['dataStatus'] = statusOverride;
            }
            final fields = _fullHaiDisplayFields(data);
            final currentStatus = _dataStatuses.contains(data['dataStatus'])
                ? '${data['dataStatus']}'
                : 'Raw Data';
            return AlertDialog(
              title: Text(
                'HAI Surveillance Record ${currentIndex + 1} of ${docs.length}',
              ),
              content: SizedBox(
                width: 560,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    DropdownButtonFormField<String>(
                      value: currentStatus,
                      decoration: const InputDecoration(
                        labelText: 'Data status',
                        border: OutlineInputBorder(),
                      ),
                      items: _dataStatuses
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        await _updateHaiRecordDataStatus(doc.id, value);
                        setDialogState(() => statusOverride = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    ...fields.entries.map(
                      (entry) => ListTile(
                        dense: true,
                        title: Text(entry.key),
                        subtitle: Text('${entry.value ?? '-'}'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: currentIndex == 0
                      ? null
                      : () => setDialogState(() {
                          currentIndex -= 1;
                          statusOverride = '';
                        }),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                ),
                TextButton.icon(
                  onPressed: currentIndex >= docs.length - 1
                      ? null
                      : () => setDialogState(() {
                          currentIndex += 1;
                          statusOverride = '';
                        }),
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _editRecord(doc.id, data);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateHaiRecordDataStatus(
    String documentId,
    String dataStatus,
  ) async {
    await FirebaseFirestore.instance
        .collection('hai_surveillance')
        .doc(documentId)
        .update({
          'dataStatus': dataStatus,
          'dataStatusUpdatedAt': FieldValue.serverTimestamp(),
          'dataStatusUpdatedById': widget.staffId,
          'dataStatusUpdatedBy': widget.staffName,
          'lastUpdatedById': widget.staffId,
          'lastUpdatedBy': widget.staffName,
          'updatedAt': FieldValue.serverTimestamp(),
          'changeHistory': FieldValue.arrayUnion([
            {
              'staffId': widget.staffId,
              'staffName': widget.staffName,
              'action':
                  'data_status_${dataStatus.toLowerCase().replaceAll(' ', '_')}',
              'at': Timestamp.now(),
            },
          ]),
        });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data status changed to $dataStatus')),
    );
  }

  void _editRecord(String documentId, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _HAIReportFormScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          staffName: widget.staffName,
          infectionType: data['infectionType'] as String? ?? 'Routine HAI',
          surveillanceType:
              data['surveillanceType'] as String? ??
              ((data['infectionType'] == 'Routine HAI')
                  ? 'Routine HAI Surveillance'
                  : 'Targeted HAI Surveillance'),
          documentId: documentId,
          initialData: data,
          allowFinalEdit: true,
        ),
      ),
    );
  }

  Future<void> _deleteHaiRecord(String documentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete HAI record'),
        content: const Text('Delete this HAI surveillance record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('hai_surveillance')
          .doc(documentId)
          .delete();
    }
  }

  List<String> _haiFilterOptions(
    List<QueryDocumentSnapshot> docs,
    String Function(Map<String, dynamic> data) selector,
  ) {
    final values =
        docs
            .map((doc) => selector(doc.data() as Map<String, dynamic>))
            .where((value) => value.trim().isNotEmpty && value != '-')
            .toSet()
            .toList()
          ..sort();
    return ['All', ...values];
  }

  String _haiDepartmentOf(Map<String, dynamic> data) {
    final labels = data['haiQuestionnaireResponseLabels'] is Map
        ? Map<String, dynamic>.from(
            data['haiQuestionnaireResponseLabels'] as Map,
          )
        : const <String, dynamic>{};
    final responses = data['haiQuestionnaireResponses'] is Map
        ? Map<String, dynamic>.from(data['haiQuestionnaireResponses'] as Map)
        : const <String, dynamic>{};
    return '${labels['Department'] ?? responses['Department'] ?? data['department'] ?? '-'}';
  }

  String _haiWardOf(Map<String, dynamic> data) {
    final labels = data['haiQuestionnaireResponseLabels'] is Map
        ? Map<String, dynamic>.from(
            data['haiQuestionnaireResponseLabels'] as Map,
          )
        : const <String, dynamic>{};
    final responses = data['haiQuestionnaireResponses'] is Map
        ? Map<String, dynamic>.from(data['haiQuestionnaireResponses'] as Map)
        : const <String, dynamic>{};
    const wardFields = [
      '_3_Surgical_Wards',
      '_4_Medical_Wards',
      '_5_O_G_Wards',
      '_6_Paediatric_Wards',
      '_7_Other_Wards',
      'ward',
      'unit',
    ];
    for (final field in wardFields) {
      final value = labels[field] ?? responses[field] ?? data[field];
      if (value != null && '$value'.trim().isNotEmpty) return '$value';
    }
    return '${data['ward'] ?? data['unit'] ?? '-'}';
  }

  bool _matchesHaiDateRange(Map<String, dynamic> data) {
    if (_haiStartDate == null && _haiEndDate == null) return true;
    bool matches(DateTime? date) {
      if (date == null) return false;
      if (_haiStartDate != null && date.isBefore(_startOfDay(_haiStartDate!))) {
        return false;
      }
      if (_haiEndDate != null && date.isAfter(_endOfDay(_haiEndDate!))) {
        return false;
      }
      return true;
    }

    final admissionDate = _haiAdmissionDate(data);
    final sampleDate = _haiSampleCollectionDate(data);
    switch (_haiDateRangeBasis) {
      case 'sample':
        return matches(sampleDate);
      case 'both':
        return matches(admissionDate) || matches(sampleDate);
      case 'admission':
      default:
        return matches(admissionDate);
    }
  }

  Future<void> _pickHaiDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _haiStartDate == null && _haiEndDate == null
          ? null
          : DateTimeRange(
              start: _haiStartDate ?? _haiEndDate!,
              end: _haiEndDate ?? _haiStartDate!,
            ),
    );
    if (picked == null) return;
    setState(() {
      _haiStartDate = picked.start;
      _haiEndDate = picked.end;
      _showAllRoutineHaiData = false;
      _showAllTargetedHaiData = false;
    });
  }

  String _haiDateRangeLabel() {
    if (_haiStartDate == null && _haiEndDate == null) return 'Date range';
    final formatter = DateFormat('dd/MM/yyyy');
    final start = _haiStartDate == null
        ? 'Start'
        : formatter.format(_haiStartDate!);
    final end = _haiEndDate == null ? 'End' : formatter.format(_haiEndDate!);
    return '$start - $end';
  }

  Future<void> _updateSelectedHaiStatus() async {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in _selectedHaiRecordIds) {
      batch.update(
        FirebaseFirestore.instance.collection('hai_surveillance').doc(id),
        {
          'dataStatus': _selectedDataStatus,
          'dataStatusUpdatedAt': FieldValue.serverTimestamp(),
          'dataStatusUpdatedById': widget.staffId,
          'dataStatusUpdatedBy': widget.staffName,
          'lastUpdatedById': widget.staffId,
          'lastUpdatedBy': widget.staffName,
          'updatedAt': FieldValue.serverTimestamp(),
          'changeHistory': FieldValue.arrayUnion([
            {
              'staffId': widget.staffId,
              'staffName': widget.staffName,
              'action':
                  'data_status_${_selectedDataStatus.toLowerCase().replaceAll(' ', '_')}',
              'at': Timestamp.now(),
            },
          ]),
        },
      );
    }
    await batch.commit();
    setState(() => _selectedHaiRecordIds.clear());
  }

  Map<String, dynamic> _fullHaiDisplayFields(Map<String, dynamic> data) {
    final responses = data['haiQuestionnaireResponses'] is Map
        ? Map<String, dynamic>.from(data['haiQuestionnaireResponses'] as Map)
        : const <String, dynamic>{};
    final labels = data['haiQuestionnaireResponseLabels'] is Map
        ? Map<String, dynamic>.from(
            data['haiQuestionnaireResponseLabels'] as Map,
          )
        : const <String, dynamic>{};
    return {
      'Form ID': data['formId'],
      'Data status': data['dataStatus'] ?? 'Raw Data',
      'Submission status': data['submissionStatus'] ?? 'Final',
      'Created by staff ID': data['createdById'] ?? data['reportedById'],
      'Last edited by staff ID': data['lastUpdatedById'],
      'Finalized by staff ID': data['finalizedById'],
      for (final field in haiQuestionnaireFields)
        field.label: labels[field.name] ?? responses[field.name] ?? '-',
    };
  }

  List<String> _fullHaiExportHeaders() {
    return [
      'Form ID',
      'Data status',
      'Submission status',
      'Created by staff ID',
      'Last edited by staff ID',
      'Finalized by staff ID',
      ...haiQuestionnaireFields.map((field) => field.label),
    ];
  }

  Map<String, dynamic> _fullHaiExportRow(Map<String, dynamic> data) {
    final responses = data['haiQuestionnaireResponses'] is Map
        ? Map<String, dynamic>.from(data['haiQuestionnaireResponses'] as Map)
        : const <String, dynamic>{};
    final labels = data['haiQuestionnaireResponseLabels'] is Map
        ? Map<String, dynamic>.from(
            data['haiQuestionnaireResponseLabels'] as Map,
          )
        : const <String, dynamic>{};
    return {
      'Form ID': data['formId'],
      'Data status': data['dataStatus'] ?? 'Raw Data',
      'Submission status': data['submissionStatus'] ?? 'Final',
      'Created by staff ID': data['createdById'] ?? data['reportedById'],
      'Last edited by staff ID': data['lastUpdatedById'],
      'Finalized by staff ID': data['finalizedById'],
      for (final field in haiQuestionnaireFields)
        field.label: _formatHaiExportValue(
          labels[field.name] ?? responses[field.name],
        ),
    };
  }

  String _formatHaiExportValue(Object? value) {
    if (value is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(value.toDate());
    }
    if (value is List) return value.join('; ');
    if (value is Map) return jsonEncode(value);
    return '${value ?? ''}';
  }

  Future<void> _openHaiExportDialog(List<QueryDocumentSnapshot> docs) async {
    final selectedFormat = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export selected HAI data'),
        content: const Text('Choose the format to export.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'excel'),
            child: const Text('Excel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'csv'),
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'pdf'),
            child: const Text('PDF'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'word'),
            child: const Text('Word doc'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selectedFormat == null) return;
    await _exportHaiData(docs, selectedFormat);
  }

  Future<void> _exportHaiData(
    List<QueryDocumentSnapshot> docs,
    String format,
  ) async {
    final selectedDocs = docs
        .where((doc) => _selectedHaiRecordIds.contains(doc.id))
        .toList();
    if (selectedDocs.isEmpty) return;
    final headers = _fullHaiExportHeaders();
    final rows = selectedDocs
        .map((doc) => _fullHaiExportRow(doc.data() as Map<String, dynamic>))
        .toList();
    late final Uint8List bytes;
    late final String fileName;
    late final String mimeType;
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    if (format == 'pdf') {
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (context) => [
            pw.Text(
              'HAI Surveillance Data Export',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Records: ${rows.length}'),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows
                  .map((row) => headers.map((header) => row[header]).toList())
                  .toList(),
              cellStyle: const pw.TextStyle(fontSize: 5),
              headerStyle: pw.TextStyle(
                fontSize: 5,
                fontWeight: pw.FontWeight.bold,
              ),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ],
        ),
      );
      bytes = await doc.save();
      fileName = 'hai_surveillance_$stamp.pdf';
      mimeType = 'application/pdf';
    } else if (format == 'word' || format == 'excel') {
      final html = StringBuffer()
        ..writeln('<html><head><meta charset="utf-8"></head><body>')
        ..writeln('<h1>HAI Surveillance Data Export</h1>')
        ..writeln('<p>Records: ${rows.length}</p>')
        ..writeln('<table border="1" cellspacing="0" cellpadding="4">')
        ..writeln(
          '<tr>${headers.map((header) => '<th>${_htmlEscape(header)}</th>').join()}</tr>',
        );
      for (final row in rows) {
        html.writeln(
          '<tr>${headers.map((header) => '<td>${_htmlEscape('${row[header] ?? ''}')}</td>').join()}</tr>',
        );
      }
      html.writeln('</table></body></html>');
      bytes = Uint8List.fromList(utf8.encode(html.toString()));
      fileName = format == 'word'
          ? 'hai_surveillance_$stamp.doc'
          : 'hai_surveillance_$stamp.xls';
      mimeType = format == 'word'
          ? 'application/msword'
          : 'application/vnd.ms-excel';
    } else {
      final csv = StringBuffer()..writeln(headers.map(_csvCell).join(','));
      for (final row in rows) {
        csv.writeln(headers.map((header) => _csvCell(row[header])).join(','));
      }
      bytes = Uint8List.fromList(utf8.encode(csv.toString()));
      fileName = 'hai_surveillance_$stamp.csv';
      mimeType = 'text/csv';
    }
    final storagePath =
        'ipc_surveillance_downloads/${widget.facilityId}/hai/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await FirebaseStorage.instance
        .ref(storagePath)
        .putData(bytes, SettableMetadata(contentType: mimeType));
    final downloadRef = await FirebaseFirestore.instance
        .collection('surveillance_downloads')
        .add({
          'facilityId': widget.facilityId,
          'downloadType': 'hai_excel',
          'name': fileName,
          'storagePath': storagePath,
          'mimeType': mimeType,
          'recordCount': selectedDocs.length,
          'createdById': widget.staffId,
          'createdBy': widget.staffName,
          'downloadedAt': FieldValue.serverTimestamp(),
        });
    await Share.shareXFiles([
      XFile.fromData(bytes, mimeType: mimeType, name: fileName),
    ]);
    setState(() {
      _haiDownloads.insert(
        0,
        _DownloadedReport(
          id: downloadRef.id,
          name: fileName,
          downloadedAt: DateTime.now(),
          recordCount: selectedDocs.length,
          bytes: bytes,
          mimeType: mimeType,
          storagePath: storagePath,
        ),
      );
    });
  }

  Future<void> _loadHaiDownloads() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('surveillance_downloads')
          .where('facilityId', isEqualTo: widget.facilityId)
          .get();
      final downloads =
          snapshot.docs
              .where((doc) => doc.data()['downloadType'] == 'hai_excel')
              .map((doc) {
                final data = doc.data();
                final timestamp = data['downloadedAt'];
                return _DownloadedReport(
                  id: doc.id,
                  name: '${data['name'] ?? 'hai_surveillance_download.csv'}',
                  downloadedAt: timestamp is Timestamp
                      ? timestamp.toDate()
                      : DateTime.now(),
                  recordCount: data['recordCount'] is int
                      ? data['recordCount'] as int
                      : int.tryParse('${data['recordCount']}') ?? 0,
                  mimeType: '${data['mimeType'] ?? 'text/csv'}',
                  storagePath: '${data['storagePath'] ?? ''}',
                );
              })
              .toList()
            ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
      if (!mounted) return;
      setState(() {
        _haiDownloads
          ..clear()
          ..addAll(downloads);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load saved HAI downloads')),
      );
    }
  }

  Future<void> _downloadSavedHaiExcel(_DownloadedReport download) async {
    try {
      final bytes =
          download.bytes ??
          (download.storagePath == null || download.storagePath!.isEmpty
              ? null
              : await FirebaseStorage.instance
                    .ref(download.storagePath!)
                    .getData(20 * 1024 * 1024));
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloaded file could not be found')),
        );
        return;
      }
      await Share.shareXFiles([
        XFile.fromData(
          bytes,
          mimeType: download.mimeType ?? 'text/csv',
          name: download.name,
        ),
      ]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to download saved HAI Excel')),
      );
    }
  }

  Future<void> _deleteSavedHaiDownload(_DownloadedReport download) async {
    if (download.id != null) {
      await FirebaseFirestore.instance
          .collection('surveillance_downloads')
          .doc(download.id)
          .delete();
    }
    if (download.storagePath != null && download.storagePath!.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref(download.storagePath!).delete();
      } catch (_) {
        // The list entry is still removed even if the old storage object is missing.
      }
    }
    if (!mounted) return;
    setState(() => _haiDownloads.remove(download));
  }

  Future<void> _submitHaiReportForApproval({
    required _HaiGeneratedReport report,
    required List<String> selectedRecordIds,
  }) async {
    try {
      final reference = await FirebaseFirestore.instance
          .collection('hai_report_approvals')
          .add({
            'facilityId': widget.facilityId,
            'facilityName': widget.facilityName,
            'title': report.title,
            'reportStatus': 'submitted',
            'status': 'Submitted',
            'reportDate': Timestamp.fromDate(report.options.reportDate),
            'reportMonth': report.options.month,
            'reportPeriod': report.options.period,
            'reportBasis': report.options.basis,
            'surveillanceType': report.options.surveillanceType,
            'reportDateBasis': report.options.dateBasis,
            'selectedRecordIds': selectedRecordIds,
            'recordCount': report.totalRecords,
            'denominatorWarnings': _haiReportDenominatorWarnings(report),
            'initiatedById': widget.staffId,
            'initiatedByName': widget.staffName,
            'submittedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'reportData': report.toApprovalMap(),
            'auditTrail': [
              {
                'action': 'submitted',
                'staffId': widget.staffId,
                'staffName': widget.staffName,
                'at': Timestamp.now(),
              },
            ],
          });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'HAI report sent for approval. Reference: ${reference.id}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to submit report for approval: $error')),
      );
    }
  }

  String _haiReportScopeLabel(String scope) {
    switch (scope) {
      case 'laboratory':
        return 'Laboratory-based HAI Report';
      case 'clinical':
        return 'Clinical-based HAI Report';
      case 'both':
        return 'Laboratory and Clinical-based HAI Report';
      default:
        return 'HAI Report';
    }
  }

  List<String> _defaultHaiReportSections(String scope) {
    if (scope == 'laboratory') {
      return const ['overall_summary', 'hai_by_ward', 'microbiology_profile'];
    }
    if (scope == 'clinical') {
      return const [
        'overall_summary',
        'targeted_non_device',
        'device_incidence',
        'microbiology_profile',
        'antimicrobial_profile',
        'resistance_profile',
        'outcome_summary',
        'trend_status',
      ];
    }
    return const [
      'overall_summary',
      'hai_by_ward',
      'microbiology_profile',
      'targeted_non_device',
      'device_incidence',
      'antimicrobial_profile',
      'resistance_profile',
      'outcome_summary',
      'trend_status',
    ];
  }

  List<String> _defaultHaiSummaryMetrics(String scope) {
    final metrics = <String>[
      'selected_records',
      'unique_patients',
      'total_non_device',
      if (scope != 'laboratory') 'total_device',
      'total_hai',
      if (scope != 'laboratory') 'total_patient_days',
      'total_discharges',
      'overall_percentage',
      if (scope != 'laboratory') 'overall_rate',
      'top_ward',
      'top_hai_type',
      'total_positive_isolates',
      'top_organism',
    ];
    return metrics;
  }

  List<_HaiReportChoice> _haiReportSectionOptions(String scope) {
    final options = <_HaiReportChoice>[
      const _HaiReportChoice('overall_summary', 'Overall summary'),
      const _HaiReportChoice('hai_by_ward', 'HAI by ward & infection type'),
      const _HaiReportChoice('microbiology_profile', 'Microbiology profile'),
    ];
    if (scope != 'laboratory') {
      options.addAll(const [
        _HaiReportChoice(
          'targeted_non_device',
          'Targeted non-device HAI rates',
        ),
        _HaiReportChoice('device_incidence', 'Device-associated HAI rates'),
        _HaiReportChoice('antimicrobial_profile', 'Antimicrobial profile'),
        _HaiReportChoice('resistance_profile', 'Resistance profile'),
        _HaiReportChoice('outcome_summary', 'Patient outcome summary'),
        _HaiReportChoice('trend_status', 'Trend status'),
      ]);
    }
    return options;
  }

  List<_HaiReportChoice> _haiSummaryMetricOptions(String scope) {
    final options = <_HaiReportChoice>[
      const _HaiReportChoice('selected_records', 'Selected records'),
      const _HaiReportChoice(
        'unique_patients',
        'Unique HAI patients/admissions',
      ),
      const _HaiReportChoice('total_non_device', 'Total non-device HAI cases'),
      const _HaiReportChoice(
        'total_device',
        'Total device-associated HAI cases',
      ),
      const _HaiReportChoice('total_hai', 'Total HAI cases'),
      const _HaiReportChoice('total_patient_days', 'Total patient-days'),
      const _HaiReportChoice('total_discharges', 'Total discharges'),
      const _HaiReportChoice('overall_percentage', 'Overall HAI percentage'),
      const _HaiReportChoice('overall_rate', 'Overall HAI rate'),
      const _HaiReportChoice('top_ward', 'Most affected ward/unit'),
      const _HaiReportChoice('top_hai_type', 'Most common HAI type'),
      const _HaiReportChoice(
        'total_positive_isolates',
        'Total positive isolates',
      ),
      const _HaiReportChoice('top_organism', 'Most common organism'),
    ];
    if (scope != 'laboratory') {
      options.addAll(const [
        _HaiReportChoice('cauti', 'CAUTI cases, percent and rate'),
        _HaiReportChoice('clabsi', 'CLABSI cases, percent and rate'),
        _HaiReportChoice('plabsi', 'PLABSI cases, percent and rate'),
        _HaiReportChoice('vap', 'VAP cases, percent and rate'),
        _HaiReportChoice('catheter_utilization', 'Catheter utilization ratio'),
        _HaiReportChoice(
          'central_line_utilization',
          'Central line utilization ratio',
        ),
        _HaiReportChoice(
          'ventilator_utilization',
          'Ventilator utilization ratio',
        ),
        _HaiReportChoice(
          'top_device_infection',
          'Most common device infection',
        ),
        _HaiReportChoice(
          'patients_on_antimicrobials',
          'Patients on antimicrobials',
        ),
        _HaiReportChoice('top_antimicrobial', 'Most common antimicrobial'),
        _HaiReportChoice('mdr', 'Overall MDR proportion'),
        _HaiReportChoice('esbl', 'Overall ESBL proportion'),
        _HaiReportChoice('carbapenem', 'Overall carbapenem resistance'),
        _HaiReportChoice('mrsa', 'MRSA proportion'),
        _HaiReportChoice('vre', 'VRE proportion'),
        _HaiReportChoice('hai_deaths', 'HAI-contributed deaths'),
      ]);
    }
    return options;
  }

  bool _haiReportIncludes(_HaiGeneratedReport report, String sectionId) =>
      report.options.sectionIds.contains(sectionId);

  Future<void> _openGenerateHaiReportDialog(
    List<QueryDocumentSnapshot> docs,
  ) async {
    final selectedDocs = docs
        .where((doc) => _selectedHaiRecordIds.contains(doc.id))
        .toList();
    final selectedRows = selectedDocs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
    if (selectedRows.isEmpty) return;

    var reportDate = DateTime.now();
    var selectedMonth = DateTime.now().month;
    var reportPeriod = 'Monthly report';
    var reportDateBasis = 'admission';
    var reportScope = 'both';
    var outputFormat = 'PDF';
    var preview = false;
    var selectedSectionIds = _defaultHaiReportSections(reportScope).toSet();
    var selectedSummaryMetricIds = _defaultHaiSummaryMetrics(
      reportScope,
    ).toSet();
    final selectedRoutineCount = selectedRows.where(_isRoutineHaiRow).length;
    final selectedTargetedCount = selectedRows.length - selectedRoutineCount;
    final remarksController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          selectedMonth = _normalizedHaiReportPeriodMonth(
            selectedMonth,
            reportPeriod,
          );
          final filteredRows = selectedRows.where((row) {
            return _haiReportRowMatchesDateBasis(
              row,
              reportDate,
              selectedMonth,
              reportPeriod,
              reportDateBasis,
            );
          }).toList();
          final options = _HaiReportOptions(
            reportDate: reportDate,
            month: selectedMonth,
            period: reportPeriod,
            basis: _haiReportScopeLabel(reportScope),
            surveillanceType: reportScope,
            reportScope: reportScope,
            sectionIds: selectedSectionIds,
            summaryMetricIds: selectedSummaryMetricIds,
            outputFormat: outputFormat,
            dateBasis: reportDateBasis,
          );
          return AlertDialog(
            title: const Text('HAI Dashboard'),
            content: SizedBox(
              width: 780,
              child: ListView(
                shrinkWrap: true,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 270,
                        child: DropdownButtonFormField<String>(
                          value: reportDateBasis,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Read date from',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'admission',
                              child: Text('Admission date'),
                            ),
                            DropdownMenuItem(
                              value: 'sample',
                              child: Text('Sample collection date'),
                            ),
                            DropdownMenuItem(
                              value: 'both',
                              child: Text('Admission or sample date'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => reportDateBasis = value);
                            }
                          },
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: reportDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() => reportDate = picked);
                          }
                        },
                        icon: const Icon(Icons.event),
                        label: Text(DateFormat('MMM d, y').format(reportDate)),
                      ),
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<int>(
                          value: selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Period',
                            border: OutlineInputBorder(),
                          ),
                          items: _haiReportPeriodItems(
                            reportDate.year,
                            reportPeriod,
                            selectedMonth,
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedMonth = value);
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: 190,
                        child: DropdownButtonFormField<String>(
                          value: reportPeriod,
                          decoration: const InputDecoration(
                            labelText: 'Report period',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Monthly report',
                              child: Text('Monthly report'),
                            ),
                            DropdownMenuItem(
                              value: 'Quarterly report',
                              child: Text('Quarterly report'),
                            ),
                            DropdownMenuItem(
                              value: 'Mid-year report',
                              child: Text('Mid-year report'),
                            ),
                            DropdownMenuItem(
                              value: 'Annual report',
                              child: Text('Annual report'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                reportPeriod = value;
                                selectedMonth = _normalizedHaiReportPeriodMonth(
                                  selectedMonth,
                                  reportPeriod,
                                );
                              });
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          value: reportScope,
                          decoration: const InputDecoration(
                            labelText: 'Report type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'laboratory',
                              child: Text('Laboratory-based'),
                            ),
                            DropdownMenuItem(
                              value: 'clinical',
                              child: Text('Clinical-based'),
                            ),
                            DropdownMenuItem(
                              value: 'both',
                              child: Text('Both'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                reportScope = value;
                                selectedSectionIds = _defaultHaiReportSections(
                                  value,
                                ).toSet();
                                selectedSummaryMetricIds =
                                    _defaultHaiSummaryMetrics(value).toSet();
                              });
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: DropdownButtonFormField<String>(
                          value: outputFormat,
                          decoration: const InputDecoration(
                            labelText: 'Print as',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                            DropdownMenuItem(
                              value: 'Word doc',
                              child: Text('Word doc'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => outputFormat = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${filteredRows.length} of ${selectedRows.length} selected HAI records match this report period using ${_haiReportDateBasisLabel(reportDateBasis).toLowerCase()}.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  Text(
                    'Selected data mix: $selectedRoutineCount routine, $selectedTargetedCount targeted.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Report sections',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _haiReportSectionOptions(reportScope).map((
                      option,
                    ) {
                      return SizedBox(
                        width: 330,
                        child: CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selectedSectionIds.contains(option.id),
                          title: Text(option.label),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selectedSectionIds.add(option.id);
                              } else {
                                selectedSectionIds.remove(option.id);
                              }
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  if (selectedSectionIds.contains('overall_summary')) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Overall summary indicators',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _haiSummaryMetricOptions(reportScope).map((
                        option,
                      ) {
                        return SizedBox(
                          width: 330,
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: selectedSummaryMetricIds.contains(option.id),
                            title: Text(option.label),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  selectedSummaryMetricIds.add(option.id);
                                } else {
                                  selectedSummaryMetricIds.remove(option.id);
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.storage_outlined),
                    title: const Text(
                      'Denominator data are automatically retrieved from the Ward Denominator table under Surveillance Data.',
                    ),
                    trailing: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _ReportsListScreen(
                            title: 'Ward Denominator Data',
                            collection: 'ward_denominators',
                            facilityId: widget.facilityId,
                            facilityName: widget.facilityName,
                          ),
                        ),
                      ),
                      child: const Text('View denominator data'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Summary / remarks',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: filteredRows.isEmpty
                          ? null
                          : () async {
                              final suggestion =
                                  await _generateHaiReportRemarksSuggestion(
                                    filteredRows,
                                    options,
                                  );
                              if (suggestion.trim().isNotEmpty) {
                                remarksController.text = suggestion;
                              }
                            },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('AI summary suggestion'),
                    ),
                  ),
                  if (preview) ...[
                    const Divider(height: 28),
                    FutureBuilder<_HaiGeneratedReport>(
                      future: _buildGeneratedHaiReport(
                        filteredRows,
                        options,
                        remarksController.text,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Text('Unable to preview: ${snapshot.error}');
                        }
                        final report = snapshot.data;
                        if (report == null) return const SizedBox.shrink();
                        return _haiGeneratedReportPreview(report);
                      },
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
              TextButton(
                onPressed: filteredRows.isEmpty
                    ? null
                    : () => setDialogState(() => preview = true),
                child: const Text('Preview dashboard'),
              ),
              OutlinedButton.icon(
                onPressed: filteredRows.isEmpty
                    ? null
                    : () async {
                        final report = await _buildGeneratedHaiReport(
                          filteredRows,
                          options,
                          remarksController.text,
                        );
                        await _submitHaiReportForApproval(
                          report: report,
                          selectedRecordIds: selectedDocs
                              .map((doc) => doc.id)
                              .toList(),
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Send for approval'),
              ),
              FilledButton.icon(
                onPressed: filteredRows.isEmpty
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Generate printable HAI report?'),
                            content: const Text(
                              'The report will be generated from the selected HAI data and available ward denominator records.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Generate'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        final report = await _buildGeneratedHaiReport(
                          filteredRows,
                          options,
                          remarksController.text,
                        );
                        if (outputFormat == 'Word doc') {
                          await _shareGeneratedHaiReportDoc(report);
                        } else {
                          await _shareGeneratedHaiReportPdf(report);
                        }
                      },
                icon: const Icon(Icons.print_outlined),
                label: const Text('Export / print report'),
              ),
            ],
          );
        },
      ),
    );
    remarksController.dispose();
  }

  bool _haiReportRowMatchesDateBasis(
    Map<String, dynamic> row,
    DateTime reportDate,
    int selectedMonth,
    String reportPeriod,
    String dateBasis,
  ) {
    bool matches(DateTime? date) {
      if (date == null) return false;
      return _dateMatchesHaiReportPeriod(
        date,
        reportDate,
        selectedMonth,
        reportPeriod,
      );
    }

    final admissionDate = _haiAdmissionDate(row);
    final sampleDate = _haiSampleCollectionDate(row);
    switch (dateBasis) {
      case 'sample':
        return matches(sampleDate);
      case 'both':
        return matches(admissionDate) || matches(sampleDate);
      case 'admission':
      default:
        return matches(admissionDate);
    }
  }

  DateTime? _haiAdmissionDate(Map<String, dynamic> row) {
    return _haiDateAny(
      row,
      keys: const [
        '_8_Date_of_admission',
        '_12_Date_of_Admission',
        'Date_of_admission',
        'Date_of_Admission',
        'Admission_Date',
        'admissionDate',
      ],
      questionNumbers: const ['8', '12'],
      labelContains: const [
        'date of admission',
        'admission date',
        'date admitted',
        'hospital admission date',
      ],
    );
  }

  DateTime? _haiSampleCollectionDate(Map<String, dynamic> row) {
    return _haiDateAny(
      row,
      keys: const [
        '_57_Date_of_sample_collection',
        '_83_Date_of_sample_collection_2',
        'Date_of_sample_collection',
        'Sample_collection_date',
        'sampleCollectionDate',
      ],
      questionNumbers: const ['57', '83'],
      labelContains: const [
        'date of sample collection',
        'sample collection date',
        'date sample collected',
        'specimen collection date',
        'date of specimen collection',
      ],
    );
  }

  DateTime? _haiDateAny(
    Map<String, dynamic> row, {
    required List<String> keys,
    List<String> questionNumbers = const [],
    List<String> labelContains = const [],
  }) {
    final dates = row['haiQuestionnaireDates'] is Map
        ? Map<String, dynamic>.from(row['haiQuestionnaireDates'] as Map)
        : const <String, dynamic>{};
    final responses = row['haiQuestionnaireResponses'] is Map
        ? Map<String, dynamic>.from(row['haiQuestionnaireResponses'] as Map)
        : const <String, dynamic>{};
    final questionLabels = row['haiQuestionnaireQuestionLabels'] is Map
        ? Map<String, dynamic>.from(
            row['haiQuestionnaireQuestionLabels'] as Map,
          )
        : const <String, dynamic>{};

    for (final key in _haiCandidateKeys(keys, questionNumbers)) {
      final parsed = _haiDateValue(dates[key] ?? responses[key] ?? row[key]);
      if (parsed != null) return parsed;
    }
    final normalizedContains = labelContains
        .map(_normalizeHaiLookupText)
        .where((item) => item.isNotEmpty)
        .toList();
    for (final entry in questionLabels.entries) {
      final prompt = '${entry.value}';
      final normalizedPrompt = _normalizeHaiLookupText(prompt);
      final numberMatch = questionNumbers.any(
        (number) => RegExp(
          r'^\s*' + RegExp.escape(number) + r'[\).\s_-]',
        ).hasMatch(prompt),
      );
      final labelMatch = normalizedContains.any(
        (needle) => _haiSemanticLabelMatches(normalizedPrompt, needle),
      );
      if (!numberMatch && !labelMatch) continue;
      final key = entry.key;
      final parsed = _haiDateValue(dates[key] ?? responses[key] ?? row[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  DateTime? _haiDateValue(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse('$value');
  }

  bool _dateMatchesHaiReportPeriod(
    DateTime date,
    DateTime reportDate,
    int selectedMonth,
    String reportPeriod,
  ) {
    if (date.year != reportDate.year) return false;
    switch (reportPeriod) {
      case 'Monthly report':
        return date.month == selectedMonth;
      case 'Quarterly report':
        final selectedQuarter = ((selectedMonth - 1) ~/ 3) + 1;
        final dateQuarter = ((date.month - 1) ~/ 3) + 1;
        return dateQuarter == selectedQuarter;
      case 'Mid-year report':
        final selectedHalf = selectedMonth <= 6 ? 1 : 2;
        final dateHalf = date.month <= 6 ? 1 : 2;
        return dateHalf == selectedHalf;
      case 'Annual report':
      default:
        return true;
    }
  }

  String _haiReportPeriodLabel(
    DateTime reportDate,
    int selectedMonth,
    String reportPeriod,
  ) {
    switch (reportPeriod) {
      case 'Monthly report':
        return '${DateFormat.MMMM().format(DateTime(reportDate.year, selectedMonth))} ${reportDate.year}';
      case 'Quarterly report':
        final quarter = ((selectedMonth - 1) ~/ 3) + 1;
        return 'Q$quarter ${reportDate.year}';
      case 'Mid-year report':
        final half = selectedMonth <= 6 ? 'January-June' : 'July-December';
        return '$half ${reportDate.year}';
      case 'Annual report':
      default:
        return '${reportDate.year}';
    }
  }

  int _normalizedHaiReportPeriodMonth(int selectedMonth, String reportPeriod) {
    switch (reportPeriod) {
      case 'Quarterly report':
        return (((selectedMonth - 1) ~/ 3) * 3) + 1;
      case 'Mid-year report':
        return selectedMonth <= 6 ? 1 : 7;
      case 'Annual report':
        return 1;
      case 'Monthly report':
      default:
        return selectedMonth.clamp(1, 12).toInt();
    }
  }

  List<DropdownMenuItem<int>> _haiReportPeriodItems(
    int reportYear,
    String reportPeriod,
    int selectedMonth,
  ) {
    switch (reportPeriod) {
      case 'Quarterly report':
        return const [
          DropdownMenuItem(value: 1, child: Text('Q1')),
          DropdownMenuItem(value: 4, child: Text('Q2')),
          DropdownMenuItem(value: 7, child: Text('Q3')),
          DropdownMenuItem(value: 10, child: Text('Q4')),
        ];
      case 'Mid-year report':
        return const [
          DropdownMenuItem(value: 1, child: Text('Jan-Jun')),
          DropdownMenuItem(value: 7, child: Text('Jul-Dec')),
        ];
      case 'Annual report':
        return [
          DropdownMenuItem(value: selectedMonth, child: Text('$reportYear')),
        ];
      case 'Monthly report':
      default:
        return List.generate(
          12,
          (index) => DropdownMenuItem(
            value: index + 1,
            child: Text(
              DateFormat.MMM().format(DateTime(reportYear, index + 1)),
            ),
          ),
        );
    }
  }

  String _haiReportDateBasisLabel(String value) {
    switch (value) {
      case 'sample':
        return 'Sample collection date';
      case 'both':
        return 'Admission or sample collection date';
      case 'admission':
      default:
        return 'Admission date';
    }
  }

  Widget _haiGeneratedReportPreview(_HaiGeneratedReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(report.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          'Date basis: ${_haiReportDateBasisLabel(report.options.dateBasis)}',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            _haiSummaryCard('Records', '${report.totalRecords}', Colors.red),
            _haiSummaryCard(
              'HAI cases',
              '${report.totalHaiCases}',
              Colors.orange,
            ),
            _haiSummaryCard(
              'Patient-days',
              '${report.totalPatientDays}',
              Colors.blue,
            ),
            _haiSummaryCard(
              'HAI rate',
              '${report.overallRateLabel} / 1,000',
              Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._haiReportPreviewSections(report),
      ],
    );
  }

  List<Widget> _haiReportPreviewSections(_HaiGeneratedReport report) {
    final widgets = <Widget>[];
    void add(Widget widget) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
      widgets.add(widget);
    }

    if (_haiReportIncludes(report, 'overall_summary')) {
      add(_haiOverallSummaryTable(report));
    }
    if (_haiReportIncludes(report, 'hai_by_ward')) {
      add(_haiLabWardTable(report.labWardRows));
      add(_haiNonDeviceKeyFindings(report.labWardRows));
    }
    if (_haiReportIncludes(report, 'microbiology_profile')) {
      add(_haiMicrobiologyProfileTable(report.microbiologyRows));
    }
    if (report.options.reportScope == 'both' &&
        widgets.isNotEmpty &&
        _haiReportSectionOptions('clinical').any(
          (option) =>
              option.id != 'overall_summary' &&
              report.options.sectionIds.contains(option.id),
        )) {
      add(const Divider(height: 24));
    }
    if (_haiReportIncludes(report, 'targeted_non_device')) {
      add(_haiTargetedNonDeviceTable(report.clinicalIncidenceRows));
    }
    if (_haiReportIncludes(report, 'device_incidence')) {
      add(_haiDeviceIncidenceTable(report.deviceIncidenceRows));
      add(_haiDeviceKeyFindings(report.deviceIncidenceRows));
    }
    if (_haiReportIncludes(report, 'antimicrobial_profile')) {
      add(_haiAntimicrobialPrescriptionTable(report));
    }
    if (_haiReportIncludes(report, 'resistance_profile')) {
      add(_haiResistanceProfileTable(report.resistanceRows));
    }
    if (_haiReportIncludes(report, 'outcome_summary')) {
      add(_haiOutcomeSummaryTable(report));
    }
    if (_haiReportIncludes(report, 'trend_status')) {
      add(_haiTrendStatusTable(report));
    }
    return widgets;
  }

  Widget _haiOverallSummaryTable(_HaiGeneratedReport report) {
    return _compactHaiTable('Overall HAI Surveillance Summary', const [
      'Indicator',
      'Value',
      'Indicator',
      'Value',
    ], _haiOverallSummaryGridRows(report));
  }

  Widget _haiOutcomeSummaryTable(_HaiGeneratedReport report) {
    return _compactHaiTable('Patient Outcome Summary', [
      'Outcome',
      'Unique patients',
      'Percent',
    ], _haiOutcomeRows(report));
  }

  Widget _haiTrendStatusTable(_HaiGeneratedReport report) {
    return _compactHaiTable('Trend Status', const [
      'Component',
      'Current result',
      'Status',
    ], _haiTrendRows(report));
  }

  Widget _haiLabWardTable(List<_HaiLabWardRow> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HAI by Ward and Infection Type',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Ward')),
              DataColumn(label: Text('No. Discharges')),
              DataColumn(label: Text('No. Culture Request')),
              DataColumn(label: Text('No. of HAIs')),
              DataColumn(label: Text('Overall % of HAIs in the Hospital')),
              DataColumn(label: Text('% of HAIs per Ward/Unit')),
              DataColumn(label: Text('Surgical Site')),
              DataColumn(label: Text('Skin & Soft Tissue')),
              DataColumn(label: Text('HAP')),
              DataColumn(label: Text('BSI')),
              DataColumn(label: Text('UTI')),
              DataColumn(label: Text('Others')),
              DataColumn(label: Text('No. of infected patients')),
            ],
            rows: _haiLabWardTableRows(rows)
                .map(
                  (row) => DataRow(
                    cells: row.map((cell) => DataCell(Text('$cell'))).toList(),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  List<String> _haiLabWardHeaders() => const [
    'Ward',
    'No. Discharges',
    'No. Culture Request',
    'No. of HAIs',
    'Overall % of HAIs in the Hospital',
    '% of HAIs per Ward/Unit',
    'Surgical Site',
    'Skin & Soft Tissue',
    'HAP',
    'BSI',
    'UTI',
    'Others',
    'No. of infected patients',
  ];

  List<List<Object>> _haiLabWardTableRows(List<_HaiLabWardRow> rows) {
    final totalDischarges = rows.fold<int>(
      0,
      (sum, row) => sum + row.discharges,
    );
    final totalCultureRequests = rows.fold<int>(
      0,
      (sum, row) => sum + row.cultureRequests,
    );
    final totalHai = rows.fold<int>(
      0,
      (sum, row) => sum + row.infectionSiteTotal,
    );
    final totalSsi = rows.fold<int>(0, (sum, row) => sum + row.ssi);
    final totalSst = rows.fold<int>(0, (sum, row) => sum + row.sst);
    final totalRti = rows.fold<int>(0, (sum, row) => sum + row.rti);
    final totalBsi = rows.fold<int>(0, (sum, row) => sum + row.bsi);
    final totalUti = rows.fold<int>(0, (sum, row) => sum + row.uti);
    final totalOthers = rows.fold<int>(
      0,
      (sum, row) => sum + row.git + row.neonatalSepsis + row.others,
    );
    final totalInfected = totalHai;
    String percent(int numerator, int denominator) => denominator == 0
        ? '0.0'
        : ((numerator / denominator) * 100).toStringAsFixed(1);
    return [
      ...rows.map((row) {
        final infectionSiteTotal = row.infectionSiteTotal;
        return [
          row.ward,
          row.discharges,
          row.cultureRequests,
          infectionSiteTotal,
          percent(infectionSiteTotal, totalDischarges),
          percent(infectionSiteTotal, row.discharges),
          row.ssi,
          row.sst,
          row.rti,
          row.bsi,
          row.uti,
          row.git + row.neonatalSepsis + row.others,
          infectionSiteTotal,
        ];
      }),
      [
        'Total',
        totalDischarges,
        totalCultureRequests,
        totalHai,
        percent(totalHai, totalDischarges),
        '',
        totalSsi,
        totalSst,
        totalRti,
        totalBsi,
        totalUti,
        totalOthers,
        totalInfected,
      ],
      [
        'Percentage',
        '',
        '',
        '',
        percent(totalHai, totalDischarges),
        '',
        percent(totalSsi, totalHai),
        percent(totalSst, totalHai),
        percent(totalRti, totalHai),
        percent(totalBsi, totalHai),
        percent(totalUti, totalHai),
        percent(totalOthers, totalHai),
        '',
      ],
    ];
  }

  List<_HaiLabWardRow> _withHaiLabTotals(List<_HaiLabWardRow> rows) {
    final totals = rows.fold<_HaiLabWardRow>(
      _HaiLabWardRow.empty('Total'),
      (sum, row) => sum + row,
    );
    return [...rows, totals];
  }

  Widget _haiNonDeviceKeyFindings(List<_HaiLabWardRow> rows) {
    final dataRows = rows.where((row) => row.ward != 'Total').toList();
    final highestCount = dataRows.isEmpty
        ? null
        : dataRows.reduce((a, b) => a.haiCount >= b.haiCount ? a : b);
    final highestPercentage = dataRows
        .where((row) => row.discharges > 0)
        .fold<_HaiLabWardRow?>(null, (best, row) {
          if (best == null) return row;
          return row.wardPercent >= best.wardPercent ? row : best;
        });
    final highestRate = dataRows
        .where((row) => row.patientDays > 0)
        .fold<_HaiLabWardRow?>(null, (best, row) {
          if (best == null) return row;
          return row.haiRatePer1000 >= best.haiRatePer1000 ? row : best;
        });
    final totals = _withHaiLabTotals(rows).last;
    final infectionCounts = <String, int>{
      'SSI': totals.ssi,
      'Non-catheter UTI': totals.uti,
      'Non-central-line BSI': totals.bsi,
      'HAP': totals.rti,
      'Skin & Soft Tissue': totals.sst,
      'Neonatal sepsis': totals.neonatalSepsis,
      'Others': totals.others,
    };
    final mostCommon = infectionCounts.entries.fold<MapEntry<String, int>?>(
      null,
      (best, entry) => best == null || entry.value > best.value ? entry : best,
    );
    return _haiInterpretationCard(
      title: 'HAI by Ward and Infection Type key findings',
      icon: Icons.insights_outlined,
      body: [
        if (highestCount != null)
          'Highest case count: ${highestCount.ward} (${highestCount.haiCount}).',
        if (highestPercentage != null)
          'Highest HAI percentage: ${highestPercentage.ward} (${highestPercentage.wardPercent.toStringAsFixed(1)}%).',
        if (highestRate != null)
          'Highest HAI rate: ${highestRate.ward} (${highestRate.haiRatePer1000.toStringAsFixed(2)} per 1,000 patient-days).',
        if (mostCommon != null && mostCommon.value > 0)
          'Most common non-device HAI: ${mostCommon.key} (${mostCommon.value}, ${totals.haiCount == 0 ? '0.0' : ((mostCommon.value / totals.haiCount) * 100).toStringAsFixed(1)}%).',
      ].join(' '),
    );
  }

  Widget _haiPathogenSiteTable(List<_HaiPathogenSiteRow> rows) {
    return _compactHaiTable(
      'Site and Pathogens',
      const [
        'Pathogens',
        'Surgical site',
        'Skin & Soft Tissue',
        'HAP',
        'BSI',
        'UTI',
        'Others',
        'Total',
        'Percentage',
      ],
      rows
          .map(
            (row) => [
              row.pathogen,
              row.ssi,
              row.sst,
              row.rti,
              row.bsi,
              row.uti,
              row.git,
              row.others,
              row.total,
              '${row.percentage.toStringAsFixed(1)}%',
            ],
          )
          .toList(),
    );
  }

  Widget _haiMicrobiologyProfileTable(List<_HaiMicrobiologyRow> rows) {
    final total = rows.fold<int>(0, (sum, row) => sum + row.total);
    final top = rows.isEmpty
        ? null
        : rows.reduce((a, b) => a.total >= b.total ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _compactHaiTable('Microbiology Profile', const [
          'Pathogens',
          'Surgical site',
          'Skin & Soft Tissue',
          'HAP',
          'BSI',
          'UTI',
          'Others',
          'Total',
          'Percentage',
        ], _haiMicrobiologyTableRows(rows)),
        const SizedBox(height: 8),
        _haiInterpretationCard(
          title: 'Microbiology Profile key findings',
          icon: Icons.biotech_outlined,
          body: [
            'Total positive isolates: $total.',
            if (top != null)
              'Most common organism: ${top.organism} (${top.total}, ${top.percentage.toStringAsFixed(1)}%).',
            'No-growth, not-performed, and pending culture entries are excluded from the positive-isolate denominator where identifiable.',
          ].join(' '),
        ),
      ],
    );
  }

  List<List<Object>> _haiMicrobiologyTableRows(List<_HaiMicrobiologyRow> rows) {
    final totalSsi = rows.fold<int>(0, (sum, row) => sum + row.ssi);
    final totalSst = rows.fold<int>(0, (sum, row) => sum + row.sst);
    final totalRti = rows.fold<int>(0, (sum, row) => sum + row.rti);
    final totalBsi = rows.fold<int>(0, (sum, row) => sum + row.bsi);
    final totalUti = rows.fold<int>(0, (sum, row) => sum + row.uti);
    final totalOthers = rows.fold<int>(
      0,
      (sum, row) => sum + row.git + row.others,
    );
    final grandTotal = rows.fold<int>(0, (sum, row) => sum + row.total);
    String typePercent(int value) => grandTotal == 0
        ? '0.0'
        : ((value / grandTotal) * 100).toStringAsFixed(1);
    return [
      ...rows.map(
        (row) => [
          row.organism,
          row.ssi,
          row.sst,
          row.rti,
          row.bsi,
          row.uti,
          row.git + row.others,
          row.total,
          row.percentage.toStringAsFixed(1),
        ],
      ),
      [
        'Total',
        totalSsi,
        totalSst,
        totalRti,
        totalBsi,
        totalUti,
        totalOthers,
        grandTotal,
        '',
      ],
      [
        'Percentage',
        typePercent(totalSsi),
        typePercent(totalSst),
        typePercent(totalRti),
        typePercent(totalBsi),
        typePercent(totalUti),
        typePercent(totalOthers),
        '',
        '',
      ],
    ];
  }

  Widget _haiResistanceProfileTable(List<_HaiResistanceRow> rows) {
    final totals = rows.fold<_HaiResistanceAccumulator>(
      _HaiResistanceAccumulator('Overall'),
      (sum, row) => sum..addRow(row),
    );
    final tableRows = [
      ...rows.map((row) => row.toCells()),
      totals.toRow().toCells(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _compactHaiTable('Antimicrobial Resistance Profile', const [
          'Organism',
          'Total tested',
          'MDR',
          'ESBL',
          'Carbapenem-resistant',
          'MRSA',
          'VRE',
        ], tableRows),
        const SizedBox(height: 8),
        _haiInterpretationCard(
          title: 'Antimicrobial Resistance Profile key findings',
          icon: Icons.bug_report_outlined,
          body: _resistanceKeyFindings(rows, totals.toRow()),
        ),
      ],
    );
  }

  Widget _haiAntimicrobialPrescriptionTable(_HaiGeneratedReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _compactHaiTable(
          'Antimicrobial Prescription Profile',
          const ['Prescription habit', 'Count', 'Percent'],
          report.antimicrobialHabitRows
              .map((row) => [row.label, row.count, row.percentLabel])
              .toList(),
        ),
        const SizedBox(height: 12),
        _compactHaiTable(
          'Common Antimicrobials Prescribed',
          const [
            'Antimicrobial',
            'Count',
            'Percent',
            'Antimicrobial',
            'Count',
            'Percent',
          ],
          _haiTopAntimicrobialRows(report.antimicrobialAgentRows),
        ),
        const SizedBox(height: 8),
        _haiInterpretationCard(
          title: 'Antimicrobial prescribing key findings',
          icon: Icons.medication_outlined,
          body: _antimicrobialKeyFindings(report),
        ),
      ],
    );
  }

  String _antimicrobialKeyFindings(_HaiGeneratedReport report) {
    final topHabit = report.antimicrobialHabitRows.isEmpty
        ? null
        : report.antimicrobialHabitRows.first;
    final topAgent = report.antimicrobialAgentRows.isEmpty
        ? null
        : report.antimicrobialAgentRows.first;
    return [
      'Patients on antimicrobials: ${report.totalOnAntimicrobials}.',
      if (topHabit != null)
        'Most common prescription habit: ${topHabit.label} (${topHabit.count}, ${topHabit.percentLabel}).',
      if (topAgent != null)
        'Most common antimicrobial: ${topAgent.label} (${topAgent.count}, ${topAgent.percentLabel}).',
      'Review empirical prescribing, stop/review documentation, culture linkage, and targeted therapy conversion with the antimicrobial stewardship team.',
    ].join(' ');
  }

  List<List<Object>> _haiTopAntimicrobialRows(List<_HaiCountRow> rows) {
    final topTen = rows.take(10).toList();
    final left = topTen.take(5).toList();
    final right = topTen.skip(5).take(5).toList();
    return List.generate(5, (index) {
      final leftRow = index < left.length ? left[index] : null;
      final rightRow = index < right.length ? right[index] : null;
      return [
        leftRow?.label ?? '',
        leftRow?.count ?? '',
        leftRow?.percentLabel ?? '',
        rightRow?.label ?? '',
        rightRow?.count ?? '',
        rightRow?.percentLabel ?? '',
      ];
    });
  }

  String _resistanceKeyFindings(
    List<_HaiResistanceRow> rows,
    _HaiResistanceRow overall,
  ) {
    _HaiResistanceRow? topBy(int Function(_HaiResistanceRow) value) {
      final withSignal = rows.where((row) => value(row) > 0).toList();
      if (withSignal.isEmpty) return null;
      return withSignal.reduce((a, b) => value(a) >= value(b) ? a : b);
    }

    final mdr = topBy((row) => row.mdr);
    final esbl = topBy((row) => row.esbl);
    final car = topBy((row) => row.carbapenemResistant);
    return [
      if (mdr != null)
        'Most common MDR organism: ${mdr.organism} (${mdr.mdr}).',
      'Overall MDR proportion: ${overall.mdrLabel}.',
      if (esbl != null)
        'Most common ESBL-producing organism: ${esbl.organism} (${esbl.esbl}).',
      'Overall ESBL proportion: ${overall.esblLabel}.',
      if (car != null)
        'Most common carbapenem-resistant organism: ${car.organism} (${car.carbapenemResistant}).',
      'Overall carbapenem resistance proportion: ${overall.carbapenemLabel}.',
      'MRSA proportion: ${overall.mrsaLabel}.',
      'VRE proportion: ${overall.vreLabel}.',
    ].join(' ');
  }

  List<List<Object>> _haiOverallSummaryRows(_HaiGeneratedReport report) {
    final deviceTotals = _withHaiDeviceTotals(report.deviceIncidenceRows).last;
    final labTotals = _withHaiLabTotals(report.labWardRows).last;
    final topWard = report.wardTotalHaiCounts.entries
        .fold<MapEntry<String, int>?>(
          null,
          (best, entry) =>
              best == null || entry.value > best.value ? entry : best,
        );
    final topSite = _topCount(report.combinedHaiTypeCounts);
    final topDevice = _topCount({
      'CAUTI': deviceTotals.cauti,
      'CLABSI': deviceTotals.cvcHai,
      'PLABSI': deviceTotals.pvcHai,
      'VAP': deviceTotals.invHai,
    });
    final topOrganism = report.microbiologyRows.isEmpty
        ? null
        : report.microbiologyRows.reduce((a, b) => a.total >= b.total ? a : b);
    final resistanceTotals = report.resistanceRows
        .fold<_HaiResistanceAccumulator>(
          _HaiResistanceAccumulator('Overall'),
          (sum, row) => sum..addRow(row),
        )
        .toRow();
    final rows = <MapEntry<String, List<Object>>>[
      MapEntry('selected_records', ['Selected records', report.totalRecords]),
      MapEntry('unique_patients', [
        'Unique HAI patients/admissions',
        report.uniqueOutcomeDenominator,
      ]),
      MapEntry('total_non_device', [
        'Total non-device HAI cases',
        report.nonDeviceTotal,
      ]),
      MapEntry('total_device', [
        'Total device-associated HAI cases',
        report.deviceTotal,
      ]),
      MapEntry('total_hai', ['Total HAI cases', report.totalHaiCases]),
      MapEntry('total_patient_days', [
        'Total patient-days',
        report.totalPatientDays,
      ]),
      MapEntry('total_discharges', [
        'Total discharges',
        report.totalDenominator,
      ]),
      MapEntry('overall_percentage', [
        'Overall HAI percentage',
        report.overallPercentageLabel,
      ]),
      MapEntry('overall_rate', [
        'Overall HAI rate / 1,000 patient-days',
        report.overallRateLabel,
      ]),
      MapEntry('cauti', [
        'CAUTI cases, % and rate',
        '${deviceTotals.cauti} (${deviceTotals.cautiPercentLabel}; ${deviceTotals.cautiRateLabel})',
      ]),
      MapEntry('clabsi', [
        'CLABSI cases, % and rate',
        '${deviceTotals.cvcHai} (${deviceTotals.clabsiPercentLabel}; ${deviceTotals.clabsiRateLabel})',
      ]),
      MapEntry('plabsi', [
        'PLABSI cases, % and rate',
        '${deviceTotals.pvcHai} (${deviceTotals.plabsiPercentLabel}; ${deviceTotals.plabsiRateLabel})',
      ]),
      MapEntry('vap', [
        'VAP cases, % and rate',
        '${deviceTotals.invHai} (${deviceTotals.vapPercentLabel}; ${deviceTotals.vapRateLabel})',
      ]),
      MapEntry('catheter_utilization', [
        'Catheter utilization ratio',
        deviceTotals.catheterUtilizationLabel,
      ]),
      MapEntry('central_line_utilization', [
        'Central line utilization ratio',
        deviceTotals.centralLineUtilizationLabel,
      ]),
      MapEntry('ventilator_utilization', [
        'Ventilator utilization ratio',
        deviceTotals.ventilatorUtilizationLabel,
      ]),
      MapEntry('top_ward', [
        'Most affected ward/unit',
        topWard == null ? 'N/A' : '${topWard.key} (${topWard.value})',
      ]),
      MapEntry('top_hai_type', [
        'Most common HAI type',
        topSite == null ? 'N/A' : '${topSite.key} (${topSite.value})',
      ]),
      MapEntry('top_device_infection', [
        'Most common device infection',
        topDevice == null ? 'N/A' : '${topDevice.key} (${topDevice.value})',
      ]),
      MapEntry('total_positive_isolates', [
        'Total positive isolates',
        report.microbiologyRows.fold<int>(0, (sum, row) => sum + row.total),
      ]),
      MapEntry('top_organism', [
        'Most common organism',
        topOrganism == null
            ? 'N/A'
            : '${topOrganism.organism} (${topOrganism.total}, ${topOrganism.percentage.toStringAsFixed(1)}%)',
      ]),
      MapEntry('patients_on_antimicrobials', [
        'Patients on antimicrobials',
        report.totalOnAntimicrobials,
      ]),
      MapEntry('top_antimicrobial', [
        'Most common antimicrobial',
        report.antimicrobialAgentRows.isEmpty
            ? 'N/A'
            : '${report.antimicrobialAgentRows.first.label} (${report.antimicrobialAgentRows.first.count})',
      ]),
      MapEntry('mdr', ['Overall MDR proportion', resistanceTotals.mdrLabel]),
      MapEntry('esbl', ['Overall ESBL proportion', resistanceTotals.esblLabel]),
      MapEntry('carbapenem', [
        'Overall carbapenem resistance proportion',
        resistanceTotals.carbapenemLabel,
      ]),
      MapEntry('mrsa', ['MRSA proportion', resistanceTotals.mrsaLabel]),
      MapEntry('vre', ['VRE proportion', resistanceTotals.vreLabel]),
      MapEntry('hai_deaths', [
        'HAI-contributed deaths',
        report.haiContributedDeaths,
      ]),
      MapEntry('non_device_hai_total', [
        'Non-device HAI total',
        labTotals.haiCount,
      ]),
    ];
    return rows
        .where((entry) => report.options.summaryMetricIds.contains(entry.key))
        .map((entry) => entry.value)
        .toList();
  }

  List<List<Object>> _haiOverallSummaryGridRows(_HaiGeneratedReport report) {
    final rows = _haiOverallSummaryRows(report);
    final gridRows = <List<Object>>[];
    for (var index = 0; index < rows.length; index += 2) {
      final left = rows[index];
      final right = index + 1 < rows.length ? rows[index + 1] : const ['', ''];
      gridRows.add([left[0], left[1], right[0], right[1]]);
    }
    return gridRows;
  }

  List<List<Object>> _haiTrendRows(_HaiGeneratedReport report) {
    final topOrganism = report.microbiologyRows.isEmpty
        ? 'N/A'
        : '${report.microbiologyRows.first.organism} (${report.microbiologyRows.first.total})';
    return [
      [
        'Overall HAI',
        '${report.totalHaiCases} cases, ${report.overallRateLabel} per 1,000 patient-days',
        'Current reporting period only',
      ],
      [
        'Non-device HAI',
        '${report.nonDeviceTotal} cases',
        'Compare with previous approved reports when available',
      ],
      [
        'Device-associated HAI',
        '${report.deviceTotal} cases',
        'Rates use pooled denominators, not averaged ward rates',
      ],
      ['Microbiology', topOrganism, 'No-growth/pending cultures excluded'],
      [
        'Patient outcomes',
        '${report.uniqueOutcomeDenominator} unique patients/admissions',
        'Outcome percentages use unique patients/admissions',
      ],
    ];
  }

  List<String> _haiReportDenominatorWarnings(_HaiGeneratedReport report) {
    final warnings = <String>[];
    if (report.options.surveillanceType == 'targeted') {
      for (final row in report.clinicalIncidenceRows) {
        if (row.ssi > 0 && row.surgicalPatients == 0) {
          warnings.add(
            '${row.ward}: surgical-procedure denominator is required for SSI.',
          );
        }
        final patientDenominatorCases =
            row.bsi + row.uti + row.git + row.sst + row.rti + row.others;
        if (patientDenominatorCases > 0 && row.patients == 0) {
          warnings.add(
            '${row.ward}: patient denominator is required for non-device targeted HAI rates.',
          );
        }
      }
    } else {
      for (final row in report.labWardRows) {
        if (row.haiCount > 0 && row.discharges == 0) {
          warnings.add(
            '${row.ward}: discharges are required for HAI percentage.',
          );
        }
        if (row.haiCount > 0 && row.patientDays == 0) {
          warnings.add('${row.ward}: patient-days are required for HAI rate.');
        }
      }
    }
    for (final row in report.deviceIncidenceRows) {
      if (row.cauti > 0 && row.urinaryCatheter == 0) {
        warnings.add(
          '${row.ward}: urinary catheter-days are required for CAUTI rate.',
        );
      }
      if (row.cauti > 0 && row.urinaryCatheterInsertions == 0) {
        warnings.add(
          '${row.ward}: urinary catheter insertions/placements are required for CAUTI percentage.',
        );
      }
      if (row.cvcHai > 0 && row.cvc == 0) {
        warnings.add(
          '${row.ward}: central line-days are required for CLABSI rate.',
        );
      }
      if (row.cvcHai > 0 && row.cvcInsertions == 0) {
        warnings.add(
          '${row.ward}: CVC insertions/placements are required for CLABSI percentage.',
        );
      }
      if (row.pvcHai > 0 && row.pvc == 0) {
        warnings.add(
          '${row.ward}: peripheral line-days are required for PLABSI rate.',
        );
      }
      if (row.pvcHai > 0 && row.pvcInsertions == 0) {
        warnings.add(
          '${row.ward}: PVC insertions/placements are required for PLABSI percentage.',
        );
      }
      if (row.invHai > 0 && row.inv == 0) {
        warnings.add('${row.ward}: ventilator-days are required for VAP rate.');
      }
      if (row.invHai > 0 && row.invInsertions == 0) {
        warnings.add(
          '${row.ward}: invasive ventilator starts/placements are required for VAP percentage.',
        );
      }
      if (row.patientDays > 0 && row.urinaryCatheter > row.patientDays) {
        warnings.add('${row.ward}: urinary catheter-days exceed patient-days.');
      }
      if (row.patientDays > 0 && row.cvc > row.patientDays) {
        warnings.add('${row.ward}: central line-days exceed patient-days.');
      }
      if (row.patientDays > 0 && row.inv > row.patientDays) {
        warnings.add('${row.ward}: ventilator-days exceed patient-days.');
      }
    }
    return warnings.toSet().toList();
  }

  Widget _haiClinicalExposureTable(List<_HaiClinicalExposureRow> rows) {
    return _compactHaiTable(
      'Clinically-based Point Prevalence HAIs Surveillance',
      const [
        'Ward',
        'Patients Surveyed',
        'Surgical procedures',
        'Urinary Catheter',
        'Catheter days',
        'CVC',
        'CVC Days',
        'PVC',
        'PVC Days',
        'INV',
        'INV Days',
        'NIV',
        'NIV Days',
      ],
      rows
          .map(
            (row) => [
              row.ward,
              row.patientsSurveyed,
              row.surgicalPatients,
              row.urinaryCatheter,
              row.catheterDays,
              row.cvc,
              row.cvcDays,
              row.pvc,
              row.pvcDays,
              row.inv,
              row.invDays,
              row.niv,
              row.nivDays,
            ],
          )
          .toList(),
    );
  }

  List<List<Object>> _haiTargetedNonDeviceRows(
    List<_HaiClinicalIncidenceRow> rows,
  ) {
    return rows
        .map(
          (row) => [
            row.ward,
            row.ssiLabel,
            row.utiLabel,
            row.bsiLabel,
            row.rtiLabel,
            row.sstLabel,
            row.othersWithGitLabel,
            row.totalHai,
          ],
        )
        .toList();
  }

  Widget _haiClinicalIncidenceTable(List<_HaiClinicalIncidenceRow> rows) {
    return _compactHaiTable(
      'Clically-based Surveillance HAI Incidence',
      const [
        'Ward',
        'No. SSI',
        'No. BSI',
        'No. UTI',
        'No. SST',
        'No. HAP',
        'No. Others',
        'Total No. HAI',
        'SSI (%)',
        'BSI (%)',
        'UTI (%)',
        'SST (%)',
        'HAP (%)',
        'Others (%)',
      ],
      rows
          .map(
            (row) => [
              row.ward,
              row.ssi,
              row.bsi,
              row.uti,
              row.sst,
              row.rti,
              row.git + row.others,
              row.totalHai,
              '${row.ssiPercent.toStringAsFixed(1)}%',
              '${row.bsiPercent.toStringAsFixed(1)}%',
              '${row.utiPercent.toStringAsFixed(1)}%',
              '${row.sstPercent.toStringAsFixed(1)}%',
              '${row.rtiPercent.toStringAsFixed(1)}%',
              '${row.othersWithGitPercent.toStringAsFixed(1)}%',
            ],
          )
          .toList(),
    );
  }

  Widget _haiTargetedNonDeviceTable(List<_HaiClinicalIncidenceRow> rows) {
    return _compactHaiTable(
      'Targeted Non-device HAI Rates by Ward',
      const [
        'Ward',
        'SSI',
        'Non-catheter UTI',
        'Non-central-line BSI',
        'HAP',
        'Skin and soft tissue',
        'Others',
        'Total non-device HAI',
      ],
      rows
          .map(
            (row) => [
              row.ward,
              row.ssiLabel,
              row.utiLabel,
              row.bsiLabel,
              row.rtiLabel,
              row.sstLabel,
              row.othersWithGitLabel,
              row.totalHai,
            ],
          )
          .toList(),
    );
  }

  Widget _haiDeviceIncidenceTable(List<_HaiDeviceIncidenceRow> rows) {
    return _compactHaiTable(
      'Device-Associated Infection Surveillance by Ward',
      const [
        'Ward or unit',
        'Patient-days',
        'Urinary catheter-days',
        'Catheter utilization ratio',
        'Urinary catheter insertions',
        'CAUTI cases',
        'CAUTI %',
        'CAUTI rate / 1,000 catheter-days',
        'Central line-days',
        'Central line utilization ratio',
        'CVC insertions',
        'CLABSI cases',
        'CLABSI %',
        'CLABSI rate / 1,000 line-days',
        'Peripheral line-days',
        'Peripheral line utilization ratio',
        'PVC insertions',
        'PLABSI cases',
        'PLABSI %',
        'PLABSI rate / 1,000 line-days',
        'Ventilator-days',
        'Ventilator utilization ratio',
        'Ventilator starts',
        'VAP cases',
        'VAP %',
        'VAP rate / 1,000 ventilator-days',
      ],
      _withHaiDeviceTotals(rows)
          .map(
            (row) => [
              row.ward,
              row.patientDays,
              row.urinaryCatheter,
              row.catheterUtilizationLabel,
              row.urinaryCatheterInsertions,
              row.cauti,
              row.cautiPercentLabel,
              row.cautiRateLabel,
              row.cvc,
              row.centralLineUtilizationLabel,
              row.cvcInsertions,
              row.cvcHai,
              row.clabsiPercentLabel,
              row.clabsiRateLabel,
              row.pvc,
              row.peripheralLineUtilizationLabel,
              row.pvcInsertions,
              row.pvcHai,
              row.plabsiPercentLabel,
              row.plabsiRateLabel,
              row.inv,
              row.ventilatorUtilizationLabel,
              row.invInsertions,
              row.invHai,
              row.vapPercentLabel,
              row.vapRateLabel,
            ],
          )
          .toList(),
    );
  }

  List<_HaiDeviceIncidenceRow> _withHaiDeviceTotals(
    List<_HaiDeviceIncidenceRow> rows,
  ) {
    final totals = rows.fold<_HaiDeviceIncidenceRow>(
      _HaiDeviceIncidenceRow.empty('Total'),
      (sum, row) => sum + row,
    );
    return [...rows, totals];
  }

  Widget _haiDeviceKeyFindings(List<_HaiDeviceIncidenceRow> rows) {
    final dataRows = rows.where((row) => row.ward != 'Total').toList();
    _HaiDeviceIncidenceRow? top(
      Iterable<_HaiDeviceIncidenceRow> source,
      double Function(_HaiDeviceIncidenceRow) value,
    ) {
      return source.fold<_HaiDeviceIncidenceRow?>(null, (best, row) {
        if (best == null) return row;
        return value(row) >= value(best) ? row : best;
      });
    }

    final highestCathUtil = top(
      dataRows.where((row) => row.patientDays > 0),
      (row) => row.catheterUtilization,
    );
    final highestCvcUtil = top(
      dataRows.where((row) => row.patientDays > 0),
      (row) => row.centralLineUtilization,
    );
    final highestVentUtil = top(
      dataRows.where((row) => row.patientDays > 0),
      (row) => row.ventilatorUtilization,
    );
    final highestCauti = top(
      dataRows.where((row) => row.urinaryCatheter > 0),
      (row) => row.cautiRate,
    );
    final highestClabsi = top(
      dataRows.where((row) => row.cvc > 0),
      (row) => row.clabsiRate,
    );
    final highestPlabsi = top(
      dataRows.where((row) => row.pvc > 0),
      (row) => row.plabsiRate,
    );
    final highestVap = top(
      dataRows.where((row) => row.inv > 0),
      (row) => row.vapRate,
    );
    final totals = _withHaiDeviceTotals(rows).last;
    final deviceCounts = <String, int>{
      'CAUTI': totals.cauti,
      'CLABSI': totals.cvcHai,
      'PLABSI': totals.pvcHai,
      'VAP': totals.invHai,
    };
    final mostCommon = deviceCounts.entries.fold<MapEntry<String, int>?>(
      null,
      (best, entry) => best == null || entry.value > best.value ? entry : best,
    );
    return _haiInterpretationCard(
      title: 'Device-Associated Infection Surveillance key findings',
      icon: Icons.monitor_heart_outlined,
      body: [
        if (highestCathUtil != null)
          'Highest catheter utilization: ${highestCathUtil.ward} (${highestCathUtil.catheterUtilizationLabel}).',
        if (highestCvcUtil != null)
          'Highest central line utilization: ${highestCvcUtil.ward} (${highestCvcUtil.centralLineUtilizationLabel}).',
        if (highestVentUtil != null)
          'Highest ventilator utilization: ${highestVentUtil.ward} (${highestVentUtil.ventilatorUtilizationLabel}).',
        if (highestCauti != null)
          'Highest CAUTI rate: ${highestCauti.ward} (${highestCauti.cautiRateLabel}).',
        if (highestClabsi != null)
          'Highest CLABSI rate: ${highestClabsi.ward} (${highestClabsi.clabsiRateLabel}).',
        if (highestPlabsi != null)
          'Highest PLABSI rate: ${highestPlabsi.ward} (${highestPlabsi.plabsiRateLabel}).',
        if (highestVap != null)
          'Highest VAP rate: ${highestVap.ward} (${highestVap.vapRateLabel}).',
        if (mostCommon != null && mostCommon.value > 0)
          'Most common device-associated infection: ${mostCommon.key} (${mostCommon.value}).',
      ].join(' '),
    );
  }

  Widget _haiAmsTable(List<_HaiAmsRow> rows) {
    return _compactHaiTable(
      'Antimicrobial Stewardship Surveillance',
      const [
        'Ward',
        'Total Patients',
        'Total on Antimicrobials',
        'Empirical Tx CAI',
        'Targeted Tx CAI',
        'Empirical Tx HAI',
        'Targeted Tx HAI',
        'Surgical Prophylaxis',
        'Medical Prophylaxis',
        'Unknown Indication',
        'Culture Requests',
        'Positive Cultures',
      ],
      rows
          .map(
            (row) => [
              row.ward,
              row.totalPatients,
              row.totalOnAntimicrobials,
              row.empiricalCai,
              row.targetedCai,
              row.empiricalHai,
              row.targetedHai,
              row.surgicalProphylaxis,
              row.medicalProphylaxis,
              row.unknownIndication,
              row.cultureRequests,
              row.positiveCultures,
            ],
          )
          .toList(),
    );
  }

  Widget _compactHaiTable(
    String title,
    List<String> headers,
    List<List<Object>> rows,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: headers
                .map((header) => DataColumn(label: Text(header)))
                .toList(),
            rows: rows
                .map(
                  (row) => DataRow(
                    cells: row.map((cell) => DataCell(Text('$cell'))).toList(),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Future<_HaiGeneratedReport> _buildGeneratedHaiReport(
    List<Map<String, dynamic>> rows,
    _HaiReportOptions options,
    String remarks,
  ) async {
    final denominators = await _loadWardDenominators(options);
    final serviceCounts = <String, int>{};
    final siteCounts = <String, int>{};
    final pathogenCounts = <String, int>{};
    final pathogenBySiteCounts = <String, Map<String, int>>{};
    final wardSiteCounts = <String, Map<String, int>>{};
    final wardDeviceCounts = <String, Map<String, int>>{};
    final wardNonDeviceCounts = <String, Map<String, int>>{};
    final wardAmsCounts = <String, _HaiAmsAccumulator>{};
    final cultureRequestsByWard = <String, int>{};
    final microbiologyCounts = <String, int>{};
    final microbiologyHaiTypeCounts = <String, Map<String, int>>{};
    final resistanceAccumulators = <String, _HaiResistanceAccumulator>{};
    final antimicrobialHabitCounts = <String, int>{};
    final antimicrobialAgentCounts = <String, int>{};
    var totalOnAntimicrobials = 0;

    for (final row in rows) {
      final ward = _haiWard(row);
      if (_questionnaireLabel(
        row,
        'Culture_requested',
      ).toLowerCase().contains('yes')) {
        cultureRequestsByWard[ward] = (cultureRequestsByWard[ward] ?? 0) + 1;
      }
      wardAmsCounts.putIfAbsent(ward, () => _HaiAmsAccumulator()).add(row);
      if (_haiRowLabel(row, 'Antimicrobials').toLowerCase().contains('yes')) {
        totalOnAntimicrobials += 1;
        final habit = _haiAntimicrobialHabit(row);
        antimicrobialHabitCounts[habit] =
            (antimicrobialHabitCounts[habit] ?? 0) + 1;
        for (final agent in _haiAntimicrobialAgents(row)) {
          antimicrobialAgentCounts[agent] =
              (antimicrobialAgentCounts[agent] ?? 0) + 1;
        }
      }
      if (_isHaiConfirmed(row)) {
        final site = _haiSiteBucket(row);
        final pathogen = _haiPathogen(row);
        for (final isolate in _haiPositiveIsolates(row)) {
          microbiologyCounts[isolate.organism] =
              (microbiologyCounts[isolate.organism] ?? 0) + 1;
          microbiologyHaiTypeCounts.putIfAbsent(
            isolate.organism,
            () => <String, int>{},
          );
          microbiologyHaiTypeCounts[isolate.organism]![site] =
              (microbiologyHaiTypeCounts[isolate.organism]![site] ?? 0) + 1;
          resistanceAccumulators
              .putIfAbsent(
                isolate.organism,
                () => _HaiResistanceAccumulator(isolate.organism),
              )
              .addPattern(isolate.pattern);
        }
        serviceCounts[ward] = (serviceCounts[ward] ?? 0) + 1;
        siteCounts[site] = (siteCounts[site] ?? 0) + 1;
        pathogenCounts[pathogen] = (pathogenCounts[pathogen] ?? 0) + 1;
        wardSiteCounts.putIfAbsent(ward, () => <String, int>{});
        wardSiteCounts[ward]![site] = (wardSiteCounts[ward]![site] ?? 0) + 1;
        pathogenBySiteCounts.putIfAbsent(site, () => <String, int>{});
        pathogenBySiteCounts[site]![pathogen] =
            (pathogenBySiteCounts[site]![pathogen] ?? 0) + 1;
        final device = _haiDeviceBucket(row);
        if (device != null) {
          wardDeviceCounts.putIfAbsent(ward, () => <String, int>{});
          wardDeviceCounts[ward]![device] =
              (wardDeviceCounts[ward]![device] ?? 0) + 1;
        } else {
          wardNonDeviceCounts.putIfAbsent(ward, () => <String, int>{});
          wardNonDeviceCounts[ward]![site] =
              (wardNonDeviceCounts[ward]![site] ?? 0) + 1;
        }
      }
    }

    final orderedWards = _haiTemplateWards.where((ward) {
      final key = _normalizeHaiKey(ward);
      return serviceCounts.containsKey(ward) || denominators.containsKey(key);
    }).toList();
    for (final ward in serviceCounts.keys) {
      if (!orderedWards.contains(ward)) orderedWards.add(ward);
    }

    final totalInfected = serviceCounts.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final totalDenominator = denominators.values.fold<int>(
      0,
      (sum, value) => sum + value.discharges,
    );
    final totalPatientDays = denominators.values.fold<int>(
      0,
      (sum, value) => sum + value.totalPatients,
    );
    final totalPathogens = pathogenCounts.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final outcomeByPatient = <String, String>{};
    final deathContributionByPatient = <String, bool>{};
    for (final row in rows.where(_isHaiConfirmed)) {
      final patientKey = _haiPatientKey(row);
      outcomeByPatient.putIfAbsent(
        patientKey,
        () => _haiClinicalOutcomeLabel(row),
      );
      if (_haiDeathContributed(row)) {
        deathContributionByPatient[patientKey] = true;
      }
    }
    final outcomeCounts = <String, int>{};
    for (final outcome in outcomeByPatient.values) {
      outcomeCounts[outcome] = (outcomeCounts[outcome] ?? 0) + 1;
    }
    final labWardRows = orderedWards.map((ward) {
      final key = _normalizeHaiKey(ward);
      final denominator = denominators[key] ?? _HaiWardDenominator.empty(ward);
      final sites = wardSiteCounts[ward] ?? const <String, int>{};
      final haiCount = sites.values.fold<int>(0, (sum, value) => sum + value);
      final discharges = denominator.discharges;
      final wardHaiRate = _rate(haiCount, discharges);
      return _HaiLabWardRow(
        ward: ward,
        patientDays: denominator.totalPatients,
        discharges: discharges,
        cultureRequests: denominator.cultureRequests == 0
            ? (cultureRequestsByWard[ward] ?? 0)
            : denominator.cultureRequests,
        haiCount: haiCount,
        wardPercent: wardHaiRate,
        haiRatePer1000: _ratePer1000(haiCount, denominator.totalPatients),
        ssi: sites['Surgical site'] ?? 0,
        sst: sites['Skin & Soft Tissue'] ?? 0,
        rti: sites['RTI'] ?? 0,
        bsi: sites['BSI'] ?? 0,
        uti: sites['UTI'] ?? 0,
        git: sites['GIT'] ?? 0,
        neonatalSepsis: sites['Neonatal sepsis'] ?? 0,
        others: sites['Others'] ?? 0,
        infectedPatients: haiCount,
      );
    }).toList();
    final pathogenSiteRows = pathogenCounts.keys.map((pathogen) {
      int count(String site) => pathogenBySiteCounts[site]?[pathogen] ?? 0;
      final total =
          count('Surgical site') +
          count('Skin & Soft Tissue') +
          count('RTI') +
          count('BSI') +
          count('UTI') +
          count('GIT') +
          count('Others');
      return _HaiPathogenSiteRow(
        pathogen: pathogen,
        ssi: count('Surgical site'),
        sst: count('Skin & Soft Tissue'),
        rti: count('RTI'),
        bsi: count('BSI'),
        uti: count('UTI'),
        git: count('GIT'),
        others: count('Others'),
        total: total,
        percentage: _rate(total, totalPathogens),
      );
    }).toList()..sort((a, b) => b.total.compareTo(a.total));
    final totalPositiveIsolates = microbiologyCounts.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final microbiologyRows = microbiologyCounts.keys.map((organism) {
      final sites =
          microbiologyHaiTypeCounts[organism] ?? const <String, int>{};
      int count(String site) => sites[site] ?? 0;
      final total = microbiologyCounts[organism] ?? 0;
      return _HaiMicrobiologyRow(
        organism: organism,
        ssi: count('Surgical site'),
        sst: count('Skin & Soft Tissue'),
        rti: count('RTI'),
        bsi: count('BSI'),
        uti: count('UTI'),
        git: count('GIT'),
        others: count('Others') + count('Neonatal sepsis'),
        total: total,
        percentage: _rate(total, totalPositiveIsolates),
      );
    }).toList()..sort((a, b) => b.total.compareTo(a.total));
    final resistanceRows =
        resistanceAccumulators.values.map((item) => item.toRow()).toList()
          ..sort((a, b) => b.totalTested.compareTo(a.totalTested));
    final antimicrobialHabitRows = _haiCountRows(
      antimicrobialHabitCounts,
      totalOnAntimicrobials,
    );
    final antimicrobialAgentRows = _haiCountRows(
      antimicrobialAgentCounts,
      totalOnAntimicrobials,
    );
    final clinicalExposureRows = orderedWards.map((ward) {
      final denominator =
          denominators[_normalizeHaiKey(ward)] ??
          _HaiWardDenominator.empty(ward);
      return _HaiClinicalExposureRow(
        ward: ward,
        patientsSurveyed: denominator.totalPatients,
        surgicalPatients: denominator.surgicalPatients,
        urinaryCatheter: denominator.urinaryCatheter,
        urinaryCatheterInsertions: denominator.urinaryCatheterInsertions,
        catheterDays: denominator.catheterDays,
        cvc: denominator.cvc,
        cvcInsertions: denominator.cvcInsertions,
        cvcDays: denominator.cvcDays,
        pvc: denominator.pvc,
        pvcInsertions: denominator.pvcInsertions,
        pvcDays: denominator.pvcDays,
        inv: denominator.inv,
        invInsertions: denominator.invInsertions,
        invDays: denominator.invDays,
        niv: denominator.niv,
        nivDays: denominator.nivDays,
      );
    }).toList();
    final clinicalIncidenceRows = orderedWards.map((ward) {
      final sites = wardNonDeviceCounts[ward] ?? const <String, int>{};
      final denominator =
          denominators[_normalizeHaiKey(ward)] ??
          _HaiWardDenominator.empty(ward);
      final totalHai = sites.values.fold<int>(0, (sum, value) => sum + value);
      return _HaiClinicalIncidenceRow(
        ward: ward,
        ssi: sites['Surgical site'] ?? 0,
        bsi: sites['BSI'] ?? 0,
        uti: sites['UTI'] ?? 0,
        git: sites['GIT'] ?? 0,
        sst: sites['Skin & Soft Tissue'] ?? 0,
        rti: sites['RTI'] ?? 0,
        others: sites['Others'] ?? 0,
        totalHai: totalHai,
        patients: denominator.totalPatients,
        surgicalPatients: denominator.surgicalPatients,
      );
    }).toList();
    final deviceIncidenceRows = orderedWards.map((ward) {
      final devices = wardDeviceCounts[ward] ?? const <String, int>{};
      final denominator =
          denominators[_normalizeHaiKey(ward)] ??
          _HaiWardDenominator.empty(ward);
      return _HaiDeviceIncidenceRow(
        ward: ward,
        patientDays: denominator.totalPatients,
        cvcHai: devices['cvc'] ?? 0,
        pvcHai: devices['pvc'] ?? 0,
        cauti: devices['urinary'] ?? 0,
        invHai: devices['inv'] ?? 0,
        nivHai: devices['niv'] ?? 0,
        cvc: denominator.cvc,
        cvcInsertions: denominator.cvcInsertions,
        pvc: denominator.pvc,
        pvcInsertions: denominator.pvcInsertions,
        urinaryCatheter: denominator.urinaryCatheter,
        urinaryCatheterInsertions: denominator.urinaryCatheterInsertions,
        inv: denominator.inv,
        invInsertions: denominator.invInsertions,
        niv: denominator.niv,
      );
    }).toList();
    final amsRows = orderedWards.map((ward) {
      final denominator =
          denominators[_normalizeHaiKey(ward)] ??
          _HaiWardDenominator.empty(ward);
      final ams = wardAmsCounts[ward] ?? _HaiAmsAccumulator();
      return _HaiAmsRow(
        ward: ward,
        totalPatients: denominator.totalPatients == 0
            ? (serviceCounts[ward] ?? 0)
            : denominator.totalPatients,
        totalOnAntimicrobials: ams.totalOnAntimicrobials,
        empiricalCai: ams.empiricalCai,
        targetedCai: ams.targetedCai,
        empiricalHai: ams.empiricalHai,
        targetedHai: ams.targetedHai,
        surgicalProphylaxis: ams.surgicalProphylaxis,
        medicalProphylaxis: ams.medicalProphylaxis,
        unknownIndication: ams.unknownIndication,
        cultureRequests: denominator.cultureRequests == 0
            ? (cultureRequestsByWard[ward] ?? ams.cultureRequests)
            : denominator.cultureRequests,
        positiveCultures: ams.positiveCultures,
      );
    }).toList();
    return _HaiGeneratedReport(
      title:
          '${options.basis} - ${_haiReportPeriodLabel(options.reportDate, options.month, options.period)}',
      facilityName: widget.facilityName,
      options: options,
      totalRecords: rows.length,
      totalInfected: totalInfected,
      totalDenominator: totalDenominator,
      totalPatientDays: totalPatientDays,
      labWardRows: labWardRows,
      pathogenSiteRows: pathogenSiteRows,
      microbiologyRows: microbiologyRows,
      resistanceRows: resistanceRows,
      antimicrobialHabitRows: antimicrobialHabitRows,
      antimicrobialAgentRows: antimicrobialAgentRows,
      totalOnAntimicrobials: totalOnAntimicrobials,
      clinicalExposureRows: clinicalExposureRows,
      clinicalIncidenceRows: clinicalIncidenceRows,
      deviceIncidenceRows: deviceIncidenceRows,
      amsRows: amsRows,
      serviceCounts: serviceCounts,
      siteCounts: siteCounts,
      pathogenCounts: pathogenCounts,
      outcomeCounts: outcomeCounts,
      uniqueOutcomeDenominator: outcomeByPatient.length,
      haiContributedDeaths: deathContributionByPatient.length,
      remarks: remarks.trim(),
      logoUrl: await _facilityLogoUrl(),
    );
  }

  Future<Map<String, _HaiWardDenominator>> _loadWardDenominators(
    _HaiReportOptions options,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('ward_denominators')
        .where('facilityId', isEqualTo: widget.facilityId)
        .get();
    final totals = <String, _HaiWardDenominator>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final date = data['denominatorDate'] is Timestamp
          ? (data['denominatorDate'] as Timestamp).toDate()
          : null;
      if (date != null) {
        if (!_dateMatchesHaiReportPeriod(
          date,
          options.reportDate,
          options.month,
          options.period,
        )) {
          continue;
        }
      }
      final responses = data['wardDenominatorResponses'] is Map
          ? Map<String, dynamic>.from(data['wardDenominatorResponses'] as Map)
          : const <String, dynamic>{};
      final labels = data['wardDenominatorResponseLabels'] is Map
          ? Map<String, dynamic>.from(
              data['wardDenominatorResponseLabels'] as Map,
            )
          : const <String, dynamic>{};
      final ward =
          '${data['ward'] ?? labels['Ward'] ?? responses['Ward'] ?? ''}';
      if (ward.trim().isEmpty) continue;
      final key = _normalizeHaiKey(ward);
      totals[key] =
          (totals[key] ?? _HaiWardDenominator.empty(ward)) +
          _HaiWardDenominator(
            ward: ward,
            discharges: _HaiDenominatorMapping.discharges(responses, data),
            cultureRequests: _HaiDenominatorMapping.cultureRequests(
              responses,
              data,
            ),
            totalPatients: _HaiDenominatorMapping.patientDays(responses, data),
            surgicalPatients: _HaiDenominatorMapping.surgicalProcedures(
              responses,
              data,
            ),
            urinaryCatheter: _HaiDenominatorMapping.urinaryCatheterDays(
              responses,
            ),
            urinaryCatheterInsertions:
                _HaiDenominatorMapping.urinaryCatheterInsertions(responses),
            catheterDays: _haiInt(responses['Catheter_days']),
            cvc: _HaiDenominatorMapping.centralLineDays(responses),
            cvcInsertions: _HaiDenominatorMapping.centralLineInsertions(
              responses,
            ),
            cvcDays: _haiInt(responses['CVC_Days']),
            pvc: _HaiDenominatorMapping.peripheralLineDays(responses),
            pvcInsertions: _HaiDenominatorMapping.peripheralLineInsertions(
              responses,
            ),
            pvcDays: _haiInt(responses['PVC_Days']),
            inv: _HaiDenominatorMapping.ventilatorDays(responses),
            invInsertions: _HaiDenominatorMapping.ventilatorInsertions(
              responses,
            ),
            invDays: _haiInt(responses['INV_Days']),
            niv: _HaiDenominatorMapping.nonInvasiveVentilatorDays(responses),
            nivDays: _haiInt(responses['NIV_Days']),
          );
    }
    return totals;
  }

  int _haiInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('$value') ?? 0;
  }

  Future<String?> _facilityLogoUrl() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(widget.facilityId)
          .get()
          .timeout(const Duration(seconds: 4));
      final data = doc.data();
      if (data == null) return null;
      return (data['logoUrl'] ?? data['logo_url'] ?? data['facilityLogo'])
          ?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<String> _generateHaiReportRemarksSuggestion(
    List<Map<String, dynamic>> rows,
    _HaiReportOptions options,
  ) async {
    try {
      final report = await _buildGeneratedHaiReport(rows, options, '');
      final topService = _topCount(report.serviceCounts);
      final topSite = _topCount(report.siteCounts);
      final topPathogen = _topCount(report.pathogenCounts);
      final topOutcome = _topCount(report.outcomeCounts);
      final topDeviceSignal = _topDeviceSignal(report.deviceIncidenceRows);
      final ipcContext = await _loadHaiRootCauseContext(report, options);
      await GeminiService.initialize();
      final gemini = GeminiService.instance;
      if (!gemini.isConfigured) return _fallbackHaiReportRemarks(report);
      final response = await gemini.getChatResponse(
        userRole: 'doctor',
        specialization: 'infection prevention and control surveillance',
        userMessage:
            'Write a brief HAI surveillance report remarks paragraph for an IPC officer. '
            'Explain the overall incidence rate and key critical signals from the selected data. '
            'Mention the overall HAI rate per 1,000 patient-days, the HAI percentage, the most affected ward/service when available, the leading infection site, important device-associated infection signal, leading pathogen, and the most common patient outcome. '
            'Use related IPC surveillance context to suggest possible root-cause contributors such as environmental cleaning gaps, hand hygiene gaps, outbreak signals, denominator/device utilization pressure, or IPC assessment gaps. '
            'Do not claim a root cause as proven unless the data support it; use wording such as possible contributor or should be investigated. '
            'If a key signal is unavailable, do not invent it. '
            'Keep it straightforward, professional, and action-oriented. '
            'Do not use markdown, headings, bullets, #, *, tables, or emojis. '
            'Do not repeat questionnaire questions. Keep it to one short paragraph of not more than 100 words. '
            'End with a complete sentence. Do not leave an unfinished thought, trailing phrase, or sentence ending with and, because, due to, or including. '
            'Facility: ${report.facilityName}. Report: ${report.title}. '
            'Records: ${report.totalRecords}. Total HAI cases: ${report.totalHaiCases}. Patient-days: ${report.totalPatientDays}. Discharges: ${report.totalDenominator}. '
            'Overall HAI rate: ${report.overallRateLabel} per 1,000 patient-days. Overall HAI percentage: ${report.overallPercentageLabel}. '
            'Denominator note: ${_haiDenominatorNote(report)} '
            'Most affected ward/service: ${topService == null ? 'Unavailable' : '${topService.key} (${topService.value})'}. '
            'Leading infection site: ${topSite == null ? 'Unavailable' : '${topSite.key} (${topSite.value})'}. '
            'Device signal: ${topDeviceSignal ?? 'Unavailable'}. '
            'Leading pathogen: ${topPathogen == null ? 'Unavailable' : '${topPathogen.key} (${topPathogen.value})'}. '
            'Most common outcome: ${topOutcome == null ? 'Unavailable' : '${topOutcome.key} (${topOutcome.value})'}. '
            'Related IPC surveillance context: $ipcContext',
      );
      return response.trim().isEmpty
          ? _fallbackHaiReportRemarks(report)
          : _completeIpcAiSentence(_cleanIpcAiText(response));
    } catch (_) {
      return '';
    }
  }

  String _fallbackHaiReportRemarks(_HaiGeneratedReport report) {
    final topService = _topCount(report.serviceCounts);
    final topSite = _topCount(report.siteCounts);
    final topPathogen = _topCount(report.pathogenCounts);
    final topOutcome = _topCount(report.outcomeCounts);
    final topDeviceSignal = _topDeviceSignal(report.deviceIncidenceRows);
    final parts = <String>[
      'The selected ${report.options.surveillanceType} data show an overall HAI incidence rate of ${report.overallRateLabel} per 1,000 patient-days and ${report.overallPercentageLabel} against discharges.',
      _haiDenominatorNote(report),
      if (topService != null)
        '${topService.key} contributed the highest case burden (${topService.value}).',
      if (topSite != null)
        'The leading infection site was ${topSite.key} (${topSite.value}).',
      ?topDeviceSignal,
      if (topPathogen != null && topPathogen.key != 'Unknown')
        'The main pathogen signal was ${topPathogen.key} (${topPathogen.value}).',
      if (topOutcome != null)
        'The most common documented outcome was ${topOutcome.key} (${topOutcome.value}).',
      'Priority action is to validate denominators, review ward IPC bundles, and correlate clinical and laboratory evidence.',
    ];
    return _completeIpcAiSentence(_cleanIpcAiText(parts.join(' ')));
  }

  String _haiDenominatorNote(_HaiGeneratedReport report) {
    if (report.options.reportScope == 'laboratory') {
      return 'Laboratory-based HAI incidence uses ward discharges as denominator and is expressed as a percentage.';
    }
    if (report.options.reportScope == 'both') {
      return 'Laboratory-based HAI incidence uses ward discharges as denominator; clinical-based rates use the standard patient, procedure, device-day, and insertion denominators.';
    }
    return 'Clinical-based HAI calculations use standard denominators: SSI uses surgical procedures, HAP/BSI/UTI/other non-device HAI use ward patient denominators, and device-associated rates use device-days with percentages based on new device insertions or placements.';
  }

  String _completeIpcAiSentence(String value) {
    final text = value.trim();
    if (text.isEmpty) return text;
    if (RegExp(r'[.!?]$').hasMatch(text)) return text;
    return '$text.';
  }

  Future<String> _loadHaiRootCauseContext(
    _HaiGeneratedReport report,
    _HaiReportOptions options,
  ) async {
    try {
      final results = await Future.wait([
        _summarizeIpcCollection(
          collection: 'environmental_inspections',
          options: options,
          relevantWards: report.wardTotalHaiCounts.keys.toSet(),
          label: 'Environmental surveillance',
        ),
        _summarizeIpcCollection(
          collection: 'hand_hygiene_observations',
          options: options,
          relevantWards: report.wardTotalHaiCounts.keys.toSet(),
          label: 'Hand hygiene',
        ),
        _summarizeIpcCollection(
          collection: 'outbreak_investigations',
          options: options,
          relevantWards: report.wardTotalHaiCounts.keys.toSet(),
          label: 'Outbreak investigation',
        ),
        _summarizeIpcCollection(
          collection: 'ipc_assessments',
          options: options,
          relevantWards: report.wardTotalHaiCounts.keys.toSet(),
          label: 'IPC assessment',
        ),
      ]).timeout(const Duration(seconds: 8));
      final context = results.where((item) => item.trim().isNotEmpty).join(' ');
      return context.isEmpty
          ? 'No related IPC surveillance context was available for the selected reporting period.'
          : context;
    } catch (_) {
      return 'Related IPC surveillance context could not be retrieved; interpret HAI signals with available HAI and denominator data only.';
    }
  }

  Future<String> _summarizeIpcCollection({
    required String collection,
    required _HaiReportOptions options,
    required Set<String> relevantWards,
    required String label,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(collection)
        .where('facilityId', isEqualTo: widget.facilityId)
        .get()
        .timeout(const Duration(seconds: 5));
    final records = snapshot.docs
        .map((doc) => doc.data())
        .where((data) => _recordMatchesHaiReportPeriod(data, options))
        .toList();
    if (records.isEmpty) return '$label: no records in the selected period.';
    final wardMatches = records
        .where((data) => _recordMatchesRelevantWard(data, relevantWards))
        .length;
    final gapCount = records.where(_recordSuggestsIpcGap).length;
    final pendingCount = records.where(_recordIsPendingOrRaw).length;
    final topArea = _topCount(_countRecordAreas(records));
    final summary = [
      '$label: ${records.length} record${records.length == 1 ? '' : 's'}',
      if (wardMatches > 0) '$wardMatches linked to high-burden HAI wards',
      if (gapCount > 0) '$gapCount with possible IPC gaps',
      if (pendingCount > 0) '$pendingCount pending/raw records',
      if (topArea != null) 'main area ${topArea.key} (${topArea.value})',
    ].join(', ');
    return '$summary.';
  }

  bool _recordMatchesHaiReportPeriod(
    Map<String, dynamic> data,
    _HaiReportOptions options,
  ) {
    final date = _recordDate(data);
    if (date == null) return true;
    return _dateMatchesHaiReportPeriod(
      date,
      options.reportDate,
      options.month,
      options.period,
    );
  }

  DateTime? _recordDate(Map<String, dynamic> data) {
    for (final key in const [
      'reportedDate',
      'createdAt',
      'updatedAt',
      'inspectionDate',
      'observationDate',
      'outbreakDate',
      'assessmentDate',
      'denominatorDate',
      'date',
    ]) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
    }
    return null;
  }

  bool _recordMatchesRelevantWard(
    Map<String, dynamic> data,
    Set<String> relevantWards,
  ) {
    if (relevantWards.isEmpty) return false;
    final haystack = _flattenRecordText(data).toLowerCase();
    return relevantWards.any(
      (ward) => ward.trim().isNotEmpty && haystack.contains(ward.toLowerCase()),
    );
  }

  bool _recordSuggestsIpcGap(Map<String, dynamic> data) {
    final text = _flattenRecordText(data).toLowerCase();
    const gapSignals = [
      ' no ',
      ': no',
      'not available',
      'not functional',
      'poor',
      'dirty',
      'unclean',
      'unsatisfactory',
      'inadequate',
      'non-compliant',
      'non compliant',
      'failed',
      'rejected',
      'not approved',
      'outbreak',
      'shortage',
      'overfilled',
      'not segregated',
      'not documented',
    ];
    return gapSignals.any(text.contains);
  }

  bool _recordIsPendingOrRaw(Map<String, dynamic> data) {
    final status = [
      data['submissionStatus'],
      data['submissionState'],
      data['status'],
      data['dataStatus'],
    ].map((value) => '$value'.toLowerCase()).join(' ');
    return status.contains('draft') ||
        status.contains('pending') ||
        status.contains('raw');
  }

  Map<String, int> _countRecordAreas(List<Map<String, dynamic>> records) {
    final counts = <String, int>{};
    for (final data in records) {
      final area = _recordArea(data);
      if (area.trim().isEmpty || area == 'Unknown') continue;
      counts[area] = (counts[area] ?? 0) + 1;
    }
    return counts;
  }

  String _recordArea(Map<String, dynamic> data) {
    for (final key in const [
      'ward',
      'unit',
      'department',
      'location',
      'assessmentTool',
      'surveillanceType',
      'outbreakLocation',
    ]) {
      final value = '${data[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return 'Unknown';
  }

  String _flattenRecordText(Object? value) {
    if (value == null) return '';
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key} ${_flattenRecordText(entry.value)}')
          .join(' ');
    }
    if (value is Iterable) {
      return value.map(_flattenRecordText).join(' ');
    }
    if (value is Timestamp) return value.toDate().toIso8601String();
    return '$value';
  }

  String? _topDeviceSignal(List<_HaiDeviceIncidenceRow> rows) {
    final signals = <String, double>{};
    for (final row in rows) {
      if (row.cauti > 0 && row.urinaryCatheter > 0) {
        signals['${row.ward} CAUTI ${row.cautiRateLabel}/1,000 catheter-days'] =
            row.cautiRate;
      }
      if (row.cvcHai > 0 && row.cvc > 0) {
        signals['${row.ward} CLABSI ${row.clabsiRateLabel}/1,000 line-days'] =
            row.clabsiRate;
      }
      if (row.invHai > 0 && row.inv > 0) {
        signals['${row.ward} VAP ${row.vapRateLabel}/1,000 ventilator-days'] =
            row.vapRate;
      }
    }
    if (signals.isEmpty) return null;
    final top = signals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return 'The highest device-associated signal was ${top.key}.';
  }

  Future<void> _shareGeneratedHaiReportPdf(_HaiGeneratedReport report) async {
    final doc = pw.Document();
    pw.ImageProvider? logo;
    if (report.logoUrl != null && report.logoUrl!.trim().isNotEmpty) {
      try {
        logo = await networkImage(report.logoUrl!);
      } catch (_) {
        logo = null;
      }
    }
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null) pw.Image(logo, width: 56, height: 56),
              if (logo != null) pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      report.facilityName,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text('Infection prevention and control Committee'),
                    pw.Text(report.title),
                    pw.Text(
                      '${DateFormat('MMM d, y').format(report.options.reportDate)} • ${report.options.surveillanceType}',
                    ),
                    pw.Text(
                      'Date basis: ${_haiReportDateBasisLabel(report.options.dateBasis)}',
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Overall HAI rate: ${report.overallRateLabel} per 1,000 patient-days',
          ),
          pw.Text('Total HAI cases: ${report.totalHaiCases}'),
          pw.Text('Patient-days denominator: ${report.totalPatientDays}'),
          pw.Text('Discharge denominator: ${report.totalDenominator}'),
          pw.SizedBox(height: 14),
          if (report.options.basis == 'AMS Surveillance Report') ...[
            _pdfHaiTable(
              'Antimicrobial Stewardship Surveillance',
              [
                'Ward',
                'Total Patients',
                'On Antimicrobials',
                'Empirical CAI',
                'Targeted CAI',
                'Empirical HAI',
                'Targeted HAI',
                'Surgical Proph',
                'Medical Proph',
                'Unknown',
                'Cultures',
                'Positive',
              ],
              report.amsRows
                  .map(
                    (row) => [
                      row.ward,
                      row.totalPatients,
                      row.totalOnAntimicrobials,
                      row.empiricalCai,
                      row.targetedCai,
                      row.empiricalHai,
                      row.targetedHai,
                      row.surgicalProphylaxis,
                      row.medicalProphylaxis,
                      row.unknownIndication,
                      row.cultureRequests,
                      row.positiveCultures,
                    ],
                  )
                  .toList(),
            ),
          ] else ...[
            if (_haiReportIncludes(report, 'overall_summary'))
              _pdfHaiTable(
                'Overall HAI Surveillance Summary',
                ['Indicator', 'Value', 'Indicator', 'Value'],
                _haiOverallSummaryGridRows(report),
              ),
            if (_haiReportIncludes(report, 'targeted_non_device') &&
                report.options.reportScope != 'both')
              _pdfHaiTable(
                'Targeted Non-device HAI Rates by Ward',
                [
                  'Ward',
                  'SSI',
                  'Non-catheter UTI',
                  'Non-central-line BSI',
                  'HAP',
                  'SST',
                  'Others',
                  'Total',
                ],
                _haiTargetedNonDeviceRows(report.clinicalIncidenceRows),
              ),
            if (_haiReportIncludes(report, 'hai_by_ward'))
              _pdfHaiTable(
                'HAI by Ward and Infection Type',
                _haiLabWardHeaders(),
                _haiLabWardTableRows(report.labWardRows),
              ),
            if (_haiReportIncludes(report, 'microbiology_profile'))
              _pdfHaiTable(
                'Microbiology Profile',
                [
                  'Pathogens',
                  'Surgical site',
                  'Skin & Soft Tissue',
                  'HAP',
                  'BSI',
                  'UTI',
                  'Others',
                  'Total',
                  'Percentage',
                ],
                _haiMicrobiologyTableRows(report.microbiologyRows),
              ),
            if (report.options.reportScope == 'both') pw.NewPage(),
            if (_haiReportIncludes(report, 'targeted_non_device') &&
                report.options.reportScope == 'both')
              _pdfHaiTable(
                'Targeted Non-device HAI Rates by Ward',
                [
                  'Ward',
                  'SSI',
                  'Non-catheter UTI',
                  'Non-central-line BSI',
                  'HAP',
                  'SST',
                  'Others',
                  'Total',
                ],
                _haiTargetedNonDeviceRows(report.clinicalIncidenceRows),
              ),
            if (_haiReportIncludes(report, 'device_incidence'))
              _pdfHaiTable(
                'Device-Associated Infection Surveillance by Ward',
                [
                  'Ward',
                  'Patient-days',
                  'Urinary catheter-days',
                  'Cath util',
                  'UC insertions',
                  'CAUTI',
                  'CAUTI %',
                  'CAUTI rate',
                  'Central line-days',
                  'CVC util',
                  'CVC insertions',
                  'CLABSI',
                  'CLABSI %',
                  'CLABSI rate',
                  'Peripheral line-days',
                  'PVC util',
                  'PVC insertions',
                  'PLABSI',
                  'PLABSI %',
                  'PLABSI rate',
                  'Ventilator-days',
                  'Vent util',
                  'Vent starts',
                  'VAP',
                  'VAP %',
                  'VAP rate',
                ],
                _withHaiDeviceTotals(report.deviceIncidenceRows)
                    .map(
                      (row) => [
                        row.ward,
                        row.patientDays,
                        row.urinaryCatheter,
                        row.catheterUtilizationLabel,
                        row.urinaryCatheterInsertions,
                        row.cauti,
                        row.cautiPercentLabel,
                        row.cautiRateLabel,
                        row.cvc,
                        row.centralLineUtilizationLabel,
                        row.cvcInsertions,
                        row.cvcHai,
                        row.clabsiPercentLabel,
                        row.clabsiRateLabel,
                        row.pvc,
                        row.peripheralLineUtilizationLabel,
                        row.pvcInsertions,
                        row.pvcHai,
                        row.plabsiPercentLabel,
                        row.plabsiRateLabel,
                        row.inv,
                        row.ventilatorUtilizationLabel,
                        row.invInsertions,
                        row.invHai,
                        row.vapPercentLabel,
                        row.vapRateLabel,
                      ],
                    )
                    .toList(),
              ),
            if (_haiReportIncludes(report, 'resistance_profile'))
              _pdfHaiTable(
                'Antimicrobial Resistance Profile',
                [
                  'Organism',
                  'Total tested',
                  'MDR',
                  'ESBL',
                  'CAR',
                  'MRSA',
                  'VRE',
                ],
                report.resistanceRows.map((row) => row.toCells()).toList(),
              ),
            if (_haiReportIncludes(report, 'antimicrobial_profile'))
              _pdfHaiTable(
                'Antimicrobial Prescription Habits',
                ['Prescription habit', 'Count', 'Percent'],
                report.antimicrobialHabitRows
                    .map((row) => [row.label, row.count, row.percentLabel])
                    .toList(),
              ),
            if (_haiReportIncludes(report, 'antimicrobial_profile'))
              _pdfHaiTable(
                'Common Antimicrobials Prescribed',
                [
                  'Antimicrobial',
                  'Count',
                  'Percent',
                  'Antimicrobial',
                  'Count',
                  'Percent',
                ],
                _haiTopAntimicrobialRows(report.antimicrobialAgentRows),
              ),
            if (_haiReportIncludes(report, 'outcome_summary'))
              _pdfHaiTable('Clinical Outcomes', [
                'Outcome',
                'Unique patients',
                'Percent',
              ], _haiOutcomeRows(report)),
            if (_haiReportIncludes(report, 'trend_status'))
              _pdfHaiTable('Trend Status', [
                'Component',
                'Current result',
                'Status',
              ], _haiTrendRows(report)),
          ],
          pw.NewPage(),
          pw.Text(
            'Summary / remarks',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            constraints: const pw.BoxConstraints(minHeight: 120),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600),
            ),
            child: pw.Text(
              report.remarks.trim().isEmpty ? ' ' : report.remarks.trim(),
            ),
          ),
          pw.SizedBox(height: 36),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _pdfSignatureField('IPC Doctor'),
              _pdfSignatureField('IPC Manager'),
            ],
          ),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename:
          'hai_generated_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _pdfHaiTable(
    String title,
    List<String> headers,
    List<List<Object>> rows,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(headers: headers, data: rows),
        pw.SizedBox(height: 16),
      ],
    );
  }

  List<List<Object>> _haiOutcomeRows(_HaiGeneratedReport report) {
    int countWhere(List<String> needles) {
      var total = 0;
      for (final entry in report.outcomeCounts.entries) {
        final label = entry.key.toLowerCase();
        if (needles.any(label.contains)) total += entry.value;
      }
      return total;
    }

    final categories = <String, int>{
      'Recovered': countWhere(['recover', 'resolved']),
      'Still admitted': countWhere(['admitted', 'on admission', 'still']),
      'Discharged alive': countWhere(['discharg']),
      'Transferred or referred': countWhere(['transfer', 'refer']),
      'Died': countWhere(['died', 'death', 'dead']),
      'HAI contributed to death': report.haiContributedDeaths,
      'Unknown / not documented': countWhere([
        'unknown',
        'not documented',
        'missing',
      ]),
    };
    final used = categories.entries
        .where((entry) => entry.key != 'HAI contributed to death')
        .fold<int>(0, (sum, entry) => sum + entry.value);
    final unclassified = report.uniqueOutcomeDenominator - used;
    if (unclassified > 0) {
      categories['Other clinical outcome'] = unclassified;
    }
    return categories.entries
        .where(
          (entry) => entry.value > 0 || entry.key == 'HAI contributed to death',
        )
        .map(
          (entry) => [
            entry.key,
            entry.value,
            report.uniqueOutcomeDenominator == 0
                ? 'N/A'
                : '${((entry.value / report.uniqueOutcomeDenominator) * 100).toStringAsFixed(1)}%',
          ],
        )
        .toList();
  }

  pw.Widget _pdfSignatureField(String label) {
    return pw.SizedBox(
      width: 180,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(height: 1, color: PdfColors.black),
          pw.SizedBox(height: 6),
          pw.Text(label),
        ],
      ),
    );
  }

  Future<void> _shareGeneratedHaiReportDoc(_HaiGeneratedReport report) async {
    final html = StringBuffer()
      ..writeln('<html><body>')
      ..writeln('<h1>${_htmlEscape(report.facilityName)}</h1>')
      ..writeln('<h2>Infection prevention and control Committee</h2>')
      ..writeln('<h2>${_htmlEscape(report.title)}</h2>')
      ..writeln(
        '<p><strong>Date basis:</strong> ${_htmlEscape(_haiReportDateBasisLabel(report.options.dateBasis))}</p>',
      )
      ..writeln(
        '<p><strong>Overall HAI rate:</strong> ${report.overallRateLabel} per 1,000 patient-days<br>'
        '<strong>Total HAI cases:</strong> ${report.totalHaiCases}<br>'
        '<strong>Patient-days denominator:</strong> ${report.totalPatientDays}<br>'
        '<strong>Discharge denominator:</strong> ${report.totalDenominator}</p>',
      );
    if (report.options.basis == 'AMS Surveillance Report') {
      html.writeln(
        _htmlSimpleTable(
          'Antimicrobial Stewardship Surveillance',
          [
            'Ward',
            'Total Patients',
            'Total on Antimicrobials',
            'Empirical Tx CAI',
            'Targeted Tx CAI',
            'Empirical Tx HAI',
            'Targeted Tx HAI',
            'Surgical Prophylaxis',
            'Medical Prophylaxis',
            'Unknown Indication',
            'Culture Requests',
            'Positive Cultures',
          ],
          report.amsRows
              .map(
                (row) => [
                  row.ward,
                  row.totalPatients,
                  row.totalOnAntimicrobials,
                  row.empiricalCai,
                  row.targetedCai,
                  row.empiricalHai,
                  row.targetedHai,
                  row.surgicalProphylaxis,
                  row.medicalProphylaxis,
                  row.unknownIndication,
                  row.cultureRequests,
                  row.positiveCultures,
                ],
              )
              .toList(),
        ),
      );
    } else {
      if (_haiReportIncludes(report, 'overall_summary')) {
        html.writeln(
          _htmlSimpleTable(
            'Overall HAI Surveillance Summary',
            ['Indicator', 'Value', 'Indicator', 'Value'],
            _haiOverallSummaryGridRows(report),
          ),
        );
      }
      if (_haiReportIncludes(report, 'hai_by_ward')) {
        html.writeln(
          _htmlSimpleTable(
            'HAI by Ward and Infection Type',
            _haiLabWardHeaders(),
            _haiLabWardTableRows(report.labWardRows),
          ),
        );
      }
      if (_haiReportIncludes(report, 'microbiology_profile')) {
        html.writeln(
          _htmlSimpleTable(
            'Microbiology Profile',
            [
              'Pathogens',
              'Surgical site',
              'Skin & Soft Tissue',
              'HAP',
              'BSI',
              'UTI',
              'Others',
              'Total',
              'Percentage',
            ],
            _haiMicrobiologyTableRows(report.microbiologyRows),
          ),
        );
      }
      if (report.options.reportScope == 'both') {
        html.writeln('<div style="page-break-before:always;"></div>');
      }
      if (_haiReportIncludes(report, 'targeted_non_device')) {
        html.writeln(
          _htmlSimpleTable(
            'Targeted Non-device HAI Rates by Ward',
            [
              'Ward',
              'SSI',
              'Non-catheter UTI',
              'Non-central-line BSI',
              'HAP',
              'SST',
              'Others',
              'Total',
            ],
            _haiTargetedNonDeviceRows(report.clinicalIncidenceRows),
          ),
        );
      }
      if (_haiReportIncludes(report, 'device_incidence')) {
        html.writeln(
          _htmlSimpleTable(
            'Device-Associated Infection Surveillance by Ward',
            [
              'Ward',
              'Patient-days',
              'Urinary catheter-days',
              'Cath util',
              'UC insertions',
              'CAUTI',
              'CAUTI %',
              'CAUTI rate',
              'Central line-days',
              'CVC util',
              'CVC insertions',
              'CLABSI',
              'CLABSI %',
              'CLABSI rate',
              'Peripheral line-days',
              'PVC util',
              'PVC insertions',
              'PLABSI',
              'PLABSI %',
              'PLABSI rate',
              'Ventilator-days',
              'Vent util',
              'Vent starts',
              'VAP',
              'VAP %',
              'VAP rate',
            ],
            _withHaiDeviceTotals(report.deviceIncidenceRows)
                .map(
                  (row) => [
                    row.ward,
                    row.patientDays,
                    row.urinaryCatheter,
                    row.catheterUtilizationLabel,
                    row.urinaryCatheterInsertions,
                    row.cauti,
                    row.cautiPercentLabel,
                    row.cautiRateLabel,
                    row.cvc,
                    row.centralLineUtilizationLabel,
                    row.cvcInsertions,
                    row.cvcHai,
                    row.clabsiPercentLabel,
                    row.clabsiRateLabel,
                    row.pvc,
                    row.peripheralLineUtilizationLabel,
                    row.pvcInsertions,
                    row.pvcHai,
                    row.plabsiPercentLabel,
                    row.plabsiRateLabel,
                    row.inv,
                    row.ventilatorUtilizationLabel,
                    row.invInsertions,
                    row.invHai,
                    row.vapPercentLabel,
                    row.vapRateLabel,
                  ],
                )
                .toList(),
          ),
        );
      }
      if (_haiReportIncludes(report, 'resistance_profile')) {
        html.writeln(
          _htmlSimpleTable(
            'Antimicrobial Resistance Profile',
            ['Organism', 'Total tested', 'MDR', 'ESBL', 'CAR', 'MRSA', 'VRE'],
            report.resistanceRows.map((row) => row.toCells()).toList(),
          ),
        );
      }
      if (_haiReportIncludes(report, 'antimicrobial_profile')) {
        html
          ..writeln(
            _htmlSimpleTable(
              'Antimicrobial Prescription Habits',
              ['Prescription habit', 'Count', 'Percent'],
              report.antimicrobialHabitRows
                  .map((row) => [row.label, row.count, row.percentLabel])
                  .toList(),
            ),
          )
          ..writeln(
            _htmlSimpleTable(
              'Common Antimicrobials Prescribed',
              [
                'Antimicrobial',
                'Count',
                'Percent',
                'Antimicrobial',
                'Count',
                'Percent',
              ],
              _haiTopAntimicrobialRows(report.antimicrobialAgentRows),
            ),
          );
      }
      if (_haiReportIncludes(report, 'outcome_summary')) {
        html.writeln(
          _htmlSimpleTable('Clinical Outcomes', [
            'Outcome',
            'Unique patients',
            'Percent',
          ], _haiOutcomeRows(report)),
        );
      }
      if (_haiReportIncludes(report, 'trend_status')) {
        html.writeln(
          _htmlSimpleTable('Trend Status', [
            'Component',
            'Current result',
            'Status',
          ], _haiTrendRows(report)),
        );
      }
    }
    html
      ..writeln('<div style="page-break-before:always;"></div>')
      ..writeln('<h3>Summary / remarks</h3>')
      ..writeln(
        '<div style="min-height:120px; border:1px solid #777; padding:8px;">${_htmlEscape(report.remarks.trim())}</div>',
      );
    html.writeln('''
      <table style="width:100%; margin-top:48px; border-collapse:collapse;">
        <tr>
          <td style="width:40%; border-top:1px solid #000; text-align:center; padding-top:8px;">IPC Doctor</td>
          <td style="width:20%;"></td>
          <td style="width:40%; border-top:1px solid #000; text-align:center; padding-top:8px;">IPC Manager</td>
        </tr>
      </table>
    ''');
    html.writeln('</body></html>');
    await Share.shareXFiles([
      XFile.fromData(
        Uint8List.fromList(utf8.encode(html.toString())),
        mimeType: 'application/msword',
        name:
            'hai_generated_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.doc',
      ),
    ]);
  }

  String _htmlSimpleTable(
    String title,
    List<String> headers,
    List<List<Object>> rows,
  ) {
    final buffer = StringBuffer()
      ..writeln('<h3>${_htmlEscape(title)}</h3>')
      ..writeln('<table border="1" cellspacing="0" cellpadding="4">')
      ..writeln(
        '<tr>${headers.map((header) => '<th>${_htmlEscape(header)}</th>').join()}</tr>',
      );
    for (final row in rows) {
      buffer.writeln(
        '<tr>${row.map((cell) => '<td>${_htmlEscape('$cell')}</td>').join()}</tr>',
      );
    }
    buffer.writeln('</table>');
    return buffer.toString();
  }

  String _htmlEscape(String value) => const HtmlEscape().convert(value);

  String _haiWard(Map<String, dynamic> row) {
    for (final field in const [
      '_3_Surgical_Wards',
      '_4_Medical_Wards',
      '_5_O_G_Wards',
      '_6_Paediatric_Wards',
      '_7_Other_Wards',
    ]) {
      final value = _questionnaireLabel(row, field);
      if (value != 'Unknown' && value.trim().isNotEmpty) return value;
    }
    return _questionnaireLabel(row, 'Department');
  }

  bool _isRoutineHaiRow(Map<String, dynamic> row) {
    final type = '${row['surveillanceType'] ?? ''}'.toLowerCase();
    final infectionType = '${row['infectionType'] ?? ''}'.toLowerCase();
    return type.contains('routine') || infectionType.contains('routine');
  }

  bool _isHaiConfirmed(Map<String, dynamic> row) {
    final value = _questionnaireLabelAny(
      row,
      keys: const [
        'HAIs',
        'HAI',
        'Patient_HAI',
        'Patient_HAIs',
        'Patient_had_HAI',
        'Healthcare_Associated_Infection',
      ],
      questionNumbers: const ['86', '41'],
      labelContains: const [
        'patient had hai',
        'patient has hai',
        'patient have hai',
        'patient develop hai',
        'patient developed hai',
        'patient develops hai',
        'did patient develop hai',
        'did the patient develop hai',
        'patient developed healthcare associated infection',
        'patient developed healthcare-associated infection',
        'patient hai',
        'hai diagnosis',
        'hai status',
        'healthcare-associated infection',
        'healthcare associated infection',
        'health care associated infection',
        'healthcare associated infections',
      ],
    ).trim().toLowerCase();
    return value == 'yes' ||
        value == 'true' ||
        value == 'confirmed' ||
        value == 'positive';
  }

  String _haiPatientKey(Map<String, dynamic> row) {
    for (final value in [
      row['patientId'],
      row['hospitalNumber'],
      row['patientHospitalNumber'],
      _questionnaireLabel(row, '_9_Hospital_number'),
      row['formId'],
    ]) {
      final text = '$value'.trim();
      if (text.isNotEmpty && text != 'null' && text != 'Unknown') return text;
    }
    return row.hashCode.toString();
  }

  String _haiClinicalOutcomeLabel(Map<String, dynamic> row) {
    for (final value in [
      row['clinicalOutcome'],
      row['otherClinicalOutcome'],
      _questionnaireLabel(row, 'Clinical_Outcome'),
      _questionnaireLabel(row, 'Other_Clinical_Outcome'),
    ]) {
      final text = '$value'.trim();
      if (text.isNotEmpty && text != 'null' && text != 'Unknown') {
        return text;
      }
    }
    return 'Outcome not documented';
  }

  bool _haiDeathContributed(Map<String, dynamic> row) {
    final values = [
      row['deathHaiContribution'],
      row['deathHaiContributionCode'],
      row['deathRelationship'],
      row['deathRelationshipCode'],
      _questionnaireLabel(row, 'HAI_Contributed_To_Death'),
      _questionnaireLabel(row, 'HAI_Relationship_To_Death'),
    ].map((value) => '$value'.toLowerCase()).join(' ');
    return values.contains('yes') ||
        values.contains('contribut') ||
        values.contains('direct') ||
        values.contains('related');
  }

  String _haiSite(Map<String, dynamic> row) {
    final type = _questionnaireLabelAny(
      row,
      keys: const [
        'Type_of_HAIs',
        'Type_of_HAI',
        'HAI_Type',
        'Type_of_infection',
      ],
      questionNumbers: const ['88', '43'],
      labelContains: const [
        'type of hai',
        'hai type',
        'type of healthcare associated infection',
        'healthcare associated infection type',
        'infection type',
        'type of infection',
      ],
    );
    if (type != 'Unknown' && type.trim().isNotEmpty) return type;
    for (final field in const [
      '_50_Specify_source_of_infection',
      '_51_Specify_source_of_infection',
      '_52_Specify_source_of_infection',
      '_53_Specify_source_of_infection',
      '_48_Specify_Culture_Status',
    ]) {
      final value = _questionnaireLabel(row, field);
      if (value != 'Unknown' && value.trim().isNotEmpty) return value;
    }
    return 'Unknown';
  }

  String _haiSiteBucket(Map<String, dynamic> row) {
    final value = _haiSite(row).toLowerCase();
    if (value.contains('unidentified severe infection') ||
        value.contains('unidentified infection') ||
        value.contains('sys-csep') ||
        value.contains('sys csep') ||
        value.contains('csep')) {
      return 'Others';
    }
    if (value.contains('neonatal') || value.contains('neo natal')) {
      return 'Neonatal sepsis';
    }
    if (value.contains('ssi') || value.contains('surgical')) {
      return 'Surgical site';
    }
    if (value.contains('sst') ||
        value.contains('skin') ||
        value.contains('soft tissue')) {
      return 'Skin & Soft Tissue';
    }
    if (value.contains('hap') ||
        value.contains('respiratory') ||
        value.contains('rti') ||
        value.contains('pneumonia')) {
      return 'RTI';
    }
    if (value.contains('bsi') || value.contains('blood')) return 'BSI';
    if (value.contains('urinary') || value.contains('uti')) return 'UTI';
    if (value.contains('git') ||
        value.contains('gastro') ||
        value.contains('gastrointestinal')) {
      return 'GIT';
    }
    return 'Others';
  }

  bool _isHaiHapType(Map<String, dynamic> row) {
    final value = _normalizeHaiLookupText(_haiSite(row));
    return value.split(' ').contains('hap') ||
        value.contains('hospital acquired pneumonia') ||
        value.contains('hospital associated pneumonia') ||
        value.contains('healthcare associated pneumonia') ||
        value.contains('pneumonia') ||
        value.split(' ').contains('vap');
  }

  String? _haiDeviceBucket(Map<String, dynamic> row) {
    final site = _haiSiteBucket(row);
    final isHap = _isHaiHapType(row);
    final bsiSource = _questionnaireLabelAny(
      row,
      keys: const [
        '_51_Specify_source_of_infection',
        'Device_related_BSI',
        'BSI_device_source',
        'Type_of_device_related_BSI',
      ],
      questionNumbers: const ['95', '51'],
      labelContains: const [
        'device related bsi',
        'device-related bsi',
        'type of device related bsi',
        'type of device-related bsi',
        'bsi source',
        'bloodstream infection source',
      ],
    ).toLowerCase();
    final utiSourceRaw = _questionnaireLabelAny(
      row,
      keys: const [
        '_52_Specify_source_of_infection',
        'UTI_source',
        'CAUTI_source',
        'Urinary_catheter_source',
      ],
      questionNumbers: const ['96', '52'],
      labelContains: const [
        'urinary catheter',
        'catheter associated urinary tract infection',
        'catheter-associated urinary tract infection',
        'cauti',
        'uti source',
        'urinary tract infection source',
      ],
    );
    final utiSource = utiSourceRaw.toLowerCase();
    final rtiSource = _questionnaireLabelAny(
      row,
      keys: const [
        '_53_Specify_source_of_infection',
        'RTI_source',
        'VAP_source',
        'Respiratory_device_source',
      ],
      questionNumbers: const ['53'],
      labelContains: const [
        'respiratory source',
        'respiratory tract infection source',
        'hospital acquired pneumonia',
        'pneumonia source',
        'ventilator',
        'invasive ventilator',
      ],
    ).toLowerCase();
    final deviceAnswerRaw = _questionnaireLabelAny(
      row,
      keys: const [
        'Type_of_Devices',
        'Device_Type',
        'Type_of_Device',
        'Devices_Present',
      ],
      questionNumbers: const ['36', '34'],
      labelContains: const [
        'type of device',
        'devices present',
        'device present',
        'device exposure',
        'device related risk',
        'invasive ventilator',
        'invasive mechanical ventilation',
        'urinary catheter',
        'central venous catheter',
        'peripheral venous catheter',
      ],
    );
    final text = [
      _questionnaireLabel(row, 'Type_of_risk'),
      deviceAnswerRaw,
      _questionnaireLabel(row, 'Other_devices_specify'),
      bsiSource,
      utiSource,
      rtiSource,
    ].join(' ').toLowerCase();
    final hasCentralLine =
        text.contains('central venous') ||
        text.contains('central line') ||
        text.contains('cvc') ||
        text.contains('clabsi');
    final hasPeripheralLine =
        text.contains('peripheral venous') ||
        text.contains('peripheral line') ||
        text.contains('pvc') ||
        text.contains('plabsi');
    final hasUrinaryCatheter =
        text.contains('urinary catheter') ||
        text.contains('urethral catheter') ||
        text.contains('catheter-associated') ||
        text.contains('cauti') ||
        (site == 'UTI' && _isAffirmativeHaiAnswer(utiSourceRaw));
    final mentionsNonInvasiveVentilation =
        text.contains('non-invasive') ||
        text.contains('non invasive') ||
        text.contains('niv');
    final hasInvasiveVentilator =
        !mentionsNonInvasiveVentilation &&
        (text.contains('invasive ventilator') ||
            text.contains('invasive mechanical ventilation') ||
            text.contains('mechanical ventilator') ||
            text.contains('ventilator') ||
            text.contains('endotracheal') ||
            text.contains('ett') ||
            text.contains('tracheostomy') ||
            (site == 'RTI' &&
                isHap &&
                _isAffirmativeHaiAnswer(deviceAnswerRaw)));
    if (hasCentralLine && site == 'BSI') {
      return 'cvc';
    }
    if (hasPeripheralLine && site == 'BSI') {
      return 'pvc';
    }
    if (hasUrinaryCatheter && site == 'UTI') {
      return 'urinary';
    }
    if (hasInvasiveVentilator && site == 'RTI' && isHap) {
      return 'inv';
    }
    return null;
  }

  String _haiPathogen(Map<String, dynamic> row) {
    for (final field in const [
      'Pathogen_Identified',
      'Pathogen_Identified_001',
      'Microorganism',
    ]) {
      final value = _questionnaireLabel(row, field);
      if (value != 'Unknown' && value.trim().isNotEmpty) return value;
    }
    return 'Unknown';
  }

  List<_HaiIsolate> _haiPositiveIsolates(Map<String, dynamic> row) {
    final cultureStatus = [
      _questionnaireLabel(row, '_48_Specify_Culture_Status'),
      _questionnaireLabel(row, 'Culture_requested'),
      _questionnaireLabel(row, 'The_HAIs_diagnosis_is_based_on'),
    ].join(' ').toLowerCase();
    if (cultureStatus.contains('no growth') ||
        cultureStatus.contains('pending') ||
        cultureStatus.contains('not performed') ||
        cultureStatus.contains('not done')) {
      return const [];
    }
    final isolates = <_HaiIsolate>[];
    void add(String pathogenField, List<String> patternFields) {
      final organism = _questionnaireLabel(row, pathogenField).trim();
      if (organism.isEmpty ||
          organism == 'Unknown' ||
          organism.toLowerCase().contains('no growth') ||
          organism.toLowerCase().contains('pending')) {
        return;
      }
      final pattern = patternFields
          .map((field) => _questionnaireLabel(row, field))
          .firstWhere(
            (value) =>
                value.trim().isNotEmpty &&
                value != 'Unknown' &&
                value != 'null',
            orElse: () => '',
          );
      isolates.add(_HaiIsolate(organism: organism, pattern: pattern));
    }

    add('Pathogen_Identified', const [
      '_79_Resistant_Pattern',
      '_80_Resistant_Pattern',
      '_81_Resistant_Pattern',
      '_82_Resistant_Pattern',
    ]);
    add('Pathogen_Identified_001', const [
      '_83_Type_of_Sample_Collected_2',
      '_101_Resistant_Pattern2',
      '_102_Resistant_Pattern2',
      '_103_Resistant_Pattern2',
    ]);
    return isolates;
  }

  String _haiAntimicrobialHabit(Map<String, dynamic> row) {
    final indication = _haiRowLabel(row, 'Antibiotics_indication');
    if (indication.trim().isNotEmpty && indication != 'Unknown') {
      return indication;
    }
    final documentedReason = _haiRowLabel(
      row,
      '_19_Reasons_for_anti_eatment_in_the_notes',
    );
    if (documentedReason.trim().isNotEmpty && documentedReason != 'Unknown') {
      return 'Reason documented: $documentedReason';
    }
    return 'Antimicrobial indication not documented';
  }

  List<String> _haiAntimicrobialAgents(Map<String, dynamic> row) {
    final items = _haiRowLabelItems(row, 'Antimicrobials_001')
        .where(
          (item) =>
              item.trim().isNotEmpty &&
              item != 'Unknown' &&
              item.toLowerCase() != 'others (specify)',
        )
        .toList();
    final other = _haiRowLabel(row, '_17_Please_specify');
    if (other.trim().isNotEmpty && other != 'Unknown') {
      items.add(other.trim());
    }
    return items.toSet().toList();
  }

  List<String> _haiRowLabelItems(Map<String, dynamic> row, String fieldName) {
    final labels = row['haiQuestionnaireResponseLabels'] is Map
        ? Map<String, dynamic>.from(
            row['haiQuestionnaireResponseLabels'] as Map,
          )
        : const <String, dynamic>{};
    final responses = row['haiQuestionnaireResponses'] is Map
        ? Map<String, dynamic>.from(row['haiQuestionnaireResponses'] as Map)
        : const <String, dynamic>{};
    final value = labels[fieldName] ?? responses[fieldName];
    if (value is Iterable) {
      return value.map((item) => '$item'.trim()).toList();
    }
    final text = '$value'.trim();
    if (text.isEmpty || text == 'null') return const [];
    return text
        .split(RegExp(r'[,;]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<_HaiCountRow> _haiCountRows(Map<String, int> counts, int denominator) {
    final rows =
        counts.entries
            .where((entry) => entry.key.trim().isNotEmpty && entry.value > 0)
            .map(
              (entry) => _HaiCountRow(
                label: entry.key,
                count: entry.value,
                percentage: denominator == 0
                    ? 0
                    : (entry.value / denominator) * 100,
              ),
            )
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    return rows;
  }

  String _normalizeHaiKey(String value) => value
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '')
      .trim();

  double _rate(int numerator, int denominator) =>
      denominator == 0 ? 0 : (numerator / denominator) * 100;

  double _ratePer1000(int numerator, int denominator) =>
      denominator == 0 ? 0 : (numerator / denominator) * 1000;

  static const _haiTemplateWards = [
    'Burns & Plastic Ward',
    'Male Surgical Ward',
    'Female Surgical Ward',
    'Male Orthopaedic Ward',
    'Paediatric Surgical Ward',
    'Urology Ward',
    'Male Medical Ward',
    'Female Medical Ward',
    'Paediatric Medical Ward',
    'Special Baby Care Unit',
    'Obstetric Ward',
    'Gynae Ward',
    'Oncology Ward',
    'Amenity Ward',
    'Isolation Ward',
    'Intensive Care Unit',
  ];

  Widget _haiInterpretationCard({
    required String title,
    required String body,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(_cleanIpcAiText(body)),
          ],
        ),
      ),
    );
  }

  MapEntry<String, int>? _topCount(Map<String, int> counts) {
    final entries = counts.entries
        .where((entry) => entry.key.trim().isNotEmpty && entry.value > 0)
        .toList();
    if (entries.isEmpty) return null;
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.first;
  }

  Widget _haiSummaryCard(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }

  String _questionnaireLabel(Map<String, dynamic> row, String fieldName) {
    return _haiRowLabel(row, fieldName);
  }

  String _questionnaireLabelAny(
    Map<String, dynamic> row, {
    required List<String> keys,
    List<String> questionNumbers = const [],
    List<String> labelContains = const [],
  }) {
    for (final key in keys) {
      final value = _questionnaireLabel(row, key);
      if (_isUsefulHaiAnswer(value)) return value;
    }

    final labels = row['haiQuestionnaireResponseLabels'] is Map
        ? Map<String, dynamic>.from(
            row['haiQuestionnaireResponseLabels'] as Map,
          )
        : const <String, dynamic>{};
    final responses = row['haiQuestionnaireResponses'] is Map
        ? Map<String, dynamic>.from(row['haiQuestionnaireResponses'] as Map)
        : const <String, dynamic>{};
    final questionLabels = row['haiQuestionnaireQuestionLabels'] is Map
        ? Map<String, dynamic>.from(
            row['haiQuestionnaireQuestionLabels'] as Map,
          )
        : const <String, dynamic>{};

    for (final key in _haiCandidateKeys(keys, questionNumbers)) {
      final value = labels[key] ?? responses[key] ?? row[key];
      final text = _haiAnswerText(value);
      if (_isUsefulHaiAnswer(text)) return text;
    }

    if (questionLabels.isNotEmpty) {
      final normalizedContains = labelContains
          .map(_normalizeHaiLookupText)
          .where((item) => item.isNotEmpty)
          .toList();
      for (final entry in questionLabels.entries) {
        final prompt = '${entry.value}';
        final normalizedPrompt = _normalizeHaiLookupText(prompt);
        final numberMatch = questionNumbers.any(
          (number) => RegExp(
            r'^\s*' + RegExp.escape(number) + r'[\).\s_-]',
          ).hasMatch(prompt),
        );
        final labelMatch = normalizedContains.any(
          (needle) => _haiSemanticLabelMatches(normalizedPrompt, needle),
        );
        if (!numberMatch && !labelMatch) continue;
        final key = entry.key;
        final value = labels[key] ?? responses[key] ?? row[key];
        final text = _haiAnswerText(value);
        if (_isUsefulHaiAnswer(text)) return text;
      }
    }

    return 'Unknown';
  }

  Set<String> _haiCandidateKeys(List<String> keys, List<String> numbers) {
    final candidates = <String>{};
    for (final key in keys) {
      candidates
        ..add(key)
        ..add(key.toLowerCase())
        ..add(key.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_'))
        ..add(
          key
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
              .replaceAll(RegExp(r'^_+|_+$'), ''),
        );
    }
    for (final number in numbers) {
      candidates
        ..add(number)
        ..add('_$number')
        ..add('q$number')
        ..add('q_$number')
        ..add('question_$number')
        ..add('Question_$number');
    }
    return candidates;
  }

  String _haiAnswerText(Object? value) {
    if (value is Iterable) {
      return value.map((item) => '$item').join(', ');
    }
    return '${value ?? ''}'.trim();
  }

  bool _isUsefulHaiAnswer(String value) {
    final text = value.trim();
    return text.isNotEmpty && text != 'Unknown' && text != 'null';
  }

  bool _isAffirmativeHaiAnswer(String value) {
    final text = value.trim().toLowerCase();
    return text == 'yes' ||
        text == 'true' ||
        text == 'present' ||
        text == 'available' ||
        text == 'confirmed';
  }

  bool _haiSemanticLabelMatches(
    String normalizedPrompt,
    String normalizedNeedle,
  ) {
    if (normalizedPrompt.contains(normalizedNeedle)) return true;
    final promptTokens = normalizedPrompt
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toSet();
    final needleTokens = normalizedNeedle
        .split(' ')
        .where((token) => token.length > 2)
        .toList();
    if (needleTokens.isEmpty) return false;
    return needleTokens.every(promptTokens.contains);
  }

  String _normalizeHaiLookupText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  Color _dataStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'not approved':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color? _readmissionGroupColor(String groupId) {
    if (groupId.isEmpty) return null;
    final hue = groupId.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % 360;
    return HSVColor.fromAHSV(1, hue.toDouble(), 0.58, 0.78).toColor();
  }

  static String _csvCell(Object? value) {
    final text = '${value ?? ''}'.replaceAll('"', '""');
    return '"$text"';
  }
}

class _DownloadedReport {
  final String? id;
  final String name;
  final DateTime downloadedAt;
  final int recordCount;
  final Uint8List? bytes;
  final String? mimeType;
  final String? storagePath;

  const _DownloadedReport({
    this.id,
    required this.name,
    required this.downloadedAt,
    required this.recordCount,
    this.bytes,
    this.mimeType,
    this.storagePath,
  });
}

class _IpcAssessmentReportSection {
  final String label;
  final double score;
  final double maxScore;

  const _IpcAssessmentReportSection({
    required this.label,
    required this.score,
    required this.maxScore,
  });

  double get percentage => maxScore == 0 ? 0 : (score / maxScore) * 100;
}

class _IpcAssessmentReportSuggestion {
  final List<String> improvementAreas;
  final List<String> recommendations;
  final String remarks;

  const _IpcAssessmentReportSuggestion({
    required this.improvementAreas,
    required this.recommendations,
    required this.remarks,
  });

  bool get isEmpty =>
      improvementAreas.isEmpty && recommendations.isEmpty && remarks.isEmpty;
}

class _IpcAssessmentGeneratedReport {
  final String title;
  final String tool;
  final String facilityName;
  final DateTime reportDate;
  final DateTime? assessmentDate;
  final String assessorName;
  final int recordCount;
  final double totalScore;
  final double maxScore;
  final String level;
  final List<_IpcAssessmentReportSection> sections;
  final List<String> improvementAreas;
  final List<String> recommendations;
  final String remarks;
  final String? logoUrl;

  const _IpcAssessmentGeneratedReport({
    required this.title,
    required this.tool,
    required this.facilityName,
    required this.reportDate,
    required this.assessmentDate,
    required this.assessorName,
    required this.recordCount,
    required this.totalScore,
    required this.maxScore,
    required this.level,
    required this.sections,
    required this.improvementAreas,
    required this.recommendations,
    required this.remarks,
    required this.logoUrl,
  });

  String get summary =>
      '$title for $recordCount selected assessment record${recordCount == 1 ? '' : 's'} shows a total score of ${totalScore.toStringAsFixed(totalScore % 1 == 0 ? 0 : 1)} out of ${maxScore.toStringAsFixed(maxScore % 1 == 0 ? 0 : 1)}. The facility is currently at $level level based on the selected tool scoring criteria.';

  _IpcAssessmentGeneratedReport copyWith({String? logoUrl}) {
    return _IpcAssessmentGeneratedReport(
      title: title,
      tool: tool,
      facilityName: facilityName,
      reportDate: reportDate,
      assessmentDate: assessmentDate,
      assessorName: assessorName,
      recordCount: recordCount,
      totalScore: totalScore,
      maxScore: maxScore,
      level: level,
      sections: sections,
      improvementAreas: improvementAreas,
      recommendations: recommendations,
      remarks: remarks,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }
}

class _HaiReportChoice {
  final String id;
  final String label;

  const _HaiReportChoice(this.id, this.label);
}

class _HaiReportOptions {
  final DateTime reportDate;
  final int month;
  final String period;
  final String basis;
  final String surveillanceType;
  final String reportScope;
  final Set<String> sectionIds;
  final Set<String> summaryMetricIds;
  final String outputFormat;
  final String dateBasis;

  const _HaiReportOptions({
    required this.reportDate,
    required this.month,
    required this.period,
    required this.basis,
    required this.surveillanceType,
    required this.reportScope,
    required this.sectionIds,
    required this.summaryMetricIds,
    required this.outputFormat,
    required this.dateBasis,
  });
}

class _HaiGeneratedReport {
  final String title;
  final String facilityName;
  final _HaiReportOptions options;
  final int totalRecords;
  final int totalInfected;
  final int totalDenominator;
  final int totalPatientDays;
  final List<_HaiLabWardRow> labWardRows;
  final List<_HaiPathogenSiteRow> pathogenSiteRows;
  final List<_HaiMicrobiologyRow> microbiologyRows;
  final List<_HaiResistanceRow> resistanceRows;
  final List<_HaiCountRow> antimicrobialHabitRows;
  final List<_HaiCountRow> antimicrobialAgentRows;
  final int totalOnAntimicrobials;
  final List<_HaiClinicalExposureRow> clinicalExposureRows;
  final List<_HaiClinicalIncidenceRow> clinicalIncidenceRows;
  final List<_HaiDeviceIncidenceRow> deviceIncidenceRows;
  final List<_HaiAmsRow> amsRows;
  final Map<String, int> serviceCounts;
  final Map<String, int> siteCounts;
  final Map<String, int> pathogenCounts;
  final Map<String, int> outcomeCounts;
  final int uniqueOutcomeDenominator;
  final int haiContributedDeaths;
  final String remarks;
  final String? logoUrl;

  const _HaiGeneratedReport({
    required this.title,
    required this.facilityName,
    required this.options,
    required this.totalRecords,
    required this.totalInfected,
    required this.totalDenominator,
    required this.totalPatientDays,
    required this.labWardRows,
    required this.pathogenSiteRows,
    required this.microbiologyRows,
    required this.resistanceRows,
    required this.antimicrobialHabitRows,
    required this.antimicrobialAgentRows,
    required this.totalOnAntimicrobials,
    required this.clinicalExposureRows,
    required this.clinicalIncidenceRows,
    required this.deviceIncidenceRows,
    required this.amsRows,
    required this.serviceCounts,
    required this.siteCounts,
    required this.pathogenCounts,
    required this.outcomeCounts,
    required this.uniqueOutcomeDenominator,
    required this.haiContributedDeaths,
    required this.remarks,
    required this.logoUrl,
  });

  int get nonDeviceTotal =>
      labWardRows.fold<int>(0, (sum, row) => sum + row.haiCount);

  int get deviceTotal => deviceIncidenceRows.fold<int>(
    0,
    (sum, row) => sum + row.cauti + row.cvcHai + row.pvcHai + row.invHai,
  );

  int get totalHaiCases => nonDeviceTotal + deviceTotal;

  double get overallRate =>
      totalPatientDays == 0 ? 0 : (totalHaiCases / totalPatientDays) * 1000;

  double get overallPercentage =>
      totalDenominator == 0 ? 0 : (totalHaiCases / totalDenominator) * 100;

  String get overallRateLabel =>
      totalPatientDays == 0 ? 'N/A' : overallRate.toStringAsFixed(2);

  String get overallPercentageLabel => totalDenominator == 0
      ? 'N/A'
      : '${overallPercentage.toStringAsFixed(1)}%';

  Map<String, int> get combinedHaiTypeCounts {
    final labTotals = labWardRows.fold<_HaiLabWardRow>(
      _HaiLabWardRow.empty('Total'),
      (sum, row) => sum + row,
    );
    final deviceTotals = deviceIncidenceRows.fold<_HaiDeviceIncidenceRow>(
      _HaiDeviceIncidenceRow.empty('Total'),
      (sum, row) => sum + row,
    );
    return {
      'SSI': labTotals.ssi,
      'Non-catheter UTI': labTotals.uti,
      'Non-central-line BSI': labTotals.bsi,
      'HAP': labTotals.rti,
      'Skin and soft-tissue infection': labTotals.sst,
      'Neonatal sepsis': labTotals.neonatalSepsis,
      'Other non-device HAI': labTotals.git + labTotals.others,
      'CAUTI': deviceTotals.cauti,
      'CLABSI': deviceTotals.cvcHai,
      'PLABSI': deviceTotals.pvcHai,
      'VAP': deviceTotals.invHai,
    };
  }

  Map<String, int> get wardTotalHaiCounts {
    final totals = <String, int>{};
    for (final row in labWardRows) {
      totals[row.ward] = (totals[row.ward] ?? 0) + row.haiCount;
    }
    for (final row in deviceIncidenceRows) {
      totals[row.ward] =
          (totals[row.ward] ?? 0) +
          row.cauti +
          row.cvcHai +
          row.pvcHai +
          row.invHai;
    }
    totals.removeWhere((key, value) => value <= 0);
    return totals;
  }

  Map<String, dynamic> toApprovalMap() => {
    'title': title,
    'facilityName': facilityName,
    'totalRecords': totalRecords,
    'totalInfected': totalInfected,
    'totalHaiCases': totalHaiCases,
    'totalNonDeviceHaiCases': nonDeviceTotal,
    'totalDeviceAssociatedHaiCases': deviceTotal,
    'totalDischarges': totalDenominator,
    'totalPatientDays': totalPatientDays,
    'overallRate': overallRate,
    'overallPercentage': overallPercentage,
    'remarks': remarks,
    'logoUrl': logoUrl,
    'options': {
      'reportDate': Timestamp.fromDate(options.reportDate),
      'month': options.month,
      'period': options.period,
      'basis': options.basis,
      'surveillanceType': options.surveillanceType,
      'reportScope': options.reportScope,
      'sectionIds': options.sectionIds.toList(),
      'summaryMetricIds': options.summaryMetricIds.toList(),
      'outputFormat': options.outputFormat,
      'dateBasis': options.dateBasis,
    },
    'labWardRows': labWardRows.map((row) => row.toMap()).toList(),
    'pathogenSiteRows': pathogenSiteRows.map((row) => row.toMap()).toList(),
    'microbiologyRows': microbiologyRows.map((row) => row.toMap()).toList(),
    'resistanceRows': resistanceRows.map((row) => row.toMap()).toList(),
    'antimicrobialHabitRows': antimicrobialHabitRows
        .map((row) => row.toMap())
        .toList(),
    'antimicrobialAgentRows': antimicrobialAgentRows
        .map((row) => row.toMap())
        .toList(),
    'totalOnAntimicrobials': totalOnAntimicrobials,
    'clinicalExposureRows': clinicalExposureRows
        .map((row) => row.toMap())
        .toList(),
    'clinicalIncidenceRows': clinicalIncidenceRows
        .map((row) => row.toMap())
        .toList(),
    'deviceIncidenceRows': deviceIncidenceRows
        .map((row) => row.toMap())
        .toList(),
    'amsRows': amsRows.map((row) => row.toMap()).toList(),
    'serviceCounts': serviceCounts,
    'siteCounts': siteCounts,
    'pathogenCounts': pathogenCounts,
    'outcomeCounts': outcomeCounts,
    'uniqueOutcomeDenominator': uniqueOutcomeDenominator,
    'haiContributedDeaths': haiContributedDeaths,
  };
}

class _HaiLabWardRow {
  final String ward;
  final int patientDays;
  final int discharges;
  final int cultureRequests;
  final int haiCount;
  final double wardPercent;
  final double haiRatePer1000;
  final int ssi;
  final int sst;
  final int rti;
  final int bsi;
  final int uti;
  final int git;
  final int neonatalSepsis;
  final int others;
  final int infectedPatients;

  const _HaiLabWardRow({
    required this.ward,
    required this.patientDays,
    required this.discharges,
    required this.cultureRequests,
    required this.haiCount,
    required this.wardPercent,
    required this.haiRatePer1000,
    required this.ssi,
    required this.sst,
    required this.rti,
    required this.bsi,
    required this.uti,
    required this.git,
    required this.neonatalSepsis,
    required this.others,
    required this.infectedPatients,
  });

  double get ssiPercent => discharges == 0 ? 0 : (ssi / discharges) * 100;
  double get sstPercent => discharges == 0 ? 0 : (sst / discharges) * 100;
  double get rtiPercent => discharges == 0 ? 0 : (rti / discharges) * 100;
  double get bsiPercent => discharges == 0 ? 0 : (bsi / discharges) * 100;
  double get utiPercent => discharges == 0 ? 0 : (uti / discharges) * 100;
  double get gitPercent => discharges == 0 ? 0 : (git / discharges) * 100;
  double get othersPercent => discharges == 0 ? 0 : (others / discharges) * 100;
  String get haiRateLabel =>
      patientDays == 0 ? 'N/A' : haiRatePer1000.toStringAsFixed(2);
  String get wardPercentLabel =>
      discharges == 0 ? 'N/A' : '${wardPercent.toStringAsFixed(1)}%';
  int get infectionSiteTotal =>
      ssi + sst + rti + bsi + uti + git + neonatalSepsis + others;

  factory _HaiLabWardRow.empty(String ward) => _HaiLabWardRow(
    ward: ward,
    patientDays: 0,
    discharges: 0,
    cultureRequests: 0,
    haiCount: 0,
    wardPercent: 0,
    haiRatePer1000: 0,
    ssi: 0,
    sst: 0,
    rti: 0,
    bsi: 0,
    uti: 0,
    git: 0,
    neonatalSepsis: 0,
    others: 0,
    infectedPatients: 0,
  );

  _HaiLabWardRow operator +(_HaiLabWardRow other) {
    final totalHai = haiCount + other.haiCount;
    final totalDischarges = discharges + other.discharges;
    final totalPatientDays = patientDays + other.patientDays;
    return _HaiLabWardRow(
      ward: ward,
      patientDays: totalPatientDays,
      discharges: totalDischarges,
      cultureRequests: cultureRequests + other.cultureRequests,
      haiCount: totalHai,
      wardPercent: totalDischarges == 0
          ? 0
          : (totalHai / totalDischarges) * 100,
      haiRatePer1000: totalPatientDays == 0
          ? 0
          : (totalHai / totalPatientDays) * 1000,
      ssi: ssi + other.ssi,
      sst: sst + other.sst,
      rti: rti + other.rti,
      bsi: bsi + other.bsi,
      uti: uti + other.uti,
      git: git + other.git,
      neonatalSepsis: neonatalSepsis + other.neonatalSepsis,
      others: others + other.others,
      infectedPatients: infectedPatients + other.infectedPatients,
    );
  }

  Map<String, dynamic> toMap() => {
    'ward': ward,
    'patientDays': patientDays,
    'discharges': discharges,
    'cultureRequests': cultureRequests,
    'haiCount': haiCount,
    'wardPercent': wardPercent,
    'haiRatePer1000': haiRatePer1000,
    'ssi': ssi,
    'sst': sst,
    'rti': rti,
    'bsi': bsi,
    'uti': uti,
    'git': git,
    'neonatalSepsis': neonatalSepsis,
    'others': others,
    'infectedPatients': infectedPatients,
  };
}

class _HaiPathogenSiteRow {
  final String pathogen;
  final int ssi;
  final int sst;
  final int rti;
  final int bsi;
  final int uti;
  final int git;
  final int others;
  final int total;
  final double percentage;

  const _HaiPathogenSiteRow({
    required this.pathogen,
    required this.ssi,
    required this.sst,
    required this.rti,
    required this.bsi,
    required this.uti,
    required this.git,
    required this.others,
    required this.total,
    required this.percentage,
  });

  Map<String, dynamic> toMap() => {
    'pathogen': pathogen,
    'ssi': ssi,
    'sst': sst,
    'rti': rti,
    'bsi': bsi,
    'uti': uti,
    'git': git,
    'others': others,
    'total': total,
    'percentage': percentage,
  };
}

class _HaiMicrobiologyRow {
  final String organism;
  final int ssi;
  final int sst;
  final int rti;
  final int bsi;
  final int uti;
  final int git;
  final int others;
  final int total;
  final double percentage;

  const _HaiMicrobiologyRow({
    required this.organism,
    required this.ssi,
    required this.sst,
    required this.rti,
    required this.bsi,
    required this.uti,
    required this.git,
    required this.others,
    required this.total,
    required this.percentage,
  });

  Map<String, dynamic> toMap() => {
    'organism': organism,
    'ssi': ssi,
    'sst': sst,
    'rti': rti,
    'bsi': bsi,
    'uti': uti,
    'git': git,
    'others': others,
    'total': total,
    'percentage': percentage,
  };
}

class _HaiIsolate {
  final String organism;
  final String pattern;

  const _HaiIsolate({required this.organism, required this.pattern});
}

class _HaiCountRow {
  final String label;
  final int count;
  final double percentage;

  const _HaiCountRow({
    required this.label,
    required this.count,
    required this.percentage,
  });

  String get percentLabel => '${percentage.toStringAsFixed(1)}%';

  Map<String, dynamic> toMap() => {
    'label': label,
    'count': count,
    'percentage': percentage,
  };
}

class _HaiResistanceRow {
  final String organism;
  final int totalTested;
  final int mdr;
  final int mdrDenominator;
  final int esbl;
  final int esblDenominator;
  final int carbapenemResistant;
  final int carbapenemDenominator;
  final int mrsa;
  final int mrsaDenominator;
  final int vre;
  final int vreDenominator;

  const _HaiResistanceRow({
    required this.organism,
    required this.totalTested,
    required this.mdr,
    required this.mdrDenominator,
    required this.esbl,
    required this.esblDenominator,
    required this.carbapenemResistant,
    required this.carbapenemDenominator,
    required this.mrsa,
    required this.mrsaDenominator,
    required this.vre,
    required this.vreDenominator,
  });

  String get mdrLabel => _resistanceLabel(mdr, mdrDenominator);
  String get esblLabel => _resistanceLabel(esbl, esblDenominator);
  String get carbapenemLabel =>
      _resistanceLabel(carbapenemResistant, carbapenemDenominator);
  String get mrsaLabel => _resistanceLabel(mrsa, mrsaDenominator);
  String get vreLabel => _resistanceLabel(vre, vreDenominator);

  List<Object> toCells() => [
    organism,
    totalTested,
    mdrLabel,
    esblLabel,
    carbapenemLabel,
    mrsaLabel,
    vreLabel,
  ];

  Map<String, dynamic> toMap() => {
    'organism': organism,
    'totalTested': totalTested,
    'mdr': mdr,
    'mdrDenominator': mdrDenominator,
    'esbl': esbl,
    'esblDenominator': esblDenominator,
    'carbapenemResistant': carbapenemResistant,
    'carbapenemDenominator': carbapenemDenominator,
    'mrsa': mrsa,
    'mrsaDenominator': mrsaDenominator,
    'vre': vre,
    'vreDenominator': vreDenominator,
  };

  static String _resistanceLabel(int numerator, int denominator) {
    if (denominator == 0) return 'N/A';
    return '$numerator (${((numerator / denominator) * 100).toStringAsFixed(1)}%)';
  }
}

class _HaiResistanceAccumulator {
  final String organism;
  int totalTested = 0;
  int mdr = 0;
  int mdrDenominator = 0;
  int esbl = 0;
  int esblDenominator = 0;
  int carbapenemResistant = 0;
  int carbapenemDenominator = 0;
  int mrsa = 0;
  int mrsaDenominator = 0;
  int vre = 0;
  int vreDenominator = 0;

  _HaiResistanceAccumulator(this.organism);

  void addPattern(String pattern) {
    final value = pattern.toLowerCase();
    if (value.isEmpty) return;
    totalTested += 1;
    final noResistance = value.contains('no resistant');
    if (!noResistance && value.contains('mdr')) {
      mdr += 1;
      mdrDenominator += 1;
    } else {
      mdrDenominator += 1;
    }
    if (_isEsblApplicable &&
        !noResistance &&
        (value.contains('c3g') || value.contains('esbl'))) {
      esbl += 1;
      esblDenominator += 1;
    } else if (_isEsblApplicable) {
      esblDenominator += 1;
    }
    if (_isCarbapenemApplicable &&
        !noResistance &&
        (value == 'car' || value.contains('car'))) {
      carbapenemResistant += 1;
      carbapenemDenominator += 1;
    } else if (_isCarbapenemApplicable) {
      carbapenemDenominator += 1;
    }
    if (_isMrsaApplicable && !noResistance && value.contains('mrsa')) {
      mrsa += 1;
      mrsaDenominator += 1;
    } else if (_isMrsaApplicable) {
      mrsaDenominator += 1;
    }
    if (_isVreApplicable && !noResistance && value.contains('vre')) {
      vre += 1;
      vreDenominator += 1;
    } else if (_isVreApplicable) {
      vreDenominator += 1;
    }
  }

  void addRow(_HaiResistanceRow row) {
    totalTested += row.totalTested;
    mdr += row.mdr;
    mdrDenominator += row.mdrDenominator;
    esbl += row.esbl;
    esblDenominator += row.esblDenominator;
    carbapenemResistant += row.carbapenemResistant;
    carbapenemDenominator += row.carbapenemDenominator;
    mrsa += row.mrsa;
    mrsaDenominator += row.mrsaDenominator;
    vre += row.vre;
    vreDenominator += row.vreDenominator;
  }

  bool get _isEsblApplicable {
    final text = organism.toLowerCase();
    return text.contains('escherichia') ||
        text.contains('enterobacter') ||
        text.contains('citrobacter') ||
        text.contains('klebsiella') ||
        text.contains('morganella') ||
        text.contains('proteus') ||
        text.contains('serratia');
  }

  bool get _isCarbapenemApplicable {
    final text = organism.toLowerCase();
    return text.contains('acinetobacter') ||
        text.contains('pseudomonas') ||
        _isEsblApplicable;
  }

  bool get _isMrsaApplicable => organism.toLowerCase().contains('staph');
  bool get _isVreApplicable => organism.toLowerCase().contains('enterococcus');

  _HaiResistanceRow toRow() => _HaiResistanceRow(
    organism: organism,
    totalTested: totalTested,
    mdr: mdr,
    mdrDenominator: mdrDenominator,
    esbl: esbl,
    esblDenominator: esblDenominator,
    carbapenemResistant: carbapenemResistant,
    carbapenemDenominator: carbapenemDenominator,
    mrsa: mrsa,
    mrsaDenominator: mrsaDenominator,
    vre: vre,
    vreDenominator: vreDenominator,
  );
}

class _HaiClinicalExposureRow {
  final String ward;
  final int patientsSurveyed;
  final int surgicalPatients;
  final int urinaryCatheter;
  final int urinaryCatheterInsertions;
  final int catheterDays;
  final int cvc;
  final int cvcInsertions;
  final int cvcDays;
  final int pvc;
  final int pvcInsertions;
  final int pvcDays;
  final int inv;
  final int invInsertions;
  final int invDays;
  final int niv;
  final int nivDays;

  const _HaiClinicalExposureRow({
    required this.ward,
    required this.patientsSurveyed,
    required this.surgicalPatients,
    required this.urinaryCatheter,
    required this.urinaryCatheterInsertions,
    required this.catheterDays,
    required this.cvc,
    required this.cvcInsertions,
    required this.cvcDays,
    required this.pvc,
    required this.pvcInsertions,
    required this.pvcDays,
    required this.inv,
    required this.invInsertions,
    required this.invDays,
    required this.niv,
    required this.nivDays,
  });

  Map<String, dynamic> toMap() => {
    'ward': ward,
    'patientsSurveyed': patientsSurveyed,
    'surgicalPatients': surgicalPatients,
    'urinaryCatheter': urinaryCatheter,
    'catheterDays': catheterDays,
    'cvc': cvc,
    'cvcDays': cvcDays,
    'pvc': pvc,
    'pvcDays': pvcDays,
    'inv': inv,
    'invDays': invDays,
    'niv': niv,
    'nivDays': nivDays,
  };
}

class _HaiClinicalIncidenceRow {
  final String ward;
  final int ssi;
  final int bsi;
  final int uti;
  final int git;
  final int sst;
  final int rti;
  final int others;
  final int totalHai;
  final int patients;
  final int surgicalPatients;

  const _HaiClinicalIncidenceRow({
    required this.ward,
    required this.ssi,
    required this.bsi,
    required this.uti,
    required this.git,
    required this.sst,
    required this.rti,
    required this.others,
    required this.totalHai,
    required this.patients,
    required this.surgicalPatients,
  });

  double get ssiPercent =>
      surgicalPatients == 0 ? 0 : (ssi / surgicalPatients) * 100;
  double get bsiPercent => patients == 0 ? 0 : (bsi / patients) * 100;
  double get utiPercent => patients == 0 ? 0 : (uti / patients) * 100;
  double get gitPercent => patients == 0 ? 0 : (git / patients) * 100;
  double get sstPercent => patients == 0 ? 0 : (sst / patients) * 100;
  double get rtiPercent => patients == 0 ? 0 : (rti / patients) * 100;
  double get othersPercent => patients == 0 ? 0 : (others / patients) * 100;
  double get othersWithGitPercent =>
      patients == 0 ? 0 : ((git + others) / patients) * 100;
  String get ssiLabel => _targetedPercentLabel(ssi, surgicalPatients);
  String get bsiLabel => _targetedPercentLabel(bsi, patients);
  String get utiLabel => _targetedPercentLabel(uti, patients);
  String get gitLabel => _targetedPercentLabel(git, patients);
  String get sstLabel => _targetedPercentLabel(sst, patients);
  String get rtiLabel => _targetedPercentLabel(rti, patients);
  String get othersLabel => _targetedPercentLabel(others, patients);
  String get othersWithGitLabel =>
      _targetedPercentLabel(git + others, patients);

  static String _targetedPercentLabel(int numerator, int denominator) {
    if (denominator == 0) return '$numerator / N/A';
    return '$numerator / $denominator (${((numerator / denominator) * 100).toStringAsFixed(1)}%)';
  }

  Map<String, dynamic> toMap() => {
    'ward': ward,
    'ssi': ssi,
    'bsi': bsi,
    'uti': uti,
    'git': git,
    'sst': sst,
    'rti': rti,
    'others': others,
    'totalHai': totalHai,
    'patients': patients,
    'surgicalPatients': surgicalPatients,
  };
}

class _HaiDeviceIncidenceRow {
  final String ward;
  final int patientDays;
  final int cvcHai;
  final int pvcHai;
  final int cauti;
  final int invHai;
  final int nivHai;
  final int cvc;
  final int cvcInsertions;
  final int pvc;
  final int pvcInsertions;
  final int urinaryCatheter;
  final int urinaryCatheterInsertions;
  final int inv;
  final int invInsertions;
  final int niv;

  const _HaiDeviceIncidenceRow({
    required this.ward,
    required this.patientDays,
    required this.cvcHai,
    required this.pvcHai,
    required this.cauti,
    required this.invHai,
    required this.nivHai,
    required this.cvc,
    required this.cvcInsertions,
    required this.pvc,
    required this.pvcInsertions,
    required this.urinaryCatheter,
    required this.urinaryCatheterInsertions,
    required this.inv,
    required this.invInsertions,
    required this.niv,
  });

  factory _HaiDeviceIncidenceRow.empty(String ward) => _HaiDeviceIncidenceRow(
    ward: ward,
    patientDays: 0,
    cvcHai: 0,
    pvcHai: 0,
    cauti: 0,
    invHai: 0,
    nivHai: 0,
    cvc: 0,
    cvcInsertions: 0,
    pvc: 0,
    pvcInsertions: 0,
    urinaryCatheter: 0,
    urinaryCatheterInsertions: 0,
    inv: 0,
    invInsertions: 0,
    niv: 0,
  );

  _HaiDeviceIncidenceRow operator +(_HaiDeviceIncidenceRow other) {
    return _HaiDeviceIncidenceRow(
      ward: ward,
      patientDays: patientDays + other.patientDays,
      cvcHai: cvcHai + other.cvcHai,
      pvcHai: pvcHai + other.pvcHai,
      cauti: cauti + other.cauti,
      invHai: invHai + other.invHai,
      nivHai: nivHai + other.nivHai,
      cvc: cvc + other.cvc,
      cvcInsertions: cvcInsertions + other.cvcInsertions,
      pvc: pvc + other.pvc,
      pvcInsertions: pvcInsertions + other.pvcInsertions,
      urinaryCatheter: urinaryCatheter + other.urinaryCatheter,
      urinaryCatheterInsertions:
          urinaryCatheterInsertions + other.urinaryCatheterInsertions,
      inv: inv + other.inv,
      invInsertions: invInsertions + other.invInsertions,
      niv: niv + other.niv,
    );
  }

  double get clabsiPercent =>
      cvcInsertions == 0 ? 0 : (cvcHai / cvcInsertions) * 100;
  double get plabsiPercent =>
      pvcInsertions == 0 ? 0 : (pvcHai / pvcInsertions) * 100;
  double get cautiPercent => urinaryCatheterInsertions == 0
      ? 0
      : (cauti / urinaryCatheterInsertions) * 100;
  double get vapPercent =>
      invInsertions == 0 ? 0 : (invHai / invInsertions) * 100;
  double get nivPercent => niv == 0 ? 0 : (nivHai / niv) * 100;
  double get catheterUtilization =>
      _ratio(urinaryCatheter, patientDaysForUtilization);
  double get centralLineUtilization => _ratio(cvc, patientDaysForUtilization);
  double get peripheralLineUtilization =>
      _ratio(pvc, patientDaysForUtilization);
  double get ventilatorUtilization => _ratio(inv, patientDaysForUtilization);
  double get clabsiRate => _per1000(cvcHai, cvc);
  double get plabsiRate => _per1000(pvcHai, pvc);
  double get cautiRate => _per1000(cauti, urinaryCatheter);
  double get vapRate => _per1000(invHai, inv);
  int get patientDaysForUtilization => patientDays;
  String get catheterUtilizationLabel => patientDaysForUtilization == 0
      ? 'N/A'
      : catheterUtilization.toStringAsFixed(2);
  String get centralLineUtilizationLabel => patientDaysForUtilization == 0
      ? 'N/A'
      : centralLineUtilization.toStringAsFixed(2);
  String get peripheralLineUtilizationLabel => patientDaysForUtilization == 0
      ? 'N/A'
      : peripheralLineUtilization.toStringAsFixed(2);
  String get ventilatorUtilizationLabel => patientDaysForUtilization == 0
      ? 'N/A'
      : ventilatorUtilization.toStringAsFixed(2);
  String get clabsiRateLabel =>
      cvc == 0 ? 'N/A' : clabsiRate.toStringAsFixed(2);
  String get plabsiRateLabel =>
      pvc == 0 ? 'N/A' : plabsiRate.toStringAsFixed(2);
  String get cautiRateLabel =>
      urinaryCatheter == 0 ? 'N/A' : cautiRate.toStringAsFixed(2);
  String get vapRateLabel => inv == 0 ? 'N/A' : vapRate.toStringAsFixed(2);
  String get cautiPercentLabel => urinaryCatheterInsertions == 0
      ? 'N/A'
      : '${cautiPercent.toStringAsFixed(1)}%';
  String get clabsiPercentLabel =>
      cvcInsertions == 0 ? 'N/A' : '${clabsiPercent.toStringAsFixed(1)}%';
  String get plabsiPercentLabel =>
      pvcInsertions == 0 ? 'N/A' : '${plabsiPercent.toStringAsFixed(1)}%';
  String get vapPercentLabel =>
      invInsertions == 0 ? 'N/A' : '${vapPercent.toStringAsFixed(1)}%';

  static double _ratio(int numerator, int denominator) =>
      denominator == 0 ? 0 : numerator / denominator;

  static double _per1000(int numerator, int denominator) =>
      denominator == 0 ? 0 : (numerator / denominator) * 1000;

  Map<String, dynamic> toMap() => {
    'ward': ward,
    'patientDays': patientDays,
    'cvcHai': cvcHai,
    'pvcHai': pvcHai,
    'cauti': cauti,
    'invHai': invHai,
    'nivHai': nivHai,
    'cvc': cvc,
    'cvcInsertions': cvcInsertions,
    'pvc': pvc,
    'pvcInsertions': pvcInsertions,
    'urinaryCatheter': urinaryCatheter,
    'urinaryCatheterInsertions': urinaryCatheterInsertions,
    'inv': inv,
    'invInsertions': invInsertions,
    'niv': niv,
  };
}

class _HaiAmsRow {
  final String ward;
  final int totalPatients;
  final int totalOnAntimicrobials;
  final int empiricalCai;
  final int targetedCai;
  final int empiricalHai;
  final int targetedHai;
  final int surgicalProphylaxis;
  final int medicalProphylaxis;
  final int unknownIndication;
  final int cultureRequests;
  final int positiveCultures;

  const _HaiAmsRow({
    required this.ward,
    required this.totalPatients,
    required this.totalOnAntimicrobials,
    required this.empiricalCai,
    required this.targetedCai,
    required this.empiricalHai,
    required this.targetedHai,
    required this.surgicalProphylaxis,
    required this.medicalProphylaxis,
    required this.unknownIndication,
    required this.cultureRequests,
    required this.positiveCultures,
  });

  Map<String, dynamic> toMap() => {
    'ward': ward,
    'totalPatients': totalPatients,
    'totalOnAntimicrobials': totalOnAntimicrobials,
    'empiricalCai': empiricalCai,
    'targetedCai': targetedCai,
    'empiricalHai': empiricalHai,
    'targetedHai': targetedHai,
    'surgicalProphylaxis': surgicalProphylaxis,
    'medicalProphylaxis': medicalProphylaxis,
    'unknownIndication': unknownIndication,
    'cultureRequests': cultureRequests,
    'positiveCultures': positiveCultures,
  };
}

class _HaiAmsAccumulator {
  int totalOnAntimicrobials = 0;
  int empiricalCai = 0;
  int targetedCai = 0;
  int empiricalHai = 0;
  int targetedHai = 0;
  int surgicalProphylaxis = 0;
  int medicalProphylaxis = 0;
  int unknownIndication = 0;
  int cultureRequests = 0;
  int positiveCultures = 0;

  void add(Map<String, dynamic> row) {
    final antimicrobials = _haiRowLabel(row, 'Antimicrobials').toLowerCase();
    if (antimicrobials.contains('yes')) {
      totalOnAntimicrobials += 1;
    }

    final indication = _haiRowLabel(
      row,
      'Antibiotics_indication',
    ).toLowerCase();
    if (indication.contains('community acquired') &&
        indication.contains('empirical')) {
      empiricalCai += 1;
    } else if (indication.contains('community acquired') &&
        indication.contains('targeted')) {
      targetedCai += 1;
    } else if (indication.contains('hospital acquired') &&
        indication.contains('empirical')) {
      empiricalHai += 1;
    } else if (indication.contains('hospital acquired') &&
        indication.contains('targeted')) {
      targetedHai += 1;
    } else if (indication.contains('surgical prophylaxis')) {
      surgicalProphylaxis += 1;
    } else if (indication.contains('medical prophylaxis')) {
      medicalProphylaxis += 1;
    } else if (indication.contains('unknown indication')) {
      unknownIndication += 1;
    }

    if (_haiRowLabel(row, 'Culture_requested').toLowerCase().contains('yes')) {
      cultureRequests += 1;
    }
    final cultureStatus = _haiRowLabel(
      row,
      '_48_Specify_Culture_Status',
    ).toLowerCase();
    if (cultureStatus.contains('positive') ||
        cultureStatus.contains('growth')) {
      positiveCultures += 1;
    }
  }
}

class _HaiWardDenominator {
  final String ward;
  final int discharges;
  final int cultureRequests;
  final int totalPatients;
  final int surgicalPatients;
  final int urinaryCatheter;
  final int urinaryCatheterInsertions;
  final int catheterDays;
  final int cvc;
  final int cvcInsertions;
  final int cvcDays;
  final int pvc;
  final int pvcInsertions;
  final int pvcDays;
  final int inv;
  final int invInsertions;
  final int invDays;
  final int niv;
  final int nivDays;

  const _HaiWardDenominator({
    required this.ward,
    required this.discharges,
    required this.cultureRequests,
    required this.totalPatients,
    required this.surgicalPatients,
    required this.urinaryCatheter,
    required this.urinaryCatheterInsertions,
    required this.catheterDays,
    required this.cvc,
    required this.cvcInsertions,
    required this.cvcDays,
    required this.pvc,
    required this.pvcInsertions,
    required this.pvcDays,
    required this.inv,
    required this.invInsertions,
    required this.invDays,
    required this.niv,
    required this.nivDays,
  });

  factory _HaiWardDenominator.empty(String ward) => _HaiWardDenominator(
    ward: ward,
    discharges: 0,
    cultureRequests: 0,
    totalPatients: 0,
    surgicalPatients: 0,
    urinaryCatheter: 0,
    urinaryCatheterInsertions: 0,
    catheterDays: 0,
    cvc: 0,
    cvcInsertions: 0,
    cvcDays: 0,
    pvc: 0,
    pvcInsertions: 0,
    pvcDays: 0,
    inv: 0,
    invInsertions: 0,
    invDays: 0,
    niv: 0,
    nivDays: 0,
  );

  _HaiWardDenominator operator +(_HaiWardDenominator other) {
    return _HaiWardDenominator(
      ward: ward,
      discharges: discharges + other.discharges,
      cultureRequests: cultureRequests + other.cultureRequests,
      totalPatients: totalPatients + other.totalPatients,
      surgicalPatients: surgicalPatients + other.surgicalPatients,
      urinaryCatheter: urinaryCatheter + other.urinaryCatheter,
      urinaryCatheterInsertions:
          urinaryCatheterInsertions + other.urinaryCatheterInsertions,
      catheterDays: catheterDays + other.catheterDays,
      cvc: cvc + other.cvc,
      cvcInsertions: cvcInsertions + other.cvcInsertions,
      cvcDays: cvcDays + other.cvcDays,
      pvc: pvc + other.pvc,
      pvcInsertions: pvcInsertions + other.pvcInsertions,
      pvcDays: pvcDays + other.pvcDays,
      inv: inv + other.inv,
      invInsertions: invInsertions + other.invInsertions,
      invDays: invDays + other.invDays,
      niv: niv + other.niv,
      nivDays: nivDays + other.nivDays,
    );
  }
}

class _HaiDenominatorMapping {
  static int patientDays(
    Map<String, dynamic> responses,
    Map<String, dynamic> data,
  ) => _readInt(
    responses['No_of_New_Admissions'] ??
        responses['New_Patients'] ??
        data['newPatients'] ??
        responses['Total_Patients'] ??
        data['totalPatients'],
  );

  static int discharges(
    Map<String, dynamic> responses,
    Map<String, dynamic> data,
  ) => _readInt(responses['No_of_Discharges'] ?? data['discharges']);

  static int surgicalProcedures(
    Map<String, dynamic> responses,
    Map<String, dynamic> data,
  ) => _readInt(
    responses['No_of_Surgical_Procedures'] ??
        responses['Surgical_Procedures'] ??
        responses['No_Surgical_Procedures'] ??
        responses['Number_of_Surgical_Procedures'] ??
        responses['No_of_Surgeries'] ??
        responses['Surgical_Patients'] ??
        data['surgicalProcedures'] ??
        data['surgicalPatients'],
  );

  static int urinaryCatheterDays(Map<String, dynamic> responses) =>
      _readInt(responses['No_of_patients_on_Urinary_Catheter']);

  static int urinaryCatheterInsertions(Map<String, dynamic> responses) =>
      _readInt(
        responses['New_Urinary_Catheter_Insertions'] ??
            responses['New_UC_Insertions'] ??
            responses['New_UC_Placements'] ??
            responses['New_Catheter_Insertions'] ??
            responses['New_Urinary_Catheter_Placements'],
      );

  static int centralLineDays(Map<String, dynamic> responses) =>
      _readInt(responses['No_of_patients_on_C_venous_catheter_CVC']);

  static int centralLineInsertions(Map<String, dynamic> responses) => _readInt(
    responses['New_CVC_Insertions'] ??
        responses['New_CVC_Placements'] ??
        responses['New_Central_Line_Insertions'] ??
        responses['New_Central_Venous_Catheter_Insertions'],
  );

  static int peripheralLineDays(Map<String, dynamic> responses) =>
      _readInt(responses['No_of_patients_on_P_venous_catheter_PVC']);

  static int peripheralLineInsertions(Map<String, dynamic> responses) =>
      _readInt(
        responses['New_PVC_Insertions'] ??
            responses['New_PVC_Placements'] ??
            responses['New_Peripheral_Line_Insertions'] ??
            responses['New_Peripheral_Venous_Catheter_Insertions'],
      );

  static int ventilatorDays(Map<String, dynamic> responses) =>
      _readInt(responses['No_of_patients_on_I_cal_ventilation_INV']);

  static int ventilatorInsertions(Map<String, dynamic> responses) => _readInt(
    responses['New_INV_Insertions'] ??
        responses['New_INV_Placements'] ??
        responses['New_Invasive_Ventilator_Starts'] ??
        responses['New_Invasive_Ventilator_Placements'],
  );

  static int nonInvasiveVentilatorDays(Map<String, dynamic> responses) =>
      _readInt(responses['No_of_patients_on_N_cal_ventilation_NIV']);

  static int cultureRequests(
    Map<String, dynamic> responses,
    Map<String, dynamic> data,
  ) => _readInt(
    responses['No_Culture_Request'] ??
        responses['No_of_Culture_Request'] ??
        data['cultureRequests'],
  );

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('$value') ?? 0;
  }
}

class _HandHygieneCalculatorData {
  final List<_HandHygieneCalculatorSession> sessions;
  final Map<String, _HandHygieneCalculatorCount> categoryTotals;

  const _HandHygieneCalculatorData({
    required this.sessions,
    required this.categoryTotals,
  });

  List<String> get categories => categoryTotals.keys.take(4).toList();

  int get totalOpportunities =>
      categoryTotals.values.fold(0, (sum, item) => sum + item.opp);

  int get totalActions =>
      categoryTotals.values.fold(0, (sum, item) => sum + item.hw + item.hr);

  double get complianceRate =>
      totalOpportunities == 0 ? 0 : (totalActions / totalOpportunities) * 100;
}

class _HandHygieneCalculatorSession {
  final String sessionLabel;
  final String department;
  final String ward;
  final Map<String, _HandHygieneCalculatorCount> byCategory;

  const _HandHygieneCalculatorSession({
    required this.sessionLabel,
    required this.department,
    required this.ward,
    required this.byCategory,
  });

  _HandHygieneCalculatorCount get total => byCategory.values.fold(
    const _HandHygieneCalculatorCount(),
    (sum, item) => sum + item,
  );
}

class _HandHygieneCalculatorCount {
  final int opp;
  final int hw;
  final int hr;

  const _HandHygieneCalculatorCount({this.opp = 0, this.hw = 0, this.hr = 0});

  double get compliance => opp == 0 ? 0 : ((hw + hr) / opp) * 100;

  _HandHygieneCalculatorCount operator +(_HandHygieneCalculatorCount other) {
    return _HandHygieneCalculatorCount(
      opp: opp + other.opp,
      hw: hw + other.hw,
      hr: hr + other.hr,
    );
  }
}

class _ReportsListScreen extends StatefulWidget {
  final String title;
  final String collection;
  final String facilityId;
  final String? facilityName;
  final String? staffId;
  final String? staffName;
  final String? sourceField;
  final String? sourceValue;

  const _ReportsListScreen({
    required this.title,
    required this.collection,
    required this.facilityId,
    this.facilityName,
    this.staffId,
    this.staffName,
    this.sourceField,
    this.sourceValue,
  });

  @override
  State<_ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<_ReportsListScreen> {
  String _search = '';
  String _searchInput = '';
  String _searchField = 'formId';
  String _statusFilter = 'All';
  String _departmentFilter = 'All';
  String _wardFilter = 'All';
  String _selectedDataStatus = 'Raw Data';
  DateTime? _startDate;
  DateTime? _endDate;
  final Set<String> _selectedRecordIds = {};
  final List<_DownloadedReport> _downloads = [];
  bool _showAllRecords = false;
  static const _dataStatuses = [
    'Raw Data',
    'Approved',
    'Not Approved',
    'Rejected',
  ];

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection(widget.collection)
        .where('facilityId', isEqualTo: widget.facilityId);
    if (widget.sourceField != null && widget.sourceValue != null) {
      query = query.where(widget.sourceField!, isEqualTo: widget.sourceValue);
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allDocs =
              [...?snapshot.data?.docs]
                  .where(
                    (doc) => _isFinalSurveillanceSubmission(
                      doc.data() as Map<String, dynamic>,
                    ),
                  )
                  .toList()
                ..sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aDate = _recordDate(aData);
                  final bDate = _recordDate(bData);
                  return (bDate?.millisecondsSinceEpoch ?? 0).compareTo(
                    aDate?.millisecondsSinceEpoch ?? 0,
                  );
                });
          final docs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final haystack = _searchableValue(data).toLowerCase();
            final status = _statusOf(data).toLowerCase();
            final matchesSearch =
                _search.isEmpty || haystack.contains(_search.toLowerCase());
            final matchesStatus =
                _statusFilter == 'All' || status == _statusFilter.toLowerCase();
            final matchesDepartment =
                _departmentFilter == 'All' ||
                _departmentOf(data).toLowerCase() ==
                    _departmentFilter.toLowerCase();
            final matchesWard =
                _wardFilter == 'All' ||
                _unitOf(data).toLowerCase() == _wardFilter.toLowerCase();
            final matchesDate = _matchesDateRange(data);
            return matchesSearch &&
                matchesStatus &&
                matchesDepartment &&
                matchesWard &&
                matchesDate;
          }).toList();
          final visibleDocs = _showAllRecords ? docs : docs.take(5).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildReportToolbar(allDocs, docs),
              const SizedBox(height: 12),
              if (docs.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _search.isEmpty
                          ? 'No reports found'
                          : 'Data does not exist for this search',
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Select')),
                      DataColumn(label: Text('Form ID')),
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Department')),
                      DataColumn(label: Text('Unit/Ward')),
                      DataColumn(label: Text('Data status')),
                      DataColumn(label: Text('Submission')),
                      DataColumn(label: Text('Last editor ID')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: visibleDocs.map((doc) {
                      final docIndex = docs.indexWhere(
                        (item) => item.id == doc.id,
                      );
                      final data = doc.data() as Map<String, dynamic>;
                      final selected = _selectedRecordIds.contains(doc.id);
                      final dataStatus = '${data['dataStatus'] ?? 'Raw Data'}';
                      return DataRow(
                        selected: selected,
                        color: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return _dataStatusColor(
                              dataStatus,
                            ).withOpacity(0.22);
                          }
                          return _dataStatusColor(dataStatus).withOpacity(0.08);
                        }),
                        cells: [
                          DataCell(
                            Checkbox(
                              value: selected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedRecordIds.add(doc.id);
                                  } else {
                                    _selectedRecordIds.remove(doc.id);
                                  }
                                });
                              },
                            ),
                          ),
                          DataCell(Text('${data['formId'] ?? '-'}')),
                          DataCell(Text(_typeOf(data))),
                          DataCell(Text(_departmentOf(data))),
                          DataCell(Text(_unitOf(data))),
                          DataCell(
                            Chip(
                              label: Text(dataStatus),
                              backgroundColor: _dataStatusColor(
                                dataStatus,
                              ).withOpacity(0.15),
                            ),
                          ),
                          DataCell(Text(_statusOf(data))),
                          DataCell(Text('${data['lastUpdatedById'] ?? '-'}')),
                          DataCell(Text(_dateLabel(data))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'View',
                                  icon: const Icon(Icons.visibility_outlined),
                                  onPressed: () =>
                                      _viewRecord(context, docs, docIndex),
                                ),
                                IconButton(
                                  tooltip: 'Update',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () =>
                                      _openRecord(context, doc.id, data),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      _deleteRecord(context, doc.id),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              if (docs.length > 5)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _showAllRecords = !_showAllRecords),
                    icon: Icon(
                      _showAllRecords ? Icons.expand_less : Icons.expand_more,
                    ),
                    label: Text(
                      _showAllRecords
                          ? 'Show less'
                          : 'View more (${docs.length - 5})',
                    ),
                  ),
                ),
              if (_downloads.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Downloaded files',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ..._downloads.map(
                  (download) => ListTile(
                    dense: true,
                    leading: Icon(
                      download.name.toLowerCase().endsWith('.pdf')
                          ? Icons.picture_as_pdf_outlined
                          : download.name.toLowerCase().endsWith('.doc')
                          ? Icons.description_outlined
                          : Icons.table_chart_outlined,
                    ),
                    title: Text(download.name),
                    subtitle: Text(
                      '${download.recordCount} selected records • ${DateFormat('MMM d, y HH:mm').format(download.downloadedAt)}',
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Download again',
                          icon: const Icon(Icons.download_outlined),
                          onPressed: download.bytes == null
                              ? null
                              : () => Share.shareXFiles([
                                  XFile.fromData(
                                    download.bytes!,
                                    mimeType:
                                        download.mimeType ??
                                        'application/octet-stream',
                                    name: download.name,
                                  ),
                                ]),
                        ),
                        IconButton(
                          tooltip: 'Delete from list',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              setState(() => _downloads.remove(download)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportToolbar(
    List<QueryDocumentSnapshot> allDocs,
    List<QueryDocumentSnapshot> filteredDocs,
  ) {
    final selectedDocs = filteredDocs
        .where((doc) => _selectedRecordIds.contains(doc.id))
        .toList();
    final statuses = <String>{
      'All',
      ...allDocs.map((doc) => _statusOf(doc.data() as Map<String, dynamic>)),
    }.toList();
    final departments = _filterOptions(allDocs, _departmentOf);
    final wards = _filterOptions(allDocs, _unitOf);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            value: _searchField,
            decoration: const InputDecoration(
              labelText: 'Search by',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'formId', child: Text('Form ID')),
              DropdownMenuItem(value: 'sampleId', child: Text('Sample ID')),
              DropdownMenuItem(value: 'department', child: Text('Department')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _searchField = value);
            },
          ),
        ),
        SizedBox(
          width: 280,
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Enter search value',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _searchInput = value.trim(),
            onSubmitted: (_) => setState(() {
              _search = _searchInput;
              _showAllRecords = false;
            }),
          ),
        ),
        IconButton.filled(
          tooltip: 'Search',
          onPressed: () => setState(() {
            _search = _searchInput;
            _showAllRecords = false;
          }),
          icon: const Icon(Icons.search),
        ),
        if (_search.isNotEmpty)
          TextButton(
            onPressed: () => setState(() {
              _search = '';
              _searchInput = '';
              _showAllRecords = false;
            }),
            child: const Text('Clear'),
          ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            value: departments.contains(_departmentFilter)
                ? _departmentFilter
                : 'All',
            decoration: const InputDecoration(
              labelText: 'Department',
              border: OutlineInputBorder(),
            ),
            items: departments
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _departmentFilter = value;
                  _showAllRecords = false;
                });
              }
            },
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            value: wards.contains(_wardFilter) ? _wardFilter : 'All',
            decoration: const InputDecoration(
              labelText: 'Ward/Unit',
              border: OutlineInputBorder(),
            ),
            items: wards
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _wardFilter = value;
                  _showAllRecords = false;
                });
              }
            },
          ),
        ),
        OutlinedButton.icon(
          onPressed: _pickDateRange,
          icon: const Icon(Icons.date_range_outlined),
          label: Text(_dateRangeFilterLabel()),
        ),
        if (_startDate != null ||
            _endDate != null ||
            _departmentFilter != 'All' ||
            _wardFilter != 'All')
          TextButton(
            onPressed: () => setState(() {
              _startDate = null;
              _endDate = null;
              _departmentFilter = 'All';
              _wardFilter = 'All';
              _showAllRecords = false;
            }),
            child: const Text('Clear filters'),
          ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            value: statuses.contains(_statusFilter)
                ? _statusFilter
                : 'All',
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: statuses
                .map(
                  (status) =>
                      DropdownMenuItem(value: status, child: Text(status)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _statusFilter = value);
            },
          ),
        ),
        SizedBox(
          width: 210,
          child: DropdownButtonFormField<String>(
            value: _selectedDataStatus,
            decoration: const InputDecoration(
              labelText: 'Data status',
              border: OutlineInputBorder(),
            ),
            items: _dataStatuses
                .map(
                  (status) =>
                      DropdownMenuItem(value: status, child: Text(status)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedDataStatus = value);
            },
          ),
        ),
        OutlinedButton.icon(
          onPressed: _selectedRecordIds.isEmpty
              ? null
              : _updateSelectedDataStatus,
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Apply status'),
        ),
        OutlinedButton.icon(
          onPressed: filteredDocs.isEmpty
              ? null
              : () {
                  final filteredIds = filteredDocs.map((doc) => doc.id).toSet();
                  setState(() {
                    if (filteredIds.every(_selectedRecordIds.contains)) {
                      _selectedRecordIds.removeAll(filteredIds);
                    } else {
                      _selectedRecordIds.addAll(filteredIds);
                    }
                  });
                },
          icon: const Icon(Icons.checklist),
          label: Text(
            filteredDocs.every((doc) => _selectedRecordIds.contains(doc.id))
                ? 'Clear selection'
                : 'Select all',
          ),
        ),
        if (widget.collection == 'ipc_assessments')
          OutlinedButton.icon(
            onPressed: selectedDocs.isEmpty
                ? null
                : () => _openIpcAssessmentReportDialog(selectedDocs),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Generate report'),
          )
        else
          OutlinedButton.icon(
            onPressed: selectedDocs.isEmpty
                ? null
                : widget.collection == 'environmental_inspections'
                ? () => _openDownloadReportDialog(selectedDocs)
                : () => _exportCsv(selectedDocs),
            icon: Icon(
              widget.collection == 'environmental_inspections'
                  ? Icons.download_outlined
                  : Icons.table_chart_outlined,
            ),
            label: Text(
              widget.collection == 'environmental_inspections'
                  ? 'Download report'
                  : 'Download Excel',
            ),
          ),
        OutlinedButton.icon(
          onPressed: selectedDocs.isEmpty
              ? null
              : () => _showReportView(context, selectedDocs),
          icon: const Icon(Icons.bar_chart),
          label: const Text('View report'),
        ),
      ],
    );
  }

  void _openRecord(
    BuildContext context,
    String documentId,
    Map<String, dynamic> data,
  ) {
    if (widget.collection == 'environmental_inspections' &&
        widget.facilityName != null &&
        widget.staffId != null &&
        widget.staffName != null) {
      final inspectionType =
          '${data['inspectionType'] ?? 'General Environmental Health'}';
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => EnvironmentalInspectionForm(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName!,
          staffId: widget.staffId!,
          staffName: widget.staffName!,
          dashboardSource: widget.sourceValue ?? 'ipc',
          initialInspectionType: inspectionType,
          documentId: documentId,
          initialData: data,
          allowFinalEdit: true,
        ),
      );
    } else if (widget.collection == 'ward_denominators' &&
        widget.facilityName != null &&
        widget.staffId != null &&
        widget.staffName != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _WardDenominatorFormScreen(
            facilityId: widget.facilityId,
            facilityName: widget.facilityName!,
            staffId: widget.staffId!,
            staffName: widget.staffName!,
            documentId: documentId,
            initialData: data,
            allowFinalEdit: true,
          ),
        ),
      );
    } else if (widget.collection == 'hand_hygiene_observations' &&
        widget.facilityName != null &&
        widget.staffId != null &&
        widget.staffName != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _HandHygieneObservationFormScreen(
            facilityId: widget.facilityId,
            facilityName: widget.facilityName!,
            staffId: widget.staffId!,
            staffName: widget.staffName!,
            documentId: documentId,
            initialData: data,
            allowFinalEdit: true,
          ),
        ),
      );
    } else if (widget.collection == 'outbreak_investigations' &&
        widget.facilityName != null &&
        widget.staffId != null &&
        widget.staffName != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _OutbreakReportFormScreen(
            facilityId: widget.facilityId,
            facilityName: widget.facilityName!,
            staffId: widget.staffId!,
            staffName: widget.staffName!,
            documentId: documentId,
            initialData: data,
          ),
        ),
      );
    } else if (widget.collection == 'ipc_assessments' &&
        widget.facilityName != null &&
        widget.staffId != null &&
        widget.staffName != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _IpcAssessmentToolFormScreen(
            facilityId: widget.facilityId,
            facilityName: widget.facilityName!,
            staffId: widget.staffId!,
            staffName: widget.staffName!,
            toolType:
                '${data['assessmentTool'] ?? data['assessmentType'] ?? 'WHO IPCAF Tool'}',
            documentId: documentId,
            initialData: data,
            allowFinalEdit: true,
          ),
        ),
      );
    } else {
      _viewSingleRecord(context, documentId, data);
    }
  }

  Future<void> _deleteRecord(BuildContext context, String documentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete record'),
        content: const Text('Delete this surveillance record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseFirestore.instance
        .collection(widget.collection)
        .doc(documentId)
        .delete();
  }

  void _viewSingleRecord(
    BuildContext context,
    String documentId,
    Map<String, dynamic> data,
  ) {
    _showRecordDialog(
      context: context,
      documentId: documentId,
      data: data,
      title: '${data['formId'] ?? _typeOf(data)}',
      positionLabel: null,
      onPrevious: null,
      onNext: null,
      onEdit: () {
        Navigator.pop(context);
        _openRecord(context, documentId, data);
      },
    );
  }

  void _viewRecord(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
    int initialIndex,
  ) {
    if (docs.isEmpty) return;
    final safeInitialIndex = initialIndex < 0 ? 0 : initialIndex;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var currentIndex = safeInitialIndex.clamp(0, docs.length - 1);
        var statusOverride = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final doc = docs[currentIndex];
            final data = Map<String, dynamic>.from(
              doc.data() as Map<String, dynamic>,
            );
            if (statusOverride.isNotEmpty) {
              data['dataStatus'] = statusOverride;
            }
            return _recordDialogContent(
              dialogContext: dialogContext,
              documentId: doc.id,
              data: data,
              title: '${data['formId'] ?? _typeOf(data)}',
              positionLabel: '${currentIndex + 1} of ${docs.length}',
              onPrevious: currentIndex == 0
                  ? null
                  : () => setDialogState(() {
                      currentIndex -= 1;
                      statusOverride = '';
                    }),
              onNext: currentIndex >= docs.length - 1
                  ? null
                  : () => setDialogState(() {
                      currentIndex += 1;
                      statusOverride = '';
                    }),
              onEdit: () {
                Navigator.pop(dialogContext);
                _openRecord(context, doc.id, data);
              },
              onStatusChanged: (value) async {
                await _updateRecordDataStatus(doc.id, value);
                setDialogState(() => statusOverride = value);
              },
            );
          },
        );
      },
    );
  }

  void _showRecordDialog({
    required BuildContext context,
    required String documentId,
    required Map<String, dynamic> data,
    required String title,
    required String? positionLabel,
    required VoidCallback? onPrevious,
    required VoidCallback? onNext,
    required VoidCallback? onEdit,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _recordDialogContent(
        dialogContext: dialogContext,
        documentId: documentId,
        data: data,
        title: title,
        positionLabel: positionLabel,
        onPrevious: onPrevious,
        onNext: onNext,
        onEdit: onEdit,
        onStatusChanged: (value) => _updateRecordDataStatus(documentId, value),
      ),
    );
  }

  AlertDialog _recordDialogContent({
    required BuildContext dialogContext,
    required String documentId,
    required Map<String, dynamic> data,
    required String title,
    required String? positionLabel,
    required VoidCallback? onPrevious,
    required VoidCallback? onNext,
    required VoidCallback? onEdit,
    required Future<void> Function(String value) onStatusChanged,
  }) {
    final fields = _fullDisplayFields(data);
    final currentStatus = _dataStatuses.contains(data['dataStatus'])
        ? '${data['dataStatus']}'
        : 'Raw Data';
    return AlertDialog(
      title: Text(positionLabel == null ? title : '$title ($positionLabel)'),
      content: SizedBox(
        width: 700,
        child: ListView(
          shrinkWrap: true,
          children: [
            DropdownButtonFormField<String>(
              value: currentStatus,
              decoration: const InputDecoration(
                labelText: 'Data status',
                border: OutlineInputBorder(),
              ),
              items: _dataStatuses
                  .map(
                    (status) =>
                        DropdownMenuItem(value: status, child: Text(status)),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                await onStatusChanged(value);
              },
            ),
            const SizedBox(height: 12),
            ...fields.entries.map(
              (entry) => ListTile(
                dense: true,
                title: Text(entry.key),
                subtitle: Text(_formatValue(entry.value)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Previous'),
        ),
        TextButton.icon(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Next'),
        ),
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _updateRecordDataStatus(
    String documentId,
    String dataStatus,
  ) async {
    await FirebaseFirestore.instance
        .collection(widget.collection)
        .doc(documentId)
        .update({
          'dataStatus': dataStatus,
          'dataStatusUpdatedAt': FieldValue.serverTimestamp(),
          'dataStatusUpdatedById': widget.staffId,
          'dataStatusUpdatedBy': widget.staffName,
          'lastUpdatedById': widget.staffId,
          'lastUpdatedBy': widget.staffName,
          'updatedAt': FieldValue.serverTimestamp(),
          'changeHistory': FieldValue.arrayUnion([
            {
              'staffId': widget.staffId,
              'staffName': widget.staffName,
              'action':
                  'data_status_${dataStatus.toLowerCase().replaceAll(' ', '_')}',
              'at': Timestamp.now(),
            },
          ]),
        });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data status changed to $dataStatus')),
    );
  }

  List<String> _filterOptions(
    List<QueryDocumentSnapshot> docs,
    String Function(Map<String, dynamic> data) selector,
  ) {
    final values =
        docs
            .map((doc) => selector(doc.data() as Map<String, dynamic>))
            .where((value) => value.trim().isNotEmpty && value != '-')
            .toSet()
            .toList()
          ..sort();
    return ['All', ...values];
  }

  DateTime? _recordDate(Map<String, dynamic> data) {
    final value =
        data['reportedDate'] ??
        data['inspectionDate'] ??
        data['observationDate'] ??
        data['assessmentDate'] ??
        data['updatedAt'] ??
        data['createdAt'] ??
        data['finalizedAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse('$value');
  }

  bool _matchesDateRange(Map<String, dynamic> data) {
    if (_startDate == null && _endDate == null) return true;
    final date = _recordDate(data);
    if (date == null) return false;
    if (_startDate != null && date.isBefore(_startOfDay(_startDate!))) {
      return false;
    }
    if (_endDate != null && date.isAfter(_endOfDay(_endDate!))) {
      return false;
    }
    return true;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _startDate == null && _endDate == null
          ? null
          : DateTimeRange(
              start: _startDate ?? _endDate!,
              end: _endDate ?? _startDate!,
            ),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
      _showAllRecords = false;
    });
  }

  String _dateRangeFilterLabel() {
    if (_startDate == null && _endDate == null) return 'Date range';
    final formatter = DateFormat('dd/MM/yyyy');
    final start = _startDate == null ? 'Start' : formatter.format(_startDate!);
    final end = _endDate == null ? 'End' : formatter.format(_endDate!);
    return '$start - $end';
  }

  Future<void> _exportCsv(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;
    final headers = _fullExportHeaders(docs);
    final csv = StringBuffer()..writeln(headers.join(','));
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final row = _fullExportRow(data, headers);
      csv.writeln(headers.map((header) => _csvCell(row[header])).join(','));
    }
    final fileName =
        '${_fileSlug(widget.title)}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    final bytes = Uint8List.fromList(utf8.encode(csv.toString()));
    await Share.shareXFiles([
      XFile.fromData(bytes, mimeType: 'text/csv', name: fileName),
    ]);
    setState(() {
      _downloads.insert(
        0,
        _DownloadedReport(
          name: fileName,
          downloadedAt: DateTime.now(),
          recordCount: docs.length,
          bytes: bytes,
          mimeType: 'text/csv',
        ),
      );
    });
  }

  Future<void> _exportExcel(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;
    final headers = _fullExportHeaders(docs);
    final html = StringBuffer()
      ..writeln('<html><head><meta charset="utf-8"></head><body>')
      ..writeln('<table border="1" cellspacing="0" cellpadding="4">')
      ..writeln(
        '<tr>${headers.map((header) => '<th>${_htmlEscape(header)}</th>').join()}</tr>',
      );
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final row = _fullExportRow(data, headers);
      html.writeln(
        '<tr>${headers.map((header) => '<td>${_htmlEscape('${row[header] ?? ''}')}</td>').join()}</tr>',
      );
    }
    html.writeln('</table></body></html>');
    final fileName =
        '${_fileSlug(widget.title)}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xls';
    final bytes = Uint8List.fromList(utf8.encode(html.toString()));
    await Share.shareXFiles([
      XFile.fromData(
        bytes,
        mimeType: 'application/vnd.ms-excel',
        name: fileName,
      ),
    ]);
    setState(() {
      _downloads.insert(
        0,
        _DownloadedReport(
          name: fileName,
          downloadedAt: DateTime.now(),
          recordCount: docs.length,
          bytes: bytes,
          mimeType: 'application/vnd.ms-excel',
        ),
      );
    });
  }

  Future<void> _openDownloadReportDialog(
    List<QueryDocumentSnapshot> docs,
  ) async {
    final selectedFormat = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download report'),
        content: const Text('Choose the report format to download.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'excel'),
            child: const Text('Excel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'csv'),
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'pdf'),
            child: const Text('PDF'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'word'),
            child: const Text('Word doc'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selectedFormat == null) return;
    final rows = docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    if (selectedFormat == 'excel') {
      await _exportExcel(docs);
    } else if (selectedFormat == 'csv') {
      await _exportCsv(docs);
    } else if (selectedFormat == 'pdf') {
      await _downloadReportPdf(rows);
    } else {
      await _downloadReportDoc(rows);
    }
  }

  Future<void> _showReportView(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
  ) async {
    if (widget.collection == 'ipc_assessments') {
      await _openIpcAssessmentReportDialog(docs);
      return;
    }
    final rows = docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    final byType = _counts(rows, _typeOf);
    final byDepartment = _counts(rows, _departmentOf);
    final byStatus = _counts(rows, _statusOf);
    final byDataStatus = _counts(
      rows,
      (row) => '${row['dataStatus'] ?? 'Raw Data'}',
    );
    final byWaterSource = _counts(
      rows.where((row) => row['inspectionType'] == 'Water Quality').toList(),
      (row) =>
          '${row['waterSource'] ?? _waterData(row)['Water_Source'] ?? 'Unknown'}',
    );
    final byOverallStatus = _counts(
      rows.where((row) => row['inspectionType'] == 'Water Quality').toList(),
      (row) =>
          '${row['overallStatus'] ?? _waterData(row)['Overall_Status'] ?? 'Unknown'}',
    );
    final localInterpretation = _localSurveillanceInterpretation(
      rows: rows,
      byType: byType,
      byDepartment: byDepartment,
      byStatus: byStatus,
      byDataStatus: byDataStatus,
      byWaterSource: byWaterSource,
      byOverallStatus: byOverallStatus,
    );
    final isEnvironmental = widget.collection == 'environmental_inspections';
    final aiInterpretation = _generateSurveillanceAiInterpretation(
      rows: rows,
      byType: byType,
      byDepartment: byDepartment,
      byStatus: byStatus,
      byDataStatus: byDataStatus,
      byWaterSource: byWaterSource,
      byOverallStatus: byOverallStatus,
    );
    final showGeneratedReportAction =
        widget.collection == 'hand_hygiene_observations' ||
        widget.collection == 'outbreak_investigations' ||
        widget.collection == 'environmental_inspections' ||
        widget.collection == 'ward_denominators';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${widget.title} Report'),
        content: SizedBox(
          width: 640,
          child: ListView(
            shrinkWrap: true,
            children: [
              Wrap(
                spacing: 12,
                children: [
                  _summaryCard('Records', '${rows.length}', Colors.blue),
                  _summaryCard('Types', '${byType.length}', Colors.green),
                  _summaryCard(
                    'Departments',
                    '${byDepartment.length}',
                    Colors.teal,
                  ),
                  _summaryCard(
                    'Data status',
                    '${byDataStatus.length}',
                    Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _barSummary('By type', byType),
              const SizedBox(height: 16),
              _barSummary('By department', byDepartment),
              const SizedBox(height: 16),
              _barSummary('By submission status', byStatus),
              const SizedBox(height: 16),
              _barSummary('By data status', byDataStatus),
              if (byWaterSource.isNotEmpty) ...[
                const SizedBox(height: 16),
                _barSummary('Water source distribution', byWaterSource),
              ],
              if (byOverallStatus.isNotEmpty) ...[
                const SizedBox(height: 16),
                _barSummary('Water quality status', byOverallStatus),
              ],
              const SizedBox(height: 16),
              if (!isEnvironmental)
                _surveillanceInterpretationCard(
                  title: 'Surveillance interpretation',
                  body: localInterpretation,
                  icon: Icons.insights_outlined,
                ),
              if (!isEnvironmental) const SizedBox(height: 8),
              FutureBuilder<String>(
                future: aiInterpretation,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      leading: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      title: Text('Generating AI interpretation...'),
                    );
                  }
                  final body = snapshot.data?.trim().isNotEmpty == true
                      ? snapshot.data!.trim()
                      : (isEnvironmental ? localInterpretation : '');
                  if (body.trim().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return _surveillanceInterpretationCard(
                    title: isEnvironmental
                        ? 'IPC interpretation'
                        : 'AI interpretation',
                    body: body,
                    icon: Icons.auto_awesome,
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          if (showGeneratedReportAction)
            TextButton(
              onPressed: () {
                if (widget.collection == 'hand_hygiene_observations') {
                  Navigator.pop(dialogContext);
                  Future.microtask(
                    () => _showHandHygieneComplianceCalculator(docs),
                  );
                } else {
                  _downloadReportPdf(rows);
                }
              },
              child: const Text('Generate report'),
            )
          else
            TextButton(
              onPressed: () => _downloadReportPdf(rows),
              child: const Text('Download PDF'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openIpcAssessmentReportDialog(
    List<QueryDocumentSnapshot> docs,
  ) async {
    if (docs.isEmpty) return;
    final rows = docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    final tools = rows.map(_assessmentToolOf).toSet().toList()..sort();
    var selectedTool = tools.first;
    var outputFormat = 'PDF';
    final improvementController = TextEditingController();
    final recommendationController = TextEditingController();
    final remarksController = TextEditingController();
    var suggestionsStarted = false;

    Future<_IpcAssessmentGeneratedReport> buildReport() async {
      final selectedRows = rows
          .where((row) => _assessmentToolOf(row) == selectedTool)
          .toList();
      final report = _buildIpcAssessmentGeneratedReport(
        selectedRows,
        improvementController.text,
        recommendationController.text,
        remarksController.text,
      );
      return report.copyWith(logoUrl: await _facilityLogoUrl());
    }

    Future<void> loadSuggestions(StateSetter setDialogState) async {
      if (suggestionsStarted) return;
      suggestionsStarted = true;
      final report = _buildIpcAssessmentGeneratedReport(
        rows.where((row) => _assessmentToolOf(row) == selectedTool).toList(),
        '',
        '',
        '',
      );
      final suggestion = await _generateIpcAssessmentReportSuggestions(report);
      if (!context.mounted) return;
      setDialogState(() {
        improvementController.text = suggestion.improvementAreas.join('\n');
        recommendationController.text = suggestion.recommendations.join('\n');
        remarksController.text = suggestion.remarks;
      });
    }

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!suggestionsStarted) {
            Future.microtask(() => loadSuggestions(setDialogState));
          }
          final selectedRows = rows
              .where((row) => _assessmentToolOf(row) == selectedTool)
              .toList();
          final report = _buildIpcAssessmentGeneratedReport(
            selectedRows,
            improvementController.text,
            recommendationController.text,
            remarksController.text,
          );
          return AlertDialog(
            title: Text(report.title),
            content: SizedBox(
              width: 860,
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (tools.length > 1)
                    DropdownButtonFormField<String>(
                      value: selectedTool,
                      decoration: const InputDecoration(
                        labelText: 'Assessment tool',
                        border: OutlineInputBorder(),
                      ),
                      items: tools
                          .map(
                            (tool) => DropdownMenuItem(
                              value: tool,
                              child: Text(tool),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedTool = value;
                          suggestionsStarted = false;
                          improvementController.clear();
                          recommendationController.clear();
                          remarksController.clear();
                        });
                      },
                    ),
                  if (tools.length > 1) const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _summaryCard(
                        'Selected records',
                        '${report.recordCount}',
                        Colors.blue,
                      ),
                      _summaryCard(
                        'Total score',
                        '${_scoreText(report.totalScore)} / ${_scoreText(report.maxScore)}',
                        Colors.green,
                      ),
                      _summaryCard('IPC level', report.level, Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Component')),
                        DataColumn(label: Text('Score')),
                        DataColumn(label: Text('Maximum')),
                        DataColumn(label: Text('Percent')),
                      ],
                      rows: report.sections
                          .map(
                            (section) => DataRow(
                              cells: [
                                DataCell(Text(section.label)),
                                DataCell(Text(_scoreText(section.score))),
                                DataCell(Text(_scoreText(section.maxScore))),
                                DataCell(
                                  Text(
                                    '${section.percentage.toStringAsFixed(1)}%',
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _surveillanceInterpretationCard(
                    title: 'Report summary',
                    body: report.summary,
                    icon: Icons.insights_outlined,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: improvementController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Areas requiring improvement',
                      helperText:
                          'AI suggestions are editable. Use one point per line.',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: recommendationController,
                    minLines: 3,
                    maxLines: 7,
                    decoration: const InputDecoration(
                      labelText: 'Recommendations',
                      helperText:
                          'AI suggestions are editable. Use one point per line.',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Short remarks',
                      helperText: 'AI suggestion is editable.',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          value: outputFormat,
                          decoration: const InputDecoration(
                            labelText: 'Export format',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                            DropdownMenuItem(
                              value: 'Word doc',
                              child: Text('Word doc'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => outputFormat = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            suggestionsStarted = false;
                            improvementController.clear();
                            recommendationController.clear();
                            remarksController.clear();
                          });
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Regenerate AI support'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final generated = await buildReport();
                  if (outputFormat == 'Word doc') {
                    await _shareIpcAssessmentReportDoc(generated);
                  } else {
                    await _shareIpcAssessmentReportPdf(generated);
                  }
                },
                icon: const Icon(Icons.download_outlined),
                label: const Text('Generate report'),
              ),
            ],
          );
        },
      ),
    );

    improvementController.dispose();
    recommendationController.dispose();
    remarksController.dispose();
  }

  _IpcAssessmentGeneratedReport _buildIpcAssessmentGeneratedReport(
    List<Map<String, dynamic>> rows,
    String improvementText,
    String recommendationText,
    String remarksText,
  ) {
    final first = rows.isNotEmpty ? rows.first : const <String, dynamic>{};
    final tool = _assessmentToolOf(first);
    final maxScore = _assessmentMaxScoreForTool(tool);
    final totalScore = rows.isEmpty
        ? 0.0
        : rows
                  .map((row) => _asDouble(row['totalScore']))
                  .fold<double>(0, (total, score) => total + score) /
              rows.length;
    final sections = _aggregateAssessmentSections(rows);
    final level = _assessmentLevelForScore(tool, totalScore);
    final gaps = sections.where((section) => section.percentage < 60).toList()
      ..sort((a, b) => a.percentage.compareTo(b.percentage));
    final defaultAreas = gaps.isEmpty
        ? ['Sustain current IPC performance and continue routine monitoring.']
        : gaps
              .take(6)
              .map(
                (section) =>
                    '${section.label}: ${section.percentage.toStringAsFixed(1)}% score suggests focused improvement is needed.',
              )
              .toList();
    final defaultRecommendations = gaps.isEmpty
        ? [
            'Maintain periodic reassessment, staff feedback, and documentation of IPC improvement activities.',
          ]
        : gaps
              .take(6)
              .map(
                (section) =>
                    'Develop a short action plan for ${section.label}, assign responsible staff, define timelines, and recheck progress at the next IPC meeting.',
              )
              .toList();
    final assessmentDates =
        rows
            .map((row) => row['assessmentDate'])
            .whereType<Timestamp>()
            .map((timestamp) => timestamp.toDate())
            .toList()
          ..sort();
    final assessorNames = rows
        .map((row) => '${row['assessorName'] ?? row['createdBy'] ?? ''}'.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    return _IpcAssessmentGeneratedReport(
      title: _assessmentReportTitle(tool),
      tool: tool,
      facilityName: widget.facilityName ?? '${first['facilityName'] ?? ''}',
      reportDate: DateTime.now(),
      assessmentDate: assessmentDates.isEmpty ? null : assessmentDates.last,
      assessorName: assessorNames.isEmpty ? '-' : assessorNames.join(', '),
      recordCount: rows.length,
      totalScore: totalScore,
      maxScore: maxScore,
      level: level,
      sections: sections,
      improvementAreas: _linesOrDefault(improvementText, defaultAreas),
      recommendations: _linesOrDefault(
        recommendationText,
        defaultRecommendations,
      ),
      remarks: remarksText.trim().isEmpty
          ? _defaultAssessmentRemarks(tool, totalScore, maxScore, level, gaps)
          : remarksText.trim(),
      logoUrl: null,
    );
  }

  List<_IpcAssessmentReportSection> _aggregateAssessmentSections(
    List<Map<String, dynamic>> rows,
  ) {
    final labels = <String, String>{};
    final scoreTotals = <String, double>{};
    final maxTotals = <String, double>{};
    final counts = <String, int>{};
    for (final row in rows) {
      final sections = row['assessmentSections'] is Map
          ? Map<String, dynamic>.from(row['assessmentSections'] as Map)
          : const <String, dynamic>{};
      for (final entry in sections.entries) {
        final section = entry.value is Map
            ? Map<String, dynamic>.from(entry.value as Map)
            : const <String, dynamic>{};
        labels[entry.key] = '${section['label'] ?? entry.key}';
        scoreTotals[entry.key] =
            (scoreTotals[entry.key] ?? 0) + _asDouble(section['score']);
        maxTotals[entry.key] =
            (maxTotals[entry.key] ?? 0) + _asDouble(section['maxScore']);
        counts[entry.key] = (counts[entry.key] ?? 0) + 1;
      }
    }
    final sections = labels.keys.map((key) {
      final count = counts[key] ?? 1;
      final score = (scoreTotals[key] ?? 0) / count;
      final maxScore = (maxTotals[key] ?? 0) / count;
      return _IpcAssessmentReportSection(
        label: labels[key] ?? key,
        score: score,
        maxScore: maxScore,
      );
    }).toList();
    return sections;
  }

  Future<_IpcAssessmentReportSuggestion>
  _generateIpcAssessmentReportSuggestions(
    _IpcAssessmentGeneratedReport report,
  ) async {
    final local = _localIpcAssessmentSuggestions(report);
    try {
      await GeminiService.initialize();
      final gemini = GeminiService.instance;
      if (!gemini.isConfigured) return local;
      final response = await gemini.getChatResponse(
        userRole: 'doctor',
        specialization: 'infection prevention and control assessment',
        userMessage:
            'Create editable IPC assessment report support for ${report.tool}. '
            'Use brief, simple, clear plain text only. Do not use markdown characters such as #, *, or tables. '
            'Return three short sections exactly named Areas, Recommendations, Remarks. '
            'Base the gaps and recommendations on these component scores: ${report.sections.map((section) => '${section.label} ${section.score}/${section.maxScore}').join('; ')}. '
            'Total score: ${report.totalScore}/${report.maxScore}. IPC level: ${report.level}.',
      );
      final cleaned = _cleanIpcAiText(response);
      final parsed = _parseAssessmentSuggestion(cleaned);
      return parsed.isEmpty ? local : parsed;
    } catch (_) {
      return local;
    }
  }

  _IpcAssessmentReportSuggestion _localIpcAssessmentSuggestions(
    _IpcAssessmentGeneratedReport report,
  ) {
    final gaps =
        report.sections.where((section) => section.percentage < 60).toList()
          ..sort((a, b) => a.percentage.compareTo(b.percentage));
    final areas = gaps.isEmpty
        ? ['No major low-scoring component was identified in the selected data.']
        : gaps
              .take(6)
              .map(
                (section) =>
                    '${section.label} requires improvement; current score is ${_scoreText(section.score)} of ${_scoreText(section.maxScore)}.',
              )
              .toList();
    final recommendations = gaps.isEmpty
        ? [
            'Maintain routine IPC assessment, document progress, and continue feedback to facility leadership.',
          ]
        : gaps
              .take(6)
              .map(
                (section) =>
                    'Prioritize ${section.label} with assigned owners, timelines, resources, and follow-up review by the IPC committee.',
              )
              .toList();
    return _IpcAssessmentReportSuggestion(
      improvementAreas: areas,
      recommendations: recommendations,
      remarks: _defaultAssessmentRemarks(
        report.tool,
        report.totalScore,
        report.maxScore,
        report.level,
        gaps,
      ),
    );
  }

  _IpcAssessmentReportSuggestion _parseAssessmentSuggestion(String text) {
    final areas = <String>[];
    final recommendations = <String>[];
    final remarks = <String>[];
    var target = areas;
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final lower = line.toLowerCase();
      if (lower.startsWith('areas')) {
        target = areas;
        continue;
      }
      if (lower.startsWith('recommendations')) {
        target = recommendations;
        continue;
      }
      if (lower.startsWith('remarks')) {
        target = remarks;
        continue;
      }
      target.add(line.replaceFirst(RegExp(r'^[0-9]+[.)]\s*'), ''));
    }
    return _IpcAssessmentReportSuggestion(
      improvementAreas: areas,
      recommendations: recommendations,
      remarks: remarks.join(' '),
    );
  }

  Future<String?> _facilityLogoUrl() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(widget.facilityId)
          .get();
      final data = snapshot.data();
      if (data == null) return null;
      return (data['logoUrl'] ?? data['logo_url'] ?? data['facilityLogo'])
          ?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareIpcAssessmentReportPdf(
    _IpcAssessmentGeneratedReport report,
  ) async {
    final doc = pw.Document();
    pw.ImageProvider? logo;
    if (report.logoUrl != null && report.logoUrl!.trim().isNotEmpty) {
      try {
        logo = await networkImage(report.logoUrl!);
      } catch (_) {
        logo = null;
      }
    }
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          _pdfIpcAssessmentHeader(report, logo),
          pw.SizedBox(height: 14),
          pw.Text('Date: ${DateFormat('MMM d, y').format(report.reportDate)}'),
          pw.Text('Assessor: ${report.assessorName}'),
          if (report.assessmentDate != null)
            pw.Text(
              'Assessment date: ${DateFormat('MMM d, y').format(report.assessmentDate!)}',
            ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(report.summary),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Component', 'Score', 'Maximum', 'Percent'],
            data: report.sections
                .map(
                  (section) => [
                    section.label,
                    _scoreText(section.score),
                    _scoreText(section.maxScore),
                    '${section.percentage.toStringAsFixed(1)}%',
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Total score: ${_scoreText(report.totalScore)} / ${_scoreText(report.maxScore)}',
          ),
          pw.Text('IPC level: ${report.level}'),
          pw.SizedBox(height: 12),
          _pdfBulletSection(
            'Areas requiring improvement',
            report.improvementAreas,
          ),
          pw.SizedBox(height: 10),
          _pdfBulletSection('Recommendations', report.recommendations),
          pw.SizedBox(height: 10),
          pw.Text(
            'Remarks',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(report.remarks),
          pw.SizedBox(height: 42),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _pdfSignatureField('IPC Doctor'),
              _pdfSignatureField('IPC Manager'),
            ],
          ),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename:
          'ipc_assessment_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  Future<void> _shareIpcAssessmentReportDoc(
    _IpcAssessmentGeneratedReport report,
  ) async {
    final html = StringBuffer()
      ..writeln('<html><body>')
      ..writeln('<h1>${_htmlEscape(report.facilityName)}</h1>')
      ..writeln('<h2>Infection prevention & Control Committee</h2>')
      ..writeln('<h2>${_htmlEscape(report.title)}</h2>')
      ..writeln(
        '<p><strong>Date:</strong> ${DateFormat('MMM d, y').format(report.reportDate)}<br>'
        '<strong>Assessor:</strong> ${_htmlEscape(report.assessorName)}<br>'
        '<strong>Total score:</strong> ${_scoreText(report.totalScore)} / ${_scoreText(report.maxScore)}<br>'
        '<strong>IPC level:</strong> ${_htmlEscape(report.level)}</p>',
      )
      ..writeln('<h3>Summary</h3>')
      ..writeln('<p>${_htmlEscape(report.summary)}</p>')
      ..writeln(
        _htmlSimpleTable(
          'Component scores',
          ['Component', 'Score', 'Maximum', 'Percent'],
          report.sections
              .map(
                (section) => [
                  section.label,
                  _scoreText(section.score),
                  _scoreText(section.maxScore),
                  '${section.percentage.toStringAsFixed(1)}%',
                ],
              )
              .toList(),
        ),
      )
      ..writeln(
        _htmlBulletSection(
          'Areas requiring improvement',
          report.improvementAreas,
        ),
      )
      ..writeln(_htmlBulletSection('Recommendations', report.recommendations))
      ..writeln('<h3>Remarks</h3>')
      ..writeln('<p>${_htmlEscape(report.remarks)}</p>')
      ..writeln('''
        <table style="width:100%; margin-top:48px; border-collapse:collapse;">
          <tr>
            <td style="width:40%; border-top:1px solid #000; text-align:center; padding-top:8px;">IPC Doctor</td>
            <td style="width:20%;"></td>
            <td style="width:40%; border-top:1px solid #000; text-align:center; padding-top:8px;">IPC Manager</td>
          </tr>
        </table>
      ''')
      ..writeln('</body></html>');
    await Share.shareXFiles([
      XFile.fromData(
        Uint8List.fromList(utf8.encode(html.toString())),
        mimeType: 'application/msword',
        name:
            'ipc_assessment_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.doc',
      ),
    ]);
  }

  pw.Widget _pdfIpcAssessmentHeader(
    _IpcAssessmentGeneratedReport report,
    pw.ImageProvider? logo,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logo != null) pw.Image(logo, width: 56, height: 56),
        if (logo != null) pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                report.facilityName,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('Infection prevention & Control Committee'),
              pw.Text(report.title),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfBulletSection(String title, List<String> points) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        ...points.map((point) => pw.Text('- $point')),
      ],
    );
  }

  pw.Widget _pdfSignatureField(String label) {
    return pw.SizedBox(
      width: 180,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(height: 1, color: PdfColors.black),
          pw.SizedBox(height: 6),
          pw.Text(label),
        ],
      ),
    );
  }

  String _htmlSimpleTable(
    String title,
    List<String> headers,
    List<List<Object>> rows,
  ) {
    final buffer = StringBuffer()
      ..writeln('<h3>${_htmlEscape(title)}</h3>')
      ..writeln('<table border="1" cellspacing="0" cellpadding="4">')
      ..writeln(
        '<tr>${headers.map((header) => '<th>${_htmlEscape(header)}</th>').join()}</tr>',
      );
    for (final row in rows) {
      buffer.writeln(
        '<tr>${row.map((cell) => '<td>${_htmlEscape('$cell')}</td>').join()}</tr>',
      );
    }
    buffer.writeln('</table>');
    return buffer.toString();
  }

  String _htmlBulletSection(String title, List<String> points) {
    return '<h3>${_htmlEscape(title)}</h3><ul>${points.map((point) => '<li>${_htmlEscape(point)}</li>').join()}</ul>';
  }

  String _htmlEscape(String value) => const HtmlEscape().convert(value);

  String _assessmentToolOf(Map<String, dynamic> data) =>
      '${data['assessmentTool'] ?? data['assessmentType'] ?? 'WHO IPCAF Tool'}';

  String _assessmentReportTitle(String tool) {
    final lower = tool.toLowerCase();
    if (lower.contains('hhsaf')) {
      return 'Hand Hygiene Self-Assessment Framework Report';
    }
    if (lower.contains('wash')) return 'WASH FIT Assessment Report';
    return 'IPC Assessment Framework Report';
  }

  double _assessmentMaxScoreForTool(String tool) {
    final lower = tool.toLowerCase();
    if (lower.contains('hhsaf')) return 500;
    if (lower.contains('wash')) return 14;
    return 800;
  }

  String _assessmentLevelForScore(String tool, double score) {
    final lower = tool.toLowerCase();
    if (lower.contains('hhsaf')) {
      if (score >= 376) return 'Advanced';
      if (score >= 251) return 'Intermediate';
      if (score >= 126) return 'Basic';
      return 'Inadequate';
    }
    if (lower.contains('wash')) {
      final percent = _assessmentMaxScoreForTool(tool) == 0
          ? 0
          : (score / _assessmentMaxScoreForTool(tool)) * 100;
      if (percent >= 75) return 'Low risk / good progress';
      if (percent >= 50) return 'Medium risk / improvement required';
      return 'High risk / urgent improvement required';
    }
    if (score >= 601) return 'Advanced';
    if (score >= 401) return 'Intermediate';
    if (score >= 201) return 'Basic';
    return 'Inadequate';
  }

  String _defaultAssessmentRemarks(
    String tool,
    double score,
    double maxScore,
    String level,
    List<_IpcAssessmentReportSection> gaps,
  ) {
    final gapText = gaps.isEmpty
        ? 'No major component gap was identified in the selected assessment.'
        : 'Priority attention is needed for ${gaps.take(3).map((gap) => gap.label).join(', ')}.';
    return '${_assessmentReportTitle(tool)} shows a total score of ${_scoreText(score)} out of ${_scoreText(maxScore)}, placing the facility at $level level. $gapText';
  }

  List<String> _linesOrDefault(String text, List<String> fallback) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return lines.isEmpty ? fallback : lines;
  }

  String _scoreText(num value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  Future<void> _downloadReportPdf(List<Map<String, dynamic>> rows) async {
    final doc = pw.Document();
    final byType = _counts(rows, _typeOf);
    final byDepartment = _counts(rows, _departmentOf);
    final byStatus = _counts(rows, _statusOf);
    final byDataStatus = _counts(
      rows,
      (row) => '${row['dataStatus'] ?? 'Raw Data'}',
    );
    final byWaterSource = _counts(
      rows.where((row) => row['inspectionType'] == 'Water Quality').toList(),
      (row) =>
          '${row['waterSource'] ?? _waterData(row)['Water_Source'] ?? 'Unknown'}',
    );
    final byOverallStatus = _counts(
      rows.where((row) => row['inspectionType'] == 'Water Quality').toList(),
      (row) =>
          '${row['overallStatus'] ?? _waterData(row)['Overall_Status'] ?? 'Unknown'}',
    );
    final localInterpretation = _localSurveillanceInterpretation(
      rows: rows,
      byType: byType,
      byDepartment: byDepartment,
      byStatus: byStatus,
      byDataStatus: byDataStatus,
      byWaterSource: byWaterSource,
      byOverallStatus: byOverallStatus,
    );
    final aiInterpretation = widget.collection == 'environmental_inspections'
        ? await _generateSurveillanceAiInterpretation(
            rows: rows,
            byType: byType,
            byDepartment: byDepartment,
            byStatus: byStatus,
            byDataStatus: byDataStatus,
            byWaterSource: byWaterSource,
            byOverallStatus: byOverallStatus,
          )
        : '';
    final interpretation = aiInterpretation.trim().isNotEmpty
        ? aiInterpretation.trim()
        : localInterpretation;
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            widget.title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Total records: ${rows.length}'),
          pw.SizedBox(height: 12),
          pw.Text('By type'),
          pw.TableHelper.fromTextArray(
            data: byType.entries.map((e) => [e.key, e.value]).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Text('By department'),
          pw.TableHelper.fromTextArray(
            data: byDepartment.entries.map((e) => [e.key, e.value]).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Text('By status'),
          pw.TableHelper.fromTextArray(
            data: byStatus.entries.map((e) => [e.key, e.value]).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Text('By data status'),
          pw.TableHelper.fromTextArray(
            data: byDataStatus.entries.map((e) => [e.key, e.value]).toList(),
          ),
          if (byWaterSource.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Water source distribution'),
            pw.TableHelper.fromTextArray(
              data: byWaterSource.entries.map((e) => [e.key, e.value]).toList(),
            ),
          ],
          if (byOverallStatus.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Water quality status'),
            pw.TableHelper.fromTextArray(
              data: byOverallStatus.entries
                  .map((e) => [e.key, e.value])
                  .toList(),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Text(
            widget.collection == 'environmental_inspections'
                ? 'IPC interpretation'
                : 'Surveillance interpretation',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(interpretation),
        ],
      ),
    );
    final fileName = '${_fileSlug(widget.title)}_report.pdf';
    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: fileName);
    if (!mounted) return;
    setState(() {
      _downloads.insert(
        0,
        _DownloadedReport(
          name: fileName,
          downloadedAt: DateTime.now(),
          recordCount: rows.length,
          bytes: bytes,
          mimeType: 'application/pdf',
        ),
      );
    });
  }

  Future<void> _downloadReportDoc(List<Map<String, dynamic>> rows) async {
    final byType = _counts(rows, _typeOf);
    final byDepartment = _counts(rows, _departmentOf);
    final byStatus = _counts(rows, _statusOf);
    final byDataStatus = _counts(
      rows,
      (row) => '${row['dataStatus'] ?? 'Raw Data'}',
    );
    final byWaterSource = _counts(
      rows.where((row) => row['inspectionType'] == 'Water Quality').toList(),
      (row) =>
          '${row['waterSource'] ?? _waterData(row)['Water_Source'] ?? 'Unknown'}',
    );
    final byOverallStatus = _counts(
      rows.where((row) => row['inspectionType'] == 'Water Quality').toList(),
      (row) =>
          '${row['overallStatus'] ?? _waterData(row)['Overall_Status'] ?? 'Unknown'}',
    );
    final localInterpretation = _localSurveillanceInterpretation(
      rows: rows,
      byType: byType,
      byDepartment: byDepartment,
      byStatus: byStatus,
      byDataStatus: byDataStatus,
      byWaterSource: byWaterSource,
      byOverallStatus: byOverallStatus,
    );
    final aiInterpretation = widget.collection == 'environmental_inspections'
        ? await _generateSurveillanceAiInterpretation(
            rows: rows,
            byType: byType,
            byDepartment: byDepartment,
            byStatus: byStatus,
            byDataStatus: byDataStatus,
            byWaterSource: byWaterSource,
            byOverallStatus: byOverallStatus,
          )
        : '';
    final interpretation = aiInterpretation.trim().isNotEmpty
        ? aiInterpretation.trim()
        : localInterpretation;
    final html = StringBuffer()
      ..writeln('<html><head><meta charset="utf-8"></head><body>')
      ..writeln('<h1>${_htmlEscape(widget.title)}</h1>')
      ..writeln('<p><strong>Total records:</strong> ${rows.length}</p>')
      ..writeln(
        _htmlSimpleTable(
          'By type',
          ['Type', 'Count'],
          byType.entries.map((entry) => [entry.key, entry.value]).toList(),
        ),
      )
      ..writeln(
        _htmlSimpleTable(
          'By department',
          ['Department', 'Count'],
          byDepartment.entries
              .map((entry) => [entry.key, entry.value])
              .toList(),
        ),
      )
      ..writeln(
        _htmlSimpleTable(
          'By submission status',
          ['Status', 'Count'],
          byStatus.entries.map((entry) => [entry.key, entry.value]).toList(),
        ),
      )
      ..writeln(
        _htmlSimpleTable(
          'By data status',
          ['Data status', 'Count'],
          byDataStatus.entries
              .map((entry) => [entry.key, entry.value])
              .toList(),
        ),
      );
    if (byWaterSource.isNotEmpty) {
      html.writeln(
        _htmlSimpleTable(
          'Water source distribution',
          ['Water source', 'Count'],
          byWaterSource.entries
              .map((entry) => [entry.key, entry.value])
              .toList(),
        ),
      );
    }
    if (byOverallStatus.isNotEmpty) {
      html.writeln(
        _htmlSimpleTable(
          'Water quality status',
          ['Status', 'Count'],
          byOverallStatus.entries
              .map((entry) => [entry.key, entry.value])
              .toList(),
        ),
      );
    }
    final interpretationTitle = widget.collection == 'environmental_inspections'
        ? 'IPC interpretation'
        : 'Surveillance interpretation';
    html
      ..writeln('<h3>${_htmlEscape(interpretationTitle)}</h3>')
      ..writeln('<p>${_htmlEscape(interpretation)}</p>')
      ..writeln('</body></html>');
    final fileName = '${_fileSlug(widget.title)}_report.doc';
    final bytes = Uint8List.fromList(utf8.encode(html.toString()));
    await Share.shareXFiles([
      XFile.fromData(bytes, mimeType: 'application/msword', name: fileName),
    ]);
    if (!mounted) return;
    setState(() {
      _downloads.insert(
        0,
        _DownloadedReport(
          name: fileName,
          downloadedAt: DateTime.now(),
          recordCount: rows.length,
          bytes: bytes,
          mimeType: 'application/msword',
        ),
      );
    });
  }

  void _showHandHygieneComplianceCalculator(List<QueryDocumentSnapshot> docs) {
    final rows = docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    final calculator = _buildHandHygieneCalculator(rows);
    final categories = calculator.categories;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hand Hygiene Observation Report'),
        content: SizedBox(
          width: 820,
          child: ListView(
            shrinkWrap: true,
            children: [
              Wrap(
                spacing: 12,
                children: [
                  _summaryCard(
                    'Sessions',
                    '${calculator.sessions.length}',
                    Colors.blue,
                  ),
                  _summaryCard(
                    'Opportunities',
                    '${calculator.totalOpportunities}',
                    Colors.orange,
                  ),
                  _summaryCard(
                    'Compliance',
                    '${calculator.complianceRate.toStringAsFixed(1)}%',
                    Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    const DataColumn(label: Text('Session')),
                    const DataColumn(label: Text('Department')),
                    const DataColumn(label: Text('Ward/Unit')),
                    for (final category in categories) ...[
                      DataColumn(label: Text('$category Opp')),
                      DataColumn(label: Text('$category HW')),
                      DataColumn(label: Text('$category HR')),
                    ],
                    const DataColumn(label: Text('Total Opp')),
                    const DataColumn(label: Text('Total HW')),
                    const DataColumn(label: Text('Total HR')),
                    const DataColumn(label: Text('Compliance')),
                  ],
                  rows: calculator.sessions.map((session) {
                    return DataRow(
                      cells: [
                        DataCell(Text(session.sessionLabel)),
                        DataCell(Text(session.department)),
                        DataCell(Text(session.ward)),
                        for (final category in categories) ...[
                          DataCell(
                            Text('${session.byCategory[category]?.opp ?? 0}'),
                          ),
                          DataCell(
                            Text('${session.byCategory[category]?.hw ?? 0}'),
                          ),
                          DataCell(
                            Text('${session.byCategory[category]?.hr ?? 0}'),
                          ),
                        ],
                        DataCell(Text('${session.total.opp}')),
                        DataCell(Text('${session.total.hw}')),
                        DataCell(Text('${session.total.hr}')),
                        DataCell(
                          Text(
                            '${session.total.compliance.toStringAsFixed(1)}%',
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              _barSummary('Compliance by professional category', {
                for (final category in categories)
                  category:
                      calculator.categoryTotals[category]?.compliance.round() ??
                      0,
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _exportHandHygieneCalculatorCsv(calculator),
            child: const Text('Download Excel'),
          ),
          TextButton(
            onPressed: () => _downloadHandHygieneCalculatorPdf(calculator),
            child: const Text('Print PDF'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  _HandHygieneCalculatorData _buildHandHygieneCalculator(
    List<Map<String, dynamic>> rows,
  ) {
    final sessions = <_HandHygieneCalculatorSession>[];
    final categoryTotals = <String, _HandHygieneCalculatorCount>{};
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final sessionLabel =
          '${row['sessionNumber'] ?? row['formId'] ?? 'Session ${i + 1}'}';
      final byCategory = <String, _HandHygieneCalculatorCount>{};
      final summary = row['complianceSummary'] is Map
          ? Map<String, dynamic>.from(row['complianceSummary'] as Map)
          : const <String, dynamic>{};
      final perCategory = summary['perCategory'];
      if (perCategory is List) {
        for (final item in perCategory) {
          if (item is! Map) continue;
          final data = Map<String, dynamic>.from(item);
          final category =
              '${data['professionalCategory'] ?? 'Category ${data['index'] ?? byCategory.length + 1}'}';
          final count = _HandHygieneCalculatorCount(
            opp: _asInt(data['opportunities']),
            hw: _asInt(data['handwash']),
            hr: _asInt(data['handrub']),
          );
          byCategory[category] = count;
          categoryTotals.update(
            category,
            (existing) => existing + count,
            ifAbsent: () => count,
          );
        }
      } else {
        final category = '${row['staffCategory'] ?? 'Observed staff'}';
        final action = '${row['method'] ?? ''}';
        final count = _HandHygieneCalculatorCount(
          opp: row['compliant'] == null ? 0 : 1,
          hw: action.contains('soap') ? 1 : 0,
          hr: action.contains('Alcohol') ? 1 : 0,
        );
        byCategory[category] = count;
        categoryTotals.update(
          category,
          (existing) => existing + count,
          ifAbsent: () => count,
        );
      }
      sessions.add(
        _HandHygieneCalculatorSession(
          sessionLabel: sessionLabel,
          department: '${row['department'] ?? '-'}',
          ward: '${row['ward'] ?? row['unit'] ?? '-'}',
          byCategory: byCategory,
        ),
      );
    }
    return _HandHygieneCalculatorData(
      sessions: sessions,
      categoryTotals: categoryTotals,
    );
  }

  Future<void> _exportHandHygieneCalculatorCsv(
    _HandHygieneCalculatorData calculator,
  ) async {
    final categories = calculator.categories;
    final headers = [
      'Session',
      'Department',
      'Ward/Unit',
      for (final category in categories) ...[
        '$category Opp',
        '$category HW',
        '$category HR',
      ],
      'Total Opp',
      'Total HW',
      'Total HR',
      'Compliance %',
    ];
    final csv = StringBuffer()..writeln(headers.map(_csvCell).join(','));
    for (final session in calculator.sessions) {
      csv.writeln(
        [
          session.sessionLabel,
          session.department,
          session.ward,
          for (final category in categories) ...[
            session.byCategory[category]?.opp ?? 0,
            session.byCategory[category]?.hw ?? 0,
            session.byCategory[category]?.hr ?? 0,
          ],
          session.total.opp,
          session.total.hw,
          session.total.hr,
          session.total.compliance.toStringAsFixed(1),
        ].map(_csvCell).join(','),
      );
    }
    await Share.shareXFiles([
      XFile.fromData(
        Uint8List.fromList(utf8.encode(csv.toString())),
        mimeType: 'text/csv',
        name:
            'hand_hygiene_compliance_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
      ),
    ]);
  }

  Future<void> _downloadHandHygieneCalculatorPdf(
    _HandHygieneCalculatorData calculator,
  ) async {
    final categories = calculator.categories;
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'Hand Hygiene Observation - Basic Compliance Calculation',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Total sessions: ${calculator.sessions.length}'),
          pw.Text('Total opportunities: ${calculator.totalOpportunities}'),
          pw.Text(
            'Total compliance: ${calculator.complianceRate.toStringAsFixed(1)}%',
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: [
              'Session',
              'Department',
              'Ward/Unit',
              for (final category in categories) ...[
                '$category Opp',
                '$category HW',
                '$category HR',
              ],
              'Total Opp',
              'Total HW',
              'Total HR',
              'Compliance %',
            ],
            data: calculator.sessions
                .map(
                  (session) => [
                    session.sessionLabel,
                    session.department,
                    session.ward,
                    for (final category in categories) ...[
                      session.byCategory[category]?.opp ?? 0,
                      session.byCategory[category]?.hw ?? 0,
                      session.byCategory[category]?.hr ?? 0,
                    ],
                    session.total.opp,
                    session.total.hw,
                    session.total.hr,
                    session.total.compliance.toStringAsFixed(1),
                  ],
                )
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'hand_hygiene_compliance_calculator.pdf',
    );
  }

  Widget _surveillanceInterpretationCard({
    required String title,
    required String body,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(_cleanIpcAiText(body)),
          ],
        ),
      ),
    );
  }

  Map<String, int> _environmentalGapSignals(List<Map<String, dynamic>> rows) {
    final signals = <String, int>{};
    const focusTerms = [
      'clean',
      'waste',
      'bin',
      'sharp',
      'toilet',
      'sanitary',
      'hand hygiene',
      'sink',
      'water',
      'soap',
      'abhr',
      'ppe',
      'linen',
      'equipment',
      'schedule',
      'disinfect',
      'spill',
    ];
    const negativeTerms = [
      'no',
      'not available',
      'not functional',
      'not stored',
      'never',
      'unknown',
      'failed',
      'poor',
      'dirty',
      'incomplete',
      'pending',
    ];
    for (final row in rows) {
      final fields = _fullDisplayFields(row);
      for (final entry in fields.entries) {
        final key = entry.key.toLowerCase();
        final value = _formatValue(entry.value).toLowerCase();
        if (!focusTerms.any(key.contains)) continue;
        if (!negativeTerms.any(value.contains)) continue;
        signals.update(entry.key, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final entries = signals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries.take(12));
  }

  Future<String> _generateSurveillanceAiInterpretation({
    required List<Map<String, dynamic>> rows,
    required Map<String, int> byType,
    required Map<String, int> byDepartment,
    required Map<String, int> byStatus,
    required Map<String, int> byDataStatus,
    required Map<String, int> byWaterSource,
    required Map<String, int> byOverallStatus,
  }) async {
    try {
      await GeminiService.initialize();
      final gemini = GeminiService.instance;
      if (!gemini.isConfigured) return '';
      final isEnvironmental = widget.collection == 'environmental_inspections';
      final environmentalGaps = isEnvironmental
          ? _environmentalGapSignals(rows)
          : const <String, int>{};
      final response = await gemini.getChatResponse(
        userRole: 'doctor',
        specialization: 'infection prevention and control surveillance',
        userMessage: isEnvironmental
            ? 'Interpret this selected environmental surveillance dataset for an IPC team. Use one brief, detailed, simple, and clear plain-text interpretation only. Do not use markdown, headings, bullets, #, *, tables, emojis, or a separate AI interpretation label. Do not repeat individual questionnaire questions. Identify reasonable IPC gaps from the submitted data and give practical suggestions to improve environmental cleaning, waste segregation, sharps safety, hand hygiene resources, water/sanitation, PPE, linen, and equipment management where applicable. Keep it professionally aligned with IPC standards in no more than six short lines. Selected records: ${rows.length}. Surveillance type distribution: $byType. Department distribution: $byDepartment. Submission status: $byStatus. Data validation status: $byDataStatus. Water source distribution: $byWaterSource. Water quality status: $byOverallStatus. Detected gap signals from negative or incomplete responses: $environmentalGaps.'
            : 'Interpret this selected ${widget.title} dataset for an IPC/public health surveillance team. Use brief, detailed, simple, and clear plain text. Do not use markdown, headings, bullets, #, *, tables, or emojis. Do not repeat individual questionnaire questions. Provide epidemiological and IPC interpretation, priority areas, and practical corrective actions in no more than six short lines. Selected records: ${rows.length}. Type distribution: $byType. Department distribution: $byDepartment. Submission status: $byStatus. Data validation status: $byDataStatus. Water source distribution when applicable: $byWaterSource. Water quality status when applicable: $byOverallStatus.',
      );
      return _cleanIpcAiText(response);
    } catch (_) {
      return '';
    }
  }

  String _localSurveillanceInterpretation({
    required List<Map<String, dynamic>> rows,
    required Map<String, int> byType,
    required Map<String, int> byDepartment,
    required Map<String, int> byStatus,
    required Map<String, int> byDataStatus,
    required Map<String, int> byWaterSource,
    required Map<String, int> byOverallStatus,
  }) {
    final total = rows.length;
    final topType = _topSurveillanceCount(byType);
    final topDepartment = _topSurveillanceCount(byDepartment);
    final topStatus = _topSurveillanceCount(byStatus);
    final topDataStatus = _topSurveillanceCount(byDataStatus);
    final topWaterSource = _topSurveillanceCount(byWaterSource);
    final topOverallStatus = _topSurveillanceCount(byOverallStatus);
    final pending = _countSurveillanceMatching(byStatus, [
      'draft',
      'pending',
      'incomplete',
    ]);
    final rejected = _countSurveillanceMatching(byDataStatus, [
      'rejected',
      'not approved',
    ]);
    final environmentalGaps = widget.collection == 'environmental_inspections'
        ? _environmentalGapSignals(rows)
        : const <String, int>{};
    final buffer = StringBuffer();

    buffer.writeln(
      'This report summarizes $total selected ${widget.title.toLowerCase()} record${total == 1 ? '' : 's'} and should be interpreted as a filtered surveillance extract.',
    );
    if (topType != null) {
      buffer.writeln(
        'The most frequent surveillance type is ${topType.key} (${topType.value}, ${_surveillancePercent(topType.value, total)}%), so the first review should focus on this surveillance stream.',
      );
    }
    if (topDepartment != null && topDepartment.key != '-') {
      buffer.writeln(
        'The largest department signal is ${topDepartment.key} (${topDepartment.value}, ${_surveillancePercent(topDepartment.value, total)}%). Prioritize feedback, validation, and corrective action follow-up there.',
      );
    }
    if (topOverallStatus != null &&
        topOverallStatus.key.toLowerCase() != 'unknown') {
      buffer.writeln(
        'For water quality records, the leading result category is ${topOverallStatus.key} (${topOverallStatus.value}). Confirm failed or borderline results against microbiology/chemical thresholds and initiate corrective actions where needed.',
      );
    } else if (topWaterSource != null &&
        topWaterSource.key.toLowerCase() != 'unknown') {
      buffer.writeln(
        'Water records are concentrated around ${topWaterSource.key} sources (${topWaterSource.value}); compare these against result status and sampling point to identify recurrent supply risks.',
      );
    }
    if (pending > 0) {
      buffer.writeln(
        '$pending record${pending == 1 ? '' : 's'} remain pending or draft; these should be completed or validated before using the report for formal performance decisions.',
      );
    }
    if (rejected > 0) {
      buffer.writeln(
        '$rejected selected record${rejected == 1 ? '' : 's'} have not been approved or were rejected; review data quality, missing fields, and supervisor comments before analysis is finalized.',
      );
    }
    if (environmentalGaps.isNotEmpty) {
      final gapText = environmentalGaps.entries
          .take(5)
          .map((entry) => '${entry.key} (${entry.value})')
          .join(', ');
      buffer.writeln(
        'IPC gap signals were detected around $gapText. Focus corrective action on reliable cleaning schedules, visible environmental cleanliness, waste segregation, sharps container safety, hand hygiene supplies, water availability, PPE access, linen flow, and equipment disinfection as applicable.',
      );
    }
    if (topStatus != null || topDataStatus != null) {
      buffer.writeln(
        'Recommended actions: validate selected records, investigate high-frequency departments or surveillance types, assign corrective action owners, set follow-up dates, and re-audit after intervention.',
      );
    }
    return buffer.toString().trim();
  }

  MapEntry<String, int>? _topSurveillanceCount(Map<String, int> counts) {
    final entries = counts.entries
        .where((entry) => entry.key.trim().isNotEmpty && entry.value > 0)
        .toList();
    if (entries.isEmpty) return null;
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.first;
  }

  int _countSurveillanceMatching(
    Map<String, int> counts,
    List<String> needles,
  ) {
    var total = 0;
    for (final entry in counts.entries) {
      final key = entry.key.toLowerCase();
      if (needles.any(key.contains)) total += entry.value;
    }
    return total;
  }

  String _surveillancePercent(int value, int total) {
    if (total == 0) return '0.0';
    return ((value / total) * 100).toStringAsFixed(1);
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _barSummary(String title, Map<String, int> counts) {
    final max = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...counts.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 160,
                  child: Text(entry.key, overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: entry.value / max,
                    minHeight: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${entry.value}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Map<String, int> _counts(
    List<Map<String, dynamic>> rows,
    String Function(Map<String, dynamic>) selector,
  ) {
    final counts = <String, int>{};
    for (final row in rows) {
      final key = selector(row);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _updateSelectedDataStatus() async {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in _selectedRecordIds) {
      batch.update(
        FirebaseFirestore.instance.collection(widget.collection).doc(id),
        {
          'dataStatus': _selectedDataStatus,
          'dataStatusUpdatedAt': FieldValue.serverTimestamp(),
          if (widget.staffId != null) 'dataStatusUpdatedById': widget.staffId,
          if (widget.staffName != null) 'dataStatusUpdatedBy': widget.staffName,
          if (widget.staffId != null) 'lastUpdatedById': widget.staffId,
          if (widget.staffName != null) 'lastUpdatedBy': widget.staffName,
          'updatedAt': FieldValue.serverTimestamp(),
          'changeHistory': FieldValue.arrayUnion([
            {
              'staffId': widget.staffId ?? 'unknown',
              'staffName': widget.staffName ?? 'Unknown',
              'action':
                  'data_status_${_selectedDataStatus.toLowerCase().replaceAll(' ', '_')}',
              'at': Timestamp.now(),
            },
          ]),
        },
      );
    }
    await batch.commit();
    setState(() => _selectedRecordIds.clear());
  }

  Map<String, dynamic> _fullDisplayFields(Map<String, dynamic> data) {
    return {
      'Form ID': data['formId'],
      'Data status': data['dataStatus'] ?? 'Raw Data',
      'Submission status': _statusOf(data),
      'Type': _typeOf(data),
      'Department': _departmentOf(data),
      'Unit/Ward': _unitOf(data),
      'Created by staff ID': data['createdById'] ?? data['inspectorId'],
      'Last edited by staff ID': data['lastUpdatedById'],
      'Finalized by staff ID': data['finalizedById'],
      ..._questionnaireDisplayFields(data),
    };
  }

  Map<String, dynamic> _questionnaireDisplayFields(Map<String, dynamic> data) {
    if (widget.collection == 'environmental_inspections') {
      if (data['inspectionType'] == 'Water Quality') {
        final waterData = _waterData(data);
        return {
          for (final field in waterQualityFields)
            field.label: waterData[field.name] ?? data[field.name] ?? '-',
          'Meets Standard':
              waterData['Meets_Standard'] ?? data['meetsStandard'],
          'Overall Status':
              waterData['Overall_Status'] ?? data['overallStatus'],
          'Pending Sections': data['pendingSections'],
        };
      }
      if (data['inspectionType'] == 'General Environmental Health') {
        final responses = data['questionnaireResponses'] is Map
            ? Map<String, dynamic>.from(data['questionnaireResponses'] as Map)
            : const <String, dynamic>{};
        final labels = data['questionnaireResponseLabels'] is Map
            ? Map<String, dynamic>.from(
                data['questionnaireResponseLabels'] as Map,
              )
            : const <String, dynamic>{};
        return {
          for (final question in environmentalHealthQuestions)
            question.label:
                labels[question.name] ?? responses[question.name] ?? '-',
        };
      }
    }
    if (widget.collection == 'ward_denominators') {
      final responses = data['wardDenominatorResponses'] is Map
          ? Map<String, dynamic>.from(data['wardDenominatorResponses'] as Map)
          : const <String, dynamic>{};
      final labels = data['wardDenominatorResponseLabels'] is Map
          ? Map<String, dynamic>.from(
              data['wardDenominatorResponseLabels'] as Map,
            )
          : const <String, dynamic>{};
      return {
        for (final field in wardDenominatorFields)
          field.label: labels[field.name] ?? responses[field.name] ?? '-',
      };
    }
    if (widget.collection == 'hand_hygiene_observations') {
      final summary = data['complianceSummary'] is Map
          ? Map<String, dynamic>.from(data['complianceSummary'] as Map)
          : const <String, dynamic>{};
      return {
        'Session number': data['sessionNumber'],
        'Total opportunities': summary['totalOpportunities'],
        'Handwash actions': summary['totalHandwash'],
        'Handrub actions': summary['totalHandrub'],
        'Missed actions': summary['totalMissed'],
        'Compliance rate (%)': _numericPercent(summary['complianceRate']),
      };
    }
    if (widget.collection == 'ipc_assessments') {
      final sections = data['assessmentSections'] is Map
          ? Map<String, dynamic>.from(data['assessmentSections'] as Map)
          : const <String, dynamic>{};
      return {
        'Assessment tool': data['assessmentTool'] ?? data['assessmentType'],
        'Assessor': data['assessorName'],
        'Assessment date': data['assessmentDate'],
        'Total score': data['totalScore'],
        'Maximum score': data['maxScore'],
        'Percentage score': _numericPercent(data['percentageScore']),
        'Assessment level': data['assessmentLevel'],
        'Strengths': data['strengths'],
        'Priority gaps': data['priorityGaps'],
        'Recommended actions': data['recommendedActions'],
        for (final entry in sections.entries)
          ..._assessmentSectionDisplayFields(entry.key, entry.value),
      };
    }
    if (widget.collection == 'ipc_custom_form_submissions') {
      final responses = data['responses'] is Map
          ? Map<String, dynamic>.from(data['responses'] as Map)
          : const <String, dynamic>{};
      final labels = data['responseLabels'] is Map
          ? Map<String, dynamic>.from(data['responseLabels'] as Map)
          : const <String, dynamic>{};
      final questions = data['questions'] is List
          ? (data['questions'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : const <Map<String, dynamic>>[];
      return {
        'Custom form': data['customFormTitle'],
        for (final question in questions)
          '${question['label'] ?? question['id']}':
              labels[question['id']] ?? responses[question['id']] ?? '-',
      };
    }
    return {
      'Findings level': data['findingsLevel'],
      'Findings': data['findings'],
      'Recommendations': data['recommendations'],
      'Moment': data['moment'],
      'Compliant': data['compliant'],
      'Outbreak status': data['status'],
    };
  }

  List<String> _fullExportHeaders(List<QueryDocumentSnapshot> docs) {
    final rows = docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    return _fullExportHeadersFromRows(rows);
  }

  List<String> _fullExportHeadersFromRows(List<Map<String, dynamic>> rows) {
    final hasEnvironmental = widget.collection == 'environmental_inspections';
    final hasWardDenominator = widget.collection == 'ward_denominators';
    final hasHandHygiene = widget.collection == 'hand_hygiene_observations';
    final hasIpcAssessments = widget.collection == 'ipc_assessments';
    final hasCustomForms = widget.collection == 'ipc_custom_form_submissions';
    final hasWater = rows.any(
      (row) => row['inspectionType'] == 'Water Quality',
    );
    final hasGeneral = rows.any(
      (row) => row['inspectionType'] == 'General Environmental Health',
    );
    final headers = <String>[
      'Form ID',
      'Data status',
      'Submission status',
      'Type',
      'Department',
      'Unit/Ward',
      'Created by staff ID',
      'Last edited by staff ID',
      'Finalized by staff ID',
      'Date',
    ];
    if (hasEnvironmental && hasGeneral) {
      headers.addAll(environmentalHealthQuestions.map((q) => q.label));
    }
    if (hasEnvironmental && hasWater) {
      headers.addAll(waterQualityFields.map((field) => field.label));
      headers.addAll(['Meets Standard', 'Overall Status', 'Pending Sections']);
    }
    if ((!hasEnvironmental &&
            !hasWardDenominator &&
            !hasIpcAssessments &&
            !hasCustomForms) ||
        (hasEnvironmental && !hasWater && !hasGeneral)) {
      headers.addAll([
        'Findings level',
        'Findings',
        'Recommendations',
        'Moment',
        'Compliant',
        'Outbreak status',
      ]);
    }
    if (hasWardDenominator) {
      headers.addAll(wardDenominatorFields.map((field) => field.label));
    }
    if (hasHandHygiene) {
      headers.addAll([
        'Session number',
        'Total opportunities',
        'Handwash actions',
        'Handrub actions',
        'Missed actions',
        'Compliance rate (%)',
        'Professional category results',
      ]);
    }
    if (hasIpcAssessments) {
      headers.addAll([
        'Assessment tool',
        'Assessor',
        'Assessment date',
        'Total score',
        'Maximum score',
        'Percentage score',
        'Assessment level',
        'Strengths',
        'Priority gaps',
        'Recommended actions',
      ]);
      for (final row in rows) {
        final sections = row['assessmentSections'] is Map
            ? Map<String, dynamic>.from(row['assessmentSections'] as Map)
            : const <String, dynamic>{};
        for (final entry in sections.entries) {
          headers.addAll(
            _assessmentSectionDisplayFields(entry.key, entry.value).keys,
          );
        }
      }
    }
    if (hasCustomForms) {
      headers.add('Custom form');
      for (final row in rows) {
        final questions = row['questions'] is List
            ? (row['questions'] as List)
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : const <Map<String, dynamic>>[];
        headers.addAll(questions.map((question) => '${question['label']}'));
      }
    }
    return headers.toSet().toList();
  }

  Map<String, dynamic> _fullExportRow(
    Map<String, dynamic> data,
    List<String> headers,
  ) {
    final display = {..._fullDisplayFields(data), 'Date': _dateLabel(data)};
    return {for (final header in headers) header: display[header] ?? ''};
  }

  String _searchableValue(Map<String, dynamic> data) {
    switch (_searchField) {
      case 'sampleId':
        return '${data['sampleId'] ?? _waterData(data)['Sample_ID'] ?? ''}';
      case 'department':
        return _departmentOf(data);
      case 'formId':
      default:
        return '${data['formId'] ?? ''}';
    }
  }

  String _typeOf(Map<String, dynamic> data) =>
      '${data['inspectionType'] ?? data['assessmentTool'] ?? data['assessmentType'] ?? data['infectionType'] ?? data['recordType'] ?? data['moment'] ?? widget.title}';

  String _departmentOf(Map<String, dynamic> data) =>
      '${data['department'] ?? _waterData(data)['Ward_Department'] ?? '-'}';

  String _unitOf(Map<String, dynamic> data) =>
      '${data['unit'] ?? data['ward'] ?? _waterData(data)['Unit'] ?? '-'}';

  String _statusOf(Map<String, dynamic> data) =>
      '${data['submissionStatus'] ?? data['status'] ?? (data['compliant'] == true
              ? 'Compliant'
              : data['compliant'] == false
              ? 'Non-compliant'
              : 'Submitted')}';

  String _dateLabel(Map<String, dynamic> data) {
    final timestamp =
        data['reportedDate'] ??
        data['inspectionDate'] ??
        data['observationDate'] ??
        data['assessmentDate'];
    return timestamp is Timestamp
        ? DateFormat('MMM d, y').format(timestamp.toDate())
        : '-';
  }

  String _formatValue(Object? value) {
    if (value is Timestamp) {
      return DateFormat('MMM d, y HH:mm').format(value.toDate());
    }
    if (value is Map || value is List) return jsonEncode(value);
    return '${value ?? '-'}';
  }

  String _numericPercent(Object? value) {
    if (value is num) return value.toStringAsFixed(1);
    return '${value ?? '-'}';
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('$value') ?? 0;
  }

  Map<String, dynamic> _waterData(Map<String, dynamic> data) {
    return data['waterQualityData'] is Map
        ? Map<String, dynamic>.from(data['waterQualityData'] as Map)
        : const <String, dynamic>{};
  }

  Color _dataStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'not approved':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  static String _csvCell(Object? value) {
    final text = '${value ?? ''}'.replaceAll('"', '""');
    return '"$text"';
  }

  static String _fileSlug(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  Map<String, dynamic> _assessmentSectionDisplayFields(
    String key,
    Object? value,
  ) {
    final section = value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
    final label = '${section['label'] ?? key}';
    final questions = section['questions'] is Map
        ? Map<String, dynamic>.from(section['questions'] as Map)
        : const <String, dynamic>{};
    return {
      '$label score': section['score'],
      '$label maximum score': section['maxScore'],
      '$label percentage score': section['percentageScore'],
      for (final entry in questions.entries)
        ..._assessmentQuestionDisplayFields(label, entry.value),
      '$label observation': section['observation'],
      '$label action': section['action'],
    };
  }

  Map<String, dynamic> _assessmentQuestionDisplayFields(
    String sectionLabel,
    Object? value,
  ) {
    final question = value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
    final prompt = '${question['prompt'] ?? 'Question'}';
    return {
      '$sectionLabel - $prompt answer': question['answerLabel'],
      '$sectionLabel - $prompt score': question['score'],
    };
  }
}

// ===================== CUSTOM SURVEILLANCE FORM ENTRY =====================

class _CustomSurveillanceEntryScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final String formId;
  final Map<String, dynamic> formData;

  const _CustomSurveillanceEntryScreen({
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    required this.formId,
    required this.formData,
  });

  @override
  State<_CustomSurveillanceEntryScreen> createState() =>
      _CustomSurveillanceEntryScreenState();
}

class _CustomSurveillanceEntryScreenState
    extends State<_CustomSurveillanceEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _answers = {};
  final Map<String, String> _answerLabels = {};
  bool _saving = false;

  List<Map<String, dynamic>> get _questions {
    final items = widget.formData['questions'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _save({required bool finalSubmit}) async {
    _syncCalculatedAnswers();
    if (finalSubmit && !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final generatedId = await SurveillanceFormIdService.nextFormId(
        facilityId: widget.facilityId,
        surveillanceCode: 'ipc_custom_${widget.formId}',
      );
      await FirebaseFirestore.instance
          .collection('ipc_custom_form_submissions')
          .add({
            'facilityId': widget.facilityId,
            'facilityName': widget.facilityName,
            'formId': generatedId,
            'customFormId': widget.formId,
            'customFormTitle': widget.formData['title'],
            'recordType': 'Custom Surveillance Form',
            'inspectionType': widget.formData['title'],
            'submissionStatus': finalSubmit ? 'Final' : 'Draft',
            'submissionState': finalSubmit ? 'final' : 'draft',
            'status': finalSubmit ? 'submitted' : 'pending',
            'isFinal': finalSubmit,
            'dataStatus': 'Raw Data',
            'responses': _answers,
            'responseLabels': _answerLabels,
            'questions': _questions,
            'dashboardSource': 'ipc',
            'createdBy': widget.staffName,
            'createdById': widget.staffId,
            'lastUpdatedBy': widget.staffName,
            'lastUpdatedById': widget.staffId,
            'reportedDate': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              finalSubmit
                  ? 'Custom surveillance submitted'
                  : 'Custom surveillance saved as draft',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save custom form: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _isVisible(Map<String, dynamic> question) {
    final rules = _conditionalRulesForQuestion(question);
    if (rules.isEmpty) return true;
    return rules.any(_conditionalRuleMatches);
  }

  List<Map<String, String>> _conditionalRulesForQuestion(
    Map<String, dynamic> question,
  ) {
    final rules = <Map<String, String>>[];
    final rawRules = question['showIfRules'];
    if (rawRules is List) {
      for (final raw in rawRules) {
        if (raw is! Map) continue;
        final questionId =
            '${raw['questionId'] ?? raw['showIfQuestionId'] ?? ''}'.trim();
        final value = _normalizeCustomSkipLogicValue(
          raw['value'] ?? raw['showIfValue'],
        );
        if (questionId.isEmpty || value.isEmpty) continue;
        rules.add({'questionId': questionId, 'value': value});
      }
    }
    final legacyQuestionId = '${question['showIfQuestionId'] ?? ''}'.trim();
    final legacyValue = _normalizeCustomSkipLogicValue(question['showIfValue']);
    if (legacyQuestionId.isNotEmpty && legacyValue.isNotEmpty) {
      final exists = rules.any(
        (rule) =>
            rule['questionId'] == legacyQuestionId &&
            rule['value'] == legacyValue,
      );
      if (!exists) {
        rules.add({'questionId': legacyQuestionId, 'value': legacyValue});
      }
    }
    return rules;
  }

  bool _conditionalRuleMatches(Map<String, String> rule) {
    final parentId = (rule['questionId'] ?? '').trim();
    final expected = (rule['value'] ?? '').trim().toLowerCase();
    if (parentId.isEmpty || expected.isEmpty) return false;
    final value = _answers[parentId];
    if (expected == '__answered__') return _hasCustomSkipLogicAnswer(value);
    if (value is List) {
      return value.map((item) => '$item'.toLowerCase()).contains(expected);
    }
    return '$value'.trim().toLowerCase() == expected;
  }

  String _normalizeCustomSkipLogicValue(Object? value) {
    final text = '${value ?? ''}'.trim();
    final normalized = text.toLowerCase();
    if (normalized == 'answered' ||
        normalized == 'is answered' ||
        normalized == 'any answer' ||
        normalized == 'not blank' ||
        normalized == '__answered__') {
      return '__answered__';
    }
    return text;
  }

  bool _hasCustomSkipLogicAnswer(Object? value) {
    if (value == null) return false;
    if (value is Iterable) return value.isNotEmpty;
    final text = '$value'.trim();
    return text.isNotEmpty && text != 'null';
  }

  DateTime? _dateFromAnswer(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  String _daysBetween(
    DateTime startDate,
    DateTime endDate, {
    required bool inclusive,
  }) {
    final start = _startOfDay(startDate);
    final end = _startOfDay(endDate);
    final days = end.difference(start).inDays + (inclusive ? 1 : 0);
    return '${days < 0 ? 0 : days}';
  }

  void _syncCalculatedAnswers() {
    for (final question in _questions) {
      final id = '${question['id'] ?? ''}'.trim();
      if (id.isEmpty ||
          '${question['type'] ?? ''}' != 'calculated' ||
          !_isVisible(question)) {
        continue;
      }
      final rawCalculation = question['calculation'];
      final calculation = rawCalculation is Map
          ? Map<String, dynamic>.from(rawCalculation)
          : const <String, dynamic>{};
      if ('${calculation['type'] ?? ''}' != 'days_since_date') continue;
      final sourceQuestionId =
          '${calculation['sourceQuestionId'] ?? calculation['sourceQuestion'] ?? ''}'
              .trim();
      if (sourceQuestionId.isEmpty) continue;
      final sourceDate = _dateFromAnswer(_answers[sourceQuestionId]);
      if (sourceDate == null) continue;
      final endQuestionId =
          '${calculation['endQuestionId'] ?? calculation['endQuestion'] ?? ''}'
              .trim();
      final endDate = endQuestionId.isEmpty
          ? null
          : _dateFromAnswer(_answers[endQuestionId]);
      final value = _daysBetween(
        sourceDate,
        endDate ?? DateTime.now(),
        inclusive: calculation['inclusive'] != false,
      );
      _answers[id] = value;
      _answerLabels[id] = '$value days';
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncCalculatedAnswers();
    final title = '${widget.formData['title'] ?? 'Custom Surveillance'}';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if ('${widget.formData['description'] ?? ''}'.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('${widget.formData['description']}'),
              ),
            ..._questions.where(_isVisible).map(_questionField),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _save(finalSubmit: false),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save progress'),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _save(finalSubmit: true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Final submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionField(Map<String, dynamic> question) {
    final id = '${question['id']}';
    final label = '${question['label'] ?? 'Question'}';
    final type = '${question['type'] ?? 'short_text'}';
    final required = question['required'] == true;
    final options = (question['options'] as List<dynamic>? ?? [])
        .map((item) => '$item')
        .toList();
    final validator = required
        ? (Object? value) {
            final answer = _answers[id];
            if (answer == null || '$answer'.trim().isEmpty) {
              return 'This question is required';
            }
            if (answer is List && answer.isEmpty) return 'Select an option';
            return null;
          }
        : null;

    Widget field;
    switch (type) {
      case 'multiple_choice':
        field = FormField<String>(
          validator: (_) => validator?.call(_answers[id]),
          builder: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              ...options.map(
                (option) => RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: _answers[id] as String?,
                  onChanged: (value) => setState(() {
                    _answers[id] = value;
                    _answerLabels[id] = value ?? '';
                    state.didChange(value);
                    _syncCalculatedAnswers();
                  }),
                ),
              ),
              if (state.hasError)
                Text(
                  state.errorText!,
                  style: const TextStyle(color: Colors.red),
                ),
            ],
          ),
        );
        break;
      case 'checkbox':
        final selected = (_answers[id] as List<dynamic>? ?? []).cast<String>();
        field = FormField<List<String>>(
          validator: (_) => validator?.call(selected),
          builder: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              ...options.map(
                (option) => CheckboxListTile(
                  title: Text(option),
                  value: selected.contains(option),
                  onChanged: (checked) => setState(() {
                    if (checked ?? false) {
                      selected.add(option);
                    } else {
                      selected.remove(option);
                    }
                    _answers[id] = selected;
                    _answerLabels[id] = selected.join(', ');
                    state.didChange(selected);
                    _syncCalculatedAnswers();
                  }),
                ),
              ),
              if (state.hasError)
                Text(
                  state.errorText!,
                  style: const TextStyle(color: Colors.red),
                ),
            ],
          ),
        );
        break;
      case 'long_text':
        field = TextFormField(
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              required && (value == null || value.trim().isEmpty)
              ? 'This question is required'
              : null,
          onChanged: (value) {
            _answers[id] = value;
            _answerLabels[id] = value;
            _syncCalculatedAnswers();
          },
        );
        break;
      case 'number':
        field = TextFormField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              required && (value == null || value.trim().isEmpty)
              ? 'This question is required'
              : null,
          onChanged: (value) {
            _answers[id] = num.tryParse(value) ?? value;
            _answerLabels[id] = value;
            _syncCalculatedAnswers();
          },
        );
        break;
      case 'date':
      case 'time':
        field = ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: Text(_answerLabels[id] ?? 'Not selected'),
          trailing: const Icon(Icons.calendar_month_outlined),
          onTap: () async {
            if (type == 'date') {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                initialDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _answers[id] = Timestamp.fromDate(picked);
                  _answerLabels[id] = DateFormat('yyyy-MM-dd').format(picked);
                  _syncCalculatedAnswers();
                });
              }
            } else {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (picked != null) {
                setState(() {
                  _answers[id] = picked.format(context);
                  _answerLabels[id] = picked.format(context);
                  _syncCalculatedAnswers();
                });
              }
            }
          },
        );
        break;
      case 'file_upload':
        field = ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: Text(_answerLabels[id] ?? 'No file uploaded'),
          trailing: const Icon(Icons.upload_file_outlined),
          onTap: () => _pickAndUploadFile(id),
        );
        break;
      case 'linear_scale':
        final min = question['scaleMin'] is int
            ? question['scaleMin'] as int
            : 1;
        final max = question['scaleMax'] is int
            ? question['scaleMax'] as int
            : 5;
        field = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: (max - min).abs(),
              value: ((_answers[id] as num?)?.toDouble() ?? min.toDouble())
                  .clamp(min.toDouble(), max.toDouble()),
              label: '${_answers[id] ?? min}',
              onChanged: (value) => setState(() {
                _answers[id] = value.round();
                _answerLabels[id] = '${value.round()}';
                _syncCalculatedAnswers();
              }),
            ),
          ],
        );
        break;
      case 'multiple_choice_grid':
      case 'tickbox_grid':
        field = _gridField(question);
        break;
      case 'calculated':
        field = FormField<String>(
          validator: (_) {
            final value = '${_answers[id] ?? ''}'.trim();
            return required && value.isEmpty
                ? 'This question is required'
                : null;
          },
          builder: (state) => InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              suffixText: 'days',
              errorText: state.errorText,
            ),
            child: Text('${_answers[id] ?? ''}'),
          ),
        );
        break;
      case 'short_text':
      default:
        field = TextFormField(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              required && (value == null || value.trim().isEmpty)
              ? 'This question is required'
              : null,
          onChanged: (value) {
            _answers[id] = value;
            _answerLabels[id] = value;
          },
        );
    }
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: field);
  }

  Widget _gridField(Map<String, dynamic> question) {
    final id = '${question['id']}';
    final rows = (question['gridRows'] as List<dynamic>? ?? [])
        .map((item) => '$item')
        .toList();
    final columns = (question['gridColumns'] as List<dynamic>? ?? [])
        .map((item) => '$item')
        .toList();
    final tickbox = question['type'] == 'tickbox_grid';
    final answer = Map<String, dynamic>.from(
      _answers[id] as Map? ?? const <String, dynamic>{},
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${question['label']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        ...rows.map(
          (row) => Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    row,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ...columns.map((column) {
                  final selectedValues = (answer[row] as List<dynamic>? ?? [])
                      .cast<String>();
                  return tickbox
                      ? CheckboxListTile(
                          title: Text(column),
                          value: selectedValues.contains(column),
                          onChanged: (checked) => setState(() {
                            if (checked ?? false) {
                              selectedValues.add(column);
                            } else {
                              selectedValues.remove(column);
                            }
                            answer[row] = selectedValues;
                            _answers[id] = answer;
                            _answerLabels[id] = jsonEncode(answer);
                            _syncCalculatedAnswers();
                          }),
                        )
                      : RadioListTile<String>(
                          title: Text(column),
                          value: column,
                          groupValue: answer[row] as String?,
                          onChanged: (value) => setState(() {
                            answer[row] = value;
                            _answers[id] = answer;
                            _answerLabels[id] = jsonEncode(answer);
                            _syncCalculatedAnswers();
                          }),
                        );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadFile(String questionId) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;
    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final path =
        'ipc_custom_surveillance/${widget.facilityId}/${widget.formId}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(file.bytes!);
    final url = await ref.getDownloadURL();
    setState(() {
      _answers[questionId] = {'name': file.name, 'url': url, 'path': path};
      _answerLabels[questionId] = file.name;
      _syncCalculatedAnswers();
    });
  }
}

// ===================== IPC ASSESSMENT TOOLS FORM =====================

class _IpcAssessmentSection {
  final String key;
  final String label;
  final String prompt;
  final double maxScore;
  final List<_IpcAssessmentQuestion> questions;

  const _IpcAssessmentSection({
    required this.key,
    required this.label,
    required this.prompt,
    required this.maxScore,
    required this.questions,
  });
}

class _IpcAssessmentQuestion {
  final String key;
  final String prompt;
  final List<_IpcAssessmentOption> options;

  const _IpcAssessmentQuestion({
    required this.key,
    required this.prompt,
    required this.options,
  });
}

class _IpcAssessmentOption {
  final String key;
  final String label;
  final double score;

  const _IpcAssessmentOption(this.key, this.label, this.score);
}

const _yesNo2_5 = [
  _IpcAssessmentOption('no', 'No', 0),
  _IpcAssessmentOption('yes', 'Yes', 2.5),
];

const _yesNo5 = [
  _IpcAssessmentOption('no', 'No', 0),
  _IpcAssessmentOption('yes', 'Yes', 5),
];

const _yesNo7_5 = [
  _IpcAssessmentOption('no', 'No', 0),
  _IpcAssessmentOption('yes', 'Yes', 7.5),
];

const _yesNo10 = [
  _IpcAssessmentOption('no', 'No', 0),
  _IpcAssessmentOption('yes', 'Yes', 10),
];

const _yesNo15 = [
  _IpcAssessmentOption('no', 'No', 0),
  _IpcAssessmentOption('yes', 'Yes', 15),
];

const _hhsafYesNo5 = [
  _IpcAssessmentOption('no', 'No', 0),
  _IpcAssessmentOption('yes', 'Yes', 5),
];

const _hhsafYesNo10 = [
  _IpcAssessmentOption('no', 'No', 0),
  _IpcAssessmentOption('yes', 'Yes', 10),
];

const _hhsafYesNo15 = [
  _IpcAssessmentOption('no', 'No', 0),
  _IpcAssessmentOption('yes', 'Yes', 15),
];

const _hhsafYesNo20 = [
  _IpcAssessmentOption('no', 'No', 0),
  _IpcAssessmentOption('yes', 'Yes', 20),
];

const _washFitOptions = [
  _IpcAssessmentOption('red', 'Red - criterion not met', 0),
  _IpcAssessmentOption('yellow', 'Yellow - partially met', 1),
  _IpcAssessmentOption('green', 'Green - fully met', 2),
];

const _ipcafAssessmentSections = [
  _IpcAssessmentSection(
    key: 'ipc_programme',
    label: 'IPC programme',
    prompt: 'Leadership, objectives, IPC team, committee and annual work plan.',
    maxScore: 100,
    questions: [
      _IpcAssessmentQuestion(
        key: 'ipc_programme',
        prompt: 'Do you have an IPC programme?',
        options: [
          _IpcAssessmentOption('no', 'No', 0),
          _IpcAssessmentOption(
            'yes_no_objectives',
            'Yes, without clearly defined objectives',
            5,
          ),
          _IpcAssessmentOption(
            'yes_objectives_plan',
            'Yes, with clearly defined objectives and annual activity plan',
            10,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'ipc_team',
        prompt:
            'Is the IPC programme supported by an IPC team comprising IPC professionals?',
        options: [
          _IpcAssessmentOption('no', 'No', 0),
          _IpcAssessmentOption(
            'focal_person',
            'Not a team, only an IPC focal person',
            5,
          ),
          _IpcAssessmentOption('yes', 'Yes', 10),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'full_time_ipc',
        prompt:
            'Does the IPC team have at least one full-time IPC professional or equivalent?',
        options: [
          _IpcAssessmentOption('none', 'No IPC professional available', 0),
          _IpcAssessmentOption(
            'part_time',
            'No, only a part-time IPC professional available',
            2.5,
          ),
          _IpcAssessmentOption('gt_250', 'Yes, one per > 250 beds', 5),
          _IpcAssessmentOption('lte_250', 'Yes, one per <= 250 beds', 10),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'dedicated_time',
        prompt:
            'Does the IPC team or focal person have dedicated time for IPC activities?',
        options: _yesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'doctor_nurse_team',
        prompt: 'Does the IPC team include both doctors and nurses?',
        options: _yesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'ipc_committee',
        prompt:
            'Do you have an IPC committee actively supporting the IPC team?',
        options: _yesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'senior_leadership_committee',
        prompt:
            'Is senior facility leadership represented in the IPC committee?',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'senior_clinical_committee',
        prompt: 'Are senior clinical staff represented in the IPC committee?',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'facility_management_committee',
        prompt:
            'Is facility management/WASH/biosafety represented in the IPC committee?',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'ipc_objectives',
        prompt: 'Do you have clearly defined IPC objectives?',
        options: [
          _IpcAssessmentOption('no', 'No', 0),
          _IpcAssessmentOption(
            'objectives_only',
            'Yes, IPC objectives only',
            2.5,
          ),
          _IpcAssessmentOption(
            'objectives_indicators',
            'Yes, IPC objectives and measurable outcome indicators',
            5,
          ),
          _IpcAssessmentOption(
            'objectives_indicators_targets',
            'Yes, IPC objectives, measurable indicators and future targets',
            10,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'allocated_budget',
        prompt:
            'Is there an allocated budget specifically for the IPC programme?',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'leadership_support',
        prompt:
            'Does senior leadership visibly support IPC objectives and indicators?',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'microbiology_support',
        prompt:
            'Does your facility have microbiological laboratory support for routine day-to-day use?',
        options: [
          _IpcAssessmentOption('no', 'No', 0),
          _IpcAssessmentOption(
            'unreliable',
            'Yes, but not delivering results reliably',
            5,
          ),
          _IpcAssessmentOption(
            'reliable',
            'Yes, delivering reliable timely quality results',
            10,
          ),
        ],
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'ipc_guidelines',
    label: 'IPC guidelines',
    prompt: 'Availability, adaptation, approval and use of IPC guidelines.',
    maxScore: 100,
    questions: [
      _IpcAssessmentQuestion(
        key: 'guideline_expertise',
        prompt:
            'Does your facility have IPC/infectious disease expertise for developing or adapting guidelines?',
        options: _yesNo7_5,
      ),
      _IpcAssessmentQuestion(
        key: 'standard_precautions',
        prompt: 'Guideline available: Standard precautions',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'hand_hygiene_guideline',
        prompt: 'Guideline available: Hand hygiene',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'transmission_precautions',
        prompt: 'Guideline available: Transmission-based precautions',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'outbreak_guideline',
        prompt: 'Guideline available: Outbreak management and preparedness',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'ssi_guideline',
        prompt: 'Guideline available: Prevention of surgical site infection',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'vascular_bsi_guideline',
        prompt:
            'Guideline available: Prevention of vascular catheter-associated bloodstream infections',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'hap_guideline',
        prompt:
            'Guideline available: Prevention of hospital-acquired pneumonia',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'cauti_guideline',
        prompt:
            'Guideline available: Prevention of catheter-associated urinary tract infections',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'mdro_guideline',
        prompt:
            'Guideline available: Prevention of transmission of multidrug-resistant pathogens',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'disinfection_sterilization_guideline',
        prompt: 'Guideline available: Disinfection and sterilization',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'hcw_safety_guideline',
        prompt: 'Guideline available: Health care worker protection and safety',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'injection_safety_guideline',
        prompt: 'Guideline available: Injection safety',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'waste_guideline',
        prompt: 'Guideline available: Waste management',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'antibiotic_stewardship_guideline',
        prompt: 'Guideline available: Antibiotic stewardship',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'guidelines_consistent',
        prompt:
            'Are facility guidelines consistent with national/international guidelines?',
        options: _yesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'local_adaptation',
        prompt:
            'Is guideline implementation adapted to local needs/resources while maintaining key IPC standards?',
        options: _yesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'frontline_involvement',
        prompt:
            'Are frontline health care workers involved in planning and executing guideline implementation?',
        options: _yesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'stakeholder_involvement',
        prompt:
            'Are relevant stakeholders involved in guideline development/adaptation?',
        options: _yesNo7_5,
      ),
      _IpcAssessmentQuestion(
        key: 'guideline_training',
        prompt:
            'Do health care workers receive training on new or updated IPC guidelines?',
        options: _yesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'guideline_monitoring',
        prompt:
            'Do you regularly monitor implementation of at least some IPC guidelines?',
        options: _yesNo10,
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'ipc_education_training',
    label: 'IPC education and training',
    prompt: 'IPC training for clinical, non-clinical and new staff.',
    maxScore: 100,
    questions: [
      _IpcAssessmentQuestion(
        key: 'ipc_trainers',
        prompt:
            'Are there IPC/infectious disease personnel to lead IPC training?',
        options: _yesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'non_ipc_trainers',
        prompt:
            'Are additional non-IPC personnel skilled to serve as trainers/mentors?',
        options: _yesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'hcw_training_frequency',
        prompt: 'How frequently do health care workers receive IPC training?',
        options: [
          _IpcAssessmentOption('never', 'Never or rarely', 0),
          _IpcAssessmentOption(
            'orientation_only',
            'New employee orientation only',
            5,
          ),
          _IpcAssessmentOption(
            'annual_not_mandatory',
            'Orientation and annual IPC training offered but not mandatory',
            10,
          ),
          _IpcAssessmentOption(
            'annual_mandatory',
            'Orientation and annual mandatory IPC training for all health care workers',
            15,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'cleaners_training_frequency',
        prompt:
            'How frequently do cleaners and other patient-care personnel receive IPC training?',
        options: [
          _IpcAssessmentOption('never', 'Never or rarely', 0),
          _IpcAssessmentOption(
            'orientation_only',
            'New employee orientation only',
            5,
          ),
          _IpcAssessmentOption(
            'annual_not_mandatory',
            'Orientation and annual training offered but not mandatory',
            10,
          ),
          _IpcAssessmentOption(
            'annual_mandatory',
            'Orientation and annual mandatory training for other personnel',
            15,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'admin_training',
        prompt:
            'Does administrative and managerial staff receive general IPC training?',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'training_method',
        prompt: 'How are health care workers and other personnel trained?',
        options: [
          _IpcAssessmentOption('none', 'No training available', 0),
          _IpcAssessmentOption(
            'written_or_oral',
            'Written information/oral instruction/e-learning only',
            5,
          ),
          _IpcAssessmentOption(
            'interactive',
            'Includes interactive sessions such as simulation or bedside training',
            10,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'training_evaluation',
        prompt: 'Are there periodic evaluations of training effectiveness?',
        options: [
          _IpcAssessmentOption('no', 'No', 0),
          _IpcAssessmentOption('irregular', 'Yes, but not regularly', 5),
          _IpcAssessmentOption(
            'regular',
            'Yes, regularly at least annually',
            10,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'integrated_training',
        prompt:
            'Is IPC training integrated in clinical practice/training of other specialties?',
        options: [
          _IpcAssessmentOption('no', 'No', 0),
          _IpcAssessmentOption('some', 'Yes, in some disciplines', 5),
          _IpcAssessmentOption('all', 'Yes, in all disciplines', 10),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'patient_family_training',
        prompt:
            'Is specific IPC training provided for patients/family members where relevant?',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'ipc_staff_development',
        prompt: 'Is ongoing development/education offered for IPC staff?',
        options: _yesNo10,
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'hai_surveillance',
    label: 'HAI surveillance',
    prompt: 'HAI definitions, surveillance methods, feedback and reporting.',
    maxScore: 100,
    questions: [
      _IpcAssessmentQuestion(
        key: 'defined_surveillance',
        prompt: 'HAI surveillance is a defined IPC programme component',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'surveillance_personnel',
        prompt: 'Personnel are responsible for surveillance activities',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'surveillance_training',
        prompt:
            'Surveillance personnel are trained in epidemiology, surveillance and IPC',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'it_support',
        prompt: 'Informatics/IT support is available for surveillance',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'prioritization',
        prompt:
            'A prioritization exercise determines HAIs targeted for surveillance',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'ssi_surveillance',
        prompt: 'Surveillance conducted for surgical site infections',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'device_surveillance',
        prompt: 'Surveillance conducted for device-associated infections',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'clinical_surveillance',
        prompt: 'Surveillance conducted for clinically-defined infections',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'mdro_surveillance',
        prompt: 'Surveillance conducted for MDRO colonization/infections',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'epidemic_surveillance',
        prompt:
            'Surveillance conducted for local priority epidemic-prone infections',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'vulnerable_surveillance',
        prompt: 'Surveillance conducted for vulnerable populations',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'hcw_surveillance',
        prompt:
            'Surveillance conducted for infections affecting health care workers',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'priority_review',
        prompt: 'Surveillance priorities are regularly evaluated',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'case_definitions',
        prompt:
            'Reliable surveillance case definitions with numerator and denominator are used',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'standard_methods',
        prompt: 'Standardized data collection methods are used',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'data_quality',
        prompt: 'Processes regularly review surveillance data quality',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'lab_capacity',
        prompt: 'Microbiology/laboratory capacity supports surveillance',
        options: [
          _IpcAssessmentOption('no', 'No', 0),
          _IpcAssessmentOption(
            'gram_only',
            'Can differentiate Gram-positive/negative but cannot identify pathogens',
            2.5,
          ),
          _IpcAssessmentOption(
            'pathogens',
            'Can reliably identify pathogens in a timely manner',
            5,
          ),
          _IpcAssessmentOption(
            'pathogens_amr',
            'Can identify pathogens and antimicrobial resistance patterns timely',
            10,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'unit_plans',
        prompt: 'Surveillance data are used for tailored IPC improvement plans',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'amr_analysis',
        prompt: 'Antimicrobial resistance is analysed regularly',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'feedback_frontline',
        prompt: 'Surveillance feedback to frontline health care workers',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'feedback_clinical_leaders',
        prompt: 'Surveillance feedback to clinical leaders/heads of department',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'feedback_ipc_committee',
        prompt: 'Surveillance feedback to IPC committee',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'feedback_management',
        prompt:
            'Surveillance feedback to non-clinical management/administration',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'feedback_method',
        prompt: 'How is up-to-date surveillance information fed back?',
        options: [
          _IpcAssessmentOption('none', 'No feedback', 0),
          _IpcAssessmentOption(
            'written_or_oral',
            'Written/oral information only',
            2.5,
          ),
          _IpcAssessmentOption(
            'interactive',
            'Presentation and interactive problem-oriented solution finding',
            7.5,
          ),
        ],
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'multimodal_strategies',
    label: 'Multimodal strategies',
    prompt:
        'System change, training, monitoring, reminders and safety culture.',
    maxScore: 100,
    questions: [
      _IpcAssessmentQuestion(
        key: 'use_multimodal',
        prompt:
            'Do you use multimodal strategies to implement IPC interventions?',
        options: _yesNo15,
      ),
      _IpcAssessmentQuestion(
        key: 'system_change',
        prompt: 'Multimodal element: system change',
        options: [
          _IpcAssessmentOption('not_included', 'Element not included', 0),
          _IpcAssessmentOption(
            'infrastructure_supplies',
            'Infrastructure and continuous supplies are ensured',
            5,
          ),
          _IpcAssessmentOption(
            'ergonomics_accessibility',
            'Infrastructure/supplies plus ergonomics and accessibility addressed',
            10,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'education_training',
        prompt: 'Multimodal element: education and training',
        options: [
          _IpcAssessmentOption('not_included', 'Element not included', 0),
          _IpcAssessmentOption(
            'basic',
            'Written/oral instruction and/or e-learning only',
            5,
          ),
          _IpcAssessmentOption(
            'interactive',
            'Additional interactive training such as simulation or bedside training',
            10,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'monitoring_feedback',
        prompt: 'Multimodal element: monitoring and feedback',
        options: [
          _IpcAssessmentOption('not_included', 'Element not included', 0),
          _IpcAssessmentOption(
            'monitoring',
            'Monitoring compliance with process or outcome indicators',
            5,
          ),
          _IpcAssessmentOption(
            'feedback',
            'Monitoring plus timely feedback to health care workers/key players',
            10,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'communications_reminders',
        prompt: 'Multimodal element: communications and reminders',
        options: [
          _IpcAssessmentOption('not_included', 'Element not included', 0),
          _IpcAssessmentOption(
            'reminders',
            'Reminders, posters or advocacy tools used',
            5,
          ),
          _IpcAssessmentOption(
            'team_communication',
            'Additional methods improve team communication across units/disciplines',
            10,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'safety_climate',
        prompt: 'Multimodal element: safety climate and culture change',
        options: [
          _IpcAssessmentOption('not_included', 'Element not included', 0),
          _IpcAssessmentOption(
            'visible_support',
            'Managers/leaders show visible support',
            5,
          ),
          _IpcAssessmentOption(
            'adaptive_teamwork',
            'Visible support plus adaptive/teamwork culture-change approaches',
            10,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'multidisciplinary_team',
        prompt:
            'Is a multidisciplinary team used to implement IPC multimodal strategies?',
        options: _yesNo15,
      ),
      _IpcAssessmentQuestion(
        key: 'quality_patient_safety_link',
        prompt:
            'Do you regularly link with quality improvement and patient safety colleagues?',
        options: _yesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'bundles_checklists',
        prompt: 'Do these strategies include bundles or checklists?',
        options: _yesNo10,
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'monitoring_audit_feedback',
    label: 'Monitoring, audit and feedback',
    prompt: 'IPC indicators, regular audits, feedback and quality improvement.',
    maxScore: 100,
    questions: [
      _IpcAssessmentQuestion(
        key: 'trained_auditors',
        prompt: 'Trained staff are responsible for IPC monitoring and audit',
        options: _yesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'monitoring_plan',
        prompt: 'Monitoring plan has targets, tools and defined indicators',
        options: _yesNo7_5,
      ),
      _IpcAssessmentQuestion(
        key: 'hh_compliance_monitoring',
        prompt: 'Process monitored: hand hygiene compliance',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'catheter_monitoring',
        prompt: 'Process monitored: intravascular catheter insertion/care',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'wound_monitoring',
        prompt: 'Process monitored: wound dressing change',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'isolation_monitoring',
        prompt:
            'Process monitored: transmission-based precautions/isolation for MDRO',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'cleaning_monitoring',
        prompt: 'Process monitored: ward environmental cleaning',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'sterilization_monitoring',
        prompt: 'Process monitored: disinfection and sterilization',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'abhr_soap_monitoring',
        prompt: 'Process monitored: ABHR or soap consumption',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'antimicrobial_monitoring',
        prompt: 'Process monitored: antimicrobial consumption/usage',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'waste_monitoring',
        prompt: 'Process monitored: waste management',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'hhsaf_frequency',
        prompt: 'How frequently is the WHO HHSAF survey undertaken?',
        options: [
          _IpcAssessmentOption('never', 'Never', 0),
          _IpcAssessmentOption(
            'periodic',
            'Periodically, but no regular schedule',
            2.5,
          ),
          _IpcAssessmentOption('annual', 'At least annually', 5),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'report_ipc_team',
        prompt: 'Audit reporting: within the IPC team',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'report_department_leaders',
        prompt: 'Audit reporting: department leaders/managers in audited areas',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'report_frontline',
        prompt: 'Audit reporting: frontline health care workers',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'report_committee',
        prompt: 'Audit reporting: IPC committee/quality committee',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'report_management',
        prompt: 'Audit reporting: hospital management/senior administration',
        options: _yesNo2_5,
      ),
      _IpcAssessmentQuestion(
        key: 'regular_reporting',
        prompt: 'Monitoring data are reported regularly at least annually',
        options: _yesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'blame_free_culture',
        prompt:
            'Monitoring and feedback occur in a blame-free improvement culture',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'safety_culture_assessment',
        prompt: 'Safety cultural factors are assessed using a survey/tool',
        options: _yesNo5,
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'workload_staffing_bed_occupancy',
    label: 'Workload, staffing and bed occupancy',
    prompt:
        'Staffing levels, bed spacing, overcrowding and occupancy controls.',
    maxScore: 100,
    questions: [
      _IpcAssessmentQuestion(
        key: 'staffing_assessment',
        prompt: 'Staffing and workload are assessed against patient care needs',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'staff_patient_ratio',
        prompt: 'Agreed health care worker to patient ratio is maintained',
        options: [
          _IpcAssessmentOption('no', 'No', 0),
          _IpcAssessmentOption(
            'lt_50',
            'Yes, for staff in less than 50% of units',
            5,
          ),
          _IpcAssessmentOption(
            'gt_50',
            'Yes, for staff in more than 50% of units',
            10,
          ),
          _IpcAssessmentOption(
            'all',
            'Yes, for all health care workers in the facility',
            15,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'staffing_response',
        prompt:
            'System acts on staffing needs assessment when staffing is too low',
        options: _yesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'ward_design_capacity',
        prompt: 'Ward design follows international standards for bed capacity',
        options: [
          _IpcAssessmentOption('no', 'No', 0),
          _IpcAssessmentOption(
            'some',
            'Yes, but only in certain departments',
            5,
          ),
          _IpcAssessmentOption('all', 'Yes, for all departments', 15),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'one_patient_per_bed',
        prompt: 'Bed occupancy is kept to one patient per bed',
        options: [
          _IpcAssessmentOption('no', 'No', 0),
          _IpcAssessmentOption(
            'some',
            'Yes, but only in certain departments',
            5,
          ),
          _IpcAssessmentOption('all', 'Yes, for all units', 15),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'corridor_beds',
        prompt: 'Patients are placed in beds in corridors/outside rooms',
        options: [
          _IpcAssessmentOption(
            'frequent',
            'Yes, more frequently than twice a week',
            0,
          ),
          _IpcAssessmentOption(
            'rare',
            'Yes, less frequently than twice a week',
            5,
          ),
          _IpcAssessmentOption('no', 'No', 15),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'bed_spacing',
        prompt: 'Adequate spacing of > 1 meter between patient beds is ensured',
        options: [
          _IpcAssessmentOption('no', 'No', 0),
          _IpcAssessmentOption(
            'some',
            'Yes, but only in certain departments',
            5,
          ),
          _IpcAssessmentOption('all', 'Yes, for all departments', 15),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'bed_capacity_response',
        prompt:
            'System assesses and responds when adequate bed capacity is exceeded',
        options: [
          _IpcAssessmentOption('no', 'No', 0),
          _IpcAssessmentOption(
            'hod',
            'Yes, responsibility of head of department',
            5,
          ),
          _IpcAssessmentOption(
            'management',
            'Yes, responsibility of hospital administration/management',
            10,
          ),
        ],
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'built_environment_equipment',
    label: 'Built environment, materials and equipment',
    prompt:
        'Infrastructure, supplies, water, sanitation, hygiene and equipment.',
    maxScore: 100,
    questions: [
      _IpcAssessmentQuestion(
        key: 'water_sanitation',
        prompt:
            'Water services are available at all times and sufficient for all uses',
        options: [
          _IpcAssessmentOption(
            'lt_5_days',
            'No, available on average < 5 days per week',
            0,
          ),
          _IpcAssessmentOption(
            'limited',
            'Yes, >= 5 days/week or daily but insufficient quantity',
            2.5,
          ),
          _IpcAssessmentOption(
            'sufficient',
            'Yes, every day and sufficient quantity',
            7.5,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'drinking_water',
        prompt:
            'Safe drinking water station is accessible for staff, patients and families',
        options: [
          _IpcAssessmentOption('none', 'No, not available', 0),
          _IpcAssessmentOption(
            'limited',
            'Sometimes/only some places/not all users',
            2.5,
          ),
          _IpcAssessmentOption(
            'all',
            'Yes, at all times and all wards/groups',
            7.5,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'hand_hygiene_stations',
        prompt:
            'Functioning hand hygiene stations are available at all points of care',
        options: [
          _IpcAssessmentOption('none', 'No, not present', 0),
          _IpcAssessmentOption(
            'unreliable',
            'Present, but supplies not reliably available',
            2.5,
          ),
          _IpcAssessmentOption(
            'reliable',
            'Yes, with reliably available supplies',
            7.5,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'toilets',
        prompt:
            'Required number of functional toilets/improved latrines is available',
        options: [
          _IpcAssessmentOption(
            'insufficient',
            'Less than required number available/functioning',
            0,
          ),
          _IpcAssessmentOption(
            'not_all_functioning',
            'Sufficient number present but not all functioning',
            2.5,
          ),
          _IpcAssessmentOption(
            'sufficient',
            'Sufficient number present and functioning',
            7.5,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'power_supply',
        prompt:
            'Sufficient energy/power supply is available day and night for all uses',
        options: [
          _IpcAssessmentOption('no', 'No', 0),
          _IpcAssessmentOption(
            'sometimes',
            'Yes, sometimes or only in some areas',
            2.5,
          ),
          _IpcAssessmentOption(
            'always',
            'Yes, always and in all mentioned areas',
            5,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'ventilation',
        prompt:
            'Functioning environmental ventilation is available in patient care areas',
        options: _yesNo5,
      ),
      _IpcAssessmentQuestion(
        key: 'cleaning_record',
        prompt:
            'Cleaning records for floors/horizontal surfaces are completed daily',
        options: [
          _IpcAssessmentOption('none', 'No cleaning record', 0),
          _IpcAssessmentOption(
            'incomplete',
            'Record exists but not completed/signed daily or outdated',
            2.5,
          ),
          _IpcAssessmentOption('daily', 'Record completed and signed daily', 5),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'cleaning_materials',
        prompt:
            'Appropriate and well-maintained cleaning materials are available',
        options: [
          _IpcAssessmentOption('none', 'No materials available', 0),
          _IpcAssessmentOption(
            'poor',
            'Available but not well maintained',
            2.5,
          ),
          _IpcAssessmentOption(
            'maintained',
            'Available and well maintained',
            5,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'isolation_rooms',
        prompt:
            'Single rooms or cohorting rooms are available for similar pathogens',
        options: [
          _IpcAssessmentOption('no', 'No', 0),
          _IpcAssessmentOption(
            'cohorting',
            'No single rooms but cohorting rooms available',
            2.5,
          ),
          _IpcAssessmentOption(
            'single_rooms',
            'Yes, single rooms are available',
            7.5,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'ppe_supplies',
        prompt: 'PPE is available at all times and sufficient for all uses',
        options: [
          _IpcAssessmentOption('no', 'No', 0),
          _IpcAssessmentOption(
            'limited',
            'Yes, but not continuously sufficient',
            2.5,
          ),
          _IpcAssessmentOption(
            'sufficient',
            'Yes, continuously sufficient',
            7.5,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'waste_bins',
        prompt:
            'Functional waste containers for general, infectious and sharps waste are near generation points',
        options: [
          _IpcAssessmentOption(
            'none',
            'No bins or separate sharps disposal',
            0,
          ),
          _IpcAssessmentOption(
            'partial',
            'Separate bins present but incomplete/overfull/not at all points',
            2.5,
          ),
          _IpcAssessmentOption('yes', 'Yes', 5),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'general_waste_disposal',
        prompt:
            'Functional disposal method exists for non-hazardous/general waste',
        options: [
          _IpcAssessmentOption('no', 'No pit or other disposal method used', 0),
          _IpcAssessmentOption(
            'partial',
            'Pit/dump/pick-up present but insufficient/irregular',
            2.5,
          ),
          _IpcAssessmentOption('yes', 'Yes', 5),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'infectious_waste_treatment',
        prompt:
            'Functional infectious/sharp waste treatment technology is present',
        options: [
          _IpcAssessmentOption('none', 'No, none present', 0),
          _IpcAssessmentOption(
            'not_functional',
            'Present, but not functional',
            1,
          ),
          _IpcAssessmentOption('yes', 'Yes', 5),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'wastewater_treatment',
        prompt:
            'Wastewater treatment system is present and functioning reliably',
        options: [
          _IpcAssessmentOption('no', 'No, not present', 0),
          _IpcAssessmentOption(
            'unreliable',
            'Yes, but not functioning reliably',
            2.5,
          ),
          _IpcAssessmentOption('yes', 'Yes and functioning reliably', 5),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'decontamination_area',
        prompt:
            'Dedicated decontamination/sterile supply service is present and reliable',
        options: [
          _IpcAssessmentOption('no', 'No, not present', 0),
          _IpcAssessmentOption(
            'unreliable',
            'Yes, but not functioning reliably',
            2.5,
          ),
          _IpcAssessmentOption('yes', 'Yes and functioning reliably', 5),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'sterile_equipment',
        prompt: 'Sterile and disinfected equipment is reliably ready for use',
        options: [
          _IpcAssessmentOption(
            'lt_5_days',
            'No, available on average < 5 days/week',
            0,
          ),
          _IpcAssessmentOption(
            'limited',
            'Yes, >= 5 days/week or daily but insufficient quantity',
            2.5,
          ),
          _IpcAssessmentOption(
            'sufficient',
            'Yes, every day and sufficient quantity',
            5,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'disposable_items',
        prompt: 'Disposable items are available when necessary',
        options: [
          _IpcAssessmentOption('no', 'No, not available', 0),
          _IpcAssessmentOption(
            'sometimes',
            'Yes, but only sometimes available',
            2.5,
          ),
          _IpcAssessmentOption('continuous', 'Yes, continuously available', 5),
        ],
      ),
    ],
  ),
];

const _washFitAssessmentSections = [
  _IpcAssessmentSection(
    key: 'water',
    label: 'Water',
    prompt: 'Availability, quality, storage, access points and continuity.',
    maxScore: 2,
    questions: [
      _IpcAssessmentQuestion(
        key: 'water_services',
        prompt:
            'Water is safe, available, accessible and reliable for care delivery',
        options: _washFitOptions,
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'sanitation',
    label: 'Sanitation',
    prompt:
        'Toilets, accessibility, cleanliness, wastewater and sludge safety.',
    maxScore: 2,
    questions: [
      _IpcAssessmentQuestion(
        key: 'sanitation_services',
        prompt:
            'Sanitation facilities are safe, clean, accessible and functional',
        options: _washFitOptions,
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'health_care_waste',
    label: 'Health care waste management',
    prompt: 'Segregation, sharps, storage, transport, treatment and disposal.',
    maxScore: 2,
    questions: [
      _IpcAssessmentQuestion(
        key: 'waste_services',
        prompt:
            'Health care waste is segregated, handled, treated and disposed safely',
        options: _washFitOptions,
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'hand_hygiene',
    label: 'Hand hygiene',
    prompt:
        'Functional hand hygiene stations, supplies and point-of-care access.',
    maxScore: 2,
    questions: [
      _IpcAssessmentQuestion(
        key: 'hand_hygiene_services',
        prompt:
            'Hand hygiene facilities and supplies are available at points of care',
        options: _washFitOptions,
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'environmental_cleaning',
    label: 'Environmental cleaning and disinfection',
    prompt:
        'Cleaning schedules, products, staff training and high-touch surfaces.',
    maxScore: 2,
    questions: [
      _IpcAssessmentQuestion(
        key: 'cleaning_services',
        prompt:
            'Environmental cleaning is staffed, scheduled, supplied and monitored',
        options: _washFitOptions,
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'energy_environment',
    label: 'Energy and environment',
    prompt:
        'Reliable power, ventilation, lighting and climate-resilient services.',
    maxScore: 2,
    questions: [
      _IpcAssessmentQuestion(
        key: 'energy_services',
        prompt:
            'Energy, ventilation and environmental conditions support safe care',
        options: _washFitOptions,
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'management_workforce',
    label: 'Management and workforce',
    prompt:
        'Improvement team, risk prioritization, budgets and action follow-up.',
    maxScore: 2,
    questions: [
      _IpcAssessmentQuestion(
        key: 'management_services',
        prompt:
            'WASH FIT team prioritizes risks and follows an improvement plan',
        options: _washFitOptions,
      ),
    ],
  ),
];

const _hhsafAssessmentSections = [
  _IpcAssessmentSection(
    key: 'system_change',
    label: 'System change',
    prompt:
        'Infrastructure and supplies required for hand hygiene at point of care.',
    maxScore: 100,
    questions: [
      _IpcAssessmentQuestion(
        key: 'abhr_availability',
        prompt: 'Alcohol-based handrub availability at point of care',
        options: [
          _IpcAssessmentOption('none', 'Not available', 0),
          _IpcAssessmentOption(
            'unproven',
            'Available, but efficacy and tolerability have not been proven',
            0,
          ),
          _IpcAssessmentOption(
            'some',
            'Available only in some wards or in discontinuous supply',
            5,
          ),
          _IpcAssessmentOption(
            'facility_wide',
            'Available facility-wide with continuous supply',
            10,
          ),
          _IpcAssessmentOption(
            'majority_poc',
            'Available facility-wide with continuous supply and at point of care in majority of wards',
            30,
          ),
          _IpcAssessmentOption(
            'all_poc',
            'Available facility-wide with continuous supply at each point of care',
            50,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'sink_bed_ratio',
        prompt: 'What is the sink:bed ratio?',
        options: [
          _IpcAssessmentOption('lt_1_10', 'Less than 1:10', 0),
          _IpcAssessmentOption('most_wards', 'At least 1:10 in most wards', 5),
          _IpcAssessmentOption(
            'facility_wide',
            'At least 1:10 facility-wide and 1:1 in isolation rooms and ICUs',
            10,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'running_water',
        prompt: 'Is there a continuous supply of clean, running water?',
        options: _hhsafYesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'soap_each_sink',
        prompt: 'Is soap available at each sink?',
        options: _hhsafYesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'single_use_towels',
        prompt: 'Are single-use towels available at each sink?',
        options: _hhsafYesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'budget_procurement',
        prompt:
            'Is there dedicated/available budget for continuous procurement of hand hygiene products?',
        options: _hhsafYesNo10,
      ),
      _IpcAssessmentQuestion(
        key: 'infrastructure_action_plan',
        prompt:
            'If system-change score is less than 100, is there a realistic action plan to improve infrastructure?',
        options: _hhsafYesNo5,
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'training_education',
    label: 'Training and education',
    prompt: 'Hand hygiene training for all professional categories.',
    maxScore: 100,
    questions: [
      _IpcAssessmentQuestion(
        key: 'training_frequency',
        prompt: 'Frequency and coverage of hand hygiene training',
        options: [
          _IpcAssessmentOption('never', 'Never or rarely', 0),
          _IpcAssessmentOption('once', 'At least once', 10),
          _IpcAssessmentOption('annual', 'Regular annual training', 20),
          _IpcAssessmentOption(
            'mandatory',
            'Mandatory induction and annual training for all staff',
            40,
          ),
        ],
      ),
      _IpcAssessmentQuestion(
        key: 'training_completion',
        prompt: 'System confirms staff complete training',
        options: _hhsafYesNo20,
      ),
      _IpcAssessmentQuestion(
        key: 'who_materials',
        prompt: 'WHO hand hygiene materials or local adaptations are available',
        options: _hhsafYesNo20,
      ),
      _IpcAssessmentQuestion(
        key: 'competency',
        prompt: 'Hand hygiene knowledge and technique are assessed',
        options: _hhsafYesNo20,
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'evaluation_feedback',
    label: 'Evaluation and feedback',
    prompt: 'Monitoring hand hygiene practice and giving feedback.',
    maxScore: 100,
    questions: [
      _IpcAssessmentQuestion(
        key: 'observations',
        prompt:
            'Direct hand hygiene observations are performed with standard methods',
        options: _hhsafYesNo20,
      ),
      _IpcAssessmentQuestion(
        key: 'consumption',
        prompt: 'ABHR or soap consumption is monitored',
        options: _hhsafYesNo20,
      ),
      _IpcAssessmentQuestion(
        key: 'feedback',
        prompt: 'Results are fed back to wards, leaders and staff',
        options: _hhsafYesNo20,
      ),
      _IpcAssessmentQuestion(
        key: 'improvement_tracking',
        prompt: 'Feedback results are linked to improvement actions',
        options: _hhsafYesNo20,
      ),
      _IpcAssessmentQuestion(
        key: 'hh_saf_repeat',
        prompt: 'HHSAF is repeated to monitor progress over time',
        options: _hhsafYesNo20,
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'reminders_workplace',
    label: 'Reminders in the workplace',
    prompt: 'Posters, prompts and communication materials for hand hygiene.',
    maxScore: 100,
    questions: [
      _IpcAssessmentQuestion(
        key: 'moments_posters',
        prompt: 'Five Moments for Hand Hygiene posters are displayed',
        options: _hhsafYesNo20,
      ),
      _IpcAssessmentQuestion(
        key: 'technique_posters',
        prompt: 'Handrub and handwash technique posters are displayed',
        options: _hhsafYesNo20,
      ),
      _IpcAssessmentQuestion(
        key: 'poster_audit',
        prompt: 'Posters are audited and replaced when damaged',
        options: _hhsafYesNo20,
      ),
      _IpcAssessmentQuestion(
        key: 'patient_materials',
        prompt:
            'Hand hygiene information is available for patients and visitors',
        options: _hhsafYesNo20,
      ),
      _IpcAssessmentQuestion(
        key: 'campaigns',
        prompt: 'Hand hygiene promotion campaigns are updated regularly',
        options: _hhsafYesNo20,
      ),
    ],
  ),
  _IpcAssessmentSection(
    key: 'institutional_safety_climate',
    label: 'Institutional safety climate',
    prompt: 'Leadership, team structure and safety culture for hand hygiene.',
    maxScore: 100,
    questions: [
      _IpcAssessmentQuestion(
        key: 'hh_team',
        prompt: 'Dedicated hand hygiene team is established and active',
        options: _hhsafYesNo20,
      ),
      _IpcAssessmentQuestion(
        key: 'leadership_commitment',
        prompt: 'Facility leadership visibly supports hand hygiene improvement',
        options: _hhsafYesNo20,
      ),
      _IpcAssessmentQuestion(
        key: 'annual_plan',
        prompt:
            'Annual plan exists for hand hygiene promotion and 5 May activities',
        options: _hhsafYesNo20,
      ),
      _IpcAssessmentQuestion(
        key: 'champions',
        prompt: 'Hand hygiene champions or role models are recognized',
        options: _hhsafYesNo20,
      ),
      _IpcAssessmentQuestion(
        key: 'patient_engagement',
        prompt: 'Patients and families are engaged in hand hygiene improvement',
        options: _hhsafYesNo20,
      ),
    ],
  ),
];

class _IpcAssessmentToolFormScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final String toolType;
  final String? documentId;
  final Map<String, dynamic>? initialData;
  final bool allowFinalEdit;

  const _IpcAssessmentToolFormScreen({
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    required this.toolType,
    this.documentId,
    this.initialData,
    this.allowFinalEdit = false,
  });

  @override
  State<_IpcAssessmentToolFormScreen> createState() =>
      _IpcAssessmentToolFormScreenState();
}

class _IpcAssessmentToolFormScreenState
    extends State<_IpcAssessmentToolFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _departmentController = TextEditingController();
  final _unitController = TextEditingController();
  final _assessorController = TextEditingController();
  final Map<String, String> _answers = {};
  final Map<String, TextEditingController> _observationControllers = {};
  final Map<String, TextEditingController> _actionControllers = {};
  DateTime _assessmentDate = DateTime.now();
  bool _isSubmitting = false;

  bool get _isWashFit => widget.toolType.toLowerCase().contains('wash');
  bool get _isHhsaf => widget.toolType.toLowerCase().contains('hhsaf');
  bool get _isIpcaf => widget.toolType.toLowerCase().contains('ipcaf');
  List<_IpcAssessmentSection> get _sections => _isHhsaf
      ? _hhsafAssessmentSections
      : _isWashFit
      ? _washFitAssessmentSections
      : _ipcafAssessmentSections;
  double get _maxScore =>
      _sections.fold(0, (total, section) => total + section.maxScore);
  double get _totalScore =>
      _sections.fold(0, (total, section) => total + _sectionScore(section));
  double get _percentageScore =>
      _maxScore == 0 ? 0 : (_totalScore / _maxScore) * 100;

  @override
  void initState() {
    super.initState();
    _departmentController.text = '${widget.initialData?['department'] ?? ''}';
    _unitController.text = '${widget.initialData?['unit'] ?? ''}';
    _assessorController.text =
        '${widget.initialData?['assessorName'] ?? widget.staffName}';
    if (widget.initialData?['assessmentDate'] is Timestamp) {
      _assessmentDate = (widget.initialData!['assessmentDate'] as Timestamp)
          .toDate();
    }
    final savedSections = widget.initialData?['assessmentSections'] is Map
        ? Map<String, dynamic>.from(
            widget.initialData!['assessmentSections'] as Map,
          )
        : const <String, dynamic>{};
    for (final section in _sections) {
      final saved = savedSections[section.key] is Map
          ? Map<String, dynamic>.from(savedSections[section.key] as Map)
          : const <String, dynamic>{};
      final savedQuestions = saved['questions'] is Map
          ? Map<String, dynamic>.from(saved['questions'] as Map)
          : const <String, dynamic>{};
      for (final question in section.questions) {
        final questionKey = _questionKey(section, question);
        final savedQuestion = savedQuestions[question.key] is Map
            ? Map<String, dynamic>.from(savedQuestions[question.key] as Map)
            : const <String, dynamic>{};
        final answer = savedQuestion['answerKey'];
        if (answer != null && '$answer'.trim().isNotEmpty) {
          _answers[questionKey] = '$answer';
        }
      }
      _observationControllers[section.key] = TextEditingController(
        text: '${saved['observation'] ?? ''}',
      );
      _actionControllers[section.key] = TextEditingController(
        text: '${saved['action'] ?? ''}',
      );
    }
  }

  @override
  void dispose() {
    _departmentController.dispose();
    _unitController.dispose();
    _assessorController.dispose();
    for (final controller in _observationControllers.values) {
      controller.dispose();
    }
    for (final controller in _actionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _assessmentLevel() {
    final score = _totalScore;
    if (_isIpcaf) {
      if (score >= 601) return 'Advanced';
      if (score >= 401) return 'Intermediate';
      if (score >= 201) return 'Basic';
      return 'Inadequate';
    }
    if (_isHhsaf) {
      if (score >= 376) return 'Advanced';
      if (score >= 251) return 'Intermediate';
      if (score >= 126) return 'Basic';
      return 'Inadequate';
    }
    final percent = _percentageScore;
    if (percent >= 75) return 'Low risk / good progress';
    if (percent >= 50) return 'Medium risk / improvement required';
    return 'High risk / urgent improvement required';
  }

  List<String> _strengths() => _sections
      .where((section) => _sectionPercent(section) >= 75)
      .map((section) => section.label)
      .toList();

  List<String> _priorityGaps() => _sections
      .where((section) => _sectionPercent(section) < 50)
      .map((section) => section.label)
      .toList();

  List<String> _recommendedActions() =>
      _priorityGaps().map((gap) => 'Prioritize improvement for $gap.').toList();

  String _questionKey(
    _IpcAssessmentSection section,
    _IpcAssessmentQuestion question,
  ) => '${section.key}.${question.key}';

  _IpcAssessmentOption? _selectedOption(
    _IpcAssessmentSection section,
    _IpcAssessmentQuestion question,
  ) {
    final selectedKey = _answers[_questionKey(section, question)];
    return question.options
        .where((option) => option.key == selectedKey)
        .firstOrNull;
  }

  double _sectionScore(_IpcAssessmentSection section) {
    final score = section.questions.fold<double>(
      0,
      (total, question) =>
          total + (_selectedOption(section, question)?.score ?? 0),
    );
    return score > section.maxScore ? section.maxScore : score;
  }

  double _sectionPercent(_IpcAssessmentSection section) {
    if (section.maxScore == 0) return 0;
    return (_sectionScore(section) / section.maxScore) * 100;
  }

  Future<void> _save({required bool finalSubmit}) async {
    if (finalSubmit && !_formKey.currentState!.validate()) return;
    final hasAnyEntry =
        _departmentController.text.trim().isNotEmpty ||
        _unitController.text.trim().isNotEmpty ||
        _assessorController.text.trim().isNotEmpty ||
        _answers.isNotEmpty ||
        _observationControllers.values.any(
          (controller) => controller.text.trim().isNotEmpty,
        ) ||
        _actionControllers.values.any(
          (controller) => controller.text.trim().isNotEmpty,
        );
    if (!finalSubmit && !hasAnyEntry) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one assessment detail')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final formId =
          widget.initialData?['formId'] as String? ??
          await SurveillanceFormIdService.nextFormId(
            facilityId: widget.facilityId,
            surveillanceCode: _isHhsaf
                ? 'ipc_assessment_hhsaf'
                : _isWashFit
                ? 'ipc_assessment_washfit'
                : 'ipc_assessment_ipcaf',
          );
      final sections = {
        for (final section in _sections)
          section.key: {
            'label': section.label,
            'prompt': section.prompt,
            'score': _sectionScore(section),
            'maxScore': section.maxScore,
            'percentageScore': double.parse(
              _sectionPercent(section).toStringAsFixed(1),
            ),
            'questions': {
              for (final question in section.questions)
                question.key: {
                  'prompt': question.prompt,
                  'answerKey': _answers[_questionKey(section, question)] ?? '',
                  'answerLabel':
                      _selectedOption(section, question)?.label ?? '',
                  'score': _selectedOption(section, question)?.score ?? 0,
                },
            },
            'observation':
                _observationControllers[section.key]?.text.trim() ?? '',
            'action': _actionControllers[section.key]?.text.trim() ?? '',
          },
      };
      final status = finalSubmit ? 'Final' : 'Draft';
      final data = {
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityName,
        'formId': formId,
        'recordType': 'IPC Assessment Tool',
        'assessmentTool': widget.toolType,
        'assessmentType': widget.toolType,
        'department': _departmentController.text.trim(),
        'unit': _unitController.text.trim(),
        'assessorName': _assessorController.text.trim(),
        'assessmentDate': Timestamp.fromDate(_assessmentDate),
        'submissionStatus': status,
        'submissionState': finalSubmit ? 'final' : 'draft',
        'status': finalSubmit ? 'submitted' : 'pending',
        'isFinal': finalSubmit,
        'dataStatus': widget.initialData?['dataStatus'] ?? 'Raw Data',
        'assessmentSections': sections,
        'totalScore': _totalScore,
        'maxScore': _maxScore,
        'percentageScore': double.parse(_percentageScore.toStringAsFixed(1)),
        'assessmentLevel': _assessmentLevel(),
        'strengths': _strengths(),
        'priorityGaps': _priorityGaps(),
        'recommendedActions': _recommendedActions(),
        'dashboardSource': 'ipc',
        'createdBy': widget.initialData?['createdBy'] ?? widget.staffName,
        'createdById': widget.initialData?['createdById'] ?? widget.staffId,
        'lastUpdatedBy': widget.staffName,
        'lastUpdatedById': widget.staffId,
        'updatedAt': FieldValue.serverTimestamp(),
        'changeHistory': FieldValue.arrayUnion([
          {
            'staffId': widget.staffId,
            'staffName': widget.staffName,
            'action': finalSubmit ? 'final_submit' : 'save_progress',
            'at': Timestamp.now(),
          },
        ]),
        if (finalSubmit) ...{
          'finalizedBy': widget.staffName,
          'finalizedById': widget.staffId,
          'finalizedAt': FieldValue.serverTimestamp(),
        },
      };
      final collection = FirebaseFirestore.instance.collection(
        'ipc_assessments',
      );
      if (widget.documentId == null) {
        await collection.add({
          ...data,
          'reportedDate': FieldValue.serverTimestamp(),
        });
      } else {
        await collection
            .doc(widget.documentId)
            .set(data, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              finalSubmit
                  ? '${widget.toolType} submitted successfully'
                  : '${widget.toolType} progress saved',
            ),
          ),
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickAssessmentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _assessmentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _assessmentDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isFinal = widget.initialData?['submissionStatus'] == 'Final';
    final canSaveProgress = !isFinal;
    final canFinalSubmit = !isFinal || widget.allowFinalEdit;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.documentId == null
              ? widget.toolType
              : 'Update ${widget.toolType}',
        ),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 16),
            _buildBasicDetails(),
            const SizedBox(height: 16),
            ..._sections.map(_buildSectionCard),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSubmitting || !canSaveProgress
                      ? null
                      : () => _save(finalSubmit: false),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save progress'),
                ),
                ElevatedButton.icon(
                  onPressed: _isSubmitting || !canFinalSubmit
                      ? null
                      : () => _save(finalSubmit: true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Final submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assessment details',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _assessorController,
              decoration: const InputDecoration(
                labelText: 'Assessor name',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _departmentController,
              decoration: const InputDecoration(
                labelText: 'Department or service area',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'Unit or ward',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickAssessmentDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(DateFormat('MMM d, y').format(_assessmentDate)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(_IpcAssessmentSection section) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(section.prompt),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Subtotal: ${_sectionScore(section)} / ${section.maxScore} (${_sectionPercent(section).toStringAsFixed(1)}%)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            ...section.questions.map(
              (question) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: _answers[_questionKey(section, question)],
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: question.prompt,
                    border: const OutlineInputBorder(),
                  ),
                  items: question.options
                      .map(
                        (option) => DropdownMenuItem(
                          value: option.key,
                          child: Text(
                            '${option.label} (${option.score} pts)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(
                      () => _answers[_questionKey(section, question)] = value,
                    );
                  },
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _observationControllers[section.key],
              decoration: const InputDecoration(
                labelText: 'Key observations',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _actionControllers[section.key],
              decoration: const InputDecoration(
                labelText: 'Recommended action',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final strengths = _strengths();
    final gaps = _priorityGaps();
    final actions = _recommendedActions();
    return Card(
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.toolType} summary',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Score: $_totalScore / $_maxScore (${_percentageScore.toStringAsFixed(1)}%)',
            ),
            Text('Level: ${_assessmentLevel()}'),
            Text('Interpretation: ${_scoreBandDescription()}'),
            const SizedBox(height: 8),
            ..._sections.map(
              (section) => Text(
                '${section.label}: ${_sectionScore(section)} / ${section.maxScore}',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Strengths: ${strengths.isEmpty ? 'None yet' : strengths.join(', ')}',
            ),
            Text(
              'Priority gaps: ${gaps.isEmpty ? 'None yet' : gaps.join(', ')}',
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Suggested actions: ${actions.join(' ')}'),
            ],
          ],
        ),
      ),
    );
  }

  String _scoreBandDescription() {
    if (_isIpcaf) {
      return 'IPCAF bands: 0-200 inadequate, 201-400 basic, 401-600 intermediate, 601-800 advanced.';
    }
    if (_isHhsaf) {
      return 'HHSAF bands: 0-125 inadequate, 126-250 basic, 251-375 intermediate, 376-500 advanced.';
    }
    return 'WASH FIT result is based on total percentage across assessed domains.';
  }
}

// ===================== WARD DENOMINATOR FORM =====================

class _WardDenominatorFormScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final String? documentId;
  final Map<String, dynamic>? initialData;
  final bool allowFinalEdit;

  const _WardDenominatorFormScreen({
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    this.documentId,
    this.initialData,
    this.allowFinalEdit = false,
  });

  @override
  State<_WardDenominatorFormScreen> createState() =>
      _WardDenominatorFormScreenState();
}

Future<Map<String, dynamic>?> _loadLatestBuiltInIpcTemplateDataFromServer({
  required String facilityKey,
  required String facilityId,
  required String facilityName,
  required String templateId,
}) async {
  final collection = FirebaseFirestore.instance.collection(
    'ipc_form_templates',
  );
  final candidates = <Map<String, dynamic>>[];

  final deterministicIds = <String>{
    if (_ipcFacilityKey(facilityId).isNotEmpty)
      '${_ipcFacilityKey(facilityId)}_$templateId',
    '${facilityKey}_$templateId',
  };
  for (final documentId in deterministicIds) {
    try {
      final deterministicSnapshot = await collection
          .doc(documentId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 12));
      final deterministicData = deterministicSnapshot.data();
      if (_isUsableBuiltInIpcTemplate(deterministicData, templateId)) {
        candidates.add(
          _templateDataWithDocumentId(
            deterministicData!,
            deterministicSnapshot.id,
          ),
        );
      }
    } catch (_) {
      // Continue with the next deterministic lookup or broader query below.
    }
  }

  try {
    final querySnapshot = await collection
        .where('templateId', isEqualTo: templateId)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      if (_isSameIpcTemplateFacility(data, facilityId, facilityName) &&
          _isUsableBuiltInIpcTemplate(data, templateId)) {
        candidates.add(_templateDataWithDocumentId(data, doc.id));
      }
    }
  } catch (_) {
    // Staff runtime forms require saved Firestore templates.
  }
  if (candidates.isEmpty) {
    return null;
  }
  candidates.sort(_compareBuiltInIpcTemplateFreshness);
  return candidates.last;
}

Map<String, dynamic> _templateDataWithDocumentId(
  Map<String, dynamic> data,
  String documentId,
) {
  return {...data, '_documentId': documentId};
}

bool _isSameIpcTemplateFacility(
  Map<String, dynamic> data,
  String facilityId,
  String facilityName,
) {
  final savedFacilityId = '${data['facilityId'] ?? ''}'.trim();
  if (facilityId.trim().isNotEmpty && savedFacilityId == facilityId.trim()) {
    return true;
  }
  final savedFacilityName = '${data['facilityName'] ?? ''}'.trim();
  return savedFacilityName == facilityName.trim() ||
      _ipcFacilityKey(savedFacilityName) == _ipcFacilityKey(facilityName);
}

String _ipcFacilityKey(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

bool _isUsableBuiltInIpcTemplate(
  Map<String, dynamic>? data,
  String templateId,
) {
  if (data == null || data['templateId'] != templateId) return false;
  if (data['isActive'] == false) return false;
  final questions = data['questions'];
  return questions is List && questions.isNotEmpty;
}

int _compareBuiltInIpcTemplateFreshness(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final timeComparison = _templateMillis(a).compareTo(_templateMillis(b));
  if (timeComparison != 0) return timeComparison;
  return '${a['_documentId'] ?? ''}'.compareTo('${b['_documentId'] ?? ''}');
}

int _templateMillis(Map<String, dynamic> data) {
  final updatedAt = data['updatedAt'];
  if (updatedAt is Timestamp) return updatedAt.millisecondsSinceEpoch;
  final importedAt = data['importedAt'];
  if (importedAt is Timestamp) return importedAt.millisecondsSinceEpoch;
  final createdAt = data['createdAt'];
  if (createdAt is Timestamp) return createdAt.millisecondsSinceEpoch;
  return 0;
}

class _IpcServerTemplateUnavailable extends StatelessWidget {
  final String title;
  final String message;

  const _IpcServerTemplateUnavailable({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_late_outlined,
              size: 48,
              color: Colors.orange.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _WardDenominatorFormScreenState
    extends State<_WardDenominatorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _controllers = {};
  List<WardDenominatorField>? _facilityWardDenominatorFields;
  bool _isLoadingWardDenominatorTemplate = true;
  String? _wardDenominatorTemplateError;
  DateTime? _date;
  bool _isSubmitting = false;

  List<WardDenominatorField> get _wardFields =>
      _facilityWardDenominatorFields ?? const <WardDenominatorField>[];

  @override
  void initState() {
    super.initState();
    _loadFacilityWardDenominatorTemplate();
    final initialResponses =
        widget.initialData?['wardDenominatorResponses'] is Map
        ? Map<String, dynamic>.from(
            widget.initialData!['wardDenominatorResponses'] as Map,
          )
        : const <String, dynamic>{};
    _answers.addAll(initialResponses);
    final initialDate = initialResponses['Date'];
    if (initialDate is Timestamp) {
      _date = initialDate.toDate();
    } else if (widget.initialData?['denominatorDate'] is Timestamp) {
      _date = (widget.initialData!['denominatorDate'] as Timestamp).toDate();
    }
    for (final field in _wardFields.where((field) => field.type == 'integer')) {
      _controllers[field.name] = TextEditingController(
        text: '${_answers[field.name] ?? ''}',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFacilityWardDenominatorTemplate() async {
    try {
      final facilityKey = widget.facilityName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final data = await _loadLatestBuiltInIpcTemplateDataFromServer(
        facilityKey: facilityKey,
        facilityId: widget.facilityId,
        facilityName: widget.facilityName,
        templateId: 'ward_denominator',
      );
      final questions = data?['questions'];
      if (questions is! List || questions.isEmpty) return;
      final mapped = questions
          .whereType<Map>()
          .map(
            (item) => _wardFieldFromTemplate(Map<String, dynamic>.from(item)),
          )
          .whereType<WardDenominatorField>()
          .toList();
      if (mapped.isEmpty) {
        _wardDenominatorTemplateError =
            'Ward Denominator template has no usable questions.';
        return;
      }
      setState(() {
        _facilityWardDenominatorFields = mapped;
        _wardDenominatorTemplateError = null;
        for (final field in _wardFields.where(
          (field) => field.type == 'integer',
        )) {
          _controllers.putIfAbsent(
            field.name,
            () => TextEditingController(text: '${_answers[field.name] ?? ''}'),
          );
        }
      });
    } catch (error) {
      _wardDenominatorTemplateError =
          'Unable to load Ward Denominator template. Please ask the facility admin to save the template again.';
    } finally {
      if (mounted) {
        setState(() => _isLoadingWardDenominatorTemplate = false);
      }
    }
  }

  WardDenominatorField? _wardFieldFromTemplate(Map<String, dynamic> question) {
    final stableName = '${question['stableName'] ?? question['id'] ?? ''}';
    final label = '${question['label'] ?? ''}'.trim();
    if (stableName.trim().isEmpty || label.isEmpty) return null;
    final type = _wardTypeFromTemplate('${question['type'] ?? ''}');
    final optionValues = question['optionValues'] is Map
        ? Map<String, dynamic>.from(question['optionValues'] as Map)
        : const <String, dynamic>{};
    final options = (question['options'] as List<dynamic>? ?? [])
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .map(
          (item) => WardDenominatorChoice(
            '${optionValues[item] ?? _stableWardTemplateValue(item)}',
            item,
          ),
        )
        .toList();
    return WardDenominatorField(
      type: type,
      name: stableName,
      label: label,
      required: question['required'] == true,
      choiceList: _wardTemplateChoiceList(stableName),
      choices: options,
    );
  }

  String _wardTypeFromTemplate(String type) {
    return switch (type) {
      'sub_heading' => 'note',
      'multiple_choice' => 'select_one',
      'checkbox' => 'select_multiple',
      'number' => 'integer',
      'date' => 'date',
      _ => 'text',
    };
  }

  String? _wardTemplateChoiceList(String stableName) {
    return switch (stableName) {
      'Department' => 'Department',
      'Ward' => 'Ward',
      'Surveillance_Day' => 'Surveillance_Day',
      _ => null,
    };
  }

  String _stableWardTemplateValue(String label) {
    return label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Future<void> _save({required bool finalSubmit}) async {
    if (finalSubmit && !_formKey.currentState!.validate()) return;
    if (finalSubmit && _date == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select date')));
      return;
    }
    final hasNumericEntry = _controllers.values.any(
      (controller) => controller.text.trim().isNotEmpty,
    );
    if (!finalSubmit &&
        !hasNumericEntry &&
        _date == null &&
        _answers.values.every((value) => '$value'.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one denominator detail')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      for (final field in _wardFields.where(
        (field) => field.type == 'integer',
      )) {
        final raw = _controllers[field.name]?.text.trim() ?? '';
        if (raw.isEmpty) {
          _answers.remove(field.name);
        } else {
          _answers[field.name] = int.tryParse(raw) ?? raw;
        }
      }
      if (_date != null) {
        _answers['Date'] = Timestamp.fromDate(_date!);
      }

      final labels = {
        for (final field in _wardFields)
          if (_answers[field.name] != null)
            field.name: field.type == 'select_one'
                ? _wardChoiceLabel(field, _answers[field.name])
                : field.type == 'date' && _answers[field.name] is Timestamp
                ? DateFormat(
                    'MMM d, y',
                  ).format((_answers[field.name] as Timestamp).toDate())
                : _answers[field.name],
      };
      final deviceWarnings = _wardDenominatorDeviceWarnings(labels);
      var overrideConfirmed = false;
      if (deviceWarnings.isNotEmpty) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm denominator values'),
            content: Text(
              'Some device-day values exceed patient-days. Please confirm only if the denominator data are correct.\n\n${deviceWarnings.join('\n')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Review'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm and save'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
        overrideConfirmed = true;
      }
      final formId =
          widget.initialData?['formId'] as String? ??
          await SurveillanceFormIdService.nextFormId(
            facilityId: widget.facilityId,
            surveillanceCode: 'ipc_ward_denominator',
          );
      final status = finalSubmit ? 'Final' : 'Draft';
      final duplicateMessage = finalSubmit
          ? await _wardDenominatorDuplicateMessage(labels)
          : null;
      if (duplicateMessage != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(duplicateMessage),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final data = {
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityName,
        'formId': formId,
        'recordType': 'Ward Denominator',
        'department': labels['Department'] ?? _answers['Department'],
        'ward': labels['Ward'] ?? _answers['Ward'],
        'surveillanceDay':
            labels['Surveillance_Day'] ?? _answers['Surveillance_Day'],
        'discharges': _answers['No_of_Discharges'],
        if (_date != null) 'denominatorDate': Timestamp.fromDate(_date!),
        'submissionStatus': status,
        'submissionState': finalSubmit ? 'final' : 'draft',
        'status': finalSubmit ? 'submitted' : 'pending',
        'isFinal': finalSubmit,
        'dataStatus': widget.initialData?['dataStatus'] ?? 'Raw Data',
        'wardDenominatorResponses': Map<String, dynamic>.from(_answers),
        'wardDenominatorResponseLabels': labels,
        if (deviceWarnings.isNotEmpty) 'denominatorWarnings': deviceWarnings,
        if (overrideConfirmed) ...{
          'denominatorOverrideConfirmed': true,
          'denominatorOverrideConfirmedBy': widget.staffName,
          'denominatorOverrideConfirmedById': widget.staffId,
          'denominatorOverrideConfirmedAt': FieldValue.serverTimestamp(),
        },
        'createdBy': widget.initialData?['createdBy'] ?? widget.staffName,
        'createdById': widget.initialData?['createdById'] ?? widget.staffId,
        'lastUpdatedBy': widget.staffName,
        'lastUpdatedById': widget.staffId,
        'updatedAt': FieldValue.serverTimestamp(),
        'changeHistory': FieldValue.arrayUnion([
          {
            'staffId': widget.staffId,
            'staffName': widget.staffName,
            'action': finalSubmit ? 'final_submit' : 'save_progress',
            'at': Timestamp.now(),
            if (overrideConfirmed)
              'denominatorOverrideWarnings': deviceWarnings,
          },
        ]),
        if (finalSubmit) ...{
          'finalizedBy': widget.staffName,
          'finalizedById': widget.staffId,
          'finalizedAt': FieldValue.serverTimestamp(),
        },
      };
      final collection = FirebaseFirestore.instance.collection(
        'ward_denominators',
      );
      if (widget.documentId == null) {
        await collection.add({
          ...data,
          'reportedDate': FieldValue.serverTimestamp(),
        });
      } else {
        await collection.doc(widget.documentId).update(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              finalSubmit
                  ? 'Ward denominator submitted successfully'
                  : 'Ward denominator progress saved',
            ),
          ),
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  List<String> _wardDenominatorDeviceWarnings(Map<String, dynamic> labels) {
    final patientDays = _wardInt(
      _answers['No_of_New_Admissions'] ?? _answers['Total_Patients'],
    );
    if (patientDays <= 0) return const [];
    final checks = <String, int>{
      'Urinary catheter-days': _wardInt(
        _answers['No_of_patients_on_Urinary_Catheter'],
      ),
      'Central line-days': _wardInt(
        _answers['No_of_patients_on_C_venous_catheter_CVC'],
      ),
      'Peripheral line-days': _wardInt(
        _answers['No_of_patients_on_P_venous_catheter_PVC'],
      ),
      'Ventilator-days': _wardInt(
        _answers['No_of_patients_on_I_cal_ventilation_INV'],
      ),
      'Non-invasive ventilator-days': _wardInt(
        _answers['No_of_patients_on_N_cal_ventilation_NIV'],
      ),
    };
    return checks.entries
        .where((entry) => entry.value > patientDays)
        .map(
          (entry) =>
              '${entry.key} (${entry.value}) exceed patient-days ($patientDays) for ${labels['Ward'] ?? _answers['Ward'] ?? 'this ward'}.',
        )
        .toList();
  }

  int _wardInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('$value') ?? 0;
  }

  String _wardChoiceLabel(WardDenominatorField field, Object? value) {
    if (field.choiceList != null) {
      return wardDenominatorChoiceLabel(field.name, value);
    }
    return field.choices
            .where((choice) => choice.value == value)
            .map((choice) => choice.label)
            .firstOrNull ??
        '${value ?? ''}';
  }

  Future<String?> _wardDenominatorDuplicateMessage(
    Map<String, dynamic> labels,
  ) async {
    if (_date == null) return null;
    final ward = '${labels['Ward'] ?? _answers['Ward'] ?? ''}'.trim();
    if (ward.isEmpty) return null;
    final currentDischarges = _wardInt(_answers['No_of_Discharges']);
    final currentSurveillanceDays = _wardDuplicateKeys([
      _answers['Surveillance_Day'],
      labels['Surveillance_Day'],
    ]);
    final snapshot = await FirebaseFirestore.instance
        .collection('ward_denominators')
        .where('facilityId', isEqualTo: widget.facilityId)
        .where('ward', isEqualTo: ward)
        .get();
    for (final doc in snapshot.docs) {
      if (widget.documentId != null && doc.id == widget.documentId) continue;
      final data = doc.data();
      final date = data['denominatorDate'] is Timestamp
          ? (data['denominatorDate'] as Timestamp).toDate()
          : null;
      if (date == null) continue;
      final sameMonth = date.year == _date!.year && date.month == _date!.month;
      final sameDay =
          date.year == _date!.year &&
          date.month == _date!.month &&
          date.day == _date!.day;
      if (sameDay) {
        return 'A ward denominator record already exists for this ward and date.';
      }
      if (sameMonth) {
        final existingResponses = data['wardDenominatorResponses'] is Map
            ? Map<String, dynamic>.from(data['wardDenominatorResponses'] as Map)
            : const <String, dynamic>{};
        final existingLabels = data['wardDenominatorResponseLabels'] is Map
            ? Map<String, dynamic>.from(
                data['wardDenominatorResponseLabels'] as Map,
              )
            : const <String, dynamic>{};
        final existingSurveillanceDays = _wardDuplicateKeys([
          existingResponses['Surveillance_Day'],
          existingLabels['Surveillance_Day'],
          data['surveillanceDay'],
        ]);
        if (currentSurveillanceDays.isNotEmpty &&
            currentSurveillanceDays
                .intersection(existingSurveillanceDays)
                .isNotEmpty) {
          return 'This surveillance day has already been submitted for this ward in the selected month.';
        }
        if (currentDischarges <= 0) continue;
        final existingDischarges = _wardInt(
          existingResponses['No_of_Discharges'] ?? data['discharges'],
        );
        if (existingDischarges > 0) {
          return 'Monthly discharges already exist for this ward and month. Leave discharges blank or update the existing monthly discharge record.';
        }
      }
    }
    return null;
  }

  Set<String> _wardDuplicateKeys(Iterable<Object?> values) {
    final keys = <String>{};
    for (final value in values) {
      final raw = '$value'.trim().toLowerCase();
      if (raw.isEmpty || raw == 'null') continue;
      keys.add(raw);
      keys.add(raw.replaceAll(RegExp(r'\s+'), ''));
      final dayMatch = RegExp(r'^day\s*(\d+)$').firstMatch(raw);
      if (dayMatch != null) {
        keys.add('day${dayMatch.group(1)}');
      }
      final dayNumber = RegExp(r'^\d+$').firstMatch(raw);
      if (dayNumber != null) {
        keys.add('day$raw');
      }
    }
    return keys;
  }

  @override
  Widget build(BuildContext context) {
    final isFinal = widget.initialData?['submissionStatus'] == 'Final';
    final canSaveProgress = !isFinal;
    final canFinalSubmit = !isFinal || widget.allowFinalEdit;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.documentId == null
              ? 'Add Ward Denominator'
              : 'Update Ward Denominator',
        ),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingWardDenominatorTemplate
          ? const Center(child: CircularProgressIndicator())
          : _wardFields.isEmpty
          ? _IpcServerTemplateUnavailable(
              title: 'Ward Denominator template unavailable',
              message:
                  _wardDenominatorTemplateError ??
                  'Save the Ward Denominator template from IPC Dashboard Control before staff use this form.',
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final field in _wardFields) ...[
                    _buildField(field, finalSubmitEnabled: canFinalSubmit),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  if (canSaveProgress) ...[
                    OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _save(finalSubmit: false),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Save progress'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ElevatedButton.icon(
                    onPressed: _isSubmitting || !canFinalSubmit
                        ? null
                        : () => _save(finalSubmit: true),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(isFinal ? Icons.update : Icons.check_circle),
                    label: Text(isFinal ? 'Update' : 'Final submit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade800,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildField(
    WardDenominatorField field, {
    required bool finalSubmitEnabled,
  }) {
    if (field.type == 'note') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          border: Border(
            left: BorderSide(color: Colors.teal.shade700, width: 4),
          ),
        ),
        child: Text(
          field.label,
          style: TextStyle(
            color: Colors.teal.shade900,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    switch (field.name) {
      case 'Department':
        return DropdownButtonFormField<String>(
          value: _answers[field.name] as String?,
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
          ),
          items: wardDenominatorDepartmentChoices
              .map(
                (choice) => DropdownMenuItem(
                  value: choice.value,
                  child: Text(choice.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _answers[field.name] = value;
              _answers.remove('Ward');
            });
          },
          validator: (value) =>
              value == null && finalSubmitEnabled ? 'Required' : null,
        );
      case 'Ward':
        final department = _answers['Department'] as String?;
        final wards = wardDenominatorWardChoices
            .where((choice) => choice.department == department)
            .toList();
        return DropdownButtonFormField<String>(
          value: _answers[field.name] as String?,
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
          ),
          items: wards
              .map(
                (choice) => DropdownMenuItem(
                  value: choice.value,
                  child: Text(choice.label),
                ),
              )
              .toList(),
          onChanged: department == null
              ? null
              : (value) => setState(() => _answers[field.name] = value),
          validator: (value) =>
              value == null && finalSubmitEnabled ? 'Required' : null,
        );
      case 'Surveillance_Day':
        return DropdownButtonFormField<String>(
          value: _answers[field.name] as String?,
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
          ),
          items: wardDenominatorDayChoices
              .map(
                (choice) => DropdownMenuItem(
                  value: choice.value,
                  child: Text(choice.label),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _answers[field.name] = value),
          validator: (value) =>
              value == null && finalSubmitEnabled ? 'Required' : null,
        );
      case 'Date':
        return InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => _date = picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: field.label,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_today),
              errorText: finalSubmitEnabled && _date == null ? null : null,
            ),
            child: Text(
              _date == null
                  ? 'Select date'
                  : DateFormat('MMM d, y').format(_date!),
            ),
          ),
        );
      default:
        if (field.type == 'select_one') {
          return DropdownButtonFormField<String>(
            value: _answers[field.name] as String?,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: field.label,
              border: const OutlineInputBorder(),
            ),
            items: field.choices
                .map(
                  (choice) => DropdownMenuItem(
                    value: choice.value,
                    child: Text(choice.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _answers[field.name] = value),
            validator: (value) =>
                value == null && finalSubmitEnabled && field.required
                ? 'Required'
                : null,
          );
        }
        if (field.type == 'select_multiple') {
          final selected = List<String>.from(
            _answers[field.name] as List? ?? const [],
          );
          return FormField<List<String>>(
            initialValue: selected,
            validator: (_) =>
                finalSubmitEnabled && field.required && selected.isEmpty
                ? 'Select at least one option'
                : null,
            builder: (formField) => InputDecorator(
              decoration: InputDecoration(
                labelText: field.label,
                border: const OutlineInputBorder(),
                errorText: formField.errorText,
              ),
              child: Column(
                children: field.choices
                    .map(
                      (choice) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(choice.label),
                        value: selected.contains(choice.value),
                        onChanged: (checked) {
                          setState(() {
                            if (checked ?? false) {
                              selected.add(choice.value);
                            } else {
                              selected.remove(choice.value);
                            }
                            _answers[field.name] = selected;
                            formField.didChange(selected);
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        }
        if (field.type != 'integer') {
          final controller = _controllers.putIfAbsent(
            field.name,
            () => TextEditingController(text: '${_answers[field.name] ?? ''}'),
          );
          return TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: field.label,
              border: const OutlineInputBorder(),
            ),
            minLines: field.type == 'multiline' ? 3 : 1,
            maxLines: field.type == 'multiline' ? 5 : 1,
            onChanged: (value) => _answers[field.name] = value.trim(),
            validator: (value) =>
                finalSubmitEnabled &&
                    field.required &&
                    (value == null || value.trim().isEmpty)
                ? 'Required'
                : null,
          );
        }
        final isMonthlyDischarge = field.name == 'No_of_Discharges';
        return TextFormField(
          controller: _controllers[field.name],
          decoration: InputDecoration(
            labelText: field.label,
            helperText: isMonthlyDischarge
                ? 'Enter once per ward/month; leave blank on daily denominator records.'
                : null,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (!finalSubmitEnabled) return null;
            final text = value?.trim() ?? '';
            if (isMonthlyDischarge && text.isEmpty) return null;
            if (text.isEmpty) return 'Required';
            final parsed = int.tryParse(text);
            if (parsed == null) {
              return 'Enter a whole number';
            }
            if (parsed < 0) return 'Enter zero or greater';
            return null;
          },
        );
    }
  }
}

// ===================== HAI REPORT FORM =====================

class _HAIReportFormScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final String infectionType;
  final String surveillanceType;
  final String? documentId;
  final Map<String, dynamic>? initialData;
  final bool allowFinalEdit;

  const _HAIReportFormScreen({
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    required this.infectionType,
    required this.surveillanceType,
    this.documentId,
    this.initialData,
    this.allowFinalEdit = false,
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
  final _organismController = TextEditingController();
  final Map<String, dynamic> _haiAnswers = {};
  final Map<String, TextEditingController> _haiTextControllers = {};
  final Map<String, DateTime> _haiDates = {};
  List<HaiQuestionnaireField>? _facilityHaiTemplateFields;
  bool _isLoadingHaiTemplate = true;
  String? _haiTemplateError;

  String? _selectedGender;
  String? _selectedDepartment;
  String? _selectedSeverity;
  DateTime? _onsetDate;
  DateTime? _admissionDate;
  String? _selectedDeviceType;
  int? _daysSinceAdmission;
  bool _labConfirmed = false;
  bool _isSubmitting = false;
  bool _isGeneratingRemarkSuggestion = false;
  bool _isGeneratingHaiDecisionSupport = false;

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
  void initState() {
    super.initState();
    _loadFacilityHaiTemplate();
    final data = widget.initialData;
    if (data == null) return;

    _patientIdController.text = '${data['patientId'] ?? ''}';
    _patientNameController.text = '${data['patientName'] ?? ''}';
    _ageController.text = data['age']?.toString() ?? '';
    _diagnosisController.text = '${data['diagnosis'] ?? ''}';
    _symptomsController.text = '${data['symptoms'] ?? ''}';
    _riskFactorsController.text = '${data['riskFactors'] ?? ''}';
    _interventionsController.text = '${data['interventions'] ?? ''}';
    _notesController.text = '${data['notes'] ?? ''}';
    _organismController.text = '${data['organism'] ?? ''}';
    _selectedGender = data['gender'] as String?;
    _selectedDepartment = data['department'] as String?;
    _selectedSeverity = data['severity'] as String?;
    _selectedDeviceType = data['deviceType'] as String?;
    _daysSinceAdmission = data['daysSinceAdmission'] as int?;
    _labConfirmed = data['labConfirmed'] as bool? ?? false;
    _onsetDate =
        (data['eventDate'] as Timestamp?)?.toDate() ??
        (data['onsetDate'] as Timestamp?)?.toDate();
    _admissionDate = (data['admissionDate'] as Timestamp?)?.toDate();
    final responses = data['haiQuestionnaireResponses'];
    if (responses is Map) {
      _haiAnswers.addAll(Map<String, dynamic>.from(responses));
    }
    _migrateHistoricalHaiRemark();
    final dates = data['haiQuestionnaireDates'];
    if (dates is Map) {
      for (final entry in dates.entries) {
        final value = entry.value;
        if (value is Timestamp) {
          _haiDates['${entry.key}'] = value.toDate();
        }
      }
    }
  }

  List<HaiQuestionnaireField> get _haiFields =>
      _facilityHaiTemplateFields ?? const <HaiQuestionnaireField>[];

  List<String> get _haiSections {
    final sections = <String>[];
    for (final field in _haiFields) {
      if (!sections.contains(field.section)) sections.add(field.section);
    }
    return sections;
  }

  Future<void> _loadFacilityHaiTemplate() async {
    try {
      final facilityKey = widget.facilityName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final data = await _loadLatestBuiltInIpcTemplateDataFromServer(
        facilityKey: facilityKey,
        facilityId: widget.facilityId,
        facilityName: widget.facilityName,
        templateId: 'hai_surveillance',
      );
      final questions = data?['questions'];
      if (questions is! List || questions.isEmpty) return;
      final templateQuestions = questions
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final idToStableName = <String, String>{};
      for (final question in templateQuestions) {
        final id = '${question['id'] ?? ''}'.trim();
        final stableName = '${question['stableName'] ?? ''}'.trim();
        if (id.isNotEmpty && stableName.isNotEmpty) {
          idToStableName[id] = stableName;
        }
      }
      final fields = templateQuestions
          .map((item) => _haiFieldFromTemplate(item, idToStableName))
          .whereType<HaiQuestionnaireField>()
          .toList();
      final fieldsWithRepeatMetadata = _withBuiltInHaiRepeatMetadata(fields);
      if (fieldsWithRepeatMetadata.isEmpty) {
        _haiTemplateError =
            'HAI Surveillance template has no usable questions.';
        return;
      }
      if (!mounted) return;
      setState(() {
        _facilityHaiTemplateFields = fieldsWithRepeatMetadata;
        _haiTemplateError = null;
      });
    } catch (error) {
      _haiTemplateError =
          'Unable to load HAI Surveillance template. Please ask the facility admin to save the template again.';
    } finally {
      if (mounted) {
        setState(() => _isLoadingHaiTemplate = false);
      }
    }
  }

  HaiQuestionnaireField? _haiFieldFromTemplate(
    Map<String, dynamic> question,
    Map<String, String> idToStableName,
  ) {
    final id = '${question['id'] ?? ''}'.trim();
    final stableName = '${question['stableName'] ?? question['id'] ?? ''}';
    final label = '${question['label'] ?? ''}'.trim();
    if (stableName.trim().isEmpty || label.isEmpty) return null;
    final options = (question['options'] as List<dynamic>? ?? [])
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final optionValues = question['optionValues'] is Map
        ? Map<String, dynamic>.from(question['optionValues'] as Map)
        : const <String, dynamic>{};
    return HaiQuestionnaireField(
      id: id,
      name: stableName,
      label: label,
      section: '${question['section'] ?? 'Patient Biodata'}',
      type: _haiTypeFromTemplate('${question['type'] ?? 'short_text'}'),
      required: question['required'] == true,
      relevant: _templateRelevantExpression(question, idToStableName),
      calculation: question['calculation'] is Map
          ? Map<String, dynamic>.from(question['calculation'] as Map)
          : const <String, dynamic>{},
      metadata: question['metadata'] is Map
          ? Map<String, dynamic>.from(question['metadata'] as Map)
          : const <String, dynamic>{},
      options: options
          .map(
            (label) => HaiQuestionnaireOption(
              '${optionValues[label] ?? _stableOptionValue(label)}',
              label,
            ),
          )
          .toList(),
    );
  }

  List<HaiQuestionnaireField> _withBuiltInHaiRepeatMetadata(
    List<HaiQuestionnaireField> fields,
  ) {
    final antimicrobialChildFields = _haiAntimicrobialChildFields(fields);
    final additionalPathogenChildFields = _haiAdditionalPathogenChildFields(
      fields,
    );
    final mergedFields = <HaiQuestionnaireField>[];
    for (final field in fields) {
      if (field.name == 'Antimicrobials_001') {
        mergedFields.add(
          _copyHaiField(
            field,
            metadata: {
              'behavior': 'antimicrobial_bank',
              'addButtonLabel': 'Add antimicrobial',
              'selectionTitle': 'Select antimicrobial',
              'detailsAnswerKey': 'Antimicrobials_001_details',
              'hideTemplateQuestions': antimicrobialChildFields
                  .map((item) => item.name)
                  .toList(),
              'childFields': antimicrobialChildFields
                  .map(
                    (item) =>
                        _haiRepeatChildMetadata(item, antimicrobialChildFields),
                  )
                  .toList(),
            },
          ),
        );
        continue;
      }
      if (_isHaiAdditionalPathogenRepeatField(field)) {
        final triggerFieldName =
            _haiFirstFieldNameByMeaning(fields, const [
              'pathogen identified',
              'organism identified',
              'microorganism identified',
              'pathogen isolated',
              'organism isolated',
              'microorganism isolated',
            ]) ??
            'Pathogen_Identified';
        mergedFields.add(
          _copyHaiField(
            field,
            label: 'Add pathogen',
            type: 'text',
            required: false,
            options: const <HaiQuestionnaireOption>[],
            relevant: "\${$triggerFieldName} != ''",
            metadata: {
              'behavior': 'repeat_group',
              'addButtonLabel': 'Add pathogen',
              'buttonVariant': 'link',
              'detailsAnswerKey': 'Additional_Pathogens_Details',
              'itemTitlePrefix': 'Additional pathogen',
              'childFields': additionalPathogenChildFields
                  .map(
                    (item) => _haiRepeatChildMetadata(
                      item,
                      additionalPathogenChildFields,
                    ),
                  )
                  .toList(),
            },
          ),
        );
        continue;
      }
      final defaultCalculation = _haiBuiltInDefaultCalculation(field.name);
      if (defaultCalculation != null) {
        mergedFields.add(
          _copyHaiField(
            field,
            type: 'calculated',
            calculation: defaultCalculation,
            relevant: _haiBuiltInDefaultRelevant(field.name) ?? field.relevant,
          ),
        );
        continue;
      }
      mergedFields.add(field);
    }
    final additionalPathogenTriggerField =
        _haiFirstFieldNameByMeaning(mergedFields, const [
          'pathogen identified',
          'organism identified',
          'microorganism identified',
          'pathogen isolated',
          'organism isolated',
          'microorganism isolated',
        ]) ??
        'Pathogen_Identified';
    final additionalPathogenInsertAfter =
        _haiLastFieldNameByMeaning(mergedFields, const [
          'resistant pattern',
          'resistance pattern',
          'resistant type',
          'resistance type',
        ]) ??
        additionalPathogenTriggerField;
    _insertMissingHaiCalculationField(
      mergedFields,
      afterName: additionalPathogenInsertAfter,
      field: HaiQuestionnaireField(
        name: '_76_Sub_specy',
        label: 'Add pathogen',
        section: 'Patient Microorganism',
        type: 'text',
        required: false,
        relevant: "\${$additionalPathogenTriggerField} != ''",
        metadata: {
          'behavior': 'repeat_group',
          'addButtonLabel': 'Add pathogen',
          'buttonVariant': 'link',
          'detailsAnswerKey': 'Additional_Pathogens_Details',
          'itemTitlePrefix': 'Additional pathogen',
          'childFields': additionalPathogenChildFields
              .map(
                (item) => _haiRepeatChildMetadata(
                  item,
                  additionalPathogenChildFields,
                ),
              )
              .toList(),
        },
      ),
    );
    return mergedFields;
  }

  Map<String, dynamic>? _haiBuiltInDefaultCalculation(String fieldName) {
    return switch (fieldName) {
      '_40_Duration_of_hosp_ays_weeks_or_months' => const {
        'type': 'days_since_date',
        'sourceQuestionId': '_8_Date_of_admission',
        'endQuestionId': 'Date_of_discharge',
        'endFallback': 'today',
        'inclusive': true,
        'unit': 'days',
      },
      'Duration_on_device_days' => const {
        'type': 'days_since_date',
        'sourceQuestionId': 'Date_of_device_insertion',
        'endQuestionId': 'Date_of_device_removal',
        'endFallback': 'today',
        'inclusive': true,
        'unit': 'days',
      },
      _ => null,
    };
  }

  String? _haiBuiltInDefaultRelevant(String fieldName) {
    return switch (fieldName) {
      'Duration_on_device_days' =>
        r"selected(${Type_of_risk}, 'medical_device') and ${Date_of_device_insertion} != ''",
      _ => null,
    };
  }

  void _insertMissingHaiCalculationField(
    List<HaiQuestionnaireField> fields, {
    required String afterName,
    required HaiQuestionnaireField field,
  }) {
    if (fields.any((item) => item.name == field.name)) return;
    final index = fields.indexWhere((item) => item.name == afterName);
    if (index < 0 || index + 1 >= fields.length) {
      fields.add(field);
    } else {
      fields.insert(index + 1, field);
    }
  }

  List<HaiQuestionnaireField> _haiFieldsBetween(
    List<HaiQuestionnaireField> fields, {
    required String startName,
    required String endBeforeName,
  }) {
    final start = fields.indexWhere((field) => field.name == startName);
    final end = fields.indexWhere((field) => field.name == endBeforeName);
    if (start < 0 || end <= start) return const <HaiQuestionnaireField>[];
    return fields.sublist(start, end);
  }

  List<HaiQuestionnaireField> _haiAntimicrobialChildFields(
    List<HaiQuestionnaireField> fields,
  ) {
    final childFields = _haiFieldsBetween(
      fields,
      startName: '_17_Please_specify',
      endBeforeName: '_29_What_was_the_reason_for_th',
    ).toList();
    for (final field in fields) {
      if (!_haiFieldMatchesMeaning(field, const [
        'date antimicrobial commenced',
        'date antimicrobial commencement',
        'antimicrobial commencement date',
        'date antimicrobial completed',
        'date antimicrobial completion',
        'antimicrobial completion date',
        'date antibiotic commenced',
        'date antibiotic completion',
        'duration on antimicrobial',
        'duration of antimicrobial',
        'antimicrobial duration',
        'route of administration',
        'reason for prescription',
      ])) {
        continue;
      }
      if (!childFields.any((item) => item.name == field.name)) {
        childFields.add(field);
      }
    }
    return childFields;
  }

  List<HaiQuestionnaireField> _haiAdditionalPathogenChildFields(
    List<HaiQuestionnaireField> fields,
  ) {
    var start = fields.indexWhere(
      (field) => _haiFieldMatchesMeaning(field, const [
        'type of sample collected',
        'sample type',
        'specimen type',
        'specimen collected',
        'sample collected',
      ]),
    );
    if (start < 0) {
      start = fields.indexWhere(
        (field) => _haiFieldMatchesMeaning(field, const [
          'pathogen identified',
          'organism identified',
          'microorganism identified',
          'pathogen isolated',
          'organism isolated',
          'microorganism isolated',
        ]),
      );
    }
    if (start < 0) return const <HaiQuestionnaireField>[];
    var end = fields.indexWhere(
      (field) => _isHaiAdditionalPathogenRepeatField(field),
    );
    if (end <= start) {
      var lastResistance = -1;
      for (var index = start; index < fields.length; index += 1) {
        final field = fields[index];
        if (_isHaiAdditionalPathogenRepeatField(field)) continue;
        if (_haiFieldMatchesMeaning(field, const [
          'resistant pattern',
          'resistance pattern',
          'resistant type',
          'resistance type',
        ])) {
          lastResistance = index;
        }
      }
      end = lastResistance >= start ? lastResistance + 1 : fields.length;
    }
    return fields
        .sublist(start, end)
        .where((field) => !_isHaiAdditionalPathogenRepeatField(field))
        .toList();
  }

  bool _isHaiAdditionalPathogenRepeatField(HaiQuestionnaireField field) {
    if (field.name == '_76_Sub_specy') return true;
    final behavior = '${field.metadata['behavior'] ?? ''}';
    final detailsKey = '${field.metadata['detailsAnswerKey'] ?? ''}';
    if (behavior == 'repeat_group' &&
        detailsKey == 'Additional_Pathogens_Details') {
      return true;
    }
    final label = _normalizeHaiFormLookupText(field.label);
    final name = _normalizeHaiFormLookupText(field.name);
    return label == 'add_pathogen' ||
        label == 'add_additional_pathogen' ||
        name == 'add_pathogen' ||
        name == 'add_additional_pathogen';
  }

  bool _haiFieldMatchesMeaning(
    HaiQuestionnaireField field,
    List<String> meanings,
  ) {
    final haystack = _normalizeHaiFormLookupText(
      '${field.label} ${field.name}',
    );
    return meanings
        .map(_normalizeHaiFormLookupText)
        .any((meaning) => haystack.contains(meaning));
  }

  String? _haiFirstFieldNameByMeaning(
    List<HaiQuestionnaireField> fields,
    List<String> meanings,
  ) {
    for (final field in fields) {
      if (_haiFieldMatchesMeaning(field, meanings)) return field.name;
    }
    return null;
  }

  String? _haiLastFieldNameByMeaning(
    List<HaiQuestionnaireField> fields,
    List<String> meanings,
  ) {
    String? match;
    for (final field in fields) {
      if (_haiFieldMatchesMeaning(field, meanings)) match = field.name;
    }
    return match;
  }

  Map<String, dynamic> _haiRepeatChildMetadata(
    HaiQuestionnaireField field,
    List<HaiQuestionnaireField> groupFields,
  ) {
    final calculation = _haiRepeatChildCalculation(field, groupFields);
    return {
      'key': field.name,
      'label': field.label,
      'type': _haiRepeatChildType(field.type),
      'required': field.required,
      'options': field.options.map((option) => option.label).toList(),
      'optionValues': {
        for (final option in field.options) option.label: option.value,
      },
      if (calculation.isNotEmpty) 'calculation': calculation,
      if (field.relevant.trim().isNotEmpty) 'relevant': field.relevant,
    };
  }

  Map<String, dynamic> _haiRepeatChildCalculation(
    HaiQuestionnaireField field,
    List<HaiQuestionnaireField> groupFields,
  ) {
    if (field.type != 'calculated') return const {};
    final calculation = Map<String, dynamic>.from(field.calculation);
    final text = _normalizeHaiFormLookupText('${field.label} ${field.name}');
    if (!text.contains('duration') && !text.contains('days')) {
      return calculation;
    }

    String? firstDateByMeaning(List<String> meanings) {
      for (final candidate in groupFields) {
        if (candidate.type == 'date' &&
            _haiFieldMatchesMeaning(candidate, meanings)) {
          return candidate.name;
        }
      }
      return null;
    }

    if (text.contains('antimicrobial') ||
        text.contains('antibiotic') ||
        text.contains('antibiotics')) {
      calculation['sourceQuestionId'] =
          '${calculation['sourceQuestionId'] ?? calculation['sourceQuestion'] ?? firstDateByMeaning(const ['date antimicrobial commenced', 'date antimicrobial commencement', 'antimicrobial commencement date', 'date antibiotic commenced', 'date antibiotic commencement', 'antibiotic commencement date', 'date antimicrobial started', 'date antibiotic started']) ?? ''}';
      final endQuestionId =
          '${calculation['endQuestionId'] ?? calculation['endQuestion'] ?? ''}'
              .trim();
      if (endQuestionId.isEmpty) {
        final inferredEnd = firstDateByMeaning(const [
          'date antimicrobial completed',
          'date antimicrobial completion',
          'antimicrobial completion date',
          'date antibiotic completed',
          'date antibiotic completion',
          'antibiotic completion date',
          'date antimicrobial stopped',
          'date antibiotic stopped',
        ]);
        if (inferredEnd != null) calculation['endQuestionId'] = inferredEnd;
      }
    }

    if ('${calculation['sourceQuestionId'] ?? ''}'.trim().isEmpty) {
      return const {};
    }
    return {
      'type': 'days_since_date',
      'sourceQuestionId': '${calculation['sourceQuestionId']}',
      if ('${calculation['endQuestionId'] ?? ''}'.trim().isNotEmpty)
        'endQuestionId': '${calculation['endQuestionId']}',
      'endFallback': '${calculation['endFallback'] ?? 'today'}',
      'inclusive': calculation['inclusive'] != false,
      'unit': 'days',
    };
  }

  String _haiRepeatChildType(String type) {
    return switch (type) {
      'integer' || 'decimal' => 'number',
      'multiselect' => 'multiselect',
      'multiline' => 'long_text',
      _ => type,
    };
  }

  HaiQuestionnaireField _copyHaiField(
    HaiQuestionnaireField field, {
    String? label,
    String? type,
    bool? required,
    List<HaiQuestionnaireOption>? options,
    String? relevant,
    Map<String, dynamic>? calculation,
    Map<String, dynamic>? metadata,
  }) {
    return HaiQuestionnaireField(
      id: field.id,
      name: field.name,
      label: label ?? field.label,
      section: field.section,
      type: type ?? field.type,
      required: required ?? field.required,
      options: options ?? field.options,
      relevant: relevant ?? field.relevant,
      calculation: calculation ?? field.calculation,
      metadata: metadata ?? field.metadata,
    );
  }

  String _templateRelevantExpression(
    Map<String, dynamic> question,
    Map<String, String> idToStableName,
  ) {
    final existing = '${question['relevant'] ?? ''}'.trim();
    final expressions = <String>[];
    final rawRules = question['showIfRules'];
    if (rawRules is List) {
      for (final raw in rawRules) {
        if (raw is! Map) continue;
        final questionId =
            '${raw['questionId'] ?? raw['showIfQuestionId'] ?? ''}'.trim();
        final value =
            '${raw['optionValue'] ?? raw['value'] ?? raw['showIfValue'] ?? ''}'
                .trim();
        if (questionId.isEmpty || value.isEmpty) continue;
        final fieldName = idToStableName[questionId] ?? questionId;
        expressions.add(
          value == '__answered__'
              ? "\${$fieldName} != ''"
              : "\${$fieldName} = ${jsonEncode(value)}",
        );
      }
    }
    final legacyQuestionId = '${question['showIfQuestionId'] ?? ''}'.trim();
    final legacyValue = '${question['showIfValue'] ?? ''}'.trim();
    if (legacyQuestionId.isNotEmpty && legacyValue.isNotEmpty) {
      final fieldName = idToStableName[legacyQuestionId] ?? legacyQuestionId;
      expressions.add(
        legacyValue == '__answered__'
            ? "\${$fieldName} != ''"
            : "\${$fieldName} = ${jsonEncode(legacyValue)}",
      );
    }
    final combined = expressions.toSet().join(' or ');
    if (combined.isNotEmpty) return combined;
    return existing;
  }

  String _haiTypeFromTemplate(String type) {
    return switch (type) {
      'sub_heading' => 'note',
      'calculated' => 'calculated',
      'multiple_choice' => 'select',
      'checkbox' => 'multiselect',
      'date' => 'date',
      'number' => 'decimal',
      'long_text' => 'multiline',
      _ => 'text',
    };
  }

  String _stableOptionValue(String label) {
    return label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

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
    _organismController.dispose();
    for (final controller in _haiTextControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _isWorkbookHaiForm() => true;

  void _migrateHistoricalHaiRemark() {
    final remark = '${_haiAnswers['Remark'] ?? ''}'.trim();
    if (remark.isEmpty) return;
    _haiAnswers['Historical_Remark'] ??= remark;
    _haiAnswers.remove('Remark');
    _haiAnswers['Clinical_Outcome'] ??= _inferClinicalOutcomeFromRemark(remark);
    if (_haiAnswers['Clinical_Outcome'] == 'other') {
      _haiAnswers['Other_Clinical_Outcome'] ??= remark;
    }
  }

  String _inferClinicalOutcomeFromRemark(String remark) {
    final text = remark.toLowerCase();
    if (text.contains('recover')) return 'recovered';
    if (text.contains('improv')) return 'improved';
    if (text.contains('deteriorat')) return 'deteriorated';
    if (text.contains('ongoing') || text.contains('treatment')) {
      return 'ongoing_treatment';
    }
    if (text.contains('died') ||
        text.contains('dead') ||
        text.contains('death')) {
      return 'died';
    }
    if (text.contains('discharg')) return 'discharged';
    if (text.contains('transfer')) return 'transferred';
    if (text.contains('refer')) return 'referred';
    if (text.contains('lama') || text.contains('against medical advice')) {
      return 'left_against_medical_advice';
    }
    if (text.contains('abscond')) return 'absconded';
    if (text.contains('still admitted')) return 'still_admitted';
    if (text.contains('unknown')) return 'unknown';
    return 'other';
  }

  bool _isHaiFieldVisible(HaiQuestionnaireField field) {
    final relevant = field.relevant.trim();
    if (relevant.isEmpty) return true;
    return relevant
        .split(RegExp(r'\s+or\s+', caseSensitive: false))
        .any(
          (orClause) => orClause
              .split(RegExp(r'\s+and\s+', caseSensitive: false))
              .every(_haiRelevantConditionMatches),
        );
  }

  bool _haiRelevantConditionMatches(String clause) {
    final selectedMatch =
        RegExp(
          r"""selected\(\$\{([^}]+)\},\s*'((?:\\.|[^'])*)'\)""",
        ).firstMatch(clause) ??
        RegExp(
          r'''selected\(\$\{([^}]+)\},\s*"((?:\\.|[^"])*)"\)''',
        ).firstMatch(clause);
    if (selectedMatch != null) {
      final fieldName = selectedMatch.group(1) ?? '';
      return _haiAnswerMatchesExpected(
        fieldName,
        _haiRelevantLiteral(selectedMatch.group(2)),
      );
    }

    final equalsMatch =
        RegExp(
          r"""\$\{([^}]+)\}\s*(!=|=)\s*'((?:\\.|[^'])*)'""",
        ).firstMatch(clause) ??
        RegExp(
          r'''\$\{([^}]+)\}\s*(!=|=)\s*"((?:\\.|[^"])*)"''',
        ).firstMatch(clause);
    if (equalsMatch == null) return false;
    final fieldName = equalsMatch.group(1) ?? '';
    final matches = _haiAnswerMatchesExpected(
      fieldName,
      _haiRelevantLiteral(equalsMatch.group(3)),
    );
    if (equalsMatch.group(2) == '!=') return !matches;
    return matches;
  }

  String _haiRelevantLiteral(String? value) => (value ?? '')
      .replaceAll(r"\'", "'")
      .replaceAll(r'\"', '"')
      .replaceAll(r'\\', r'\');

  bool _haiAnswerMatchesExpected(String fieldName, String? expected) {
    final value = _haiAnswers[fieldName];
    final expectedText = (expected ?? '').trim();
    if (value == null) return expectedText.isEmpty;
    if (value is Iterable) {
      if (value.isEmpty) return expectedText.isEmpty;
      return value.any(
        (item) => _haiRelevanceValueMatches(fieldName, item, expected),
      );
    }
    return '$value'
        .split(',')
        .map((item) => item.trim())
        .any((item) => _haiRelevanceValueMatches(fieldName, item, expected));
  }

  bool _haiRelevanceValueMatches(
    String fieldName,
    Object? answer,
    String? expected,
  ) {
    final expectedText = (expected ?? '').trim();
    final answerText = '${answer ?? ''}'.trim();
    if (expectedText.isEmpty) return answerText.isEmpty;
    if (_haiComparableToken(answerText) == _haiComparableToken(expectedText)) {
      return true;
    }

    final field = _haiFields
        .where((item) => item.name == fieldName)
        .firstOrNull;
    if (field == null) return false;
    for (final option in field.options) {
      final optionValue = option.value.trim();
      final optionLabel = option.label.trim();
      final answerMatchesOption =
          _haiComparableToken(answerText) == _haiComparableToken(optionValue) ||
          _haiComparableToken(answerText) == _haiComparableToken(optionLabel);
      if (!answerMatchesOption) continue;
      return _haiComparableToken(expectedText) ==
              _haiComparableToken(optionValue) ||
          _haiComparableToken(expectedText) == _haiComparableToken(optionLabel);
    }
    return false;
  }

  String _haiComparableToken(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  String _formatHaiDateOnly(DateTime value) =>
      DateFormat('MMM d, y').format(value);

  String _haiAnswerLabel(String fieldName) {
    final value = _haiAnswers[fieldName];
    final field = _haiFields
        .where((item) => item.name == fieldName)
        .firstOrNull;
    if (field == null || value == null) return '${value ?? ''}';
    if (field.type == 'date') {
      final dateValue = _haiDateFromValue(_haiDates[fieldName] ?? value);
      return dateValue == null ? '' : _formatHaiDateOnly(dateValue);
    }
    if (value is Timestamp || value is DateTime) {
      final dateValue = _haiDateFromValue(value);
      return dateValue == null ? '' : _formatHaiDateOnly(dateValue);
    }
    if (value is List) {
      return value
          .map(
            (item) =>
                field.options
                    .where((option) => option.value == item)
                    .map((option) => option.label)
                    .firstOrNull ??
                '$item',
          )
          .join(', ');
    }
    return field.options
            .where((option) => option.value == value)
            .map((option) => option.label)
            .firstOrNull ??
        '$value';
  }

  String _haiAnswerLabelByMeaning(List<String> labelNeedles) {
    final normalizedNeedles = labelNeedles
        .map(_normalizeHaiFormLookupText)
        .where((item) => item.isNotEmpty)
        .toList();
    for (final field in _haiFields) {
      final normalizedLabel = _normalizeHaiFormLookupText(field.label);
      final normalizedName = _normalizeHaiFormLookupText(field.name);
      final matches = normalizedNeedles.any(
        (needle) =>
            _haiFormSemanticLabelMatches(normalizedLabel, needle) ||
            _haiFormSemanticLabelMatches(normalizedName, needle),
      );
      if (!matches) continue;
      final value = _haiAnswerLabel(field.name).trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }

  String _haiSurgicalProcedureContext() {
    final direct = _haiAnswerLabel('Type_of_Surgical_Procedure').trim();
    if (direct.isNotEmpty && direct != 'null') return direct;
    return _haiAnswerLabelByMeaning(const [
      'type of surgical procedure',
      'surgical procedure',
      'surgery performed',
      'operation performed',
      'type of surgery',
      'patient risk surgical procedure',
    ]);
  }

  DateTime? _haiDeviceInsertionDateForCurrentForm() {
    return _haiDateByMeaning(
      fieldNames: const [
        'Date_of_device_insertion',
        'Device_insertion_date',
        'Date_Device_Inserted',
        'Device_Insertion_Date',
      ],
      labelNeedles: const [
        'date of device insertion',
        'device insertion date',
        'date device inserted',
        'date of insertion of device',
        'date of medical device insertion',
      ],
    );
  }

  String _haiDeviceDurationContext() {
    return _haiAnswerLabelByMeaning(const [
      'duration on device',
      'duration of device',
      'device duration',
      'days on device',
      'number of days on device',
      'duration of medical device',
      'duration with device',
    ]);
  }

  String? _haiFieldNameForTemplateId(String templateId) {
    final normalized = templateId.trim();
    if (normalized.isEmpty) return null;
    final field = _haiFields
        .where(
          (item) =>
              item.id == normalized ||
              item.name == normalized ||
              _haiComparableToken(item.id) == _haiComparableToken(normalized) ||
              _haiComparableToken(item.name) == _haiComparableToken(normalized),
        )
        .firstOrNull;
    return field?.name;
  }

  String _haiDaysBetweenDates(
    DateTime startDate,
    DateTime endDate, {
    required bool inclusive,
  }) {
    final start = _startOfDay(startDate);
    final end = _startOfDay(endDate);
    final days = end.difference(start).inDays + (inclusive ? 1 : 0);
    return '${days < 0 ? 0 : days}';
  }

  String? _haiInferredDateFieldNameForCalculation({
    required HaiQuestionnaireField field,
    required bool endDate,
  }) {
    final text = _normalizeHaiFormLookupText('${field.label} ${field.name}');
    if (!text.contains('duration') && !text.contains('days')) return null;
    if (text.contains('antimicrobial') ||
        text.contains('antibiotic') ||
        text.contains('antibiotics')) {
      return _haiFirstDateFieldNameByMeaning(
        endDate
            ? const [
                'date antimicrobial completed',
                'date antimicrobial completion',
                'antimicrobial completion date',
                'date antibiotic completed',
                'date antibiotic completion',
                'antibiotic completion date',
                'date antimicrobial stopped',
                'date antibiotic stopped',
              ]
            : const [
                'date antimicrobial commenced',
                'date antimicrobial commencement',
                'antimicrobial commencement date',
                'date antibiotic commenced',
                'date antibiotic commencement',
                'antibiotic commencement date',
                'date antimicrobial started',
                'date antibiotic started',
              ],
      );
    }
    if (text.contains('device') ||
        text.contains('catheter') ||
        text.contains('ventilator')) {
      return _haiFirstDateFieldNameByMeaning(
        endDate
            ? const [
                'date of device removal',
                'device removal date',
                'date device removed',
                'date of catheter removal',
                'catheter removal date',
                'date of ventilator removal',
                'ventilator removal date',
              ]
            : const [
                'date of device insertion',
                'device insertion date',
                'date device inserted',
                'date of catheter insertion',
                'catheter insertion date',
                'date of ventilator insertion',
                'ventilator insertion date',
              ],
      );
    }
    if (text.contains('hospital') ||
        text.contains('admission') ||
        text.contains('stay')) {
      return _haiFirstDateFieldNameByMeaning(
        endDate
            ? const [
                'date of discharge',
                'discharge date',
                'date discharged',
                'hospital discharge date',
              ]
            : const [
                'date of admission',
                'admission date',
                'date admitted',
                'hospital admission date',
              ],
      );
    }
    return null;
  }

  String? _haiFirstDateFieldNameByMeaning(List<String> meanings) {
    for (final field in _haiFields) {
      if (field.type == 'date' && _haiFieldMatchesMeaning(field, meanings)) {
        return field.name;
      }
    }
    return null;
  }

  void _setHaiCalculatedAnswer(String fieldName, String value) {
    if (value.trim().isEmpty) return;
    _haiAnswers[fieldName] = value;
    final controller = _haiTextControllers[fieldName];
    if (controller != null && controller.text != value) {
      controller.text = value;
    }
  }

  void _clearHaiCalculatedAnswer(String fieldName) {
    _haiAnswers.remove(fieldName);
    final controller = _haiTextControllers[fieldName];
    if (controller != null && controller.text.isNotEmpty) {
      controller.clear();
    }
  }

  void _syncHaiTemplateCalculations() {
    for (final field in _haiFields) {
      if (field.type != 'calculated') continue;
      if (!_isHaiFieldVisible(field)) {
        _clearHaiCalculatedAnswer(field.name);
        continue;
      }
      var calculation = Map<String, dynamic>.from(field.calculation);
      if ('${calculation['type'] ?? ''}' != 'days_since_date') {
        final inferredSource = _haiInferredDateFieldNameForCalculation(
          field: field,
          endDate: false,
        );
        if (inferredSource == null) continue;
        final inferredEnd = _haiInferredDateFieldNameForCalculation(
          field: field,
          endDate: true,
        );
        calculation = {
          'type': 'days_since_date',
          'sourceQuestionId': inferredSource,
          'endQuestionId': ?inferredEnd,
          'endFallback': 'today',
          'inclusive': true,
          'unit': 'days',
        };
      }
      final sourceQuestionId =
          '${calculation['sourceQuestionId'] ?? calculation['sourceQuestion'] ?? ''}'
              .trim();
      final sourceFieldName = sourceQuestionId.isEmpty
          ? _haiInferredDateFieldNameForCalculation(
              field: field,
              endDate: false,
            )
          : _haiFieldNameForTemplateId(sourceQuestionId);
      if (sourceFieldName == null) continue;
      final sourceDate = _haiDateFromValue(
        _haiDates[sourceFieldName] ?? _haiAnswers[sourceFieldName],
      );
      if (sourceDate == null) {
        _clearHaiCalculatedAnswer(field.name);
        continue;
      }
      final endQuestionId =
          '${calculation['endQuestionId'] ?? calculation['endQuestion'] ?? ''}'
              .trim();
      final endFieldName = endQuestionId.isEmpty
          ? _haiInferredDateFieldNameForCalculation(field: field, endDate: true)
          : _haiFieldNameForTemplateId(endQuestionId);
      final endDate = endFieldName == null
          ? null
          : _haiDateFromValue(
              _haiDates[endFieldName] ?? _haiAnswers[endFieldName],
            );
      _setHaiCalculatedAnswer(
        field.name,
        _haiDaysBetweenDates(
          sourceDate,
          endDate ?? DateTime.now(),
          inclusive: calculation['inclusive'] != false,
        ),
      );
    }
  }

  DateTime? _haiSurgicalProcedureDateForCurrentForm() {
    return _haiDateByMeaning(
      fieldNames: const [
        'Date_of_surgical_procedure',
        'Surgical_procedure_date',
        'Date_of_surgery',
        'Surgery_Date',
        'Operation_Date',
      ],
      labelNeedles: const [
        'date of surgical procedure',
        'surgical procedure date',
        'date of surgery',
        'surgery date',
        'operation date',
        'date operation performed',
      ],
    );
  }

  List<String> _haiExposureTimingContextEntries({DateTime? eventDate}) {
    final entries = <String>[];
    final device = _haiAnswerLabel('Type_of_Devices').trim();
    final deviceInsertionDate = _haiDeviceInsertionDateForCurrentForm();
    final deviceDuration = _haiDeviceDurationContext().trim();
    final surgicalProcedure = _haiSurgicalProcedureContext().trim();
    final surgicalProcedureDate = _haiSurgicalProcedureDateForCurrentForm();

    if (device.isNotEmpty && device != 'null') {
      entries.add('Device exposure: $device');
    }
    if (deviceInsertionDate != null) {
      entries.add(
        'Date of device insertion: ${DateFormat('MMM d, y').format(deviceInsertionDate)}',
      );
      if (eventDate != null) {
        entries.add(
          'Days from device insertion to event: ${eventDate.difference(deviceInsertionDate).inDays}',
        );
      }
    }
    if (deviceDuration.isNotEmpty && deviceDuration != 'null') {
      entries.add('Duration on device: $deviceDuration');
    }
    if (surgicalProcedure.isNotEmpty && surgicalProcedure != 'null') {
      entries.add('Surgical procedure: $surgicalProcedure');
    }
    if (surgicalProcedureDate != null) {
      entries.add(
        'Date of surgical procedure: ${DateFormat('MMM d, y').format(surgicalProcedureDate)}',
      );
      if (eventDate != null) {
        entries.add(
          'Days from surgical procedure to event: ${eventDate.difference(surgicalProcedureDate).inDays}',
        );
      }
    }
    return entries;
  }

  bool _haiFormSemanticLabelMatches(
    String normalizedPrompt,
    String normalizedNeedle,
  ) {
    if (normalizedPrompt.contains(normalizedNeedle)) return true;
    final promptTokens = normalizedPrompt
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toSet();
    final needleTokens = normalizedNeedle
        .split(' ')
        .where((token) => token.length > 2)
        .toList();
    if (needleTokens.isEmpty) return false;
    return needleTokens.every(promptTokens.contains);
  }

  String _normalizeHaiFormLookupText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  DateTime? _haiDateByMeaning({
    required List<String> labelNeedles,
    List<String> questionNumbers = const [],
    List<String> fieldNames = const [],
  }) {
    for (final fieldName in fieldNames) {
      final parsed = _haiDateFromValue(
        _haiDates[fieldName] ?? _haiAnswers[fieldName],
      );
      if (parsed != null) return parsed;
    }

    final normalizedNeedles = labelNeedles
        .map(_normalizeHaiFormLookupText)
        .where((item) => item.isNotEmpty)
        .toList();
    for (final field in _haiFields) {
      final normalizedLabel = _normalizeHaiFormLookupText(field.label);
      final normalizedName = _normalizeHaiFormLookupText(field.name);
      final numberMatch = questionNumbers.any(
        (number) => RegExp(
          r'^\s*' + RegExp.escape(number) + r'[\).\s_-]',
        ).hasMatch(field.label),
      );
      final labelMatch = normalizedNeedles.any(
        (needle) =>
            _haiFormSemanticLabelMatches(normalizedLabel, needle) ||
            _haiFormSemanticLabelMatches(normalizedName, needle),
      );
      if (!numberMatch && !labelMatch) continue;
      final parsed = _haiDateFromValue(
        _haiDates[field.name] ?? _haiAnswers[field.name],
      );
      if (parsed != null) return parsed;
    }
    return null;
  }

  DateTime? _haiDateFromValue(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse('$value');
  }

  DateTime? _haiAdmissionDateForCurrentForm() {
    return _haiDateByMeaning(
      fieldNames: const [
        '_8_Date_of_admission',
        '_12_Date_of_Admission',
        'Date_of_admission',
        'Date_of_Admission',
        'Admission_Date',
      ],
      questionNumbers: const ['8', '12'],
      labelNeedles: const [
        'date of admission',
        'admission date',
        'date admitted',
        'hospital admission date',
      ],
    );
  }

  DateTime? _haiEventDateForCurrentForm() {
    return _haiDateByMeaning(
      fieldNames: const [
        '_42_Date_of_first_symptoms',
        'Date_of_first_symptoms',
        'First_symptom_date',
        'Date_of_event',
        'Event_Date',
        'onsetDate',
      ],
      questionNumbers: const ['42'],
      labelNeedles: const [
        'date of first symptoms',
        'first symptoms date',
        'first symptom date',
        'date symptoms started',
        'date of symptom onset',
        'symptom onset date',
        'date of onset',
        'onset date',
        'date of event',
        'infection date of event',
      ],
    );
  }

  DateTime? _haiSampleDateForCurrentForm() {
    return _haiDateByMeaning(
      fieldNames: const [
        '_57_Date_of_sample_collection',
        '_83_Date_of_sample_collection_2',
        'Date_of_sample_collection',
        'Sample_collection_date',
      ],
      questionNumbers: const ['57', '83'],
      labelNeedles: const [
        'date of sample collection',
        'sample collection date',
        'date sample collected',
        'specimen collection date',
      ],
    );
  }

  Map<String, dynamic> _visibleHaiAnswers() {
    final answers = {
      for (final field in _haiFields)
        if (field.type != 'note' &&
            _isHaiFieldVisible(field) &&
            _haiAnswers[field.name] != null &&
            '${_haiAnswers[field.name]}'.trim().isNotEmpty)
          field.name: _haiAnswers[field.name],
    };
    for (final field in _haiFields.where(_isHaiTemplateRepeatField)) {
      if (!_isHaiFieldVisible(field)) continue;
      if (!answers.containsKey(field.name)) continue;
      final detailsKey =
          '${field.metadata['detailsAnswerKey'] ?? '${field.name}_details'}';
      final details = _haiAnswers[detailsKey];
      if (details is Map && details.isNotEmpty) {
        answers[detailsKey] = Map<String, dynamic>.from(details);
      }
    }
    return answers;
  }

  Map<String, String> _haiSectionStatus() {
    final answers = _visibleHaiAnswers();
    return {
      for (final section in _haiSections)
        section:
            _haiFields
                .where(
                  (field) =>
                      field.section == section &&
                      field.type != 'note' &&
                      field.required &&
                      _isHaiFieldVisible(field),
                )
                .every((field) {
                  final value = answers[field.name];
                  return value != null && '$value'.trim().isNotEmpty;
                })
            ? 'complete'
            : 'pending',
    };
  }

  Widget _buildWorkbookHaiQuestionnaire() {
    _syncHaiTemplateCalculations();
    final bankHiddenFields = _haiFields
        .where(_isHaiTemplateRepeatField)
        .expand((field) => _stringList(field.metadata['hideTemplateQuestions']))
        .toSet();
    final fields = _haiFields.where((field) {
      if (bankHiddenFields.contains(field.name)) return false;
      if (widget.surveillanceType == 'Routine HAI Surveillance') {
        return _isHaiFieldVisible(field);
      }
      return targetedHaiRelevantSections.contains(field.section) &&
          _isHaiFieldVisible(field);
    }).toList();
    String? currentSection;
    String? lastRenderedHeadingKey;
    final useTemplateSubHeadings =
        _facilityHaiTemplateFields != null &&
        fields.any((field) => field.type == 'note');
    final children = <Widget>[];
    for (final field in fields) {
      if (currentSection != field.section) {
        currentSection = field.section;
        if (field.section.toLowerCase().contains('patient hai')) {
          children
            ..add(_buildHaiDecisionSupportCard())
            ..add(const SizedBox(height: 12));
        }
        if (!useTemplateSubHeadings) {
          children
            ..add(_buildHaiSectionHeader(field.section))
            ..add(const SizedBox(height: 12));
          lastRenderedHeadingKey = _haiHeadingKey(field.section);
        } else {
          lastRenderedHeadingKey = null;
        }
      }
      if (_isDuplicateHaiSubHeading(field, lastRenderedHeadingKey)) {
        continue;
      }
      children
        ..add(_buildHaiField(field))
        ..add(const SizedBox(height: 16));
      if (field.type == 'note') {
        lastRenderedHeadingKey = _haiHeadingKey(field.label);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  bool _isDuplicateHaiSubHeading(
    HaiQuestionnaireField field,
    String? previousHeadingKey,
  ) {
    if (field.type != 'note') return false;
    final labelKey = _haiHeadingKey(field.label);
    final sectionKey = _haiHeadingKey(field.section);
    return labelKey.isNotEmpty &&
        (labelKey == sectionKey ||
            labelKey.contains(sectionKey) ||
            sectionKey.contains(labelKey) ||
            labelKey == previousHeadingKey);
  }

  String _haiHeadingKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();
  }

  Widget _buildHaiSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border(left: BorderSide(color: Colors.red.shade700, width: 4)),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.red.shade900,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHaiDecisionSupportCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_outlined, color: Colors.amber.shade900),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI HAI status support',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Review AI guidance before answering the Patient HAIs questions. It checks timing, site criteria, device or procedure exposure, microbiology, and missing evidence.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _isGeneratingHaiDecisionSupport
                  ? null
                  : _showHaiDecisionSupportDialog,
              icon: _isGeneratingHaiDecisionSupport
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology_alt_outlined),
              label: Text(
                _isGeneratingHaiDecisionSupport
                    ? 'Checking HAI status...'
                    : 'Check HAI status with AI',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showHaiDecisionSupportDialog() async {
    setState(() => _isGeneratingHaiDecisionSupport = true);
    try {
      final support = await _generateHaiDecisionSupport();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('AI HAI Status Support'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              child: Text(support, style: const TextStyle(height: 1.35)),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI HAI status check failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingHaiDecisionSupport = false);
    }
  }

  Future<String> _generateHaiDecisionSupport() async {
    final context = _haiDecisionSupportContext();
    final missingItems = _haiMissingPreDecisionItems();
    if (context.isEmpty) return _fallbackHaiDecisionSupport(missingItems);
    try {
      await GeminiService.initialize();
      final gemini = GeminiService.instance;
      if (!gemini.isConfigured) {
        return _fallbackHaiDecisionSupport(missingItems);
      }
      final response = await gemini.getChatResponse(
        userRole: 'nursing',
        userMessage:
            'You are supporting an IPC data collector who is about to answer the Patient HAIs questions in a surveillance form. '
            'Use only surveillance definitions, not treatment advice. Apply the HAI criteria and flowcharts below. '
            'Important: the date of first symptoms or event date is timing evidence only. Do not classify HAI from the date alone. Confirm the event using documented symptoms/signs, clinical diagnosis, microbiology where available, imaging, device exposure, procedure/surgery evidence, or severe-infection criteria. If general, urinary, respiratory, wound, bloodstream, gastrointestinal, skin/soft tissue, or other symptom fields are answered as none/no/absent and no other supporting evidence is present, state insufficient evidence or unlikely HAI. '
            'Strictly apply the criteria, but do not require every possible criterion. Laboratory evidence is not mandatory when the applicable HAI definition allows clinical diagnosis, patient symptoms/signs, imaging, device/procedure exposure, or other documented evidence, especially when a sample was not requested or collected. '
            'When declaring HAI, the Criteria line must clearly name the evidence used, such as timing from admission, symptoms/signs, clinical diagnosis, culture/lab evidence if available, imaging, device timing, surgery/procedure timing, or source evidence. '
            'For device-associated HAI support, use the device type together with date of device insertion and duration on device to judge exposure timing. Device timing is captured in the device exposure section of the form; use stable labels and do not mention question numbers. For SSI support, use the date of surgical procedure under Patient Risk Factors to judge the 30-day or implant-related 90-day window. '
            'If the available entries show no symptoms/signs, no clinical diagnosis, no microbiology, no imaging, and no device/procedure source evidence, say there is no evidence of HAI based on available evidence; do not say criteria are merely not fully documented. '
            'If culture or laboratory testing was not requested, not collected, or not done, say lab basis: no lab/culture done; do not say unclear lab basis. '
            'If device timing is documented but does not meet device-associated criteria, say device timing does not support device-associated HAI; do not ask for device timing again. '
            'Rare readmission exception: if the current admission is within 3 days after a previous admission, do not exclude HAI only because the current stay is less than 3 days. The patient may not have spent enough time outside care, so use the previous admission, discharge/readmission timing, symptoms, diagnosis, device exposure, procedure, and lab/clinical evidence together. For BSI, readmission within 3 days plus CVC/PVC exposure in the previous admission may support HAI only when BSI criteria are otherwise met. '
            'For SSI, do not classify a wound infection as surgical-site infection just because the patient has spent several days on admission or an organism was isolated. SSI must be linked to a surgical procedure and the affected tissue/organ-space. If the wound, abscess, bruise, cellulitis, ulcer, traumatic wound, or other skin/soft-tissue infection was present on admission or likely incubating at admission and is not related to an operation, classify as present-on-admission/SST/other as appropriate, or say insufficient evidence for SSI. '
            'A patient may have two or more HAIs at the same time, but only list multiple types when each type independently meets full timing, site-specific, clinical/laboratory, and device/procedure criteria. Do not combine weak evidence across sites to create multiple HAIs. '
            'Answer in exactly five concise lines using this structure: '
            'HAI status: Yes, No, or Insufficient evidence. '
            'Likely type: one or more proven types, or not clear. '
            'Criteria: one clear IPC sentence naming the decisive evidence used. '
            'Still needed: one plain sentence, or None obvious. '
            'Suggested answers: HAI yes/no; lab basis yes/no/unclear; type/subtype(s) only if each meets criteria. '
            'Keep Criteria under 35 words and other lines under 22 words. Use simple IPC language. Do not use markdown, bullets, asterisks, hashtags, question numbers, field IDs, or treatment instructions. '
            'If evidence is insufficient, do not list form questions. State only the criteria gap and one key evidence item needed.\n\n'
            'HAI criteria guide:\n${_haiDefinitionDecisionContext()}\n\n'
            'Additional flowchart criteria: '
            'BSI: recognized pathogen in blood culture, or common skin contaminant in two positive blood cultures with fever, chills, or hypotension; source may be CVC, PVC, secondary infection, unknown, or no information. '
            'UTI: clinical signs such as fever, urgency, frequency, dysuria, suprapubic tenderness; UTI-A requires urine culture confirmation, UTI-B may use pyuria, dipstick, Gram stain, repeated cultures, physician diagnosis, or treatment. '
            'SSI: superficial, deep, or organ-space infection within 30 days after operation, or 90 days with implant, with purulence, culture, abscess/evidence, wound opening with symptoms, or clinician diagnosis. The infection must be related to the surgical procedure; pre-existing or admission-onset abscess, cellulitis, bruising, traumatic wound, ulcer, or non-operative wound infection should not be counted as SSI even when culture is positive. '
            'Pneumonia: compatible X-ray/CT, general signs, pulmonary signs, and microbiologic confirmation/suspicion or clinical criteria. VAP requires ventilator exposure timing. '
            'SYS-CSEP: severe treated infection with fever, chills, or hypotension, antimicrobial treatment, and no positive blood culture because resources unavailable, culture not done, or no organism detected.\n\n'
            'Known criteria gaps from current form: ${_simpleHaiMissingItems(missingItems).isEmpty ? 'None obvious from entered fields' : _simpleHaiMissingItems(missingItems).join(', ')}.\n\n'
            'Current surveillance type: ${widget.surveillanceType}\n'
            'Selected targeted infection type: ${widget.infectionType}\n'
            'Entered patient data before Patient HAIs decision:\n$context',
      );
      final cleaned = _compactHaiDecisionSupportText(response, missingItems);
      return cleaned.isEmpty
          ? _fallbackHaiDecisionSupport(missingItems)
          : cleaned;
    } catch (_) {
      return _fallbackHaiDecisionSupport(missingItems);
    }
  }

  Widget _buildHaiField(HaiQuestionnaireField field) {
    if (_isHaiTemplateRepeatField(field)) {
      return _buildHaiAntimicrobialBankField(field);
    }

    if (field.type == 'note') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border(
            left: BorderSide(color: Colors.red.shade700, width: 4),
          ),
        ),
        child: Text(
          field.label,
          style: TextStyle(
            color: Colors.red.shade900,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final prompt = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: field.label),
          if (field.required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red.shade700),
            ),
        ],
      ),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    );

    if (field.type == 'select') {
      final seenValues = <String>{};
      final menuItems = <DropdownMenuItem<String>>[];
      for (final option in field.options) {
        if (!seenValues.add(option.value)) continue;
        menuItems.add(
          DropdownMenuItem<String>(
            value: option.value,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
        );
      }
      final currentValue = _haiAnswers[field.name] as String?;
      final valueExists =
          currentValue == null ||
          menuItems.where((item) => item.value == currentValue).length == 1;
      if (field.options.length > 12) {
        final selectedOption = field.options
            .where((option) => option.value == currentValue)
            .firstOrNull;
        return FormField<String>(
          initialValue: valueExists ? currentValue : null,
          validator: (value) =>
              field.required && (value == null || value.isEmpty)
              ? 'Required'
              : null,
          builder: (formField) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              prompt,
              const SizedBox(height: 8),
              InputDecorator(
                decoration: InputDecoration(
                  hintText: 'Select an option',
                  border: const OutlineInputBorder(),
                  errorText: formField.errorText,
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(selectedOption?.label ?? 'Select an option'),
                  trailing: const Icon(Icons.search),
                  onTap: () async {
                    final picked = await _pickHaiOption(
                      title: field.label,
                      options: field.options,
                    );
                    if (picked == null) return;
                    setState(() {
                      _haiAnswers[field.name] = picked.value;
                      _syncHaiTemplateCalculations();
                    });
                    formField.didChange(picked.value);
                  },
                ),
              ),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          prompt,
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: valueExists ? currentValue : null,
            isExpanded: true,
            decoration: const InputDecoration(
              hintText: 'Select an option',
              border: OutlineInputBorder(),
            ),
            items: menuItems,
            onChanged: (value) => setState(() {
              _haiAnswers[field.name] = value;
              _syncHaiTemplateCalculations();
            }),
            validator: (value) =>
                field.required && (value == null || value.isEmpty)
                ? 'Required'
                : null,
          ),
        ],
      );
    }

    if (field.type == 'multiselect') {
      final selected = (_haiAnswers[field.name] as List<dynamic>? ?? [])
          .map((item) => '$item')
          .toSet();
      return FormField<Set<String>>(
        validator: (_) =>
            field.required && selected.isEmpty ? 'Required' : null,
        builder: (formField) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            prompt,
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: formField.hasError ? Colors.red : Colors.grey.shade400,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: field.options
                    .map(
                      (option) => CheckboxListTile(
                        dense: true,
                        title: Text(option.label),
                        value: selected.contains(option.value),
                        onChanged: (checked) {
                          setState(() {
                            if (checked ?? false) {
                              selected.add(option.value);
                            } else {
                              selected.remove(option.value);
                            }
                            _haiAnswers[field.name] = selected.toList();
                            _syncHaiTemplateCalculations();
                            formField.didChange(selected);
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            if (formField.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  formField.errorText!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
          ],
        ),
      );
    }

    if (field.type == 'date') {
      final value = _haiDates[field.name];
      return FormField<DateTime>(
        validator: (_) => field.required && value == null ? 'Required' : null,
        builder: (formField) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            prompt,
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(
                value == null
                    ? 'Select date'
                    : DateFormat('MMM d, y').format(value),
              ),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: value ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) {
                  setState(() {
                    _haiDates[field.name] = picked;
                    _haiAnswers[field.name] = Timestamp.fromDate(picked);
                    _syncHaiTemplateCalculations();
                  });
                  formField.didChange(picked);
                }
              },
            ),
            if (formField.hasError)
              Text(
                formField.errorText!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
          ],
        ),
      );
    }

    final controller = _haiTextControllers.putIfAbsent(
      field.name,
      () => TextEditingController(text: '${_haiAnswers[field.name] ?? ''}'),
    );
    if (field.type == 'calculated') {
      _syncHaiTemplateCalculations();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          prompt,
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            readOnly: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              suffixText: 'days',
            ),
            validator: (value) =>
                field.required && (value == null || value.trim().isEmpty)
                ? 'Required'
                : null,
          ),
        ],
      );
    }
    final isRemarkField =
        field.name.toLowerCase() == 'remark' ||
        field.label.toLowerCase().contains('remark');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        prompt,
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: field.type == 'integer' || field.type == 'decimal'
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          minLines: isRemarkField ? 3 : 1,
          maxLines: isRemarkField ? 4 : 1,
          onChanged: (value) => _haiAnswers[field.name] = value.trim(),
          validator: (value) =>
              field.required && (value == null || value.trim().isEmpty)
              ? 'Required'
              : null,
        ),
        if (isRemarkField) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _isGeneratingRemarkSuggestion
                  ? null
                  : () => _suggestHaiRemark(field.name, controller),
              icon: _isGeneratingRemarkSuggestion
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: const Text('AI remark suggestion'),
            ),
          ),
        ],
      ],
    );
  }

  bool _isHaiTemplateRepeatField(HaiQuestionnaireField field) {
    final behavior = '${field.metadata['behavior'] ?? ''}';
    return behavior == 'antimicrobial_bank' || behavior == 'repeat_group';
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => '$item')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _stringDynamicMap(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(value);
  }

  Widget _buildHaiAntimicrobialBankField(HaiQuestionnaireField field) {
    final selected = (_haiAnswers[field.name] as List<dynamic>? ?? [])
        .map((item) => '$item')
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final selectedSet = selected.toSet();
    final detailsKey =
        '${field.metadata['detailsAnswerKey'] ?? '${field.name}_details'}';
    final rawDetails = _stringDynamicMap(_haiAnswers[detailsKey]);
    final childFields = (field.metadata['childFields'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final usesPicker = field.options.isNotEmpty;
    final isLinkAction = '${field.metadata['buttonVariant'] ?? ''}' == 'link';
    final actionLabel = '${field.metadata['addButtonLabel'] ?? 'Add'}';

    return FormField<List<String>>(
      validator: (_) {
        if (field.required && selected.isEmpty) return 'Required';
        for (final antimicrobial in selected) {
          final antimicrobialDetails = _stringDynamicMap(
            rawDetails[antimicrobial],
          );
          for (final child in childFields) {
            if (!_isHaiAntimicrobialChildVisible(
              child: child,
              antimicrobialValue: antimicrobial,
              details: antimicrobialDetails,
              parentFieldName: field.name,
            )) {
              continue;
            }
            if (child['required'] != true) continue;
            final key = '${child['key'] ?? ''}';
            if (key.isEmpty) continue;
            final rawValue = antimicrobialDetails[key];
            final value = rawValue is List
                ? rawValue.where((item) => '$item'.trim().isNotEmpty).toList()
                : '${rawValue ?? ''}'.trim();
            if (value is List && value.isEmpty) {
              return 'Complete details for every antimicrobial';
            }
            if (value is String && value.isEmpty) {
              return 'Complete details for every antimicrobial';
            }
          }
        }
        return null;
      },
      builder: (formField) {
        final available = field.options
            .where((option) => !selectedSet.contains(option.value))
            .toList();
        Future<void> addRepeatItem() async {
          final picked = usesPicker
              ? await _pickHaiAntimicrobial(field: field, options: available)
              : null;
          if (usesPicker && picked == null) return;
          final value =
              picked?.value ??
              '${field.name}_${DateTime.now().microsecondsSinceEpoch}';
          final title =
              picked?.label ??
              '${field.metadata['itemTitlePrefix'] ?? 'Item'} ${selected.length + 1}';
          final updatedSelected = [...selected, value];
          final updatedDetails = Map<String, dynamic>.from(rawDetails)
            ..putIfAbsent(value, () => <String, dynamic>{'__title': title});
          setState(() {
            _haiAnswers[field.name] = updatedSelected;
            _haiAnswers[detailsKey] = updatedDetails;
            _syncHaiTemplateCalculations();
          });
          formField.didChange(updatedSelected);
        }

        final VoidCallback? addAction = usesPicker && available.isEmpty
            ? null
            : () {
                addRepeatItem();
              };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: field.label),
                  if (field.required)
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                ],
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            if (isLinkAction)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: addAction,
                  icon: const Icon(Icons.add),
                  label: Text(actionLabel),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: Colors.teal.shade800,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: addAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel),
              ),
            if (selected.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...selected.map((value) {
                final option = field.options
                    .where((item) => item.value == value)
                    .firstOrNull;
                final title =
                    option?.label ??
                    '${_stringDynamicMap(rawDetails[value])['__title'] ?? value}';
                return Padding(
                  key: ValueKey('$detailsKey-card-$value'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove antimicrobial',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                final updatedSelected = selected
                                    .where((item) => item != value)
                                    .toList();
                                final updatedDetails =
                                    Map<String, dynamic>.from(rawDetails)
                                      ..remove(value);
                                setState(() {
                                  _haiAnswers[field.name] = updatedSelected;
                                  _haiAnswers[detailsKey] = updatedDetails;
                                  _syncHaiTemplateCalculations();
                                });
                                formField.didChange(updatedSelected);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...childFields
                            .where(
                              (child) => _isHaiAntimicrobialChildVisible(
                                child: child,
                                antimicrobialValue: value,
                                details: _stringDynamicMap(rawDetails[value]),
                                parentFieldName: field.name,
                              ),
                            )
                            .map(
                              (child) => KeyedSubtree(
                                key: ValueKey(
                                  '$detailsKey-child-$value-${child['key']}',
                                ),
                                child: _buildHaiAntimicrobialChildField(
                                  detailsKey: detailsKey,
                                  antimicrobialValue: value,
                                  details: rawDetails,
                                  child: child,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            if (formField.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  formField.errorText!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<HaiQuestionnaireOption?> _pickHaiAntimicrobial({
    required HaiQuestionnaireField field,
    required List<HaiQuestionnaireOption> options,
  }) {
    return _pickHaiOption(
      title: '${field.metadata['selectionTitle'] ?? 'Select option'}',
      options: options,
    );
  }

  Future<HaiQuestionnaireOption?> _pickHaiOption({
    required String title,
    required List<HaiQuestionnaireOption> options,
  }) {
    return showDialog<HaiQuestionnaireOption>(
      context: context,
      builder: (context) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = options.where((option) {
              final needle = query.trim().toLowerCase();
              if (needle.isEmpty) return true;
              return option.label.toLowerCase().contains(needle) ||
                  option.value.toLowerCase().contains(needle);
            }).toList();
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setDialogState(() => query = value),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No matching item'),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final option = filtered[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(option.label),
                                  onTap: () => Navigator.pop(context, option),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _isHaiAntimicrobialChildVisible({
    required Map<String, dynamic> child,
    required String antimicrobialValue,
    required Map<String, dynamic> details,
    required String parentFieldName,
  }) {
    final relevant = '${child['relevant'] ?? ''}'.trim();
    if (relevant.isEmpty) return true;
    return relevant
        .split(RegExp(r'\s+or\s+', caseSensitive: false))
        .any(
          (orClause) => orClause
              .split(RegExp(r'\s+and\s+', caseSensitive: false))
              .every(
                (clause) => _haiAntimicrobialChildConditionMatches(
                  clause: clause,
                  antimicrobialValue: antimicrobialValue,
                  details: details,
                  parentFieldName: parentFieldName,
                ),
              ),
        );
  }

  bool _haiAntimicrobialChildConditionMatches({
    required String clause,
    required String antimicrobialValue,
    required Map<String, dynamic> details,
    required String parentFieldName,
  }) {
    final selectedMatch =
        RegExp(
          r"""selected\(\$\{([^}]+)\},\s*'((?:\\.|[^'])*)'\)""",
        ).firstMatch(clause) ??
        RegExp(
          r'''selected\(\$\{([^}]+)\},\s*"((?:\\.|[^"])*)"\)''',
        ).firstMatch(clause);
    if (selectedMatch != null) {
      final fieldName = selectedMatch.group(1) ?? '';
      final expected = _haiRelevantLiteral(selectedMatch.group(2));
      if (fieldName == parentFieldName) {
        return _haiComparableToken(antimicrobialValue) ==
            _haiComparableToken(expected);
      }
      if (!details.containsKey(fieldName)) {
        return _haiAnswerMatchesExpected(fieldName, expected);
      }
      return _haiDetailValueMatches(details[fieldName], expected);
    }

    final equalsMatch =
        RegExp(
          r"""\$\{([^}]+)\}\s*(!=|=)\s*'((?:\\.|[^'])*)'""",
        ).firstMatch(clause) ??
        RegExp(
          r'''\$\{([^}]+)\}\s*(!=|=)\s*"((?:\\.|[^"])*)"''',
        ).firstMatch(clause);
    if (equalsMatch == null) return false;
    final fieldName = equalsMatch.group(1) ?? '';
    final expected = _haiRelevantLiteral(equalsMatch.group(3));
    final matches = fieldName == parentFieldName
        ? _haiComparableToken(antimicrobialValue) ==
              _haiComparableToken(expected)
        : details.containsKey(fieldName)
        ? _haiDetailValueMatches(details[fieldName], expected)
        : _haiAnswerMatchesExpected(fieldName, expected);
    if (equalsMatch.group(2) == '!=') return !matches;
    return matches;
  }

  bool _haiDetailValueMatches(dynamic rawValue, String expected) {
    if (rawValue == null) return expected.trim().isEmpty;
    if (rawValue is Iterable) {
      if (rawValue.isEmpty) return expected.trim().isEmpty;
      return rawValue.any((item) => _haiDetailValueMatches(item, expected));
    }
    return _haiComparableToken('${rawValue ?? ''}') ==
        _haiComparableToken(expected);
  }

  Widget _buildHaiAntimicrobialChildField({
    required String detailsKey,
    required String antimicrobialValue,
    required Map<String, dynamic> details,
    required Map<String, dynamic> child,
  }) {
    final key = '${child['key'] ?? ''}';
    if (key.isEmpty) return const SizedBox.shrink();
    final label = '${child['label'] ?? key}';
    final required = child['required'] == true;
    final type = '${child['type'] ?? 'short_text'}';
    final antimicrobialDetails = _stringDynamicMap(details[antimicrobialValue]);
    final currentValue = '${antimicrobialDetails[key] ?? ''}';
    final inputDecoration = InputDecoration(
      labelText: required ? '$label *' : label,
      border: const OutlineInputBorder(),
    );

    void updateValue(String? value) {
      antimicrobialDetails[key] = value?.trim() ?? '';
      details[antimicrobialValue] = antimicrobialDetails;
      _haiAnswers[detailsKey] = details;
    }

    if (type == 'calculated') {
      final calculatedValue = _haiRepeatCalculatedValue(
        child: child,
        details: antimicrobialDetails,
      );
      if (calculatedValue != null &&
          antimicrobialDetails[key] != calculatedValue) {
        antimicrobialDetails[key] = calculatedValue;
        details[antimicrobialValue] = antimicrobialDetails;
        _haiAnswers[detailsKey] = details;
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          key: ValueKey(
            '$detailsKey-$antimicrobialValue-$key-$calculatedValue',
          ),
          initialValue: calculatedValue ?? currentValue,
          readOnly: true,
          decoration: inputDecoration.copyWith(
            suffixIcon: const Icon(Icons.calculate_outlined),
          ),
        ),
      );
    }

    if (type == 'select' || type == 'multiple_choice') {
      final labels = _stringList(child['options']);
      final optionValues = _stringDynamicMap(child['optionValues']);
      final seenValues = <String>{};
      final menuItems = <DropdownMenuItem<String>>[];
      for (final optionLabel in labels) {
        final value =
            '${optionValues[optionLabel] ?? _stableOptionValue(optionLabel)}';
        if (!seenValues.add(value)) continue;
        menuItems.add(
          DropdownMenuItem<String>(
            value: value,
            child: Text(optionLabel, overflow: TextOverflow.ellipsis),
          ),
        );
      }
      final valueExists =
          menuItems.where((item) => item.value == currentValue).length == 1;
      if (labels.length > 12) {
        final options = <HaiQuestionnaireOption>[];
        final seenOptionValues = <String>{};
        for (final optionLabel in labels) {
          final value =
              '${optionValues[optionLabel] ?? _stableOptionValue(optionLabel)}';
          if (!seenOptionValues.add(value)) continue;
          options.add(HaiQuestionnaireOption(value, optionLabel));
        }
        final selectedOption = options
            .where((option) => option.value == currentValue)
            .firstOrNull;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InputDecorator(
            decoration: inputDecoration,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(selectedOption?.label ?? 'Select an option'),
              trailing: const Icon(Icons.search),
              onTap: () async {
                final picked = await _pickHaiOption(
                  title: label,
                  options: options,
                );
                if (picked == null) return;
                setState(() => updateValue(picked.value));
              },
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          value: valueExists ? currentValue : null,
          isExpanded: true,
          decoration: inputDecoration,
          items: menuItems,
          onChanged: (value) => setState(() => updateValue(value)),
        ),
      );
    }

    if (type == 'checkbox' || type == 'multiselect') {
      final selected = (antimicrobialDetails[key] as List<dynamic>? ?? [])
          .map((item) => '$item')
          .toSet();
      final labels = _stringList(child['options']);
      final optionValues = _stringDynamicMap(child['optionValues']);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InputDecorator(
          decoration: inputDecoration,
          child: Column(
            children: labels.map((optionLabel) {
              final optionValue =
                  '${optionValues[optionLabel] ?? _stableOptionValue(optionLabel)}';
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(optionLabel),
                value: selected.contains(optionValue),
                onChanged: (checked) {
                  setState(() {
                    if (checked ?? false) {
                      selected.add(optionValue);
                    } else {
                      selected.remove(optionValue);
                    }
                    antimicrobialDetails[key] = selected.toList();
                    details[antimicrobialValue] = antimicrobialDetails;
                    _haiAnswers[detailsKey] = details;
                  });
                },
              );
            }).toList(),
          ),
        ),
      );
    }

    if (type == 'date') {
      final parsedValue = _haiDateFromValue(antimicrobialDetails[key]);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InputDecorator(
          decoration: inputDecoration,
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(
                parsedValue == null
                    ? 'Select date'
                    : DateFormat('MMM d, y').format(parsedValue),
              ),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: parsedValue ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked == null) return;
                setState(() {
                  antimicrobialDetails[key] = Timestamp.fromDate(picked);
                  details[antimicrobialValue] = antimicrobialDetails;
                  _haiAnswers[detailsKey] = details;
                });
              },
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: currentValue,
        keyboardType: type == 'number'
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        minLines: type == 'long_text' ? 2 : 1,
        maxLines: type == 'long_text' ? 4 : 1,
        decoration: inputDecoration,
        onChanged: updateValue,
      ),
    );
  }

  String? _haiRepeatCalculatedValue({
    required Map<String, dynamic> child,
    required Map<String, dynamic> details,
  }) {
    final calculation = child['calculation'] is Map
        ? Map<String, dynamic>.from(child['calculation'] as Map)
        : const <String, dynamic>{};
    if ('${calculation['type'] ?? ''}' != 'days_since_date') return null;
    final sourceQuestionId =
        '${calculation['sourceQuestionId'] ?? calculation['sourceQuestion'] ?? ''}'
            .trim();
    if (sourceQuestionId.isEmpty) return null;
    final sourceDate = _haiDateFromValue(details[sourceQuestionId]);
    if (sourceDate == null) return null;
    final endQuestionId =
        '${calculation['endQuestionId'] ?? calculation['endQuestion'] ?? ''}'
            .trim();
    final endDate = endQuestionId.isEmpty
        ? null
        : _haiDateFromValue(details[endQuestionId]);
    return _haiDaysBetweenDates(
      sourceDate,
      endDate ?? DateTime.now(),
      inclusive: calculation['inclusive'] != false,
    );
  }

  Future<void> _suggestHaiRemark(
    String fieldName,
    TextEditingController controller,
  ) async {
    setState(() => _isGeneratingRemarkSuggestion = true);
    try {
      final suggestion = await _generateHaiRemarkSuggestion();
      if (suggestion.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No remark suggestion available yet')),
          );
        }
        return;
      }
      controller.text = suggestion;
      _haiAnswers[fieldName] = suggestion;
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('AI suggestion failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingRemarkSuggestion = false);
    }
  }

  Future<String> _generateHaiRemarkSuggestion() async {
    final summary = _haiRemarkContext();
    final definitionContext = _haiDefinitionDecisionContext();
    final missingItems = _haiMissingConclusionItems();
    if (summary.isEmpty) return _fallbackHaiRemarkSuggestion(missingItems);
    try {
      await GeminiService.initialize();
      final gemini = GeminiService.instance;
      if (!gemini.isConfigured) {
        return _fallbackHaiRemarkSuggestion(missingItems);
      }
      final response = await gemini.getChatResponse(
        userRole: 'nursing',
        userMessage:
            'Write one clear HAI surveillance remark for an IPC data collector. '
            'Say whether the entered data supports HAI, does not support HAI, or needs more evidence. '
            'Base the reasoning only on standard HAI surveillance definitions and the entered data. '
            'If multiple HAIs are possible, mention them only when each independently meets full criteria. '
            'If information is missing, name only one criteria gap and do not force a conclusion. '
            'Use simple IPC surveillance language. Do not give treatment orders. '
            'Do not use markdown, bullets, hashtags, asterisks, question numbers, field IDs, or unsupported certainty. '
            'Limit to one sentence of not more than 25 words.\n\n'
            'Definition guide:\n$definitionContext\n\n'
            'Known criteria gaps for conclusion: ${_simpleHaiMissingItems(missingItems).isEmpty ? 'None obvious from entered fields' : _simpleHaiMissingItems(missingItems).join(', ')}.\n\n'
            'Surveillance type: ${widget.surveillanceType}\n'
            'HAI type: ${widget.infectionType}\n'
            'Entered data:\n$summary',
      );
      final cleaned = _cleanIpcAiText(response).replaceAll('\n', ' ').trim();
      return cleaned.isEmpty
          ? _fallbackHaiRemarkSuggestion(missingItems)
          : cleaned;
    } catch (_) {
      return _fallbackHaiRemarkSuggestion(missingItems);
    }
  }

  String _haiDefinitionDecisionContext() {
    return [
      'Classify as HAI when the site-specific infection date of event occurs on or after hospital calendar day 3, where admission day is day 1.',
      'Classify as present on admission when the event is on admission day, the two days before admission, or the day after admission unless a healthcare device, procedure, surgery, or discharge rule supports HAI.',
      'If the current admission is less than 3 days after a previous admission, treat this as a rare continuity-of-care exception: the usual current-admission day-3 rule should not automatically exclude HAI. Use readmission timing, prior discharge timing, current symptoms/diagnosis, and documented healthcare exposure to decide strictly.',
      'Use the infection window concept: all required site-specific criteria should fit the relevant surveillance window.',
      'Do not require every possible criterion before declaring HAI. Use laboratory evidence when available, but clinical diagnosis, patient symptoms/signs, imaging, device timing, procedure timing, or severe-infection evidence may be enough when the applicable definition allows it.',
      'Whenever HAI is declared, clearly state the evidence used for the decision.',
      'A patient may have multiple concurrent HAIs only when each infection type independently meets full timing, site-specific, clinical/laboratory, and device/procedure criteria.',
      'Use location attribution and transfer rules: attribute to the inpatient location on date of event; if event occurs on transfer/discharge day or next day, attribute to the transferring or discharging location. Transfer rules do not apply to SSI.',
      'Also consider HAI when infection occurs up to 48 hours after hospital admission, up to 3 days after discharge, up to 30 days after an operation, or in a healthcare facility when admitted for another reason.',
      'BSI needs blood culture evidence: a recognized pathogen, or common skin contaminant with repeated positive culture plus compatible signs such as fever, chills, or hypotension. If readmitted within 3 days after a previous admission, prior CVC/PVC exposure may support BSI attribution only when BSI criteria are otherwise met.',
      'UTI needs urinary signs or symptoms plus appropriate urine culture evidence, and catheter-associated UTI needs catheter exposure for more than two consecutive days or recent removal. Use date of device insertion and duration on device to assess catheter/device exposure timing.',
      'SSI should relate to surgery and occur within 30 days, or up to 90 days when an implant is involved, with purulence, organism isolation, wound opening, abscess, or clinician diagnosis. SSI can occur before current-admission day 3, including on first wound opening, if linked to the operation and within the SSI window. Do not classify as SSI when abscess, cellulitis, bruising, traumatic wound, ulcer, or another non-operative wound/skin infection was present on admission or likely incubating at admission and is not linked to a surgical procedure, even if an organism is isolated.',
      'Use the date of surgical procedure under risk factors to judge SSI timing from operation to infection event.',
      'Pneumonia requires compatible clinical/radiologic features and microbiology or clinical criteria; ventilator association requires ventilator exposure timing using date of device insertion and duration on device where documented.',
      'SYS-CSEP is treated severe infection with fever, chills or hypotension plus antimicrobial treatment when blood culture is negative, unavailable, or not done.',
    ].join(' ');
  }

  String _haiDecisionSupportContext() {
    final entries = <String>[];
    final visibleAnswers = _visibleHaiAnswers();
    final admissionDate = _haiAdmissionDateForCurrentForm() ?? _admissionDate;
    final eventDate = _haiEventDateForCurrentForm() ?? _onsetDate;
    final eventEvidence = _haiClinicalEventEvidenceSummary();
    if (admissionDate != null) {
      entries.add(
        'Admission date: ${DateFormat('MMM d, y').format(admissionDate)}',
      );
    }
    if (eventDate != null) {
      entries.add(
        'Date of event or first symptoms: ${DateFormat('MMM d, y').format(eventDate)}',
      );
      final timingDate = admissionDate ?? _admissionDate;
      if (timingDate != null) {
        entries.add(
          'Days from admission to event: ${eventDate.difference(timingDate).inDays}',
        );
      }
    }
    entries.addAll(_haiExposureTimingContextEntries(eventDate: eventDate));
    entries.add(eventEvidence);
    for (final field in _haiFields) {
      if (field.section.toLowerCase().contains('patient hai')) continue;
      if (field.type == 'note') continue;
      final value = visibleAnswers[field.name];
      if (value == null || '$value'.trim().isEmpty) continue;
      entries.add('${field.label}: ${_haiAnswerLabel(field.name)}');
      if (entries.length >= 45) break;
    }
    if (_patientIdController.text.trim().isNotEmpty) {
      entries.insert(0, 'Hospital number: ${_patientIdController.text.trim()}');
    }
    if (_diagnosisController.text.trim().isNotEmpty) {
      entries.add('Clinical diagnosis: ${_diagnosisController.text.trim()}');
    }
    if (_symptomsController.text.trim().isNotEmpty) {
      entries.add('Symptoms: ${_symptomsController.text.trim()}');
    }
    if (_riskFactorsController.text.trim().isNotEmpty) {
      entries.add('Risk factors: ${_riskFactorsController.text.trim()}');
    }
    if (_organismController.text.trim().isNotEmpty) {
      entries.add('Organism: ${_organismController.text.trim()}');
    }
    return entries.join('\n');
  }

  String _haiRemarkContext() {
    final entries = <String>[];
    final visibleAnswers = _visibleHaiAnswers();
    final admissionDate = _haiAdmissionDateForCurrentForm() ?? _admissionDate;
    final eventDate = _haiEventDateForCurrentForm() ?? _onsetDate;
    final eventEvidence = _haiClinicalEventEvidenceSummary();
    if (admissionDate != null) {
      entries.add(
        'Admission date: ${DateFormat('MMM d, y').format(admissionDate)}',
      );
    }
    if (eventDate != null) {
      entries.add(
        'Date of event or first symptoms: ${DateFormat('MMM d, y').format(eventDate)}',
      );
      final timingDate = admissionDate ?? _admissionDate;
      if (timingDate != null) {
        entries.add(
          'Days from admission to event: ${eventDate.difference(timingDate).inDays}',
        );
      }
    }
    entries.addAll(_haiExposureTimingContextEntries(eventDate: eventDate));
    entries.add(eventEvidence);
    for (final field in _haiFields) {
      if (field.name == 'Remark') continue;
      final value = visibleAnswers[field.name];
      if (value == null || '$value'.trim().isEmpty) continue;
      entries.add('${field.label}: ${_haiAnswerLabel(field.name)}');
      if (entries.length >= 30) break;
    }
    return entries.join('\n');
  }

  String _haiClinicalEventEvidenceSummary() {
    final evidence = _haiClinicalEventEvidence();
    if (evidence['supporting']!.isNotEmpty) {
      return 'Clinical event evidence present: ${evidence['supporting']!.take(8).join('; ')}';
    }
    if (evidence['negative']!.isNotEmpty) {
      return 'Clinical event evidence not documented; negative symptom responses include ${evidence['negative']!.take(8).join('; ')}. The event date should be treated as timing only.';
    }
    return 'Clinical event evidence not documented yet. The event date should be treated as timing only until symptoms/signs, diagnosis, microbiology, imaging, device/procedure source, or severe-infection criteria are documented.';
  }

  bool _hasHaiClinicalEventEvidence() {
    return _haiClinicalEventEvidence()['supporting']!.isNotEmpty;
  }

  Map<String, List<String>> _haiClinicalEventEvidence() {
    final supporting = <String>[];
    final negative = <String>[];
    final visibleAnswers = _visibleHaiAnswers();
    for (final field in _haiFields) {
      if (field.type == 'note') continue;
      final label = field.label;
      final normalizedLabel = _normalizeHaiFormLookupText(label);
      final relevantLabel =
          _haiClinicalEvidenceLabel(normalizedLabel) ||
          _haiFormSemanticLabelMatches(normalizedLabel, 'symptoms') ||
          _haiFormSemanticLabelMatches(normalizedLabel, 'signs');
      if (!relevantLabel) continue;
      final rawValue = visibleAnswers[field.name] ?? _haiAnswers[field.name];
      final value = _haiAnswerLabel(field.name).trim();
      final normalizedValue = _normalizeHaiFormLookupText(value);
      if (value.isEmpty || value == 'null') continue;
      if (_haiNegativeClinicalEvidenceValue(normalizedValue, rawValue)) {
        negative.add('$label: $value');
      } else {
        supporting.add('$label: $value');
      }
    }

    for (final entry in {
      'Symptoms narrative': _symptomsController.text.trim(),
      'Clinical diagnosis': _diagnosisController.text.trim(),
      'Organism': _organismController.text.trim(),
    }.entries) {
      if (entry.value.isEmpty) continue;
      final normalized = _normalizeHaiFormLookupText(entry.value);
      if (_haiNegativeClinicalEvidenceValue(normalized, entry.value)) {
        negative.add('${entry.key}: ${entry.value}');
      } else {
        supporting.add('${entry.key}: ${entry.value}');
      }
    }

    return {'supporting': supporting, 'negative': negative};
  }

  bool _haiClinicalEvidenceLabel(String normalizedLabel) {
    const evidenceNeedles = [
      'general symptoms',
      'urinary symptoms',
      'respiratory symptoms',
      'wound symptoms',
      'surgical site symptoms',
      'pre-existing wound',
      'present on admission',
      'incubating',
      'bruise',
      'bruising',
      'bloodstream symptoms',
      'gastrointestinal symptoms',
      'skin and soft tissue symptoms',
      'cellulitis',
      'ulcer',
      'traumatic wound',
      'clinical signs',
      'fever',
      'chills',
      'hypotension',
      'dysuria',
      'suprapubic tenderness',
      'cough',
      'sputum',
      'oxygen',
      'radiology',
      'x ray',
      'chest x ray',
      'culture',
      'microbiology',
      'pathogen',
      'organism',
      'pus',
      'purulent',
      'wound discharge',
      'abscess',
      'clinician diagnosis',
      'clinical diagnosis',
      'severe infection',
      'source of infection',
      'previous admission',
      'prior admission',
      'readmission',
      're admission',
      'admitted within 3 days',
      'less than 3 days after previous admission',
      'date of discharge',
      'discharge date',
      'urinary catheter present',
      'central line present',
      'central venous catheter',
      'cvc',
      'peripheral venous catheter present',
      'pvc',
      'invasive ventilator present',
      'surgical procedure',
      'operation',
    ];
    return evidenceNeedles.any(
      (needle) => _haiFormSemanticLabelMatches(normalizedLabel, needle),
    );
  }

  bool _haiNegativeClinicalEvidenceValue(
    String normalizedValue,
    dynamic rawValue,
  ) {
    if (rawValue is Iterable) {
      final values = rawValue
          .map((item) => _normalizeHaiFormLookupText('$item'))
          .where((item) => item.isNotEmpty)
          .toList();
      if (values.isEmpty) return false;
      return values.every(_haiNegativeClinicalEvidenceText);
    }
    return _haiNegativeClinicalEvidenceText(normalizedValue);
  }

  bool _haiNegativeClinicalEvidenceText(String text) {
    if (text.isEmpty) return false;
    return text == 'none' ||
        text == 'no' ||
        text == 'nil' ||
        text == 'absent' ||
        text == 'not present' ||
        text == 'not documented' ||
        text == 'unknown' ||
        text == 'no symptoms' ||
        text == 'none selected' ||
        text == 'not applicable';
  }

  List<String> _simpleHaiMissingItems(List<String> missingItems) {
    final simplified = <String>[];
    for (final item in missingItems) {
      final text = item.toLowerCase();
      String simple;
      if (text.contains('clinical') ||
          text.contains('symptom') ||
          text.contains('sign') ||
          text.contains('diagnosis') ||
          text.contains('imaging')) {
        simple = 'clinical evidence';
      } else if (text.contains('culture') ||
          text.contains('microbiology') ||
          text.contains('pathogen') ||
          text.contains('sample')) {
        simple = 'culture evidence';
      } else if (text.contains('device') || text.contains('catheter')) {
        simple = 'device timing';
      } else if (text.contains('surgical') ||
          text.contains('surgery') ||
          text.contains('procedure')) {
        simple = 'procedure timing';
      } else if (text.contains('admission') || text.contains('event')) {
        simple = 'infection timing';
      } else if (text.contains('site') || text.contains('type')) {
        simple = 'infection site';
      } else if (text.contains('risk') || text.contains('exposure')) {
        simple = 'exposure history';
      } else if (text.contains('conclusion')) {
        simple = 'HAI answer';
      } else {
        simple = 'key evidence';
      }
      if (!simplified.contains(simple)) simplified.add(simple);
    }
    return simplified;
  }

  bool _hasNoHaiEvidenceFromCurrentForm() {
    final evidence = _haiClinicalEventEvidence();
    return evidence['supporting']!.isEmpty && evidence['negative']!.isNotEmpty;
  }

  bool _haiLabEvidenceNotDone() {
    final labValues = [
      _haiAnswerLabel('Culture_requested'),
      _haiAnswerLabel('The_HAIs_diagnosis_is_based_on'),
      _haiAnswerLabel('_48_Specify_Culture_Status'),
    ].map((value) => _normalizeHaiFormLookupText(value)).join(' ');
    if (labValues.trim().isEmpty) return false;
    const noLabNeedles = [
      'no',
      'not requested',
      'not collected',
      'not done',
      'not available',
      'sample not collected',
      'culture not done',
      'laboratory not done',
      'none',
      'nil',
    ];
    return noLabNeedles.any((needle) => labValues.contains(needle));
  }

  String _haiLabBasisSuggestion() {
    if (_haiLabEvidenceNotDone()) return 'lab basis no, no lab/culture done';
    final pathogen1 = _haiAnswerLabel('Pathogen_Identified').trim();
    final pathogen2 = _haiAnswerLabel('Pathogen_Identified_001').trim();
    final cultureBasis = _haiAnswerLabel(
      'The_HAIs_diagnosis_is_based_on',
    ).trim();
    if ((pathogen1.isNotEmpty && pathogen1 != 'null') ||
        (pathogen2.isNotEmpty && pathogen2 != 'null') ||
        (cultureBasis.isNotEmpty && cultureBasis != 'null')) {
      return 'lab basis yes if culture/lab evidence supports criteria';
    }
    return 'lab basis unclear only if lab status is not documented';
  }

  String _compactHaiDecisionSupportText(
    String response,
    List<String> missingItems,
  ) {
    final cleaned = _cleanIpcAiText(response).trim();
    if (cleaned.isEmpty) return '';
    if (!cleaned.toLowerCase().contains('insufficient')) return cleaned;

    final simpleMissing = _simpleHaiMissingItems(
      _filteredHaiMissingItems(missingItems),
    );
    final noHaiEvidence = _hasNoHaiEvidenceFromCurrentForm();
    final needed = simpleMissing.isEmpty
        ? 'clinical or lab evidence'
        : simpleMissing.take(2).join(' and ');
    final criteriaText = noHaiEvidence
        ? 'Criteria: Based on available evidence, there is no evidence of HAI.'
        : 'Criteria: Site-specific HAI criteria are not met by the entered evidence.';
    final stillNeededText = noHaiEvidence
        ? 'Still needed: None unless new symptoms, diagnosis, lab, device, or procedure evidence appears.'
        : 'Still needed: $needed.';
    final lines = cleaned.split('\n').take(5).toList();
    final compacted = <String>[];
    var hasCriteria = false;
    var hasStillNeeded = false;

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.startsWith('criteria') ||
          lower.startsWith('criteria supporting')) {
        compacted.add(criteriaText);
        hasCriteria = true;
      } else if (lower.startsWith('still needed') ||
          lower.startsWith('information still needed')) {
        compacted.add(stillNeededText);
        hasStillNeeded = true;
      } else if (lower.startsWith('suggested answers') && line.length > 110) {
        compacted.add(
          'Suggested answers: HAI ${noHaiEvidence ? 'no' : 'no/unclear'}; ${_haiLabBasisSuggestion()}; complete criteria first.',
        );
      } else {
        compacted.add(line);
      }
    }

    if (!hasCriteria) {
      compacted.insert(
        compacted.length > 2 ? 2 : compacted.length,
        criteriaText,
      );
    }
    if (!hasStillNeeded) {
      compacted.insert(
        compacted.length > 3 ? 3 : compacted.length,
        stillNeededText,
      );
    }
    return compacted.take(5).join('\n');
  }

  String _fallbackHaiDecisionSupport(List<String> missingItems) {
    final missing = _simpleHaiMissingItems(
      _filteredHaiMissingItems(missingItems),
    );
    final noHaiEvidence = _hasNoHaiEvidenceFromCurrentForm();
    final needed = missing.isEmpty
        ? 'clinical or lab evidence'
        : missing.take(2).join(' and ');
    return [
      'Likely HAI status: ${noHaiEvidence ? 'No' : 'Insufficient evidence'}.',
      'Most likely HAI type: Not clear from the entered data.',
      noHaiEvidence
          ? 'Criteria: Based on available evidence, there is no evidence of HAI.'
          : 'Criteria: Site-specific HAI criteria are not met by the entered evidence.',
      noHaiEvidence
          ? 'Information still needed: None unless new symptoms, diagnosis, lab, device, or procedure evidence appears.'
          : 'Information still needed: $needed.',
      'Suggested answers: HAI ${noHaiEvidence ? 'no' : 'no/unclear'}; ${_haiLabBasisSuggestion()}; complete criteria first.',
    ].join('\n');
  }

  List<String> _filteredHaiMissingItems(List<String> missingItems) {
    final device = _haiAnswerLabel('Type_of_Devices').trim();
    final deviceInsertionDate = _haiDeviceInsertionDateForCurrentForm();
    final deviceDuration = _haiDeviceDurationContext().trim();
    final hasDeviceTiming =
        device.isNotEmpty &&
        device != 'null' &&
        (deviceInsertionDate != null ||
            deviceDuration.isNotEmpty && deviceDuration != 'null');
    return missingItems.where((item) {
      final text = item.toLowerCase();
      if (_haiLabEvidenceNotDone() &&
          (text.contains('culture') ||
              text.contains('microbiology') ||
              text.contains('pathogen') ||
              text.contains('sample'))) {
        return false;
      }
      if (hasDeviceTiming &&
          (text.contains('device') || text.contains('catheter'))) {
        return false;
      }
      return true;
    }).toList();
  }

  List<String> _haiMissingPreDecisionItems() {
    final missing = <String>[];
    final admissionDate = _haiAdmissionDateForCurrentForm() ?? _admissionDate;
    final eventDate = _haiEventDateForCurrentForm() ?? _onsetDate;
    final hasClinicalEventEvidence = _hasHaiClinicalEventEvidence();
    final diagnosis = _haiAnswerLabel('_13_Clinical_diagnosis').trim();
    final riskType = _haiAnswerLabel('Type_of_risk').trim();
    final surgery = _haiSurgicalProcedureContext();
    final device = _haiAnswerLabel('Type_of_Devices').trim();
    final deviceInsertionDate = _haiDeviceInsertionDateForCurrentForm();
    final deviceDuration = _haiDeviceDurationContext().trim();
    final surgicalProcedureDate = _haiSurgicalProcedureDateForCurrentForm();
    final hasNarrativeEvidence =
        _symptomsController.text.trim().isNotEmpty ||
        _diagnosisController.text.trim().isNotEmpty ||
        diagnosis.isNotEmpty && diagnosis != 'null';

    if (admissionDate == null || '$admissionDate'.trim().isEmpty) {
      missing.add('admission date or timing from admission');
    }
    if (eventDate == null) {
      missing.add('date of first symptoms or infection event date');
    }
    if (!hasNarrativeEvidence || !hasClinicalEventEvidence) {
      missing.add(
        'clinical event evidence such as symptoms/signs, diagnosis, microbiology, imaging, device/procedure source, or severe-infection criteria',
      );
    }
    if (riskType.isEmpty || riskType == 'null') {
      missing.add('risk factor or exposure history');
    }
    if ((surgery.isEmpty || surgery == 'null') &&
        (device.isEmpty || device == 'null')) {
      missing.add('device, procedure, surgery, or exposure timing if relevant');
    }
    if (device.isNotEmpty &&
        device != 'null' &&
        deviceInsertionDate == null &&
        (deviceDuration.isEmpty || deviceDuration == 'null')) {
      missing.add('date of device insertion or duration on device');
    }
    if (surgery.isNotEmpty &&
        surgery != 'null' &&
        surgicalProcedureDate == null) {
      missing.add('date of surgical procedure');
    }
    final selectedType = widget.infectionType.toLowerCase();
    final cultureRequested = _normalizeHaiFormLookupText(
      _haiAnswerLabel('Culture_requested'),
    );
    final cultureNeeded =
        selectedType.contains('bsi') ||
        selectedType.contains('bloodstream') ||
        cultureRequested.contains('yes') ||
        cultureRequested.contains('requested');
    if (cultureNeeded && !_haiLabEvidenceNotDone()) {
      missing.add(
        'microbiology/culture evidence where required by the selected infection type',
      );
    }
    return missing.toSet().toList();
  }

  List<String> _haiMissingConclusionItems() {
    final missing = <String>[];
    final admissionDate = _haiAdmissionDateForCurrentForm() ?? _admissionDate;
    final eventDate = _haiEventDateForCurrentForm() ?? _onsetDate;
    final hasClinicalEventEvidence = _hasHaiClinicalEventEvidence();
    final haiConclusion = _haiAnswerLabel('HAIs').trim();
    final haiType = _haiAnswerLabel('Type_of_HAIs').trim();
    final cultureBasis = _haiAnswerLabel(
      'The_HAIs_diagnosis_is_based_on',
    ).trim();
    final cultureRequested = _haiAnswerLabel('Culture_requested').trim();
    final sampleDate = _haiSampleDateForCurrentForm();
    final pathogen1 = _haiAnswerLabel('Pathogen_Identified').trim();
    final pathogen2 = _haiAnswerLabel('Pathogen_Identified_001').trim();
    final device = _haiAnswerLabel('Type_of_Devices').trim();
    final surgery = _haiSurgicalProcedureContext();
    final deviceInsertionDate = _haiDeviceInsertionDateForCurrentForm();
    final deviceDuration = _haiDeviceDurationContext().trim();
    final surgicalProcedureDate = _haiSurgicalProcedureDateForCurrentForm();

    if (admissionDate == null || '$admissionDate'.trim().isEmpty) {
      missing.add('admission date or timing from admission');
    }
    if (eventDate == null) {
      missing.add('date of first symptoms or infection event date');
    }
    if (haiConclusion.isEmpty || haiConclusion == 'null') {
      missing.add('HAI conclusion field');
    }
    if (haiType.isEmpty || haiType == 'null') {
      missing.add('site/type of HAI');
    }
    if (!hasClinicalEventEvidence) {
      missing.add(
        'clinical event evidence confirming infection beyond the event date alone',
      );
    }
    if ((cultureBasis.isEmpty || cultureBasis == 'null') &&
        (cultureRequested.isEmpty || cultureRequested == 'null')) {
      missing.add('culture or diagnostic basis');
    }
    if (sampleDate == null || '$sampleDate'.trim().isEmpty) {
      missing.add('sample collection date where laboratory evidence applies');
    }
    if ((pathogen1.isEmpty || pathogen1 == 'null') &&
        (pathogen2.isEmpty || pathogen2 == 'null')) {
      missing.add('pathogen or microbiology result where applicable');
    }
    if (widget.infectionType != 'Routine HAI' &&
        widget.infectionType != 'Targeted HAI' &&
        !widget.infectionType.toLowerCase().contains('ssi') &&
        (device.isEmpty || device == 'null') &&
        (surgery.isEmpty || surgery == 'null')) {
      missing.add('device/procedure exposure where relevant');
    }
    if (device.isNotEmpty &&
        device != 'null' &&
        deviceInsertionDate == null &&
        (deviceDuration.isEmpty || deviceDuration == 'null')) {
      missing.add('date of device insertion or duration on device');
    }
    if ((widget.infectionType.toLowerCase().contains('ssi') ||
            surgery.isNotEmpty && surgery != 'null') &&
        surgicalProcedureDate == null) {
      missing.add('date of surgical procedure');
    }
    return missing.toSet().toList();
  }

  String _fallbackHaiRemarkSuggestion(List<String> missingItems) {
    final hospitalNumber = _haiHospitalNumberForDuplicateCheck();
    final haiConclusion = _haiAnswerLabel('HAIs').trim();
    final haiType = _haiAnswerLabel('Type_of_HAIs').trim().isNotEmpty
        ? _haiAnswerLabel('Type_of_HAIs')
        : widget.infectionType;
    final pathogen = _haiAnswerLabel('Pathogen_Identified').trim().isNotEmpty
        ? _haiAnswerLabel('Pathogen_Identified')
        : _haiAnswerLabel('Pathogen_Identified_001');
    if (missingItems.isNotEmpty) {
      final missing = _simpleHaiMissingItems(missingItems);
      final evidence = haiConclusion.toLowerCase().contains('no')
          ? 'does not meet documented HAI criteria for $haiType'
          : 'needs IPC review for possible $haiType';
      return [
        if (hospitalNumber != null) 'Patient $hospitalNumber:',
        evidence,
        if (pathogen.trim().isNotEmpty && pathogen != 'null')
          'with $pathogen noted',
        'but ${missing.isEmpty ? 'key evidence' : missing.first} is still needed.',
      ].join(' ');
    }
    final parts = [
      if (hospitalNumber != null) 'Patient $hospitalNumber',
      haiConclusion.toLowerCase().contains('no')
          ? 'does not meet documented HAI criteria for $haiType'
          : 'has evidence supporting possible $haiType HAI',
      if (pathogen.trim().isNotEmpty && pathogen != 'null')
        'with $pathogen noted',
      'by entered surveillance criteria.',
    ];
    return parts.join(' ');
  }

  Map<String, dynamic> _buildRecordData(String submissionStatus) {
    _syncHaiTemplateCalculations();
    final haiAnswers = _visibleHaiAnswers();
    final eventDate = _haiEventDateForCurrentForm() ?? _onsetDate;
    final admissionDate = _haiAdmissionDateForCurrentForm() ?? _admissionDate;
    final haiSectionStatus = _haiSectionStatus();
    final pendingSections = haiSectionStatus.entries
        .where((entry) => entry.value != 'complete')
        .map((entry) => entry.key)
        .toList();
    final historicalRemark =
        '${_haiAnswers['Historical_Remark'] ?? widget.initialData?['historicalRemark'] ?? ''}'
            .trim();
    final changeEntry = {
      'staffId': widget.staffId,
      'staffName': widget.staffName,
      'action': submissionStatus == 'Final' ? 'final_submit' : 'save_draft',
      'at': Timestamp.now(),
      'sectionStatus': haiSectionStatus,
    };
    return {
      'facilityId': widget.facilityId,
      'facilityName': widget.facilityName,
      'surveillanceType': widget.surveillanceType,
      'infectionType': widget.infectionType,
      'patientId': _patientIdController.text.trim().isNotEmpty
          ? _patientIdController.text.trim()
          : '${haiAnswers['_9_Hospital_number'] ?? ''}',
      'patientName': _patientNameController.text.trim(),
      'age':
          int.tryParse(_ageController.text.trim()) ??
          int.tryParse('${haiAnswers['_10_Patient_Age'] ?? ''}'),
      'gender': _selectedGender ?? _haiAnswerLabel('_11_Patient_Gender'),
      'department': _selectedDepartment ?? _haiAnswerLabel('Department'),
      'severity': _selectedSeverity,
      'eventDate': eventDate == null ? null : Timestamp.fromDate(eventDate),
      'onsetDate': eventDate == null ? null : Timestamp.fromDate(eventDate),
      'admissionDate': admissionDate == null
          ? null
          : Timestamp.fromDate(admissionDate),
      'daysSinceAdmission': eventDate != null && admissionDate != null
          ? eventDate.difference(admissionDate).inDays
          : _daysSinceAdmission,
      'deviceType': _selectedDeviceType,
      'diagnosis': _diagnosisController.text.trim().isNotEmpty
          ? _diagnosisController.text.trim()
          : '${haiAnswers['_13_Clinical_diagnosis'] ?? ''}',
      'symptoms': _symptomsController.text.trim(),
      'riskFactors': _riskFactorsController.text.trim(),
      'labConfirmed': _labConfirmed,
      'organism': _organismController.text.trim(),
      'clinicalOutcome': _haiAnswerLabel('Clinical_Outcome'),
      'clinicalOutcomeCode': haiAnswers['Clinical_Outcome'],
      'otherClinicalOutcome': haiAnswers['Other_Clinical_Outcome'],
      'outcomeDate': _haiDates['Outcome_Date'] == null
          ? null
          : Timestamp.fromDate(_haiDates['Outcome_Date']!),
      'deathHaiContribution': _haiAnswerLabel('HAI_Contributed_To_Death'),
      'deathHaiContributionCode': haiAnswers['HAI_Contributed_To_Death'],
      'deathRelationship': _haiAnswerLabel('HAI_Relationship_To_Death'),
      'deathRelationshipCode': haiAnswers['HAI_Relationship_To_Death'],
      if (historicalRemark.isNotEmpty) 'historicalRemark': historicalRemark,
      'interventions': _interventionsController.text.trim(),
      'notes': _notesController.text.trim(),
      'reportedBy': widget.initialData?['reportedBy'] ?? widget.staffName,
      'reportedById': widget.initialData?['reportedById'] ?? widget.staffId,
      'createdBy': widget.initialData?['createdBy'] ?? widget.staffName,
      'createdById': widget.initialData?['createdById'] ?? widget.staffId,
      'submissionStatus': submissionStatus,
      'status': submissionStatus == 'Draft' ? 'Draft' : 'Active',
      'dataStatus': widget.initialData?['dataStatus'] ?? 'Raw Data',
      'isFinal': submissionStatus == 'Final',
      if (submissionStatus == 'Final') ...{
        'finalizedBy': widget.staffName,
        'finalizedById': widget.staffId,
        'finalizedAt': FieldValue.serverTimestamp(),
      },
      'sectionStatus': haiSectionStatus,
      'pendingSections': pendingSections,
      'completedSections': haiSectionStatus.entries
          .where((entry) => entry.value == 'complete')
          .map((entry) => entry.key)
          .toList(),
      'questionnaireVersion': 'hai-xlsform-v1',
      'haiQuestionnaireResponses': haiAnswers,
      'haiQuestionnaireResponseLabels': {
        for (final key in haiAnswers.keys) key: _haiAnswerLabel(key),
      },
      'haiQuestionnaireQuestionLabels': {
        for (final field in _haiFields) field.name: field.label,
      },
      'haiQuestionnaireDates': {
        for (final entry in _haiDates.entries)
          entry.key: Timestamp.fromDate(entry.value),
      },
      'updatedAt': FieldValue.serverTimestamp(),
      'lastUpdatedBy': widget.staffName,
      'lastUpdatedById': widget.staffId,
      'changeHistory': FieldValue.arrayUnion([changeEntry]),
    };
  }

  Future<void> _saveHAIReport({required bool asDraft}) async {
    _syncHaiTemplateCalculations();
    if (!asDraft && !_formKey.currentState!.validate()) return;
    if (!asDraft && !_validateClinicalOutcome()) return;
    if (!_validateHaiNumericValues()) return;

    if (!_isWorkbookHaiForm() && !asDraft && _onsetDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select onset date')));
      return;
    }

    final hospitalNumber = _haiHospitalNumberForDuplicateCheck();
    if (hospitalNumber != null &&
        await _haiHospitalNumberAlreadyExists(hospitalNumber)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'A matching HAI event already exists for hospital number $hospitalNumber and this admission/infection type.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final status = asDraft ? 'Draft' : 'Final';
      final data = _buildRecordData(status);
      final formId =
          widget.initialData?['formId'] as String? ??
          await SurveillanceFormIdService.nextFormId(
            facilityId: widget.facilityId,
            surveillanceCode:
                'ipc_hai_${widget.surveillanceType == 'Routine HAI Surveillance' ? 'routine' : widget.infectionType}',
          );
      data['formId'] = formId;
      final collection = FirebaseFirestore.instance.collection(
        'hai_surveillance',
      );
      if (widget.documentId == null) {
        await collection.add({
          ...data,
          'reportedDate': FieldValue.serverTimestamp(),
        });
      } else {
        await collection.doc(widget.documentId).update(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              asDraft
                  ? 'Progress saved successfully'
                  : 'HAI surveillance data submitted successfully',
            ),
          ),
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

  bool _validateClinicalOutcome() {
    final outcome = '${_haiAnswers['Clinical_Outcome'] ?? ''}'.trim();
    if (outcome == 'other' &&
        '${_haiAnswers['Other_Clinical_Outcome'] ?? ''}'.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please specify the other clinical outcome'),
        ),
      );
      return false;
    }
    final outcomeDate = _haiDates['Outcome_Date'];
    if (outcome == 'died' && outcomeDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select date of death/outcome date'),
        ),
      );
      return false;
    }
    if (_admissionDate != null &&
        outcomeDate != null &&
        outcomeDate.isBefore(_startOfDay(_admissionDate!))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Outcome date cannot be earlier than admission date'),
        ),
      );
      return false;
    }
    return true;
  }

  bool _validateHaiNumericValues() {
    for (final field in _haiFields) {
      if (field.type != 'integer' && field.type != 'decimal') continue;
      final value = _haiAnswers[field.name];
      if (value == null || '$value'.trim().isEmpty) continue;
      final number = num.tryParse('$value');
      if (number == null) continue;
      if (number < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${field.label} cannot be less than zero.'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }
    return true;
  }

  String? _haiHospitalNumberForDuplicateCheck() {
    final values = [
      _haiAnswers['_9_Hospital_number'],
      _haiAnswers['Hospital_number'],
      _patientIdController.text,
      widget.initialData?['patientId'],
    ];
    for (final value in values) {
      final text = '$value'.trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return null;
  }

  Future<bool> _haiHospitalNumberAlreadyExists(String hospitalNumber) async {
    final normalized = hospitalNumber.trim().toLowerCase();
    final currentSignature = _haiDuplicateEventSignature(
      infectionType: widget.infectionType,
      haiType: _haiAnswerLabel('Type_of_HAIs'),
      admissionDate: _admissionDate,
    );
    if (currentSignature.trim().isEmpty) return false;
    final snapshot = await FirebaseFirestore.instance
        .collection('hai_surveillance')
        .where('facilityId', isEqualTo: widget.facilityId)
        .get();
    for (final doc in snapshot.docs) {
      if (widget.documentId != null && doc.id == widget.documentId) continue;
      final data = doc.data();
      final responses = data['haiQuestionnaireResponses'] is Map
          ? Map<String, dynamic>.from(data['haiQuestionnaireResponses'] as Map)
          : const <String, dynamic>{};
      final candidates = [
        data['patientId'],
        responses['_9_Hospital_number'],
        responses['Hospital_number'],
      ];
      for (final candidate in candidates) {
        if ('$candidate'.trim().toLowerCase() != normalized) continue;
        final signature = _haiDuplicateEventSignature(
          infectionType: '${data['infectionType'] ?? ''}',
          haiType:
              '${(data['haiQuestionnaireResponseLabels'] is Map ? (data['haiQuestionnaireResponseLabels'] as Map)['Type_of_HAIs'] : null) ?? responses['Type_of_HAIs'] ?? ''}',
          admissionDate: data['admissionDate'] is Timestamp
              ? (data['admissionDate'] as Timestamp).toDate()
              : null,
        );
        if (signature == currentSignature) return true;
      }
    }
    return false;
  }

  String _haiDuplicateEventSignature({
    required String infectionType,
    required String haiType,
    required DateTime? admissionDate,
  }) {
    final type = (haiType.trim().isNotEmpty && haiType != 'Unknown')
        ? haiType
        : infectionType;
    final normalizedType = type.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '',
    );
    if (normalizedType.isEmpty) return '';
    final admission = admissionDate == null
        ? 'unknown-admission'
        : DateFormat('yyyy-MM-dd').format(admissionDate);
    return '$normalizedType|$admission';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingHaiTemplate || _haiFields.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.documentId == null
                ? 'Add ${widget.infectionType}'
                : 'Update ${widget.infectionType}',
          ),
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
        ),
        body: _isLoadingHaiTemplate
            ? const Center(child: CircularProgressIndicator())
            : _IpcServerTemplateUnavailable(
                title: 'HAI Surveillance template unavailable',
                message:
                    _haiTemplateError ??
                    'Save the HAI Surveillance template from IPC Dashboard Control before staff use this form.',
              ),
      );
    }

    if (_isWorkbookHaiForm()) {
      final isFinal = widget.initialData?['submissionStatus'] == 'Final';
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.documentId == null
                ? 'Add ${widget.infectionType}'
                : 'Update ${widget.infectionType}',
          ),
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.surveillanceType == 'Targeted HAI Surveillance')
                Card(
                  color: Colors.red.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.track_changes),
                    title: Text(widget.infectionType),
                    subtitle: const Text('Targeted HAI surveillance subtype'),
                  ),
                ),
              if (widget.surveillanceType == 'Targeted HAI Surveillance')
                const SizedBox(height: 16),
              _buildWorkbookHaiQuestionnaire(),
              const SizedBox(height: 24),
              if (!isFinal) ...[
                OutlinedButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () => _saveHAIReport(asDraft: true),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save progress'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => _saveHAIReport(asDraft: false),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(isFinal ? Icons.update : Icons.check_circle_outline),
                label: Text(
                  isFinal ? 'Update final submission' : 'Final submit',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.documentId == null
              ? 'Add ${widget.infectionType}'
              : 'Update ${widget.infectionType}',
        ),
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
                controller: _organismController,
                decoration: const InputDecoration(
                  labelText: 'Organism Isolated *',
                  border: OutlineInputBorder(),
                  hintText: 'E.g., Staphylococcus aureus',
                ),
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

            if (widget.initialData?['submissionStatus'] != 'Final')
              OutlinedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => _saveHAIReport(asDraft: true),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save progress'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            if (widget.initialData?['submissionStatus'] != 'Final')
              const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () => _saveHAIReport(asDraft: false),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      widget.initialData?['submissionStatus'] == 'Final'
                          ? Icons.update
                          : Icons.check_circle_outline,
                    ),
              label: Text(
                widget.initialData?['submissionStatus'] == 'Final'
                    ? 'Update final submission'
                    : 'Final submission',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
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
  final String? documentId;
  final Map<String, dynamic>? initialData;
  final bool allowFinalEdit;

  const _HandHygieneObservationFormScreen({
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    this.documentId,
    this.initialData,
    this.allowFinalEdit = false,
  });

  @override
  State<_HandHygieneObservationFormScreen> createState() =>
      _HandHygieneObservationFormScreenState();
}

class _HandHygieneObservationFormScreenState
    extends State<_HandHygieneObservationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sessionController = TextEditingController();
  final _notesController = TextEditingController();
  final List<_HandHygieneColumnDraft> _columns = List.generate(
    4,
    (_) => _HandHygieneColumnDraft(),
  );
  String? _documentId;

  String? _selectedDepartment;
  String? _selectedWard;
  DateTime _observationDate = DateTime.now();
  bool _isSubmitting = false;

  static const _indications = <String, String>{
    'before_patient': 'bef-pat.',
    'before_aseptic': 'bef-asept.',
    'after_body_fluid': 'aft-b.f.',
    'after_patient': 'aft-pat.',
    'after_patient_surroundings': 'aft.p.surr.',
  };

  static const _actions = <String, String>{
    'HR': 'HR',
    'HW': 'HW',
    'missed': 'missed',
  };

  static const _professionalCategories = [
    '1. Nurse / Midwife',
    '1.1 Nurse',
    '1.2 Midwife',
    '1.3 Student',
    '2. Auxiliary',
    '3. Medical Doctor',
    '3.1 Internal Medicine',
    '3.2 Surgeon',
    '3.3 Anaesthetist / Emergency Physician',
    '3.4 Paediatrician',
    '3.5 Gynaecologist',
    '3.6 Consultant',
    '3.7 Medical Student',
    '4. Other Health-care Worker',
    '4.1 Therapist',
    '4.2 Technician',
    '4.3 Other',
    '4.4 Student',
  ];

  static const _departments = <_HandHygieneLocationChoice>[
    _HandHygieneLocationChoice('surgery', 'Surgery'),
    _HandHygieneLocationChoice('medicine', 'Medicine'),
    _HandHygieneLocationChoice('paediatric', 'Paediatric'),
    _HandHygieneLocationChoice('o&g', 'O&G'),
    _HandHygieneLocationChoice('others', 'Other Units'),
  ];

  static const _wards = <_HandHygieneLocationChoice>[
    _HandHygieneLocationChoice('msw', 'MSW', department: 'surgery'),
    _HandHygieneLocationChoice('fsw', 'FSW', department: 'surgery'),
    _HandHygieneLocationChoice('psw', 'PSW', department: 'surgery'),
    _HandHygieneLocationChoice('mow', 'MOW', department: 'surgery'),
    _HandHygieneLocationChoice(
      'burns and palstic',
      'Burns & Plastic',
      department: 'surgery',
    ),
    _HandHygieneLocationChoice('mmw', 'MMW', department: 'medicine'),
    _HandHygieneLocationChoice('fmw', 'FMW', department: 'medicine'),
    _HandHygieneLocationChoice('pmw', 'PMW', department: 'paediatric'),
    _HandHygieneLocationChoice('scbu', 'SCBU', department: 'paediatric'),
    _HandHygieneLocationChoice(
      'obstetric',
      'Obstetric Ward',
      department: 'o&g',
    ),
    _HandHygieneLocationChoice('gynae', 'Gynae', department: 'o&g'),
    _HandHygieneLocationChoice('icu', 'ICU', department: 'others'),
    _HandHygieneLocationChoice('oncology', 'Oncology', department: 'others'),
    _HandHygieneLocationChoice('isolation', 'Isolation', department: 'others'),
    _HandHygieneLocationChoice('amenity', 'Amenity', department: 'others'),
  ];

  @override
  void initState() {
    super.initState();
    _documentId = widget.documentId;
    final data = widget.initialData;
    _sessionController.text = '${data?['sessionNumber'] ?? ''}';
    _selectedDepartment =
        data?['departmentValue'] as String? ??
        _choiceValue(_departments, data?['department']);
    _selectedWard =
        data?['wardValue'] as String? ?? _choiceValue(_wards, data?['ward']);
    _notesController.text = '${data?['notes'] ?? ''}';
    if (data?['observationDate'] is Timestamp) {
      _observationDate = (data!['observationDate'] as Timestamp).toDate();
    }
    final storedColumns = data?['handHygieneColumns'];
    if (storedColumns is List) {
      for (var i = 0; i < storedColumns.length && i < _columns.length; i++) {
        final raw = storedColumns[i];
        if (raw is Map) {
          _columns[i].load(Map<String, dynamic>.from(raw));
        }
      }
    }
  }

  @override
  void dispose() {
    _sessionController.dispose();
    _notesController.dispose();
    for (final column in _columns) {
      column.dispose();
    }
    super.dispose();
  }

  Future<void> _saveObservation({required bool finalSubmit}) async {
    if (finalSubmit && !_formKey.currentState!.validate()) return;
    if (!finalSubmit &&
        _selectedDepartment == null &&
        !_columns.any((column) => column.hasAnyData)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one observation detail')),
      );
      return;
    }
    if (finalSubmit && !_columns.any((column) => column.opportunityCount > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Record at least one opportunity')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final departmentLabel = _choiceLabel(_departments, _selectedDepartment);
      final wardLabel = _choiceLabel(_wards, _selectedWard);
      final formId =
          widget.initialData?['formId'] as String? ??
          await SurveillanceFormIdService.nextFormId(
            facilityId: widget.facilityId,
            surveillanceCode: 'ipc_hand_hygiene',
          );
      final columnsData = _columns.map((column) => column.toMap()).toList();
      final summary = _buildComplianceSummary();
      final collection = FirebaseFirestore.instance.collection(
        'hand_hygiene_observations',
      );
      final data = {
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityName,
        'formId': formId,
        'recordType': 'Hand Hygiene Observation',
        'sessionNumber': _sessionController.text.trim(),
        'department': departmentLabel,
        'departmentValue': _selectedDepartment,
        'ward': wardLabel,
        'unit': wardLabel,
        'wardValue': _selectedWard,
        'handHygieneColumns': columnsData,
        'complianceSummary': summary,
        'totalOpportunities': summary['totalOpportunities'],
        'totalHandwash': summary['totalHandwash'],
        'totalHandrub': summary['totalHandrub'],
        'totalActions': summary['totalActions'],
        'complianceRate': summary['complianceRate'],
        'notes': _notesController.text.trim(),
        'status': finalSubmit ? 'submitted' : 'pending',
        'submissionStatus': finalSubmit ? 'Final' : 'Draft',
        'submissionState': finalSubmit ? 'final' : 'draft',
        'isFinal': finalSubmit,
        'observedBy': widget.staffName,
        'observedById': widget.staffId,
        'createdBy': widget.staffName,
        'createdById': widget.staffId,
        if (finalSubmit) ...{
          'finalizedBy': widget.staffName,
          'finalizedById': widget.staffId,
          'finalizedAt': FieldValue.serverTimestamp(),
        },
        'lastUpdatedBy': widget.staffName,
        'lastUpdatedById': widget.staffId,
        'changeHistory': [
          {
            'staffId': widget.staffId,
            'staffName': widget.staffName,
            'action': finalSubmit ? 'final_submit' : 'save_progress',
            'at': Timestamp.now(),
          },
        ],
        'observationDate': Timestamp.fromDate(_observationDate),
        'reportedDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (_documentId == null) {
        final docRef = await collection.add(data);
        _documentId = docRef.id;
      } else {
        await collection.doc(_documentId).update({
          ...data,
          'changeHistory': FieldValue.arrayUnion([
            {
              'staffId': widget.staffId,
              'staffName': widget.staffName,
              'action': finalSubmit ? 'final_submit' : 'save_progress',
              'at': Timestamp.now(),
            },
          ]),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              finalSubmit
                  ? 'Observation recorded successfully'
                  : 'Observation progress saved',
            ),
          ),
        );
        if (finalSubmit) {
          Navigator.pop(context);
        } else {
          setState(() {});
        }
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
    final isFinal = widget.initialData?['submissionStatus'] == 'Final';
    final canSaveProgress = !isFinal;
    final canFinalize = !isFinal || widget.allowFinalEdit;
    final availableWards = _wards
        .where((ward) => ward.department == _selectedDepartment)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.documentId == null
              ? 'Hand Hygiene Observation'
              : 'Update Hand Hygiene Observation',
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                collapsedBackgroundColor: Colors.blue.shade50,
                backgroundColor: Colors.blue.shade50,
                title: const Text('General Recommendations'),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: const [
                  Text(
                    'Refer to the Hand Hygiene Technical Reference Manual. Introduce yourself when appropriate, explain the observation task, and provide immediate informal feedback when suitable.\n\nObserve health-care workers during patient care. Complete header details before data collection except end time/session duration. Sessions should last no more than 20 minutes, plus or minus 10 minutes depending on activity.\n\nEach column is dedicated to a professional category or a single health-care worker. Record each opportunity independently, mark all indications that apply, and record HR, HW, missed action, and glove use only when hand hygiene is missed while gloves are worn.\n\nProf. Cat.: 1 nurse/midwife, 2 auxiliary, 3 medical doctor, 4 other health-care worker. Opp.: one or more indications. Indications: bef.pat, bef.asept, aft.b.f, aft.pat, aft.p.surr. HH action: HR, HW, or Missed.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _sessionController,
              decoration: const InputDecoration(
                labelText: 'Session number',
                border: OutlineInputBorder(),
              ),
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
                return DropdownMenuItem(
                  value: dept.value,
                  child: Text(dept.label),
                );
              }).toList(),
              onChanged: (value) => setState(() {
                _selectedDepartment = value;
                _selectedWard = null;
              }),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _selectedWard,
              decoration: const InputDecoration(
                labelText: 'Ward/Unit *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.meeting_room_outlined),
              ),
              items: availableWards.map((ward) {
                return DropdownMenuItem(
                  value: ward.value,
                  child: Text(ward.label),
                );
              }).toList(),
              onChanged: _selectedDepartment == null
                  ? null
                  : (value) => setState(() => _selectedWard = value),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            ListTile(
              title: const Text('Observation Date'),
              subtitle: Text(DateFormat('MMM d, y').format(_observationDate)),
              trailing: const Icon(Icons.calendar_today),
              tileColor: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _observationDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _observationDate = picked);
              },
            ),
            const SizedBox(height: 20),

            const Text(
              'Observation Grid',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < _columns.length; index++) ...[
              _buildProfessionalColumn(index),
              const SizedBox(height: 12),
            ],

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

            if (canSaveProgress) ...[
              OutlinedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => _saveObservation(finalSubmit: false),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Save progress'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 12),
            ],

            ElevatedButton(
              onPressed: _isSubmitting || !canFinalize
                  ? null
                  : () => _saveObservation(finalSubmit: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save finalize', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalColumn(int index) {
    final column = _columns[index];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Professional category ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: column.professionalCategory,
              decoration: const InputDecoration(
                labelText: 'Prof. cat',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: _professionalCategories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => column.professionalCategory = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: column.codeController,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: column.numberController,
                    decoration: const InputDecoration(
                      labelText: 'N°',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < column.opportunities.length; i++)
              _buildOpportunity(column, i),
          ],
        ),
      ),
    );
  }

  Widget _buildOpportunity(_HandHygieneColumnDraft column, int index) {
    final opportunity = column.opportunities[index];
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('Opportunity ${index + 1}'),
      subtitle: opportunity.hasAnyData
          ? Text(
              '${opportunity.indicationLabels.join(', ')} • ${opportunity.action ?? 'No action'}',
            )
          : null,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 0,
            children: _indications.entries
                .map(
                  (entry) => FilterChip(
                    label: Text(entry.value),
                    selected: opportunity.indications.contains(entry.key),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          opportunity.indications.add(entry.key);
                        } else {
                          opportunity.indications.remove(entry.key);
                        }
                      });
                    },
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: opportunity.action,
          decoration: const InputDecoration(
            labelText: 'HH Action',
            border: OutlineInputBorder(),
          ),
          items: _actions.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() {
            opportunity.action = value;
            if (value != 'missed') opportunity.gloves = false;
          }),
        ),
        if (opportunity.action == 'missed')
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: opportunity.gloves,
            title: const Text('gloves'),
            onChanged: (value) =>
                setState(() => opportunity.gloves = value ?? false),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Map<String, dynamic> _buildComplianceSummary() {
    final perCategory = <Map<String, dynamic>>[];
    var totalOpportunities = 0;
    var totalHandwash = 0;
    var totalHandrub = 0;
    var totalMissed = 0;
    for (var index = 0; index < _columns.length; index++) {
      final column = _columns[index];
      final opp = column.opportunityCount;
      final hw = column.handwashCount;
      final hr = column.handrubCount;
      final missed = column.missedCount;
      totalOpportunities += opp;
      totalHandwash += hw;
      totalHandrub += hr;
      totalMissed += missed;
      perCategory.add({
        'index': index + 1,
        'professionalCategory': column.professionalCategory,
        'code': column.codeController.text.trim(),
        'numberObserved': int.tryParse(column.numberController.text.trim()),
        'opportunities': opp,
        'handwash': hw,
        'handrub': hr,
        'missed': missed,
        'actions': hw + hr,
        'complianceRate': opp == 0 ? 0 : ((hw + hr) / opp) * 100,
      });
    }
    final totalActions = totalHandwash + totalHandrub;
    return {
      'perCategory': perCategory,
      'totalOpportunities': totalOpportunities,
      'totalHandwash': totalHandwash,
      'totalHandrub': totalHandrub,
      'totalMissed': totalMissed,
      'totalActions': totalActions,
      'complianceRate': totalOpportunities == 0
          ? 0
          : (totalActions / totalOpportunities) * 100,
    };
  }

  String? _choiceValue(
    List<_HandHygieneLocationChoice> choices,
    Object? label,
  ) {
    if (label == null) return null;
    final text = '$label';
    for (final choice in choices) {
      if (choice.value == text || choice.label == text) return choice.value;
    }
    return null;
  }

  String? _choiceLabel(
    List<_HandHygieneLocationChoice> choices,
    String? value,
  ) {
    if (value == null) return null;
    for (final choice in choices) {
      if (choice.value == value) return choice.label;
    }
    return value;
  }
}

class _HandHygieneLocationChoice {
  final String value;
  final String label;
  final String? department;

  const _HandHygieneLocationChoice(this.value, this.label, {this.department});
}

class _HandHygieneColumnDraft {
  String? professionalCategory;
  final codeController = TextEditingController();
  final numberController = TextEditingController();
  final opportunities = List.generate(8, (_) => _HandHygieneOpportunityDraft());

  bool get hasAnyData =>
      professionalCategory != null ||
      codeController.text.trim().isNotEmpty ||
      numberController.text.trim().isNotEmpty ||
      opportunities.any((opportunity) => opportunity.hasAnyData);

  int get opportunityCount => opportunities
      .where((opportunity) => opportunity.indications.isNotEmpty)
      .length;
  int get handwashCount =>
      opportunities.where((opportunity) => opportunity.action == 'HW').length;
  int get handrubCount =>
      opportunities.where((opportunity) => opportunity.action == 'HR').length;
  int get missedCount => opportunities
      .where((opportunity) => opportunity.action == 'missed')
      .length;

  void load(Map<String, dynamic> data) {
    professionalCategory = data['professionalCategory'] as String?;
    codeController.text = '${data['code'] ?? ''}';
    numberController.text = '${data['numberObserved'] ?? ''}';
    final stored = data['opportunities'];
    if (stored is List) {
      for (var i = 0; i < stored.length && i < opportunities.length; i++) {
        final raw = stored[i];
        if (raw is Map) {
          opportunities[i].load(Map<String, dynamic>.from(raw));
        }
      }
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'professionalCategory': professionalCategory,
      'code': codeController.text.trim(),
      'numberObserved': int.tryParse(numberController.text.trim()),
      'opportunities': opportunities
          .map((opportunity) => opportunity.toMap())
          .toList(),
    };
  }

  void dispose() {
    codeController.dispose();
    numberController.dispose();
  }
}

class _HandHygieneOpportunityDraft {
  final Set<String> indications = {};
  String? action;
  bool gloves = false;

  bool get hasAnyData => indications.isNotEmpty || action != null || gloves;

  List<String> get indicationLabels => indications
      .map(
        (key) =>
            _HandHygieneObservationFormScreenState._indications[key] ?? key,
      )
      .toList();

  void load(Map<String, dynamic> data) {
    final storedIndications = data['indications'];
    if (storedIndications is List) {
      indications
        ..clear()
        ..addAll(storedIndications.map((item) => '$item'));
    }
    action = data['action'] as String?;
    gloves = data['gloves'] == true;
  }

  Map<String, dynamic> toMap() {
    return {
      'indications': indications.toList(),
      'action': action,
      'gloves': gloves,
    };
  }
}

// ===================== OUTBREAK REPORT FORM =====================

class _OutbreakReportFormScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final String? documentId;
  final Map<String, dynamic>? initialData;

  const _OutbreakReportFormScreen({
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    this.documentId,
    this.initialData,
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

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    if (data == null) return;
    _selectedInfectionType = data['infectionType'] as String?;
    _selectedDepartment = data['department'] as String?;
    _numberOfCasesController.text = _initialText(data['numberOfCases']);
    _descriptionController.text = _initialText(data['description']);
    _affectedAreasController.text = _initialText(data['affectedAreas']);
    _riskFactorsController.text = _initialText(data['riskFactors']);
    _controlMeasuresController.text = _initialText(data['controlMeasures']);
    _notesController.text = _initialText(data['notes']);
    if (data['outbreakStartDate'] is Timestamp) {
      _outbreakStartDate = (data['outbreakStartDate'] as Timestamp).toDate();
    }
  }

  String _initialText(Object? value) => value == null ? '' : '$value';

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

  Future<void> _saveOutbreakReport({required bool asDraft}) async {
    if (!asDraft && !_formKey.currentState!.validate()) return;

    if (!asDraft && _outbreakStartDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select outbreak start date')),
      );
      return;
    }
    if (asDraft && !_hasOutbreakProgress()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one outbreak detail')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final formId =
          widget.initialData?['formId'] ??
          await SurveillanceFormIdService.nextFormId(
            facilityId: widget.facilityId,
            surveillanceCode: 'ipc_outbreak_investigation',
          );
      final data = {
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityName,
        'formId': formId,
        'infectionType': _selectedInfectionType,
        'department': _selectedDepartment,
        'numberOfCases': int.tryParse(_numberOfCasesController.text.trim()),
        if (_outbreakStartDate != null)
          'outbreakStartDate': Timestamp.fromDate(_outbreakStartDate!),
        'description': _descriptionController.text.trim(),
        'affectedAreas': _affectedAreasController.text.trim(),
        'riskFactors': _riskFactorsController.text.trim(),
        'controlMeasures': _controlMeasuresController.text.trim(),
        'notes': _notesController.text.trim(),
        'reportedBy': widget.staffName,
        'reportedById': widget.staffId,
        'createdBy': widget.staffName,
        'createdById': widget.staffId,
        'lastUpdatedBy': widget.staffName,
        'lastUpdatedById': widget.staffId,
        'changeHistory': [
          {
            'staffId': widget.staffId,
            'staffName': widget.staffName,
            'action': asDraft ? 'save_progress' : 'final_submit',
            'at': Timestamp.now(),
          },
        ],
        'reportedDate': FieldValue.serverTimestamp(),
        'submissionStatus': asDraft ? 'Draft' : 'Final',
        'dataStatus': 'Raw Data',
        'status': asDraft ? 'Pending' : 'Active',
        'investigationStep': asDraft ? 'Draft' : 'Verification',
        if (!asDraft) 'finalizedAt': FieldValue.serverTimestamp(),
        if (!asDraft) 'finalizedBy': widget.staffName,
        if (!asDraft) 'finalizedById': widget.staffId,
      };
      if (widget.documentId == null) {
        await FirebaseFirestore.instance
            .collection('outbreak_investigations')
            .add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('outbreak_investigations')
            .doc(widget.documentId)
            .update({
              ...data,
              'changeHistory': FieldValue.arrayUnion([
                {
                  'staffId': widget.staffId,
                  'staffName': widget.staffName,
                  'action': asDraft ? 'save_progress' : 'final_submit',
                  'at': Timestamp.now(),
                },
              ]),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              asDraft
                  ? 'Outbreak progress saved'
                  : 'Outbreak reported successfully',
            ),
          ),
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

  bool _hasOutbreakProgress() {
    return _selectedInfectionType != null ||
        _selectedDepartment != null ||
        _outbreakStartDate != null ||
        _numberOfCasesController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _affectedAreasController.text.trim().isNotEmpty ||
        _riskFactorsController.text.trim().isNotEmpty ||
        _controlMeasuresController.text.trim().isNotEmpty ||
        _notesController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.documentId == null ? 'Report Outbreak' : 'Update Outbreak',
        ),
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

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => _saveOutbreakReport(asDraft: true),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save progress'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _saveOutbreakReport(asDraft: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Submit final',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
