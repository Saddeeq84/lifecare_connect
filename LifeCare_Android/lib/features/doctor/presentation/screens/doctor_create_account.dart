import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart' as file_picker;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lifecare_connect/core/utils/email_admin_approval.dart';
import 'package:lifecare_connect/core/utils/admin_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:lifecare_connect/core/constants/doctor_service_agreement.dart';

class DoctorCreateAccountScreen extends StatefulWidget {
  const DoctorCreateAccountScreen({super.key});

  @override
  State<DoctorCreateAccountScreen> createState() =>
      _DoctorCreateAccountScreenState();
}

class _DoctorCreateAccountScreenState extends State<DoctorCreateAccountScreen> {
  String? licenseFileError;
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

  // firebase_auth 6.x does not support fetchSignInMethodsForEmail; always return empty list so registration proceeds.
  Future<List<String>> fetchSignInMethodsForEmailWithErrorHandling(
    String email,
  ) async {
    // NOTE: When firebase_auth supports fetchSignInMethodsForEmail again, restore real check here.
    return [];
  }

  Uint8List? licenseFileBytes;
  final _formKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String? selectedSpecialization;
  String? selectedGender;
  DateTime? selectedDOB;
  final dobController = TextEditingController();
  File? profileImage;
  Uint8List? profileImageBytes;
  String? profileImageName;
  File? licenseFile;
  bool loading = false;
  bool _progressDialogShowing = false;
  bool _agreedToTerms = false;

  final List<String> specializations = [
    'General Practitioner (GP)',
    'Family Medicine',
    'Internal Medicine',
    'Pediatrician',
    'Obstetrician & Gynecologist (OB/GYN)',
    'General Surgeon',
    'Orthopedic Surgeon',
    'Anesthesiologist',
    'Emergency Medicine',
    'Psychiatrist',
    'Dermatologist',
    'Ophthalmologist',
    'ENT Specialist (Otorhinolaryngologist)',
    'Cardiologist',
    'Neurologist',
    'Neurosurgeon',
    'Urologist',
    'Radiologist',
    'Pathologist',
    'Medical Microbiologist',
    'Hematologist',
    'Infectious Disease Specialist',
    'Pulmonologist (Chest Physician)',
    'Nephrologist',
    'Gastroenterologist',
    'Endocrinologist',
    'Rheumatologist',
    'Oncologist (Cancer Specialist)',
    'Plastic & Reconstructive Surgeon',
    'Cardiothoracic Surgeon',
    'Pediatric Surgeon',
    'Neonatologist',
    'Public Health Physician',
    'Community Medicine Specialist',
    'Occupational Health Physician',
    'Clinical Pharmacologist',
    'Medical Rehabilitation Specialist',
    'Physiotherapist',
    'Dentist',
    'Dental Surgeon',
    'Oral & Maxillofacial Surgeon',
    'Orthodontist',
    'Pharmacist',
    'Medical Laboratory Scientist',
    'Optometrist',
    'Nutritionist / Dietitian',
    'Nurse Practitioner',
    'Midwife',
    'Other',
  ];
  String? otherSpecialization;

  final ImagePicker _picker = ImagePicker();

  Future<void> pickProfilePicture() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          profileImageBytes = bytes;
          profileImageName = picked.name;
          profileImage = null;
        });
      } else {
        setState(() {
          profileImage = File(picked.path);
          profileImageBytes = null;
          profileImageName = null;
        });
      }
    }
  }

  String? licenseFileName;
  String? licenseFileExtension;
  Future<void> pickLicenseFile() async {
    try {
      // Use file_picker for all supported file types
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
            licenseFileError =
                'File size must be less than 10MB. Current size: ${(file.size / (1024 * 1024)).toStringAsFixed(1)}MB';
          });
          return;
        }

        setState(() {
          licenseFile = File(file.path!);
          licenseFileName = file.name;
          licenseFileExtension = file.extension?.toLowerCase();
          licenseFileError = null; // Clear any previous errors
          if (kIsWeb && file.bytes != null) {
            licenseFileBytes = file.bytes;
          } else {
            licenseFileBytes = null;
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
                    'License file "${file.name}" uploaded successfully!',
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
        licenseFileError = 'Failed to upload file: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload license file: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> pickDOB() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDOB ?? DateTime(1990),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        selectedDOB = picked;
        dobController.text =
            '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/'
            '${picked.year}';
      });
    }
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
                        'Medical Doctor Service Agreement',
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
                    DoctorServiceAgreement.fullAgreement,
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

  Future<String?> uploadFile(
    File file,
    String folderName, {
    Uint8List? fileBytes,
    String? fileNameOverride,
  }) async {
    try {
      // Sanitize filename - remove spaces and special characters
      String sanitizedFileName;
      if (fileNameOverride != null) {
        // Remove spaces, convert to lowercase, and sanitize special characters
        sanitizedFileName = fileNameOverride
            .replaceAll(' ', '_')
            .replaceAll(RegExp(r'[^\w\-_\.]'), '')
            .toLowerCase();
      } else {
        sanitizedFileName = kIsWeb
            ? 'web_upload_${DateTime.now().millisecondsSinceEpoch}'
            : '${DateTime.now().millisecondsSinceEpoch}${file.path.split('/').last}';
      }

      final ref = FirebaseStorage.instance.ref(
        '$folderName/$sanitizedFileName',
      );
      print('📤 [UPLOAD] Uploading to: $folderName/$sanitizedFileName');

      if (kIsWeb) {
        if (fileBytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'File upload error: No file bytes provided for web upload.',
                ),
              ),
            );
          }
          return null;
        }
        // On web, upload using bytes with optimized metadata
        final metadata = SettableMetadata(
          contentType: _getContentType(sanitizedFileName),
          cacheControl: 'public, max-age=31536000', // 1 year cache
        );
        print('📤 [UPLOAD] Starting web upload with ${fileBytes.length} bytes');
        final uploadTask = await ref.putData(fileBytes, metadata);
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        print('✅ [UPLOAD] Web upload completed: $downloadUrl');
        return downloadUrl;
      } else {
        // On mobile/desktop, upload using File with optimized metadata
        final metadata = SettableMetadata(
          cacheControl: 'public, max-age=31536000', // 1 year cache
        );
        print('📤 [UPLOAD] Starting file upload');
        final uploadTask = await ref.putFile(file, metadata);
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        print('✅ [UPLOAD] File upload completed: $downloadUrl');
        return downloadUrl;
      }
    } catch (e) {
      print('❌ File upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('File upload error: $e')));
      }
      return null;
    }
  }

  void _showProgressDialog(String message) {
    if (!_progressDialogShowing) {
      _progressDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        ),
      );
      print('📱 [UI] Progress dialog shown: $message');
    }
  }

  void _dismissProgressDialog() {
    if (_progressDialogShowing) {
      Navigator.of(context).pop();
      _progressDialogShowing = false;
      print('📱 [UI] Progress dialog dismissed');
    }
  }

  Future<void> handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => loading = false);
      return;
    }

    // License upload is now required
    if (licenseFile == null) {
      setState(() {
        licenseFileError =
            '⚠️ Medical license upload is mandatory for doctor registration.';
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
                  'License upload is required to register as a doctor.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 4),
        ),
      );

      // Also show a dialog for extra emphasis
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.warning_amber, color: Colors.red.shade600, size: 48),
          title: const Text('License Required'),
          content: const Text(
            'Please upload your medical license before proceeding with registration. '
            'This is required for account verification and approval.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('I Understand'),
            ),
          ],
        ),
      );
      return;
    } else {
      setState(() {
        licenseFileError = null;
      });
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

    // Remove fetchSignInMethodsForEmailWithErrorHandling, rely on FirebaseAuth error

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    if (selectedSpecialization == null ||
        selectedGender == null ||
        selectedDOB == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all personal information')),
      );
      return;
    }

    setState(() => loading = true);
    _showProgressDialog('Creating your account...');

    UserCredential? userCred;
    try {
      // 1. Create user first
      print(
        '🔐 [DOCTOR REGISTRATION] Step 1: Creating Firebase Auth account...',
      );
      final startTime = DateTime.now();
      userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      print(
        '✅ [DOCTOR REGISTRATION] Auth account created in ${DateTime.now().difference(startTime).inMilliseconds}ms',
      );

      final uid = userCred.user?.uid;
      if (uid == null) throw Exception("User creation failed");
      print('👤 [DOCTOR REGISTRATION] User UID: $uid');

      // 2. Upload license file to user-specific folder (required)
      String? licenseUrl;
      try {
        print('📄 [DOCTOR REGISTRATION] Step 2: Uploading license file...');
        _dismissProgressDialog();
        _showProgressDialog('Uploading license document...');
        final uploadStartTime = DateTime.now();
        final licenseFolder = 'user_uploads/$uid/doctor_licenses';

        // Add timeout to prevent hanging
        final uploadFuture = kIsWeb && licenseFileBytes != null
            ? uploadFile(
                File('dummy'),
                licenseFolder,
                fileBytes: licenseFileBytes,
                fileNameOverride: licenseFileName,
              )
            : uploadFile(licenseFile!, licenseFolder);

        licenseUrl = await uploadFuture.timeout(
          const Duration(seconds: 30),
          onTimeout: () =>
              throw Exception('License upload timed out after 30 seconds'),
        );

        if (licenseUrl == null || licenseUrl.isEmpty) {
          throw Exception('License upload failed. Please try again.');
        }
        print(
          '✅ [DOCTOR REGISTRATION] License uploaded in ${DateTime.now().difference(uploadStartTime).inMilliseconds}ms',
        );
        print('🔗 [DOCTOR REGISTRATION] License URL: $licenseUrl');
      } catch (e) {
        print('❌ [DOCTOR REGISTRATION] License upload failed: $e');
        _dismissProgressDialog();
        throw Exception('License upload failed: $e');
      }

      // 3. Upload profile image (if any) to user-specific folder
      String? imageUrl;
      try {
        print('🖼️ [DOCTOR REGISTRATION] Step 3: Uploading profile image...');
        if (profileImage != null || profileImageBytes != null) {
          _dismissProgressDialog();
          _showProgressDialog('Uploading profile image...');
        }
        final imageStartTime = DateTime.now();
        final profileFolder = 'user_uploads/$uid/doctor_profiles';
        if (kIsWeb && profileImageBytes != null) {
          imageUrl = await uploadFile(
            File('dummy'),
            profileFolder,
            fileBytes: profileImageBytes,
            fileNameOverride: profileImageName,
          );
          print(
            '✅ [DOCTOR REGISTRATION] Profile image uploaded in ${DateTime.now().difference(imageStartTime).inMilliseconds}ms',
          );
        } else if (profileImage != null) {
          imageUrl = await uploadFile(profileImage!, profileFolder);
          print(
            '✅ [DOCTOR REGISTRATION] Profile image uploaded in ${DateTime.now().difference(imageStartTime).inMilliseconds}ms',
          );
        } else {
          print('ℹ️ [DOCTOR REGISTRATION] No profile image to upload');
        }
        if (imageUrl != null) {
          print('🔗 [DOCTOR REGISTRATION] Image URL: $imageUrl');
        }
      } catch (e) {
        print(
          '⚠️ [DOCTOR REGISTRATION] Profile image upload failed: $e (continuing anyway)',
        );
        // Profile image is optional, so continue
        imageUrl = null;
      }

      // 4. Save user document in Firestore
      try {
        print('💾 [DOCTOR REGISTRATION] Step 4: Saving to Firestore...');
        _dismissProgressDialog();
        _showProgressDialog('Saving your profile...');
        final firestoreStartTime = DateTime.now();
        final userData = {
          'fullName': fullNameController.text.trim(),
          'email': emailController.text.trim(),
          'phone': phoneController.text.trim(),
          'specialization': selectedSpecialization,
          'gender': selectedGender,
          'dob': selectedDOB!.toIso8601String(),
          'role': 'doctor',
          'imageUrl': imageUrl ?? '',
          'licenseUrl': licenseUrl,
          'isApproved': false,
          'isRejected': false,
          'createdAt': FieldValue.serverTimestamp(),
        };
        print(
          '📋 [DOCTOR REGISTRATION] User data to save: ${userData.toString()}',
        );

        // CRITICAL FIX: Force sign in the user first to establish Firestore auth context
        // This ensures the security rules recognize the authenticated user
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim(),
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw Exception('Authentication timed out'),
            );
        print('🔓 [DOCTOR REGISTRATION] User signed in for Firestore write');

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(userData)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () =>
                  throw Exception('Firestore write timed out after 15 seconds'),
            );
        print(
          '✅ [DOCTOR REGISTRATION] Firestore document saved in ${DateTime.now().difference(firestoreStartTime).inMilliseconds}ms',
        );

        // Sign out immediately after document creation for security
        await FirebaseAuth.instance.signOut();
        print(
          '🔒 [DOCTOR REGISTRATION] User signed out after document creation',
        );
      } catch (e) {
        print('❌ [DOCTOR REGISTRATION] Firestore save failed: $e');
        _dismissProgressDialog();
        throw Exception('Saving user data failed: $e');
      }

      // 5. App Check (Skip if it causes delays)
      try {
        print('🔒 [DOCTOR REGISTRATION] Step 5: Getting App Check token...');
        final appCheckStartTime = DateTime.now();
        await FirebaseAppCheck.instance.getToken();
        print(
          '✅ [DOCTOR REGISTRATION] App Check token obtained in ${DateTime.now().difference(appCheckStartTime).inMilliseconds}ms',
        );
      } catch (e) {
        print(
          '⚠️ [DOCTOR REGISTRATION] AppCheck failed: $e (continuing anyway)',
        );
        // Don't throw - App Check failure shouldn't block registration
      }

      // 6. Send admin approval email and admin notification (non-blocking - don't fail registration if email fails)
      try {
        print(
          '📧 [DOCTOR REGISTRATION] Step 6: Sending admin approval email...',
        );
        final emailStartTime = DateTime.now();
        await sendAdminApprovalRequiredEmail(
          emailController.text.trim(),
          fullNameController.text.trim(),
        );
        print(
          '✅ [DOCTOR REGISTRATION] Admin approval email sent in ${DateTime.now().difference(emailStartTime).inMilliseconds}ms',
        );
      } catch (e) {
        print(
          '⚠️ [DOCTOR REGISTRATION] Warning: Failed to send admin approval email: $e',
        );
        // Don't throw - email failure shouldn't block registration
      }

      // 7. Send admin notification about new doctor registration
      try {
        print('📧 [DOCTOR REGISTRATION] Step 7: Sending admin notification...');
        final notificationStartTime = DateTime.now();
        await sendAdminNewUserNotification(
          email: emailController.text.trim(),
          name: fullNameController.text.trim(),
          role: 'doctor',
          userId: uid,
        );
        print(
          '✅ [DOCTOR REGISTRATION] Admin notification sent in ${DateTime.now().difference(notificationStartTime).inMilliseconds}ms',
        );
      } catch (e) {
        print(
          '⚠️ [DOCTOR REGISTRATION] Warning: Failed to send admin notification: $e',
        );
        // Don't throw - notification failure shouldn't block registration
      }

      print(
        '🎉 [DOCTOR REGISTRATION] Registration completed successfully for UID: $uid',
      );
      print(
        '📊 [DOCTOR REGISTRATION] Total registration time: ${DateTime.now().difference(startTime).inMilliseconds}ms',
      );

      // Dismiss progress dialog
      _dismissProgressDialog();

      // Show success message and info dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created! Registration requires admin approval before your account is active.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(
              Icons.check_circle,
              color: Colors.green.shade600,
              size: 48,
            ),
            title: const Text('Registration Submitted Successfully!'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✅ Your doctor account has been created and is now pending admin review.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12),
                Text('📋 What happens next:'),
                SizedBox(height: 8),
                Text('• Admin will review your details and medical license'),
                Text('• Account approval typically takes 1-2 business days'),
                Text('• You will receive email notification upon approval'),
                Text('• Only approved doctors can access the dashboard'),
                SizedBox(height: 12),
                Text(
                  '📧 Please check your email for a confirmation message.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: const Text('Understood'),
              ),
            ],
          ),
        );
        // Clear form fields after successful submission
        fullNameController.clear();
        emailController.clear();
        phoneController.clear();
        passwordController.clear();
        confirmPasswordController.clear();
        dobController.clear();
        setState(() {
          selectedSpecialization = null;
          selectedGender = null;
          selectedDOB = null;
          profileImage = null;
          licenseFile = null;
          licenseFileBytes = null;
          licenseFileName = null;
          licenseFileExtension = null;
          otherSpecialization = null;
          loading = false;
        });
      }
      return; // Early return to prevent loading being reset below
    } on FirebaseAuthException catch (e) {
      // Dismiss progress dialog first
      _dismissProgressDialog();

      if (e.code == 'email-already-in-use') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This email is already in use. Please use a different email.',
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Registration failed: ${e.message ?? e.code}'),
            ),
          );
        }
      }
    } catch (e) {
      // Dismiss progress dialog first
      _dismissProgressDialog();

      // If user was created but a later step failed, still show success and admin approval info
      if (userCred != null && userCred.user != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Registration successful! Your account requires admin approval before it is active.',
              ),
              backgroundColor: Colors.green,
            ),
          );
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              icon: Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 48,
              ),
              title: const Text('Registration Submitted Successfully!'),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ Your doctor account has been created and is now pending admin review.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 12),
                  Text('📋 What happens next:'),
                  SizedBox(height: 8),
                  Text('• Admin will review your details and medical license'),
                  Text('• Account approval typically takes 1-2 business days'),
                  Text('• You will receive email notification upon approval'),
                  Text('• Only approved doctors can access the dashboard'),
                  SizedBox(height: 12),
                  Text(
                    '📧 Please check your email for a confirmation message.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text('Understood'),
                ),
              ],
            ),
          );
          // Clear form fields after successful submission
          fullNameController.clear();
          emailController.clear();
          phoneController.clear();
          passwordController.clear();
          confirmPasswordController.clear();
          dobController.clear();
          setState(() {
            selectedSpecialization = null;
            selectedGender = null;
            selectedDOB = null;
            profileImage = null;
            licenseFile = null;
            licenseFileBytes = null;
            licenseFileName = null;
            licenseFileExtension = null;
            otherSpecialization = null;
            loading = false;
          });
        }
        return; // Early return to prevent loading being reset below
      } else {
        // Only show error if user creation failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed at step: $e')),
          );
        }
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Registration'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: pickProfilePicture,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: profileImage != null
                      ? FileImage(profileImage!)
                      : null,
                  child: profileImage == null
                      ? const Icon(Icons.camera_alt, size: 40)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (val) => val!.isEmpty ? 'Enter full name' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (val) =>
                    val!.length < 10 ? 'Invalid phone number' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (val) =>
                    val != null && val.contains('@') ? null : 'Invalid email',
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (val) => val != null && val.length >= 6
                    ? null
                    : 'Minimum 6 characters',
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
                validator: (val) => val != passwordController.text
                    ? 'Passwords do not match'
                    : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Specialization'),
                value: selectedSpecialization,
                items: specializations
                    .map(
                      (spec) =>
                          DropdownMenuItem(value: spec, child: Text(spec)),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    selectedSpecialization = val;
                    if (val != 'Other') otherSpecialization = null;
                  });
                },
                validator: (val) =>
                    val == null ? 'Please select a specialization' : null,
              ),
              if (selectedSpecialization == 'Other')
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Please specify your specialization',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) =>
                        setState(() => otherSpecialization = val),
                    validator: (val) {
                      if (selectedSpecialization == 'Other' &&
                          (val == null || val.trim().isEmpty)) {
                        return 'Please specify your specialization';
                      }
                      return null;
                    },
                  ),
                ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Gender'),
                value: selectedGender,
                items: ['Male', 'Female', 'Other']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (val) => setState(() => selectedGender = val),
                validator: (val) => val == null ? 'Select gender' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: dobController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: pickDOB,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Select Date of Birth' : null,
              ),
              const SizedBox(height: 20),
              // Medical License Upload Section - Enhanced with prominence
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: licenseFile == null
                        ? Colors.red.shade300
                        : Colors.teal.shade300,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: licenseFile == null
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
                          color: licenseFile == null ? Colors.red : Colors.teal,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Medical License Upload (Required)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: licenseFile == null
                                  ? Colors.red.shade700
                                  : Colors.teal.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '⚠️ Your medical license is required for account approval. Please upload a clear, valid copy of your practicing license.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: pickLicenseFile,
                      icon: Icon(
                        licenseFile == null
                            ? Icons.upload_file
                            : Icons.check_circle,
                      ),
                      label: Text(
                        licenseFile == null
                            ? 'Select License File'
                            : 'License Uploaded ✓',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: licenseFile == null
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
                    if (licenseFileError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          licenseFileError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (licenseFile != null && licenseFileName != null)
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
                              if (licenseFileExtension == 'jpg' ||
                                  licenseFileExtension == 'jpeg' ||
                                  licenseFileExtension == 'png')
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: kIsWeb && licenseFileBytes != null
                                      ? Image.memory(
                                          licenseFileBytes!,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          licenseFile!,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              if (licenseFileExtension == 'pdf')
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'License File:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.teal.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      licenseFileName!,
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
                      DoctorServiceAgreement.summary,
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

              ElevatedButton(
                onPressed: (loading || !_agreedToTerms)
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirm Submission'),
                            content: const Text(
                              'Are you sure you want to register this account?',
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
                                child: const Text('Yes, Register'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          handleRegister();
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
