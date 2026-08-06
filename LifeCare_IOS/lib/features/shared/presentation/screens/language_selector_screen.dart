import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/localization/app_localizations.dart';

class LanguageSelectorScreen extends StatelessWidget {
  const LanguageSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.selectLanguage ?? 'Select Language'),
        backgroundColor: Colors.blue,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: LanguageProvider.supportedLanguages.length,
        itemBuilder: (context, index) {
          final language = LanguageProvider.supportedLanguages[index];
          final languageCode = language['code']!;
          final isSelected =
              languageProvider.locale.languageCode == languageCode;

          return Card(
            elevation: isSelected ? 4 : 1,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _getLanguageFlag(languageCode),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              title: Text(
                language['nativeName']!,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 18,
                  color: isSelected ? Colors.blue : Colors.black87,
                ),
              ),
              subtitle: Text(
                language['name']!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.blue, size: 28)
                  : const Icon(
                      Icons.radio_button_unchecked,
                      color: Colors.grey,
                    ),
              onTap: () async {
                await languageProvider.setLocale(Locale(languageCode));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${language['nativeName']} ${localizations?.translate('selected') ?? 'selected'}',
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  String _getLanguageFlag(String code) {
    switch (code) {
      case 'en':
        return '🇬🇧'; // UK flag for English
      case 'ha':
        return '🇳🇬'; // Nigeria flag for Hausa
      case 'sw':
        return '🇹🇿'; // Tanzania flag for Swahili
      case 'fr':
        return '🇫🇷'; // France flag for French
      case 'es':
        return '🇪🇸'; // Spain flag for Spanish
      case 'ig':
        return '🇳🇬'; // Nigeria flag for Igbo
      case 'yo':
        return '🇳🇬'; // Nigeria flag for Yoruba
      default:
        return '🌍';
    }
  }
}

class LanguageSelectorDialog extends StatelessWidget {
  const LanguageSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final localizations = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.language, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    localizations?.selectLanguage ?? 'Select Language',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),
            ...LanguageProvider.supportedLanguages.map((language) {
              final languageCode = language['code']!;
              final isSelected =
                  languageProvider.locale.languageCode == languageCode;

              return ListTile(
                leading: Text(
                  _getLanguageFlag(languageCode),
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(
                  language['nativeName']!,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(language['name']!),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.blue)
                    : null,
                onTap: () async {
                  await languageProvider.setLocale(Locale(languageCode));
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getLanguageFlag(String code) {
    switch (code) {
      case 'en':
        return '🇬🇧';
      case 'ha':
        return '🇳🇬';
      case 'sw':
        return '🇹🇿';
      case 'fr':
        return '🇫🇷';
      case 'es':
        return '🇪🇸';
      case 'ig':
        return '🇳🇬';
      case 'yo':
        return '🇳🇬';
      default:
        return '🌍';
    }
  }
}
