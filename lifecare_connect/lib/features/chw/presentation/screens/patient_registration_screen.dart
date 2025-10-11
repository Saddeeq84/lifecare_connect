import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Shared patient registration form for both CHW and patient self-registration
class _PatientRegistrationForm extends StatefulWidget {
  final bool isCHW;
  const _PatientRegistrationForm({required this.isCHW});

  @override
  State<_PatientRegistrationForm> createState() =>
      _PatientRegistrationFormState();
}

class _PatientRegistrationFormState extends State<_PatientRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _verificationId;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handlePhoneRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date of birth')),
      );
      return;
    }
    if (_selectedGender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select gender')));
      return;
    }
    setState(() => _isLoading = true);
    // Normalize phone number only for self-registration (not CHW email registration)
    String phone = _phoneController.text.trim().replaceAll(' ', '');
    if (!widget.isCHW) {
      // Accept any 11-digit starting with 0, 13-digit starting with 234, or 14-digit starting with +234
      final regex = RegExp(r'^(0\d{10}|234\d{10}|\+234\d{10})$');
      if (regex.hasMatch(phone)) {
        if (phone.length == 11 && phone.startsWith('0')) {
          phone = '+234${phone.substring(1)}';
        } else if (phone.length == 13 && phone.startsWith('234')) {
          phone = '+234${phone.substring(3)}';
        }
        // already in correct format if 14 and starts with +234
      } else {
        setState(() => _isLoading = false);
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invalid Phone Number'),
            content: const Text('Please enter a valid Nigerian phone number'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }
    // Check for duplicate phone number only for self-registration
    if (!widget.isCHW) {
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        setState(() => _isLoading = false);
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Phone Number Exists'),
            content: const Text(
              'This phone number is already registered. Please use a different number.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      // Use Firebase Phone Auth for OTP verification
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          setState(() => _isLoading = false);
          await _completeRegistration(phone);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Phone verification failed: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => _isLoading = false);
          _verificationId = verificationId;
          _showFirebaseCodeDialog(phone);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } else {
      // For CHW email registration, skip phone verification and proceed to registration
      await _completeRegistration(phone);
    }
  }

  void _showFirebaseCodeDialog(String phone) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter Verification Code'),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '6-digit code'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              setState(() => _isLoading = true);
              try {
                final credential = PhoneAuthProvider.credential(
                  verificationId: _verificationId!,
                  smsCode: codeController.text.trim(),
                );
                await FirebaseAuth.instance.signInWithCredential(credential);
                setState(() => _isLoading = false);
                Navigator.of(context).pop();
                await _completeRegistration(phone);
              } catch (e) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error verifying code: $e')),
                );
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeRegistration(String phone) async {
    if (widget.isCHW) {
      // CHW registers patient by email, patient receives password setup link, CHW stays logged in
      final email = _emailController.text.trim();
      try {
        // Create Firebase Auth user for patient with a temporary password
        final tempPassword = UniqueKey().toString();
        final userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: email,
              password: tempPassword,
            );
        final patientUid = userCredential.user?.uid;
        // Create patient Firestore document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(patientUid)
            .set({
              'uid': patientUid,
              'name': _nameController.text.trim(),
              'email': email,
              'phone': phone,
              'role': 'patient',
              'createdAt': FieldValue.serverTimestamp(),
              'isApproved': true,
              'registeredBy': 'CHW',
              'createdBy': FirebaseAuth.instance.currentUser?.uid,
            });
        // Send password setup link to patient email
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Patient registered! Password setup link sent to their email.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating patient account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // Self-registration or phone registration logic (unchanged)
      // Always use the UID of the currently signed-in phone user
      final phoneUser = FirebaseAuth.instance.currentUser;
      if (phoneUser != null) {
        final patientData = {
          'uid': phoneUser.uid,
          'fullName': _nameController.text.trim(),
          'phone': phone,
          'role': 'patient',
          'createdBy': FirebaseAuth.instance.currentUser?.uid ?? 'self',
          'createdAt': FieldValue.serverTimestamp(),
          'isApproved': true,
          'isActive': true,
          'registrationMethod': 'phone',
          'registeredBy': 'self',
          'address': _addressController.text.trim(),
          'emergencyContact': _emergencyContactController.text.trim(),
          'gender': _selectedGender ?? '',
          'dateOfBirth': _selectedDate,
        };
        await FirebaseFirestore.instance
            .collection('users')
            .doc(phoneUser.uid)
            .set(patientData);
        // Sign out the patient user
        await FirebaseAuth.instance.signOut();
        // Show dialog to CHW to log back in
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('CHW Login Required'),
            content: const Text(
              'Patient account created successfully. Please log back in to continue as CHW.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacementNamed(context, '/chw_login');
                },
                child: const Text('Log in as CHW'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration failed: No user found.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            Text(
              widget.isCHW
                  ? 'Patient Registration by Email'
                  : 'Patient Self Registration',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? 'Enter patient name' : null,
            ),
            const SizedBox(height: 10),
            if (widget.isCHW) ...[
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val != null && val.contains('@')
                    ? null
                    : 'Enter a valid email',
              ),
              const SizedBox(height: 10),
            ] else ...[
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (val) => val != null && val.length >= 10
                    ? null
                    : 'Enter a valid phone number',
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter phone number';
                  final localPattern = RegExp(r'^(0[789][01]\d{8})$');
                  final intlPattern = RegExp(r'^\+234[789][01]\d{8}$');
                  if (localPattern.hasMatch(val) || intlPattern.hasMatch(val)) {
                    return null;
                  }
                  return 'Enter a valid Nigerian phone number (e.g. 070..., 081..., +23470...)';
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val != null && val.contains('@')
                    ? null
                    : 'Enter a valid email',
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (val) => val != null && val.length >= 6
                    ? null
                    : 'Minimum 6 characters',
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                ),
                validator: (val) => val != _passwordController.text
                    ? 'Passwords do not match'
                    : null,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 10),
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _selectedDate == null
                      ? 'Select date of birth'
                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  style: TextStyle(
                    color: _selectedDate == null ? Colors.grey : Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
              ),
              items: ['Male', 'Female', 'Other'].map((gender) {
                return DropdownMenuItem(value: gender, child: Text(gender));
              }).toList(),
              onChanged: (value) => setState(() => _selectedGender = value),
              validator: (value) =>
                  value == null ? 'Please select gender' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emergencyContactController,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return null; // Optional field, no error if blank
                }
                final localPattern = RegExp(r'^(0(70|80|81|90|91|71)\d{8})$');
                final intlPattern = RegExp(r'^\+234(70|80|81|90|91|71)\d{8}$');
                if (localPattern.hasMatch(val.trim()) ||
                    intlPattern.hasMatch(val.trim())) {
                  return null;
                }
                return 'Enter a valid Nigerian phone number';
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: const Size.fromHeight(45),
              ),
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (widget.isCHW) {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirm Patient Registration'),
                            content: const Text(
                              'Are you sure you want to register this patient? They will receive an email to set their password.',
                            ),
                            actions: [
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                              ),
                              ElevatedButton(
                                child: const Text('Confirm'),
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await _handlePhoneRegister();
                        }
                      } else {
                        await _handlePhoneRegister();
                      }
                    },
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}

class PatientRegistrationScreen extends StatelessWidget {
  final bool isCHW;
  const PatientRegistrationScreen({super.key, this.isCHW = true});

  @override
  Widget build(BuildContext context) {
    if (!isCHW) {
      // For self-registration, show only the form
      return Scaffold(
        appBar: AppBar(
          title: const Text('Create Account'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
        ),
        body: const SafeArea(child: _PatientRegistrationForm(isCHW: false)),
      );
    }
    // For CHW, show tab bar for form and phone registration
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Register New Patient'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Email Registration'),
              Tab(text: 'Phone Registration'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const SafeArea(child: _PatientRegistrationForm(isCHW: true)),
            SafeArea(child: _CHWPatientPhoneRegistration()),
          ],
        ),
      ),
    );
  }
}

// CHW Patient Phone Registration Widget
class _CHWPatientPhoneRegistration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _CHWPatientPhoneForm();
  }
}

class _CHWPatientPhoneForm extends StatefulWidget {
  @override
  State<_CHWPatientPhoneForm> createState() => _CHWPatientPhoneFormState();
}

class _CHWPatientPhoneFormState extends State<_CHWPatientPhoneForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDate;
  bool _isLoading = false;
  final _codeController = TextEditingController();
  bool _codeSent = false;
  String? _verificationId;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _verifyPhone() async {
    // Check if phone number already exists in Firestore
    String phone = _phoneController.text.trim().replaceAll(' ', '');
    // Accept and normalize any standard Nigerian phone number
    final localPattern = RegExp(r'^0[789][01]\d{8}$');
    final intlPattern = RegExp(r'^\+234[789][01]\d{8}$');
    final altIntlPattern = RegExp(r'^234[789][01]\d{8}$');
    if (localPattern.hasMatch(phone)) {
      phone = '+234${phone.substring(1)}';
    } else if (altIntlPattern.hasMatch(phone)) {
      phone = '+$phone';
    }
    // Validate final phone format
    if (!intlPattern.hasMatch(phone)) {
      setState(() => _isLoading = false);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Phone Number'),
          content: const Text(
            'Please enter a valid Nigerian phone number in the format 070..., 080..., 090..., or +23470..., +23480..., +23490...',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    // Check if phone number already exists in Firestore
    final existing = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Phone Number Exists'),
          content: const Text(
            'This phone number is already registered. Please use a different number.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      setState(() => _isLoading = false);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final info = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phone Number Verification'),
        content: const Text(
          'A verification code will be sent to the provided phone number. Please enter the code below and submit to complete patient registration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (info != true) return;
    setState(() => _isLoading = true);
    // Use Firebase phone authentication to send OTP and get verificationId
    // For both web and mobile, just call verifyPhoneNumber. On web, Firebase injects reCAPTCHA automatically if container exists in web/index.html.
    bool otpSent = false;
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          // Optionally handle auto-verification
        },
        verificationFailed: (e) async {
          setState(() => _isLoading = false);
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('OTP Error'),
              content: Text(
                'Error sending OTP: ${e.message}\nPossible reasons: invalid phone format, quota exceeded, or Firebase Auth not enabled for phone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
        codeSent: (verificationId, _) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isLoading = false;
          });
          otpSent = true;
        },
        codeAutoRetrievalTimeout: (_) {},
      );
      // If codeSent is never called, show error dialog
      if (!otpSent) {
        setState(() => _isLoading = false);
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('OTP Not Sent'),
            content: const Text(
              'No verification code was sent to this phone number. Please check the number and try again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('OTP Error'),
          content: Text('Error sending OTP: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _submitCode() async {
    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() => _isLoading = false);
      // Proceed with patient registration
      final phone = _phoneController.text.trim();
      final generatedEmail =
          '${phone.replaceAll('+', '').replaceAll(' ', '')}_${DateTime.now().millisecondsSinceEpoch}@lifecare.com';
      final generatedPassword = UniqueKey().toString();
      try {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: generatedEmail,
              password: generatedPassword,
            );
        final user = credential.user;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'uid': user.uid,
                'name': _nameController.text.trim(),
                'phone': phone,
                'address': _addressController.text.trim(),
                'emergencyContact': _emergencyContactController.text.trim(),
                'dateOfBirth': _selectedDate != null
                    ? Timestamp.fromDate(_selectedDate!)
                    : null,
                'gender': _selectedGender,
                'role': 'patient',
                'isApproved': true,
                'registeredBy': 'CHW',
                'createdBy': FirebaseAuth.instance.currentUser?.uid,
                'createdAt': FieldValue.serverTimestamp(),
              });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Patient registered successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Account creation failed: $e')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Verification error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            const Text(
              'Patient Registration by Phone',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? 'Enter patient name' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (val) => val != null && val.length >= 10
                  ? null
                  : 'Enter a valid phone number',
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _selectedDate == null
                      ? 'Select date of birth'
                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  style: TextStyle(
                    color: _selectedDate == null ? Colors.grey : Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
              ),
              items: ['Male', 'Female', 'Other'].map((gender) {
                return DropdownMenuItem(value: gender, child: Text(gender));
              }).toList(),
              onChanged: (value) => setState(() => _selectedGender = value),
              validator: (value) =>
                  value == null ? 'Please select gender' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emergencyContactController,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return null; // Optional field, no error if blank
                }
                final localPattern = RegExp(r'^(0(70|80|81|90|91|71)\d{8})$');
                final intlPattern = RegExp(r'^\+234(70|80|81|90|91|71)\d{8}$');
                if (localPattern.hasMatch(val.trim()) ||
                    intlPattern.hasMatch(val.trim())) {
                  return null;
                }
                return 'Enter a valid Nigerian phone number';
              },
            ),
            const SizedBox(height: 20),
            if (!_codeSent) ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  minimumSize: const Size.fromHeight(45),
                ),
                onPressed: _isLoading ? null : _verifyPhone,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Account'),
              ),
            ] else ...[
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Verification Code',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  minimumSize: const Size.fromHeight(45),
                ),
                onPressed: _isLoading ? null : _submitCode,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Code'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
