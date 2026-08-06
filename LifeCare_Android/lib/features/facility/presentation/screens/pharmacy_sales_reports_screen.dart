// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Pharmacy Sales & Reports Screen
/// Displays sales statistics and list of all sales transactions with staff analytics
class PharmacySalesReportsScreen extends StatefulWidget {
  final String facilityId;

  const PharmacySalesReportsScreen({super.key, required this.facilityId});

  @override
  State<PharmacySalesReportsScreen> createState() =>
      _PharmacySalesReportsScreenState();
}

class _PharmacySalesReportsScreenState extends State<PharmacySalesReportsScreen>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'all'; // all, today, week, month
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update actions in AppBar
    });
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
        title: const Text('Sales & Reports'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_cart), text: 'Sales Overview'),
            Tab(icon: Icon(Icons.people_alt), text: 'Staff Analytics'),
          ],
        ),
        actions: [
          if (_tabController.index == 0)
            PopupMenuButton<String>(
              initialValue: _selectedFilter,
              onSelected: (value) {
                setState(() {
                  _selectedFilter = value;
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'all', child: Text('All Sales')),
                const PopupMenuItem(value: 'today', child: Text('Today')),
                const PopupMenuItem(value: 'week', child: Text('This Week')),
                const PopupMenuItem(value: 'month', child: Text('This Month')),
              ],
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filter Sales',
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSalesOverviewTab(), _buildStaffAnalyticsTab()],
      ),
    );
  }

  // Sales Overview Tab (existing content)
  Widget _buildSalesOverviewTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getSalesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allSales = snapshot.data?.docs ?? [];
        final filteredSales = _filterSales(allSales);

        // Calculate statistics
        final stats = _calculateStatistics(filteredSales);

        return Column(
          children: [
            // Sales List Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getFilterTitle(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${filteredSales.length} sale(s)',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Sales List with Statistics at top
            Expanded(
              child: filteredSales.isEmpty
                  ? SingleChildScrollView(
                      child: Column(
                        children: [
                          // Statistics Cards
                          _buildStatisticsSection(stats, filteredSales.length),
                          const SizedBox(height: 40),
                          Icon(
                            Icons.receipt_long,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No sales found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          filteredSales.length + 1, // +1 for statistics section
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // First item is the statistics section
                          return _buildStatisticsSection(
                            stats,
                            filteredSales.length,
                          );
                        }
                        // Adjust index for sales data
                        final sale = filteredSales[index - 1];
                        final saleData = sale.data() as Map<String, dynamic>;
                        return _buildSaleCard(sale.id, saleData);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // Staff Analytics Tab (NEW)
  Widget _buildStaffAnalyticsTab() {
    return _StaffAnalyticsView(facilityId: widget.facilityId);
  }

  String _getFilterTitle() {
    switch (_selectedFilter) {
      case 'today':
        return 'Today\'s Sales';
      case 'week':
        return 'This Week\'s Sales';
      case 'month':
        return 'This Month\'s Sales';
      default:
        return 'All Sales';
    }
  }

  Stream<QuerySnapshot> _getSalesStream() {
    return FirebaseFirestore.instance
        .collection('pharmacy_sales')
        .where('facilityId', isEqualTo: widget.facilityId)
        .orderBy('saleDate', descending: true)
        .snapshots();
  }

  List<QueryDocumentSnapshot> _filterSales(List<QueryDocumentSnapshot> sales) {
    final now = DateTime.now();

    return sales.where((sale) {
      final data = sale.data() as Map<String, dynamic>;
      final saleDate = (data['saleDate'] as Timestamp?)?.toDate();

      if (saleDate == null) return false;

      switch (_selectedFilter) {
        case 'today':
          return saleDate.year == now.year &&
              saleDate.month == now.month &&
              saleDate.day == now.day;
        case 'week':
          final weekAgo = now.subtract(const Duration(days: 7));
          return saleDate.isAfter(weekAgo);
        case 'month':
          return saleDate.year == now.year && saleDate.month == now.month;
        default:
          return true;
      }
    }).toList();
  }

  Map<String, dynamic> _calculateStatistics(List<QueryDocumentSnapshot> sales) {
    double totalRevenue = 0;
    int totalItems = 0;

    for (var sale in sales) {
      final data = sale.data() as Map<String, dynamic>;
      totalRevenue += (data['totalAmount'] as num?)?.toDouble() ?? 0;
      final items = data['items'] as List?;
      if (items != null) {
        for (var item in items) {
          totalItems += ((item as Map)['quantity'] as num?)?.toInt() ?? 0;
        }
      }
    }

    final averageSale = sales.isEmpty ? 0.0 : totalRevenue / sales.length;

    return {
      'totalRevenue': totalRevenue,
      'totalTransactions': sales.length,
      'totalItems': totalItems,
      'averageSale': averageSale,
    };
  }

  Widget _buildStatisticsSection(Map<String, dynamic> stats, int salesCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue Overview',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Revenue Breakdown Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Cash Sales (Dispensary)',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '₦${stats['totalRevenue'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.white30),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Online Revenue (Services)',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const Text(
                      'See Wallet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Cash Revenue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₦${stats['totalRevenue'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Note about wallet
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.amber.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cash sales shown here. For online service payments, check Wallet.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Other Statistics
          const Text(
            'Sales Statistics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildStatCard(
            icon: Icons.receipt,
            title: 'Total Transactions',
            value: '${stats['totalTransactions']}',
            color: Colors.blue,
          ),
          const SizedBox(height: 12),

          _buildStatCard(
            icon: Icons.shopping_cart,
            title: 'Items Sold',
            value: '${stats['totalItems']}',
            color: Colors.orange,
          ),
          const SizedBox(height: 12),

          _buildStatCard(
            icon: Icons.trending_up,
            title: 'Average Sale',
            value: '₦${stats['averageSale'].toStringAsFixed(2)}',
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(String saleId, Map<String, dynamic> saleData) {
    final customerName = saleData['customerName'] ?? 'Unknown';
    final totalAmount = (saleData['totalAmount'] as num?)?.toDouble() ?? 0;
    final saleDate = (saleData['saleDate'] as Timestamp?)?.toDate();
    final items = saleData['items'] as List? ?? [];
    final soldBy = saleData['soldBy'] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSaleDetails(saleId, saleData),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        radius: 20,
                        child: Icon(
                          Icons.receipt_long,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _formatDateTime(saleDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₦${totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Paid',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Divider(height: 24),

              // Items Summary
              Row(
                children: [
                  Icon(Icons.shopping_bag, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${items.length} item(s)',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 24),
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'By: $soldBy',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Sale ID
              const SizedBox(height: 8),
              Text(
                'ID: $saleId',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSaleDetails(String saleId, Map<String, dynamic> saleData) {
    final items = saleData['items'] as List? ?? [];
    final customerName = saleData['customerName'] ?? 'Unknown';
    final customerPhone = saleData['customerPhone'] ?? 'N/A';
    final soldBy = saleData['soldBy'] ?? 'N/A';
    final totalAmount = (saleData['totalAmount'] as num?)?.toDouble() ?? 0;
    final saleDate = (saleData['saleDate'] as Timestamp?)?.toDate();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            const Expanded(child: Text('Sale Details')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Sale ID', saleId),
              const SizedBox(height: 12),
              _buildInfoRow('Customer', customerName),
              const SizedBox(height: 12),
              _buildInfoRow('Phone', customerPhone),
              const SizedBox(height: 12),
              _buildInfoRow('Sold By', soldBy),
              const SizedBox(height: 12),
              _buildInfoRow('Date & Time', _formatDateTime(saleDate)),

              const Divider(height: 32),

              const Text(
                'Items Purchased',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value as Map;
                final name = item['name'] ?? 'Unknown';
                final quantity = item['quantity'] ?? 0;
                final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0;
                final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0;

                return Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}. $name',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₦${unitPrice.toStringAsFixed(2)} x $quantity',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '₦${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              const Divider(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₦${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
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
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final formatter = DateFormat('MMM dd, yyyy • hh:mm a');
    return formatter.format(dateTime);
  }
}

// ===========================================================================
// STAFF ANALYTICS WIDGET - Comprehensive Performance Tracking
// ===========================================================================

/// Staff Analytics View - Track individual staff performance, prevent fraud,
/// improve transparency and accountability
class _StaffAnalyticsView extends StatefulWidget {
  final String facilityId;

  const _StaffAnalyticsView({required this.facilityId});

  @override
  State<_StaffAnalyticsView> createState() => _StaffAnalyticsViewState();
}

class _StaffAnalyticsViewState extends State<_StaffAnalyticsView> {
  String _selectedPeriod = 'today'; // today, week, month, custom
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Period Filter Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _getPeriodTitle(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                initialValue: _selectedPeriod,
                onSelected: (value) async {
                  if (value == 'custom') {
                    await _selectCustomDateRange();
                  } else {
                    setState(() {
                      _selectedPeriod = value;
                      _customStartDate = null;
                      _customEndDate = null;
                    });
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'today', child: Text('Today')),
                  const PopupMenuItem(value: 'week', child: Text('This Week')),
                  const PopupMenuItem(
                    value: 'month',
                    child: Text('This Month'),
                  ),
                  const PopupMenuItem(
                    value: 'custom',
                    child: Text('Custom Range'),
                  ),
                ],
                icon: const Icon(Icons.calendar_today),
                tooltip: 'Select Period',
              ),
            ],
          ),
        ),

        // Staff Analytics Content
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getSalesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              final allSales = snapshot.data?.docs ?? [];
              final filteredSales = _filterSalesByPeriod(allSales);
              final staffPerformance = _calculateStaffPerformance(
                filteredSales,
              );

              if (staffPerformance.isEmpty) {
                return _buildEmptyState();
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Overall Summary Card
                  _buildOverallSummaryCard(filteredSales, staffPerformance),
                  const SizedBox(height: 24),

                  // Top Performers Section
                  _buildTopPerformersSection(staffPerformance),
                  const SizedBox(height: 24),

                  // Individual Staff Performance Cards
                  const Text(
                    'Individual Staff Performance',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  ...staffPerformance.entries.map((entry) {
                    return _buildStaffPerformanceCard(
                      entry.key,
                      entry.value,
                      filteredSales,
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _getPeriodTitle() {
    switch (_selectedPeriod) {
      case 'today':
        return 'Today\'s Staff Performance';
      case 'week':
        return 'This Week\'s Staff Performance';
      case 'month':
        return 'This Month\'s Staff Performance';
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          final formatter = DateFormat('MMM dd');
          return '${formatter.format(_customStartDate!)} - ${formatter.format(_customEndDate!)}';
        }
        return 'Custom Period';
      default:
        return 'Staff Performance';
    }
  }

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = 'custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
    }
  }

  Stream<QuerySnapshot> _getSalesStream() {
    return FirebaseFirestore.instance
        .collection('pharmacy_sales')
        .where('facilityId', isEqualTo: widget.facilityId)
        .orderBy('saleDate', descending: true)
        .snapshots();
  }

  List<QueryDocumentSnapshot> _filterSalesByPeriod(
    List<QueryDocumentSnapshot> sales,
  ) {
    final now = DateTime.now();

    return sales.where((sale) {
      final data = sale.data() as Map<String, dynamic>;
      final saleDate = (data['saleDate'] as Timestamp?)?.toDate();

      if (saleDate == null) return false;

      switch (_selectedPeriod) {
        case 'today':
          return saleDate.year == now.year &&
              saleDate.month == now.month &&
              saleDate.day == now.day;
        case 'week':
          final weekAgo = now.subtract(const Duration(days: 7));
          return saleDate.isAfter(weekAgo);
        case 'month':
          return saleDate.year == now.year && saleDate.month == now.month;
        case 'custom':
          if (_customStartDate == null || _customEndDate == null) return false;
          return saleDate.isAfter(
                _customStartDate!.subtract(const Duration(days: 1)),
              ) &&
              saleDate.isBefore(_customEndDate!.add(const Duration(days: 1)));
        default:
          return true;
      }
    }).toList();
  }

  Map<String, Map<String, dynamic>> _calculateStaffPerformance(
    List<QueryDocumentSnapshot> sales,
  ) {
    print(
      '🔄 [STAFF ANALYTICS] Calculating performance for ${sales.length} sales',
    );

    final Map<String, Map<String, dynamic>> staffStats = {};

    for (var sale in sales) {
      final data = sale.data() as Map<String, dynamic>;
      final staffName = data['soldBy'] ?? 'Unknown';
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
      final items = data['items'] as List? ?? [];
      final saleDate = (data['saleDate'] as Timestamp?)?.toDate();

      int totalItems = 0;
      for (var item in items) {
        totalItems += ((item as Map)['quantity'] as num?)?.toInt() ?? 0;
      }

      if (!staffStats.containsKey(staffName)) {
        staffStats[staffName] = {
          'transactionCount': 0,
          'totalRevenue': 0.0,
          'totalItems': 0,
          'transactions': <Map<String, dynamic>>[],
          'averageSale': 0.0,
          'firstSale': saleDate,
          'lastSale': saleDate,
        };
      }

      staffStats[staffName]!['transactionCount'] =
          (staffStats[staffName]!['transactionCount'] as int) + 1;
      staffStats[staffName]!['totalRevenue'] =
          (staffStats[staffName]!['totalRevenue'] as double) + totalAmount;
      staffStats[staffName]!['totalItems'] =
          (staffStats[staffName]!['totalItems'] as int) + totalItems;

      (staffStats[staffName]!['transactions'] as List).add({
        'id': sale.id,
        'amount': totalAmount,
        'items': items.length,
        'date': saleDate,
        'customer': data['customerName'] ?? 'Unknown',
      });

      // Update first and last sale dates
      final firstSale = staffStats[staffName]!['firstSale'] as DateTime?;
      final lastSale = staffStats[staffName]!['lastSale'] as DateTime?;

      if (saleDate != null) {
        if (firstSale == null || saleDate.isBefore(firstSale)) {
          staffStats[staffName]!['firstSale'] = saleDate;
        }
        if (lastSale == null || saleDate.isAfter(lastSale)) {
          staffStats[staffName]!['lastSale'] = saleDate;
        }
      }
    }

    // Calculate average sale for each staff
    staffStats.forEach((staff, stats) {
      final transactionCount = stats['transactionCount'] as int;
      final totalRevenue = stats['totalRevenue'] as double;
      stats['averageSale'] = transactionCount > 0
          ? totalRevenue / transactionCount
          : 0.0;
    });

    print('✅ [STAFF ANALYTICS] Processed ${staffStats.length} staff members');
    return staffStats;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No staff sales data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sales made by staff will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallSummaryCard(
    List<QueryDocumentSnapshot> sales,
    Map<String, Map<String, dynamic>> staffPerformance,
  ) {
    double totalRevenue = 0;
    int totalTransactions = 0;
    int totalStaff = staffPerformance.length;

    staffPerformance.forEach((_, stats) {
      totalRevenue += stats['totalRevenue'] as double;
      totalTransactions += stats['transactionCount'] as int;
    });

    final averagePerStaff = totalStaff > 0 ? totalRevenue / totalStaff : 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.purple.shade700, Colors.purple.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                const Text(
                  'Overall Summary',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Revenue',
                    '₦${totalRevenue.toStringAsFixed(2)}',
                    Icons.account_balance_wallet,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Transactions',
                    totalTransactions.toString(),
                    Icons.receipt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Active Staff',
                    totalStaff.toString(),
                    Icons.people,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Avg per Staff',
                    '₦${averagePerStaff.toStringAsFixed(2)}',
                    Icons.trending_up,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformersSection(
    Map<String, Map<String, dynamic>> staffPerformance,
  ) {
    // Sort staff by revenue
    final sortedStaff = staffPerformance.entries.toList()
      ..sort(
        (a, b) => (b.value['totalRevenue'] as double).compareTo(
          a.value['totalRevenue'] as double,
        ),
      );

    final topThree = sortedStaff.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber[700], size: 28),
            const SizedBox(width: 8),
            const Text(
              'Top Performers',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ...topThree.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final staffName = entry.value.key;
          final stats = entry.value.value;

          IconData medalIcon;
          Color iconColor;
          Color backgroundColor;

          switch (rank) {
            case 1:
              backgroundColor = Colors.amber.withOpacity(0.2);
              iconColor = Colors.amber.shade700;
              medalIcon = Icons.looks_one;
              break;
            case 2:
              backgroundColor = Colors.grey.withOpacity(0.2);
              iconColor = Colors.grey.shade700;
              medalIcon = Icons.looks_two;
              break;
            case 3:
              backgroundColor = Colors.brown.withOpacity(0.2);
              iconColor = Colors.brown.shade700;
              medalIcon = Icons.looks_3;
              break;
            default:
              backgroundColor = Colors.grey.withOpacity(0.2);
              iconColor = Colors.grey.shade700;
              medalIcon = Icons.star;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: rank == 1 ? 4 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: rank == 1
                  ? BorderSide(color: Colors.amber.shade700, width: 2)
                  : BorderSide.none,
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(medalIcon, color: iconColor, size: 28),
              ),
              title: Text(
                staffName,
                style: TextStyle(
                  fontWeight: rank == 1 ? FontWeight.bold : FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '${stats['transactionCount']} sales • ${stats['totalItems']} items',
                style: const TextStyle(fontSize: 13),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₦${(stats['totalRevenue'] as double).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  Text(
                    'Revenue',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStaffPerformanceCard(
    String staffName,
    Map<String, dynamic> stats,
    List<QueryDocumentSnapshot> allSales,
  ) {
    final transactionCount = stats['transactionCount'] as int;
    final totalRevenue = stats['totalRevenue'] as double;
    final totalItems = stats['totalItems'] as int;
    final averageSale = stats['averageSale'] as double;
    final transactions = stats['transactions'] as List<Map<String, dynamic>>;

    // Fraud detection: flag unusually high sales (3x above average)
    final unusuallyHighSales = transactions
        .where((t) => (t['amount'] as double) > (averageSale * 3))
        .length;

    final firstSale = stats['firstSale'] as DateTime?;
    final lastSale = stats['lastSale'] as DateTime?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            radius: 28,
            child: Text(
              staffName.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          title: Text(
            staffName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$transactionCount transaction(s) • $totalItems item(s) sold',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₦${totalRevenue.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              Text(
                'Total Revenue',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
          children: [
            const Divider(height: 24),

            // Performance Metrics
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Avg Sale',
                    '₦${averageSale.toStringAsFixed(2)}',
                    Icons.show_chart,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Items/Sale',
                    (totalItems / transactionCount).toStringAsFixed(1),
                    Icons.shopping_cart,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Activity Period
            if (firstSale != null && lastSale != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Activity Period',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${DateFormat('MMM dd, hh:mm a').format(firstSale)} - ${DateFormat('MMM dd, hh:mm a').format(lastSale)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Fraud Detection Alerts
            if (unusuallyHighSales > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ $unusuallyHighSales transaction(s) significantly above average - Review recommended',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // View Transactions Button
            OutlinedButton.icon(
              onPressed: () => _showStaffTransactions(staffName, transactions),
              icon: const Icon(Icons.receipt_long),
              label: const Text('View All Transactions'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
        ],
      ),
    );
  }

  void _showStaffTransactions(
    String staffName,
    List<Map<String, dynamic>> transactions,
  ) {
    // Sort transactions by date (most recent first)
    transactions.sort((a, b) {
      final dateA = a['date'] as DateTime?;
      final dateB = b['date'] as DateTime?;
      if (dateA == null || dateB == null) return 0;
      return dateB.compareTo(dateA);
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 24,
                      child: Text(
                        staffName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            staffName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${transactions.length} transactions',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Transaction List
              Expanded(
                child: transactions.isEmpty
                    ? const Center(child: Text('No transactions'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = transactions[index];
                          final amount = transaction['amount'] as double;
                          final items = transaction['items'] as int;
                          final date = transaction['date'] as DateTime?;
                          final customer = transaction['customer'] as String;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green.shade100,
                                child: Icon(
                                  Icons.receipt,
                                  color: Colors.green.shade700,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                customer,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    date != null
                                        ? DateFormat(
                                            'MMM dd, yyyy • hh:mm a',
                                          ).format(date)
                                        : 'N/A',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '$items item(s)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Text(
                                '₦${amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
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
}
