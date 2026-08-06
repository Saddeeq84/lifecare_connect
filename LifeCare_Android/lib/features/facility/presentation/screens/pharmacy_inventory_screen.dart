import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PharmacyInventoryScreen extends StatefulWidget {
  final String facilityId;
  final String staffId;
  final String staffName;

  const PharmacyInventoryScreen({
    super.key,
    required this.facilityId,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<PharmacyInventoryScreen> createState() =>
      _PharmacyInventoryScreenState();
}

class _PharmacyInventoryScreenState extends State<PharmacyInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Helper method to check if an item is expiring soon (within 3 months)
  bool _isExpiringSoon(dynamic expirationTimestamp) {
    if (expirationTimestamp == null) return false;

    final expirationDate = (expirationTimestamp as Timestamp).toDate();
    final now = DateTime.now();
    final daysUntilExpiration = expirationDate.difference(now).inDays;

    // Alert 3 months (90 days) ahead
    return daysUntilExpiration <= 90 && daysUntilExpiration > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy Inventory Management'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        actions: [
          // Expiration Alert Icon
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('pharmacy_inventory')
                .where('facilityId', isEqualTo: widget.facilityId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              final now = DateTime.now();
              final threeMonthsFromNow = now.add(const Duration(days: 90));

              final expiringCount = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['expirationDate'] != null) {
                  final expirationDate = (data['expirationDate'] as Timestamp)
                      .toDate();
                  return expirationDate.isAfter(now) &&
                      expirationDate.isBefore(threeMonthsFromNow);
                }
                return false;
              }).length;

              return Stack(
                children: [
                  IconButton(
                    onPressed: () => _tabController.animateTo(
                      3,
                    ), // Navigate to Expiring Soon tab
                    icon: const Icon(Icons.warning_amber_rounded),
                    tooltip: "Items expiring soon",
                  ),
                  if (expiringCount > 0)
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
                          expiringCount > 99 ? '99+' : '$expiringCount',
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
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All Items'),
            Tab(text: 'Low Stock'),
            Tab(text: 'Out of Stock'),
            Tab(text: 'Expiring Soon'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search medications...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Inventory Summary Cards
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildInventorySummary(),
          ),
          const SizedBox(height: 8),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllItemsTab(),
                _buildLowStockTab(),
                _buildOutOfStockTab(),
                _buildExpiringSoonTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddInventoryDialog,
        backgroundColor: Colors.orange.shade800,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAllItemsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pharmacy_inventory')
          .where('facilityId', isEqualTo: widget.facilityId)
          .orderBy('name')
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
                  Icons.inventory_2_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No inventory items found',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the + button to add items',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        final filteredDocs = snapshot.data!.docs.where((doc) {
          if (_searchQuery.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          return (data['name'] ?? '').toString().toLowerCase().contains(
                _searchQuery,
              ) ||
              (data['category'] ?? '').toString().toLowerCase().contains(
                _searchQuery,
              );
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;

            // Check if item is expiring soon for visual indication
            final isExpiringSoon =
                data['expirationDate'] != null &&
                _isExpiringSoon(data['expirationDate']);

            return _buildInventoryCard(
              doc.id,
              data,
              isExpiringSoon: isExpiringSoon,
            );
          },
        );
      },
    );
  }

  Widget _buildLowStockTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pharmacy_inventory')
          .where('facilityId', isEqualTo: widget.facilityId)
          .orderBy('currentStock')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No data available'));
        }

        // Filter items with low stock
        final lowStockDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final currentStock = (data['currentStock'] as num?)?.toInt() ?? 0;
          final minStock = (data['minStockLevel'] as num?)?.toInt() ?? 10;
          return currentStock > 0 && currentStock <= minStock;
        }).toList();

        if (lowStockDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Colors.green.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No low stock items',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Print Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () => _printLowStockReport(lowStockDocs),
                icon: const Icon(Icons.print),
                label: const Text('Print Low Stock Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: lowStockDocs.length,
                itemBuilder: (context, index) {
                  final doc = lowStockDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildInventoryCard(doc.id, data, isLowStock: true);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOutOfStockTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pharmacy_inventory')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('currentStock', isEqualTo: 0)
          .orderBy('lastUpdated', descending: true)
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
                  Icons.check_circle_outline,
                  size: 80,
                  color: Colors.green.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No out of stock items',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        final outOfStockDocs = snapshot.data!.docs;

        return Column(
          children: [
            // Print Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () => _printOutOfStockReport(outOfStockDocs),
                icon: const Icon(Icons.print),
                label: const Text('Print Out of Stock Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: outOfStockDocs.length,
                itemBuilder: (context, index) {
                  final doc = outOfStockDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildInventoryCard(doc.id, data, isOutOfStock: true);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpiringSoonTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pharmacy_inventory')
          .where('facilityId', isEqualTo: widget.facilityId)
          .orderBy('expirationDate')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No data available'));
        }

        // Filter items expiring within 3 months (90 days)
        final now = DateTime.now();
        final threeMonthsFromNow = now.add(const Duration(days: 90));

        final expiringSoonDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['expirationDate'] != null) {
            final expirationDate = (data['expirationDate'] as Timestamp)
                .toDate();
            return expirationDate.isAfter(now) &&
                expirationDate.isBefore(threeMonthsFromNow);
          }
          return false;
        }).toList();

        if (expiringSoonDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Colors.green.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No items expiring soon',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'All medications are safe for the next 3 months',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: expiringSoonDocs.length,
          itemBuilder: (context, index) {
            final doc = expiringSoonDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildInventoryCard(doc.id, data, isExpiringSoon: true);
          },
        );
      },
    );
  }

  Widget _buildInventoryCard(
    String docId,
    Map<String, dynamic> data, {
    bool isLowStock = false,
    bool isOutOfStock = false,
    bool isExpiringSoon = false,
  }) {
    final currentStock = (data['currentStock'] as num?)?.toInt() ?? 0;
    final minStock = (data['minStockLevel'] as num?)?.toInt() ?? 10;
    final maxStock = (data['maxStockLevel'] as num?)?.toInt() ?? 100;
    final unitPrice = (data['unitPrice'] as num?)?.toDouble() ?? 0.0;

    Color cardColor = Colors.white;
    Color borderColor = Colors.grey.shade300;

    if (isOutOfStock) {
      cardColor = Colors.red.shade50;
      borderColor = Colors.red.shade300;
    } else if (isExpiringSoon) {
      cardColor = Colors.amber.shade50;
      borderColor = Colors.amber.shade400;
    } else if (isLowStock) {
      cardColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade300;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] ?? 'Unknown Item',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Category: ${data['category'] ?? 'N/A'}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      if (data['expirationDate'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Expires: ${DateFormat('MMM dd, yyyy').format((data['expirationDate'] as Timestamp).toDate())}',
                          style: TextStyle(
                            color: _isExpiringSoon(data['expirationDate'])
                                ? Colors.orange
                                : Colors.grey.shade600,
                            fontSize: 13,
                            fontWeight: _isExpiringSoon(data['expirationDate'])
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                      if (data['description'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          data['description'],
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) =>
                      _handleInventoryAction(docId, data, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'restock',
                      child: Text('Restock'),
                    ),
                    const PopupMenuItem(
                      value: 'adjust',
                      child: Text('Adjust Stock'),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Details'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStockInfo(
                    'Current Stock',
                    currentStock.toString(),
                    isOutOfStock
                        ? Colors.red
                        : isLowStock
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStockInfo(
                    'Min Level',
                    minStock.toString(),
                    Colors.grey,
                  ),
                ),
                Expanded(
                  child: _buildStockInfo(
                    'Unit Price',
                    '₦${unitPrice.toStringAsFixed(2)}',
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Stock Level Indicator
            LinearProgressIndicator(
              value: maxStock > 0 ? currentStock / maxStock : 0,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOutOfStock
                    ? Colors.red
                    : isLowStock
                    ? Colors.orange
                    : Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last Updated: ${data['lastUpdated'] != null ? DateFormat('MMM dd, yyyy').format((data['lastUpdated'] as Timestamp).toDate()) : 'N/A'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (isExpiringSoon)
                  ElevatedButton.icon(
                    onPressed: () => _showExpirationActionDialog(docId, data),
                    icon: const Icon(Icons.warning, size: 16),
                    label: const Text('Expiring Soon'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                  )
                else if (isOutOfStock || isLowStock)
                  ElevatedButton.icon(
                    onPressed: () => _showRestockDialog(docId, data),
                    icon: const Icon(Icons.add_box, size: 16),
                    label: Text(isOutOfStock ? 'Restock' : 'Add Stock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOutOfStock
                          ? Colors.red
                          : Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventorySummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pharmacy_inventory')
          .where('facilityId', isEqualTo: widget.facilityId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;
        double totalValue = 0.0;
        int totalItems = 0;
        int lowStockItems = 0;
        int outOfStockItems = 0;

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final currentStock = (data['currentStock'] as num?)?.toInt() ?? 0;
          final minStock = (data['minStockLevel'] as num?)?.toInt() ?? 10;
          final unitPrice = (data['unitPrice'] as num?)?.toDouble() ?? 0.0;

          // Calculate total value
          totalValue += (currentStock * unitPrice);
          totalItems += currentStock;

          // Count low stock and out of stock items
          if (currentStock == 0) {
            outOfStockItems++;
          } else if (currentStock <= minStock) {
            lowStockItems++;
          }
        }

        return GestureDetector(
          onTap: () => _showInventoryValueBreakdown(docs),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Total Inventory Value
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Total Inventory Value',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₦${totalValue.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${docs.length} products • $totalItems total items',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.touch_app,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            Text(
                              ' Tap for breakdown',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Container(width: 1, height: 50, color: Colors.grey.shade300),
                  const SizedBox(width: 16),

                  // Quick Stats
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickStat(
                          'Low Stock',
                          lowStockItems.toString(),
                          lowStockItems > 0 ? Colors.orange : Colors.grey,
                        ),
                        _buildQuickStat(
                          'Out of Stock',
                          outOfStockItems.toString(),
                          outOfStockItems > 0 ? Colors.red : Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showInventoryValueBreakdown(List<QueryDocumentSnapshot> docs) {
    // Calculate detailed breakdown
    final categoryBreakdown = <String, Map<String, dynamic>>{};
    double totalValue = 0.0;
    int totalItems = 0;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final category = data['category'] ?? 'Other';
      final currentStock = (data['currentStock'] as num?)?.toInt() ?? 0;
      final unitPrice = (data['unitPrice'] as num?)?.toDouble() ?? 0.0;
      final itemValue = currentStock * unitPrice;

      totalValue += itemValue;
      totalItems += currentStock;

      if (!categoryBreakdown.containsKey(category)) {
        categoryBreakdown[category] = {'value': 0.0, 'items': 0, 'products': 0};
      }

      categoryBreakdown[category]!['value'] += itemValue;
      categoryBreakdown[category]!['items'] += currentStock;
      categoryBreakdown[category]!['products'] += 1;
    }

    // Sort categories by value (highest first)
    final sortedCategories = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value['value'].compareTo(a.value['value']));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.analytics, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text('Inventory Value Breakdown'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Total Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Inventory Value',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        Text(
                          '₦${totalValue.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$totalItems items',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${docs.length} products',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Category Breakdown
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'By Category:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),

              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sortedCategories.length,
                  itemBuilder: (context, index) {
                    final entry = sortedCategories[index];
                    final category = entry.key;
                    final data = entry.value;
                    final value = data['value'] as double;
                    final items = data['items'] as int;
                    final products = data['products'] as int;
                    final percentage = totalValue > 0
                        ? (value / totalValue * 100)
                        : 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          category,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text('$items items • $products products'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₦${value.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStockInfo(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _handleInventoryAction(
    String docId,
    Map<String, dynamic> data,
    String action,
  ) {
    switch (action) {
      case 'restock':
        _showRestockDialog(docId, data);
        break;
      case 'adjust':
        _showAdjustStockDialog(docId, data);
        break;
      case 'edit':
        _showEditItemDialog(docId, data);
        break;
      case 'delete':
        _showDeleteConfirmation(docId, data);
        break;
    }
  }

  // Nigerian Pharmacy Categories
  static const List<String> _medicationCategories = [
    'Antibiotics',
    'Analgesics & Painkillers',
    'Anti-inflammatory',
    'Antimalaria',
    'Antifungal',
    'Antiviral',
    'Cardiovascular',
    'Respiratory',
    'Gastrointestinal',
    'Diabetes Management',
    'Blood Pressure',
    'Mental Health',
    'Contraceptives',
    'Vitamins & Supplements',
    'Eye & Ear Care',
    'Skin Care & Dermatology',
    'Wound Care',
    'Child Health',
    'Maternal Health',
    'Emergency Medicine',
    'Surgical Supplies',
    'Medical Devices',
    'Other',
  ];

  // Medication Forms/Types
  static const List<String> _medicationForms = [
    'Tablet',
    'Capsule',
    'Syrup/Liquid',
    'Injection',
    'Cream/Ointment',
    'Drops (Eye/Ear)',
    'Inhaler',
    'Suppository',
    'Patch',
    'Powder',
    'Gel',
    'Lotion',
    'Solution',
    'Suspension',
    'Spray',
    'Kit/Device',
    'Other',
  ];

  void _showAddInventoryDialog() {
    final nameController = TextEditingController();
    final initialStockController = TextEditingController();
    final minStockController = TextEditingController();
    final maxStockController = TextEditingController();
    final unitPriceController = TextEditingController();
    String? selectedCategory;
    String? selectedMedicationForm;
    DateTime? expirationDate;
    bool isSimpleMode = true; // Default to simple mode

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Add New Inventory Item'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSimpleMode ? 'Simple' : 'Advanced',
                    style: TextStyle(
                      fontSize: 14,
                      color: isSimpleMode ? Colors.green : Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: !isSimpleMode,
                    onChanged: (value) {
                      setState(() {
                        isSimpleMode = !value;
                        // Auto-fill min/max in simple mode
                        if (isSimpleMode) {
                          minStockController.text = '10';
                          maxStockController.text = '100';
                        }
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(),
                  ),
                  items: _medicationCategories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Medication Form Field
                DropdownButtonFormField<String>(
                  value: selectedMedicationForm,
                  decoration: const InputDecoration(
                    labelText: 'Medication Form/Type *',
                    border: OutlineInputBorder(),
                    helperText:
                        'Select the form of the medication (e.g., Tablet, Syrup)',
                  ),
                  items: _medicationForms.map((form) {
                    return DropdownMenuItem<String>(
                      value: form,
                      child: Text(form),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedMedicationForm = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select medication form';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Expiration Date Field (Mandatory)
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(
                        const Duration(days: 365),
                      ),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(
                        const Duration(days: 3650),
                      ), // 10 years
                    );
                    if (picked != null) {
                      setState(() {
                        expirationDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: expirationDate == null
                            ? Colors.red
                            : Colors.grey,
                        width: expirationDate == null ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      color: expirationDate == null ? Colors.red.shade50 : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          expirationDate == null
                              ? 'Expiration Date (Required) *'
                              : 'Expires: ${DateFormat('MMM dd, yyyy').format(expirationDate!)}',
                          style: TextStyle(
                            color: expirationDate == null
                                ? Colors.red.shade700
                                : Colors.black,
                            fontWeight: expirationDate == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (expirationDate != null)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    expirationDate = null;
                                  });
                                },
                                child: Icon(
                                  Icons.clear,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.calendar_today,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Stock Information Section
                if (isSimpleMode) ...[
                  // SIMPLE MODE - Just current stock and price
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Simple Mode',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Just enter what you have and the price. We\'ll set smart defaults for alerts!',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: initialStockController,
                          decoration: const InputDecoration(
                            labelText: 'How many do you have? *',
                            hintText: 'e.g., 50',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.inventory),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: unitPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Price per item (₦) *',
                            hintText: 'e.g., 150',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Auto-set: Alert when 10 items left, Max storage 100 items',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // ADVANCED MODE - Full control
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.settings,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Advanced Stock Management',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• Current Stock: How many you have right now\n'
                          '• Min Level: When to reorder (low stock alert)\n'
                          '• Max Level: Maximum to keep in storage',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: initialStockController,
                          decoration: const InputDecoration(
                            labelText: 'Current Stock *',
                            hintText: 'e.g., 50',
                            helperText: 'Quantity you have now',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: unitPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Unit Price (₦) *',
                            hintText: 'e.g., 150',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minStockController,
                          decoration: const InputDecoration(
                            labelText: 'Min Level (Alert) *',
                            hintText: 'e.g., 10',
                            helperText: 'Alert when stock reaches this',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: maxStockController,
                          decoration: const InputDecoration(
                            labelText: 'Max Level (Storage) *',
                            hintText: 'e.g., 200',
                            helperText: 'Maximum storage capacity',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _addInventoryItem(
                nameController.text,
                selectedCategory ?? '',
                selectedMedicationForm ?? '',
                initialStockController.text,
                isSimpleMode
                    ? '10'
                    : minStockController.text, // Default to 10 in simple mode
                isSimpleMode
                    ? '100'
                    : maxStockController.text, // Default to 100 in simple mode
                unitPriceController.text,
                expirationDate,
              ),
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestockDialog(String docId, Map<String, dynamic> data) {
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restock ${data['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Stock: ${data['currentStock'] ?? 0}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity to Add *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _restockItem(docId, data, quantityController.text),
            child: const Text('Restock'),
          ),
        ],
      ),
    );
  }

  void _showAdjustStockDialog(String docId, Map<String, dynamic> data) {
    final newStockController = TextEditingController(
      text: (data['currentStock'] ?? 0).toString(),
    );
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adjust Stock - ${data['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Stock: ${data['currentStock'] ?? 0}'),
            const SizedBox(height: 16),
            TextField(
              controller: newStockController,
              decoration: const InputDecoration(
                labelText: 'New Stock Level *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Adjustment *',
                hintText: 'e.g., Expired items removed',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _adjustStock(
              docId,
              data,
              newStockController.text,
              reasonController.text,
            ),
            child: const Text('Adjust'),
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(String docId, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name'] ?? '');
    final minStockController = TextEditingController(
      text: (data['minStockLevel'] ?? 0).toString(),
    );
    final maxStockController = TextEditingController(
      text: (data['maxStockLevel'] ?? 0).toString(),
    );
    final unitPriceController = TextEditingController(
      text: (data['unitPrice'] ?? 0).toString(),
    );
    String? selectedCategory = data['category'] ?? '';
    DateTime? expirationDate;

    // Parse existing expiration date if it exists
    if (data['expirationDate'] != null) {
      expirationDate = (data['expirationDate'] as Timestamp).toDate();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Item Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value:
                      (selectedCategory != null && selectedCategory!.isNotEmpty)
                      ? selectedCategory
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(),
                  ),
                  items: _medicationCategories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Expiration Date Field (Required)
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate:
                          expirationDate ??
                          DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(
                        const Duration(days: 3650),
                      ), // 10 years
                    );
                    if (picked != null) {
                      setState(() {
                        expirationDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: expirationDate == null
                            ? Colors.red
                            : Colors.grey,
                        width: expirationDate == null ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          expirationDate == null
                              ? 'Expiration Date (Required) *'
                              : 'Expires: ${DateFormat('MMM dd, yyyy').format(expirationDate!)}',
                          style: TextStyle(
                            color: expirationDate == null
                                ? Colors.red
                                : Colors.black,
                            fontWeight: expirationDate == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        Icon(
                          Icons.calendar_today,
                          color: expirationDate == null
                              ? Colors.red
                              : Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unitPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Unit Price (₦) *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minStockController,
                        decoration: const InputDecoration(
                          labelText: 'Min Stock Level *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: maxStockController,
                        decoration: const InputDecoration(
                          labelText: 'Max Stock Level *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
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
              onPressed: () => _editItem(
                docId,
                nameController.text,
                selectedCategory ?? '',
                minStockController.text,
                maxStockController.text,
                unitPriceController.text,
                expirationDate,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
          'Are you sure you want to delete "${data['name']}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _deleteItem(docId),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showExpirationActionDialog(String docId, Map<String, dynamic> data) {
    final expirationDate = data['expirationDate'] != null
        ? (data['expirationDate'] as Timestamp).toDate()
        : null;

    final daysUntilExpiration = expirationDate != null
        ? expirationDate.difference(DateTime.now()).inDays
        : 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.amber.shade600),
            const SizedBox(width: 8),
            const Text('Expiring Soon'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Item: ${data['name']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Current Stock: ${data['currentStock'] ?? 0}'),
            const SizedBox(height: 4),
            Text(
              'Expires: ${expirationDate != null ? DateFormat('MMM dd, yyyy').format(expirationDate) : 'N/A'}',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Days remaining: $daysUntilExpiration',
              style: TextStyle(
                color: daysUntilExpiration <= 30 ? Colors.red : Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'What would you like to do?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showAdjustStockDialog(docId, data);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Adjust Stock'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditItemDialog(docId, data);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Update Details'),
          ),
        ],
      ),
    );
  }

  Future<void> _addInventoryItem(
    String name,
    String category,
    String medicationForm,
    String initialStock,
    String minStock,
    String maxStock,
    String unitPrice,
    DateTime? expirationDate,
  ) async {
    if (name.trim().isEmpty ||
        category.trim().isEmpty ||
        medicationForm.trim().isEmpty ||
        initialStock.trim().isEmpty ||
        minStock.trim().isEmpty ||
        maxStock.trim().isEmpty ||
        unitPrice.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    // Validate expiration date is provided
    if (expirationDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expiration date is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final initialStockInt = int.parse(initialStock);
      final minStockInt = int.parse(minStock);
      final maxStockInt = int.parse(maxStock);
      final unitPriceDouble = double.parse(unitPrice);

      Map<String, dynamic> itemData = {
        'facilityId': widget.facilityId,
        'name': name.trim(),
        'category': category.trim(),
        'medicationForm': medicationForm.trim(),
        'currentStock': initialStockInt,
        'minStockLevel': minStockInt,
        'maxStockLevel': maxStockInt,
        'unitPrice': unitPriceDouble,
        'expirationDate': Timestamp.fromDate(expirationDate),
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdBy': widget.staffName,
        'transactions': [
          {
            'type': 'initial_stock',
            'quantity': initialStockInt,
            'timestamp': Timestamp.now(),
            'performedBy': widget.staffName,
            'reason': 'Initial inventory setup',
          },
        ],
      };

      await FirebaseFirestore.instance
          .collection('pharmacy_inventory')
          .add(itemData);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name added to inventory successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding item: $e')));
    }
  }

  Future<void> _restockItem(
    String docId,
    Map<String, dynamic> data,
    String quantity,
  ) async {
    if (quantity.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter quantity to add')),
      );
      return;
    }

    try {
      final quantityInt = int.parse(quantity);
      final currentStock = (data['currentStock'] as num?)?.toInt() ?? 0;
      final newStock = currentStock + quantityInt;

      await FirebaseFirestore.instance
          .collection('pharmacy_inventory')
          .doc(docId)
          .update({
            'currentStock': newStock,
            'lastUpdated': FieldValue.serverTimestamp(),
            'transactions': FieldValue.arrayUnion([
              {
                'type': 'restock',
                'quantity': quantityInt,
                'timestamp': Timestamp.now(),
                'performedBy': widget.staffName,
                'reason': 'Stock replenishment',
                'previousStock': currentStock,
                'newStock': newStock,
              },
            ]),
          });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${data['name']} restocked successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error restocking item: $e')));
    }
  }

  Future<void> _adjustStock(
    String docId,
    Map<String, dynamic> data,
    String newStock,
    String reason,
  ) async {
    if (newStock.trim().isEmpty || reason.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    try {
      final newStockInt = int.parse(newStock);
      final currentStock = (data['currentStock'] as num?)?.toInt() ?? 0;

      await FirebaseFirestore.instance
          .collection('pharmacy_inventory')
          .doc(docId)
          .update({
            'currentStock': newStockInt,
            'lastUpdated': FieldValue.serverTimestamp(),
            'transactions': FieldValue.arrayUnion([
              {
                'type': 'adjustment',
                'quantity': newStockInt - currentStock,
                'timestamp': Timestamp.now(),
                'performedBy': widget.staffName,
                'reason': reason.trim(),
                'previousStock': currentStock,
                'newStock': newStockInt,
              },
            ]),
          });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${data['name']} stock adjusted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adjusting stock: $e')));
    }
  }

  Future<void> _editItem(
    String docId,
    String name,
    String category,
    String minStock,
    String maxStock,
    String unitPrice,
    DateTime? expirationDate,
  ) async {
    if (name.trim().isEmpty ||
        category.trim().isEmpty ||
        minStock.trim().isEmpty ||
        maxStock.trim().isEmpty ||
        unitPrice.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    // Validate expiration date is provided
    if (expirationDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expiration date is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final minStockInt = int.parse(minStock);
      final maxStockInt = int.parse(maxStock);
      final unitPriceDouble = double.parse(unitPrice);

      Map<String, dynamic> updateData = {
        'name': name.trim(),
        'category': category.trim(),
        'minStockLevel': minStockInt,
        'maxStockLevel': maxStockInt,
        'unitPrice': unitPriceDouble,
        'expirationDate': Timestamp.fromDate(expirationDate),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('pharmacy_inventory')
          .doc(docId)
          .update(updateData);

      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name updated successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating item: $e')));
    }
  }

  Future<void> _deleteItem(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('pharmacy_inventory')
          .doc(docId)
          .delete();

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting item: $e')));
    }
  }

  Future<void> _printLowStockReport(
    List<QueryDocumentSnapshot> lowStockDocs,
  ) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'LOW STOCK REPORT',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Generated on: ${dateFormat.format(now)}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Total Items: ${lowStockDocs.length}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Divider(thickness: 2),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _buildTableCell('Medication Name', isHeader: true),
                    _buildTableCell('Category', isHeader: true),
                    _buildTableCell('Current', isHeader: true),
                    _buildTableCell('Min Level', isHeader: true),
                    _buildTableCell('Unit Price', isHeader: true),
                  ],
                ),
                // Data Rows
                ...lowStockDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final currentStock =
                      (data['currentStock'] as num?)?.toInt() ?? 0;
                  final minStock =
                      (data['minStockLevel'] as num?)?.toInt() ?? 0;
                  final unitPrice =
                      (data['unitPrice'] as num?)?.toDouble() ?? 0.0;

                  return pw.TableRow(
                    children: [
                      _buildTableCell(data['name'] ?? 'N/A'),
                      _buildTableCell(data['category'] ?? 'N/A'),
                      _buildTableCell(currentStock.toString()),
                      _buildTableCell(minStock.toString()),
                      _buildTableCell('₦${unitPrice.toStringAsFixed(2)}'),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 20),

            // Footer Note
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.orange50,
                border: pw.Border.all(color: PdfColors.orange200),
              ),
              child: pw.Text(
                '⚠️ These items need restocking soon to maintain adequate inventory levels.',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _printOutOfStockReport(
    List<QueryDocumentSnapshot> outOfStockDocs,
  ) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'OUT OF STOCK REPORT',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red700,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Generated on: ${dateFormat.format(now)}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Total Items: ${outOfStockDocs.length}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red700,
                    ),
                  ),
                  pw.Divider(thickness: 2),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2.5),
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.red100),
                  children: [
                    _buildTableCell('Medication Name', isHeader: true),
                    _buildTableCell('Category', isHeader: true),
                    _buildTableCell('Min Level', isHeader: true),
                    _buildTableCell('Unit Price', isHeader: true),
                  ],
                ),
                // Data Rows
                ...outOfStockDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final minStock =
                      (data['minStockLevel'] as num?)?.toInt() ?? 0;
                  final unitPrice =
                      (data['unitPrice'] as num?)?.toDouble() ?? 0.0;

                  return pw.TableRow(
                    children: [
                      _buildTableCell(data['name'] ?? 'N/A'),
                      _buildTableCell(data['category'] ?? 'N/A'),
                      _buildTableCell(minStock.toString()),
                      _buildTableCell('₦${unitPrice.toStringAsFixed(2)}'),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 20),

            // Footer Note
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                border: pw.Border.all(color: PdfColors.red300),
              ),
              child: pw.Text(
                '🚨 URGENT: These items are completely out of stock and need immediate restocking.',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red700,
                ),
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
