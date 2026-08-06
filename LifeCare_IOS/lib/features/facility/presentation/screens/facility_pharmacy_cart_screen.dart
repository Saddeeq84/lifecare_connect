// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FacilityPharmacyCartScreen extends StatefulWidget {
  final String facilityId; // Provider pharmacy ID
  final Map<String, dynamic> facilityData; // Provider pharmacy data

  const FacilityPharmacyCartScreen({
    super.key,
    required this.facilityId,
    required this.facilityData,
  });

  @override
  State<FacilityPharmacyCartScreen> createState() =>
      _FacilityPharmacyCartScreenState();
}

class _FacilityPharmacyCartScreenState
    extends State<FacilityPharmacyCartScreen> {
  final Map<String, int> _cart = {}; // productId -> quantity
  final Map<String, Map<String, dynamic>> _products =
      {}; // productId -> product data
  bool _isLoading = false;
  double _walletBalance = 0.0;
  String? _consumerFacilityId; // The ordering facility ID
  String? _consumerFacilityName;

  @override
  void initState() {
    super.initState();
    _loadFacilityInfo();
  }

  Future<void> _loadFacilityInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get ordering facility info
      final facilityDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (facilityDoc.exists) {
        final data = facilityDoc.data()!;
        setState(() {
          _consumerFacilityId = user.uid;
          _consumerFacilityName =
              data['facilityName'] ?? data['name'] ?? 'Unknown Facility';
        });

        // Load facility wallet balance
        await _loadWalletBalance();
      }
    } catch (e) {
      debugPrint('Error loading facility info: $e');
    }
  }

  Future<void> _loadWalletBalance() async {
    if (_consumerFacilityId == null) return;

    try {
      final walletDoc = await FirebaseFirestore.instance
          .collection('wallets')
          .doc(_consumerFacilityId)
          .get();

      if (walletDoc.exists) {
        setState(() {
          _walletBalance = (walletDoc.data()?['balance'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {
      debugPrint('Error loading wallet balance: $e');
    }
  }

  double get _cartTotal {
    double total = 0.0;
    _cart.forEach((productId, quantity) {
      final product = _products[productId];
      if (product != null) {
        final price = (product['price'] ?? 0.0) as num;
        total += price.toDouble() * quantity;
      }
    });
    return total;
  }

  int get _cartItemCount {
    return _cart.values.fold(0, (sum, quantity) => sum + quantity);
  }

  void _addToCart(String productId, Map<String, dynamic> productData) {
    setState(() {
      _cart[productId] = (_cart[productId] ?? 0) + 1;
      _products[productId] = productData;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${productData['name']} added to cart'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removeFromCart(String productId) {
    setState(() {
      if (_cart[productId] != null && _cart[productId]! > 1) {
        _cart[productId] = _cart[productId]! - 1;
      } else {
        _cart.remove(productId);
        _products.remove(productId);
      }
    });
  }

  Future<void> _submitOrder() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Your cart is empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_consumerFacilityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Facility information not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final total = _cartTotal;

    // Check wallet balance
    if (_walletBalance < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Insufficient balance. Required: ₦${total.toStringAsFixed(2)}, Available: ₦${_walletBalance.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Provider: ${widget.facilityData['facilityName'] ?? widget.facilityData['name']}',
            ),
            const SizedBox(height: 8),
            Text('Total Items: $_cartItemCount'),
            const SizedBox(height: 8),
            Text(
              'Total Amount: ₦${total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text('Wallet Balance: ₦${_walletBalance.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text(
              'Payment will be held until items are supplied.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
            child: const Text('Place Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // Prepare items array
      final List<Map<String, dynamic>> items = [];
      _cart.forEach((productId, quantity) {
        final product = _products[productId]!;
        items.add({
          'productId': productId,
          'name': product['name'],
          'category': product['category'] ?? 'General',
          'quantity': quantity,
          'price': (product['price'] ?? 0.0) as num,
          'subtotal': ((product['price'] ?? 0.0) as num) * quantity,
        });
      });

      // Create service request order
      await FirebaseFirestore.instance.collection('service_requests').add({
        // Consumer (ordering facility) info
        'consumerType': 'facility',
        'consumerId': _consumerFacilityId,
        'consumerName': _consumerFacilityName,

        // Provider (pharmacy) info
        'providerId': widget.facilityId,
        'providerType': 'Pharmacy',
        'providerName':
            widget.facilityData['facilityName'] ?? widget.facilityData['name'],
        'facilityId': widget.facilityId,
        'facilityName':
            widget.facilityData['facilityName'] ?? widget.facilityData['name'],

        // Order details
        'serviceType': 'Pharmacy',
        'orderType': 'facility-to-provider',
        'items': items,
        'amount': total,
        'status': 'pending',
        'paymentStatus': 'pending',
        'paymentHeld': true,
        'shippingStatus': 'pending',

        // Timestamps
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to provider
      await _sendOrderNotification();

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Order placed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Clear cart and go back
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error placing order: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _sendOrderNotification() async {
    try {
      // Find or create conversation
      final conversationsQuery = await FirebaseFirestore.instance
          .collection('conversations')
          .where('participantIds', arrayContains: _consumerFacilityId)
          .get();

      String? conversationId;

      for (var doc in conversationsQuery.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participantIds'] ?? []);
        if (participants.contains(widget.facilityId)) {
          conversationId = doc.id;
          break;
        }
      }

      // Create conversation if doesn't exist
      if (conversationId == null) {
        final newConv = await FirebaseFirestore.instance
            .collection('conversations')
            .add({
              'participantIds': [_consumerFacilityId, widget.facilityId],
              'participantNames': {
                _consumerFacilityId!: _consumerFacilityName,
                widget.facilityId:
                    widget.facilityData['facilityName'] ??
                    widget.facilityData['name'],
              },
              'lastMessage': 'New order placed',
              'lastMessageTime': FieldValue.serverTimestamp(),
              'unreadCounts': {_consumerFacilityId!: 0, widget.facilityId: 1},
              'createdAt': FieldValue.serverTimestamp(),
            });
        conversationId = newConv.id;
      }

      // Send message
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
            'senderId': _consumerFacilityId,
            'senderName': _consumerFacilityName,
            'message':
                'New supply order placed. Total: ₦${_cartTotal.toStringAsFixed(2)}. Items: $_cartItemCount',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });

      // Update conversation
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .update({
            'lastMessage': 'New supply order placed',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'unreadCounts.${widget.facilityId}': FieldValue.increment(1),
          });
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  void _showCartBottomSheet() {
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Shopping Cart',
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
              ),
              const Divider(height: 1),
              // Cart items
              Expanded(
                child: _cart.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Your cart is empty',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _cart.length,
                        itemBuilder: (context, index) {
                          final productId = _cart.keys.elementAt(index);
                          final product = _products[productId]!;
                          final quantity = _cart[productId]!;
                          final price = (product['price'] ?? 0.0) as num;
                          final subtotal = price * quantity;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₦${price.toStringAsFixed(2)} × $quantity',
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
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          setState(
                                            () => _removeFromCart(productId),
                                          );
                                          Navigator.pop(context);
                                          _showCartBottomSheet();
                                        },
                                        icon: const Icon(
                                          Icons.remove_circle,
                                          color: Colors.red,
                                        ),
                                      ),
                                      Text(
                                        '$quantity',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          setState(
                                            () =>
                                                _addToCart(productId, product),
                                          );
                                          Navigator.pop(context);
                                          _showCartBottomSheet();
                                        },
                                        icon: const Icon(
                                          Icons.add_circle,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // Bottom summary
              if (_cart.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₦${_cartTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _submitOrder();
                          },
                          icon: const Icon(Icons.shopping_bag),
                          label: const Text('Checkout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pharmacyName =
        widget.facilityData['facilityName'] ??
        widget.facilityData['name'] ??
        'Pharmacy';

    return Scaffold(
      appBar: AppBar(
        title: Text(pharmacyName),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // Cart badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: _showCartBottomSheet,
                icon: const Icon(Icons.shopping_cart),
              ),
              if (_cartItemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$_cartItemCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Wallet balance banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: Colors.teal.shade700,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Facility Wallet Balance:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Text(
                  '₦${_walletBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
          ),

          // Products list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('facility_services')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .where('type', isEqualTo: 'service')
                  .snapshots(),
              builder: (context, snapshot) {
                debugPrint(
                  '📦 StreamBuilder state: ${snapshot.connectionState}',
                );

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
                          const Text(
                            'Error loading products',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final products = snapshot.data?.docs ?? [];

                // Client-side filtering and sorting
                final availableProducts = products.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isAvailable'] != false;
                }).toList();

                // Sort alphabetically
                availableProducts.sort((a, b) {
                  final aName =
                      (a.data() as Map<String, dynamic>)['name'] ?? '';
                  final bName =
                      (b.data() as Map<String, dynamic>)['name'] ?? '';
                  return aName.toString().compareTo(bName.toString());
                });

                debugPrint('📦 Total Products Found: ${products.length}');
                debugPrint(
                  '📦 Available Products: ${availableProducts.length}',
                );
                if (availableProducts.isNotEmpty) {
                  final firstProduct =
                      availableProducts.first.data() as Map<String, dynamic>;
                  debugPrint('📦 First Product: ${firstProduct['name']}');
                }

                if (availableProducts.isEmpty) {
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
                            'No products available',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'This pharmacy hasn\'t added products yet.\nFacility ID: ${widget.facilityId}',
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
                  itemCount: availableProducts.length,
                  itemBuilder: (context, index) {
                    final product = availableProducts[index];
                    final productData = product.data() as Map<String, dynamic>;
                    final productId = product.id;
                    final name = productData['name'] ?? 'Unnamed Product';
                    final description = productData['description'] ?? '';
                    final price = (productData['price'] ?? 0.0) as num;
                    final category = productData['category'] ?? 'General';
                    final cartQuantity = _cart[productId] ?? 0;

                    debugPrint('🛒 Product: $name, Cart Qty: $cartQuantity');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.medication,
                                    color: Colors.teal.shade700,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          category,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₦${price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 12),
                            // Cart controls
                            if (cartQuantity == 0)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _addToCart(productId, productData),
                                  icon: const Icon(
                                    Icons.add_shopping_cart,
                                    size: 18,
                                  ),
                                  label: const Text('Add to Cart'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Quantity:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () =>
                                              _removeFromCart(productId),
                                          icon: const Icon(
                                            Icons.remove_circle,
                                            color: Colors.red,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '$cartQuantity',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => _addToCart(
                                            productId,
                                            productData,
                                          ),
                                          icon: const Icon(
                                            Icons.add_circle,
                                            color: Colors.teal,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
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

          // Checkout bar
          if (_cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        Text(
                          '₦${_cartTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitOrder,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.shopping_bag),
                    label: Text(_isLoading ? 'Processing...' : 'Checkout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
