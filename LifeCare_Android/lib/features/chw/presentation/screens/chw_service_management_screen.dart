import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CHWServiceManagementScreen extends StatefulWidget {
  const CHWServiceManagementScreen({super.key});

  @override
  State<CHWServiceManagementScreen> createState() =>
      _CHWServiceManagementScreenState();
}

class _CHWServiceManagementScreenState
    extends State<CHWServiceManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Price controllers
  final _consultationController = TextEditingController();
  final _ancController = TextEditingController();
  final _pncController = TextEditingController();
  final _homeVisitController = TextEditingController();
  final _immunizationController = TextEditingController();
  final _appointmentController = TextEditingController();

  // Default prices
  final Map<String, double> _defaultPrices = {
    'consultation': 500.0,
    'anc': 500.0,
    'pnc': 400.0,
    'home_visit': 300.0,
    'immunization': 200.0,
    'appointment': 100.0,
  };

  @override
  void initState() {
    super.initState();
    _loadServicePrices();
  }

  Future<void> _loadServicePrices() async {
    setState(() => _isLoading = true);

    try {
      final chwId = FirebaseAuth.instance.currentUser?.uid;
      if (chwId == null) throw Exception('CHW not logged in');

      final serviceDoc = await FirebaseFirestore.instance
          .collection('chw_services')
          .doc(chwId)
          .get();

      if (serviceDoc.exists) {
        final services =
            serviceDoc.data()?['services'] as Map<String, dynamic>?;

        _consultationController.text =
            (services?['consultation'] ?? _defaultPrices['consultation'])
                .toString();
        _ancController.text = (services?['anc'] ?? _defaultPrices['anc'])
            .toString();
        _pncController.text = (services?['pnc'] ?? _defaultPrices['pnc'])
            .toString();
        _homeVisitController.text =
            (services?['home_visit'] ?? _defaultPrices['home_visit'])
                .toString();
        _immunizationController.text =
            (services?['immunization'] ?? _defaultPrices['immunization'])
                .toString();
        _appointmentController.text =
            (services?['appointment'] ?? _defaultPrices['appointment'])
                .toString();
      } else {
        // Set default prices
        _consultationController.text = _defaultPrices['consultation']
            .toString();
        _ancController.text = _defaultPrices['anc'].toString();
        _pncController.text = _defaultPrices['pnc'].toString();
        _homeVisitController.text = _defaultPrices['home_visit'].toString();
        _immunizationController.text = _defaultPrices['immunization']
            .toString();
        _appointmentController.text = _defaultPrices['appointment'].toString();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading prices: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveServicePrices() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final chwId = FirebaseAuth.instance.currentUser?.uid;
      if (chwId == null) throw Exception('CHW not logged in');

      final services = {
        'consultation': double.parse(_consultationController.text),
        'anc': double.parse(_ancController.text),
        'pnc': double.parse(_pncController.text),
        'home_visit': double.parse(_homeVisitController.text),
        'immunization': double.parse(_immunizationController.text),
        'appointment': double.parse(_appointmentController.text),
      };

      await FirebaseFirestore.instance
          .collection('chw_services')
          .doc(chwId)
          .set({
            'chwId': chwId,
            'services': services,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service prices updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving prices: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Default Prices'),
        content: const Text(
          'Are you sure you want to reset all prices to their default values?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _consultationController.text = _defaultPrices['consultation']
                    .toString();
                _ancController.text = _defaultPrices['anc'].toString();
                _pncController.text = _defaultPrices['pnc'].toString();
                _homeVisitController.text = _defaultPrices['home_visit']
                    .toString();
                _immunizationController.text = _defaultPrices['immunization']
                    .toString();
                _appointmentController.text = _defaultPrices['appointment']
                    .toString();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Prices reset to defaults')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _consultationController.dispose();
    _ancController.dispose();
    _pncController.dispose();
    _homeVisitController.dispose();
    _immunizationController.dispose();
    _appointmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Management'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetToDefaults,
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: Colors.deepPurple.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.deepPurple,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Service Pricing Information',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Set your prices for each service. Payment will be automatically deducted from patient wallets.',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'You receive 70% of each payment. 30% goes to platform administration.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Service Prices (₦)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildServicePriceCard(
                      title: 'Consultation',
                      icon: Icons.medical_services,
                      color: Colors.blue,
                      controller: _consultationController,
                      description: 'General health consultation and assessment',
                    ),
                    const SizedBox(height: 12),

                    _buildServicePriceCard(
                      title: 'Antenatal Care (ANC)',
                      icon: Icons.pregnant_woman,
                      color: Colors.pink,
                      controller: _ancController,
                      description: 'Prenatal checkup and monitoring',
                    ),
                    const SizedBox(height: 12),

                    _buildServicePriceCard(
                      title: 'Postnatal Care (PNC)',
                      icon: Icons.child_care,
                      color: Colors.purple,
                      controller: _pncController,
                      description: 'Postpartum mother and baby care',
                    ),
                    const SizedBox(height: 12),

                    _buildServicePriceCard(
                      title: 'Home Visit',
                      icon: Icons.home,
                      color: Colors.orange,
                      controller: _homeVisitController,
                      description: 'Community-based patient visit',
                    ),
                    const SizedBox(height: 12),

                    _buildServicePriceCard(
                      title: 'Immunization',
                      icon: Icons.vaccines,
                      color: Colors.teal,
                      controller: _immunizationController,
                      description: 'Vaccine administration and tracking',
                    ),
                    const SizedBox(height: 12),

                    _buildServicePriceCard(
                      title: 'Appointment Booking',
                      icon: Icons.event,
                      color: Colors.indigo,
                      controller: _appointmentController,
                      description: 'Schedule future visit',
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveServicePrices,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save, color: Colors.white),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save Prices',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildServicePriceCard({
    required String title,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
    required String description,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Price (₦)',
                prefixText: '₦ ',
                border: const OutlineInputBorder(),
                suffixIcon: Icon(Icons.edit, color: color),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (val) {
                if (val?.isEmpty ?? true) return 'Required';
                final price = double.tryParse(val!);
                if (price == null || price < 0) return 'Invalid price';
                return null;
              },
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will receive: ₦${(double.tryParse(controller.text) ?? 0) * 0.7}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
