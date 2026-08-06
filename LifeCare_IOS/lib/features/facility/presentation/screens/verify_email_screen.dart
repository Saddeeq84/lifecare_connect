import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String collection;
  final String docId;

  const VerifyEmailScreen({
    super.key,
    required this.collection,
    required this.docId,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isVerifying = true;
  bool _verificationSuccess = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    print('🔍 [VerifyEmailScreen] Screen initialized!');
    print('🔍 [VerifyEmailScreen] Collection: ${widget.collection}');
    print('🔍 [VerifyEmailScreen] DocId: ${widget.docId}');
    _verifyEmail();
  }

  Future<void> _verifyEmail() async {
    try {
      print(
        '[EmailVerify] Verifying email for collection: ${widget.collection}, docId: ${widget.docId}',
      );

      // Update the staff document
      await FirebaseFirestore.instance
          .collection(widget.collection)
          .doc(widget.docId)
          .update({
            'emailVerified': true,
            'status': 'active',
            'emailVerifiedAt': FieldValue.serverTimestamp(),
          });

      print('[EmailVerify] ✅ Email verified successfully');

      setState(() {
        _isVerifying = false;
        _verificationSuccess = true;
      });
    } catch (e) {
      print('[EmailVerify] ❌ Verification failed: $e');
      setState(() {
        _isVerifying = false;
        _verificationSuccess = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Verification'),
        backgroundColor: Colors.teal.shade800,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isVerifying) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    const Text(
                      'Verifying your email...',
                      style: TextStyle(fontSize: 18),
                    ),
                  ] else if (_verificationSuccess) ...[
                    Icon(Icons.check_circle, color: Colors.green, size: 80),
                    const SizedBox(height: 24),
                    const Text(
                      'Email Verified Successfully!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your account is now active. You can login using your Staff ID and password.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.go('/login');
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Go to Login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ] else ...[
                    Icon(Icons.error, color: Colors.red, size: 80),
                    const SizedBox(height: 24),
                    const Text(
                      'Verification Failed',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to verify your email. Please contact your facility administrator.',
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.go('/login');
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to Login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
