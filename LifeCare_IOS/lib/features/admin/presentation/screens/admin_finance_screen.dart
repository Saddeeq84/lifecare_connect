import 'admin_withdrawal_approvals_screen.dart';
import 'package:flutter/material.dart';
import 'admin_wallet_screen.dart';
import 'bulk_payment_screen.dart';
import '../../../shared/data/services/wallet_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'admin_fee_management_screen.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _adminBalance = 0.0;
  final String _adminWalletId = 'admin_wallet';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAdminBalance();
  }

  Future<void> _loadAdminBalance() async {
    final balance = await WalletService.getBalance(userId: _adminWalletId);
    if (mounted) {
      setState(() {
        _adminBalance = balance;
      });
    }
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
        title: const Text('Financial Management'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard),
            tooltip: 'Pay Bonuses',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      BulkPaymentScreen(adminBalance: _adminBalance),
                ),
              );
              if (result == true) {
                await _loadAdminBalance();
                // Refresh the admin wallet tab if it's currently active
                if (_tabController.index == 0) {
                  // Trigger refresh for the wallet tab
                  setState(() {});
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.verified_user),
            tooltip: 'Withdrawal Approvals',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminWithdrawalApprovalsScreen(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Admin Wallet', icon: Icon(Icons.account_balance_wallet)),
            Tab(text: 'Financial Reports', icon: Icon(Icons.bar_chart)),
            Tab(text: 'Balance Sheet', icon: Icon(Icons.receipt_long)),
            Tab(text: 'Fee Management', icon: Icon(Icons.monetization_on)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AdminWalletTab(),
          _FinancialReportsTab(),
          _BalanceSheetTab(),
          _FeeManagementTab(),
        ],
      ),
    );
  }
}

class _AdminWalletTab extends StatelessWidget {
  const _AdminWalletTab();

  @override
  Widget build(BuildContext context) {
    return const AdminWalletScreen();
  }
}

class _FinancialReportsTab extends StatefulWidget {
  const _FinancialReportsTab();

  @override
  State<_FinancialReportsTab> createState() => _FinancialReportsTabState();
}

class _FinancialReportsTabState extends State<_FinancialReportsTab> {
  String _selectedPeriod = 'Today';
  final List<String> _periods = [
    'Today',
    'This Week',
    'This Month',
    'This Year',
    'All Time',
  ];
  bool _loading = true;
  Map<String, dynamic> _reportData = {};

  @override
  void initState() {
    super.initState();
    _loadFinancialReport();
  }

  Future<void> _loadFinancialReport() async {
    setState(() => _loading = true);

    try {
      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'This Week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'This Year':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = DateTime(2020, 1, 1); // All time
      }

      // Fetch all wallet data
      final walletsSnapshot = await FirebaseFirestore.instance
          .collection('wallets')
          .get();

      double totalRevenue = 0;
      double totalWithdrawals = 0;
      double totalDeposits = 0;
      int totalTransactions = 0;
      Map<String, double> userIncomes = {};
      Map<String, int> transactionsByType = {};

      for (var doc in walletsSnapshot.docs) {
        final data = doc.data();
        final transactions = data['transactions'] as List<dynamic>? ?? [];

        for (var txn in transactions) {
          final tx = txn as Map<String, dynamic>;
          final timestamp = tx['timestamp'];
          DateTime? txDate;

          if (timestamp is Timestamp) {
            txDate = timestamp.toDate();
          } else if (timestamp is String) {
            txDate = DateTime.tryParse(timestamp);
          }

          if (txDate != null && txDate.isAfter(startDate)) {
            final type = tx['type'] as String? ?? 'unknown';
            final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

            totalTransactions++;
            transactionsByType[type] = (transactionsByType[type] ?? 0) + 1;

            if (type == 'fund' || type == 'credit') {
              totalDeposits += amount;
            } else if (type == 'withdrawal') {
              totalWithdrawals += amount;
            } else if (type == 'admin_commission') {
              totalRevenue += amount;
            }

            // Track user income
            if (type.contains('earning') || type == 'credit') {
              final userId = doc.id;
              userIncomes[userId] = (userIncomes[userId] ?? 0) + amount;
            }
          }
        }
      }

      setState(() {
        _reportData = {
          'totalRevenue': totalRevenue,
          'totalWithdrawals': totalWithdrawals,
          'totalDeposits': totalDeposits,
          'totalTransactions': totalTransactions,
          'userIncomes': userIncomes,
          'transactionsByType': transactionsByType,
        };
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading report: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.indigo.shade50,
          child: Row(
            children: [
              const Text(
                'Period: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedPeriod,
                items: _periods.map((period) {
                  return DropdownMenuItem(value: period, child: Text(period));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedPeriod = value);
                    _loadFinancialReport();
                  }
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadFinancialReport,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildReportContent(),
        ),
      ],
    );
  }

  Widget _buildReportContent() {
    final totalRevenue = _reportData['totalRevenue'] ?? 0.0;
    final totalWithdrawals = _reportData['totalWithdrawals'] ?? 0.0;
    final totalDeposits = _reportData['totalDeposits'] ?? 0.0;
    final totalTransactions = _reportData['totalTransactions'] ?? 0;
    final userIncomes =
        _reportData['userIncomes'] as Map<String, double>? ?? {};
    final transactionsByType =
        _reportData['transactionsByType'] as Map<String, int>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Revenue',
                  '₦${NumberFormat('#,##0.00').format(totalRevenue)}',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Deposits',
                  '₦${NumberFormat('#,##0.00').format(totalDeposits)}',
                  Icons.arrow_downward,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Withdrawals',
                  '₦${NumberFormat('#,##0.00').format(totalWithdrawals)}',
                  Icons.arrow_upward,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Transactions',
                  totalTransactions.toString(),
                  Icons.receipt_long,
                  Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Transaction Types Breakdown
          const Text(
            'Transactions by Type',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: transactionsByType.isEmpty
                  ? const Text('No transactions in this period')
                  : Column(
                      children: transactionsByType.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${entry.value} transactions',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Top Earners
          const Text(
            'Top Earners',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: userIncomes.isEmpty
                  ? const Text('No earnings in this period')
                  : Column(children: _buildTopEarners(userIncomes)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTopEarners(Map<String, double> userIncomes) {
    final sortedEntries = userIncomes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topEarners = sortedEntries.take(10).toList();

    return topEarners.asMap().entries.map((entry) {
      final index = entry.key;
      final earner = entry.value;

      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(earner.key)
            .get(),
        builder: (context, snapshot) {
          String userName = 'User ${earner.key.substring(0, 8)}...';
          String role = 'Unknown';

          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            userName = userData['name'] ?? userName;
            role = userData['role'] ?? role;
          }

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: index < 3 ? Colors.amber : Colors.grey.shade300,
              child: Text('${index + 1}'),
            ),
            title: Text(userName),
            subtitle: Text(role.toUpperCase()),
            trailing: Text(
              '₦${NumberFormat('#,##0.00').format(earner.value)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          );
        },
      );
    }).toList();
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
    );
  }
}

class _BalanceSheetTab extends StatefulWidget {
  const _BalanceSheetTab();

  @override
  State<_BalanceSheetTab> createState() => _BalanceSheetTabState();
}

class _BalanceSheetTabState extends State<_BalanceSheetTab> {
  String _selectedPeriod = 'Today';
  final List<String> _periods = [
    'Today',
    'This Week',
    'This Month',
    'This Year',
    'All Time',
  ];
  bool _loading = true;
  List<Map<String, dynamic>> _allTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadBalanceSheet();
  }

  Future<void> _loadBalanceSheet() async {
    setState(() => _loading = true);

    try {
      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'This Week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'This Year':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = DateTime(2020, 1, 1); // All time
      }

      // Fetch all wallet transactions
      final walletsSnapshot = await FirebaseFirestore.instance
          .collection('wallets')
          .get();

      List<Map<String, dynamic>> allTransactions = [];

      for (var doc in walletsSnapshot.docs) {
        final data = doc.data();
        final userId = doc.id;
        final transactions = data['transactions'] as List<dynamic>? ?? [];

        for (var txn in transactions) {
          final tx = txn as Map<String, dynamic>;
          final timestamp = tx['timestamp'];
          DateTime? txDate;

          if (timestamp is Timestamp) {
            txDate = timestamp.toDate();
          } else if (timestamp is String) {
            txDate = DateTime.tryParse(timestamp);
          }

          if (txDate != null && txDate.isAfter(startDate)) {
            allTransactions.add({
              'userId': userId,
              'type': tx['type'] ?? 'unknown',
              'amount': (tx['amount'] as num?)?.toDouble() ?? 0.0,
              'description': tx['description'] ?? 'No description',
              'timestamp': txDate,
            });
          }
        }
      }

      // Sort by timestamp (most recent first)
      allTransactions.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );

      setState(() {
        _allTransactions = allTransactions;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading balance sheet: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.indigo.shade50,
          child: Row(
            children: [
              const Text(
                'Period: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedPeriod,
                items: _periods.map((period) {
                  return DropdownMenuItem(value: period, child: Text(period));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedPeriod = value);
                    _loadBalanceSheet();
                  }
                },
              ),
              const Spacer(),
              Text(
                '${_allTransactions.length} Transactions',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadBalanceSheet,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildBalanceSheetContent(),
        ),
      ],
    );
  }

  Widget _buildBalanceSheetContent() {
    if (_allTransactions.isEmpty) {
      return const Center(child: Text('No transactions in this period'));
    }

    // Calculate summary
    double totalCredits = 0;
    double totalDebits = 0;

    for (var tx in _allTransactions) {
      final type = tx['type'] as String;
      final amount = tx['amount'] as double;

      if (type == 'fund' ||
          type == 'credit' ||
          type.contains('earning') ||
          type == 'admin_commission') {
        totalCredits += amount;
      } else if (type == 'deduct' || type == 'withdrawal') {
        totalDebits += amount;
      }
    }

    final netBalance = totalCredits - totalDebits;

    return Column(
      children: [
        // Summary Section
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBalanceSummaryItem(
                'Total Credits',
                totalCredits,
                Colors.green,
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade400),
              _buildBalanceSummaryItem('Total Debits', totalDebits, Colors.red),
              Container(width: 1, height: 40, color: Colors.grey.shade400),
              _buildBalanceSummaryItem(
                'Net Balance',
                netBalance,
                netBalance >= 0 ? Colors.blue : Colors.orange,
              ),
            ],
          ),
        ),

        // Transactions List
        Expanded(
          child: ListView.builder(
            itemCount: _allTransactions.length,
            itemBuilder: (context, index) {
              final tx = _allTransactions[index];
              return _buildTransactionTile(tx);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '₦${NumberFormat('#,##0.00').format(amount)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> tx) {
    final type = tx['type'] as String;
    final amount = tx['amount'] as double;
    final description = tx['description'] as String;
    final timestamp = tx['timestamp'] as DateTime;
    final userId = tx['userId'] as String;

    final isCredit =
        type == 'fund' ||
        type == 'credit' ||
        type.contains('earning') ||
        type == 'admin_commission';
    final color = isCredit ? Colors.green : Colors.red;
    final icon = isCredit ? Icons.arrow_downward : Icons.arrow_upward;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        String userName = 'User ${userId.substring(0, 8)}...';
        String role = 'Unknown';

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          userName = userData['name'] ?? userName;
          role = userData['role'] ?? role;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(
              description,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$userName ($role)'),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : '-'}₦${NumberFormat('#,##0.00').format(amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                Text(
                  type.toUpperCase(),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class _FeeManagementTab extends StatelessWidget {
  const _FeeManagementTab();

  @override
  Widget build(BuildContext context) {
    return const AdminFeeManagementScreen();
  }
}
