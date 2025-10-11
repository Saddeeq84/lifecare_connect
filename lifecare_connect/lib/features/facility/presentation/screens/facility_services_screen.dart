// lib/screens/facilityscreen/facility_services_screen.dart

// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FacilityServicesScreen extends StatefulWidget {
  const FacilityServicesScreen({super.key});

  @override
  State<FacilityServicesScreen> createState() => _FacilityServicesScreenState();
}

class _FacilityServicesScreenState extends State<FacilityServicesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final String currentFacilityId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
          tabs: const [
            Tab(icon: Icon(Icons.medical_services), text: 'Services'),
            Tab(icon: Icon(Icons.inventory), text: 'Items'),
            Tab(icon: Icon(Icons.request_quote), text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildServicesTab(), _buildItemsTab(), _buildRequestsTab()],
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
                  'Manage Available Services',
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
                label: const Text('Add Service'),
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
                          Text(
                            'Patient ID: ${requestData['patientId'] ?? 'Unknown'}',
                          ),
                          Text('Status: ${requestData['status'] ?? 'pending'}'),
                          if (requestData['notes'] != null)
                            Text('Notes: ${requestData['notes']}'),
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
                                  Icon(Icons.check, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Approve'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'reject',
                              child: Row(
                                children: [
                                  Icon(Icons.close, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Reject'),
                                ],
                              ),
                            ),
                          ],
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility),
                                SizedBox(width: 8),
                                Text('View Details'),
                              ],
                            ),
                          ),
                          if (requestData['status'] == 'approved') ...[
                            const PopupMenuItem(
                              value: 'complete',
                              child: Row(
                                children: [
                                  Icon(Icons.done, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Mark Complete'),
                                ],
                              ),
                            ),
                          ],
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

  void _showAddServiceDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    String selectedCategory = 'General';

    final categories = [
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
                  initialValue: selectedCategory,
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
                  initialValue: selectedCategory,
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
        _updateRequestStatus(request, 'approved');
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
              _buildDetailRow('Service', requestData['serviceName'] ?? 'N/A'),
              _buildDetailRow('Patient ID', requestData['patientId'] ?? 'N/A'),
              _buildDetailRow('Status', requestData['status'] ?? 'N/A'),
              _buildDetailRow('Created', _formatDate(requestData['createdAt'])),
              if (requestData['notes'] != null)
                _buildDetailRow('Notes', requestData['notes']),
              if (requestData['urgency'] != null)
                _buildDetailRow('Urgency', requestData['urgency']),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
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
}
