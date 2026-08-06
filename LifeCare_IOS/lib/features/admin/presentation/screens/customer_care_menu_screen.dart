import 'package:flutter/material.dart';
import 'manual_wallet_credit_screen.dart';
import 'admin_subscription_management_screen.dart';
import 'admin_patient_refund_management_screen.dart';
import 'account_deletion_requests_screen.dart';
import 'duplicate_accounts_screen.dart';

class CustomerSupportMenuScreen extends StatelessWidget {
  const CustomerSupportMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Support'),
        backgroundColor: Colors.purple.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            const Text(
              'Users Support & Assistance',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage patient support requests and financial issues',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            _buildMenuTile(
              context: context,
              icon: Icons.add_card,
              title: 'Manual Wallet Credit',
              subtitle: 'Credit patient wallets for failed payments',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManualWalletCreditScreen(),
                ),
              ),
            ),
            _buildMenuTile(
              context: context,
              icon: Icons.subscriptions,
              title: 'Subscription Management',
              subtitle: 'Manage patient subscriptions and renewals',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const AdminSubscriptionManagementScreen(),
                ),
              ),
            ),
            _buildMenuTile(
              context: context,
              icon: Icons.money_off,
              title: 'Patient Refund Management',
              subtitle: 'Review and process refund applications',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const AdminPatientRefundManagementScreen(),
                ),
              ),
            ),
            _buildMenuTile(
              context: context,
              icon: Icons.delete_forever,
              title: 'Account Deletion Requests',
              subtitle: 'Review and process account deletion requests',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountDeletionRequestsScreen(),
                ),
              ),
            ),
            _buildMenuTile(
              context: context,
              icon: Icons.people_alt_outlined,
              title: 'Duplicate Accounts',
              subtitle: 'Find and manage duplicate patient accounts',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DuplicateAccountsScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        leading: Icon(icon, size: 32, color: Colors.purple),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
