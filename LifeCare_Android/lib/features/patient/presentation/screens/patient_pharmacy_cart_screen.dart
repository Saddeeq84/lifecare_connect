// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientPharmacyCartScreen extends StatefulWidget {
  final String facilityId;
  final Map<String, dynamic> facilityData;

  const PatientPharmacyCartScreen({
    super.key,
    required this.facilityId,
    required this.facilityData,
  });

  @override
  State<PatientPharmacyCartScreen> createState() =>
      _PatientPharmacyCartScreenState();
}

class _PatientPharmacyCartScreenState extends State<PatientPharmacyCartScreen> {
  final Map<String, int> _cart = {}; // productId -> quantity
  final Map<String, Map<String, dynamic>> _products =
      {}; // productId -> product data
  bool _isLoading = false;
  double _walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    // Get user ID from Firebase Auth or SharedPreferences (phone-authenticated patients)
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    try {
      final walletDoc = await FirebaseFirestore.instance
          .collection('wallets')
          .doc(userId)
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

    // Check wallet balance
    if (_walletBalance < _cartTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Insufficient wallet balance!\n'
            'Required: ₦${_cartTotal.toStringAsFixed(2)}\n'
            'Available: ₦${_walletBalance.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Get user ID from Firebase Auth or SharedPreferences (phone-authenticated patients)
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('user_id');
    }

    if (userId == null || userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to place an order.')),
        );
      }
      return;
    }
    final String patientId = userId;

    // Confirm order
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Items: $_cartItemCount'),
            const SizedBox(height: 8),
            Text(
              'Total Amount: ₦${_cartTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: Payment will be deducted from your wallet when the pharmacy supplies and delivers your order.',
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
            child: const Text('Confirm Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // Get user details
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .get();

      final userName =
          userDoc.data()?['fullName'] ??
          userDoc.data()?['name'] ??
          'Unknown Patient';

      // Prepare cart items
      final cartItems = _cart.entries.map((entry) {
        final product = _products[entry.key]!;
        return {
          'productId': entry.key,
          'productName': product['name'],
          'category': product['category'],
          'price': product['price'],
          'quantity': entry.value,
          'subtotal': (product['price'] as num).toDouble() * entry.value,
        };
      }).toList();

      // Create order
      await FirebaseFirestore.instance.collection('service_requests').add({
        'patientId': patientId,
        'patientName': userName,
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityData['name'] ?? 'Unknown Facility',
        'serviceType': 'pharmacy_order',
        'serviceName': 'Pharmacy Order ($_cartItemCount items)',
        'items': cartItems,
        'amount': _cartTotal,
        'status': 'pending',
        'paymentStatus': 'pending', // Will change to 'paid' when supplied
        'paymentHeld': false, // Will be true when pharmacy supplies
        'shippingStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification message
      await _sendOrderNotification(patientId, userName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Order placed successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear cart and navigate back
        Navigator.pop(context);
        Navigator.pop(context); // Back to My Orders
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error placing order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendOrderNotification(
    String patientId,
    String patientName,
  ) async {
    final facilityName = widget.facilityData['name'] ?? 'Facility';
    final conversationId = '${widget.facilityId}_$patientId';

    // Add message to messages collection
    final messageRef = await FirebaseFirestore.instance.collection('messages').add({
      'conversationId': conversationId,
      'senderId': widget.facilityId,
      'senderName': facilityName,
      'senderRole': 'facility',
      'receiverId': patientId,
      'receiverName': patientName,
      'receiverRole': 'patient',
      'content':
          'New pharmacy order received: $_cartItemCount items, Total: ₦${_cartTotal.toStringAsFixed(2)}',
      'type': 'patient_facility',
      'timestamp': FieldValue.serverTimestamp(),
      'isSystem': true,
    });

    // Update or create conversation
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .set({
          'participantIds': [widget.facilityId, patientId],
          'participants': [widget.facilityId, patientId],
          'participantNames': {
            widget.facilityId: facilityName,
            patientId: patientName,
          },
          'participantRoles': {
            widget.facilityId: 'facility',
            patientId: 'patient',
          },
          'title': 'Private Chat',
          'type': 'patient_facility',
          'recipientType': 'patient',
          'isActive': true,
          'lastMessage': 'New pharmacy order received',
          'lastMessageId': messageRef.id,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastSenderId': widget.facilityId,
          'unreadCounts': {widget.facilityId: 1, patientId: 0},
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.facilityData['name'] ?? 'Pharmacy'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // Cart icon with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: _cart.isEmpty ? null : () => _showCartBottomSheet(),
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
                      minWidth: 16,
                      minHeight: 16,
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
            color: Colors.green.shade50,
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.green),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wallet Balance',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '₦${_walletBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
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
                          const Icon(Icons.error, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading products',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final products = snapshot.data?.docs ?? [];

                // Filter only available products and sort by name
                final availableProducts = products.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isAvailable'] != false; // Show if true or null
                }).toList();

                // Sort by name
                availableProducts.sort((a, b) {
                  final aName =
                      (a.data() as Map<String, dynamic>)['name'] ?? '';
                  final bName =
                      (b.data() as Map<String, dynamic>)['name'] ?? '';
                  return aName.toString().compareTo(bName.toString());
                });

                // Debug: Print product count
                debugPrint('📦 Total Products Found: ${products.length}');
                debugPrint(
                  '📦 Available Products: ${availableProducts.length}',
                );
                if (availableProducts.isNotEmpty) {
                  debugPrint(
                    '📦 First product: ${availableProducts.first.data()}',
                  );
                }

                if (availableProducts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2,
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
                            'This pharmacy hasn\'t added any products yet.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Facility ID: ${widget.facilityId}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
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
                    final cartQuantity = _cart[productId] ?? 0;

                    debugPrint(
                      '🛒 Product: ${productData['name']}, Cart Qty: $cartQuantity',
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Product icon
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.medication,
                                color: Colors.teal.shade700,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Product details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    productData['name'] ?? 'Unknown Product',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    productData['category'] ?? 'General',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '₦${(productData['price'] ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Add to cart / Quantity controls
                            if (cartQuantity == 0)
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _addToCart(productId, productData),
                                icon: const Icon(
                                  Icons.add_shopping_cart,
                                  size: 18,
                                ),
                                label: const Text('Add'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.teal.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          _removeFromCart(productId),
                                      icon: const Icon(Icons.remove),
                                      color: Colors.teal.shade700,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        '$cartQuantity',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal.shade700,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          _addToCart(productId, productData),
                                      icon: const Icon(Icons.add),
                                      color: Colors.teal.shade700,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      padding: EdgeInsets.zero,
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
      ),
      bottomNavigationBar: _cart.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_cartItemCount items',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '₦${_cartTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitOrder,
                      icon: _isLoading
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
                          : const Icon(Icons.shopping_cart_checkout),
                      label: Text(_isLoading ? 'Processing...' : 'Checkout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.teal.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_cart, color: Colors.teal),
                      const SizedBox(width: 12),
                      Text(
                        'Cart ($_cartItemCount items)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _cart.clear();
                            _products.clear();
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final productId = _cart.keys.elementAt(index);
                      final quantity = _cart[productId]!;
                      final product = _products[productId]!;
                      final price = (product['price'] ?? 0.0) as num;
                      final subtotal = price.toDouble() * quantity;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product['name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₦${price.toStringAsFixed(2)} × $quantity',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₦${subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Quantity controls
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        _removeFromCart(productId);
                                        if (_cart.isEmpty) {
                                          Navigator.pop(context);
                                        }
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.remove),
                                      iconSize: 20,
                                    ),
                                    Text(
                                      '$quantity',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        _addToCart(productId, product);
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.add),
                                      iconSize: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
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
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _submitOrder();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Proceed to Checkout'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => setState(() {})); // Refresh after closing
  }
}
