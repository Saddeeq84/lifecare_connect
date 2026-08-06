import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'patient_service_request_main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientMyOrdersScreen extends StatefulWidget {
  final String? userId;
  const PatientMyOrdersScreen({super.key, this.userId});

  @override
  State<PatientMyOrdersScreen> createState() => _PatientMyOrdersScreenState();
}

class _PatientMyOrdersScreenState extends State<PatientMyOrdersScreen> {
  String _selectedFilter =
      'all'; // all, pending, approved, supplied, delivered, completed, rejected
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeUserId();
  }

  Future<void> _initializeUserId() async {
    // Get user ID from parameter, Firebase Auth, or SharedPreferences
    String? userId = widget.userId;

    if (userId == null || userId.isEmpty) {
      userId = FirebaseAuth.instance.currentUser?.uid;
    }

    if (userId == null || userId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('user_id');
    }

    if (mounted) {
      setState(() {
        _currentUserId = userId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Please log in to view your orders')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
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
                  _buildFilterChip('Rejected', 'rejected', Icons.cancel),
                ],
              ),
            ),
          ),

          // Orders list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getOrdersStream(_currentUserId!),
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

                // Filter orders based on selected filter
                final filteredOrders = _selectedFilter == 'all'
                    ? allOrders
                    : allOrders.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (_selectedFilter == 'shipped') {
                          return data['shippingStatus'] == 'shipped';
                        } else if (_selectedFilter == 'delivered') {
                          return data['shippingStatus'] == 'delivered' ||
                              data['status'] == 'completed';
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
                            Icons.shopping_bag_outlined,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _selectedFilter == 'all'
                                ? 'No Orders Yet'
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
                                ? 'Your service requests will appear here'
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

                    return _buildOrderCard(orderData, order.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PatientServiceRequestMainScreen(),
            ),
          );
        },
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Place New Order'),
      ),
    );
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
          setState(() {
            _selectedFilter = value;
          });
        },
        selectedColor: Colors.teal,
        checkmarkColor: Colors.white,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.teal,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? Colors.teal : Colors.grey.shade300,
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getOrdersStream(String userId) {
    return FirebaseFirestore.instance
        .collection('service_requests')
        .where('patientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Widget _buildOrderCard(Map<String, dynamic> orderData, String orderId) {
    final status = orderData['status'] ?? 'pending';
    final shippingStatus = orderData['shippingStatus'] ?? 'pending';
    final amount = (orderData['amount'] ?? 0.0) as num;
    final serviceName =
        orderData['serviceName'] ??
        orderData['serviceLabel'] ??
        'Unknown Service';
    final facilityName = orderData['facilityName'] ?? 'Unknown Facility';
    final createdAt = orderData['createdAt'] as Timestamp?;
    final trackingNumber = orderData['trackingNumber'] as String?;
    final paymentStatus = orderData['paymentStatus'] ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(status).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => _showOrderDetails(orderData, orderId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Service name and amount
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.store,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                facilityName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (amount > 0) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₦${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getPaymentStatusColor(
                              paymentStatus,
                            ).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            paymentStatus == 'paid' ? 'Paid' : 'Unpaid',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getPaymentStatusColor(paymentStatus),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Status chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusChip(
                    _getStatusIcon(status),
                    status.toUpperCase(),
                    _getStatusColor(status),
                  ),
                  if (shippingStatus != 'pending') ...[
                    _buildStatusChip(
                      _getShippingIcon(shippingStatus),
                      shippingStatus.toUpperCase(),
                      _getShippingColor(shippingStatus),
                    ),
                  ],
                ],
              ),

              // Tracking number
              if (trackingNumber != null && trackingNumber.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
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
                        size: 20,
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
                              fontSize: 14,
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

              // Date
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    createdAt != null
                        ? 'Ordered: ${DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt.toDate())}'
                        : 'Date unknown',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),

              // Cancel button for pending orders within 24 hours
              if (_canCancelOrder(orderData)) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelOrder(orderId, orderData),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Cancel Order'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildStatusChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> orderData, String orderId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final serviceName =
            orderData['serviceName'] ??
            orderData['serviceLabel'] ??
            'Unknown Service';
        final facilityName = orderData['facilityName'] ?? 'Unknown Facility';
        final status = orderData['status'] ?? 'pending';
        final shippingStatus = orderData['shippingStatus'] ?? 'pending';
        final amount = (orderData['amount'] ?? 0.0) as num;
        final description = orderData['description'] ?? 'No description';
        final paymentStatus = orderData['paymentStatus'] ?? 'pending';
        final trackingNumber = orderData['trackingNumber'] as String?;
        final createdAt = orderData['createdAt'] as Timestamp?;
        final approvedAt = orderData['approvedAt'] as Timestamp?;
        final suppliedAt = orderData['suppliedAt'] as Timestamp?;
        final actualDelivery = orderData['actualDelivery'] as Timestamp?;

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order Details',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Order ID: $orderId',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 24),

                  // Service info card
                  _buildDetailCard(
                    title: 'Service Information',
                    icon: Icons.medical_services,
                    iconColor: Colors.teal,
                    children: [
                      _buildDetailRow('Service', serviceName),
                      _buildDetailRow('Facility', facilityName),
                      _buildDetailRow('Description', description),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Payment info card
                  if (amount > 0) ...[
                    _buildDetailCard(
                      title: 'Payment Information',
                      icon: Icons.payment,
                      iconColor: Colors.green,
                      children: [
                        _buildDetailRow(
                          'Amount',
                          '₦${amount.toStringAsFixed(2)}',
                        ),
                        _buildDetailRow('Payment Method', 'Wallet'),
                        _buildDetailRow(
                          'Payment Status',
                          paymentStatus == 'paid' ? '✅ Paid' : '⏳ Pending',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Shipping info card
                  _buildDetailCard(
                    title: 'Shipping & Tracking',
                    icon: Icons.local_shipping,
                    iconColor: Colors.blue,
                    children: [
                      _buildDetailRow(
                        'Shipping Status',
                        shippingStatus.toUpperCase(),
                      ),
                      if (trackingNumber != null)
                        _buildDetailRow('Tracking Number', trackingNumber),
                      _buildDetailRow(
                        'Shipping Method',
                        orderData['shippingMethod'] ?? 'Standard Delivery',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Timeline card
                  _buildDetailCard(
                    title: 'Order Timeline',
                    icon: Icons.timeline,
                    iconColor: Colors.orange,
                    children: [
                      if (createdAt != null)
                        _buildDetailRow(
                          '📝 Ordered',
                          DateFormat(
                            'MMM dd, yyyy • hh:mm a',
                          ).format(createdAt.toDate()),
                        ),
                      if (approvedAt != null)
                        _buildDetailRow(
                          '✅ Approved',
                          DateFormat(
                            'MMM dd, yyyy • hh:mm a',
                          ).format(approvedAt.toDate()),
                        ),
                      if (suppliedAt != null)
                        _buildDetailRow(
                          '📦 Supplied',
                          DateFormat(
                            'MMM dd, yyyy • hh:mm a',
                          ).format(suppliedAt.toDate()),
                        ),
                      if (actualDelivery != null)
                        _buildDetailRow(
                          '🎉 Delivered',
                          DateFormat(
                            'MMM dd, yyyy • hh:mm a',
                          ).format(actualDelivery.toDate()),
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Contact facility button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Navigate to chat with facility
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Contact facility feature coming soon!',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat),
                      label: const Text('Contact Facility'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
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
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.blue;
      case 'supplied':
        return Colors.teal;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  Color _getShippingColor(String? status) {
    switch (status) {
      case 'processing':
        return Colors.orange;
      case 'shipped':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getPaymentStatusColor(String? status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'supplied':
        return Icons.inventory_2;
      case 'completed':
        return Icons.done_all;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.pending;
    }
  }

  IconData _getShippingIcon(String? status) {
    switch (status) {
      case 'processing':
        return Icons.inventory;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.where_to_vote;
      default:
        return Icons.hourglass_empty;
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

  // Cancel order method
  Future<void> _cancelOrder(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    // Get user ID from Firebase Auth or SharedPreferences (phone-authenticated patients)
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    // Confirm cancellation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text(
          'Are you sure you want to cancel this order? If payment was made, it will be refunded to your wallet.',
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
        'cancelledBy': userId,
        'cancellationReason': 'Cancelled by patient',
      });

      // Process refund if payment was made
      final paymentStatus = orderData['paymentStatus'] ?? '';
      final amount = (orderData['amount'] ?? 0.0) as num;

      if (paymentStatus == 'paid' && amount > 0) {
        // Refund to patient wallet
        final walletRef = FirebaseFirestore.instance
            .collection('wallets')
            .doc(userId);

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
        final facilityId = orderData['facilityId'] as String?;
        if (facilityId != null) {
          final facilityWalletRef = FirebaseFirestore.instance
              .collection('wallets')
              .doc(facilityId);

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
        }
      }

      // Create notification for facility
      final facilityId = orderData['facilityId'] as String?;
      if (facilityId != null) {
        final notificationRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc();

        batch.set(notificationRef, {
          'recipientId': facilityId,
          'title': 'Order Cancelled',
          'body':
              'Patient cancelled order for: ${orderData['serviceName'] ?? 'Service'}',
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
                  ? '✅ Order cancelled successfully. ₦${amount.toStringAsFixed(2)} refunded to your wallet.'
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
