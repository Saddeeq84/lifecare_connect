// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lifecare_connect/firebase_options.dart';

// Import login screens from their new locations
import '../../../chw/presentation/screens/chw_login_screen.dart';
import '../../../patient/presentation/screens/login_patient.dart';
import '../../../admin/presentation/screens/login_admin.dart';
import '../../../doctor/presentation/screens/login_doctor.dart';
import '../../../facility/presentation/screens/facility_login_screen.dart';
import '../../../patient/presentation/screens/login_patient_register.dart';
// ...existing code...
import '../../../chw/presentation/screens/chw_create_account.dart';
import '../../../doctor/presentation/screens/doctor_create_account.dart';
import '../../../facility/presentation/screens/owner_register_facility_screen.dart';
import 'about_screen.dart';
import 'contact_screen.dart';
import 'privacy_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _selectedLoginType;

  static const List<Map<String, dynamic>> _loginTypes = [
    {'value': 'patient', 'label': 'Patient', 'icon': Icons.person_outline},
    {'value': 'chw', 'label': 'Health Worker', 'icon': Icons.group_outlined},
    {
      'value': 'doctor',
      'label': 'Consultant',
      'icon': Icons.medical_services_outlined,
    },
    {'value': 'facility', 'label': 'Facility', 'icon': Icons.business_outlined},
  ];

  Future<FirebaseApp> _initializeFirebase() async {
    if (Firebase.apps.isEmpty) {
      return await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      return Firebase.apps.first;
    }
  }

  void _showRegistrationOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Create Account',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select your account type:', style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),
            SizedBox(
              width: double.maxFinite,
              child: ElevatedButton.icon(
                icon: Icon(Icons.people_outline),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PatientRegisterScreen()),
                  );
                },
                label: Text('Patient Account'),
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.maxFinite,
              child: ElevatedButton.icon(
                icon: Icon(Icons.health_and_safety),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CHWCreateAccountScreen()),
                  );
                },
                label: Text('Health Worker'),
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.maxFinite,
              child: ElevatedButton.icon(
                icon: Icon(Icons.local_hospital_outlined),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DoctorCreateAccountScreen(),
                    ),
                  );
                },
                label: Text('Consultant'),
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.maxFinite,
              child: ElevatedButton.icon(
                icon: Icon(Icons.business_outlined),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OwnerRegisterFacilityScreen(),
                    ),
                  );
                },
                label: Text('Facility'),
              ),
            ),
            SizedBox(height: 18),
            Text(
              'Note: Patient accounts are activated immediately. CHW, Doctor, and Facility accounts require admin approval before activation.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAboutScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AboutScreen()),
    );
  }

  void _showContactScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ContactScreen()),
    );
  }

  void _showPrivacyScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PrivacyScreen()),
    );
  }

  void _proceedToSelectedLogin(BuildContext context) {
    Widget? loginScreen;

    switch (_selectedLoginType) {
      case 'patient':
        loginScreen = LoginPatient();
        break;
      case 'chw':
        loginScreen = CHWLoginScreen();
        break;
      case 'doctor':
        loginScreen = LoginDoctorScreen();
        break;
      case 'facility':
        loginScreen = FacilityLoginScreen();
        break;
    }

    if (loginScreen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a login type to continue.')),
      );
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => loginScreen!));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeFirebase(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Error initializing Firebase:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30.0,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 40,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.info_outline,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    tooltip: 'About',
                                    onPressed: () => _showAboutScreen(context),
                                  ),
                                  SizedBox(width: 2),
                                  IconButton(
                                    icon: Icon(
                                      Icons.mail_outline,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    tooltip: 'Contact',
                                    onPressed: () =>
                                        _showContactScreen(context),
                                  ),
                                  SizedBox(width: 2),
                                  IconButton(
                                    icon: Icon(
                                      Icons.privacy_tip_outlined,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    tooltip: 'Privacy',
                                    onPressed: () =>
                                        _showPrivacyScreen(context),
                                  ),
                                  SizedBox(width: 2),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => LoginAdminScreen(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      margin: EdgeInsets.only(top: 2, right: 2),
                                      child: Icon(
                                        Icons.verified_user_outlined,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Image.asset(
                              'assets/images/logo.png',
                              height: 48,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'LifeCare Connect',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Connecting communities to quality healthcare',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 40),
                    Text(
                      'Select login type',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedLoginType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Login as',
                        prefixIcon: Icon(Icons.login_outlined),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.teal, width: 2),
                        ),
                      ),
                      hint: Text('Select login type'),
                      items: _loginTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type['value'] as String,
                          child: Row(
                            children: [
                              Icon(
                                type['icon'] as IconData,
                                color: Colors.teal,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Flexible(child: Text(type['label'] as String)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLoginType = value;
                        });
                      },
                    ),
                    SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.arrow_forward),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          textStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _proceedToSelectedLogin(context),
                        label: Text('Proceed to login'),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Choose your user type from the dropdown to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 40),
                    Divider(thickness: 1.2),
                    SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        _showRegistrationOptions(context);
                      },
                      child: Text(
                        "Don't have an account? Create one",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.teal,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    // ...existing code...
                    // Footer with About, Contact, Privacy buttons
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          icon: Icon(Icons.info_outline, color: Colors.teal),
                          label: Text(
                            'About',
                            style: TextStyle(color: Colors.teal),
                          ),
                          onPressed: () => _showAboutScreen(context),
                        ),
                        SizedBox(width: 8),
                        TextButton.icon(
                          icon: Icon(Icons.mail_outline, color: Colors.teal),
                          label: Text(
                            'Contact',
                            style: TextStyle(color: Colors.teal),
                          ),
                          onPressed: () => _showContactScreen(context),
                        ),
                        SizedBox(width: 8),
                        TextButton.icon(
                          icon: Icon(
                            Icons.privacy_tip_outlined,
                            color: Colors.teal,
                          ),
                          label: Text(
                            'Privacy',
                            style: TextStyle(color: Colors.teal),
                          ),
                          onPressed: () => _showPrivacyScreen(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
