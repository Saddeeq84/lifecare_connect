// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Pharmacy Dispensary/Sales Screen
/// Allows staff to sell medicines to customers and automatically updates inventory
class PharmacyDispensaryScreen extends StatefulWidget {
  final String facilityId;
  final String staffId;
  final String staffName;

  const PharmacyDispensaryScreen({
    super.key,
    required this.facilityId,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<PharmacyDispensaryScreen> createState() =>
      _PharmacyDispensaryScreenState();
}

class _PharmacyDispensaryScreenState extends State<PharmacyDispensaryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Cart items: Map of inventory docId to {data, quantity}
  final Map<String, Map<String, dynamic>> _cart = {};

  // Customer details
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  bool _isProcessingSale = false;

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  double get _totalAmount {
    double total = 0;
    for (var item in _cart.values) {
      final data = item['data'] as Map<String, dynamic>;

      // Try multiple field names for price
      double price =
          (data['unitPrice'] as num?)?.toDouble() ??
          (data['sellingPrice'] as num?)?.toDouble() ??
          (data['price'] as num?)?.toDouble() ??
          0;

      final quantity = item['quantity'] as int;
      total += price * quantity;

      // Debug output
      print(
        'Item: ${data['name']}, Price: $price, Quantity: $quantity, Subtotal: ${price * quantity}',
      );
    }
    print('Total Amount: $total');
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispensary / Sales'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Cart badge
          Stack(
            children: [
              IconButton(
                onPressed: _cart.isEmpty ? null : _showCartDialog,
                icon: const Icon(Icons.shopping_cart),
                tooltip: 'View Cart',
              ),
              if (_cart.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '${_cart.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
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
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search medicines...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Available medicines list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pharmacy_inventory')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allItems = snapshot.data?.docs ?? [];

                // Filter by search query and only show items in stock
                final filteredItems = allItems.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final currentStock =
                      (data['currentStock'] as num?)?.toInt() ?? 0;

                  final matchesSearch =
                      _searchQuery.isEmpty || name.contains(_searchQuery);
                  final inStock = currentStock > 0;

                  return matchesSearch && inStock;
                }).toList();

                if (filteredItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No medicines in stock'
                              : 'No medicines found matching "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final doc = filteredItems[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final docId = doc.id;

                    final name = data['name'] ?? 'Unknown';
                    final category = data['category'] ?? '';
                    final form = data['medicationForm'] ?? '';
                    final currentStock =
                        (data['currentStock'] as num?)?.toInt() ?? 0;

                    // Try multiple field names for price
                    final unitPrice =
                        (data['unitPrice'] as num?)?.toDouble() ??
                        (data['sellingPrice'] as num?)?.toDouble() ??
                        (data['price'] as num?)?.toDouble() ??
                        0;

                    final isInCart = _cart.containsKey(docId);
                    final cartQuantity = isInCart
                        ? _cart[docId]!['quantity'] as int
                        : 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: Icon(
                            Icons.medication,
                            color: Colors.green.shade700,
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$category • $form'),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Stock: $currentStock',
                                  style: TextStyle(
                                    color: currentStock < 10
                                        ? Colors.orange
                                        : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '₦${unitPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (isInCart)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.green.shade300,
                                  ),
                                ),
                                child: Text(
                                  'In cart: $cartQuantity',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: isInCart
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _removeFromCart(docId),
                                    icon: const Icon(Icons.remove_circle),
                                    color: Colors.red.shade700,
                                    tooltip: 'Remove one',
                                  ),
                                  IconButton(
                                    onPressed: () => _addToCart(docId, data),
                                    icon: const Icon(Icons.add_circle),
                                    color: Colors.green.shade700,
                                    tooltip: 'Add one more',
                                  ),
                                ],
                              )
                            : IconButton(
                                onPressed: () => _addToCart(docId, data),
                                icon: const Icon(Icons.add_circle),
                                color: Colors.green.shade700,
                                tooltip: 'Add to cart',
                              ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Cart summary footer
          if (_cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total: ₦${_totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_cart.length} item(s)',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showCheckoutDialog,
                    icon: const Icon(Icons.point_of_sale),
                    label: const Text('Checkout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
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

  void _addToCart(String docId, Map<String, dynamic> data) {
    final currentStock = (data['currentStock'] as num?)?.toInt() ?? 0;

    if (_cart.containsKey(docId)) {
      final currentCartQty = _cart[docId]!['quantity'] as int;

      if (currentCartQty >= currentStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot add more than available stock'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _cart[docId]!['quantity'] = currentCartQty + 1;
      });
    } else {
      setState(() {
        _cart[docId] = {'data': data, 'quantity': 1};
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${data['name']} to cart'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removeFromCart(String docId) {
    if (_cart.containsKey(docId)) {
      final currentCartQty = _cart[docId]!['quantity'] as int;

      if (currentCartQty > 1) {
        // Decrease quantity
        setState(() {
          _cart[docId]!['quantity'] = currentCartQty - 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Removed one ${_cart[docId]!['data']['name']} from cart',
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        // Remove item completely if quantity is 1
        final itemName = _cart[docId]!['data']['name'];
        setState(() {
          _cart.remove(docId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed $itemName from cart'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shopping Cart'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _cart.length,
                  itemBuilder: (context, index) {
                    final entry = _cart.entries.elementAt(index);
                    final docId = entry.key;
                    final item = entry.value;
                    final data = item['data'] as Map<String, dynamic>;
                    final quantity = item['quantity'] as int;
                    final name = data['name'] ?? 'Unknown';
                    final unitPrice =
                        (data['unitPrice'] as num?)?.toDouble() ?? 0;
                    final subtotal = unitPrice * quantity;

                    return ListTile(
                      title: Text(name),
                      subtitle: Text(
                        '₦${unitPrice.toStringAsFixed(2)} x $quantity = ₦${subtotal.toStringAsFixed(2)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Decrease quantity button
                          IconButton(
                            onPressed: () {
                              setState(() {
                                if (quantity > 1) {
                                  _cart[docId]!['quantity'] = quantity - 1;
                                } else {
                                  _cart.remove(docId);
                                }
                              });
                              Navigator.pop(context);
                              if (_cart.isNotEmpty) {
                                _showCartDialog();
                              }
                            },
                            icon: Icon(
                              quantity > 1 ? Icons.remove_circle : Icons.delete,
                              color: quantity > 1 ? Colors.orange : Colors.red,
                            ),
                            iconSize: 20,
                            tooltip: quantity > 1
                                ? 'Reduce quantity'
                                : 'Remove item',
                          ),
                          // Quantity display
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text(
                              '$quantity',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                          // Increase quantity button
                          IconButton(
                            onPressed: () {
                              final currentStock =
                                  (data['currentStock'] as num?)?.toInt() ?? 0;
                              if (quantity < currentStock) {
                                setState(() {
                                  _cart[docId]!['quantity'] = quantity + 1;
                                });
                                Navigator.pop(context);
                                _showCartDialog();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Cannot add more than available stock',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.green,
                            ),
                            iconSize: 20,
                            tooltip: 'Increase quantity',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₦${_totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showCheckoutDialog();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Proceed to Checkout'),
          ),
        ],
      ),
    );
  }

  void _showCheckoutDialog() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty. Add items before checkout.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Checkout'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customer Details (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customerNameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customerPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Order Summary',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._cart.entries.map((entry) {
                final data = entry.value['data'] as Map<String, dynamic>;
                final quantity = entry.value['quantity'] as int;
                final name = data['name'] ?? 'Unknown';

                // Try multiple field names for price
                final unitPrice =
                    (data['unitPrice'] as num?)?.toDouble() ??
                    (data['sellingPrice'] as num?)?.toDouble() ??
                    (data['price'] as num?)?.toDouble() ??
                    0;
                final subtotal = unitPrice * quantity;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('$name x $quantity')),
                      Text(
                        '₦${subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₦${_totalAmount.toStringAsFixed(2)}',
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isProcessingSale ? null : _processSale,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: _isProcessingSale
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Complete Sale'),
          ),
        ],
      ),
    );
  }

  Future<void> _processSale() async {
    setState(() {
      _isProcessingSale = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      final saleTime = Timestamp.now();

      // Create sale record
      final saleRef = FirebaseFirestore.instance
          .collection('pharmacy_sales')
          .doc();

      final saleItems = _cart.entries.map((entry) {
        final docId = entry.key;
        final item = entry.value;
        final data = item['data'] as Map<String, dynamic>;
        final quantity = item['quantity'] as int;

        // Try multiple field names for price
        final unitPrice =
            (data['unitPrice'] as num?)?.toDouble() ??
            (data['sellingPrice'] as num?)?.toDouble() ??
            (data['price'] as num?)?.toDouble() ??
            0;

        return {
          'inventoryId': docId,
          'name': data['name'],
          'category': data['category'],
          'medicationForm': data['medicationForm'],
          'quantity': quantity,
          'unitPrice': unitPrice,
          'subtotal': unitPrice * quantity,
        };
      }).toList();

      batch.set(saleRef, {
        'facilityId': widget.facilityId,
        'saleId': saleRef.id,
        'items': saleItems,
        'totalAmount': _totalAmount,
        'customerName': _customerNameController.text.trim().isEmpty
            ? 'Walk-in Customer'
            : _customerNameController.text.trim(),
        'customerPhone': _customerPhoneController.text.trim(),
        'soldBy': widget.staffName,
        'soldById': widget.staffId,
        'saleDate': saleTime,
        'createdAt': saleTime,
        'paymentStatus': 'paid',
      });

      // Update inventory for each item
      for (var entry in _cart.entries) {
        final docId = entry.key;
        final item = entry.value;
        final data = item['data'] as Map<String, dynamic>;
        final quantity = item['quantity'] as int;
        final currentStock = (data['currentStock'] as num).toInt();
        final newStock = currentStock - quantity;

        final inventoryRef = FirebaseFirestore.instance
            .collection('pharmacy_inventory')
            .doc(docId);

        // Get current transactions or initialize empty array
        final currentDoc = await inventoryRef.get();
        final currentData = currentDoc.data() ?? {};
        final currentTransactions =
            (currentData['transactions'] as List<dynamic>?) ?? [];

        final updatedTransactions = [
          ...currentTransactions,
          {
            'type': 'dispense',
            'quantity': -quantity, // Negative to indicate deduction
            'timestamp': saleTime.toDate().toIso8601String(),
            'performedBy': widget.staffName,
            'reason':
                'Sale - ${_customerNameController.text.trim().isEmpty ? "Walk-in Customer" : _customerNameController.text.trim()}',
            'saleId': saleRef.id,
          },
        ];

        batch.update(inventoryRef, {
          'currentStock': newStock,
          'lastUpdated': saleTime,
          'transactions': updatedTransactions,
        });
      }

      // Commit the batch
      await batch.commit();

      // Capture total before clearing cart
      final saleTotal = _totalAmount;

      // Clear cart and customer details
      setState(() {
        _cart.clear();
        _customerNameController.clear();
        _customerPhoneController.clear();
        _isProcessingSale = false;
      });

      // Close checkout dialog
      Navigator.pop(context);

      // Show success message with receipt option
      _showSaleSuccessDialog(saleRef.id, saleTotal);
    } catch (e) {
      setState(() {
        _isProcessingSale = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing sale: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSaleSuccessDialog(String saleId, double totalAmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 32),
            const SizedBox(width: 12),
            const Text('Sale Completed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sale ID: $saleId'),
            const SizedBox(height: 8),
            Text(
              'Total: ₦${totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Inventory has been automatically updated.'),
          ],
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
}
