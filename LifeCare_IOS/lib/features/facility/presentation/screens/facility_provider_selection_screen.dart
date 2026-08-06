// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'facility_pharmacy_cart_screen.dart';

class FacilityProviderSelectionScreen extends StatelessWidget {
  final String categoryType;
  final String categoryLabel;

  const FacilityProviderSelectionScreen({
    super.key,
    required this.categoryType,
    required this.categoryLabel,
  });

  void _onProviderSelected(BuildContext context, DocumentSnapshot providerDoc) {
    final providerData = providerDoc.data() as Map<String, dynamic>;
    final providerType =
        categoryType; // 'Pharmacy', 'Laboratory', 'Scan Center'

    // Route to appropriate screen based on provider type
    if (providerType == 'Pharmacy') {
      // Navigate to pharmacy cart screen for product browsing
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FacilityPharmacyCartScreen(
            facilityId: providerDoc.id,
            facilityData: providerData,
          ),
        ),
      );
    } else {
      // For labs and scan centers, show coming soon (can implement later)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ordering from $providerType is coming soon!'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select $categoryLabel'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade50, Colors.teal.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _getCategoryIcon(categoryType),
                  size: 48,
                  color: Colors.teal.shade700,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Order Medical Supplies',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a $categoryLabel to order supplies from',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Provider List
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Available ${categoryLabel}s',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a provider to browse their products',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildProviderList()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderList() {
    // Query providers by type field
    final providersQuery = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'facility')
        .where('isApproved', isEqualTo: true)
        .where('type', isEqualTo: categoryType);

    return StreamBuilder<QuerySnapshot>(
      stream: providersQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final docs = snapshot.data?.docs ?? [];

        // Filter to only show active providers
        final activeProviders = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // If isActive field doesn't exist, assume provider is active
          return !data.containsKey('isActive') || data['isActive'] == true;
        }).toList();

        if (activeProviders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  "No ${categoryLabel}s found",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: activeProviders.length,
          itemBuilder: (context, index) {
            final provider = activeProviders[index];
            final data = provider.data() as Map<String, dynamic>;
            final name =
                data['facilityName'] ?? data['name'] ?? 'Unknown Provider';
            final type = data['type'] ?? data['facilityType'] ?? 'Unknown Type';
            final location =
                data['location'] ?? data['address'] ?? 'Unknown Location';
            final phone = data['phone'] ?? 'N/A';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.shade100,
                  child: Icon(
                    _getCategoryIcon(type),
                    color: Colors.teal.shade700,
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('$location\nPhone: $phone'),
                isThreeLine: true,
                trailing: ElevatedButton.icon(
                  onPressed: () => _onProviderSelected(context, provider),
                  icon: const Icon(Icons.shopping_cart, size: 18),
                  label: const Text('Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getCategoryIcon(String providerType) {
    final type = providerType.toLowerCase();

    if (type.contains('pharmacy')) {
      return Icons.local_pharmacy;
    } else if (type.contains('laboratory') || type.contains('lab')) {
      return Icons.science;
    } else if (type.contains('scan') || type.contains('imaging')) {
      return Icons.monitor_heart;
    } else {
      return Icons.business;
    }
  }
}
