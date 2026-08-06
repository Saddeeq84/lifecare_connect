import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WardSetupScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const WardSetupScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<WardSetupScreen> createState() => _WardSetupScreenState();
}

class _WardSetupScreenState extends State<WardSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wardNameController = TextEditingController();
  final _numberOfBedsController = TextEditingController();

  String _wardType = 'General Ward';
  bool _isLoading = false;

  @override
  void dispose() {
    _wardNameController.dispose();
    _numberOfBedsController.dispose();
    super.dispose();
  }

  Future<void> _createWard() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final numberOfBeds = int.parse(_numberOfBedsController.text.trim());
      final wardName = _wardNameController.text.trim();

      // Create ward
      final wardRef = FirebaseFirestore.instance.collection('wards').doc();
      await wardRef.set({
        'wardId': wardRef.id,
        'wardName': wardName,
        'wardType': _wardType,
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityName,
        'totalBeds': numberOfBeds,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create beds for this ward in top-level beds collection
      final batch = FirebaseFirestore.instance.batch();
      for (int i = 1; i <= numberOfBeds; i++) {
        final bedRef = FirebaseFirestore.instance.collection('beds').doc();
        batch.set(bedRef, {
          'bedId': bedRef.id,
          'bedNumber': i.toString().padLeft(2, '0'),
          'bedType': _wardType == 'ICU' ? 'ICU Bed' : 'Standard',
          'wardId': wardRef.id,
          'wardName': wardName,
          'facilityId': widget.facilityId,
          'status': 'available',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ward created with $numberOfBeds beds successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _wardNameController.clear();
        _numberOfBedsController.clear();
        setState(() {
          _wardType = 'General Ward';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating ward: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteWard(String wardId, String wardName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Ward'),
        content: Text(
          'Are you sure you want to delete "$wardName"? This will also delete all beds in this ward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Delete all beds in this ward from top-level beds collection
      final beds = await FirebaseFirestore.instance
          .collection('beds')
          .where('wardId', isEqualTo: wardId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var bed in beds.docs) {
        batch.delete(bed.reference);
      }

      // Delete ward from both locations (old root collection and new nested path)
      // Delete from old root collection
      batch.delete(FirebaseFirestore.instance.collection('wards').doc(wardId));

      // Delete from new nested collection
      batch.delete(
        FirebaseFirestore.instance
            .collection('facilities')
            .doc(widget.facilityId)
            .collection('wards')
            .doc(wardId),
      );

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ward deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting ward: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createStandardWards() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Standard Wards'),
        content: const Text(
          'This will create the following standard wards:\n\n'
          '• Male Ward (20 beds)\n'
          '• Female Ward (20 beds)\n'
          '• Pediatric Ward (15 beds)\n'
          '• Maternity Ward (12 beds)\n'
          '• ICU (8 beds)\n'
          '• Private Ward (6 beds)\n\n'
          'Do you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final standardWards = [
        {'name': 'Male Ward', 'type': 'General Ward', 'beds': 20},
        {'name': 'Female Ward', 'type': 'General Ward', 'beds': 20},
        {'name': 'Pediatric Ward', 'type': 'Pediatric', 'beds': 15},
        {'name': 'Maternity Ward', 'type': 'Maternity', 'beds': 12},
        {'name': 'ICU', 'type': 'ICU', 'beds': 8},
        {'name': 'Private Ward', 'type': 'Private Ward', 'beds': 6},
      ];

      for (var ward in standardWards) {
        // Create ward
        final wardRef = FirebaseFirestore.instance.collection('wards').doc();
        await wardRef.set({
          'wardId': wardRef.id,
          'wardName': ward['name'],
          'wardType': ward['type'],
          'facilityId': widget.facilityId,
          'facilityName': widget.facilityName,
          'totalBeds': ward['beds'],
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Create beds for this ward
        final batch = FirebaseFirestore.instance.batch();
        final numberOfBeds = ward['beds'] as int;
        for (int i = 1; i <= numberOfBeds; i++) {
          final bedRef = FirebaseFirestore.instance.collection('beds').doc();
          batch.set(bedRef, {
            'bedId': bedRef.id,
            'bedNumber': i.toString().padLeft(2, '0'),
            'bedType': ward['type'] == 'ICU'
                ? 'ICU Bed'
                : ward['type'] == 'Private Ward'
                ? 'Private'
                : 'Standard',
            'wardId': wardRef.id,
            'wardName': ward['name'],
            'facilityId': widget.facilityId,
            'status': 'available',
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Standard wards created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating standard wards: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ward & Bed Setup'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Create Standard Wards',
            onPressed: _isLoading ? null : _createStandardWards,
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Setup Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.teal.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap the ✨ icon above to quickly create standard wards (Male, Female, Pediatric, Maternity, ICU, Private)',
                    style: TextStyle(color: Colors.teal.shade900, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Add Ward Form
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create New Ward',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _wardNameController,
                        decoration: const InputDecoration(
                          labelText: 'Ward Name',
                          border: OutlineInputBorder(),
                          hintText: 'e.g., Male Ward, Female Ward',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter ward name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _wardType,
                        decoration: const InputDecoration(
                          labelText: 'Ward Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'General Ward',
                            child: Text('General Ward'),
                          ),
                          DropdownMenuItem(
                            value: 'Private Ward',
                            child: Text('Private Ward'),
                          ),
                          DropdownMenuItem(value: 'ICU', child: Text('ICU')),
                          DropdownMenuItem(
                            value: 'Maternity',
                            child: Text('Maternity'),
                          ),
                          DropdownMenuItem(
                            value: 'Pediatric',
                            child: Text('Pediatric'),
                          ),
                          DropdownMenuItem(
                            value: 'Surgical',
                            child: Text('Surgical'),
                          ),
                          DropdownMenuItem(
                            value: 'Emergency',
                            child: Text('Emergency'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _wardType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _numberOfBedsController,
                        decoration: const InputDecoration(
                          labelText: 'Number of Beds',
                          border: OutlineInputBorder(),
                          hintText: 'e.g., 10',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter number of beds';
                          }
                          final number = int.tryParse(value.trim());
                          if (number == null || number <= 0) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createWard,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text('Create Ward with Beds'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Existing Wards List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('wards')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final wards = snapshot.data!.docs;

                if (wards.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_city,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No wards created yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first ward above',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: wards.length,
                  itemBuilder: (context, index) {
                    final ward = wards[index].data() as Map<String, dynamic>;
                    final wardId = wards[index].id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Text(
                            ward['totalBeds'].toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          ward['wardName'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${ward['wardType']} - ${ward['totalBeds']} beds',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('beds')
                                  .where('wardId', isEqualTo: wardId)
                                  .where('status', isEqualTo: 'occupied')
                                  .snapshots(),
                              builder: (context, bedSnapshot) {
                                if (!bedSnapshot.hasData) {
                                  return const SizedBox.shrink();
                                }
                                final occupied = bedSnapshot.data!.docs.length;
                                final total = ward['totalBeds'] as int;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$occupied/$total occupied',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteWard(
                                wardId,
                                ward['wardName'] ?? 'Unknown',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
