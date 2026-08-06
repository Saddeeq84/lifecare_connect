import 'package:flutter/material.dart';
import '../services/ai_validation_service.dart';

/// AI Validation Alert Dialog
/// Shows warnings, suggestions, and AI recommendations
class AIValidationDialog extends StatelessWidget {
  final ValidationResult result;
  final String title;
  final VoidCallback? onProceed;
  final VoidCallback? onCancel;

  const AIValidationDialog({
    super.key,
    required this.result,
    required this.title,
    this.onProceed,
    this.onCancel,
  });

  static Future<bool?> show({
    required BuildContext context,
    required ValidationResult result,
    required String title,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AIValidationDialog(
        result: result,
        title: title,
        onProceed: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(result.severity.icon, color: result.severity.color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: result.severity.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Severity Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: result.severity.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: result.severity.color),
              ),
              child: Text(
                _getSeverityText(result.severity),
                style: TextStyle(
                  color: result.severity.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Warnings Section
            if (result.warnings.isNotEmpty) ...[
              _buildSectionHeader('⚠️ Warnings', Colors.orange),
              const SizedBox(height: 8),
              ...result.warnings.map(
                (warning) => _buildListItem(
                  warning,
                  warning.contains('🔴') ? Colors.red : Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Suggestions Section
            if (result.suggestions.isNotEmpty) ...[
              _buildSectionHeader('💡 Recommendations', Colors.blue),
              const SizedBox(height: 8),
              ...result.suggestions.map(
                (suggestion) => _buildListItem(suggestion, Colors.blue),
              ),
              const SizedBox(height: 16),
            ],

            // AI Recommendation
            if (result.aiRecommendation != null) ...[
              _buildSectionHeader('🤖 AI Analysis', Colors.teal),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Text(
                  result.aiRecommendation!,
                  style: TextStyle(color: Colors.teal.shade900, fontSize: 13),
                ),
              ),
            ],

            if (result.severity == ValidationSeverity.critical) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI Advisory: Please review these warnings. You can proceed if clinically appropriate.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: onCancel, child: const Text('Review & Edit')),
        ElevatedButton(
          onPressed: onProceed,
          style: ElevatedButton.styleFrom(
            backgroundColor: result.severity.color,
            foregroundColor: Colors.white,
          ),
          child: const Text('Acknowledge & Proceed'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _buildListItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSeverityText(ValidationSeverity severity) {
    switch (severity) {
      case ValidationSeverity.safe:
        return 'SAFE ✓';
      case ValidationSeverity.info:
        return 'INFORMATIONAL';
      case ValidationSeverity.warning:
        return 'CAUTION ADVISED';
      case ValidationSeverity.critical:
        return 'CRITICAL ALERT';
    }
  }
}

/// Inline AI Validation Widget
/// Shows validation status inline with form fields
class InlineValidationWidget extends StatelessWidget {
  final ValidationResult result;

  const InlineValidationWidget({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    if (!result.hasWarnings && !result.hasSuggestions) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.severity.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: result.severity.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.severity.icon,
                color: result.severity.color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'AI Validation',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: result.severity.color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...result.warnings
                .take(2)
                .map(
                  (warning) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      warning,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ),
          ],
          if (result.warnings.length > 2)
            TextButton(
              onPressed: () {
                AIValidationDialog.show(
                  context: context,
                  result: result,
                  title: 'AI Validation Details',
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
              ),
              child: const Text(
                'View all warnings →',
                style: TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
