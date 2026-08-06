import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../admin/presentation/screens/login_admin.dart';
import 'about_screen.dart';
import 'contact_screen.dart';

class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({super.key});

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  String? _selectedLoginRoute;

  static const _loginTypes = [
    _LoginType(
      label: 'Patient',
      route: '/login/patient',
      icon: Icons.person_outline,
    ),
    _LoginType(
      label: 'Health Worker',
      route: '/login/chw',
      icon: Icons.group_outlined,
    ),
    _LoginType(
      label: 'Consultant',
      route: '/login/doctor',
      icon: Icons.medical_services_outlined,
    ),
    _LoginType(
      label: 'Facility',
      route: '/login/facility',
      icon: Icons.business_outlined,
    ),
  ];

  void _openSelectedLogin() {
    final route = _selectedLoginRoute;
    if (route == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account type.')),
      );
      return;
    }

    context.go(route);
  }

  void _openAbout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AboutScreen()),
    );
  }

  void _openContact() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContactScreen()),
    );
  }

  void _openAdminLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginAdminScreen()),
    );
  }

  Widget _appBarAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    required bool compact,
  }) {
    final size = compact ? 20.0 : 22.0;
    final minSize = compact ? 38.0 : 44.0;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: size),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: minSize, height: minSize),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compactAppBar = MediaQuery.sizeOf(context).width < 430;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FBFA),
      appBar: AppBar(
        titleSpacing: compactAppBar ? 8 : 16,
        title: Text(
          compactAppBar ? 'LifeCare' : 'LifeCare Connect',
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _appBarAction(
            tooltip: 'About',
            onPressed: _openAbout,
            icon: Icons.info_outline,
            compact: compactAppBar,
          ),
          _appBarAction(
            tooltip: 'Contact',
            onPressed: _openContact,
            icon: Icons.mail_outline,
            compact: compactAppBar,
          ),
          _appBarAction(
            tooltip: 'Privacy',
            onPressed: () => context.go('/privacy'),
            icon: Icons.privacy_tip_outlined,
            compact: compactAppBar,
          ),
          _appBarAction(
            tooltip: 'Admin',
            onPressed: _openAdminLogin,
            icon: Icons.verified_user_outlined,
            compact: compactAppBar,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 88,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.health_and_safety,
                      size: 72,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'LifeCare Connect',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF00695C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select account type',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 28),
                  DropdownButtonFormField<String>(
                    value: _selectedLoginRoute,
                    isExpanded: true,
                    hint: const Text('Select account type'),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.login_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.teal.shade100),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Colors.teal,
                          width: 2,
                        ),
                      ),
                    ),
                    items: _loginTypes.map((loginType) {
                      return DropdownMenuItem<String>(
                        value: loginType.route,
                        child: Row(
                          children: [
                            Icon(loginType.icon, color: Colors.teal, size: 20),
                            const SizedBox(width: 12),
                            Text(loginType.label),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLoginRoute = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _openSelectedLogin,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Proceed to Login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => _showRegistrationOptions(context),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Create Account'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal[800],
                      side: BorderSide(color: Colors.teal.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _showRegistrationOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _RegistrationButton(
                  label: 'Patient Account',
                  icon: Icons.people_outline,
                  route: '/register/patient',
                ),
                _RegistrationButton(
                  label: 'Health Worker',
                  icon: Icons.health_and_safety,
                  route: '/register/chw',
                ),
                _RegistrationButton(
                  label: 'Consultant',
                  icon: Icons.local_hospital_outlined,
                  route: '/register/doctor',
                ),
                _RegistrationButton(
                  label: 'Facility',
                  icon: Icons.business_outlined,
                  route: '/register/facility',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RegistrationButton extends StatelessWidget {
  const _RegistrationButton({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          context.go(route);
        },
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

class _LoginType {
  const _LoginType({
    required this.label,
    required this.route,
    required this.icon,
  });

  final String label;
  final String route;
  final IconData icon;
}
