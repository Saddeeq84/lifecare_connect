// CHW account creation screen

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lifecare_connect/core/utils/email_admin_approval.dart';
import 'package:lifecare_connect/core/utils/admin_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:lifecare_connect/core/constants/chw_service_agreement.dart';

class CHWCreateAccountScreen extends StatefulWidget {
  const CHWCreateAccountScreen({super.key});

  @override
  State<CHWCreateAccountScreen> createState() => _CHWCreateAccountScreenState();
}

class _CHWCreateAccountScreenState extends State<CHWCreateAccountScreen> {
  // firebase_auth 6.x does not support fetchSignInMethodsForEmail; always return false so registration proceeds.
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String _loadingMessage = '';
  bool _agreedToTerms = false;

  // Credential upload variables (similar to doctor registration)
  File? _credentialFile;
  Uint8List? _credentialFileBytes;
  String? _credentialFileName;
  String? _credentialFileExtension;
  String? _credentialFileError;

  // Returns the content type for a given file extension (used for web uploads)
  String _getContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  /// Pick credential file (license, certificate, etc.)
  Future<void> _pickCredentialFile() async {
    try {
      final result = await file_picker.FilePicker.platform.pickFiles(
        type: file_picker.FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: kIsWeb, // get bytes for web uploads
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;

        // Validate file size (max 10MB)
        final maxSizeInBytes = 10 * 1024 * 1024; // 10MB
        if (file.size > maxSizeInBytes) {
          setState(() {
            _credentialFileError =
                'File size must be less than 10MB. Current size: ${(file.size / (1024 * 1024)).toStringAsFixed(1)}MB';
          });
          return;
        }

        setState(() {
          _credentialFile = File(file.path!);
          _credentialFileName = file.name;
          _credentialFileExtension = file.extension?.toLowerCase();
          _credentialFileError = null; // Clear any previous errors
          if (kIsWeb && file.bytes != null) {
            _credentialFileBytes = file.bytes;
          } else {
            _credentialFileBytes = null;
          }
        });

        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Credential file "${file.name}" uploaded successfully!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _credentialFileError = 'Failed to upload file: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload credential file: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  /// Upload credential file to Firebase Storage
  Future<String?> _uploadCredentialFile(String userId) async {
    if (_credentialFile == null) return null;

    try {
      // Sanitize filename
      String sanitizedFileName = _credentialFileName!
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^\w\-_\.]'), '');

      // FIXED: Use user_uploads path structure to match Firebase Storage rules
      final fileName =
          'user_uploads/$userId/chw_credentials/${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';
      final ref = FirebaseStorage.instance.ref().child(fileName);

      // Add timeout to prevent hanging uploads (like doctor implementation)
      final uploadFuture = kIsWeb && _credentialFileBytes != null
          ? ref.putData(
              _credentialFileBytes!,
              SettableMetadata(
                contentType: _getContentType(_credentialFileName!),
                cacheControl: 'public, max-age=31536000', // 1 year cache
              ),
            )
          : ref.putFile(
              _credentialFile!,
              SettableMetadata(cacheControl: 'public, max-age=31536000'),
            );

      final uploadTask = await uploadFuture.timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
            throw Exception('Credential upload timed out after 30 seconds'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();

      if (downloadUrl.isEmpty) {
        throw Exception('Failed to get download URL for uploaded credential');
      }

      return downloadUrl;
    } catch (e) {
      // Re-throw with more specific error message
      throw Exception('Credential upload failed: $e');
    }
  }

  /// Clear all form fields
  void _clearForm() {
    fullNameController.clear();
    emailController.clear();
    phoneController.clear();
    passwordController.clear();
    confirmPasswordController.clear();
    setState(() {
      _credentialFile = null;
      _credentialFileBytes = null;
      _credentialFileName = null;
      _credentialFileExtension = null;
      _credentialFileError = null;
    });
  }

  /// Show Service Agreement Dialog
  void _showServiceAgreement() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'CHW Service Agreement',
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    CHWServiceAgreement.fullAgreement,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _agreedToTerms = true);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                      ),
                      child: const Text('I Accept'),
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

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register as CHW'),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField('Full Name', fullNameController),
                  const SizedBox(height: 15),
                  _buildTextField(
                    'Email',
                    emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    'Phone (e.g., 0701234567 or +2347012345678)',
                    phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    'Password',
                    passwordController,
                    obscureText: true,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    'Confirm Password',
                    confirmPasswordController,
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  // Credential Upload Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _credentialFile == null
                            ? Colors.red.shade300
                            : Colors.teal.shade300,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: _credentialFile == null
                          ? Colors.red.shade50
                          : Colors.teal.shade50,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified_user,
                              color: _credentialFile == null
                                  ? Colors.red
                                  : Colors.teal,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Qualification/License Upload (Required)',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _credentialFile == null
                                      ? Colors.red.shade700
                                      : Colors.teal.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload your CHW license, school certificate, or other qualification document to support your registration. This is mandatory for account approval.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _pickCredentialFile,
                          icon: Icon(
                            _credentialFile == null
                                ? Icons.upload_file
                                : Icons.check_circle,
                          ),
                          label: Text(
                            _credentialFile == null
                                ? 'Select Credential File'
                                : 'Credential Uploaded ✓',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _credentialFile == null
                                ? Colors.red.shade600
                                : Colors.teal.shade600,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Accepted file types: JPG, JPEG, PNG, PDF',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        if (_credentialFileError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _credentialFileError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (_credentialFile != null &&
                            _credentialFileName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.teal.shade300),
                              ),
                              child: Row(
                                children: [
                                  if (_credentialFileExtension == 'jpg' ||
                                      _credentialFileExtension == 'jpeg' ||
                                      _credentialFileExtension == 'png')
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child:
                                          kIsWeb && _credentialFileBytes != null
                                          ? Image.memory(
                                              _credentialFileBytes!,
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.file(
                                              _credentialFile!,
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  if (_credentialFileExtension == 'pdf')
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.picture_as_pdf,
                                        color: Colors.red,
                                        size: 30,
                                      ),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Credential File:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.teal.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _credentialFileName!,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.teal.shade600,
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Service Agreement Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _agreedToTerms
                            ? Colors.teal.shade300
                            : Colors.orange.shade300,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: _agreedToTerms
                          ? Colors.teal.shade50
                          : Colors.orange.shade50,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _agreedToTerms ? Icons.check_circle : Icons.info,
                              color: _agreedToTerms
                                  ? Colors.teal
                                  : Colors.orange.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Service Agreement (Required)',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _agreedToTerms
                                      ? Colors.teal.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          CHWServiceAgreement.summary,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showServiceAgreement,
                          icon: const Icon(Icons.description),
                          label: const Text(
                            'Read Full Service Agreement',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: _agreedToTerms,
                          onChanged: (value) {
                            if (value == true) {
                              _showServiceAgreement();
                            } else {
                              setState(() => _agreedToTerms = false);
                            }
                          },
                          title: const Text(
                            'I have read and agree to the Service Agreement',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: Colors.teal,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Registration button
                  ElevatedButton(
                    onPressed:
                        (_isLoading ||
                            _credentialFile == null ||
                            !_agreedToTerms)
                        ? null
                        : () async {
                            final fullName = fullNameController.text.trim();
                            final email = emailController.text.trim();
                            final phoneInput = phoneController.text.trim();
                            final password = passwordController.text.trim();
                            final confirmPassword = confirmPasswordController
                                .text
                                .trim();

                            if (password != confirmPassword) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Passwords do not match'),
                                ),
                              );
                              return;
                            }

                            if (!_formKey.currentState!.validate()) {
                              return;
                            }

                            // Credential upload is now required for CHWs
                            if (_credentialFile == null) {
                              setState(() {
                                _credentialFileError =
                                    '⚠️ Qualification/license upload is mandatory for CHW registration.';
                              });

                              // Show both a snackbar and dialog for maximum visibility
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.error, color: Colors.white),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Credential upload is required to register as a CHW.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.red.shade600,
                                  duration: const Duration(seconds: 4),
                                ),
                              );

                              await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Credential Required'),
                                  content: const Text(
                                    'You must upload your CHW qualification, license, or certification document before registering. This helps verify your credentials for approval.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }

                            // Check service agreement acceptance
                            if (!_agreedToTerms) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please read and accept the Service Agreement before registering',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            setState(() {
                              _isLoading = true;
                              _loadingMessage = 'Creating account...';
                            });

                            try {
                              UserCredential userCredential = await _auth
                                  .createUserWithEmailAndPassword(
                                    email: email,
                                    password: password,
                                  );
                              final user = userCredential.user;
                              if (user == null) {
                                throw Exception('User creation failed');
                              }

                              // CRITICAL: Upload and verify credential file BEFORE proceeding
                              String? credentialUrl;
                              if (_credentialFile != null) {
                                setState(
                                  () => _loadingMessage =
                                      'Uploading credential document...',
                                );

                                try {
                                  credentialUrl = await _uploadCredentialFile(
                                    user.uid,
                                  );

                                  // VALIDATION: Ensure credential upload was successful
                                  if (credentialUrl == null ||
                                      credentialUrl.isEmpty) {
                                    throw Exception(
                                      'Credential file upload failed. Please try again.',
                                    );
                                  }
                                } catch (e) {
                                  // Clean up - delete the user account since credential upload failed
                                  try {
                                    await user.delete();
                                  } catch (deleteError) {}
                                  throw Exception(
                                    'Failed to upload credential document. Please try again with a different file.',
                                  );
                                }
                              } else {
                                // This should never happen due to button validation, but safety check
                                throw Exception(
                                  'Credential file is required for CHW registration.',
                                );
                              }

                              setState(
                                () => _loadingMessage =
                                    'Saving account information...',
                              );

                              await _firestore.collection('users').doc(user.uid).set({
                                'fullName': fullName,
                                'email': email,
                                'phone':
                                    phoneInput, // Store phone as entered, no normalization needed
                                'role': 'chw',
                                'isPhoneVerified':
                                    false, // CHWs don't need phone verification
                                'isApproved': false, // CHWs need admin approval
                                'isRejected': false,
                                'emailVerified':
                                    true, // CHWs don't need email verification
                                'createdAt': FieldValue.serverTimestamp(),
                                'credentialUrl':
                                    credentialUrl, // Guaranteed to be non-null after validation above
                              });

                              setState(
                                () => _loadingMessage =
                                    'Verifying registration...',
                              );

                              // CRITICAL VERIFICATION: Ensure document exists AND contains credential URL
                              final docSnapshot = await _firestore
                                  .collection('users')
                                  .doc(user.uid)
                                  .get();
                              if (!docSnapshot.exists) {
                                throw Exception(
                                  'Failed to verify account creation - please try again',
                                );
                              }

                              final userData = docSnapshot.data();
                              final storedCredentialUrl =
                                  userData?['credentialUrl'] as String?;

                              if (storedCredentialUrl == null ||
                                  storedCredentialUrl.isEmpty) {
                                throw Exception(
                                  'Failed to verify credential upload - please try again',
                                );
                              }

                              if (storedCredentialUrl != credentialUrl) {
                                throw Exception(
                                  'Credential verification mismatch - please try again',
                                );
                              }

                              // Send admin approval email and notification (non-blocking)
                              try {
                                await sendAdminApprovalRequiredEmail(
                                  email,
                                  fullName,
                                );
                              } catch (e) {
                                // Don't block registration if email fails
                              }

                              // Send admin notification about new CHW registration
                              try {
                                await sendAdminNewUserNotification(
                                  email: email,
                                  name: fullName,
                                  role: 'chw',
                                  userId: user.uid,
                                );
                              } catch (e) {
                                // Don't block registration if notification fails
                              }

                              // Sign out user since they need admin approval
                              await _auth.signOut();

                              // Clear the form after successful registration
                              _clearForm();

                              // Show success dialog
                              await showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => AlertDialog(
                                  icon: Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade600,
                                    size: 48,
                                  ),
                                  title: const Text('Registration Successful!'),
                                  content: const Text(
                                    'Your CHW account has been created successfully!\n\n'
                                    '✅ Account registration complete\n'
                                    '⏳ Awaiting admin approval\n'
                                    '📧 You will receive an email notification once your account is approved\n\n'
                                    'Thank you for joining LifeCare Connect!',
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        context.go(
                                          '/login',
                                        ); // Navigate back to login
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                      ),
                                      child: const Text('Continue to Login'),
                                    ),
                                  ],
                                ),
                              );
                            } catch (e) {
                              // Provide user-friendly error messages
                              String userMessage;
                              if (e.toString().contains('credential')) {
                                userMessage =
                                    'Failed to upload credential document. Please check your file and try again.';
                              } else if (e.toString().contains(
                                'email-already-in-use',
                              )) {
                                userMessage =
                                    'An account with this email already exists. Please use a different email or try logging in.';
                              } else if (e.toString().contains(
                                'weak-password',
                              )) {
                                userMessage =
                                    'Password is too weak. Please choose a stronger password.';
                              } else if (e.toString().contains(
                                'invalid-email',
                              )) {
                                userMessage =
                                    'Please enter a valid email address.';
                              } else if (e.toString().contains('network')) {
                                userMessage =
                                    'Network error. Please check your internet connection and try again.';
                              } else {
                                userMessage =
                                    'Registration failed. Please try again. If the problem persists, contact support.';
                              }

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(userMessage),
                                    backgroundColor: Colors.red.shade600,
                                    duration: const Duration(seconds: 6),
                                    action: SnackBarAction(
                                      label: 'Dismiss',
                                      textColor: Colors.white,
                                      onPressed: () => ScaffoldMessenger.of(
                                        context,
                                      ).hideCurrentSnackBar(),
                                    ),
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                  _loadingMessage = '';
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _credentialFile == null
                                ? 'Upload Credential to Register'
                                : 'Register as CHW',
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                  // Helper text when credential is missing
                  if (_credentialFile == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Please upload your credential document above',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _loadingMessage.isNotEmpty
                              ? _loadingMessage
                              : 'Processing...',
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (val) =>
          val == null || val.trim().isEmpty ? 'Please enter $label' : null,
    );
  }
}

/// Allows CHWs to create an account, verify phone, and await admin approval before dashboard access.
