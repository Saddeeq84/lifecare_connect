import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import 'admin_dashboard.dart';
import 'customer_home.dart';
import 'delivery_home.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (auth.isLoadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    switch (auth.userRole) {
      case 'admin':
        return const AdminDashboard();
      case 'rider':
      case 'delivery':
        return const DeliveryHome();
      case 'customer':
        return const CustomerHome();
      default:
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.tr(
                  'This account has no CarryGo profile. Contact support.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
    }
  }
}
