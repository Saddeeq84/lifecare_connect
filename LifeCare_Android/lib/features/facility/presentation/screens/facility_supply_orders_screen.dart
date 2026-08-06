import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class FacilitySupplyOrdersScreen extends StatefulWidget {
  const FacilitySupplyOrdersScreen({super.key});

  @override
  State<FacilitySupplyOrdersScreen> createState() =>
      _FacilitySupplyOrdersScreenState();
}

class _FacilitySupplyOrdersScreenState
    extends State<FacilitySupplyOrdersScreen> {
  String _selectedFilter =
      'all'; // all, pending, approved, supplied, shipped, delivered, rejected

  Stream<QuerySnapshot> _getOrdersStream(String facilityId) {
    var query = FirebaseFirestore.instance
        .collection('service_requests')
        .where('consumerId', isEqualTo: facilityId)
        .where('consumerType', isEqualTo: 'facility')
        .orderBy('createdAt', descending: true);

    return query.snapshots();
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.teal,
            ),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedFilter = value);
        },
        selectedColor: Colors.teal,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.teal,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'supplied':
        return Colors.purple;
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'approved':
        return Icons.check_circle;
      case 'supplied':
        return Icons.inventory_2;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
      case 'completed':
        return Icons.done_all;
      case 'rejected':
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Future<void> _cancelOrder(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    // Check if order is still pending
    if (orderData['status'] != 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Only pending orders can be cancelled'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if within 24 hours
    final createdAt = (orderData['createdAt'] as Timestamp?)?.toDate();
    if (createdAt != null) {
      final hoursSinceCreation = DateTime.now().difference(createdAt).inHours;
      if (hoursSinceCreation > 24) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Orders can only be cancelled within 24 hours'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text(
          'Are you sure you want to cancel this order?\n\n'
          'Amount: ₦${(orderData['amount'] ?? 0).toStringAsFixed(2)}\n\n'
          'The amount will be refunded to your facility wallet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final amount = (orderData['amount'] ?? 0).toDouble();
      final providerId = orderData['providerId'] ?? orderData['facilityId'];
      final consumerId = orderData['consumerId'];

      if (providerId == null || consumerId == null) {
        throw Exception('Invalid order data');
      }

      // Start batch write
      final batch = FirebaseFirestore.instance.batch();

      // Update order status
      batch.update(
        FirebaseFirestore.instance.collection('service_requests').doc(orderId),
        {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Refund to facility wallet (100% refund)
      final facilityWalletRef = FirebaseFirestore.instance
          .collection('wallets')
          .doc(consumerId);

      batch.update(facilityWalletRef, {
        'balance': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add refund transaction to facility wallet
      batch.set(facilityWalletRef.collection('transactions').doc(), {
        'type': 'refund',
        'amount': amount,
        'description': 'Refund for cancelled order #${orderId.substring(0, 8)}',
        'orderId': orderId,
        'timestamp': FieldValue.serverTimestamp(),
        'balanceAfter': FieldValue.increment(amount),
      });

      // Reverse from provider wallet (100% reversal)
      final providerWalletRef = FirebaseFirestore.instance
          .collection('wallets')
          .doc(providerId);

      batch.update(providerWalletRef, {
        'balance': FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add reversal transaction to provider wallet
      batch.set(providerWalletRef.collection('transactions').doc(), {
        'type': 'reversal',
        'amount': -amount,
        'description': 'Order cancelled - #${orderId.substring(0, 8)}',
        'orderId': orderId,
        'timestamp': FieldValue.serverTimestamp(),
        'balanceAfter': FieldValue.increment(-amount),
      });

      // Commit batch
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Order cancelled and refunded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
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

  void _showOrderDetails(String orderId, Map<String, dynamic> orderData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          final items = List<Map<String, dynamic>>.from(
            orderData['items'] ?? [],
          );
          final status = orderData['status'] ?? 'unknown';
          final shippingStatus = orderData['shippingStatus'] ?? 'pending';
          final amount = (orderData['amount'] ?? 0).toDouble();
          final providerName =
              orderData['providerName'] ??
              orderData['facilityName'] ??
              'Provider';
          final createdAt = (orderData['createdAt'] as Timestamp?)?.toDate();
          final canCancel =
              status == 'pending' &&
              createdAt != null &&
              DateTime.now().difference(createdAt).inHours <= 24;

          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Order Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _getStatusColor(status)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getStatusIcon(status),
                            color: _getStatusColor(status),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(status),
                            ),
                          ),
                          if (shippingStatus != 'pending') ...[
                            const SizedBox(width: 8),
                            const Text('•'),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.local_shipping,
                              size: 16,
                              color: _getStatusColor(shippingStatus),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              shippingStatus.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                color: _getStatusColor(shippingStatus),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Order info
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Provider info
                    _buildInfoCard('Provider Information', Icons.store, [
                      _buildInfoRow('Provider', providerName),
                      _buildInfoRow('Order ID', '#${orderId.substring(0, 8)}'),
                      if (createdAt != null)
                        _buildInfoRow(
                          'Order Date',
                          DateFormat(
                            'MMM dd, yyyy • hh:mm a',
                          ).format(createdAt),
                        ),
                    ]),

                    const SizedBox(height: 16),

                    // Items
                    _buildInfoCard(
                      'Items Ordered',
                      Icons.shopping_cart,
                      items.map((item) {
                        final qty = item['quantity'] ?? 0;
                        final price = (item['price'] ?? 0) as num;
                        final subtotal = (item['subtotal'] ?? 0) as num;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] ?? 'Unknown Item',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₦${price.toStringAsFixed(2)} × $qty',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Subtotal: ₦${subtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Total
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₦${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (canCancel) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _cancelOrder(orderId, orderData);
                          },
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text('Cancel Order'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Supply Orders'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Please log in to view your orders')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Supply Orders'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all', Icons.list_alt),
                  _buildFilterChip('Pending', 'pending', Icons.pending),
                  _buildFilterChip('Approved', 'approved', Icons.check_circle),
                  _buildFilterChip('Supplied', 'supplied', Icons.inventory_2),
                  _buildFilterChip('Shipped', 'shipped', Icons.local_shipping),
                  _buildFilterChip('Delivered', 'delivered', Icons.done_all),
                  _buildFilterChip('Cancelled', 'cancelled', Icons.cancel),
                ],
              ),
            ),
          ),

          // Orders list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getOrdersStream(user.uid),
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
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text('Error loading orders: ${snapshot.error}'),
                        ],
                      ),
                    ),
                  );
                }

                final allOrders = snapshot.data?.docs ?? [];

                // Filter orders
                final filteredOrders = _selectedFilter == 'all'
                    ? allOrders
                    : allOrders.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (_selectedFilter == 'shipped') {
                          return data['shippingStatus'] == 'shipped';
                        } else if (_selectedFilter == 'delivered') {
                          return data['shippingStatus'] == 'delivered' ||
                              data['status'] == 'completed';
                        } else if (_selectedFilter == 'cancelled') {
                          return data['status'] == 'cancelled';
                        }
                        return data['status'] == _selectedFilter;
                      }).toList();

                if (filteredOrders.isEmpty) {
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
                            _selectedFilter == 'all'
                                ? 'No Supply Orders Yet'
                                : 'No ${_selectedFilter.toUpperCase()} Orders',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedFilter == 'all'
                                ? 'Your supply orders will appear here'
                                : 'You don\'t have any $_selectedFilter orders',
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
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    final orderData = order.data() as Map<String, dynamic>;
                    final orderId = order.id;
                    final status = orderData['status'] ?? 'unknown';
                    final shippingStatus =
                        orderData['shippingStatus'] ?? 'pending';
                    final amount = (orderData['amount'] ?? 0).toDouble();
                    final providerName =
                        orderData['providerName'] ??
                        orderData['facilityName'] ??
                        'Provider';
                    final createdAt = (orderData['createdAt'] as Timestamp?)
                        ?.toDate();
                    final items = List<Map<String, dynamic>>.from(
                      orderData['items'] ?? [],
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () => _showOrderDetails(orderId, orderData),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          providerName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Order #${orderId.substring(0, 8)}',
                                          style: TextStyle(
                                            fontSize: 12,
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
                                      color: _getStatusColor(
                                        status,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getStatusIcon(status),
                                          size: 14,
                                          color: _getStatusColor(status),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _getStatusColor(status),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              // Items summary
                              Row(
                                children: [
                                  Icon(
                                    Icons.shopping_cart,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${items.length} item${items.length != 1 ? 's' : ''}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    createdAt != null
                                        ? DateFormat(
                                            'MMM dd, yyyy',
                                          ).format(createdAt)
                                        : 'Unknown',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),

                              if (shippingStatus != 'pending') ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.local_shipping,
                                      size: 16,
                                      color: _getStatusColor(shippingStatus),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Shipping: ${shippingStatus.toUpperCase()}',
                                      style: TextStyle(
                                        color: _getStatusColor(shippingStatus),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 12),

                              // Amount
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Amount:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    '₦${amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }
}
