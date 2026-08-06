import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../widgets/carrygo_brand.dart';

class SettingsIconButton extends StatelessWidget {
  const SettingsIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr('Settings'),
      icon: const Icon(Icons.settings),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      },
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: CarryGoAppBarTitle(label: context.tr('Settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.language),
                    title: Text(context.tr('Language')),
                    subtitle: Text(
                        context.tr('Changes apply instantly across the app.')),
                  ),
                  DropdownButtonFormField<String>(
                    value: settings.languageCode,
                    decoration: InputDecoration(
                      labelText: context.tr('Choose app language'),
                    ),
                    items: SettingsProvider.supportedLanguages
                        .map(
                          (language) => DropdownMenuItem(
                            value: language.code,
                            child: Text(context.tr(language.name)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      context.read<SettingsProvider>().setLanguage(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.person,
            title: context.tr('Account'),
            subtitle: context.tr('Manage profile and login details'),
          ),
          _SettingsTile(
            icon: Icons.notifications_active,
            title: context.tr('Notifications'),
            subtitle: context.tr('Booking alerts, SMS and in-app messages'),
          ),
          _SettingsTile(
            icon: Icons.account_balance_wallet,
            title: context.tr('Payments and wallet'),
            subtitle: context.tr('Cards, cash, escrow and withdrawals'),
          ),
          _SettingsTile(
            icon: Icons.lock,
            title: context.tr('Privacy and security'),
            subtitle: context.tr('Password, OTP and account safety'),
          ),
          _SettingsTile(
            icon: Icons.support_agent,
            title: context.tr('Help and support'),
            subtitle: context.tr('Complaints, disputes and customer care'),
          ),
          _SettingsTile(
            icon: Icons.info,
            title: context.tr('App version'),
            subtitle: context.tr('Production MVP'),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
