import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Shared patient registration form for both CHW and patient self-registration
class _PatientRegistrationForm extends StatefulWidget {
  final bool isCHW;
  const _PatientRegistrationForm({super.key, required this.isCHW});

  @override
  State<_PatientRegistrationForm> createState() => _PatientRegistrationFormState();
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

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date of birth')),
      );
      return;
    }
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select gender')),
      );
      return;
    }
    if (!widget.isCHW && _passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    setState(() => _isLoading = true);
    // Check if phone number already exists
    final phone = _phoneController.text.trim();
    final existing = await FirebaseFirestore.instance.collection('users')
      .where('phone', isEqualTo: phone)
      .limit(1)
      .get();
    if (existing.docs.isNotEmpty) {
      setState(() => _isLoading = false);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Phone Number Exists'),
          content: const Text('This phone number is already registered. Please use a different number.'),
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
    try {
      if (widget.isCHW) {
        // CHW registers patient by email and sends password setup link
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Registration'),
            content: const Text('Are you sure you want to register this patient by email?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          setState(() => _isLoading = false);
          return;
        }
        final email = _emailController.text.trim();
        final tempPassword = 'Temp${DateTime.now().millisecondsSinceEpoch}';
        UserCredential? credential;
        try {
          credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: tempPassword,
          );
        } catch (e) {
          setState(() => _isLoading = false);
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Registration Failed'),
              content: Text('Could not create user: $e'),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
            ),
          );
          return;
        }
        final user = credential.user;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'name': _nameController.text.trim(),
            'email': email,
            'address': _addressController.text.trim(),
            'emergencyContact': _emergencyContactController.text.trim(),
            'dateOfBirth': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
            'gender': _selectedGender,
            'role': 'patient',
            'isApproved': true,
            'registeredBy': 'CHW',
            'createdBy': FirebaseAuth.instance.currentUser?.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          await user.sendEmailVerification();
          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Patient registered! Password setup link sent to email.'), backgroundColor: Colors.green),
            );
            Navigator.pop(context);
          }
        }
      } else {
        // Patient self-registration (email/password)
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        final user = credential.user;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': phone,
            'address': _addressController.text.trim(),
            'emergencyContact': _emergencyContactController.text.trim(),
            'dateOfBirth': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
            'gender': _selectedGender,
            'role': 'patient',
            'isApproved': true,
            'registeredBy': 'self',
            'createdAt': FieldValue.serverTimestamp(),
            'emailVerified': false,
          });
          await user.sendEmailVerification();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account created! Please verify your email before logging in.'), backgroundColor: Colors.green),
            );
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            Text(widget.isCHW ? 'CHW Patient Registration' : 'Patient Self Registration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
              validator: (val) => val == null || val.isEmpty ? 'Enter patient name' : null,
            ),
            const SizedBox(height: 10),
            if (widget.isCHW) ...[
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                validator: (val) => val != null && val.contains('@') ? null : 'Enter a valid email',
              ),
              const SizedBox(height: 10),
            ] else ...[
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
                validator: (val) => val != null && val.length >= 10 ? null : 'Enter a valid phone number',
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter phone number';
                  final localPattern = RegExp(r'^(0[789][01]\d{8})$');
                  final intlPattern = RegExp(r'^\+234[789][01]\d{8}$');
                  if (localPattern.hasMatch(val) || intlPattern.hasMatch(val)) return null;
                  return 'Enter a valid Nigerian phone number (e.g. 070..., 081..., +23470...)';
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                validator: (val) => val != null && val.contains('@') ? null : 'Enter a valid email',
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (val) => val != null && val.length >= 6 ? null : 'Minimum 6 characters',
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                validator: (val) => val != _passwordController.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 10),
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date of Birth', border: OutlineInputBorder()),
                child: Text(
                  _selectedDate == null
                      ? 'Select date of birth'
                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  style: TextStyle(color: _selectedDate == null ? Colors.grey : Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
              items: ['Male', 'Female', 'Other'].map((gender) {
                return DropdownMenuItem(value: gender, child: Text(gender));
              }).toList(),
              onChanged: (value) => setState(() => _selectedGender = value),
              validator: (value) => value == null ? 'Please select gender' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emergencyContactController,
              decoration: const InputDecoration(labelText: 'Emergency Contact', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size.fromHeight(45)),
              onPressed: _isLoading ? null : _handleRegister,
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Register'),
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
          title: Text('Create Account'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
        ),
        body: SafeArea(
          child: _PatientRegistrationForm(isCHW: false),
        ),
      );
    }
    // For CHW, show tab bar for form and phone registration
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Register New Patient'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
          bottom: TabBar(
            tabs: [
              Tab(text: 'Form Registration'),
              Tab(text: 'Phone Registration'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SafeArea(child: _PatientRegistrationForm(isCHW: true)),
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
  String? _verificationId;
  final _codeController = TextEditingController();
  bool _codeSent = false;

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
    if (!_formKey.currentState!.validate()) return;
    final info = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phone Number Verification Required'),
        content: const Text('To register a patient by phone, you must verify their phone number first. A verification code will be sent to the number provided. Please enter the code to complete registration.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (info != true) return;
    setState(() => _isLoading = true);
    String phone = _phoneController.text.trim();
    final localPattern = RegExp(r'^(0[789][01]\d{8})$');
    final intlPattern = RegExp(r'^\+234[789][01]\d{8}$');
    if (localPattern.hasMatch(phone)) {
      phone = '+234${phone.substring(1)}';
    }
    if (!intlPattern.hasMatch(phone)) {
      setState(() => _isLoading = false);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Phone Number'),
          content: const Text('Please enter a valid Nigerian phone number in the format +23470..., 070..., or 081...'),
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
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          await _savePatientToFirestorePhone();
          if (mounted) Navigator.pop(context);
        },
        verificationFailed: (e) async {
          setState(() => _isLoading = false);
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Verification Failed'),
              content: Text('Error: ${e.message ?? e.toString()}'),
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
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      setState(() => _isLoading = false);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Verification Error'),
          content: Text('Error: ${e.toString()}'),
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
    if (_verificationId == null) return;
    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      await _savePatientToFirestorePhone();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient registered successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    }
  }

  Future<void> _savePatientToFirestorePhone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'emergencyContact': _emergencyContactController.text.trim(),
      'dateOfBirth': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
      'gender': _selectedGender,
      'role': 'patient',
      'isApproved': true,
      'registeredBy': 'CHW',
      'createdBy': FirebaseAuth.instance.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            Text('Patient Registration by Phone', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
              validator: (val) => val == null || val.isEmpty ? 'Enter patient name' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
              validator: (val) => val != null && val.length >= 10 ? null : 'Enter a valid phone number',
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date of Birth', border: OutlineInputBorder()),
                child: Text(
                  _selectedDate == null
                      ? 'Select date of birth'
                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  style: TextStyle(color: _selectedDate == null ? Colors.grey : Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
              items: ['Male', 'Female', 'Other'].map((gender) {
                return DropdownMenuItem(value: gender, child: Text(gender));
              }).toList(),
              onChanged: (value) => setState(() => _selectedGender = value),
              validator: (value) => value == null ? 'Please select gender' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emergencyContactController,
              decoration: const InputDecoration(labelText: 'Emergency Contact', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            if (!_codeSent) ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size.fromHeight(45)),
                onPressed: _isLoading ? null : _verifyPhone,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Register by Phone'),
              ),
            ] else ...[
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Verification Code', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size.fromHeight(45)),
                onPressed: _isLoading ? null : _submitCode,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Code'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}