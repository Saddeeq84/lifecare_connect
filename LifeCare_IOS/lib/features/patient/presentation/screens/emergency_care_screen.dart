import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyCareScreen extends StatefulWidget {
  const EmergencyCareScreen({super.key});

  @override
  State<EmergencyCareScreen> createState() => _EmergencyCareScreenState();
}

class _EmergencyCareScreenState extends State<EmergencyCareScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();

  String? _selectedEmergencyType;
  String? _selectedSeverity;
  String? _selectedFacilityId;
  Map<String, dynamic>? _selectedFacility;
  final bool _isSubmitting = false;
  List<QueryDocumentSnapshot> _emergencyFacilities = [];

  final List<Map<String, dynamic>> _emergencyTypes = [
    {
      'value': 'surgical_emergency',
      'label': 'Surgical Emergency',
      'description':
          'Acute conditions requiring immediate surgical intervention',
      'icon': Icons.local_hospital,
      'color': Colors.red.shade700,
    },
    {
      'value': 'obstetric_emergency',
      'label': 'Obstetric Emergency',
      'description': 'Labor complications, pregnancy emergencies',
      'icon': Icons.pregnant_woman,
      'color': Colors.pink.shade700,
    },
    {
      'value': 'cardiac_emergency',
      'label': 'Cardiac Emergency',
      'description': 'Heart attack, chest pain, cardiac arrest',
      'icon': Icons.favorite,
      'color': Colors.red.shade800,
    },
    {
      'value': 'respiratory_emergency',
      'label': 'Respiratory Emergency',
      'description': 'Severe breathing difficulties, asthma attack',
      'icon': Icons.air,
      'color': Colors.blue.shade700,
    },
    {
      'value': 'neurological_emergency',
      'label': 'Neurological Emergency',
      'description': 'Stroke, seizures, head trauma',
      'icon': Icons.psychology,
      'color': Colors.purple.shade700,
    },
    {
      'value': 'trauma_emergency',
      'label': 'Trauma Emergency',
      'description': 'Accidents, injuries, fractures',
      'icon': Icons.healing,
      'color': Colors.orange.shade700,
    },
    {
      'value': 'pediatric_emergency',
      'label': 'Pediatric Emergency',
      'description': 'Child medical emergencies',
      'icon': Icons.child_care,
      'color': Colors.green.shade700,
    },
    {
      'value': 'psychiatric_emergency',
      'label': 'Psychiatric Emergency',
      'description': 'Mental health crisis, self-harm risk',
      'icon': Icons.support,
      'color': Colors.indigo.shade700,
    },
  ];

  final List<Map<String, dynamic>> _severityLevels = [
    {
      'value': 'critical',
      'label': 'Critical - Life Threatening',
      'color': Colors.red.shade700,
      'icon': Icons.warning,
    },
    {
      'value': 'urgent',
      'label': 'Urgent - Requires Immediate Care',
      'color': Colors.orange.shade700,
      'icon': Icons.priority_high,
    },
    {
      'value': 'moderate',
      'label': 'Moderate - Needs Prompt Attention',
      'color': Colors.yellow.shade700,
      'icon': Icons.info,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadEmergencyFacilities();
  }

  Future<void> _loadEmergencyFacilities() async {
    try {
      // Query facilities that provide emergency services
      final QuerySnapshot facilitiesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'facility')
          .where('isActive', isEqualTo: true)
          .where('facilityType', whereIn: ['hospital', 'scan_center'])
          .get();

      setState(() {
        _emergencyFacilities = facilitiesSnapshot.docs;
      });
    } catch (e) {}
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _callEmergencyNumber(String number) async {
    final emergencyNumber = 'tel:$number';
    if (await canLaunchUrl(Uri.parse(emergencyNumber))) {
      await launchUrl(Uri.parse(emergencyNumber));
    }
  }

  void _showEmergencyNumbersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Numbers'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.local_hospital, color: Colors.red),
              title: const Text('Medical Emergency'),
              subtitle: const Text('199 - Emergency Medical Services'),
              trailing: IconButton(
                icon: const Icon(Icons.phone),
                onPressed: () => _callEmergencyNumber('199'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.security, color: Colors.blue),
              title: const Text('Police Emergency'),
              subtitle: const Text('199 - Nigeria Police Force'),
              trailing: IconButton(
                icon: const Icon(Icons.phone),
                onPressed: () => _callEmergencyNumber('199'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.fire_truck, color: Colors.orange),
              title: const Text('Fire Emergency'),
              subtitle: const Text('199 - Fire Service'),
              trailing: IconButton(
                icon: const Icon(Icons.phone),
                onPressed: () => _callEmergencyNumber('199'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.drive_eta, color: Colors.green),
              title: const Text('Road Safety'),
              subtitle: const Text('122 - Federal Road Safety Corps'),
              trailing: IconButton(
                icon: const Icon(Icons.phone),
                onPressed: () => _callEmergencyNumber('122'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitEmergencyRequest() async {
    // Show service not available message
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.orange),
            SizedBox(width: 8),
            Text('Service Notice'),
          ],
        ),
        content: const Text(
          'Emergency request submission is currently under development. '
          'For immediate emergencies, please call the emergency numbers directly.\n\n'
          'This feature will be available soon with direct connection to registered emergency facilities.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Call Emergency Numbers'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEmergencyNumbersDialog();
            },
            child: const Text('View Numbers'),
          ),
        ],
      ),
    );
    return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Care'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: _showEmergencyNumbersDialog,
            tooltip: 'Emergency Numbers',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emergency Alert Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade50, Colors.red.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.emergency, size: 48, color: Colors.red.shade700),
                    const SizedBox(height: 12),
                    const Text(
                      'Emergency Medical Care',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'For life-threatening emergencies, call 199 immediately',
                      style: TextStyle(fontSize: 16, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showEmergencyNumbersDialog,
                      icon: const Icon(Icons.phone),
                      label: const Text('VIEW EMERGENCY NUMBERS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Emergency Type *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Emergency Type Selection
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _emergencyTypes.length,
                  itemBuilder: (context, index) {
                    final emergencyType = _emergencyTypes[index];
                    final isSelected =
                        _selectedEmergencyType == emergencyType['value'];

                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? emergencyType['color'].withOpacity(0.1)
                            : null,
                        border: Border(
                          bottom: index < _emergencyTypes.length - 1
                              ? BorderSide(color: Colors.grey.shade200)
                              : BorderSide.none,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: emergencyType['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            emergencyType['icon'],
                            color: emergencyType['color'],
                            size: 24,
                          ),
                        ),
                        title: Text(
                          emergencyType['label'],
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? emergencyType['color'] : null,
                          ),
                        ),
                        subtitle: Text(
                          emergencyType['description'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: emergencyType['color'],
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedEmergencyType = emergencyType['value'];
                          });
                        },
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Severity Level *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Severity Level Selection
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: _severityLevels.map((severity) {
                    final isSelected = _selectedSeverity == severity['value'];

                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? severity['color'].withOpacity(0.1)
                            : null,
                        border: Border(
                          bottom: severity != _severityLevels.last
                              ? BorderSide(color: Colors.grey.shade200)
                              : BorderSide.none,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          severity['icon'],
                          color: severity['color'],
                        ),
                        title: Text(
                          severity['label'],
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? severity['color'] : null,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: severity['color'])
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedSeverity = severity['value'];
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // Emergency Facility Selection
              const Text(
                'Preferred Emergency Facility (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _emergencyFacilities.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        child: const Column(
                          children: [
                            Icon(Icons.info, color: Colors.orange),
                            SizedBox(height: 8),
                            Text(
                              'No emergency facilities currently registered',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.near_me,
                              color: _selectedFacilityId == null
                                  ? Colors.teal
                                  : Colors.grey,
                            ),
                            title: const Text(
                              'Let system find nearest facility',
                            ),
                            subtitle: const Text(
                              'Automatically locate closest emergency facility',
                            ),
                            trailing: _selectedFacilityId == null
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.teal,
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedFacilityId = null;
                                _selectedFacility = null;
                              });
                            },
                          ),
                          const Divider(height: 1),
                          ..._emergencyFacilities.map((facility) {
                            final facilityData =
                                facility.data() as Map<String, dynamic>;
                            final isSelected =
                                _selectedFacilityId == facility.id;

                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  facilityData['facilityType'] == 'hospital'
                                      ? Icons.local_hospital
                                      : Icons.medical_services,
                                  color: Colors.red.shade700,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                facilityData['facilityName'] ??
                                    'Unknown Facility',
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    facilityData['facilityType']
                                            ?.toString()
                                            .replaceAll('_', ' ')
                                            .toUpperCase() ??
                                        'FACILITY',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (facilityData['address'] != null)
                                    Text(
                                      facilityData['address'],
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle,
                                      color: Colors.red.shade700,
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedFacilityId = facility.id;
                                  _selectedFacility =
                                      facility.data() as Map<String, dynamic>;
                                });
                              },
                            );
                          }),
                          if (_selectedFacility != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 12.0,
                                left: 8.0,
                                right: 8.0,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selected Facility:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedFacility?['facilityName'] ?? '',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    if (_selectedFacility?['address'] != null)
                                      Text(
                                        _selectedFacility?['address'],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),

              const SizedBox(height: 24),

              // Service Status Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.construction, color: Colors.amber.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Service Under Development',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Emergency facility connection service is currently being developed. For immediate emergencies, please call the emergency numbers directly.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Description
              const Text(
                'Description of Emergency *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Describe the emergency situation in detail...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please describe the emergency';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Contact Phone
              const Text(
                'Contact Phone Number *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: 'Enter phone number for emergency contact',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a contact phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Location
              const Text(
                'Current Location *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  hintText: 'Enter your current location/address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide your location';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitEmergencyRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit Emergency Request',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Disclaimer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Important Emergency Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'For immediate life-threatening emergencies in Nigeria:\n'
                            '• Call 199 for Medical, Police, and Fire emergencies\n'
                            '• Call 122 for Federal Road Safety Corps\n\n'
                            'This app feature is under development and will connect you with registered emergency facilities soon.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
