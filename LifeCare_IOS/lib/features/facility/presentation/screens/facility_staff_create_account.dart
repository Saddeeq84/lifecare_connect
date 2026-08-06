import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifecare_connect/core/utils/send_staff_setup_password_email.dart';
import 'dart:math';

class FacilityStaffCreateAccountScreen extends StatefulWidget {
  final String facilityName;
  const FacilityStaffCreateAccountScreen({
    super.key,
    required this.facilityName,
  });

  @override
  State<FacilityStaffCreateAccountScreen> createState() =>
      _FacilityStaffCreateAccountScreenState();
}

class _FacilityStaffCreateAccountScreenState
    extends State<FacilityStaffCreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _dob;
  final _staffIdController = TextEditingController();
  String? _selectedDepartment;
  String?
  _selectedWardUnit; // For nursing staff ward/unit assignment (stores wardId)
  String? _selectedWardName; // Stores the ward name for display
  String? _facilityType;
  String? _facilityId; // Store facility ID to load wards
  bool _isLoadingFacilityType = true;
  List<Map<String, dynamic>> _availableWards =
      []; // Wards loaded from Firestore
  bool _isLoadingWards = false;
  final List<String> _professions = [
    // Medical Doctors
    'Doctor',
    'Surgeon',
    'Pediatrician',
    'Obstetrician',
    'Gynecologist',
    'Anesthesiologist',
    'Radiologist',
    'Pathologist',
    'Psychiatrist',

    // Nursing Staff
    'Nurse',
    'Midwife',
    'Nurse Practitioner',
    'Nursing Assistant',

    // Pharmacy
    'Pharmacist',
    'Pharmacy Technician',

    // Laboratory
    'Lab Scientist',
    'Laboratory Technician',
    'Medical Lab Technologist',

    // Allied Health Professionals
    'Radiographer',
    'Physiotherapist',
    'Occupational Therapist',
    'Dietitian',
    'Nutritionist',
    'Optometrist',
    'Dental Therapist',
    'Dental Technician',

    // Dentistry
    'Dentist',
    'Dental Surgeon',

    // Community Health
    'Community Health Officer',
    'Community Health Extension Worker',
    'Public Health Officer',
    'Health Educator',

    // Medical Records & Administration
    'Medical Records Officer',
    'Health Information Manager',
    'Front Desk Officer',
    'Customer Service Officer',
    'Data Entry Clerk',

    // Support Staff
    'Medical Assistant',
    'Health Attendant',
    'Ward Attendant',
    'Theater Attendant',
    'Cleaner',
    'Security Officer',
    'Driver',

    // Other
    'Other',
  ];
  String? _selectedProfession;
  String? _customProfession;
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFacilityType();
  }

  Future<void> _loadFacilityType() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // Check if user is staff (no Firebase Auth) or owner (has Firebase Auth)
      if (user == null) {
        // User is staff - get facility info from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final facilityType = prefs.getString('facility_type');
        final facilityId = prefs.getString('facility_id');

        if (mounted) {
          setState(() {
            _facilityType = facilityType;
            _facilityId = facilityId;
            _isLoadingFacilityType = false;
          });
          // Load wards after getting facility info
          _loadWards();
        }
        return;
      }

      // User is owner - get facility info from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (mounted) {
          setState(() {
            _facilityType = data?['type'] as String?;
            _facilityId =
                user.uid; // Use the user's UID as facilityId for owners
            _isLoadingFacilityType = false;
          });
          // Load wards after getting facility info
          _loadWards();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFacilityType = false);
      }
    }
  }

  Future<void> _loadWards() async {
    if (_facilityId == null) return;

    setState(() => _isLoadingWards = true);

    try {
      final wardsSnapshot = await FirebaseFirestore.instance
          .collection('wards')
          .where('facilityId', isEqualTo: _facilityId)
          .where('isActive', isEqualTo: true)
          .orderBy('wardName')
          .get();

      if (mounted) {
        setState(() {
          _availableWards = wardsSnapshot.docs
              .map(
                (doc) => {
                  'wardId': doc.id,
                  'wardName': doc.data()['wardName'] ?? 'Unnamed Ward',
                  'wardType': doc.data()['wardType'] ?? 'general',
                },
              )
              .toList();
          _isLoadingWards = false;
        });
      }
    } catch (e) {
      print('Error loading wards: $e');
      if (mounted) {
        setState(() => _isLoadingWards = false);
      }
    }
  }

  List<String> _getDepartmentsForFacilityType() {
    if (_facilityType == null) return [];

    final facilityTypeLower = _facilityType!.toLowerCase().trim();

    // Hospital departments
    if (facilityTypeLower == 'hospital') {
      return [
        'Emergency Department',
        'Out-Patient Department (OPD)', // Renamed from General Consultation
        'Inpatient Department (IPD)',
        'Intensive Care Unit (ICU)',
        'Surgery Department',
        'Pediatrics',
        'Obstetrics & Gynecology', // Updated spelling
        'Orthopedics',
        'Cardiology',
        'Neurology',
        'Radiology',
        'Laboratory',
        'Pharmacy',
        'Public Health', // Added from facility departments screen
        'Specialist Department', // New specialist department
        'Physiotherapy',
        'Nutrition & Dietetics',
        'Medical Records',
        'Dental Department', // New department
        'Ophthalmology Department', // New department
        'ENT Department', // New department
        'Nursing', // Added nursing as a department
        'Housekeeping',
        'Security',
      ];
    }
    // Clinic departments
    else if (facilityTypeLower == 'clinic' ||
        facilityTypeLower == 'clinic/phc') {
      return [
        'Out-Patient Department (OPD)', // Renamed from General Consultation
        'Emergency Department',
        'Pharmacy',
        'Laboratory',
        'Nursing',
        'Public Health', // Added from facility departments screen
        'Specialist Department', // New specialist department
        'Medical Records',
      ];
    }
    // Dental Clinic departments
    else if (facilityTypeLower == 'dental clinic') {
      return [
        'General Dentistry',
        'Oral Surgery',
        'Orthodontics',
        'Periodontics',
        'Pediatric Dentistry',
      ];
    }
    // Eye Clinic departments
    else if (facilityTypeLower == 'eye clinic') {
      return [
        'Ophthalmology',
        'Optometry',
        'Contact Lens Service',
        'Optical Dispensary',
        'Surgical Unit',
      ];
    }
    // Physiotherapy Center departments
    else if (facilityTypeLower == 'physiotherapy center') {
      return [
        'Orthopedic Physiotherapy',
        'Neurological Physiotherapy',
        'Cardiopulmonary Physiotherapy',
        'Sports Physiotherapy',
        'Pediatric Physiotherapy',
        'Geriatric Physiotherapy',
      ];
    }
    // Mental Health Center departments
    else if (facilityTypeLower == 'mental health center') {
      return [
        'Psychiatry',
        'Clinical Psychology',
        'Counseling',
        'Occupational Therapy',
        'Social Work',
        'Substance Abuse Treatment',
        'Crisis Intervention',
      ];
    }
    // Pharmacy departments
    else if (facilityTypeLower == 'pharmacy') {
      return [
        'Dispensary',
        'Clinical Pharmacy',
        'Drug Information',
        'Inventory Management',
      ];
    }
    // Laboratory departments
    else if (facilityTypeLower == 'laboratory') {
      return [
        'Clinical Chemistry',
        'Hematology',
        'Microbiology',
        'Histopathology',
        'Immunology',
        'Molecular Biology',
        'Blood Bank',
        'Sample Collection',
      ];
    }
    // Default departments for other types
    else {
      return ['General Services', 'Clinical Services', 'Support Services'];
    }
  }

  // Check if nursing department is selected
  bool _isNursingDepartmentSelected() {
    return _selectedDepartment != null &&
        (_selectedDepartment!.toLowerCase().contains('nursing') ||
            _selectedDepartment == 'Nursing' ||
            _selectedDepartment == 'Inpatient Department (IPD)' ||
            _selectedDepartment == 'Intensive Care Unit (ICU)' ||
            _selectedDepartment == 'Emergency Department');
  }

  // Get available ward/unit options for nursing staff from Firestore
  List<Map<String, dynamic>> _getWardsAndUnitsForNursing() {
    return _availableWards;
  }

  // Generate a random 6-character password with mixed alphanumeric
  String _generatePassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    final random = Random.secure();
    return List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Staff Account'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date of Birth'),
                  child: Text(
                    _dob == null
                        ? 'Select date'
                        : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _staffIdController,
                decoration: const InputDecoration(labelText: 'Staff ID'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _isLoadingFacilityType
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: _selectedDepartment,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        border: OutlineInputBorder(),
                      ),
                      items: _getDepartmentsForFacilityType()
                          .map(
                            (dept) => DropdownMenuItem(
                              value: dept,
                              child: Text(dept),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDepartment = value;
                          _selectedWardUnit =
                              null; // Reset ward selection when department changes
                          _selectedWardName =
                              null; // Reset ward name when department changes
                        });
                      },
                      validator: (value) => value == null ? 'Required' : null,
                    ),
              const SizedBox(height: 12),

              // Ward/Unit selection for nursing staff
              if (_isNursingDepartmentSelected()) ...[
                _isLoadingWards
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _availableWards.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.info, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No wards available. Please create wards first from Ward Setup.',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        value: _selectedWardUnit,
                        decoration: const InputDecoration(
                          labelText: 'Ward/Unit Assignment',
                          border: OutlineInputBorder(),
                          helperText:
                              'Select the ward or unit this nursing staff will be assigned to',
                        ),
                        items: _getWardsAndUnitsForNursing()
                            .map(
                              (ward) => DropdownMenuItem(
                                value: ward['wardId'] as String,
                                child: Text(ward['wardName'] as String),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedWardUnit = value;
                            // Find and store the ward name for the selected wardId
                            _selectedWardName =
                                _availableWards.firstWhere(
                                      (w) => w['wardId'] == value,
                                    )['wardName']
                                    as String?;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Please select a ward/unit' : null,
                      ),
                const SizedBox(height: 12),
              ],

              DropdownButtonFormField<String>(
                value: _selectedProfession,
                decoration: const InputDecoration(labelText: 'Profession'),
                items: _professions
                    .map(
                      (profession) => DropdownMenuItem(
                        value: profession,
                        child: Text(profession),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == 'Other') {
                    final custom = await showDialog<String>(
                      context: context,
                      builder: (context) {
                        String input = '';
                        return AlertDialog(
                          title: const Text('Enter Profession'),
                          content: TextField(
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Profession name',
                            ),
                            onChanged: (v) => input = v,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(input.trim()),
                              child: const Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
                    if (custom != null && custom.isNotEmpty) {
                      setState(() {
                        _selectedProfession = 'Other';
                        _customProfession = custom;
                      });
                    } else {
                      setState(() {
                        _selectedProfession = null;
                        _customProfession = null;
                      });
                    }
                  } else {
                    setState(() {
                      _selectedProfession = value;
                      _customProfession = null;
                    });
                  }
                },
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate() ||
                            _dob == null) {
                          return;
                        }
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirm Registration'),
                            content: const Text(
                              'Are you sure you want to submit this staff registration?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Confirm'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        setState(() => _isLoading = true);

                        // Generate a secure random password
                        final generatedPassword = _generatePassword();
                        print('[StaffCreate] Generated password for new staff');

                        final staffData = {
                          'fullName': _nameController.text.trim(),
                          'dateOfBirth': _dob,
                          'staffId': _staffIdController.text.trim(),
                          'department': _selectedDepartment,
                          'profession': _selectedProfession == 'Other'
                              ? _customProfession
                              : _selectedProfession,
                          'phone': _phoneController.text.trim(),
                          'email': _emailController.text.trim(),
                          'password': generatedPassword,
                          'passwordSetAt': FieldValue.serverTimestamp(),
                          'status':
                              'pending', // Pending until email verification
                          'emailVerified': false,
                          'createdAt': DateTime.now(),
                          // Add ward/unit information for nursing staff
                          if (_selectedWardUnit != null)
                            'wardId': _selectedWardUnit,
                          if (_selectedWardName != null)
                            'wardName': _selectedWardName,
                        };
                        try {
                          final collection =
                              '${widget.facilityName.toLowerCase().replaceAll(' ', '_')}_users';
                          final email = _emailController.text.trim();
                          final staffId = _staffIdController.text.trim();

                          // Check if staff ID already exists in current facility staff
                          print(
                            '[StaffCreate] Checking if staff ID already exists in facility staff',
                          );
                          final existingStaffId = await FirebaseFirestore
                              .instance
                              .collection(collection)
                              .where('staffId', isEqualTo: staffId)
                              .limit(1)
                              .get();

                          if (existingStaffId.docs.isNotEmpty) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: const [
                                      Icon(Icons.error, color: Colors.white),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'This Staff ID is already in use. Please use a unique Staff ID.',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                            setState(() => _isLoading = false);
                            return;
                          }

                          // Check if email already exists in current facility staff
                          print(
                            '[StaffCreate] Checking if email already exists in facility staff',
                          );
                          final existingStaff = await FirebaseFirestore.instance
                              .collection(collection)
                              .where('email', isEqualTo: email)
                              .limit(1)
                              .get();

                          if (existingStaff.docs.isNotEmpty) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: const [
                                      Icon(Icons.error, color: Colors.white),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'This email is already registered for another staff member.',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                            setState(() => _isLoading = false);
                            return;
                          }

                          // IMPORTANT: Create account FIRST to get docId, THEN send email with correct verification link
                          print(
                            '[StaffCreate] Creating staff account first to get document ID...',
                          );

                          try {
                            // Create the account first to get the document ID
                            print(
                              '[StaffCreate] Saving staff data to Firestore collection: $collection',
                            );
                            final docRef = await FirebaseFirestore.instance
                                .collection(collection)
                                .add(staffData);
                            print(
                              '[StaffCreate] ✅ Staff data saved successfully with ID: ${docRef.id}',
                            );

                            // Now generate verification link with the actual docId
                            final verificationLink =
                                'https://lifecare-connect.web.app/verify-email?'
                                'collection=$collection&docId=${docRef.id}';

                            // Send email with correct verification link
                            print(
                              '[StaffCreate] Attempting to send credentials email with verification link...',
                            );
                            await sendStaffSetupPasswordEmail(
                              email: email,
                              name: _nameController.text.trim(),
                              staffId: staffId,
                              setupLink:
                                  '$generatedPassword|||$verificationLink',
                            );
                            print('[StaffCreate] ✅ Email sent successfully!');

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Staff registered! Verification email sent.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                              Navigator.pop(context);
                            }
                          } catch (emailError) {
                            print(
                              '[StaffCreate] ⚠️ Email sending failed after account creation: $emailError',
                            );

                            // Email failed but account was created - staff can manually resend from staff list
                            if (mounted) {
                              // Show detailed error dialog
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Row(
                                    children: [
                                      Icon(Icons.warning, color: Colors.orange),
                                      SizedBox(width: 8),
                                      Text('Email Send Issue'),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Staff account created successfully!',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'However, the email couldn\'t be sent:',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      SizedBox(height: 8),
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.red.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          emailError.toString().replaceAll(
                                            'Exception: ',
                                            '',
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red.shade900,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'What to do:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        '• Go to Staff List\n'
                                        '• Find the staff member\n'
                                        '• Click "Resend Email" button\n'
                                        '• Or share credentials manually',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context); // Close dialog
                                        Navigator.pop(
                                          context,
                                        ); // Go back to staff list
                                      },
                                      child: Text('Go to Staff List'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          print('[StaffCreate] ❌ Registration failed: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.error,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Registration failed: ${e.toString()}',
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        }
                        setState(() => _isLoading = false);
                      },
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Submit Registration'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
