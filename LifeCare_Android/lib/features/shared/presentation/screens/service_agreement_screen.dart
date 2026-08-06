import 'package:flutter/material.dart';
import '../../../../core/constants/service_agreement.dart';

class ServiceAgreementScreen extends StatelessWidget {
  final String? userRole; // 'patient', 'doctor', 'chw', 'facility', 'admin'

  const ServiceAgreementScreen({super.key, this.userRole});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Agreement'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // Show version info
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                'v${ServiceAgreement.version}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Version and Date Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.teal.shade50,
            child: Column(
              children: [
                Text(
                  'Version ${ServiceAgreement.version}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Effective Date: ${ServiceAgreement.effectiveDate}',
                  style: TextStyle(fontSize: 12, color: Colors.teal.shade700),
                ),
              ],
            ),
          ),

          // Role-specific highlight (if role provided)
          if (userRole != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.orange.shade50,
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
                      _getRoleMessage(userRole!),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Full Agreement Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                ServiceAgreement.fullAgreement,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    _showShortSummary(context);
                  },
                  icon: const Icon(Icons.summarize),
                  label: const Text('View Summary'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Close'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleMessage(String role) {
    switch (role.toLowerCase()) {
      case 'patient':
        return 'As a patient, pay special attention to Section 2.1 regarding remote consultation limitations.';
      case 'doctor':
        return 'As a doctor, please review Section 2.2 regarding professional indemnity and your responsibilities.';
      case 'chw':
        return 'As a CHW, please review Section 2.3 regarding scope of practice and indemnification.';
      case 'facility':
        return 'As a facility, please review Section 2.4 and Section 4 regarding subscription fees and responsibilities.';
      case 'admin':
        return 'Review all sections to understand platform-wide terms and user responsibilities.';
      default:
        return 'Please review the agreement carefully.';
    }
  }

  void _showShortSummary(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Summary'),
        content: SingleChildScrollView(
          child: SelectableText(
            ServiceAgreement.shortSummary,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
