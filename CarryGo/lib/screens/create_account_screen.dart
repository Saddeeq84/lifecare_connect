import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:provider/provider.dart';
import '../constants/nigerian_cities.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/carrygo_brand.dart';
import 'settings_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _profilePhotoController = TextEditingController();
  final _idCardController = TextEditingController();
  final _bikePlateController = TextEditingController();
  final _bikeModelController = TextEditingController();
  final _bikeColorController = TextEditingController();
  final _riderLicenseController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _bankAccountNameController = TextEditingController();
  final _documentController = TextEditingController();
  String _selectedRole = 'customer';
  String _city = 'Lagos';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _profilePhotoController.dispose();
    _idCardController.dispose();
    _bikePlateController.dispose();
    _bikeModelController.dispose();
    _bikeColorController.dispose();
    _riderLicenseController.dispose();
    _bankNameController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountNameController.dispose();
    _documentController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final createFailed =
        context.trRead('We could not create your account. Please try again.');
    setState(() => _isSubmitting = true);
    try {
      final documents = _documentController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
      await Provider.of<AuthProvider>(context, listen: false).signUp(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        city: _city,
        profilePhotoUrl: _profilePhotoController.text.trim(),
        idCardUrl: _idCardController.text.trim(),
        bikePlateNumber: _bikePlateController.text.trim(),
        bikeModel: _bikeModelController.text.trim(),
        bikeColor: _bikeColorController.text.trim(),
        riderLicenseUrl: _riderLicenseController.text.trim(),
        bankName: _bankNameController.text.trim(),
        bankAccountNumber: _bankAccountNumberController.text.trim(),
        bankAccountName: _bankAccountNameController.text.trim(),
        documentUrls: documents,
      );
      navigator.pop();
    } catch (e) {
      final message = switch (e) {
        AccountCreationException(:final message) => message,
        FirebaseAuthException(:final message?) => message,
        _ => createFailed,
      };
      messenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRider = _selectedRole == 'rider';
    final identifierIsEmail = _identifierController.text.contains('@');
    return Scaffold(
      appBar: AppBar(
        title: const CarryGoAppBarTitle(label: 'Create account'),
        actions: const [SettingsIconButton()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: CarryGoLogo(size: 120)),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      isRider
                          ? context.tr(
                              'Rider onboarding: submit your bike details and verification documents. An admin must approve you before jobs appear.',
                            )
                          : context.tr(
                              'Customer onboarding: create an account, request errands, pay with Paystack, and track your rider to drop-off.',
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _identifierController,
                  decoration: InputDecoration(
                    labelText: context.tr('Email or phone number'),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration:
                      InputDecoration(labelText: context.tr('Password')),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration:
                      InputDecoration(labelText: context.tr('Full name')),
                ),
                const SizedBox(height: 12),
                if (identifierIsEmail) ...[
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: context.tr('Contact phone number'),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(labelText: context.tr('Role')),
                  items: [
                    DropdownMenuItem(
                      value: 'customer',
                      child: Text(context.tr('Customer')),
                    ),
                    DropdownMenuItem(
                      value: 'rider',
                      child: Text(context.tr('Rider')),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedRole = value ?? 'customer');
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _city,
                  decoration: InputDecoration(labelText: context.tr('City')),
                  items: nigerianStateCapitalCities
                      .map((city) => DropdownMenuItem(
                            value: city,
                            child: Text(city),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _city = value ?? 'Lagos'),
                ),
                if (isRider) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _profilePhotoController,
                    decoration: InputDecoration(
                      labelText: context.tr('Profile photo link'),
                      helperText: context.tr('Paste an uploaded photo URL'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _idCardController,
                    decoration: InputDecoration(
                      labelText: context.tr('ID card link'),
                      helperText: context
                          .tr('Paste uploaded NIN, voter card, or ID URL'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bikePlateController,
                    decoration: InputDecoration(
                      labelText: context.tr('Bike plate number'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bikeModelController,
                    decoration: InputDecoration(
                      labelText: context.tr('Bike make/model'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bikeColorController,
                    decoration:
                        InputDecoration(labelText: context.tr('Bike color')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _riderLicenseController,
                    decoration: InputDecoration(
                      labelText:
                          context.tr('Rider license or required document link'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _documentController,
                    decoration: InputDecoration(
                      labelText:
                          context.tr('Other verification document links'),
                      helperText: context.tr(
                          'Separate insurance or extra document links with commas'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bankNameController,
                    decoration:
                        InputDecoration(labelText: context.tr('Bank name')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bankAccountNumberController,
                    decoration: InputDecoration(
                      labelText: context.tr('Bank account number'),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bankAccountNameController,
                    decoration: InputDecoration(
                      labelText: context.tr('Bank account name'),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _isSubmitting ? null : _createAccount,
                  child: Text(_isSubmitting
                      ? context.tr('Creating...')
                      : context.tr('Create account')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
