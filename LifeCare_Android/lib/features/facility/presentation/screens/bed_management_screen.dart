import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BedManagementScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const BedManagementScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<BedManagementScreen> createState() => _BedManagementScreenState();
}

class _BedManagementScreenState extends State<BedManagementScreen> {
  String? _selectedWardId;

  Color _getBedStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'occupied':
        return Colors.red;
      case 'cleaning':
        return Colors.orange;
      case 'maintenance':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getBedStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Icons.check_circle;
      case 'occupied':
        return Icons.person;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'maintenance':
        return Icons.build;
      default:
        return Icons.hotel;
    }
  }

  Future<void> _updateBedStatus(String bedId, String newStatus) async {
    try {
      if (_selectedWardId == null) return;

      await FirebaseFirestore.instance.collection('beds').doc(bedId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bed status updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating bed status: $e'),
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
        title: const Text('Bed Management'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Ward Selection
          Container(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('wards')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final wards = snapshot.data!.docs;

                if (wards.isEmpty) {
                  return const Text(
                    'No wards configured. Please add wards first.',
                    style: TextStyle(color: Colors.red),
                  );
                }

                return DropdownButtonFormField<String>(
                  value: _selectedWardId,
                  decoration: const InputDecoration(
                    labelText: 'Select Ward',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  items: wards.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text('${data['wardName']} (${data['wardType']})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedWardId = value;
                    });
                  },
                );
              },
            ),
          ),

          // Bed Statistics
          if (_selectedWardId != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('beds')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .where('wardId', isEqualTo: _selectedWardId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final beds = snapshot.data!.docs;
                final totalBeds = beds.length;
                final availableBeds = beds
                    .where(
                      (doc) =>
                          (doc.data() as Map<String, dynamic>)['status'] ==
                          'available',
                    )
                    .length;
                final occupiedBeds = beds
                    .where(
                      (doc) =>
                          (doc.data() as Map<String, dynamic>)['status'] ==
                          'occupied',
                    )
                    .length;
                final occupancyRate = totalBeds > 0
                    ? (occupiedBeds / totalBeds * 100).toStringAsFixed(1)
                    : '0';

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        'Total Beds',
                        totalBeds.toString(),
                        Icons.hotel,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Available',
                        availableBeds.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                      _buildStatCard(
                        'Occupied',
                        occupiedBeds.toString(),
                        Icons.person,
                        Colors.red,
                      ),
                      _buildStatCard(
                        'Occupancy',
                        '$occupancyRate%',
                        Icons.pie_chart,
                        Colors.orange,
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 16),

          // Beds Grid
          if (_selectedWardId != null)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('beds')
                    .where('facilityId', isEqualTo: widget.facilityId)
                    .where('wardId', isEqualTo: _selectedWardId)
                    .orderBy('bedNumber')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final beds = snapshot.data!.docs;

                  if (beds.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hotel, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No beds in this ward',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                    itemCount: beds.length,
                    itemBuilder: (context, index) {
                      final bed = beds[index].data() as Map<String, dynamic>;
                      final bedId = beds[index].id;
                      final status = bed['status'] ?? 'available';

                      return InkWell(
                        onTap: () => _showBedDetails(context, bedId, bed),
                        child: Card(
                          elevation: 3,
                          color: _getBedStatusColor(status).withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _getBedStatusColor(status),
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getBedStatusIcon(status),
                                  size: 40,
                                  color: _getBedStatusColor(status),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Bed ${bed['bedNumber'] ?? 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  bed['bedType'] ?? 'Standard',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getBedStatusColor(status),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (status == 'occupied' &&
                                    bed['occupiedByName'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      bed['occupiedByName'],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          else
            Expanded(
              child: Center(
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
                      'Select a ward to view beds',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  void _showBedDetails(
    BuildContext context,
    String bedId,
    Map<String, dynamic> bed,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bed ${bed['bedNumber'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Type: ${bed['bedType'] ?? 'Standard'}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${(bed['status'] ?? 'available').toUpperCase()}',
              style: TextStyle(
                fontSize: 16,
                color: _getBedStatusColor(bed['status'] ?? 'available'),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (bed['status'] == 'occupied' &&
                bed['occupiedByName'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Patient: ${bed['occupiedByName']}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
            const SizedBox(height: 24),
            if (bed['status'] != 'occupied')
              Column(
                children: [
                  const Text(
                    'Change Status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (bed['status'] != 'available')
                        ElevatedButton.icon(
                          onPressed: () {
                            _updateBedStatus(bedId, 'available');
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Available'),
                        ),
                      if (bed['status'] != 'cleaning')
                        ElevatedButton.icon(
                          onPressed: () {
                            _updateBedStatus(bedId, 'cleaning');
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.cleaning_services, size: 18),
                          label: const Text('Cleaning'),
                        ),
                      if (bed['status'] != 'maintenance')
                        ElevatedButton.icon(
                          onPressed: () {
                            _updateBedStatus(bedId, 'maintenance');
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.build, size: 18),
                          label: const Text('Maintenance'),
                        ),
                    ],
                  ),
                ],
              )
            else
              const Text(
                'Cannot change status while bed is occupied',
                style: TextStyle(
                  color: Colors.red,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
