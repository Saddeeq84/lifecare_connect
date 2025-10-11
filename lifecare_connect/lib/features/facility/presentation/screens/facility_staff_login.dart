import 'package:flutter/material.dart';

class FacilityStaffLoginScreen extends StatefulWidget {
  const FacilityStaffLoginScreen({super.key});

  @override
  State<FacilityStaffLoginScreen> createState() =>
      _FacilityStaffLoginScreenState();
}

class _FacilityStaffLoginScreenState extends State<FacilityStaffLoginScreen> {
  final _staffIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Login'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextFormField(
              controller: _staffIdController,
              decoration: const InputDecoration(labelText: 'Staff ID'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : () {}, // TODO: Implement login
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
