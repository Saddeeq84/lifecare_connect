import 'package:flutter/material.dart';
import '../../data/services/appointment_service.dart';

class AdminDebugScreen extends StatefulWidget {
  const AdminDebugScreen({super.key});

  @override
  State<AdminDebugScreen> createState() => _AdminDebugScreenState();
}

class _AdminDebugScreenState extends State<AdminDebugScreen> {
  bool _isProcessing = false;
  String _logOutput = '';

  void _addLog(String message) {
    setState(() {
      _logOutput += '$message\n';
    });
    debugPrint(message);
  }

  Future<void> _createMissingConsultations() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _logOutput = '';
    });

    try {
      _addLog('🔄 Starting consultation migration...');
      await AppointmentService.createMissingConsultations();
      _addLog('✅ Migration completed successfully!');
    } catch (e) {
      _addLog('❌ Migration failed: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Debug Tools'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consultation Migration',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will create consultation documents for all approved appointments that don\'t have consultations yet. This fixes the issue where patients can\'t see their approved appointments in the consultation screen.',
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : _createMissingConsultations,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.build),
                      label: Text(
                        _isProcessing
                            ? 'Processing...'
                            : 'Create Missing Consultations',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Log Output:',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _logOutput.isEmpty ? 'No logs yet...' : _logOutput,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
