// Facility Register Patient Screen
// For Lifecare Insurance facilities to register patients directly

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class FacilityRegisterPatientScreen extends StatefulWidget {
  const FacilityRegisterPatientScreen({super.key});

  @override
  State<FacilityRegisterPatientScreen> createState() =>
      _FacilityRegisterPatientScreenState();
}

class _FacilityRegisterPatientScreenState
    extends State<FacilityRegisterPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _registrationNumberController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _medicalHistoryController = TextEditingController();

  String? _selectedGender;
  String? _selectedBloodGroup;
  String? _selectedHouseholdId;
  String? _selectedHouseholdName;
  DateTime? _dateOfBirth;
  int? _calculatedAge;
  bool _isSubmitting = false;
  bool _isLoadingHouseholds = true;
  List<Map<String, dynamic>> _availableHouseholds = [];
  String _registrationType = 'household'; // 'household' or 'individual'

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroupOptions = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    _loadAvailableHouseholds();
  }

  Future<void> _loadAvailableHouseholds() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('households')
          .where('facilityId', isEqualTo: currentUser.uid)
          .orderBy('householdName')
          .get();

      final households = <Map<String, dynamic>>[];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final beneficiaryCount = data['beneficiaryCount'] ?? 0;

        // Only include households that have space (less than 6 beneficiaries)
        if (beneficiaryCount < 6) {
          households.add({
            'id': doc.id,
            'householdName': data['householdName'],
            'beneficiaryCount': beneficiaryCount,
            'householdLeader': data['householdLeader'],
          });
        }
      }

      if (mounted) {
        setState(() {
          _availableHouseholds = households;
          _isLoadingHouseholds = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHouseholds = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load households: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _registrationNumberController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _emergencyContactNameController.dispose();
    _medicalHistoryController.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal.shade800,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
        _calculatedAge = _calculateAge(picked);
      });
    }
  }

  Future<void> _registerPatient() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate household selection only if registration type is household
    if (_registrationType == 'household' && _selectedHouseholdId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a household for household-based registration',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select date of birth'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select gender'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if registration number already exists
      final registrationNumber = _registrationNumberController.text.trim();
      final existingPatient = await FirebaseFirestore.instance
          .collection('facility_patients')
          .where('facilityId', isEqualTo: currentUser.uid)
          .where('registrationNumber', isEqualTo: registrationNumber)
          .limit(1)
          .get();

      if (existingPatient.docs.isNotEmpty) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Registration number "$registrationNumber" is already assigned to another patient. Please use a different number.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Get facility information
      final facilityDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!facilityDoc.exists) {
        throw Exception('Facility information not found');
      }

      final facilityData = facilityDoc.data()!;
      final facilityName =
          facilityData['facilityName'] ??
          facilityData['name'] ??
          'Unknown Facility';

      // Create patient document in a facility-specific collection
      final patientData = {
        'registrationNumber': _registrationNumberController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'name': _fullNameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'gender': _selectedGender,
        'dateOfBirth': Timestamp.fromDate(_dateOfBirth!),
        'age': _calculatedAge,
        'bloodGroup': _selectedBloodGroup,
        'emergencyContactName': _emergencyContactNameController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
        'medicalHistory': _medicalHistoryController.text.trim(),
        'facilityId': currentUser.uid,
        'facilityName': facilityName,
        'householdId': _registrationType == 'household'
            ? _selectedHouseholdId
            : null,
        'householdName': _registrationType == 'household'
            ? _selectedHouseholdName
            : null,
        'registeredBy': 'facility',
        'patientType': _registrationType == 'household'
            ? 'household_member'
            : 'individual',
        'registrationType': _registrationType, // 'household' or 'individual'
        'walletBalance': _registrationType == 'individual'
            ? 0.0
            : null, // Individual patients have their own wallet
        'isAdmitted': false, // Track admission status for inpatient management
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      // Use a transaction to add patient and update household count atomically (if household-based)
      if (_registrationType == 'household') {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // Add patient document
          final patientRef = FirebaseFirestore.instance
              .collection('facility_patients')
              .doc();
          transaction.set(patientRef, patientData);

          // Increment household beneficiary count
          final householdRef = FirebaseFirestore.instance
              .collection('households')
              .doc(_selectedHouseholdId);
          transaction.update(householdRef, {
            'beneficiaryCount': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      } else {
        // For individual registration, just add the patient document
        await FirebaseFirestore.instance
            .collection('facility_patients')
            .add(patientData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Patient ${_fullNameController.text.trim()} registered successfully!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register patient: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register New Patient'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isSubmitting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal.shade800),
                  const SizedBox(height: 16),
                  const Text(
                    'Registering patient...',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Information banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        border: Border.all(color: Colors.teal.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.teal.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Register patients who are directly managed by your facility',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.teal.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Registration Type Section
                    Text(
                      'Registration Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Registration Type Selection
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('Lifecare Member'),
                            subtitle: const Text(
                              'Patient belongs to a household (uses household wallet)',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: 'household',
                            groupValue: _registrationType,
                            activeColor: Colors.teal.shade800,
                            onChanged: (value) {
                              setState(() {
                                _registrationType = value!;
                                if (_registrationType == 'individual') {
                                  _selectedHouseholdId = null;
                                  _selectedHouseholdName = null;
                                }
                              });
                            },
                          ),
                          Divider(height: 1, color: Colors.grey.shade300),
                          RadioListTile<String>(
                            title: const Text('Individual Patient'),
                            subtitle: const Text(
                              'Patient not affiliated with any household (has own wallet)',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: 'individual',
                            groupValue: _registrationType,
                            activeColor: Colors.teal.shade800,
                            onChanged: (value) {
                              setState(() {
                                _registrationType = value!;
                                if (_registrationType == 'individual') {
                                  _selectedHouseholdId = null;
                                  _selectedHouseholdName = null;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Household Selection Section (only show for household registration)
                    if (_registrationType == 'household') ...[
                      Text(
                        'Household Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Household Dropdown (only show for household registration)
                    if (_registrationType == 'household') ...[
                      if (_isLoadingHouseholds)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                              color: Colors.teal.shade800,
                            ),
                          ),
                        )
                      else if (_availableHouseholds.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            border: Border.all(color: Colors.orange.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No households available',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Please register a household first before adding patients. Each household can have up to 6 beneficiaries.',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedHouseholdId,
                          decoration: InputDecoration(
                            labelText: 'Select Household *',
                            prefixIcon: const Icon(Icons.home_work),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            helperText:
                                'Select the household this patient belongs to',
                          ),
                          items: _availableHouseholds.map((household) {
                            final householdName =
                                household['householdName'] ?? 'Unknown';
                            final beneficiaryCount =
                                household['beneficiaryCount'] ?? 0;
                            final householdLeader =
                                household['householdLeader'] ?? '';

                            return DropdownMenuItem<String>(
                              value: household['id'],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    householdName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Leader: $householdLeader | $beneficiaryCount/6 beneficiaries',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedHouseholdId = value;
                              _selectedHouseholdName = _availableHouseholds
                                  .firstWhere(
                                    (h) => h['id'] == value,
                                  )['householdName'];
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a household';
                            }
                            return null;
                          },
                        ),
                      const SizedBox(height: 24),
                    ],

                    // Personal Information Section
                    Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Registration Number
                    TextFormField(
                      controller: _registrationNumberController,
                      decoration: InputDecoration(
                        labelText: 'Reg. Number *',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'e.g., P2025001',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter registration number';
                        }
                        if (value.trim().length < 4) {
                          return 'Registration number must be at least 4 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Full Name
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter full name';
                        }
                        if (value.trim().length < 3) {
                          return 'Name must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email (Optional)',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value != null &&
                            value.isNotEmpty &&
                            !value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number *',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter phone number';
                        }
                        if (value.trim().length < 10) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Gender
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: InputDecoration(
                        labelText: 'Gender *',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: _genderOptions.map((gender) {
                        return DropdownMenuItem(
                          value: gender,
                          child: Text(gender),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date of Birth
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date of Birth *',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _dateOfBirth == null
                              ? 'Select date'
                              : DateFormat(
                                  'MMM dd, yyyy',
                                ).format(_dateOfBirth!),
                          style: TextStyle(
                            color: _dateOfBirth == null
                                ? Colors.grey
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Age (Auto-calculated)
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Age',
                        prefixIcon: const Icon(Icons.cake),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      child: Text(
                        _calculatedAge == null
                            ? 'Select date of birth to calculate age'
                            : '$_calculatedAge year${_calculatedAge! == 1 ? '' : 's'} old',
                        style: TextStyle(
                          color: _calculatedAge == null
                              ? Colors.grey
                              : Colors.black87,
                          fontWeight: _calculatedAge != null
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Blood Group
                    DropdownButtonFormField<String>(
                      value: _selectedBloodGroup,
                      decoration: InputDecoration(
                        labelText: 'Blood Group (Optional)',
                        prefixIcon: const Icon(Icons.bloodtype),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: _bloodGroupOptions.map((bloodGroup) {
                        return DropdownMenuItem(
                          value: bloodGroup,
                          child: Text(bloodGroup),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBloodGroup = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Address
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Address *',
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Emergency Contact Section
                    Text(
                      'Emergency Contact',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Emergency Contact Name
                    TextFormField(
                      controller: _emergencyContactNameController,
                      decoration: InputDecoration(
                        labelText: 'Emergency Contact Name *',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter emergency contact name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Emergency Contact Phone
                    TextFormField(
                      controller: _emergencyContactController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Emergency Contact Phone *',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter emergency contact phone';
                        }
                        if (value.trim().length < 10) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Medical Information Section
                    Text(
                      'Medical Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Medical History
                    TextFormField(
                      controller: _medicalHistoryController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Medical History (Optional)',
                        hintText:
                            'Any chronic conditions, allergies, or relevant medical information',
                        prefixIcon: const Icon(Icons.medical_information),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _registerPatient,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade800,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Register Patient',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}
