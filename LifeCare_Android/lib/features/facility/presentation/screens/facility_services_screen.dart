// lib/screens/facilityscreen/facility_services_screen.dart

// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FacilityServicesScreen extends StatefulWidget {
  final String? facilityType;

  const FacilityServicesScreen({super.key, this.facilityType});

  @override
  State<FacilityServicesScreen> createState() => _FacilityServicesScreenState();
}

class _FacilityServicesScreenState extends State<FacilityServicesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final String currentFacilityId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _isStandalonePharmacy {
    return widget.facilityType?.toLowerCase().trim() == 'pharmacy';
  }

  @override
  void initState() {
    super.initState();
    // For standalone pharmacy: 4 tabs (Products, Customers, Requests, Order History)
    // For other facilities: 7 tabs (Services, Laboratory, Radiology, Items, Customers, Requests, Order History)
    _tabController = TabController(
      length: _isStandalonePharmacy ? 4 : 7,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services Management'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: _isStandalonePharmacy
              ? const [
                  Tab(icon: Icon(Icons.medication), text: 'Products'),
                  Tab(icon: Icon(Icons.people_alt), text: 'Customers'),
                  Tab(icon: Icon(Icons.request_quote), text: 'Requests'),
                  Tab(icon: Icon(Icons.local_shipping), text: 'Order History'),
                ]
              : const [
                  Tab(icon: Icon(Icons.medical_services), text: 'Services'),
                  Tab(icon: Icon(Icons.biotech), text: 'Laboratory'),
                  Tab(icon: Icon(Icons.camera_alt), text: 'Radiology'),
                  Tab(icon: Icon(Icons.inventory), text: 'Items'),
                  Tab(icon: Icon(Icons.people_alt), text: 'Customers'),
                  Tab(icon: Icon(Icons.request_quote), text: 'Requests'),
                  Tab(icon: Icon(Icons.local_shipping), text: 'Order History'),
                ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _isStandalonePharmacy
            ? [
                _buildServicesTab(),
                _buildCustomersTab(),
                _buildRequestsTab(),
                _buildOrderHistoryTab(),
              ]
            : [
                _buildServicesTab(),
                _buildLaboratoryTab(),
                _buildRadiologyTab(),
                _buildItemsTab(),
                _buildCustomersTab(),
                _buildRequestsTab(),
                _buildOrderHistoryTab(),
              ],
      ),
    );
  }

  Widget _buildServicesTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isStandalonePharmacy
                      ? 'Manage Pharmacy Products'
                      : 'Manage Available Services',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddServiceDialog(),
                icon: const Icon(Icons.add),
                label: Text(
                  _isStandalonePharmacy ? 'Add Product' : 'Add Service',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('facility_services')
                .where('facilityId', isEqualTo: currentFacilityId)
                .where('type', isEqualTo: 'service')
                .orderBy('createdAt', descending: true)
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
                      Icon(Icons.error, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('Error loading services: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              final services = snapshot.data?.docs ?? [];

              if (services.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.medical_services,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No services added yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add services to display them to patients',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final service = services[index];
                  final serviceData = service.data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 2,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple.shade100,
                        child: Icon(
                          _getServiceIcon(serviceData['category']),
                          color: Colors.purple.shade700,
                        ),
                      ),
                      title: Text(
                        serviceData['name'] ?? 'Unknown Service',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(serviceData['description'] ?? ''),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  serviceData['category'] ?? 'General',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₦${serviceData['price'] ?? '0'}',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) =>
                            _handleServiceAction(service, value),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(Icons.visibility),
                                SizedBox(width: 8),
                                Text('Toggle Availability'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLaboratoryTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Laboratory Services',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddLaboratoryServiceDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Lab Test'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('facility_services')
                .where('facilityId', isEqualTo: currentFacilityId)
                .where('type', isEqualTo: 'laboratory')
                .orderBy('createdAt', descending: true)
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
                      Icon(Icons.error, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('Error loading lab tests: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              final labTests = snapshot.data?.docs ?? [];

              if (labTests.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.biotech, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No laboratory tests added yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add lab tests to offer them during consultations',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: labTests.length,
                itemBuilder: (context, index) {
                  final labTest = labTests[index];
                  final testData = labTest.data() as Map<String, dynamic>;
                  final isAvailable = testData['isAvailable'] ?? true;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 2,
                    color: isAvailable ? null : Colors.grey[200],
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAvailable
                            ? Colors.blue.shade100
                            : Colors.grey.shade300,
                        child: Icon(
                          Icons.biotech,
                          color: isAvailable
                              ? Colors.blue.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                      title: Text(
                        testData['name'] ?? 'Unknown Test',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isAvailable ? Colors.black : Colors.grey[600],
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? Colors.green[100]
                                  : Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isAvailable ? 'Available' : 'Unavailable',
                              style: TextStyle(
                                color: isAvailable
                                    ? Colors.green[700]
                                    : Colors.red[700],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₦${(testData['price'] ?? 0).toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) =>
                            _handleLaboratoryAction(labTest, value),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  isAvailable
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isAvailable
                                      ? 'Mark Unavailable'
                                      : 'Mark Available',
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
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
    );
  }

  Widget _buildRadiologyTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Radiology Services',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddRadiologyServiceDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Imaging'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('facility_services')
                .where('facilityId', isEqualTo: currentFacilityId)
                .where('type', isEqualTo: 'radiology')
                .orderBy('createdAt', descending: true)
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
                      Icon(Icons.error, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('Error loading imaging services: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              final imagingServices = snapshot.data?.docs ?? [];

              if (imagingServices.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No radiology services added yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add imaging services to offer them during consultations',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: imagingServices.length,
                itemBuilder: (context, index) {
                  final imaging = imagingServices[index];
                  final imagingData = imaging.data() as Map<String, dynamic>;
                  final isAvailable = imagingData['isAvailable'] ?? true;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 2,
                    color: isAvailable ? null : Colors.grey[200],
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAvailable
                            ? Colors.deepPurple.shade100
                            : Colors.grey.shade300,
                        child: Icon(
                          Icons.camera_alt,
                          color: isAvailable
                              ? Colors.deepPurple.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                      title: Text(
                        imagingData['name'] ?? 'Unknown Imaging',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isAvailable ? Colors.black : Colors.grey[600],
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? Colors.green[100]
                                  : Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isAvailable ? 'Available' : 'Unavailable',
                              style: TextStyle(
                                color: isAvailable
                                    ? Colors.green[700]
                                    : Colors.red[700],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₦${(imagingData['price'] ?? 0).toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) =>
                            _handleRadiologyAction(imaging, value),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  isAvailable
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isAvailable
                                      ? 'Mark Unavailable'
                                      : 'Mark Available',
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
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
    );
  }

  Widget _buildItemsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Manage Available Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddItemDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('facility_services')
                .where('facilityId', isEqualTo: currentFacilityId)
                .where('type', isEqualTo: 'item')
                .orderBy('createdAt', descending: true)
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
                      Icon(Icons.error, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('Error loading items: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              final items = snapshot.data?.docs ?? [];

              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No items added yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add items to display them to patients',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final itemData = item.data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 2,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: Icon(
                          _getItemIcon(itemData['category']),
                          color: Colors.orange.shade700,
                        ),
                      ),
                      title: Text(
                        itemData['name'] ?? 'Unknown Item',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(itemData['description'] ?? ''),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Stock: ${itemData['stock'] ?? '0'}',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₦${itemData['price'] ?? '0'}',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) => _handleItemAction(item, value),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'stock',
                            child: Row(
                              children: [
                                Icon(Icons.inventory_2),
                                SizedBox(width: 8),
                                Text('Update Stock'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomersTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            border: Border(bottom: BorderSide(color: Colors.purple.shade200)),
          ),
          child: Row(
            children: [
              Icon(Icons.people_alt, color: Colors.purple.shade700),
              const SizedBox(width: 12),
              Text(
                'Customer Management',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('service_requests')
                .where('facilityId', isEqualTo: currentFacilityId)
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
                      Icon(Icons.error, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('Error loading customers: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              final requests = snapshot.data?.docs ?? [];

              // Extract unique customers from service requests (patients and facilities)
              final Map<String, Map<String, dynamic>> uniqueCustomers = {};
              for (var request in requests) {
                final data = request.data() as Map<String, dynamic>;

                // Check if order is from facility or patient
                final consumerType = data['consumerType'] ?? 'patient';
                final customerId = data['consumerId'] ?? data['patientId'];

                if (customerId != null &&
                    !uniqueCustomers.containsKey(customerId)) {
                  uniqueCustomers[customerId] = {
                    'name':
                        data['consumerName'] ??
                        data['patientName'] ??
                        'Unknown',
                    'email':
                        data['consumerEmail'] ?? data['patientEmail'] ?? 'N/A',
                    'phone':
                        data['consumerPhone'] ?? data['patientPhone'] ?? 'N/A',
                    'type': consumerType,
                    'lastVisit': data['createdAt'],
                  };
                }
              }

              final customerList = uniqueCustomers.entries.toList();

              if (customerList.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_alt, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No customers yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Customers will appear here when they request services',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: customerList.length,
                itemBuilder: (context, index) {
                  final entry = customerList[index];
                  final customerId = entry.key;
                  final customerData = entry.value;

                  // Count requests for this customer
                  final customerRequests = requests.where((req) {
                    final data = req.data() as Map<String, dynamic>;
                    final reqCustomerId =
                        data['consumerId'] ?? data['patientId'];
                    return reqCustomerId == customerId;
                  }).length;

                  final isFacility = customerData['type'] == 'facility';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: isFacility
                            ? Colors.blue.shade100
                            : Colors.purple.shade100,
                        radius: 28,
                        child: Icon(
                          isFacility ? Icons.business : Icons.person,
                          color: isFacility
                              ? Colors.blue.shade700
                              : Colors.purple.shade700,
                          size: 32,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              customerData['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (isFacility)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Text(
                                'B2B',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.phone,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                customerData['phone'] ?? 'N/A',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.email,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  customerData['email'] ?? 'N/A',
                                  style: TextStyle(color: Colors.grey[700]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$customerRequests request(s)',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                      onTap: () => _showCustomerDetails(
                        customerId,
                        customerData,
                        customerRequests,
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCustomerDetails(
    String customerId,
    Map<String, dynamic> customerData,
    int requestCount,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.purple.shade100,
              child: Icon(Icons.person, color: Colors.purple.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                customerData['name'] ?? 'Unknown',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                Icons.phone,
                'Phone',
                customerData['phone'] ?? 'N/A',
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.email,
                'Email',
                customerData['email'] ?? 'N/A',
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.shopping_bag,
                'Total Requests',
                '$requestCount',
              ),
              if (customerData['lastVisit'] != null) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.calendar_today,
                  'Last Visit',
                  _formatDate(customerData['lastVisit']),
                ),
              ],
            ],
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.purple.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Service Requests from Patients',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade700,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('service_requests')
                .where('facilityId', isEqualTo: currentFacilityId)
                .where('status', whereIn: ['pending', 'approved', 'processing'])
                .orderBy('createdAt', descending: true)
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
                      Icon(Icons.error, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('Error loading requests: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              final requests = snapshot.data?.docs ?? [];

              if (requests.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.request_quote,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No service requests yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Patient service requests will appear here',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  final requestData = request.data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 2,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(requestData['status']),
                        child: Icon(
                          _getStatusIcon(requestData['status']),
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        requestData['serviceName'] ?? 'Unknown Service',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                requestData['consumerType'] == 'facility'
                                    ? Icons.business
                                    : Icons.person,
                                size: 14,
                                color: requestData['consumerType'] == 'facility'
                                    ? Colors.blue
                                    : Colors.purple,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${requestData['consumerType'] == 'facility' ? 'Facility' : 'Patient'}: ${requestData['consumerName'] ?? requestData['patientName'] ?? 'Unknown'}',
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                _getStatusIcon(requestData['status']),
                                size: 14,
                                color: _getStatusColor(requestData['status']),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Status: ${requestData['status'] ?? 'pending'}',
                              ),
                            ],
                          ),
                          if (requestData['shippingStatus'] != null &&
                              requestData['shippingStatus'] != 'pending') ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_shipping,
                                  size: 14,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Shipping: ${requestData['shippingStatus']}',
                                ),
                              ],
                            ),
                          ],
                          if (requestData['amount'] != null &&
                              requestData['amount'] > 0) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.attach_money,
                                  size: 14,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '₦${(requestData['amount'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (requestData['trackingNumber'] != null) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.qr_code,
                                  size: 14,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Tracking: ${requestData['trackingNumber']}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                          Text(
                            'Requested: ${_formatDate(requestData['createdAt'])}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) =>
                            _handleRequestAction(request, value),
                        itemBuilder: (context) => [
                          if (requestData['status'] == 'pending') ...[
                            const PopupMenuItem(
                              value: 'approve',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Approve'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'reject',
                              child: Row(
                                children: [
                                  Icon(Icons.cancel, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Reject'),
                                ],
                              ),
                            ),
                            // Cancel option for pending orders within 24 hours
                            if (_canCancelOrder(requestData))
                              const PopupMenuItem(
                                value: 'cancel',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_forever,
                                      color: Colors.orange,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Cancel Order'),
                                  ],
                                ),
                              ),
                          ],
                          if (requestData['status'] == 'approved') ...[
                            const PopupMenuItem(
                              value: 'supply',
                              child: Row(
                                children: [
                                  Icon(Icons.inventory_2, color: Colors.teal),
                                  SizedBox(width: 8),
                                  Text('Mark as Supplied'),
                                ],
                              ),
                            ),
                          ],
                          if (requestData['status'] == 'supplied' ||
                              (requestData['shippingStatus'] != null &&
                                  requestData['shippingStatus'] !=
                                      'pending')) ...[
                            const PopupMenuItem(
                              value: 'ship',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.local_shipping,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Update Shipping'),
                                ],
                              ),
                            ),
                          ],
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('View Details'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddLaboratoryServiceDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Laboratory Test'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Test Name *',
                  hintText: 'e.g., Full Blood Count, Lipid Profile',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (₦) *',
                  hintText: '0.00',
                  prefixText: '₦ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _addLaboratoryService(
              nameController.text,
              priceController.text,
              context,
            ),
            child: const Text('Add Test'),
          ),
        ],
      ),
    );
  }

  void _showAddRadiologyServiceDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Radiology Service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Imaging Name *',
                  hintText: 'e.g., Chest X-Ray, CT Scan',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (₦) *',
                  hintText: '0.00',
                  prefixText: '₦ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _addRadiologyService(
              nameController.text,
              priceController.text,
              context,
            ),
            child: const Text('Add Imaging'),
          ),
        ],
      ),
    );
  }

  void _showAddServiceDialog() {
    // For standalone pharmacy, show inventory selection dialog
    if (_isStandalonePharmacy) {
      _showInventorySelectionDialog();
      return;
    }

    // For other facilities, show manual entry dialog
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    String selectedCategory = 'General';

    final generalCategories = [
      'General',
      'Laboratory',
      'Radiology',
      'Consultation',
      'Surgery',
      'Emergency',
      'Pharmacy',
      'Dental',
      'Physiotherapy',
      'Others',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Service'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Service Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: generalCategories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => selectedCategory = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price (₦) *',
                    hintText: '0.00',
                    prefixText: '₦ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _addService(
                nameController.text,
                descriptionController.text,
                selectedCategory,
                priceController.text,
                context,
              ),
              child: const Text('Add Service'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInventorySelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Products from Inventory',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('pharmacy_inventory')
                      .where('facilityId', isEqualTo: currentFacilityId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No items in inventory',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add items to inventory first',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Filter items - use currentStock field (pharmacy inventory uses currentStock, not quantity)
                    final items = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final currentStock =
                          (data['currentStock'] as num?)?.toInt() ?? 0;
                      return currentStock > 0;
                    }).toList();

                    // Sort by currentStock (ascending) then by name
                    items.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aStock =
                          (aData['currentStock'] as num?)?.toInt() ?? 0;
                      final bStock =
                          (bData['currentStock'] as num?)?.toInt() ?? 0;
                      if (aStock != bStock) {
                        return aStock.compareTo(bStock);
                      }
                      final aName = aData['name'] ?? '';
                      final bName = bData['name'] ?? '';
                      return aName.toString().compareTo(bName.toString());
                    });

                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No items in stock',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'All inventory items are out of stock',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final doc = items[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] ?? 'Unknown';
                        final category = data['category'] ?? 'Uncategorized';
                        final price =
                            (data['price'] as num?)?.toDouble() ?? 0.0;
                        final currentStock =
                            (data['currentStock'] as num?)?.toInt() ?? 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.purple.shade100,
                              child: Icon(
                                Icons.medication,
                                color: Colors.purple.shade700,
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Category: $category'),
                                Text(
                                  'Stock: $currentStock',
                                  style: TextStyle(
                                    color: currentStock < 10
                                        ? Colors.orange
                                        : Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₦${price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _addProductFromInventory(
                              name,
                              category,
                              price,
                              context,
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
        ),
      ),
    );
  }

  Future<void> _addProductFromInventory(
    String name,
    String category,
    double price,
    BuildContext context,
  ) async {
    try {
      // Check if product already exists in services
      final existingProduct = await FirebaseFirestore.instance
          .collection('facility_services')
          .where('facilityId', isEqualTo: currentFacilityId)
          .where('name', isEqualTo: name)
          .get();

      if (existingProduct.docs.isNotEmpty) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$name is already in your online pharmacy services',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Add product to services
      await FirebaseFirestore.instance.collection('facility_services').add({
        'facilityId': currentFacilityId,
        'type': 'service',
        'name': name.trim(),
        'description': '',
        'category': category,
        'price': price,
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $name added to online pharmacy!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding product: $e')));
      }
    }
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    String selectedCategory = 'Medical Supplies';

    final categories = [
      'Medical Supplies',
      'Medications',
      'Equipment',
      'Consumables',
      'Others',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => selectedCategory = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price (₦)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stock Quantity',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _addItem(
                nameController.text,
                descriptionController.text,
                selectedCategory,
                priceController.text,
                stockController.text,
                context,
              ),
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addService(
    String name,
    String description,
    String category,
    String price,
    BuildContext context,
  ) async {
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter service name')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('facility_services').add({
        'facilityId': currentFacilityId,
        'type': 'service',
        'name': name.trim(),
        'description': description.trim(),
        'category': category,
        'price': double.tryParse(price) ?? 0.0,
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Service added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding service: $e')));
      }
    }
  }

  Future<void> _addItem(
    String name,
    String description,
    String category,
    String price,
    String stock,
    BuildContext context,
  ) async {
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter item name')));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('facility_services').add({
        'facilityId': currentFacilityId,
        'type': 'item',
        'name': name.trim(),
        'description': description.trim(),
        'category': category,
        'price': double.tryParse(price) ?? 0.0,
        'stock': int.tryParse(stock) ?? 0,
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Item added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding item: $e')));
      }
    }
  }

  Future<void> _addLaboratoryService(
    String name,
    String price,
    BuildContext context,
  ) async {
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter test name')));
      return;
    }

    if (price.trim().isEmpty || double.tryParse(price) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('facility_services').add({
        'facilityId': currentFacilityId,
        'type': 'laboratory',
        'name': name.trim(),
        'price': double.parse(price),
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Laboratory test added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding lab test: $e')));
      }
    }
  }

  Future<void> _addRadiologyService(
    String name,
    String price,
    BuildContext context,
  ) async {
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter imaging name')),
      );
      return;
    }

    if (price.trim().isEmpty || double.tryParse(price) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('facility_services').add({
        'facilityId': currentFacilityId,
        'type': 'radiology',
        'name': name.trim(),
        'price': double.parse(price),
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Radiology service added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding imaging: $e')));
      }
    }
  }

  void _handleServiceAction(QueryDocumentSnapshot service, String action) {
    switch (action) {
      case 'edit':
        _editService(service);
        break;
      case 'toggle':
        _toggleServiceAvailability(service);
        break;
      case 'delete':
        _deleteService(service);
        break;
    }
  }

  void _handleLaboratoryAction(QueryDocumentSnapshot labTest, String action) {
    switch (action) {
      case 'edit':
        _editLaboratoryService(labTest);
        break;
      case 'toggle':
        _toggleLaboratoryAvailability(labTest);
        break;
      case 'delete':
        _deleteLaboratoryService(labTest);
        break;
    }
  }

  void _handleRadiologyAction(QueryDocumentSnapshot imaging, String action) {
    switch (action) {
      case 'edit':
        _editRadiologyService(imaging);
        break;
      case 'toggle':
        _toggleRadiologyAvailability(imaging);
        break;
      case 'delete':
        _deleteRadiologyService(imaging);
        break;
    }
  }

  void _handleItemAction(QueryDocumentSnapshot item, String action) {
    switch (action) {
      case 'edit':
        _editItem(item);
        break;
      case 'stock':
        _updateStock(item);
        break;
      case 'delete':
        _deleteItem(item);
        break;
    }
  }

  void _handleRequestAction(
    QueryDocumentSnapshot request,
    String action,
  ) async {
    switch (action) {
      case 'approve':
        await _approveRequestWithWalletCheck(request);
        break;
      case 'reject':
        String reason = '';
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('Reject Service Request'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Please provide a reason for rejecting this request:',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    maxLines: 3,
                    onChanged: (val) => reason = val,
                    decoration: const InputDecoration(
                      hintText: 'Enter reason...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (reason.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please provide a reason for rejection',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Reject'),
                ),
              ],
            );
          },
        );
        if (confirmed == true && reason.trim().isNotEmpty) {
          _updateRequestStatus(
            request,
            'rejected',
            rejectionReason: reason.trim(),
          );
        }
        break;
      case 'cancel':
        await _cancelOrderFacility(request);
        break;
      case 'supply':
        await _markAsSuppliedWithPayment(request);
        break;
      case 'ship':
        await _updateShippingStatus(request);
        break;
      case 'complete':
        _updateRequestStatus(request, 'completed');
        break;
      case 'view':
        _showRequestDetails(request);
        break;
    }
  }

  void _editService(QueryDocumentSnapshot service) {
    final serviceData = service.data() as Map<String, dynamic>;
    final nameController = TextEditingController(
      text: serviceData['name'] ?? '',
    );
    final descriptionController = TextEditingController(
      text: serviceData['description'] ?? '',
    );
    final priceController = TextEditingController(
      text: serviceData['price']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Service Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (₦)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await service.reference.update({
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'price': double.tryParse(priceController.text) ?? 0,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Service updated successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating service: $e')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _editItem(QueryDocumentSnapshot item) {
    final itemData = item.data() as Map<String, dynamic>;
    final nameController = TextEditingController(text: itemData['name'] ?? '');
    final descriptionController = TextEditingController(
      text: itemData['description'] ?? '',
    );
    final priceController = TextEditingController(
      text: itemData['price']?.toString() ?? '',
    );
    final stockController = TextEditingController(
      text: itemData['stockQuantity']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (₦)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: stockController,
                decoration: const InputDecoration(
                  labelText: 'Stock Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await item.reference.update({
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'price': double.tryParse(priceController.text) ?? 0,
                  'stockQuantity': int.tryParse(stockController.text) ?? 0,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item updated successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating item: $e')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _toggleServiceAvailability(QueryDocumentSnapshot service) async {
    final serviceData = service.data() as Map<String, dynamic>;
    final currentStatus = serviceData['isAvailable'] ?? true;

    try {
      await service.reference.update({
        'isAvailable': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentStatus ? '✅ Service enabled' : '⛔ Service disabled',
          ),
          backgroundColor: !currentStatus ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating service: $e')));
    }
  }

  void _updateStock(QueryDocumentSnapshot item) {
    final stockController = TextEditingController();
    final itemData = item.data() as Map<String, dynamic>;
    stockController.text = (itemData['stock'] ?? 0).toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Stock - ${itemData['name']}'),
        content: TextField(
          controller: stockController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Stock Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await item.reference.update({
                  'stock': int.tryParse(stockController.text) ?? 0,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Stock updated successfully!'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating stock: $e')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteService(QueryDocumentSnapshot service) {
    final serviceData = service.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text(
          'Are you sure you want to delete "${serviceData['name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await service.reference.delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Service deleted successfully!'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting service: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(QueryDocumentSnapshot item) {
    final itemData = item.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${itemData['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await item.reference.delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Item deleted successfully!'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting item: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _editLaboratoryService(QueryDocumentSnapshot labTest) {
    final testData = labTest.data() as Map<String, dynamic>;
    final nameController = TextEditingController(text: testData['name'] ?? '');
    final priceController = TextEditingController(
      text: testData['price']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Laboratory Test'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Test Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (₦)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await labTest.reference.update({
                  'name': nameController.text.trim(),
                  'price': double.tryParse(priceController.text) ?? 0,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lab test updated successfully'),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating lab test: $e')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _editRadiologyService(QueryDocumentSnapshot imaging) {
    final imagingData = imaging.data() as Map<String, dynamic>;
    final nameController = TextEditingController(
      text: imagingData['name'] ?? '',
    );
    final priceController = TextEditingController(
      text: imagingData['price']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Radiology Service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Imaging Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (₦)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await imaging.reference.update({
                  'name': nameController.text.trim(),
                  'price': double.tryParse(priceController.text) ?? 0,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Imaging service updated successfully'),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating imaging: $e')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _toggleLaboratoryAvailability(QueryDocumentSnapshot labTest) async {
    final testData = labTest.data() as Map<String, dynamic>;
    final currentStatus = testData['isAvailable'] ?? true;

    try {
      await labTest.reference.update({
        'isAvailable': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentStatus ? '✅ Lab test enabled' : '⛔ Lab test disabled',
          ),
          backgroundColor: !currentStatus ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating lab test: $e')));
    }
  }

  void _toggleRadiologyAvailability(QueryDocumentSnapshot imaging) async {
    final imagingData = imaging.data() as Map<String, dynamic>;
    final currentStatus = imagingData['isAvailable'] ?? true;

    try {
      await imaging.reference.update({
        'isAvailable': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentStatus
                ? '✅ Imaging service enabled'
                : '⛔ Imaging service disabled',
          ),
          backgroundColor: !currentStatus ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating imaging: $e')));
    }
  }

  void _deleteLaboratoryService(QueryDocumentSnapshot labTest) {
    final testData = labTest.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Laboratory Test'),
        content: Text('Are you sure you want to delete "${testData['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await labTest.reference.delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Lab test deleted successfully!'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting lab test: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteRadiologyService(QueryDocumentSnapshot imaging) {
    final imagingData = imaging.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Radiology Service'),
        content: Text(
          'Are you sure you want to delete "${imagingData['name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await imaging.reference.delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Imaging service deleted successfully!'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting imaging: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateRequestStatus(
    QueryDocumentSnapshot request,
    String status, {
    String? rejectionReason,
  }) async {
    try {
      final updateData = {
        'status': status,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'statusUpdatedBy': currentFacilityId,
      };
      if (status == 'rejected' &&
          rejectionReason != null &&
          rejectionReason.isNotEmpty) {
        updateData['rejectionReason'] = rejectionReason;
      }
      await request.reference.update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Request $status successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating request: $e')));
    }
  }

  // Approve request with wallet balance check
  Future<void> _approveRequestWithWalletCheck(
    QueryDocumentSnapshot request,
  ) async {
    final requestData = request.data() as Map<String, dynamic>;
    final amount = (requestData['amount'] ?? 0.0) as num;
    final consumerType = requestData['consumerType'] ?? 'patient';
    final consumerId =
        requestData['consumerId'] ?? requestData['patientId'] as String?;

    if (consumerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ ${consumerType == 'facility' ? 'Facility' : 'Patient'} ID not found',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // If there's an amount, check wallet balance
      if (amount > 0) {
        final walletDoc = await FirebaseFirestore.instance
            .collection('wallets')
            .doc(consumerId)
            .get();

        if (!walletDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ ${consumerType == 'facility' ? 'Facility' : 'Patient'} wallet not found. Cannot approve request.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final walletBalance = (walletDoc.data()?['balance'] ?? 0.0) as num;

        if (walletBalance < amount) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ Insufficient wallet balance. The ${consumerType == 'facility' ? 'facility' : 'patient'} needs to fund their wallet before this order can be approved. Required amount: ₦${amount.toStringAsFixed(2)}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }

        // Wallet balance is sufficient, show confirmation
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Approve Request'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The ${consumerType == 'facility' ? 'facility' : 'patient'} has sufficient wallet balance to complete this order.',
                ),
                const SizedBox(height: 12),
                Text(
                  'Order Amount: ₦${amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Payment will be deducted when you mark the order as "Supplied".',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Approve'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
      }

      // Approve the request
      await request.reference.update({
        'status': 'approved',
        'shippingStatus': 'processing',
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': currentFacilityId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Request approved! Mark as supplied when ready.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error approving request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Mark as supplied and process wallet payment
  Future<void> _markAsSuppliedWithPayment(QueryDocumentSnapshot request) async {
    final requestData = request.data() as Map<String, dynamic>;
    final amount = (requestData['amount'] ?? 0.0) as num;
    final consumerType = requestData['consumerType'] ?? 'patient';
    final consumerId =
        requestData['consumerId'] ?? requestData['patientId'] as String?;
    final status = requestData['status'] as String?;

    if (status != 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please approve the request first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (consumerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ ${consumerType == 'facility' ? 'Facility' : 'Patient'} ID not found',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mark as Supplied'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will:'),
              const SizedBox(height: 8),
              if (amount > 0) ...[
                Text(
                  '• Deduct ₦${amount.toStringAsFixed(2)} from ${consumerType == 'facility' ? 'facility' : 'patient'} wallet',
                ),
                Text(
                  '• Credit ₦${amount.toStringAsFixed(2)} to your facility wallet',
                ),
              ],
              const Text('• Update shipping status to "Shipped"'),
              Text(
                '• Notify the ${consumerType == 'facility' ? 'facility' : 'patient'}',
              ),
              const SizedBox(height: 12),
              const Text(
                'Make sure the product/service has been supplied before confirming.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Confirm Supply'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Process wallet payment if amount > 0
      String? transactionId;
      if (amount > 0) {
        // Get consumer wallet (patient or facility)
        final consumerWalletRef = FirebaseFirestore.instance
            .collection('wallets')
            .doc(consumerId);
        final consumerWalletDoc = await consumerWalletRef.get();

        if (!consumerWalletDoc.exists) {
          throw Exception(
            '${consumerType == 'facility' ? 'Facility' : 'Patient'} wallet not found',
          );
        }

        final currentBalance =
            (consumerWalletDoc.data()?['balance'] ?? 0.0) as num;

        if (currentBalance < amount) {
          throw Exception('Insufficient wallet balance');
        }

        // Get facility wallet
        final facilityWalletRef = FirebaseFirestore.instance
            .collection('wallets')
            .doc(currentFacilityId);

        // Create transaction record
        final transactionRef = await FirebaseFirestore.instance
            .collection('wallet_transactions')
            .add({
              'type': 'service_payment',
              'amount': amount.toDouble(),
              'fromUserId': consumerId,
              'toUserId': currentFacilityId,
              'fromUserType': consumerType,
              'toUserType': 'facility',
              'requestId': request.id,
              'serviceName':
                  requestData['serviceName'] ?? requestData['serviceLabel'],
              'status': 'completed',
              'createdAt': FieldValue.serverTimestamp(),
              'completedAt': FieldValue.serverTimestamp(),
            });

        transactionId = transactionRef.id;

        // Service providers (pharmacy/lab/scan) get 100% - No platform fee
        // They already pay subscription fees to the platform

        // Deduct from consumer wallet
        await consumerWalletRef.update({
          'balance': FieldValue.increment(-amount.toDouble()),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Credit facility wallet (ensure it exists first)
        final facilityWalletDoc = await facilityWalletRef.get();
        if (facilityWalletDoc.exists) {
          await facilityWalletRef.update({
            'balance': FieldValue.increment(amount.toDouble()),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await facilityWalletRef.set({
            'balance': amount.toDouble(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Record in consumer's transaction history
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(consumerId)
            .collection('transactions')
            .add({
              'type': 'debit',
              'amount': amount.toDouble(),
              'description':
                  'Payment for ${requestData['serviceName'] ?? requestData['serviceLabel']}',
              'recipientId': currentFacilityId,
              'recipientType': 'facility',
              'transactionId': transactionId,
              'timestamp': FieldValue.serverTimestamp(),
            });

        // Record in facility's transaction history
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(currentFacilityId)
            .collection('transactions')
            .add({
              'type': 'credit',
              'amount': amount.toDouble(),
              'description':
                  'Service payment from ${consumerType == 'facility' ? 'facility' : 'patient'}: ${requestData['serviceName'] ?? requestData['serviceLabel']}',
              'senderId': consumerId,
              'senderType': consumerType,
              'transactionId': transactionId,
              'timestamp': FieldValue.serverTimestamp(),
            });
      }

      // Update request status
      await request.reference.update({
        'status': 'supplied',
        'shippingStatus': 'shipped',
        'paymentStatus': amount > 0 ? 'paid' : 'not_required',
        'transactionId': transactionId,
        'suppliedAt': FieldValue.serverTimestamp(),
        'suppliedBy': currentFacilityId,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            amount > 0
                ? '✅ Supplied! ₦${amount.toStringAsFixed(2)} transferred to your wallet'
                : '✅ Marked as supplied!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error processing supply: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Update shipping status with tracking number
  Future<void> _updateShippingStatus(QueryDocumentSnapshot request) async {
    final requestData = request.data() as Map<String, dynamic>;
    final currentShippingStatus = requestData['shippingStatus'] ?? 'pending';
    final trackingNumberController = TextEditingController(
      text: requestData['trackingNumber'] ?? '',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        String selectedStatus = currentShippingStatus;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Update Shipping Status'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shipping Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('⏳ Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'processing',
                          child: Text('📦 Processing'),
                        ),
                        DropdownMenuItem(
                          value: 'shipped',
                          child: Text('🚚 Shipped'),
                        ),
                        DropdownMenuItem(
                          value: 'delivered',
                          child: Text('✅ Delivered'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => selectedStatus = value!);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: trackingNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Tracking Number (Optional)',
                        hintText: 'e.g., TRK123456789',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_shipping),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'status': selectedStatus,
                      'trackingNumber': trackingNumberController.text.trim(),
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    try {
      final updateData = <String, dynamic>{
        'shippingStatus': result['status'],
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      };

      if (result['trackingNumber'].isNotEmpty) {
        updateData['trackingNumber'] = result['trackingNumber'];
      }

      if (result['status'] == 'delivered') {
        updateData['actualDelivery'] = FieldValue.serverTimestamp();
        updateData['status'] = 'completed';
      }

      await request.reference.update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Shipping status updated to: ${result['status']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error updating shipping: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRequestDetails(QueryDocumentSnapshot request) {
    final requestData = request.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                Icons.medical_services,
                'Service',
                requestData['serviceName'] ?? 'N/A',
              ),
              _buildDetailRow(
                Icons.badge,
                'Patient ID',
                requestData['patientId'] ?? 'N/A',
              ),
              _buildDetailRow(
                Icons.info,
                'Status',
                requestData['status'] ?? 'N/A',
              ),
              _buildDetailRow(
                Icons.calendar_today,
                'Created',
                _formatDate(requestData['createdAt']),
              ),
              if (requestData['notes'] != null)
                _buildDetailRow(Icons.note, 'Notes', requestData['notes']),
              if (requestData['urgency'] != null)
                _buildDetailRow(
                  Icons.priority_high,
                  'Urgency',
                  requestData['urgency'],
                ),
            ],
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

  IconData _getServiceIcon(String? category) {
    switch (category) {
      case 'Laboratory':
        return Icons.biotech;
      case 'Radiology':
        return Icons.camera_alt;
      case 'Consultation':
        return Icons.person;
      case 'Surgery':
        return Icons.healing;
      case 'Emergency':
        return Icons.emergency;
      case 'Pharmacy':
        return Icons.medication;
      case 'Dental':
        return Icons.mood;
      case 'Physiotherapy':
        return Icons.accessibility;
      default:
        return Icons.medical_services;
    }
  }

  IconData _getItemIcon(String? category) {
    switch (category) {
      case 'Medications':
        return Icons.medication;
      case 'Equipment':
        return Icons.medical_information;
      case 'Consumables':
        return Icons.inventory_2;
      default:
        return Icons.inventory;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'approved':
        return Icons.thumb_up;
      case 'completed':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.pending;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else {
        return 'Unknown';
      }

      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  // Order History Tab - Shows supplied/shipped orders
  Widget _buildOrderHistoryTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
          ),
          child: Row(
            children: [
              Icon(Icons.history, color: Colors.blue.shade700, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    Text(
                      'Track orders you\'ve supplied and shipped',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('service_requests')
                .where('facilityId', isEqualTo: currentFacilityId)
                .where('status', whereIn: ['completed'])
                .orderBy('suppliedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading order history: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final orders = snapshot.data?.docs ?? [];

              if (orders.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Order History Yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Orders you\'ve marked as "supplied" will appear here.\nYou can track shipping and delivery status.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final orderData = order.data() as Map<String, dynamic>;

                  return _buildOrderHistoryCard(orderData, order.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderHistoryCard(
    Map<String, dynamic> orderData,
    String orderId,
  ) {
    final patientName =
        orderData['consumerName'] ??
        orderData['patientName'] ??
        'Unknown Patient';
    final patientPhone =
        orderData['consumerPhone'] ?? orderData['patientPhone'] ?? 'N/A';
    final serviceName =
        orderData['serviceName'] ??
        orderData['serviceLabel'] ??
        orderData['serviceType'] ??
        'Unknown Service';
    final amount = (orderData['amount'] ?? 0.0) as num;
    final shippingStatus = orderData['shippingStatus'] ?? 'pending';
    final trackingNumber = orderData['trackingNumber'] as String?;
    final suppliedAt = orderData['suppliedAt'] as Timestamp?;
    final statusUpdatedAt = orderData['statusUpdatedAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getShippingStatusColor(shippingStatus).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => _showOrderHistoryDetails(orderData, orderId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Patient and Service
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    radius: 24,
                    child: Icon(
                      Icons.person,
                      color: Colors.blue.shade700,
                      size: 28,
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
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              patientPhone,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (amount > 0)
                    Text(
                      '₦${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Service name
              Row(
                children: [
                  Icon(
                    Icons.medical_services,
                    size: 16,
                    color: Colors.purple.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      serviceName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Shipping status
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _getShippingStatusColor(
                    shippingStatus,
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getShippingStatusColor(
                      shippingStatus,
                    ).withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getShippingStatusIcon(shippingStatus),
                      size: 18,
                      color: _getShippingStatusColor(shippingStatus),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Status: ${shippingStatus.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _getShippingStatusColor(shippingStatus),
                      ),
                    ),
                  ],
                ),
              ),

              // Tracking number
              if (trackingNumber != null && trackingNumber.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.qr_code_2,
                        color: Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tracking Number',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            trackingNumber,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Timestamps
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    suppliedAt != null
                        ? 'Supplied: ${_formatTimestamp(suppliedAt)}'
                        : 'Supply date unknown',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              if (statusUpdatedAt != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.update, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Updated: ${_formatTimestamp(statusUpdatedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],

              // Quick action button (only show if not completed/delivered)
              if (orderData['status'] != 'completed') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _updateShippingStatusFromHistory(orderId, orderData),
                    icon: const Icon(Icons.local_shipping, size: 18),
                    label: const Text('Update Shipping Status'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade300),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getShippingStatusColor(String status) {
    switch (status) {
      case 'shipped':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getShippingStatusIcon(String status) {
    switch (status) {
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.done_all;
      case 'processing':
        return Icons.inventory;
      default:
        return Icons.pending;
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showOrderHistoryDetails(
    Map<String, dynamic> orderData,
    String orderId,
  ) {
    final patientName = orderData['patientName'] ?? 'Unknown';
    final patientPhone = orderData['patientPhone'] ?? 'N/A';
    final patientEmail = orderData['patientEmail'] ?? 'N/A';
    final serviceName =
        orderData['serviceName'] ?? orderData['serviceLabel'] ?? 'Unknown';
    final amount = (orderData['amount'] ?? 0.0) as num;
    final shippingStatus = orderData['shippingStatus'] ?? 'pending';
    final trackingNumber = orderData['trackingNumber'] ?? 'N/A';
    final paymentStatus = orderData['paymentStatus'] ?? 'pending';
    final notes = orderData['notes'] ?? 'No notes';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Order Details', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailSection('Patient Information', [
                _buildDetailRow(Icons.person, 'Name', patientName),
                _buildDetailRow(Icons.phone, 'Phone', patientPhone),
                _buildDetailRow(Icons.email, 'Email', patientEmail),
              ]),
              const SizedBox(height: 16),
              _buildDetailSection('Order Information', [
                _buildDetailRow(Icons.medical_services, 'Service', serviceName),
                _buildDetailRow(
                  Icons.attach_money,
                  'Amount',
                  '₦${amount.toStringAsFixed(2)}',
                ),
                _buildDetailRow(
                  Icons.payment,
                  'Payment',
                  paymentStatus.toUpperCase(),
                ),
              ]),
              const SizedBox(height: 16),
              _buildDetailSection('Shipping Information', [
                _buildDetailRow(
                  Icons.local_shipping,
                  'Status',
                  shippingStatus.toUpperCase(),
                ),
                _buildDetailRow(Icons.qr_code_2, 'Tracking', trackingNumber),
              ]),
              const SizedBox(height: 16),
              _buildDetailSection('Additional Notes', [
                _buildDetailRow(Icons.note, 'Notes', notes),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _updateShippingStatusFromHistory(orderId, orderData);
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Update Status'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Future<void> _updateShippingStatusFromHistory(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    final currentShippingStatus = orderData['shippingStatus'] ?? 'pending';
    final trackingNumberController = TextEditingController(
      text: orderData['trackingNumber'] ?? '',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        String selectedStatus = currentShippingStatus;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Update Shipping Status'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shipping Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('⏳ Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'processing',
                          child: Text('📦 Processing'),
                        ),
                        DropdownMenuItem(
                          value: 'shipped',
                          child: Text('🚚 Shipped'),
                        ),
                        DropdownMenuItem(
                          value: 'delivered',
                          child: Text('✅ Delivered'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => selectedStatus = value!);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: trackingNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Tracking Number (Optional)',
                        hintText: 'e.g., TRK123456789',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_shipping),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'status': selectedStatus,
                      'trackingNumber': trackingNumberController.text.trim(),
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    try {
      final updateData = <String, dynamic>{
        'shippingStatus': result['status'],
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      };

      if (result['trackingNumber'].isNotEmpty) {
        updateData['trackingNumber'] = result['trackingNumber'];
      }

      if (result['status'] == 'delivered') {
        updateData['actualDelivery'] = FieldValue.serverTimestamp();
        updateData['status'] = 'completed';
      }

      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(orderId)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Shipping status updated to: ${result['status']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error updating shipping: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Check if order can be cancelled (pending status + within 24 hours)
  bool _canCancelOrder(Map<String, dynamic> orderData) {
    final status = orderData['status'] ?? '';
    if (status != 'pending') return false;

    final createdAt = orderData['createdAt'] as Timestamp?;
    if (createdAt == null) return false;

    final orderTime = createdAt.toDate();
    final now = DateTime.now();
    final hoursDiff = now.difference(orderTime).inHours;

    return hoursDiff < 24;
  }

  // Cancel order from facility side
  Future<void> _cancelOrderFacility(QueryDocumentSnapshot request) async {
    final orderData = request.data() as Map<String, dynamic>;
    final orderId = request.id;

    // Confirm cancellation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text(
          'Are you sure you want to cancel this order? If payment was made, it will be refunded to the patient\'s wallet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final batch = FirebaseFirestore.instance.batch();

      // Update order status to cancelled
      final orderRef = FirebaseFirestore.instance
          .collection('service_requests')
          .doc(orderId);

      batch.update(orderRef, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': currentFacilityId,
        'cancellationReason': 'Cancelled by facility',
      });

      // Process refund if payment was made
      final paymentStatus = orderData['paymentStatus'] ?? '';
      final amount = (orderData['amount'] ?? 0.0) as num;
      final patientId = orderData['patientId'] as String?;

      if (paymentStatus == 'paid' && amount > 0 && patientId != null) {
        // Refund to patient wallet
        final walletRef = FirebaseFirestore.instance
            .collection('wallets')
            .doc(patientId);

        batch.update(walletRef, {
          'balance': FieldValue.increment(amount.toDouble()),
        });

        // Add refund transaction to patient wallet
        final refundTransactionRef = walletRef.collection('transactions').doc();

        batch.set(refundTransactionRef, {
          'type': 'credit',
          'amount': amount.toDouble(),
          'description':
              'Refund for cancelled order: ${orderData['serviceName'] ?? 'Service'}',
          'timestamp': FieldValue.serverTimestamp(),
          'relatedOrderId': orderId,
          'status': 'completed',
        });

        // Reverse facility payment - deduct from facility wallet
        final facilityWalletRef = FirebaseFirestore.instance
            .collection('wallets')
            .doc(currentFacilityId);

        // Service providers get 100% - No platform fee on cancellation refunds
        // Reverse the full amount from facility wallet

        batch.update(facilityWalletRef, {
          'balance': FieldValue.increment(-amount.toDouble()),
        });

        // Add reversal transaction to facility wallet
        final facilityTransactionRef = facilityWalletRef
            .collection('transactions')
            .doc();

        batch.set(facilityTransactionRef, {
          'type': 'debit',
          'amount': amount.toDouble(),
          'description':
              'Order cancellation refund: ${orderData['serviceName'] ?? 'Service'}',
          'timestamp': FieldValue.serverTimestamp(),
          'relatedOrderId': orderId,
          'status': 'completed',
        });

        // Create notification for patient
        final notificationRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc();

        batch.set(notificationRef, {
          'recipientId': patientId,
          'title': 'Order Cancelled',
          'body':
              'Your order for ${orderData['serviceName'] ?? 'Service'} has been cancelled. Refund has been processed.',
          'type': 'order_cancelled',
          'orderId': orderId,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      // Commit batch
      await batch.commit();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              paymentStatus == 'paid'
                  ? '✅ Order cancelled successfully. ₦${amount.toStringAsFixed(2)} refunded to patient.'
                  : '✅ Order cancelled successfully.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error cancelling order: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
