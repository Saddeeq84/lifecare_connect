// Environmental Surveillance Screen
// Hospital Waste Management & Environmental Health following WHO Guidelines
// Reference: WHO Safe Management of Wastes from Health-care Activities

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

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
    extends State<EnvironmentalSurveillanceScreen>
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
        title: const Text('Environmental Surveillance'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Waste Mgmt'),
            Tab(text: 'Water Quality'),
            Tab(text: 'Air Quality'),
            Tab(text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWasteManagementTab(),
          _buildWaterQualityTab(),
          _buildAirQualityTab(),
          _buildReportsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewInspectionForm(context),
        backgroundColor: Colors.green.shade700,
        icon: const Icon(Icons.add),
        label: const Text('New Inspection'),
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
      builder: (context) => _EnvironmentalInspectionForm(
        facilityId: widget.facilityId,
        facilityName: widget.facilityName,
        staffId: widget.staffId,
        staffName: widget.staffName,
      ),
    );
  }
}

// Environmental Inspection Form Widget
class _EnvironmentalInspectionForm extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const _EnvironmentalInspectionForm({
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<_EnvironmentalInspectionForm> createState() =>
      _EnvironmentalInspectionFormState();
}

class _EnvironmentalInspectionFormState
    extends State<_EnvironmentalInspectionForm> {
  final _formKey = GlobalKey<FormState>();
  String? _inspectionType;
  String? _department;
  String? _unit;
  String? _ward;
  String? _findingsLevel;
  final _findingsController = TextEditingController();
  final _recommendationsController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _wards = [];

  // Sanitation checklist
  final Map<String, bool> _checklistItems = {};
  List<String> _checklistQuestions = [];

  final List<String> _inspectionTypes = [
    'Waste Management',
    'Water Quality',
    'Air Quality',
    'General Environmental Health',
  ];

  final List<String> _departments = [
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

  final Map<String, List<String>> _departmentUnits = {
    'Laboratory': ['Hematology', 'Microbiology', 'Chemistry', 'Blood Bank'],
    'Pharmacy': ['Inpatient Pharmacy', 'Outpatient Pharmacy', 'Store'],
    'Radiology': ['X-ray', 'Ultrasound', 'CT Scan', 'MRI'],
    'Surgery/Theatre': ['Main Theatre', 'Minor Theatre', 'Recovery'],
    'Emergency': ['Triage', 'Emergency Room', 'Observation'],
    'Outpatient': ['Consultation Rooms', 'Waiting Area', 'Records'],
    'Kitchen/Catering': ['Main Kitchen', 'Store', 'Dining Area'],
  };

  final List<String> _findingsLevels = [
    'No Issues',
    'Minor Issues',
    'Major Issues',
    'Critical Issues',
  ];

  @override
  void initState() {
    super.initState();
    _loadWards();
    _initializeChecklist();
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

  Future<void> _loadWards() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('wards')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('isActive', isEqualTo: true)
          .get();

      setState(() {
        _wards = snapshot.docs.map((doc) {
          final data = doc.data();
          return {'id': doc.id, 'name': data['wardName'] ?? ''};
        }).toList();
      });
    } catch (e) {
      print('Error loading wards: $e');
    }
  }

  @override
  void dispose() {
    _findingsController.dispose();
    _recommendationsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitInspection() async {
    if (!_formKey.currentState!.validate()) return;

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

      await FirebaseFirestore.instance
          .collection('environmental_inspections')
          .add({
            'facilityId': widget.facilityId,
            'facilityName': widget.facilityName,
            'inspectorId': widget.staffId,
            'inspectorName': widget.staffName,
            'inspectionType': _inspectionType,
            'department': _department,
            'unit': _unit,
            'ward': _ward,
            'findingsLevel': _findingsLevel,
            'findings': _findingsController.text.trim(),
            'recommendations': _recommendationsController.text.trim(),
            'inspectionDate': FieldValue.serverTimestamp(),
            'status': _findingsLevel == 'No Issues'
                ? 'compliant'
                : 'action_required',
            // Sanitation checklist fields (for Waste Management)
            if (_inspectionType == 'Waste Management') ...{
              'checklistItems': _checklistItems,
              'compliantItems': compliantItems,
              'totalItems': totalItems,
              'compliancePercentage': compliancePercentage,
              'notes': _notesController.text.trim(),
            },
          });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Environmental inspection recorded successfully'),
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
                      DropdownButtonFormField<String>(
                        value: _department,
                        decoration: const InputDecoration(
                          labelText: 'Department *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                        items: _departments.map((dept) {
                          return DropdownMenuItem(
                            value: dept,
                            child: Text(dept),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _department = value;
                            _unit = null;
                            _ward = null;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Please select department' : null,
                      ),
                      const SizedBox(height: 16),
                      if (_department != null && _department == 'Nursing')
                        DropdownButtonFormField<String>(
                          value: _ward,
                          decoration: const InputDecoration(
                            labelText: 'Ward',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.meeting_room),
                          ),
                          items: _wards.map((ward) {
                            return DropdownMenuItem<String>(
                              value: ward['name'] as String,
                              child: Text(ward['name'] as String),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _ward = value),
                        ),
                      if (_department != null &&
                          _departmentUnits.containsKey(_department))
                        DropdownButtonFormField<String>(
                          value: _unit,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.apartment),
                          ),
                          items: _departmentUnits[_department]!.map((unit) {
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _unit = value),
                        ),
                      if (_department != null &&
                          (_department == 'Nursing' ||
                              _departmentUnits.containsKey(_department)))
                        const SizedBox(height: 16),
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
                      DropdownButtonFormField<String>(
                        value: _findingsLevel,
                        decoration: const InputDecoration(
                          labelText: 'Findings Level *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flag),
                        ),
                        items: _findingsLevels.map((level) {
                          return DropdownMenuItem(
                            value: level,
                            child: Text(level),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _findingsLevel = value),
                        validator: (value) => value == null
                            ? 'Please select findings level'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _findingsController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Findings/Observations *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                          hintText:
                              'Describe what was observed during inspection',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter findings';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _recommendationsController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Recommendations/Actions *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.recommend),
                          hintText: 'Recommended actions to address findings',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter recommendations';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitInspection,
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
                            _isSubmitting ? 'Saving...' : 'Submit Inspection',
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
