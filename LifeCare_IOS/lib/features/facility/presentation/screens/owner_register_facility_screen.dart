import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lifecare_connect/core/utils/email_admin_approval.dart';
import 'package:lifecare_connect/core/utils/admin_notifications.dart';
import 'package:lifecare_connect/core/constants/service_agreement.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

class OwnerRegisterFacilityScreen extends StatefulWidget {
  const OwnerRegisterFacilityScreen({super.key});

  @override
  State<OwnerRegisterFacilityScreen> createState() =>
      _OwnerRegisterFacilityScreenState();
}

class _OwnerRegisterFacilityScreenState
    extends State<OwnerRegisterFacilityScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedFacilityType;
  String? _selectedPlanId;
  Map<String, dynamic>? _selectedPlan;
  List<Map<String, dynamic>> _availablePlans = [];
  Uint8List? _selectedDocumentBytes;
  String? _selectedDocumentName;
  bool _isSubmitting = false;
  bool _agreedToTerms = false;
  final _formKey = GlobalKey<FormState>();
  // firebase_auth 6.x does not support fetchSignInMethodsForEmail; always return false so registration proceeds.

  @override
  void initState() {
    super.initState();
    _loadAvailablePlans();
  }

  Future<void> _loadAvailablePlans() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('subscription_plans')
          .where('isActive', isEqualTo: true)
          .orderBy('monthlyFee')
          .get();

      setState(() {
        _availablePlans = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();

        // Pre-select the first (cheapest) plan by default
        if (_availablePlans.isNotEmpty) {
          _selectedPlanId = _availablePlans[0]['id'];
          _selectedPlan = _availablePlans[0];
        }
      });
    } catch (e) {
      debugPrint('Failed to load subscription plans: $e');
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _selectedDocumentBytes = result.files.single.bytes;
        _selectedDocumentName = result.files.single.name;
      });
    }
  }

  void _showServiceAgreement() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description, color: Colors.teal, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Service Agreement',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    ServiceAgreement.fullAgreement,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _agreedToTerms = true;
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Thank you for accepting the Service Agreement',
                            ),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('I Accept the Agreement'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = false);
      return;
    }

    // Check if agreement is accepted - MANDATORY
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You must read and accept the Service Agreement before proceeding.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    // Ensure document is uploaded - MANDATORY
    if (_selectedDocumentBytes == null || _selectedDocumentName == null) {
      setState(() => _isSubmitting = false);

      // Show error dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Document Required'),
          content: const Text(
            'Registration document is mandatory for facility registration. Please select a valid document (PDF, DOC, DOCX, JPG, PNG) before proceeding.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // Show snackbar as well for visibility
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Document upload is mandatory for facility registration.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    UserCredential? userCredential;
    bool shouldCleanupAuth = false;

    try {
      // 1. Prepare data
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();
      final location = _locationController.text.trim();
      final contact = _contactController.text.trim();
      final phone = _phoneController.text.trim();
      final facilityType = _selectedFacilityType;

      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;

      // 2. Create user with Firebase Auth
      try {
        userCredential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        shouldCleanupAuth = true; // Mark for cleanup if subsequent steps fail
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Email exists, but check if Firestore document exists
          final existingDoc = await firestore
              .collection('users')
              .doc(auth.currentUser?.uid)
              .get();
          if (!existingDoc.exists) {
            throw Exception(
              'This email is already registered but the account setup is incomplete. '
              'Please contact support for assistance.',
            );
          }
        }
        rethrow;
      }

      // 3. Upload document - MANDATORY (already validated above)
      String? documentUrl;
      try {
        final fileName =
            'facility_docs/${userCredential.user!.uid}_$_selectedDocumentName';
        final ref = storage.ref().child(fileName);
        await ref.putData(_selectedDocumentBytes!);
        documentUrl = await ref.getDownloadURL();

        // Verify document upload was successful
        if (documentUrl.isEmpty) {
          throw Exception(
            'Document upload failed. Please try again with a different file.',
          );
        }
      } catch (uploadError) {
        // If upload fails, delete the created auth account
        if (shouldCleanupAuth && userCredential.user != null) {
          try {
            await userCredential.user!.delete();
          } catch (deleteError) {
            debugPrint('Failed to cleanup auth account: $deleteError');
          }
        }
        throw Exception(
          'Document upload failed: ${uploadError.toString()}. Account creation cancelled.',
        );
      }

      // 4. Save facility data to Firestore (pending approval) in 'users' collection
      try {
        await firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': name,
          'location': location,
          'role': 'facility',
          'type': facilityType,
          'contact': contact,
          'email': email,
          'phone': phone,
          'documentUrl': documentUrl, // Guaranteed to be non-null and non-empty
          'ownerUid': userCredential.user!.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'isApproved': false,
          'isRejected': false,
        });
        shouldCleanupAuth = false; // Success! No need to cleanup
      } catch (firestoreError) {
        // If Firestore fails, delete the created auth account and uploaded file
        if (shouldCleanupAuth && userCredential.user != null) {
          try {
            await userCredential.user!.delete();
          } catch (deleteError) {
            debugPrint('Failed to cleanup auth account: $deleteError');
          }
        }
        // Try to delete uploaded file
        try {
          final fileName =
              'facility_docs/${userCredential.user!.uid}_$_selectedDocumentName';
          await storage.ref().child(fileName).delete();
        } catch (deleteError) {
          debugPrint('Failed to cleanup uploaded file: $deleteError');
        }
        throw Exception(
          'Failed to save facility data: ${firestoreError.toString()}. Account creation cancelled.',
        );
      }

      // 5. Create subscription with selected plan
      try {
        final now = DateTime.now();
        final nextPayment = DateTime(now.year, now.month + 1, now.day);

        await firestore
            .collection('subscriptions')
            .doc(userCredential.user!.uid)
            .set({
              'userId': userCredential.user!.uid,
              'planId': _selectedPlanId,
              'isActive': true,
              'startDate': FieldValue.serverTimestamp(),
              'nextPaymentDate': Timestamp.fromDate(nextPayment),
              'totalPaid': 0.0,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } catch (subscriptionError) {
        debugPrint('Failed to create subscription: $subscriptionError');
        // Don't fail registration if subscription creation fails - can be fixed later
      }

      // 6. Send admin approval email and notification
      try {
        await sendAdminApprovalRequiredEmail(email, name);
      } catch (e) {
        debugPrint('Failed to send admin approval email: $e');
      }

      // Send admin notification about new facility registration
      try {
        await sendAdminNewUserNotification(
          email: email,
          name: name,
          role: 'facility',
          userId: userCredential.user!.uid,
        );
      } catch (e) {
        debugPrint('Failed to send admin notification: $e');
      }

      // 5. Show success dialog and clear form
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Success'),
          content: const Text(
            'Facility registered successfully!\n\nYour account requires admin review and approval. '
            'Your account will become active after admin approval and you will receive an email notification.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _formKey.currentState!.reset();
      _nameController.clear();
      _locationController.clear();
      _contactController.clear();
      _emailController.clear();
      _phoneController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      setState(() {
        _selectedFacilityType = null;
        _selectedPlanId = _availablePlans.isNotEmpty
            ? _availablePlans[0]['id']
            : null;
        _selectedPlan = _availablePlans.isNotEmpty ? _availablePlans[0] : null;
        _selectedDocumentBytes = null;
        _selectedDocumentName = null;
      });
    } on FirebaseAuthException catch (e) {
      String errorMessage = e.message ?? 'An error occurred.';

      // Provide more helpful messages for common errors
      if (e.code == 'email-already-in-use') {
        errorMessage =
            'This email is already registered. Please use a different email or try logging in.';
      } else if (e.code == 'weak-password') {
        errorMessage =
            'The password is too weak. Please use a stronger password.';
      } else if (e.code == 'invalid-email') {
        errorMessage =
            'The email address is not valid. Please check and try again.';
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              const Text('Registration Error'),
            ],
          ),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              const Text('Error'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.toString()),
              const SizedBox(height: 12),
              const Text(
                'Please try again or contact support if the problem persists.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  String _formatFeatureName(String feature) {
    return feature
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register Facility"),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Facility Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter facility name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location/Address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedFacilityType,
                decoration: const InputDecoration(
                  labelText: 'Facility Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Hospital', child: Text('Hospital')),
                  DropdownMenuItem(
                    value: 'Clinic/PHC',
                    child: Text('Clinic/PHC'),
                  ),
                  DropdownMenuItem(
                    value: 'Dental Clinic',
                    child: Text('Dental Clinic'),
                  ),
                  DropdownMenuItem(
                    value: 'Laboratory',
                    child: Text('Laboratory'),
                  ),
                  DropdownMenuItem(value: 'Pharmacy', child: Text('Pharmacy')),
                  DropdownMenuItem(
                    value: 'Scan Center',
                    child: Text('Scan Center'),
                  ),
                  DropdownMenuItem(
                    value: 'Eye Clinic',
                    child: Text('Eye Clinic'),
                  ),
                  DropdownMenuItem(
                    value: 'Mental Health Center',
                    child: Text('Mental Health Center'),
                  ),
                  DropdownMenuItem(
                    value: 'Physiotherapy Center',
                    child: Text('Physiotherapy Center'),
                  ),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedFacilityType = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select facility type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Subscription Plan Selection
              if (_availablePlans.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: _selectedPlanId,
                  decoration: const InputDecoration(
                    labelText: 'Subscription Plan *',
                    border: OutlineInputBorder(),
                    helperText: 'Select your subscription tier',
                  ),
                  items: _availablePlans.map((plan) {
                    final name = plan['name'] as String;
                    final monthlyFee = (plan['monthlyFee'] as num).toInt();
                    final transactionFee =
                        (plan['transactionFeePercent'] as num).toDouble();
                    return DropdownMenuItem<String>(
                      value: plan['id'] as String,
                      child: Text(
                        '$name - ₦${NumberFormat('#,##0').format(monthlyFee)}/mo + $transactionFee%',
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPlanId = value;
                      _selectedPlan = _availablePlans.firstWhere(
                        (p) => p['id'] == value,
                      );
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a subscription plan';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // Plan Details Card
                if (_selectedPlan != null)
                  Card(
                    color: Colors.teal.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.teal.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Plan Features',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_selectedPlan!['maxTransactionsPerMonth'] != null)
                            Text(
                              '• ${NumberFormat('#,##0').format(_selectedPlan!['maxTransactionsPerMonth'])} transactions per month',
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (_selectedPlan!['maxStaff'] != null)
                            Text(
                              '• Up to ${_selectedPlan!['maxStaff']} staff accounts',
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (_selectedPlan!['features'] != null) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children:
                                  (List<String>.from(
                                        _selectedPlan!['features'],
                                      ))
                                      .take(3)
                                      .map(
                                        (feature) => Chip(
                                          label: Text(
                                            _formatFeatureName(feature),
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      )
                                      .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact Person',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter contact person';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 4,
                color: _selectedDocumentBytes == null
                    ? Colors.orange.shade50
                    : Colors.green.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _selectedDocumentBytes == null
                        ? Colors.orange.shade300
                        : Colors.green.shade300,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _selectedDocumentBytes == null
                                ? Icons.upload_file
                                : Icons.check_circle,
                            color: _selectedDocumentBytes == null
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Registration Document',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'REQUIRED *',
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Upload a valid facility registration document (CAC, License, etc.)',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedDocumentBytes != null &&
                          _selectedDocumentName != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.description,
                                color: Colors.green.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedDocumentName!,
                                  style: TextStyle(
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.check_circle,
                                color: Colors.green.shade700,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _pickDocument,
                          icon: Icon(
                            _selectedDocumentBytes != null
                                ? Icons.sync
                                : Icons.upload_file,
                          ),
                          label: Text(
                            _selectedDocumentBytes != null
                                ? 'Change Document'
                                : 'Upload Document',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedDocumentBytes != null
                                ? Colors.teal.shade600
                                : Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      if (_selectedDocumentBytes == null ||
                          _selectedDocumentName == null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You must upload a document before you can proceed with registration',
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Service Agreement Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _agreedToTerms ? Colors.green : Colors.teal.shade200,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description,
                          color: Colors.teal.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Service Agreement',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade900,
                            ),
                          ),
                        ),
                        if (_agreedToTerms)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Accepted',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ServiceAgreement.shortSummary,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showServiceAgreement,
                        icon: const Icon(Icons.article_outlined),
                        label: const Text('Read Full Service Agreement'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal.shade700,
                          side: BorderSide(color: Colors.teal.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _agreedToTerms,
                      onChanged: (value) {
                        if (value == true) {
                          // Show agreement first before allowing acceptance
                          _showServiceAgreement();
                        } else {
                          setState(() {
                            _agreedToTerms = false;
                          });
                        }
                      },
                      title: const Text(
                        'I have read and agree to the Service Agreement',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Including subscription terms (2.5% monthly fee)',
                        style: TextStyle(fontSize: 12),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Colors.teal,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_selectedDocumentBytes == null ||
                  _selectedDocumentName == null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Upload a document above to enable registration',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton(
                onPressed:
                    _isSubmitting ||
                        (_selectedDocumentBytes == null ||
                            _selectedDocumentName == null) ||
                        !_agreedToTerms
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirm Registration'),
                            content: const Text(
                              'Are you sure you want to register this facility?',
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
                        if (confirmed == true) {
                          _handleSubmit();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Register Facility',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// This code defines a screen for facility owners to register their facilities.
