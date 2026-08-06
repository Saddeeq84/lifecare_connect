import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BedCleanupScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const BedCleanupScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<BedCleanupScreen> createState() => _BedCleanupScreenState();
}

class _BedCleanupScreenState extends State<BedCleanupScreen> {
  bool _isScanning = false;
  bool _isFixing = false;
  final List<Map<String, dynamic>> _ghostBeds = [];

  Future<void> _scanForGhostBeds() async {
    setState(() {
      _isScanning = true;
      _ghostBeds.clear();
    });

    try {
      // Get all wards
      final wardsSnapshot = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(widget.facilityId)
          .collection('wards')
          .get();

      for (var wardDoc in wardsSnapshot.docs) {
        final wardId = wardDoc.id;
        final wardName = wardDoc.data()['wardName'] ?? 'Unknown Ward';

        // Get all occupied beds in this ward
        final bedsSnapshot = await FirebaseFirestore.instance
            .collection('beds')
            .where('facilityId', isEqualTo: widget.facilityId)
            .where('wardId', isEqualTo: wardId)
            .where('status', isEqualTo: 'occupied')
            .get();

        for (var bedDoc in bedsSnapshot.docs) {
          final bedData = bedDoc.data();
          final bedId = bedDoc.id;
          final bedNumber = bedData['bedNumber'] ?? 'Unknown';
          final patientId = bedData['patientId'];
          final inpatientId = bedData['inpatientId'];

          // Check if there's an active inpatient for this bed
          bool hasActiveInpatient = false;

          if (inpatientId != null) {
            final inpatientDoc = await FirebaseFirestore.instance
                .collection('inpatients')
                .doc(inpatientId)
                .get();

            if (inpatientDoc.exists) {
              final inpatientData = inpatientDoc.data();
              final status = inpatientData?['status'];
              hasActiveInpatient =
                  (status != 'discharged' && status != 'cancelled');
            }
          }

          // If no active inpatient, this is a ghost bed
          if (!hasActiveInpatient) {
            _ghostBeds.add({
              'wardId': wardId,
              'wardName': wardName,
              'bedId': bedId,
              'bedNumber': bedNumber,
              'patientId': patientId,
              'inpatientId': inpatientId,
              'occupiedBy': bedData['occupiedBy'],
              'occupiedByName': bedData['occupiedByName'],
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _isScanning = false;
        });

        if (_ghostBeds.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No ghost beds found! All beds are properly synchronized.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning beds: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fixGhostBeds() async {
    if (_ghostBeds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fix Ghost Beds'),
        content: Text(
          'This will release ${_ghostBeds.length} occupied bed(s) that have no active inpatient. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Fix'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isFixing = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      int fixedCount = 0;

      for (var ghostBed in _ghostBeds) {
        final bedRef = FirebaseFirestore.instance
            .collection('facilities')
            .doc(widget.facilityId)
            .collection('wards')
            .doc(ghostBed['wardId'])
            .collection('beds')
            .doc(ghostBed['bedId']);

        batch.update(bedRef, {
          'status': 'available',
          'occupiedBy': null,
          'occupiedByName': null,
          'patientId': null,
          'inpatientId': null,
          'occupiedAt': null,
          'releasedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        fixedCount++;
      }

      await batch.commit();

      if (mounted) {
        setState(() {
          _isFixing = false;
          _ghostBeds.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully released $fixedCount ghost bed(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFixing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fixing beds: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bed Cleanup Tool'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Bed Cleanup Tool',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This tool finds and fixes "ghost beds" - beds marked as occupied but with no active inpatient. These can occur when:\n\n'
                      '• Patient discharge process was interrupted\n'
                      '• System error during bed release\n'
                      '• Data migration issues\n\n'
                      'Click "Scan for Ghost Beds" to identify issues.',
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _scanForGhostBeds,
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(_isScanning ? 'Scanning...' : 'Scan for Ghost Beds'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            if (_ghostBeds.isNotEmpty) ...[
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Found ${_ghostBeds.length} Ghost Bed(s)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'These beds are marked as occupied but have no active inpatient:',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _ghostBeds.length,
                  itemBuilder: (context, index) {
                    final ghost = _ghostBeds[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Text(
                            ghost['bedNumber'].toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(ghost['wardName']),
                        subtitle: Text(
                          'Bed ${ghost['bedNumber']}\n'
                          'Occupied by: ${ghost['occupiedByName'] ?? 'Unknown'}\n'
                          'Patient ID: ${ghost['patientId'] ?? 'None'}',
                        ),
                        trailing: const Icon(Icons.error, color: Colors.orange),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isFixing ? null : _fixGhostBeds,
                icon: _isFixing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.build),
                label: Text(_isFixing ? 'Fixing...' : 'Fix All Ghost Beds'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
