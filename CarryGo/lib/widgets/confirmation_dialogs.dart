import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';

Future<void> confirmAndSignOut(BuildContext context) async {
  final shouldSignOut = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('Log out')),
          content: Text(context.tr('Are you sure you want to log out?')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.logout),
              label: Text(context.tr('Log out')),
            ),
          ],
        ),
      ) ??
      false;
  if (!shouldSignOut || !context.mounted) return;
  await Provider.of<AuthProvider>(context, listen: false).signOut();
}
