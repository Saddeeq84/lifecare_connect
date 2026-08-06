import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// General Patient Transfer Screen
/// Allows transferring patients between any wards
class PatientTransferScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const PatientTransferScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<PatientTransferScreen> createState() => _PatientTransferScreenState();
}

class _PatientTransferScreenState extends State<PatientTransferScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Patients'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade700, Colors.teal.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.transfer_within_a_station,
                      size: 32,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Patient Transfer',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Transfer patients between wards',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by patient name or ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          // Admitted Patients List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('admissions')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .where('status', isEqualTo: 'admitted')
                  .where('isActive', isEqualTo: true)
                  .orderBy('admittedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.transfer_within_a_station,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No Admitted Patients',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No patients available for transfer',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Filter by search query
                var filteredDocs = snapshot.data!.docs.where((doc) {
                  if (_searchQuery.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final patientName = (data['patientName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final patientId = (data['patientId'] ?? '')
                      .toString()
                      .toLowerCase();
                  return patientName.contains(_searchQuery) ||
                      patientId.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No Results Found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final admission =
                        filteredDocs[index].data() as Map<String, dynamic>;
                    final admissionId = filteredDocs[index].id;
                    return _buildPatientCard(admission, admissionId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> admission, String admissionId) {
    final patientName = admission['patientName'] ?? 'Unknown Patient';
    final patientId = admission['patientId'] ?? 'N/A';
    final wardName = admission['wardName'] ?? 'Not Assigned';
    final bedNumber = admission['bedNumber'] ?? 'Not Assigned';
    final admissionType = admission['admissionType'] ?? 'regular';
    final admittedAt = admission['admittedAt'];

    String admittedDateStr = 'N/A';
    if (admittedAt != null) {
      try {
        DateTime admittedDate;
        if (admittedAt is Timestamp) {
          admittedDate = admittedAt.toDate();
        } else if (admittedAt is String) {
          admittedDate = DateTime.parse(admittedAt);
        } else {
          admittedDate = DateTime.now();
        }
        admittedDateStr = DateFormat(
          'MMM dd, yyyy hh:mm a',
        ).format(admittedDate);
      } catch (e) {
        admittedDateStr = 'Invalid Date';
      }
    }

    Color typeColor = Colors.blue;
    String typeLabel = admissionType.toUpperCase();
    if (admissionType.toLowerCase() == 'emergency') {
      typeColor = Colors.red;
    } else if (admissionType.toLowerCase() == 'scheduled') {
      typeColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTransferDialog(admission, admissionId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.teal.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: $patientId',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.local_hotel,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ward: $wardName',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.bed, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Bed: $bedNumber',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Admitted: $admittedDateStr',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showTransferDialog(admission, admissionId),
                    icon: const Icon(Icons.transfer_within_a_station, size: 18),
                    label: const Text('Transfer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTransferDialog(
    Map<String, dynamic> admission,
    String admissionId,
  ) async {
    final patientName = admission['patientName'] ?? 'Unknown Patient';
    final currentWardId = admission['wardId'];

    // Get all available wards (except current ward)
    final wardsSnapshot = await FirebaseFirestore.instance
        .collection('wards')
        .where('facilityId', isEqualTo: widget.facilityId)
        .where('isActive', isEqualTo: true)
        .get();

    if (!mounted) return;

    // Get wards with available beds (excluding current ward)
    List<Map<String, dynamic>> availableWards = [];
    for (var wardDoc in wardsSnapshot.docs) {
      // Skip current ward
      if (wardDoc.id == currentWardId) continue;

      final wardData = wardDoc.data();

      // Check for available beds
      final bedsSnapshot = await FirebaseFirestore.instance
          .collection('beds')
          .where('wardId', isEqualTo: wardDoc.id)
          .where('status', isEqualTo: 'available')
          .get();

      if (bedsSnapshot.docs.isNotEmpty) {
        availableWards.add({
          'wardId': wardDoc.id,
          'wardName': wardData['wardName'] ?? 'Unknown Ward',
          'wardType': wardData['wardType'] ?? 'general',
          'availableBeds': bedsSnapshot.docs.length,
          'beds': bedsSnapshot.docs,
        });
      }
    }

    if (!mounted) return;

    if (availableWards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other wards with available beds found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? selectedWardId;
    String? selectedBedId;
    Map<String, dynamic>? selectedWard;
    String transferReason = '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Transfer $patientName'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Location:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${admission['wardName']} - Bed ${admission['bedNumber']}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Select destination ward:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedWardId,
                    decoration: const InputDecoration(
                      labelText: 'Ward',
                      border: OutlineInputBorder(),
                    ),
                    items: availableWards.map((ward) {
                      return DropdownMenuItem<String>(
                        value: ward['wardId'],
                        child: Text(
                          '${ward['wardName']} (${ward['availableBeds']} beds available)',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedWardId = value;
                        selectedBedId = null;
                        selectedWard = availableWards.firstWhere(
                          (w) => w['wardId'] == value,
                        );
                      });
                    },
                  ),
                  if (selectedWard != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Select bed:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedBedId,
                      decoration: const InputDecoration(
                        labelText: 'Bed',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          (selectedWard!['beds'] as List<QueryDocumentSnapshot>)
                              .map((bedDoc) {
                                final bedData =
                                    bedDoc.data() as Map<String, dynamic>;
                                return DropdownMenuItem<String>(
                                  value: bedDoc.id,
                                  child: Text(
                                    'Bed ${bedData['bedNumber'] ?? 'N/A'}',
                                  ),
                                );
                              })
                              .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedBedId = value;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Transfer reason (optional):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Enter reason for transfer...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      transferReason = value;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedWardId == null || selectedBedId == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _performTransfer(
                        admissionId,
                        admission,
                        selectedWardId!,
                        selectedBedId!,
                        selectedWard!['wardName'],
                        selectedWard!['wardType'],
                        transferReason,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Transfer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performTransfer(
    String admissionId,
    Map<String, dynamic> admission,
    String newWardId,
    String newBedId,
    String newWardName,
    String newWardType,
    String transferReason,
  ) async {
    try {
      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transferring patient...')));

      final batch = FirebaseFirestore.instance.batch();

      // Get the new bed details
      final newBedDoc = await FirebaseFirestore.instance
          .collection('beds')
          .doc(newBedId)
          .get();

      if (!newBedDoc.exists) {
        throw Exception('Bed not found');
      }

      final newBedData = newBedDoc.data()!;
      final newBedNumber = newBedData['bedNumber'] ?? 'N/A';

      // Release old bed if exists
      final oldBedId = admission['bedId'];
      final oldWardId = admission['wardId'];
      final oldWardName = admission['wardName'];
      final oldBedNumber = admission['bedNumber'];

      if (oldBedId != null && oldBedId.toString().isNotEmpty) {
        final oldBedRef = FirebaseFirestore.instance
            .collection('beds')
            .doc(oldBedId.toString());
        batch.set(oldBedRef, {
          'status': 'available',
          'patientId': FieldValue.delete(),
          'patientName': FieldValue.delete(),
          'admissionId': FieldValue.delete(),
          'facilityId': widget.facilityId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Occupy new bed
      final newBedRef = FirebaseFirestore.instance
          .collection('beds')
          .doc(newBedId);
      batch.set(newBedRef, {
        'status': 'occupied',
        'patientId': admission['patientId'],
        'patientName': admission['patientName'],
        'admissionId': admissionId,
        'facilityId': widget.facilityId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update admission record
      final admissionRef = FirebaseFirestore.instance
          .collection('admissions')
          .doc(admissionId);
      final updateData = {
        'wardId': newWardId,
        'wardName': newWardName,
        'bedId': newBedId,
        'bedNumber': newBedNumber,
        'status': 'pending_acceptance', // Requires acceptance by receiving ward
        'transferredAt': FieldValue.serverTimestamp(),
        'transferredBy': widget.staffId,
        'transferredByName': widget.staffName,
        'transferredFrom': admission['wardName'], // Record source ward
        'lastTransferReason': transferReason.isNotEmpty ? transferReason : null,
        'facilityId': widget.facilityId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Change admissionType if transferring to/from emergency ward
      if (newWardType == 'emergency') {
        updateData['admissionType'] = 'emergency';
      } else if (admission['admissionType'] == 'emergency') {
        updateData['admissionType'] = 'regular';
      }

      batch.update(admissionRef, updateData);

      // Add transfer history
      final transferHistoryRef = FirebaseFirestore.instance
          .collection('transfer_history')
          .doc();
      batch.set(transferHistoryRef, {
        'facilityId': widget.facilityId,
        'admissionId': admissionId,
        'patientId': admission['patientId'],
        'patientName': admission['patientName'],
        'fromWardId': oldWardId,
        'fromWardName': oldWardName,
        'fromBedId': oldBedId,
        'fromBedNumber': oldBedNumber,
        'toWardId': newWardId,
        'toWardName': newWardName,
        'toBedId': newBedId,
        'toBedNumber': newBedNumber,
        'transferType': 'inter_ward',
        'transferredAt': FieldValue.serverTimestamp(),
        'transferredBy': widget.staffId,
        'transferredByName': widget.staffName,
        'reason': transferReason.isNotEmpty ? transferReason : 'Ward transfer',
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Patient successfully transferred to $newWardName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transfer failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
