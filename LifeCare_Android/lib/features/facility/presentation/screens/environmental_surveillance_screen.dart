// Environmental Surveillance Screen
// Hospital Waste Management & Environmental Health following WHO Guidelines
// Reference: WHO Safe Management of Wastes from Health-care Activities

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/services/surveillance_form_id_service.dart';
import '../models/environmental_health_questionnaire.dart';
import '../models/water_quality_questionnaire.dart';

Future<Map<String, dynamic>?>
_loadLatestBuiltInEnvironmentalTemplateDataFromServer({
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
    if (_environmentalFacilityKey(facilityId).isNotEmpty)
      '${_environmentalFacilityKey(facilityId)}_$templateId',
    '${facilityKey}_$templateId',
  };
  for (final documentId in deterministicIds) {
    try {
      final deterministicSnapshot = await collection
          .doc(documentId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 12));
      final deterministicData = deterministicSnapshot.data();
      if (_isUsableBuiltInEnvironmentalTemplate(
        deterministicData,
        templateId,
      )) {
        candidates.add(
          _environmentalTemplateDataWithDocumentId(
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
      if (_isSameEnvironmentalTemplateFacility(
            data,
            facilityId,
            facilityName,
          ) &&
          _isUsableBuiltInEnvironmentalTemplate(data, templateId)) {
        candidates.add(_environmentalTemplateDataWithDocumentId(data, doc.id));
      }
    }
  } catch (_) {
    // Staff runtime forms require saved Firestore templates.
  }
  if (candidates.isEmpty) {
    return null;
  }
  candidates.sort(_compareEnvironmentalTemplateFreshness);
  return candidates.last;
}

Map<String, dynamic> _environmentalTemplateDataWithDocumentId(
  Map<String, dynamic> data,
  String documentId,
) {
  return {...data, '_documentId': documentId};
}

bool _isSameEnvironmentalTemplateFacility(
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
      _environmentalFacilityKey(savedFacilityName) ==
          _environmentalFacilityKey(facilityName);
}

String _environmentalFacilityKey(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

bool _isUsableBuiltInEnvironmentalTemplate(
  Map<String, dynamic>? data,
  String templateId,
) {
  if (data == null || data['templateId'] != templateId) return false;
  if (data['isActive'] == false) return false;
  final questions = data['questions'];
  return questions is List && questions.isNotEmpty;
}

int _compareEnvironmentalTemplateFreshness(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final timeComparison = _environmentalTemplateMillis(
    a,
  ).compareTo(_environmentalTemplateMillis(b));
  if (timeComparison != 0) return timeComparison;
  return '${a['_documentId'] ?? ''}'.compareTo('${b['_documentId'] ?? ''}');
}

int _environmentalTemplateMillis(Map<String, dynamic> data) {
  final updatedAt = data['updatedAt'];
  if (updatedAt is Timestamp) return updatedAt.millisecondsSinceEpoch;
  final importedAt = data['importedAt'];
  if (importedAt is Timestamp) return importedAt.millisecondsSinceEpoch;
  final createdAt = data['createdAt'];
  if (createdAt is Timestamp) return createdAt.millisecondsSinceEpoch;
  return 0;
}

class EnvironmentalSurveillanceScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const EnvironmentalSurveillanceScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<EnvironmentalSurveillanceScreen> createState() =>
      _EnvironmentalSurveillanceScreenState();
}

class _EnvironmentalSurveillanceScreenState
    extends State<EnvironmentalSurveillanceScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Environmental Surveillance'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: EnvironmentalSurveillanceLauncher(
        facilityId: widget.facilityId,
        facilityName: widget.facilityName,
        staffId: widget.staffId,
        staffName: widget.staffName,
        dashboardSource: 'public_health',
      ),
    );
  }

  Widget _buildWasteManagementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    Icon(Icons.info_outline, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'WHO Waste Classification',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Healthcare waste must be properly classified, segregated, collected, '
                  'stored, transported, treated, and disposed according to WHO guidelines.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Waste Categories (WHO)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildWasteCategoryCard(
            category: 'Infectious Waste',
            color: Colors.red,
            description:
                'Waste contaminated with blood, body fluids, or infectious materials',
            examples: [
              'Cultures and stocks of infectious agents',
              'Waste from isolation wards',
              'Contaminated materials from infected patients',
              'Blood and blood products',
            ],
            disposalMethod: 'Autoclave/incineration, then landfill',
            containerColor: 'Yellow bag/container',
          ),
          _buildWasteCategoryCard(
            category: 'Pathological Waste',
            color: Colors.orange,
            description:
                'Human tissues, organs, body parts, and contaminated animal carcasses',
            examples: [
              'Anatomical waste',
              'Placenta',
              'Body parts from surgery',
              'Contaminated animal carcasses',
            ],
            disposalMethod: 'Incineration or deep burial',
            containerColor: 'Yellow bag/container',
          ),
          _buildWasteCategoryCard(
            category: 'Sharps Waste',
            color: Colors.purple,
            description: 'Items that can cause cuts or puncture wounds',
            examples: [
              'Needles and syringes',
              'Scalpels and blades',
              'Broken glass',
              'Infusion sets',
            ],
            disposalMethod: 'Encapsulation, incineration, or autoclaving',
            containerColor: 'Puncture-proof container',
          ),
          _buildWasteCategoryCard(
            category: 'Chemical Waste',
            color: Colors.blue,
            description:
                'Discarded chemical substances from laboratory and diagnostic work',
            examples: [
              'Laboratory reagents',
              'Disinfectants',
              'Heavy metals (mercury, lead)',
              'Solvents',
            ],
            disposalMethod: 'Special chemical treatment',
            containerColor: 'Brown bag/container',
          ),
          _buildWasteCategoryCard(
            category: 'Pharmaceutical Waste',
            color: Colors.pink,
            description: 'Expired, unused, or contaminated drugs and vaccines',
            examples: [
              'Expired medications',
              'Unused vaccines',
              'Cytotoxic drugs',
              'Contaminated antibiotics',
            ],
            disposalMethod:
                'Return to supplier or high-temperature incineration',
            containerColor: 'Blue bag/container',
          ),
          _buildWasteCategoryCard(
            category: 'Radioactive Waste',
            color: Colors.amber,
            description: 'Waste containing radioactive substances',
            examples: [
              'Unused radiotherapy materials',
              'Contaminated glassware',
              'Sealed sources',
            ],
            disposalMethod: 'Decay storage and disposal per regulations',
            containerColor: 'Lead-shielded container',
          ),
          _buildWasteCategoryCard(
            category: 'General/Non-Hazardous Waste',
            color: Colors.grey,
            description: 'Waste that does not pose special handling risks',
            examples: [
              'Office and administrative waste',
              'Packaging materials',
              'Food waste from kitchens',
              'General cleaning waste',
            ],
            disposalMethod: 'Municipal waste disposal',
            containerColor: 'Black bag/container',
          ),
          const SizedBox(height: 20),
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
                    Icon(Icons.warning_amber, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Text(
                      'Key Principles',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '• Segregate waste at point of generation\n'
                  '• Use color-coded containers and bags\n'
                  '• Do not mix different waste categories\n'
                  '• Fill containers to max 3/4 capacity\n'
                  '• Label all waste containers clearly\n'
                  '• Store in dedicated secure areas\n'
                  '• Train all staff on waste management',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWasteCategoryCard({
    required String category,
    required Color color,
    required String description,
    required List<String> examples,
    required String disposalMethod,
    required String containerColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.delete_outline, color: color),
        ),
        title: Text(
          category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Examples:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...examples.map(
                  (example) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.circle, size: 6, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            example,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.science, size: 16, color: color),
                          const SizedBox(width: 8),
                          const Text(
                            'Disposal Method:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        disposalMethod,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.shopping_bag, size: 16, color: color),
                          const SizedBox(width: 8),
                          const Text(
                            'Container:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        containerColor,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterQualityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Water Quality Monitoring',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildWaterTestCard(
            test: 'pH Level',
            standard: '6.5 - 8.5',
            icon: Icons.science,
            color: Colors.blue,
          ),
          _buildWaterTestCard(
            test: 'Turbidity',
            standard: '< 5 NTU',
            icon: Icons.water_drop,
            color: Colors.lightBlue,
          ),
          _buildWaterTestCard(
            test: 'Residual Chlorine',
            standard: '0.2 - 0.5 mg/L',
            icon: Icons.science,
            color: Colors.cyan,
          ),
          _buildWaterTestCard(
            test: 'Total Coliform',
            standard: '0 CFU/100mL',
            icon: Icons.biotech,
            color: Colors.purple,
          ),
          _buildWaterTestCard(
            test: 'E. coli',
            standard: '0 CFU/100mL',
            icon: Icons.coronavirus,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildWaterTestCard({
    required String test,
    required String standard,
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
        title: Text(test, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('WHO Standard: $standard'),
      ),
    );
  }

  Widget _buildAirQualityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Air Quality Monitoring',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildAirQualityCard(
          parameter: 'Ventilation',
          description: 'Adequate air exchange in all rooms',
          color: Colors.teal,
        ),
        _buildAirQualityCard(
          parameter: 'Temperature',
          description: '18-24°C in patient areas',
          color: Colors.orange,
        ),
        _buildAirQualityCard(
          parameter: 'Humidity',
          description: '30-60% relative humidity',
          color: Colors.blue,
        ),
        _buildAirQualityCard(
          parameter: 'Dust and Particles',
          description: 'Minimal dust accumulation',
          color: Colors.brown,
        ),
      ],
    );
  }

  Widget _buildAirQualityCard({
    required String parameter,
    required String description,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.air, color: color),
        ),
        title: Text(
          parameter,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
      ),
    );
  }

  Widget _buildReportsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Environmental Health Reports',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildReportCard(
          title: 'Inspection Summary Report',
          description: 'Overview of all environmental inspections',
          icon: Icons.assignment,
          color: Colors.green,
          onTap: () => _showInspectionSummaryReport(context),
        ),
        _buildReportCard(
          title: 'Sanitation Compliance Report',
          description: 'Sanitation checklist results by department',
          icon: Icons.cleaning_services,
          color: Colors.teal,
          onTap: () => _showSanitationComplianceReport(context),
        ),
        _buildReportCard(
          title: 'Department Performance',
          description: 'Environmental health performance by department',
          icon: Icons.bar_chart,
          color: Colors.blue,
          onTap: () => _showDepartmentPerformanceReport(context),
        ),
        _buildReportCard(
          title: 'Issues & Actions Report',
          description: 'Critical issues requiring immediate action',
          icon: Icons.warning,
          color: Colors.amber,
          onTap: () => _showIssuesActionsReport(context),
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

  void _showInspectionSummaryReport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _InspectionSummaryReportView(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showSanitationComplianceReport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _SanitationComplianceReportView(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showDepartmentPerformanceReport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) =>
            _DepartmentPerformanceReportView(
              facilityId: widget.facilityId,
              facilityName: widget.facilityName,
              scrollController: scrollController,
            ),
      ),
    );
  }

  void _showIssuesActionsReport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _IssuesActionsReportView(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showNewInspectionForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EnvironmentalInspectionForm(
        facilityId: widget.facilityId,
        facilityName: widget.facilityName,
        staffId: widget.staffId,
        staffName: widget.staffName,
        dashboardSource: 'public_health',
      ),
    );
  }
}

class EnvironmentalSurveillanceLauncher extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final String dashboardSource;

  const EnvironmentalSurveillanceLauncher({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    this.dashboardSource = 'public_health',
  });

  @override
  State<EnvironmentalSurveillanceLauncher> createState() =>
      _EnvironmentalSurveillanceLauncherState();
}

class _EnvironmentalSurveillanceLauncherState
    extends State<EnvironmentalSurveillanceLauncher> {
  bool _showTypes = false;
  String? _selectedSurveillanceType;
  String _pendingSearch = '';
  String _pendingSearchInput = '';
  String _pendingSearchField = 'formId';
  bool _showAllPending = false;

  static const _types = [
    (
      name: 'Water Quality',
      description: 'Collect water quality and safety surveillance data',
      icon: Icons.water_drop_outlined,
      color: Colors.blue,
    ),
    (
      name: 'General Environmental Health',
      description: 'Complete a general environmental health inspection',
      icon: Icons.health_and_safety_outlined,
      color: Colors.orange,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!_showTypes)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showTypes = true),
              icon: const Icon(Icons.add),
              label: const Text('Add new surveillance'),
            ),
          )
        else ...[
          const Text(
            'Select environmental surveillance type',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedSurveillanceType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Surveillance type',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: _types
                .map(
                  (type) => DropdownMenuItem(
                    value: type.name,
                    child: Text(type.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedSurveillanceType = value);
              _openForm(value);
            },
          ),
          const SizedBox(height: 12),
          if (_selectedSurveillanceType != null)
            Card(
              color: Colors.green.shade50,
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(_selectedSurveillanceType!),
                subtitle: const Text('Selected surveillance type'),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() {
                _showTypes = false;
                _selectedSurveillanceType = null;
              }),
              child: const Text('Hide surveillance types'),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _buildPendingEnvironmentalForms(),
      ],
    );
  }

  Widget _buildPendingEnvironmentalForms() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('environmental_inspections')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('dashboardSource', isEqualTo: widget.dashboardSource)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Unable to load pending environmental forms: ${snapshot.error}',
          );
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
          final haystack = _pendingSearchValue(data).toLowerCase();
          return _pendingSearch.isEmpty ||
              haystack.contains(_pendingSearch.toLowerCase());
        }).toList();
        final visibleDocs = _showAllPending ? docs : docs.take(5).toList();
        if (pendingDocs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pending environmental forms',
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
                    value: _pendingSearchField,
                    decoration: const InputDecoration(
                      labelText: 'Search by',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'formId', child: Text('Form ID')),
                      DropdownMenuItem(value: 'type', child: Text('Type')),
                      DropdownMenuItem(
                        value: 'department',
                        child: Text('Department/Unit'),
                      ),
                      DropdownMenuItem(
                        value: 'sampleId',
                        child: Text('Sample ID'),
                      ),
                      DropdownMenuItem(
                        value: 'staffId',
                        child: Text('Staff ID'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _pendingSearchField = value);
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
                    onChanged: (value) => _pendingSearchInput = value.trim(),
                    onSubmitted: (_) => setState(() {
                      _pendingSearch = _pendingSearchInput;
                      _showAllPending = false;
                    }),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Search',
                  onPressed: () => setState(() {
                    _pendingSearch = _pendingSearchInput;
                    _showAllPending = false;
                  }),
                  icon: const Icon(Icons.search),
                ),
                if (_pendingSearch.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() {
                      _pendingSearch = '';
                      _pendingSearchInput = '';
                      _showAllPending = false;
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
                    title: Text('${data['formId'] ?? data['inspectionType']}'),
                    subtitle: Text(
                      '${data['inspectionType'] ?? 'Environmental'} • Last edited by ${data['lastUpdatedById'] ?? data['inspectorId'] ?? '-'}',
                    ),
                    trailing: TextButton(
                      child: const Text('Continue'),
                      onPressed: () => _openForm(
                        data['inspectionType'] as String? ?? 'Water Quality',
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
                    setState(() => _showAllPending = !_showAllPending),
                icon: Icon(
                  _showAllPending ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(
                  _showAllPending
                      ? 'Show less'
                      : 'View more (${docs.length - 5})',
                ),
              ),
          ],
        );
      },
    );
  }

  String _pendingSearchValue(Map<String, dynamic> data) {
    switch (_pendingSearchField) {
      case 'type':
        return '${data['inspectionType'] ?? ''}';
      case 'department':
        return '${data['department'] ?? data['unit'] ?? data['ward'] ?? ''}';
      case 'sampleId':
        return '${data['sampleId'] ?? ''}';
      case 'staffId':
        return '${data['lastUpdatedById'] ?? data['inspectorId'] ?? ''}';
      case 'formId':
      default:
        return '${data['formId'] ?? ''}';
    }
  }

  void _openForm(
    String inspectionType, {
    String? documentId,
    Map<String, dynamic>? initialData,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EnvironmentalInspectionForm(
        facilityId: widget.facilityId,
        facilityName: widget.facilityName,
        staffId: widget.staffId,
        staffName: widget.staffName,
        dashboardSource: widget.dashboardSource,
        initialInspectionType: inspectionType,
        documentId: documentId,
        initialData: initialData,
      ),
    );
  }
}

// Environmental Inspection Form Widget
class EnvironmentalInspectionForm extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final String dashboardSource;
  final String? initialInspectionType;
  final String? documentId;
  final Map<String, dynamic>? initialData;
  final bool allowFinalEdit;

  const EnvironmentalInspectionForm({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    required this.dashboardSource,
    this.initialInspectionType,
    this.documentId,
    this.initialData,
    this.allowFinalEdit = false,
  });

  @override
  State<EnvironmentalInspectionForm> createState() =>
      _EnvironmentalInspectionFormState();
}

class _EnvironmentalInspectionFormState
    extends State<EnvironmentalInspectionForm> {
  final _formKey = GlobalKey<FormState>();
  String? _inspectionType;
  String? _department;
  String? _unit;
  String? _findingsLevel;
  final _findingsController = TextEditingController();
  final _recommendationsController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  final Map<String, dynamic> _surveyAnswers = {};
  final Map<String, TextEditingController> _surveyTextControllers = {};
  final Map<String, dynamic> _waterAnswers = {};
  final Map<String, TextEditingController> _waterTextControllers = {};
  List<EnvironmentalSurveyQuestion>? _facilityEnvironmentalQuestions;
  List<WaterQualityField>? _facilityWaterQualityFields;
  bool _isLoadingEnvironmentalTemplate = true;
  bool _isLoadingWaterQualityTemplate = true;
  String? _environmentalTemplateError;
  String? _waterQualityTemplateError;
  DateTime _waterCollectionDate = DateTime.now();
  TimeOfDay _waterCollectionTime = TimeOfDay.now();
  DateTime? _waterActionDate;
  DateTime? _waterFollowUpDate;
  String? _waterDraftDocumentId;

  // Sanitation checklist
  final Map<String, bool> _checklistItems = {};
  List<String> _checklistQuestions = [];

  static const List<String> _templateBackedInspectionTypes = [
    'Water Quality',
    'General Environmental Health',
  ];

  List<String> get _inspectionTypes {
    final selected = _inspectionType;
    if (selected != null &&
        selected.isNotEmpty &&
        !_templateBackedInspectionTypes.contains(selected)) {
      return [selected, ..._templateBackedInspectionTypes];
    }
    return _templateBackedInspectionTypes;
  }

  final List<String> _departments = [
    'Medical Department',
    'Surgical Department',
    'O&G Department',
    'Paediatric Department',
    'Emergency Departments/Units',
    'Community Medicine Department',
    'ENT Department',
    'Physiotherapy Department',
    'Maxillofacial Department',
    'Main Operating Theater',
    'Obstetric Theater',
    'Ophthalmic Complex',
    'Radiology Department',
    'Other Special Wards',
    'Special Clinics',
    'Medical Microbiology Department',
    'Chemical Pathology Department',
    'Haematology Department',
    'Histopathology Department',
    'Laundry Unit',
  ];

  final Map<String, List<String>> _departmentUnits = {
    'Medical Department': [
      'Male Medical Ward',
      'Female Medical Ward',
      'Isolation Ward',
      'Dialysis Ward',
    ],
    'Surgical Department': [
      'Male Surgical Ward',
      'Female Surgical Ward',
      'Paediatric Surgical Ward',
      'Male Orthopedic Ward',
      'Burns & Plastic Ward',
      'Urology Ward',
    ],
    'O&G Department': ['Obstetric Ward', 'Gynaecology Ward', 'Labour Room'],
    'Paediatric Department': [
      'Pediatric Medical Ward',
      'SCBU (In Born)',
      'SCBU (Out Born)',
      'EPU',
    ],
    'Emergency Departments/Units': [
      'A&E Medical',
      'A&E Surgical',
      'Gynae Emergency',
      'Obstetric Emergency',
    ],
    'Community Medicine Department': [
      'General Area/Offices/Reception',
      'Immunization Unit',
      'Incineration Room',
      'Dump Site',
    ],
    'ENT Department': [
      'General Area/Reception',
      'Audiology',
      'Endoscopy Room',
      'Bone Dissection Room',
    ],
    'Physiotherapy Department': [
      'General Area/Reception',
      'Surgery/Orthopaedic Unit',
      'Medicine/Neurology Unit',
      'Child Health Unit',
      'Treatment Room',
      'Plaster/OT/P&O Room',
    ],
    'Maxillofacial Department': [
      'General Area/Reception',
      'Surgical Room General',
      'Sterilization Room',
      'Denture Room',
    ],
    'Main Operating Theater': [
      'General Area/Reception',
      'Theater Suites',
      'Recovery Room',
      'A&E Suite',
      'Central Sterile Supply Unit',
    ],
    'Obstetric Theater': ['General Area', 'Suites'],
    'Radiology Department': [
      'General Area/Reception',
      'Scanning Rooms',
      'X-Ray Rooms',
    ],
    'Other Special Wards': ['ICU', 'Amenity Ward', 'Oncology Ward'],
    'Special Clinics': [
      'Sickle Cell Clinic',
      'Endoscopy Room (MMW)',
      'ART Clinic',
      'MOPD/SOPD Clinic',
      'Labour Room',
      'O&G Clinic',
      'Paediatric Complex',
      'GOPC',
      'NHIS Clinic',
    ],
    'Medical Microbiology Department': [
      'General Area/Reception/Sample Collection',
      'Bacteriology Unit',
      'Serology Unit',
      'Molecular Lab',
      'STC Unit',
      'Wash Room',
      'GenXpert',
    ],
    'Chemical Pathology Department': [
      'General Area/Reception/Sample Collection',
      'Processing Unit',
      'Metabolic Unit',
    ],
    'Haematology Department': [
      'General Area/Reception/Sample Collection',
      'Bleeding Room',
    ],
    'Histopathology Department': [
      'General Area/Reception/Sample Collection',
      'Processing Room',
      'Mortuary',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadFacilityFormTemplates();
    _inspectionType =
        widget.initialInspectionType ??
        widget.initialData?['inspectionType'] as String?;
    _department = widget.initialData?['department'] as String?;
    _unit = widget.initialData?['unit'] as String?;
    _waterDraftDocumentId = widget.documentId;
    final surveyData = widget.initialData?['questionnaireResponses'];
    if (surveyData is Map) {
      _surveyAnswers.addAll(Map<String, dynamic>.from(surveyData));
    }
    if (_department != null) {
      _surveyAnswers.putIfAbsent('Department_Unit', () => _department);
    }
    final waterData = widget.initialData?['waterQualityData'];
    if (waterData is Map) {
      _waterAnswers.addAll(Map<String, dynamic>.from(waterData));
      final collectionDate = widget.initialData?['collectionDate'];
      if (collectionDate is Timestamp) {
        _waterCollectionDate = collectionDate.toDate();
        _waterCollectionTime = TimeOfDay.fromDateTime(collectionDate.toDate());
      }
      final actionDate = waterData['Action_Date'];
      if (actionDate is Timestamp) _waterActionDate = actionDate.toDate();
      final followUpDate = waterData['Follow_Up_Date'];
      if (followUpDate is Timestamp) _waterFollowUpDate = followUpDate.toDate();
    }
    _initializeChecklist();
  }

  List<EnvironmentalSurveyQuestion> get _environmentalQuestions =>
      _facilityEnvironmentalQuestions ?? const <EnvironmentalSurveyQuestion>[];

  List<WaterQualityField> get _waterFields =>
      _facilityWaterQualityFields ?? const <WaterQualityField>[];

  Future<void> _loadFacilityFormTemplates() async {
    final facilityKey = widget.facilityName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    await Future.wait([
      _loadEnvironmentalTemplate(facilityKey),
      _loadWaterQualityTemplate(facilityKey),
    ]);
  }

  Future<void> _loadEnvironmentalTemplate(String facilityKey) async {
    try {
      final data = await _loadLatestBuiltInEnvironmentalTemplateDataFromServer(
        facilityKey: facilityKey,
        facilityId: widget.facilityId,
        facilityName: widget.facilityName,
        templateId: 'environmental_health_surveillance',
      );
      final questions = data?['questions'];
      if (questions is! List || questions.isEmpty) {
        _environmentalTemplateError =
            'Environmental Health Surveillance template is not available.';
        return;
      }
      final mapped = questions
          .whereType<Map>()
          .map(
            (item) => _environmentalQuestionFromTemplate(
              Map<String, dynamic>.from(item),
            ),
          )
          .whereType<EnvironmentalSurveyQuestion>()
          .toList();
      if (mapped.isEmpty) {
        _environmentalTemplateError =
            'Environmental Health Surveillance template has no usable questions.';
        return;
      }
      if (!mounted) return;
      setState(() {
        _facilityEnvironmentalQuestions = mapped;
        _environmentalTemplateError = null;
      });
    } catch (error) {
      _environmentalTemplateError =
          'Unable to load Environmental Health Surveillance template. Please ask the facility admin to save the template again.';
    } finally {
      if (mounted) {
        setState(() => _isLoadingEnvironmentalTemplate = false);
      }
    }
  }

  Future<void> _loadWaterQualityTemplate(String facilityKey) async {
    try {
      final data = await _loadLatestBuiltInEnvironmentalTemplateDataFromServer(
        facilityKey: facilityKey,
        facilityId: widget.facilityId,
        facilityName: widget.facilityName,
        templateId: 'water_quality_surveillance',
      );
      final questions = data?['questions'];
      if (questions is! List || questions.isEmpty) {
        _waterQualityTemplateError =
            'Water Quality Surveillance template is not available.';
        return;
      }
      final mapped = questions
          .whereType<Map>()
          .map(
            (item) => _waterFieldFromTemplate(Map<String, dynamic>.from(item)),
          )
          .whereType<WaterQualityField>()
          .toList();
      if (mapped.isEmpty) {
        _waterQualityTemplateError =
            'Water Quality Surveillance template has no usable questions.';
        return;
      }
      if (!mounted) return;
      setState(() {
        _facilityWaterQualityFields = mapped;
        _waterQualityTemplateError = null;
      });
    } catch (error) {
      _waterQualityTemplateError =
          'Unable to load Water Quality Surveillance template. Please ask the facility admin to save the template again.';
    } finally {
      if (mounted) {
        setState(() => _isLoadingWaterQualityTemplate = false);
      }
    }
  }

  Widget _buildTemplateUnavailable({
    required String title,
    required String message,
  }) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.assignment_late_outlined,
              size: 40,
              color: Colors.orange.shade700,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateLoading(String title) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
      ),
    );
  }

  bool get _selectedTemplateUnavailable {
    if (_inspectionType == 'General Environmental Health') {
      return _isLoadingEnvironmentalTemplate || _environmentalQuestions.isEmpty;
    }
    if (_inspectionType == 'Water Quality') {
      return _isLoadingWaterQualityTemplate || _waterFields.isEmpty;
    }
    return _inspectionType != null;
  }

  bool get _isTemplateBackedInspectionType =>
      _inspectionType == 'General Environmental Health' ||
      _inspectionType == 'Water Quality';

  EnvironmentalSurveyQuestion? _environmentalQuestionFromTemplate(
    Map<String, dynamic> question,
  ) {
    final stableName = '${question['stableName'] ?? question['id'] ?? ''}';
    final label = '${question['label'] ?? ''}'.trim();
    if (stableName.trim().isEmpty || label.isEmpty) return null;
    final optionValues = question['optionValues'] is Map
        ? Map<String, dynamic>.from(question['optionValues'] as Map)
        : const <String, dynamic>{};
    final options = (question['options'] as List<dynamic>? ?? [])
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .map(
          (label) => EnvironmentalSurveyChoice(
            '${optionValues[label] ?? _stableTemplateValue(label)}',
            label,
          ),
        )
        .toList();
    return EnvironmentalSurveyQuestion(
      type: _environmentalTypeFromTemplate('${question['type'] ?? ''}'),
      name: stableName,
      label: label,
      hint: '${question['hint'] ?? ''}'.trim().isEmpty
          ? null
          : '${question['hint']}',
      required: question['required'] == true,
      relevant: _templateRelevantExpression(question).trim().isEmpty
          ? null
          : _templateRelevantExpression(question),
      choices: options,
    );
  }

  String _templateRelevantExpression(Map<String, dynamic> question) {
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
        expressions.add(
          value == '__answered__'
              ? "\${$questionId} != ''"
              : "\${$questionId} = '${value.replaceAll("'", r"\'")}'",
        );
      }
    }
    final legacyQuestionId = '${question['showIfQuestionId'] ?? ''}'.trim();
    final legacyValue = '${question['showIfValue'] ?? ''}'.trim();
    if (legacyQuestionId.isNotEmpty && legacyValue.isNotEmpty) {
      expressions.add(
        legacyValue == '__answered__'
            ? "\${$legacyQuestionId} != ''"
            : "\${$legacyQuestionId} = '${legacyValue.replaceAll("'", r"\'")}'",
      );
    }
    if (expressions.isEmpty) return existing;
    final combined = expressions.toSet().join(' or ');
    if (existing.isEmpty) return combined;
    return '$existing or $combined';
  }

  WaterQualityField? _waterFieldFromTemplate(Map<String, dynamic> question) {
    final stableName = '${question['stableName'] ?? question['id'] ?? ''}';
    final label = '${question['label'] ?? ''}'.trim();
    if (stableName.trim().isEmpty || label.isEmpty) return null;
    final options = (question['options'] as List<dynamic>? ?? [])
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final visibilityRules = _templateVisibilityRules(question);
    return WaterQualityField(
      name: stableName,
      label: label,
      section: '${question['section'] ?? 'Water Quality'}',
      type: _waterTypeFromTemplate('${question['type'] ?? ''}'),
      required: question['required'] == true,
      options: options,
      hint: '${question['hint'] ?? ''}'.trim().isEmpty
          ? null
          : '${question['hint']}',
      visibleWhenField: visibilityRules.isEmpty
          ? null
          : visibilityRules.first['questionId'],
      visibleWhenValues: visibilityRules.isEmpty
          ? const []
          : [visibilityRules.first['value'] ?? ''],
      visibleWhenRules: visibilityRules,
    );
  }

  List<Map<String, String>> _templateVisibilityRules(
    Map<String, dynamic> question,
  ) {
    final rules = <Map<String, String>>[];
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
        rules.add({'questionId': questionId, 'value': value});
      }
    }
    final legacyQuestionId = '${question['showIfQuestionId'] ?? ''}'.trim();
    final legacyValue = '${question['showIfValue'] ?? ''}'.trim();
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

  String _environmentalTypeFromTemplate(String type) {
    return switch (type) {
      'sub_heading' => 'note',
      'multiple_choice' => 'select_one',
      'checkbox' => 'select_multiple',
      'number' => 'integer',
      'date' => 'date',
      'long_text' => 'text',
      _ => 'text',
    };
  }

  String _waterTypeFromTemplate(String type) {
    return switch (type) {
      'sub_heading' => 'note',
      'multiple_choice' => 'select',
      'checkbox' => 'multiselect',
      'number' => 'decimal',
      'date' => 'date',
      'long_text' => 'multiline',
      _ => 'text',
    };
  }

  String _stableTemplateValue(String label) {
    return label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  void _initializeChecklist() {
    _checklistQuestions = [
      'Clean floors and surfaces',
      'Proper waste segregation',
      'Functional handwashing facilities',
      'Adequate soap and water supply',
      'Clean toilets and restrooms',
      'Proper ventilation',
      'Pest control measures in place',
      'Proper storage of cleaning materials',
      'Clean windows and walls',
      'Functional drainage system',
      'Proper lighting',
      'Clean equipment and furniture',
      'Odor control',
      'Proper disinfection protocols',
      'Clean linen and bedding (if applicable)',
      'Organized storage areas',
      'Clean entrance and exit points',
      'Compliance with safety signage',
    ];

    for (var question in _checklistQuestions) {
      _checklistItems[question] = false;
    }
  }

  @override
  void dispose() {
    _findingsController.dispose();
    _recommendationsController.dispose();
    _notesController.dispose();
    for (final controller in _surveyTextControllers.values) {
      controller.dispose();
    }
    for (final controller in _waterTextControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _isQuestionVisible(EnvironmentalSurveyQuestion question) {
    final expression = question.relevant;
    if (expression == null || expression.trim().isEmpty) return true;

    return expression
        .split(RegExp(r'\s+or\s+'))
        .any(
          (orPart) => orPart
              .split(RegExp(r'\s+and\s+'))
              .every((andPart) => _evaluateCondition(andPart.trim())),
        );
  }

  bool _evaluateCondition(String condition) {
    final selectedMatch = RegExp(
      r"selected\(\$\{([^}]+)\},\s*'([^']+)'\)",
    ).firstMatch(condition);
    if (selectedMatch != null) {
      final answer = _visibleAnswer(selectedMatch.group(1)!);
      return answer is List && answer.contains(selectedMatch.group(2));
    }

    final comparisonMatch = RegExp(
      r"^\$\{([^}]+)\}\s*(!=|=)\s*'([^']*)'$",
    ).firstMatch(condition);
    if (comparisonMatch == null) return false;

    final answer = _visibleAnswer(comparisonMatch.group(1)!);
    final expected = comparisonMatch.group(3);
    if (answer == null) return false;
    return comparisonMatch.group(2) == '!='
        ? answer != expected
        : answer == expected;
  }

  dynamic _visibleAnswer(String questionName) {
    final question = _environmentalQuestions
        .where((item) => item.name == questionName)
        .firstOrNull;
    if (question != null && !_isQuestionVisible(question)) return null;
    return _surveyAnswers[questionName];
  }

  String? _choiceLabel(String questionName, dynamic answer) {
    final question = _environmentalQuestions
        .where((item) => item.name == questionName)
        .firstOrNull;
    if (question == null) return answer?.toString();
    if (answer is List) {
      return answer
          .map(
            (value) => question.choices
                .where((choice) => choice.value == value)
                .map((choice) => choice.label)
                .firstOrNull,
          )
          .whereType<String>()
          .join(', ');
    }
    return question.choices
            .where((choice) => choice.value == answer)
            .map((choice) => choice.label)
            .firstOrNull ??
        answer?.toString();
  }

  Map<String, dynamic> _visibleSurveyAnswers() {
    return {
      for (final question in _environmentalQuestions)
        if (question.type != 'note' &&
            _isQuestionVisible(question) &&
            _surveyAnswers[question.name] != null &&
            _surveyAnswers[question.name].toString().trim().isNotEmpty)
          question.name: _surveyAnswers[question.name],
    };
  }

  Map<String, String> _visibleSurveyAnswerLabels() {
    return {
      for (final entry in _visibleSurveyAnswers().entries)
        entry.key:
            _choiceLabel(entry.key, entry.value) ?? entry.value.toString(),
    };
  }

  String? _selectedUnitLabel() {
    for (final question in _environmentalQuestions.skip(1).take(17)) {
      final answer = _surveyAnswers[question.name];
      if (answer != null) return _choiceLabel(question.name, answer);
    }
    return null;
  }

  Widget _buildEnvironmentalHealthQuestionnaire() {
    final visibleQuestions = _environmentalQuestions
        .where(_isQuestionVisible)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final question in visibleQuestions) ...[
          _buildSurveyQuestion(question),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildSurveyQuestion(EnvironmentalSurveyQuestion question) {
    if (question.type == 'note') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border(
            left: BorderSide(color: Colors.green.shade700, width: 4),
          ),
        ),
        child: Text(
          question.label,
          style: TextStyle(
            color: Colors.green.shade900,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (question.type == 'select_multiple') {
      final selected = List<String>.from(
        _surveyAnswers[question.name] as List? ?? const [],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionPrompt(question),
          const SizedBox(height: 8),
          FormField<List<String>>(
            initialValue: selected,
            validator: (_) => question.required && selected.isEmpty
                ? 'Select at least one option'
                : null,
            builder: (field) => InputDecorator(
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                errorText: field.errorText,
              ),
              child: Column(
                children: question.choices
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
                            _surveyAnswers[question.name] = selected;
                            field.didChange(selected);
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      );
    }

    if (question.type == 'select_one') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionPrompt(question),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _surveyAnswers[question.name] as String?,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: question.hint ?? 'Select an option',
              border: const OutlineInputBorder(),
            ),
            items: question.choices
                .map(
                  (choice) => DropdownMenuItem(
                    value: choice.value,
                    child: Text(choice.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() => _surveyAnswers[question.name] = value);
            },
            validator: (value) => question.required && value == null
                ? 'Please select an option'
                : null,
          ),
        ],
      );
    }

    final controller = _surveyTextControllers.putIfAbsent(
      question.name,
      () => TextEditingController(
        text: _surveyAnswers[question.name]?.toString() ?? '',
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionPrompt(question),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: question.type == 'integer'
              ? TextInputType.number
              : TextInputType.text,
          minLines: question.label.toLowerCase().contains('comment') ? 3 : 1,
          maxLines: question.label.toLowerCase().contains('comment') ? 5 : 2,
          decoration: InputDecoration(
            hintText: question.hint,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => _surveyAnswers[question.name] = value.trim(),
          validator: (value) =>
              question.required && (value == null || value.trim().isEmpty)
              ? 'This field is required'
              : null,
        ),
      ],
    );
  }

  Widget _buildQuestionPrompt(EnvironmentalSurveyQuestion question) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: question.label),
          if (question.required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red.shade700),
            ),
        ],
      ),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    );
  }

  bool _isWaterFieldVisible(WaterQualityField field) {
    if (field.visibleWhenRules.isNotEmpty) {
      return field.visibleWhenRules.any((rule) {
        final dependency = (rule['questionId'] ?? '').trim();
        final expected = (rule['value'] ?? '').trim();
        if (dependency.isEmpty || expected.isEmpty) return false;
        final dependencyField = _waterFields
            .where((item) => item.name == dependency)
            .firstOrNull;
        if (dependencyField != null && !_isWaterFieldVisible(dependencyField)) {
          return false;
        }
        final answer = _waterAnswers[dependency];
        if (expected == '__answered__') {
          return '${answer ?? ''}'.trim().isNotEmpty;
        }
        return answer == expected;
      });
    }
    final dependency = field.visibleWhenField;
    if (dependency == null) return true;
    final dependencyField = _waterFields
        .where((item) => item.name == dependency)
        .firstOrNull;
    if (dependencyField != null && !_isWaterFieldVisible(dependencyField)) {
      return false;
    }
    return field.visibleWhenValues.contains(_waterAnswers[dependency]);
  }

  Widget _buildWaterQualityQuestionnaire() {
    final visibleFields = _waterFields.where(_isWaterFieldVisible).toList();
    String? currentSection;
    String? lastRenderedHeadingKey;
    final useTemplateSubHeadings =
        _facilityWaterQualityFields != null &&
        visibleFields.any((field) => field.type == 'note');
    final fieldWidgets = <Widget>[];
    for (final field in visibleFields) {
      if (currentSection != field.section) {
        currentSection = field.section;
        if (!useTemplateSubHeadings) {
          fieldWidgets
            ..add(_buildWaterSectionHeader(field.section))
            ..add(const SizedBox(height: 12));
          lastRenderedHeadingKey = _surveillanceHeadingKey(field.section);
        } else {
          lastRenderedHeadingKey = null;
        }
      }
      if (_isDuplicateWaterSubHeading(field, lastRenderedHeadingKey)) {
        continue;
      }
      fieldWidgets
        ..add(_buildWaterField(field))
        ..add(const SizedBox(height: 16));
      if (field.type == 'note') {
        lastRenderedHeadingKey = _surveillanceHeadingKey(field.label);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildWaterCollectionDateTime(showHeader: !useTemplateSubHeadings),
        const SizedBox(height: 16),
        ...fieldWidgets,
        _buildWaterStatusSummary(),
        const SizedBox(height: 16),
        if (_waterAnswers['Department_Informed'] == 'Yes')
          _buildDateField(
            label: 'Action Date',
            value: _waterActionDate,
            onChanged: (value) => setState(() => _waterActionDate = value),
          ),
        if (_waterAnswers['Department_Informed'] == 'Yes')
          const SizedBox(height: 16),
        if (_waterAnswers['Follow_Up_Required'] == 'Yes')
          _buildDateField(
            label: 'Follow-up Date',
            value: _waterFollowUpDate,
            onChanged: (value) => setState(() => _waterFollowUpDate = value),
          ),
      ],
    );
  }

  Widget _buildWaterCollectionDateTime({bool showHeader = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          _buildWaterSectionHeader('Collection Details'),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(
                'Collection date: ${DateFormat('MMM d, y').format(_waterCollectionDate)}',
              ),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _waterCollectionDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) {
                  setState(() => _waterCollectionDate = picked);
                }
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: Text(
                'Collection time: ${_waterCollectionTime.format(context)}',
              ),
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _waterCollectionTime,
                );
                if (picked != null) {
                  setState(() => _waterCollectionTime = picked);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWaterSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(left: BorderSide(color: Colors.blue.shade700, width: 4)),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.blue.shade900,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  bool _isDuplicateWaterSubHeading(
    WaterQualityField field,
    String? previousHeadingKey,
  ) {
    if (field.type != 'note') return false;
    final labelKey = _surveillanceHeadingKey(field.label);
    final sectionKey = _surveillanceHeadingKey(field.section);
    return labelKey.isNotEmpty &&
        (labelKey == sectionKey ||
            labelKey.contains(sectionKey) ||
            sectionKey.contains(labelKey) ||
            labelKey == previousHeadingKey);
  }

  String _surveillanceHeadingKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();
  }

  Widget _buildWaterField(WaterQualityField field) {
    if (field.type == 'note') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          border: Border(
            left: BorderSide(color: Colors.blue.shade700, width: 4),
          ),
        ),
        child: Text(
          field.label,
          style: TextStyle(
            color: Colors.blue.shade900,
            fontSize: 16,
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          prompt,
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _waterAnswers[field.name] as String?,
            isExpanded: true,
            decoration: const InputDecoration(
              hintText: 'Select an option',
              border: OutlineInputBorder(),
            ),
            items: field.options
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(option, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() => _waterAnswers[field.name] = value);
            },
            validator: (value) =>
                field.required && (value == null || value.isEmpty)
                ? 'Please select an option'
                : null,
          ),
        ],
      );
    }

    final controller = _waterTextControllers.putIfAbsent(
      field.name,
      () => TextEditingController(
        text: _waterAnswers[field.name]?.toString() ?? '',
      ),
    );
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
          minLines: field.type == 'multiline' ? 3 : 1,
          maxLines: field.type == 'multiline' ? 5 : 2,
          decoration: InputDecoration(
            hintText: field.hint,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => _waterAnswers[field.name] = value.trim(),
          validator: (value) =>
              field.required && (value == null || value.trim().isEmpty)
              ? 'This field is required'
              : null,
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onChanged,
  }) {
    return FormField<DateTime>(
      validator: (_) => value == null ? 'Please select $label' : null,
      builder: (field) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          side: BorderSide(
            color: field.hasError ? Colors.red : Colors.grey.shade500,
          ),
        ),
        icon: const Icon(Icons.calendar_today),
        label: Text(
          value == null
              ? 'Select $label *'
              : '$label: ${DateFormat('MMM d, y').format(value)}',
        ),
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 3650)),
          );
          if (picked != null) {
            onChanged(picked);
            field.didChange(picked);
          }
        },
      ),
    );
  }

  ({String meetsStandard, String overallStatus}) _waterQualityStatus() {
    const physicalChecks = [
      'Water_Clear',
      'No_Unusual_Colour',
      'No_Offensive_Odour',
      'Storage_Tank_Covered',
      'Tap_Clean',
      'No_Leakage',
      'Chlorine_Available',
    ];
    final keyResults = [
      _waterAnswers['E_coli'],
      _waterAnswers['Culture_Done'],
      ...physicalChecks.map((field) => _waterAnswers[field]),
    ];
    if (keyResults.any((value) => value == null) ||
        (_waterAnswers['Culture_Done'] == 'Yes' &&
            _waterAnswers['Growth_Result'] == null) ||
        (['Growth', 'Mixed growth'].contains(_waterAnswers['Growth_Result']) &&
            _waterAnswers['Significance_1'] == null)) {
      return (meetsStandard: 'Pending', overallStatus: 'Pending');
    }

    final physicalChecksAcceptable = physicalChecks.every(
      (field) =>
          _waterAnswers[field] == 'Yes' ||
          _waterAnswers[field] == 'Not Applicable',
    );
    final significantGrowth = [1, 2, 3].any((index) {
      final field = _waterFields
          .where((item) => item.name == 'Significance_$index')
          .firstOrNull;
      return field != null &&
          _isWaterFieldVisible(field) &&
          _waterAnswers[field.name] == 'Significant';
    });
    final unsafe =
        _waterAnswers['E_coli'] == 'Present' ||
        significantGrowth ||
        !physicalChecksAcceptable;

    return unsafe
        ? (meetsStandard: 'No', overallStatus: 'Unsatisfactory')
        : (meetsStandard: 'Yes', overallStatus: 'Safe');
  }

  Widget _buildWaterStatusSummary() {
    final status = _waterQualityStatus();
    final color = switch (status.overallStatus) {
      'Safe' => Colors.green,
      'Unsatisfactory' => Colors.red,
      _ => Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.shade50,
        border: Border.all(color: color.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: color.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Overall status: ${status.overallStatus}\nMeets standard: ${status.meetsStandard}',
              style: TextStyle(
                color: color.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _visibleWaterAnswers() {
    return {
      for (final field in _waterFields)
        if (_isWaterFieldVisible(field) &&
            _waterAnswers[field.name] != null &&
            _waterAnswers[field.name].toString().trim().isNotEmpty)
          field.name: _waterAnswers[field.name],
    };
  }

  static const Map<String, String> _waterSectionIds = {
    'Sample Information': 'sample_information',
    'Physical and IPC Assessment': 'physical_ipc_assessment',
    'Physical and Chemical Results': 'physical_chemical_results',
    'Microbiology Results': 'microbiology_results',
    'Culture Results': 'culture_results',
    'Assessment and Corrective Actions': 'assessment_corrective_actions',
  };

  Map<String, String> _waterSectionStatus(Map<String, dynamic> answers) {
    return {
      for (final section in _waterSectionIds.keys)
        _waterSectionIds[section]!: _isWaterSectionComplete(section, answers)
            ? 'complete'
            : 'pending',
    };
  }

  bool _isWaterSectionComplete(String section, Map<String, dynamic> answers) {
    if (section == 'Sample Information') {
      if (_department == null || _department!.trim().isEmpty) return false;
      if (_departmentUnits.containsKey(_department) &&
          (_unit == null || _unit!.trim().isEmpty)) {
        return false;
      }
    }
    final requiredFields = _waterFields.where(
      (field) => field.section == section && field.required,
    );
    for (final field in requiredFields) {
      if (!_isWaterFieldVisible(field)) continue;
      final value = answers[field.name];
      if (value == null || value.toString().trim().isEmpty) return false;
    }
    if (section == 'Assessment and Corrective Actions') {
      if (_waterAnswers['Department_Informed'] == 'Yes' &&
          _waterActionDate == null) {
        return false;
      }
      if (_waterAnswers['Follow_Up_Required'] == 'Yes' &&
          _waterFollowUpDate == null) {
        return false;
      }
    }
    return true;
  }

  Future<void> _submitInspection({bool finalSubmit = true}) async {
    final existingFinal =
        widget.initialData?['isFinal'] == true ||
        widget.initialData?['submissionStatus'] == 'Final';
    if (!finalSubmit && existingFinal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Final submissions can only be updated as final.'),
        ),
      );
      return;
    }
    if (finalSubmit && !_formKey.currentState!.validate()) return;
    if (!finalSubmit && _inspectionType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select surveillance type')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Calculate compliance if Waste Management inspection
      int? compliantItems;
      int? totalItems;
      double? compliancePercentage;

      if (_inspectionType == 'Waste Management') {
        compliantItems = _checklistItems.values.where((v) => v).length;
        totalItems = _checklistItems.length;
        compliancePercentage = totalItems > 0
            ? (compliantItems / totalItems) * 100
            : 0;
      }

      final isGeneralEnvironmentalHealth =
          _inspectionType == 'General Environmental Health';
      final isWaterQuality = _inspectionType == 'Water Quality';
      final surveyAnswers = isGeneralEnvironmentalHealth
          ? _visibleSurveyAnswers()
          : null;
      final surveyAnswerLabels = isGeneralEnvironmentalHealth
          ? _visibleSurveyAnswerLabels()
          : null;
      final department = isGeneralEnvironmentalHealth
          ? _choiceLabel('Department_Unit', _surveyAnswers['Department_Unit'])
          : _department;
      final unit = isGeneralEnvironmentalHealth ? _selectedUnitLabel() : _unit;
      final waterStatus = _waterQualityStatus();
      final waterCollectionDateTime = DateTime(
        _waterCollectionDate.year,
        _waterCollectionDate.month,
        _waterCollectionDate.day,
        _waterCollectionTime.hour,
        _waterCollectionTime.minute,
      );
      final waterAnswers = isWaterQuality ? _visibleWaterAnswers() : null;
      if (waterAnswers != null) {
        for (final fieldName in [
          'pH',
          'Temperature_C',
          'Residual_Chlorine_mg_L',
          'HPC_CFU_mL',
          'CFU_1',
          'CFU_2',
          'CFU_3',
        ]) {
          final value = waterAnswers[fieldName];
          if (value is String && value.isNotEmpty) {
            waterAnswers[fieldName] = num.tryParse(value) ?? value;
          }
        }
      }
      final formId =
          widget.initialData?['formId'] as String? ??
          await SurveillanceFormIdService.nextFormId(
            facilityId: widget.facilityId,
            surveillanceCode:
                '${widget.dashboardSource}_${isWaterQuality
                    ? 'water_quality'
                    : isGeneralEnvironmentalHealth
                    ? 'general_environmental_health'
                    : _inspectionType ?? 'environmental_surveillance'}',
          );
      final recordId =
          widget.initialData?['recordId'] as String? ??
          (widget.initialData?['waterQualityData'] is Map
              ? (widget.initialData!['waterQualityData'] as Map)['Record_ID']
                    as String?
              : null) ??
          formId;

      final waterSectionStatus = isWaterQuality
          ? _waterSectionStatus(waterAnswers ?? const {})
          : null;
      final pendingWaterSections = waterSectionStatus?.entries
          .where((entry) => entry.value != 'complete')
          .map((entry) => entry.key)
          .toList();
      final changeEntry = {
        'staffId': widget.staffId,
        'staffName': widget.staffName,
        'action': finalSubmit ? 'final_submit' : 'save_draft',
        'at': Timestamp.now(),
        'inspectionType': _inspectionType,
        'sectionStatus': ?waterSectionStatus,
      };

      final inspectionData = {
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityName,
        'inspectorId': widget.staffId,
        'inspectorName': widget.staffName,
        'createdBy': widget.initialData?['createdBy'] ?? widget.staffName,
        'createdById': widget.initialData?['createdById'] ?? widget.staffId,
        'dashboardSource': widget.dashboardSource,
        'inspectionType': _inspectionType,
        'formId': formId,
        'department': department,
        'unit': unit,
        'ward': unit,
        'findingsLevel': isGeneralEnvironmentalHealth || isWaterQuality
            ? null
            : _findingsLevel,
        'findings': isGeneralEnvironmentalHealth || isWaterQuality
            ? null
            : _findingsController.text.trim(),
        'recommendations': isGeneralEnvironmentalHealth || isWaterQuality
            ? null
            : _recommendationsController.text.trim(),
        'inspectionDate': FieldValue.serverTimestamp(),
        'reportedDate': FieldValue.serverTimestamp(),
        'status': isWaterQuality
            ? finalSubmit
                  ? waterStatus.overallStatus.toLowerCase()
                  : 'pending'
            : isGeneralEnvironmentalHealth
            ? finalSubmit
                  ? 'submitted'
                  : 'draft'
            : _findingsLevel == 'No Issues'
            ? 'compliant'
            : 'action_required',
        'submissionStatus': finalSubmit ? 'Final' : 'Draft',
        'submissionState': finalSubmit ? 'final' : 'draft',
        'isFinal': finalSubmit,
        if (finalSubmit) ...{
          'finalizedBy': widget.staffName,
          'finalizedById': widget.staffId,
          'finalizedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': widget.staffName,
        'lastUpdatedById': widget.staffId,
        'changeHistory': FieldValue.arrayUnion([changeEntry]),
        if (isGeneralEnvironmentalHealth) ...{
          'questionnaireVersion': 'environmental-health-xlsform-v1',
          'questionnaireResponses': surveyAnswers,
          'questionnaireResponseLabels': surveyAnswerLabels,
          'answeredQuestions': surveyAnswers!.length,
        },
        if (isWaterQuality) ...{
          'questionnaireVersion': 'simple-water-quality-v1',
          'recordId': recordId,
          'sampleId': waterAnswers!['Sample_ID'],
          'samplingPoint': waterAnswers['Sampling_Point'],
          'waterSource': waterAnswers['Water_Source'],
          'sampleType': waterAnswers['Sample_Type'],
          'labNumber': waterAnswers['Lab_Number'],
          'collectionDate': Timestamp.fromDate(waterCollectionDateTime),
          'meetsStandard': waterStatus.meetsStandard,
          'overallStatus': waterStatus.overallStatus,
          'immediateActionRequired': waterAnswers['Immediate_Action_Required'],
          'followUpRequired': waterAnswers['Follow_Up_Required'],
          'sectionStatus': waterSectionStatus,
          'pendingSections': pendingWaterSections,
          'completedSections': waterSectionStatus!.entries
              .where((entry) => entry.value == 'complete')
              .map((entry) => entry.key)
              .toList(),
          'waterQualityData': {
            'Record_ID': recordId,
            'Sample_ID': waterAnswers['Sample_ID'],
            'Collection_Date': Timestamp.fromDate(_waterCollectionDate),
            'Collection_Time':
                '${_waterCollectionTime.hour.toString().padLeft(2, '0')}:${_waterCollectionTime.minute.toString().padLeft(2, '0')}',
            'Facility': widget.facilityName,
            'Ward_Department': department,
            'Unit': unit,
            'Collected_By': widget.staffName,
            ...waterAnswers,
            'Meets_Standard': waterStatus.meetsStandard,
            'Overall_Status': waterStatus.overallStatus,
            if (_waterActionDate != null)
              'Action_Date': Timestamp.fromDate(_waterActionDate!),
            if (_waterFollowUpDate != null)
              'Follow_Up_Date': Timestamp.fromDate(_waterFollowUpDate!),
          },
        },
        // Sanitation checklist fields (for Waste Management)
        if (_inspectionType == 'Waste Management') ...{
          'checklistItems': _checklistItems,
          'compliantItems': compliantItems,
          'totalItems': totalItems,
          'compliancePercentage': compliancePercentage,
          'notes': _notesController.text.trim(),
        },
      };

      final existingDocumentId = widget.documentId ?? _waterDraftDocumentId;
      if (existingDocumentId != null) {
        await FirebaseFirestore.instance
            .collection('environmental_inspections')
            .doc(existingDocumentId)
            .update(inspectionData);
      } else {
        final document = await FirebaseFirestore.instance
            .collection('environmental_inspections')
            .add({
              ...inspectionData,
              'createdAt': FieldValue.serverTimestamp(),
            });
        if (isWaterQuality) {
          _waterDraftDocumentId = document.id;
        }
      }

      if (mounted) {
        if (finalSubmit) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              finalSubmit
                  ? 'Environmental surveillance submitted successfully'
                  : 'Water quality draft saved. Pending sections will show in Surveillance Data.',
            ),
          ),
        );
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
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.assignment, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Environmental Inspection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      DropdownButtonFormField<String>(
                        value: _inspectionType,
                        decoration: const InputDecoration(
                          labelText: 'Inspection Type *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: _inspectionTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _inspectionType = value),
                        validator: (value) => value == null
                            ? 'Please select inspection type'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      if (_inspectionType != null &&
                          !_isTemplateBackedInspectionType)
                        _buildTemplateUnavailable(
                          title: 'Template unavailable',
                          message:
                              'This older hard-coded form is no longer available. Ask the facility admin to save an editable template from IPC Dashboard Control before staff use this form.',
                        )
                      else if (_inspectionType ==
                          'General Environmental Health')
                        if (_isLoadingEnvironmentalTemplate)
                          _buildTemplateLoading(
                            'Loading Environmental Health Surveillance template...',
                          )
                        else if (_environmentalQuestions.isEmpty)
                          _buildTemplateUnavailable(
                            title:
                                'Environmental Health Surveillance template unavailable',
                            message:
                                _environmentalTemplateError ??
                                'Save the Environmental Health Surveillance template from IPC Dashboard Control before staff use this form.',
                          )
                        else
                          _buildEnvironmentalHealthQuestionnaire()
                      else if (_inspectionType == 'Water Quality') ...[
                        DropdownButtonFormField<String>(
                          value: _department,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Department *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business),
                          ),
                          items: _departments.map((dept) {
                            return DropdownMenuItem(
                              value: dept,
                              child: Text(
                                dept,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _department = value;
                              _unit = null;
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Please select department' : null,
                        ),
                        const SizedBox(height: 16),
                        if (_department != null &&
                            _departmentUnits.containsKey(_department))
                          DropdownButtonFormField<String>(
                            value: _unit,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Ward / Unit *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.apartment),
                            ),
                            items: _departmentUnits[_department]!.map((unit) {
                              return DropdownMenuItem(
                                value: unit,
                                child: Text(
                                  unit,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => _unit = value),
                            validator: (value) => value == null
                                ? 'Please select ward or unit'
                                : null,
                          ),
                        if (_department != null &&
                            _departmentUnits.containsKey(_department))
                          const SizedBox(height: 16),
                      ],
                      if (_inspectionType == 'Water Quality')
                        if (_isLoadingWaterQualityTemplate)
                          _buildTemplateLoading(
                            'Loading Water Quality Surveillance template...',
                          )
                        else if (_waterFields.isEmpty)
                          _buildTemplateUnavailable(
                            title:
                                'Water Quality Surveillance template unavailable',
                            message:
                                _waterQualityTemplateError ??
                                'Save the Water Quality Surveillance template from IPC Dashboard Control before staff use this form.',
                          )
                        else
                          _buildWaterQualityQuestionnaire(),
                      // Sanitation Checklist Section (for Waste Management)
                      if (_inspectionType == 'Waste Management') ...[
                        Card(
                          color: Colors.teal.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.checklist,
                                      color: Colors.teal.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Sanitation Checklist',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${_checklistItems.values.where((v) => v).length}/${_checklistItems.length}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: _checklistItems.isEmpty
                                      ? 0
                                      : _checklistItems.values
                                                .where((v) => v)
                                                .length /
                                            _checklistItems.length,
                                  backgroundColor: Colors.grey.shade300,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.teal.shade700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Compliance: ${_checklistItems.isEmpty ? 0 : ((_checklistItems.values.where((v) => v).length / _checklistItems.length) * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(_checklistQuestions.length, (index) {
                          final question = _checklistQuestions[index];
                          return CheckboxListTile(
                            value: _checklistItems[question] ?? false,
                            onChanged: (value) {
                              setState(() {
                                _checklistItems[question] = value ?? false;
                              });
                            },
                            title: Text(question),
                            subtitle: Text(
                              'Item ${index + 1} of ${_checklistQuestions.length}',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.teal,
                          );
                        }),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Additional Notes/Observations',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.note),
                            hintText: 'Any additional sanitation observations',
                            fillColor: Colors.white,
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 24),
                      if (_inspectionType != null &&
                          widget.initialData?['isFinal'] != true &&
                          widget.initialData?['submissionStatus'] !=
                              'Final') ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                _isSubmitting || _selectedTemplateUnavailable
                                ? null
                                : () => _submitInspection(finalSubmit: false),
                            icon: const Icon(Icons.fact_check_outlined),
                            label: const Text('Save progress'),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isSubmitting || _selectedTemplateUnavailable
                              ? null
                              : () => _submitInspection(finalSubmit: true),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _isSubmitting
                                ? 'Saving...'
                                : _inspectionType == 'Water Quality'
                                ? 'Final submit'
                                : 'Submit Inspection',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
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
      },
    );
  }
}

// 1. Inspection Summary Report View
class _InspectionSummaryReportView extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final ScrollController scrollController;

  const _InspectionSummaryReportView({
    required this.facilityId,
    required this.facilityName,
    required this.scrollController,
  });

  @override
  State<_InspectionSummaryReportView> createState() =>
      _InspectionSummaryReportViewState();
}

class _InspectionSummaryReportViewState
    extends State<_InspectionSummaryReportView> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = now.subtract(const Duration(days: 30));
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Inspection Summary Report',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      'From: ${DateFormat('MMM dd, yyyy').format(_startDate)}',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _startDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      'To: ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _endDate = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('environmental_inspections')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .orderBy('inspectionDate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                print(
                  '🔍 [Inspection Summary] Connection state: ${snapshot.connectionState}',
                );
                print('🔍 [Inspection Summary] Has data: ${snapshot.hasData}');
                print(
                  '🔍 [Inspection Summary] Docs count: ${snapshot.data?.docs.length ?? 0}',
                );

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  print('❌ [Inspection Summary] Error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading data: ${snapshot.error}',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  print(
                    '📭 [Inspection Summary] No documents found in collection',
                  );
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No inspections found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                // Filter inspections by date range client-side
                final allInspections = snapshot.data!.docs;
                print(
                  '📊 [Inspection Summary] Total docs before filtering: ${allInspections.length}',
                );
                print(
                  '📅 [Inspection Summary] Date range: $_startDate to $_endDate',
                );

                final inspections = allInspections.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final inspectionDate = (data['inspectionDate'] as Timestamp?)
                      ?.toDate();
                  print('  📝 Doc ${doc.id}: date=$inspectionDate');
                  if (inspectionDate == null) return false;
                  final inRange =
                      inspectionDate.isAfter(
                        _startDate.subtract(const Duration(days: 1)),
                      ) &&
                      inspectionDate.isBefore(
                        _endDate.add(const Duration(days: 1)),
                      );
                  print('     In range: $inRange');
                  return inRange;
                }).toList();

                print(
                  '✅ [Inspection Summary] Filtered docs: ${inspections.length}',
                );

                if (inspections.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No inspections found for selected period',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                final total = inspections.length;

                // Count by type
                final typeCount = <String, int>{};
                final findingsCount = <String, int>{};
                final departmentCount = <String, int>{};

                for (var doc in inspections) {
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['inspectionType'] ?? 'Unknown';
                  final findings = data['findingsLevel'] ?? 'Unknown';
                  final department = data['department'] ?? 'Unknown';

                  typeCount[type] = (typeCount[type] ?? 0) + 1;
                  findingsCount[findings] = (findingsCount[findings] ?? 0) + 1;
                  departmentCount[department] =
                      (departmentCount[department] ?? 0) + 1;
                }

                return ListView(
                  controller: widget.scrollController,
                  children: [
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Summary Statistics',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatBox(
                                  'Total\nInspections',
                                  '$total',
                                  Colors.blue,
                                ),
                                _buildStatBox(
                                  'No Issues',
                                  '${findingsCount['No Issues'] ?? 0}',
                                  Colors.green,
                                ),
                                _buildStatBox(
                                  'Minor',
                                  '${findingsCount['Minor Issues'] ?? 0}',
                                  Colors.amber,
                                ),
                                _buildStatBox(
                                  'Critical',
                                  '${findingsCount['Critical Issues'] ?? 0}',
                                  Colors.red,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'By Inspection Type',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...typeCount.entries.map(
                      (entry) => Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${entry.value}')),
                          title: Text(entry.key),
                          subtitle: Text(
                            '${((entry.value / total) * 100).toStringAsFixed(1)}% of total',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'By Department',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...departmentCount.entries.map(
                      (entry) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            child: Text('${entry.value}'),
                          ),
                          title: Text(entry.key),
                          subtitle: Text('${entry.value} inspections'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Recent Inspections',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...inspections.take(10).map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final date = (data['inspectionDate'] as Timestamp)
                          .toDate();
                      final findingsLevel = data['findingsLevel'] ?? 'Unknown';
                      Color levelColor = Colors.green;
                      if (findingsLevel == 'Minor') levelColor = Colors.amber;
                      if (findingsLevel == 'Major') levelColor = Colors.orange;
                      if (findingsLevel == 'Critical') levelColor = Colors.red;

                      return Card(
                        child: ListTile(
                          leading: Container(width: 8, color: levelColor),
                          title: Text(data['inspectionType'] ?? 'Unknown'),
                          subtitle: Text(
                            '${data['department']} - ${DateFormat('MMM dd, yyyy').format(date)}\n${data['findings'] ?? ''}',
                          ),
                          isThreeLine: true,
                          trailing: Chip(
                            label: Text(
                              findingsLevel,
                              style: const TextStyle(fontSize: 10),
                            ),
                            backgroundColor: levelColor.withOpacity(0.2),
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

  Widget _buildStatBox(String label, String value, Color color) {
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
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }
}

// 2. Sanitation Compliance Report View
class _SanitationComplianceReportView extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final ScrollController scrollController;

  const _SanitationComplianceReportView({
    required this.facilityId,
    required this.facilityName,
    required this.scrollController,
  });

  @override
  State<_SanitationComplianceReportView> createState() =>
      _SanitationComplianceReportViewState();
}

class _SanitationComplianceReportViewState
    extends State<_SanitationComplianceReportView> {
  late DateTime _startDate;
  late DateTime _endDate;
  String? _selectedDepartment;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = now.subtract(const Duration(days: 30));
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sanitation Compliance Report',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    'From: ${DateFormat('MMM dd').format(_startDate)}',
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _startDate = picked);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('To: ${DateFormat('MMM dd').format(_endDate)}'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate,
                      firstDate: _startDate,
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _endDate = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedDepartment,
            decoration: const InputDecoration(
              labelText: 'Filter by Department',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('All Departments'),
              ),
              ...[
                'Nursing',
                'Laboratory',
                'Pharmacy',
                'Radiology',
                'Surgery/Theatre',
                'Emergency',
                'Outpatient',
                'Administration',
                'Kitchen/Catering',
                'Laundry',
                'Maintenance',
              ].map((dept) => DropdownMenuItem(value: dept, child: Text(dept))),
            ],
            onChanged: (value) => setState(() => _selectedDepartment = value),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No sanitation checklists found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                // Filter by date range client-side
                final allChecklists = snapshot.data!.docs;
                final checklists = allChecklists.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final inspectionDate = (data['inspectionDate'] as Timestamp?)
                      ?.toDate();
                  if (inspectionDate == null) return false;
                  return inspectionDate.isAfter(
                        _startDate.subtract(const Duration(days: 1)),
                      ) &&
                      inspectionDate.isBefore(
                        _endDate.add(const Duration(days: 1)),
                      );
                }).toList();

                if (checklists.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No sanitation checklists found for selected period',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                final total = checklists.length;

                // Calculate average compliance
                double totalCompliance = 0;
                int compliantCount = 0;
                final departmentCompliance = <String, List<double>>{};

                for (var doc in checklists) {
                  final data = doc.data() as Map<String, dynamic>;
                  final compliance = data['compliancePercentage'] ?? 0.0;
                  final department = data['department'] ?? 'Unknown';

                  totalCompliance += compliance;
                  if (compliance >= 80) compliantCount++;

                  departmentCompliance.putIfAbsent(department, () => []);
                  departmentCompliance[department]!.add(compliance.toDouble());
                }

                final avgCompliance = total > 0 ? totalCompliance / total : 0.0;

                return ListView(
                  controller: widget.scrollController,
                  children: [
                    Card(
                      color: Colors.teal.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Compliance Overview',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatBox(
                                  'Average\nCompliance',
                                  '${avgCompliance.toStringAsFixed(1)}%',
                                  avgCompliance >= 80
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                _buildStatBox(
                                  'Total\nChecklists',
                                  '$total',
                                  Colors.blue,
                                ),
                                _buildStatBox(
                                  'Compliant\n(≥80%)',
                                  '$compliantCount',
                                  Colors.green,
                                ),
                                _buildStatBox(
                                  'Non-Compliant\n(<80%)',
                                  '${total - compliantCount}',
                                  Colors.orange,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Department Performance',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...departmentCompliance.entries.map((entry) {
                      final deptAvg =
                          entry.value.reduce((a, b) => a + b) /
                          entry.value.length;
                      final color = deptAvg >= 80
                          ? Colors.green
                          : (deptAvg >= 60 ? Colors.amber : Colors.red);

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.2),
                            child: Icon(Icons.check_circle, color: color),
                          ),
                          title: Text(entry.key),
                          subtitle: Text('${entry.value.length} checklists'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${deptAvg.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              Text(
                                deptAvg >= 80
                                    ? 'Compliant'
                                    : 'Needs Improvement',
                                style: TextStyle(fontSize: 10, color: color),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    const Text(
                      'Recent Checklists',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...checklists.take(15).map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final date = (data['inspectionDate'] as Timestamp)
                          .toDate();
                      final compliance = data['compliancePercentage'] ?? 0.0;
                      final compliantItems = data['compliantItems'] ?? 0;
                      final totalItems = data['totalItems'] ?? 18;

                      Color complianceColor = Colors.green;
                      if (compliance < 60) {
                        complianceColor = Colors.red;
                      } else if (compliance < 80)
                        complianceColor = Colors.amber;

                      return Card(
                        child: ListTile(
                          leading: Container(width: 6, color: complianceColor),
                          title: Text(data['department'] ?? 'Unknown'),
                          subtitle: Text(
                            '${data['unit'] ?? data['ward'] ?? 'N/A'} - ${DateFormat('MMM dd, yyyy').format(date)}\n$compliantItems/$totalItems items compliant',
                          ),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${compliance.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: complianceColor,
                                ),
                              ),
                              Icon(
                                compliance >= 80
                                    ? Icons.check_circle
                                    : Icons.warning,
                                color: complianceColor,
                                size: 16,
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

  Stream<QuerySnapshot> _buildQuery() {
    Query query = FirebaseFirestore.instance
        .collection('environmental_inspections')
        .where('facilityId', isEqualTo: widget.facilityId)
        .where('inspectionType', isEqualTo: 'Waste Management');

    if (_selectedDepartment != null) {
      query = query.where('department', isEqualTo: _selectedDepartment);
    }

    return query.orderBy('inspectionDate', descending: true).snapshots();
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9),
        ),
      ],
    );
  }
}

// 3. Department Performance Report View
class _DepartmentPerformanceReportView extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final ScrollController scrollController;

  const _DepartmentPerformanceReportView({
    required this.facilityId,
    required this.facilityName,
    required this.scrollController,
  });

  @override
  State<_DepartmentPerformanceReportView> createState() =>
      _DepartmentPerformanceReportViewState();
}

class _DepartmentPerformanceReportViewState
    extends State<_DepartmentPerformanceReportView> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = now.subtract(const Duration(days: 30));
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Department Performance',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    'From: ${DateFormat('MMM dd').format(_startDate)}',
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _startDate = picked);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('To: ${DateFormat('MMM dd').format(_endDate)}'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate,
                      firstDate: _startDate,
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _endDate = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<QuerySnapshot>>(
              stream: _buildCombinedQuery(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No data found for selected period',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                final inspectionsSnapshot = snapshot.data![0];
                final checklistsSnapshot = snapshot.data![1];

                // Filter by date range client-side
                final allInspectionDocs = inspectionsSnapshot.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final inspectionDate = (data['inspectionDate'] as Timestamp?)
                      ?.toDate();
                  if (inspectionDate == null) return false;
                  return inspectionDate.isAfter(
                        _startDate.subtract(const Duration(days: 1)),
                      ) &&
                      inspectionDate.isBefore(
                        _endDate.add(const Duration(days: 1)),
                      );
                }).toList();

                final allChecklistDocs = checklistsSnapshot.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final inspectionDate = (data['inspectionDate'] as Timestamp?)
                      ?.toDate();
                  if (inspectionDate == null) return false;
                  return inspectionDate.isAfter(
                        _startDate.subtract(const Duration(days: 1)),
                      ) &&
                      inspectionDate.isBefore(
                        _endDate.add(const Duration(days: 1)),
                      );
                }).toList();

                if (allInspectionDocs.isEmpty && allChecklistDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No data found for selected period',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                final departmentData = <String, Map<String, dynamic>>{};
                final departments = [
                  'Nursing',
                  'Laboratory',
                  'Pharmacy',
                  'Radiology',
                  'Surgery/Theatre',
                  'Emergency',
                  'Outpatient',
                  'Administration',
                  'Kitchen/Catering',
                  'Laundry',
                  'Maintenance',
                ];

                // Initialize all departments
                for (var dept in departments) {
                  departmentData[dept] = {
                    'inspections': 0,
                    'checklists': 0,
                    'criticalIssues': 0,
                    'avgCompliance': 0.0,
                    'complianceScores': <double>[],
                  };
                }

                // Process inspections
                for (var doc in allInspectionDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final dept = data['department'] ?? 'Unknown';
                  if (departmentData.containsKey(dept)) {
                    departmentData[dept]!['inspections'] =
                        (departmentData[dept]!['inspections'] as int) + 1;
                    if (data['findingsLevel'] == 'Critical Issues' ||
                        data['findingsLevel'] == 'Major Issues') {
                      departmentData[dept]!['criticalIssues'] =
                          (departmentData[dept]!['criticalIssues'] as int) + 1;
                    }
                  }
                }

                // Process checklists
                for (var doc in allChecklistDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final dept = data['department'] ?? 'Unknown';
                  if (departmentData.containsKey(dept)) {
                    departmentData[dept]!['checklists'] =
                        (departmentData[dept]!['checklists'] as int) + 1;
                    final compliance = (data['compliancePercentage'] ?? 0.0)
                        .toDouble();
                    (departmentData[dept]!['complianceScores'] as List<double>)
                        .add(compliance);
                  }
                }

                // Calculate average compliance
                departmentData.forEach((dept, data) {
                  final scores = data['complianceScores'] as List<double>;
                  if (scores.isNotEmpty) {
                    data['avgCompliance'] =
                        scores.reduce((a, b) => a + b) / scores.length;
                  }
                });

                // Sort by total activity (inspections + checklists)
                final sortedDepartments = departmentData.entries.toList()
                  ..sort((a, b) {
                    final aTotal =
                        (a.value['inspections'] as int) +
                        (a.value['checklists'] as int);
                    final bTotal =
                        (b.value['inspections'] as int) +
                        (b.value['checklists'] as int);
                    return bTotal.compareTo(aTotal);
                  });

                return ListView(
                  controller: widget.scrollController,
                  children: [
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: const Text(
                          'This report shows environmental health performance across all departments, '
                          'combining inspection results and sanitation compliance data.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...sortedDepartments.map((entry) {
                      final dept = entry.key;
                      final data = entry.value;
                      final inspections = data['inspections'] as int;
                      final checklists = data['checklists'] as int;
                      final criticalIssues = data['criticalIssues'] as int;
                      final avgCompliance = data['avgCompliance'] as double;
                      final totalActivity = inspections + checklists;

                      if (totalActivity == 0) return const SizedBox.shrink();

                      Color performanceColor = Colors.green;
                      String performanceLabel = 'Excellent';

                      if (criticalIssues > 0 || avgCompliance < 60) {
                        performanceColor = Colors.red;
                        performanceLabel = 'Needs Attention';
                      } else if (avgCompliance < 80) {
                        performanceColor = Colors.amber;
                        performanceLabel = 'Fair';
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: performanceColor.withOpacity(0.2),
                            child: Icon(
                              Icons.business,
                              color: performanceColor,
                            ),
                          ),
                          title: Text(
                            dept,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '$totalActivity total activities - $performanceLabel',
                            style: TextStyle(
                              color: performanceColor,
                              fontSize: 12,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildMetric(
                                        'Inspections',
                                        '$inspections',
                                        Icons.assignment,
                                        Colors.blue,
                                      ),
                                      _buildMetric(
                                        'Checklists',
                                        '$checklists',
                                        Icons.checklist,
                                        Colors.teal,
                                      ),
                                      _buildMetric(
                                        'Issues',
                                        '$criticalIssues',
                                        Icons.warning,
                                        Colors.orange,
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  if (checklists > 0) ...[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Average Sanitation Compliance',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${avgCompliance.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: performanceColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: avgCompliance / 100,
                                      backgroundColor: Colors.grey.shade300,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        performanceColor,
                                      ),
                                      minHeight: 8,
                                    ),
                                  ],
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
          ),
        ],
      ),
    );
  }

  Stream<List<QuerySnapshot>> _buildCombinedQuery() {
    final inspectionsStream = FirebaseFirestore.instance
        .collection('environmental_inspections')
        .where('facilityId', isEqualTo: widget.facilityId)
        .orderBy('inspectionDate', descending: true)
        .snapshots();

    final sanitationInspectionsStream = FirebaseFirestore.instance
        .collection('environmental_inspections')
        .where('facilityId', isEqualTo: widget.facilityId)
        .where('inspectionType', isEqualTo: 'Waste Management')
        .orderBy('inspectionDate', descending: true)
        .snapshots();

    return Rx.combineLatest2(
      inspectionsStream,
      sanitationInspectionsStream,
      (a, b) => [a, b],
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// 4. Issues & Actions Report View
class _IssuesActionsReportView extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final ScrollController scrollController;

  const _IssuesActionsReportView({
    required this.facilityId,
    required this.facilityName,
    required this.scrollController,
  });

  @override
  State<_IssuesActionsReportView> createState() =>
      _IssuesActionsReportViewState();
}

class _IssuesActionsReportViewState extends State<_IssuesActionsReportView> {
  String _filterLevel = 'All';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Issues & Actions Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'All', label: Text('All')),
              ButtonSegment(value: 'Critical Issues', label: Text('Critical')),
              ButtonSegment(value: 'Major Issues', label: Text('Major')),
              ButtonSegment(value: 'Minor Issues', label: Text('Minor')),
            ],
            selected: {_filterLevel},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() => _filterLevel = newSelection.first);
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<QuerySnapshot>>(
              stream: _buildCombinedQuery(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No critical issues found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                final inspectionsSnapshot = snapshot.data![0];
                final checklistsSnapshot = snapshot.data![1];

                final issues = <Map<String, dynamic>>[];

                // Process inspections with issues
                for (var doc in inspectionsSnapshot.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final findingsLevel = data['findingsLevel'] ?? 'No Issues';

                  if (findingsLevel != 'No Issues') {
                    if (_filterLevel == 'All' ||
                        _filterLevel == findingsLevel) {
                      issues.add({
                        'type': 'Inspection',
                        'level': findingsLevel,
                        'department': data['department'] ?? 'Unknown',
                        'location': data['unit'] ?? data['ward'] ?? 'N/A',
                        'inspectionType': data['inspectionType'] ?? 'Unknown',
                        'findings': data['findings'] ?? '',
                        'recommendations': data['recommendations'] ?? '',
                        'date': (data['inspectionDate'] as Timestamp).toDate(),
                      });
                    }
                  }
                }

                // Process non-compliant checklists
                for (var doc in checklistsSnapshot.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final compliance = data['compliancePercentage'] ?? 100.0;

                  if (compliance < 80) {
                    String level = compliance < 50
                        ? 'Critical Issues'
                        : (compliance < 70 ? 'Major Issues' : 'Minor Issues');
                    if (_filterLevel == 'All' || _filterLevel == level) {
                      issues.add({
                        'type': 'Sanitation',
                        'level': level,
                        'department': data['department'] ?? 'Unknown',
                        'location': data['unit'] ?? data['ward'] ?? 'N/A',
                        'compliance': compliance,
                        'compliantItems': data['compliantItems'] ?? 0,
                        'totalItems': data['totalItems'] ?? 18,
                        'notes': data['notes'] ?? '',
                        'date': (data['inspectionDate'] as Timestamp).toDate(),
                      });
                    }
                  }
                }

                // Sort by level priority (Critical > Major > Minor) and then by date
                issues.sort((a, b) {
                  final levelPriority = {
                    'Critical Issues': 0,
                    'Major Issues': 1,
                    'Minor Issues': 2,
                  };
                  final levelCompare = (levelPriority[a['level']] ?? 3)
                      .compareTo(levelPriority[b['level']] ?? 3);
                  if (levelCompare != 0) return levelCompare;
                  return (b['date'] as DateTime).compareTo(
                    a['date'] as DateTime,
                  );
                });

                if (issues.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_filterLevel.toLowerCase()} issues found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  controller: widget.scrollController,
                  children: [
                    Card(
                      color: Colors.amber.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber.shade900,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${issues.length} issue(s) requiring attention',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...issues.map((issue) {
                      final level = issue['level'] as String;
                      Color levelColor = Colors.green;
                      IconData levelIcon = Icons.check_circle;

                      if (level == 'Minor Issues') {
                        levelColor = Colors.amber;
                        levelIcon = Icons.warning;
                      } else if (level == 'Major Issues') {
                        levelColor = Colors.orange;
                        levelIcon = Icons.error;
                      } else if (level == 'Critical Issues') {
                        levelColor = Colors.red;
                        levelIcon = Icons.dangerous;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          leading: Container(width: 6, color: levelColor),
                          title: Row(
                            children: [
                              Chip(
                                label: Text(
                                  level.replaceAll(' Issues', ''),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: levelColor.withOpacity(0.2),
                                avatar: Icon(
                                  levelIcon,
                                  size: 16,
                                  color: levelColor,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  issue['type'] == 'Inspection'
                                      ? issue['inspectionType']
                                      : 'Sanitation Compliance',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '${issue['department']} - ${issue['location']}\n${DateFormat('MMM dd, yyyy').format(issue['date'])}',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (issue['type'] == 'Inspection') ...[
                                    const Text(
                                      'Findings:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      issue['findings'] ??
                                          'No details provided',
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Recommended Actions:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      issue['recommendations'] ??
                                          'No recommendations provided',
                                    ),
                                  ] else ...[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Compliance Score:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '${issue['compliance'].toStringAsFixed(1)}% (${issue['compliantItems']}/${issue['totalItems']})',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: levelColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: issue['compliance'] / 100,
                                      backgroundColor: Colors.grey.shade300,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        levelColor,
                                      ),
                                      minHeight: 8,
                                    ),
                                    if (issue['notes'] != null &&
                                        (issue['notes'] as String)
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Notes:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(issue['notes']),
                                    ],
                                  ],
                                  const Divider(height: 24),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${issue['department']} - ${issue['location']}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat(
                                          'MMM dd, yyyy HH:mm',
                                        ).format(issue['date']),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
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

  Stream<List<QuerySnapshot>> _buildCombinedQuery() {
    Query inspectionsQuery = FirebaseFirestore.instance
        .collection('environmental_inspections')
        .where('facilityId', isEqualTo: widget.facilityId);

    if (_filterLevel != 'All') {
      inspectionsQuery = inspectionsQuery.where(
        'findingsLevel',
        isEqualTo: _filterLevel,
      );
    }

    final sanitationInspectionsQuery = FirebaseFirestore.instance
        .collection('environmental_inspections')
        .where('facilityId', isEqualTo: widget.facilityId)
        .where('inspectionType', isEqualTo: 'Waste Management')
        .where('compliancePercentage', isLessThan: 80);

    return Rx.combineLatest2(
      inspectionsQuery.orderBy('inspectionDate', descending: true).snapshots(),
      sanitationInspectionsQuery.orderBy('compliancePercentage').snapshots(),
      (a, b) => [a, b],
    );
  }
}
