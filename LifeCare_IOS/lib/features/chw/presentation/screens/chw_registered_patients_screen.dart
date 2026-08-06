import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'chw_consultation_details_screen.dart';
import 'chw_anc_form_screen.dart';
import 'chw_pnc_form_screen.dart';
import 'chw_home_visit_form_screen.dart';
import 'chw_immunization_form_screen.dart';
import 'chw_book_appointment_screen.dart';
import 'activate_patient_portal_screen.dart';
import '../../../shared/presentation/screens/ai_assistant_screen.dart';

class CHWRegisteredPatientsScreen extends StatefulWidget {
  const CHWRegisteredPatientsScreen({super.key});

  @override
  State<CHWRegisteredPatientsScreen> createState() =>
      _CHWRegisteredPatientsScreenState();
}

class _CHWRegisteredPatientsScreenState
    extends State<CHWRegisteredPatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Payment state variables for Paystack integration
  String? _lastPaymentRef;
  double? _lastPaymentAmount;
  String? _lastPaymentPatientId;
  String? _lastPaymentPatientName;

  // Connectivity monitoring
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _listenToConnectivity();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline =
            connectivity.isNotEmpty &&
            !connectivity.contains(ConnectivityResult.none);
      });
    }
  }

  void _listenToConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (mounted) {
        setState(() {
          _isOnline =
              results.isNotEmpty && !results.contains(ConnectivityResult.none);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chwId = FirebaseAuth.instance.currentUser?.uid;

    if (chwId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Patients'),
          backgroundColor: Colors.teal,
        ),
        body: const Center(child: Text('Please log in to view patients')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Registered Patients'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patients by name or phone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Patient list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chw_patients')
                  .where('registeredBy', isEqualTo: chwId)
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No patients registered yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Register your first patient',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                var patients = snapshot.data!.docs;

                // Sort patients by creation date (most recent first)
                patients.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = (aData['createdAt'] as Timestamp?)?.toDate();
                  final bTime = (bData['createdAt'] as Timestamp?)?.toDate();

                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime); // descending order
                });

                // Filter patients based on search query
                if (_searchQuery.isNotEmpty) {
                  patients = patients.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['fullName'] ?? '')
                        .toString()
                        .toLowerCase();
                    final phone = (data['phone'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(_searchQuery) ||
                        phone.contains(_searchQuery);
                  }).toList();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    final patientDoc = patients[index];
                    final patientData =
                        patientDoc.data() as Map<String, dynamic>;
                    final patientId = patientDoc.id;

                    return _buildPatientCard(context, patientId, patientData);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRegisterPatientDialog(context),
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Register Patient',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _showRegisterPatientDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    String? selectedGender;
    DateTime? dateOfBirth;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Register New Patient'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter patient name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Gender *',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Male', 'Female', 'Other']
                        .map(
                          (gender) => DropdownMenuItem(
                            value: gender,
                            child: Text(gender),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => selectedGender = value);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select gender';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().subtract(
                          const Duration(days: 365 * 20),
                        ),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => dateOfBirth = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        dateOfBirth == null
                            ? 'Select date'
                            : '${dateOfBirth!.day}/${dateOfBirth!.month}/${dateOfBirth!.year}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
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
                if (formKey.currentState!.validate() && dateOfBirth != null) {
                  await _registerPatient(
                    context,
                    nameController.text.trim(),
                    phoneController.text.trim(),
                    selectedGender!,
                    dateOfBirth!,
                    addressController.text.trim(),
                  );
                } else if (dateOfBirth == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select date of birth'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerPatient(
    BuildContext context,
    String name,
    String phone,
    String gender,
    DateTime dob,
    String address,
  ) async {
    try {
      final chwId = FirebaseAuth.instance.currentUser?.uid;
      if (chwId == null) return;

      // Show loading
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Register patient in chw_patients collection
      await FirebaseFirestore.instance.collection('chw_patients').add({
        'fullName': name,
        'phone': phone,
        'gender': gender,
        'dateOfBirth': Timestamp.fromDate(dob),
        'address': address,
        'registeredBy': chwId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      Navigator.pop(context); // Close dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient registered successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error registering patient: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPatientCard(
    BuildContext context,
    String patientId,
    Map<String, dynamic> patientData,
  ) {
    final name = patientData['fullName'] ?? 'Unknown';
    final phone = patientData['phone'] ?? 'No phone';
    final gender = patientData['gender'] ?? 'Not specified';
    final dateOfBirth = patientData['dateOfBirth'];
    final address = patientData['address'] ?? 'No address';

    String age = 'N/A';
    if (dateOfBirth != null) {
      final dob = (dateOfBirth as Timestamp).toDate();
      final years = DateTime.now().difference(dob).inDays ~/ 365;
      age = '$years years';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal,
          child: Text(
            name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(phone, style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  gender == 'Male' ? Icons.male : Icons.female,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '$gender • $age',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient details
                _buildDetailRow(Icons.location_on, 'Address', address),
                const Divider(height: 24),
                // Action buttons
                const Text(
                  'Services',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildServiceButton(
                      context,
                      'Consultation',
                      Icons.medical_services,
                      Colors.blue,
                      () =>
                          _handleConsultation(context, patientId, patientData),
                    ),
                    _buildServiceButton(
                      context,
                      'ANC',
                      Icons.pregnant_woman,
                      Colors.pink,
                      () => _handleANC(context, patientId, patientData),
                    ),
                    _buildServiceButton(
                      context,
                      'PNC',
                      Icons.child_care,
                      Colors.purple,
                      () => _handlePNC(context, patientId, patientData),
                    ),
                    _buildServiceButton(
                      context,
                      'Home Visit',
                      Icons.home,
                      Colors.orange,
                      () => _handleHomeVisit(context, patientId, patientData),
                    ),
                    _buildServiceButton(
                      context,
                      'Immunization',
                      Icons.vaccines,
                      Colors.green,
                      () =>
                          _handleImmunization(context, patientId, patientData),
                    ),
                    _buildServiceButton(
                      context,
                      'Appointment',
                      Icons.calendar_today,
                      Colors.indigo,
                      () => _handleBookAppointment(
                        context,
                        patientId,
                        patientData,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Wallet section
                _buildWalletSection(context, patientId),
                const SizedBox(height: 12),
                // Portal Access section
                _buildPortalAccessSection(context, patientId, patientData),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildWalletSection(BuildContext context, String patientId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chw_patient_wallets')
          .doc(patientId)
          .snapshots(),
      builder: (context, snapshot) {
        double balance = 0.0;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final balanceValue = data['balance'];
          balance = balanceValue is int
              ? balanceValue.toDouble()
              : (balanceValue ?? 0.0);
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallet Balance',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    '₦${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _handleFundWallet(context, patientId),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text(
                  'Fund',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortalAccessSection(
    BuildContext context,
    String patientId,
    Map<String, dynamic> patientData,
  ) {
    final hasAuthAccount = patientData['hasAuthAccount'] == true;
    final patientName = patientData['fullName'] ?? 'Patient';
    final patientPhone = patientData['phone'] ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasAuthAccount ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasAuthAccount ? Colors.green.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasAuthAccount ? Icons.verified_user : Icons.person_add,
            color: hasAuthAccount ? Colors.green : Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAuthAccount
                      ? 'Portal Access Enabled'
                      : 'Enable Portal Access',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasAuthAccount
                        ? Colors.green.shade900
                        : Colors.blue.shade900,
                  ),
                ),
                Text(
                  hasAuthAccount
                      ? 'Patient can view their records'
                      : 'Allow patient to view health records',
                  style: TextStyle(
                    fontSize: 10,
                    color: hasAuthAccount
                        ? Colors.green.shade700
                        : Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (!hasAuthAccount)
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ActivatePatientPortalScreen(
                      patientId: patientId,
                      patientName: patientName,
                      patientPhone: patientPhone,
                    ),
                  ),
                );

                // Refresh the list if portal was activated
                if (result == true && mounted) {
                  setState(() {});
                }
              },
              icon: const Icon(
                Icons.verified_user,
                size: 16,
                color: Colors.white,
              ),
              label: const Text(
                'Activate',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          if (hasAuthAccount)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ACTIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Show dialog to choose between AI help or direct form access
  Future<void> _showServiceActionDialog(
    BuildContext context, {
    required String serviceName,
    required IconData serviceIcon,
    required Color serviceColor,
    required VoidCallback onProceedWithForm,
  }) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(serviceIcon, color: serviceColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(serviceName, style: const TextStyle(fontSize: 18)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How would you like to proceed?',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              _buildDialogOption(
                context,
                icon: Icons.smart_toy,
                title: 'Get AI Assistance',
                subtitle: 'Ask AI for guidance and best practices',
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AIAssistantScreen(
                        assistantType: AIAssistantType.chw,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildDialogOption(
                context,
                icon: serviceIcon,
                title: 'Proceed with Form',
                subtitle: 'Fill out the $serviceName form directly',
                color: serviceColor,
                onTap: () {
                  Navigator.pop(context);
                  onProceedWithForm();
                },
              ),
            ],
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
  }

  Widget _buildDialogOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _handleConsultation(
    BuildContext context,
    String patientId,
    Map<String, dynamic> patientData,
  ) {
    _showServiceActionDialog(
      context,
      serviceName: 'Consultation',
      serviceIcon: Icons.medical_services,
      serviceColor: Colors.blue,
      onProceedWithForm: () {
        // Create a temporary appointment ID for direct consultation
        final tempAppointmentId =
            'direct_${DateTime.now().millisecondsSinceEpoch}';

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CHWConsultationDetailsScreen(
              patientId: patientId,
              appointmentId: tempAppointmentId,
              patientName: patientData['fullName'] ?? 'Unknown',
              appointmentData: {
                'patientId': patientId,
                'type': 'Direct Consultation',
                'status': 'in_progress',
                'date': DateTime.now().toIso8601String(),
              },
            ),
          ),
        );
      },
    );
  }

  void _handleANC(
    BuildContext context,
    String patientId,
    Map<String, dynamic> patientData,
  ) {
    _showServiceActionDialog(
      context,
      serviceName: 'ANC',
      serviceIcon: Icons.pregnant_woman,
      serviceColor: Colors.pink,
      onProceedWithForm: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CHWANCFormScreen(
              patientId: patientId,
              patientData: patientData,
            ),
          ),
        );
      },
    );
  }

  void _handlePNC(
    BuildContext context,
    String patientId,
    Map<String, dynamic> patientData,
  ) {
    _showServiceActionDialog(
      context,
      serviceName: 'PNC',
      serviceIcon: Icons.child_care,
      serviceColor: Colors.purple,
      onProceedWithForm: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CHWPNCFormScreen(
              patientId: patientId,
              patientData: patientData,
            ),
          ),
        );
      },
    );
  }

  void _handleHomeVisit(
    BuildContext context,
    String patientId,
    Map<String, dynamic> patientData,
  ) {
    _showServiceActionDialog(
      context,
      serviceName: 'Home Visit',
      serviceIcon: Icons.home,
      serviceColor: Colors.orange,
      onProceedWithForm: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CHWHomeVisitFormScreen(
              patientId: patientId,
              patientData: patientData,
            ),
          ),
        );
      },
    );
  }

  void _handleImmunization(
    BuildContext context,
    String patientId,
    Map<String, dynamic> patientData,
  ) {
    _showServiceActionDialog(
      context,
      serviceName: 'Immunization',
      serviceIcon: Icons.vaccines,
      serviceColor: Colors.green,
      onProceedWithForm: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CHWImmunizationFormScreen(
              patientId: patientId,
              patientData: patientData,
            ),
          ),
        );
      },
    );
  }

  void _handleBookAppointment(
    BuildContext context,
    String patientId,
    Map<String, dynamic> patientData,
  ) {
    _showServiceActionDialog(
      context,
      serviceName: 'Book Appointment',
      serviceIcon: Icons.calendar_today,
      serviceColor: Colors.indigo,
      onProceedWithForm: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CHWBookAppointmentScreen(
              patientId: patientId,
              patientData: patientData,
            ),
          ),
        );
      },
    );
  }

  void _handleFundWallet(BuildContext context, String patientId) async {
    // Get patient name for display
    String patientName = 'Patient';
    try {
      final patientDoc = await FirebaseFirestore.instance
          .collection('chw_patients')
          .doc(patientId)
          .get();
      if (patientDoc.exists) {
        patientName = patientDoc.data()?['fullName'] ?? 'Patient';
      }
    } catch (e) {
      print('Error fetching patient name: $e');
    }

    final amountController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Fund $patientName Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isOnline)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.grey.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Requires internet connection',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              enabled: _isOnline,
              decoration: const InputDecoration(
                labelText: 'Amount (₦)',
                border: OutlineInputBorder(),
                prefixText: '₦',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Payment will be processed via Paystack',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isOnline
                ? () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid amount')),
                      );
                      return;
                    }

                    Navigator.pop(context);
                    await _initializePaystackPayment(
                      amount,
                      patientId,
                      patientName,
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isOnline ? Colors.teal : Colors.grey,
            ),
            child: Text(
              _isOnline ? 'Continue to Payment' : 'Offline',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initializePaystackPayment(
    double amount,
    String patientId,
    String patientName,
  ) async {
    // Check connectivity first
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment requires internet connection. Please connect and try again.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    print('💳 [Paystack] Initializing payment for CHW patient wallet...');
    print('   Patient ID: $patientId');
    print('   Patient Name: $patientName');
    print('   Amount: ₦${amount.toStringAsFixed(2)}');

    // Get CHW email for payment
    final chwEmail =
        FirebaseAuth.instance.currentUser?.email ?? 'chw@lifecare.com';
    final ref =
        'CHW_WALLET_${patientId}_${DateTime.now().millisecondsSinceEpoch}';

    print('   CHW Email: $chwEmail');
    print('   Reference: $ref');

    _lastPaymentRef = ref;
    _lastPaymentAmount = amount;
    _lastPaymentPatientId = patientId;
    _lastPaymentPatientName = patientName;

    try {
      final url = Uri.parse(
        'https://us-central1-lifecare-connect.cloudfunctions.net/paystackInitialize',
      );
      print('🌐 [Paystack] Calling Cloud Function: $url');

      final requestBody = {
        'email': chwEmail,
        'amount': (amount * 100).toInt(), // Convert to kobo
        'reference': ref,
      };
      print('📤 [Paystack] Request body: $requestBody');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('📥 [Paystack] Response status: ${response.statusCode}');
      print('📥 [Paystack] Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        final authUrl = data['data']['authorization_url'];
        print('✅ [Paystack] Payment initialized successfully');
        print('🔗 [Paystack] Authorization URL: $authUrl');

        final uri = Uri.parse(authUrl);

        if (await canLaunchUrl(uri)) {
          print('🚀 [Paystack] Launching payment URL...');
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          print('✅ [Paystack] Payment URL launched');

          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Complete Payment'),
                content: Text(
                  'Payment page has opened in your browser. After completing payment, click "Verify Payment" to credit $patientName\'s wallet.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _verifyPaymentAndCreditWallet();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Verify Payment'),
                  ),
                ],
              ),
            );
          }
        } else {
          print('❌ [Paystack] Cannot launch URL: $authUrl');
          throw Exception('Could not launch payment URL');
        }
      } else {
        print('❌ [Paystack] Payment initialization failed');
        print('   Status: ${data['status']}');
        print('   Message: ${data['message']}');
        throw Exception(data['message'] ?? 'Failed to initialize payment');
      }
    } catch (e, stackTrace) {
      print('❌ [Paystack] Error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment initialization error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _verifyPaymentAndCreditWallet() async {
    if (_lastPaymentRef == null ||
        _lastPaymentAmount == null ||
        _lastPaymentPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pending payment to verify'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('🔍 [Paystack] Verifying payment...');
    print('   Reference: $_lastPaymentRef');

    try {
      final url = Uri.parse(
        'https://us-central1-lifecare-connect.cloudfunctions.net/paystackVerify',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'reference': _lastPaymentRef}),
      );

      print('📥 [Paystack Verify] Response status: ${response.statusCode}');
      print('📥 [Paystack Verify] Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          data['status'] == true &&
          data['data']['status'] == 'success') {
        print('✅ [Paystack] Payment verified successfully!');

        // Payment verified, now credit the patient wallet
        await _creditPatientWallet(
          _lastPaymentPatientId!,
          _lastPaymentAmount!,
          _lastPaymentPatientName ?? 'Patient',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment verified! ₦${_lastPaymentAmount!.toStringAsFixed(2)} credited to ${_lastPaymentPatientName ?? "patient"}\'s wallet',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Clear payment state
        _lastPaymentRef = null;
        _lastPaymentAmount = null;
        _lastPaymentPatientId = null;
        _lastPaymentPatientName = null;
      } else {
        print('❌ [Paystack] Payment verification failed');
        print('   Data status: ${data['status']}');
        print('   Payment status: ${data['data']?['status']}');

        throw Exception(
          'Payment verification failed or payment was not successful',
        );
      }
    } catch (e, stackTrace) {
      print('❌ [Paystack Verify] Error: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment verification error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _creditPatientWallet(
    String patientId,
    double amount,
    String patientName,
  ) async {
    print('💰 [Wallet] Crediting patient wallet...');
    print('   Patient ID: $patientId');
    print('   Amount: ₦${amount.toStringAsFixed(2)}');

    try {
      final now = DateTime.now();

      // Update wallet balance
      await FirebaseFirestore.instance
          .collection('chw_patient_wallets')
          .doc(patientId)
          .set({
            'balance': FieldValue.increment(amount),
            'lastUpdated': FieldValue.serverTimestamp(),
            'transactions': FieldValue.arrayUnion([
              {
                'type': 'credit',
                'amount': amount,
                'description': 'Wallet funded via Paystack',
                'timestamp': Timestamp.fromDate(now),
                'paymentReference': _lastPaymentRef,
              },
            ]),
          }, SetOptions(merge: true));

      print('✅ [Wallet] Patient wallet credited successfully');
    } catch (e, stackTrace) {
      print('❌ [Wallet] Error crediting wallet: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
