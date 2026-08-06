import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminBalanceDashboard extends StatefulWidget {
  const AdminBalanceDashboard({super.key});

  @override
  State<AdminBalanceDashboard> createState() => _AdminBalanceDashboardState();
}

class _AdminBalanceDashboardState extends State<AdminBalanceDashboard> {
  Map<String, dynamic>? _balanceReport;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBalanceReport();
  }

  Future<void> _loadBalanceReport() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getBalanceReport')
          .call();
      if (mounted) {
        setState(() {
          _balanceReport = result.data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Balance Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadBalanceReport,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorWidget()
          : _buildDashboard(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $_error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadBalanceReport,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    if (_balanceReport == null) return const SizedBox();

    final paystack = _balanceReport!['paystack'];
    final withdrawals = _balanceReport!['withdrawals'];
    final recommendations = _balanceReport!['recommendations'];
    final timestamp = _balanceReport!['timestamp'];

    return RefreshIndicator(
      onRefresh: _loadBalanceReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Card(
            color: Colors.indigo.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance,
                        color: Colors.indigo.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Paystack Balance Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last updated: ${DateTime.parse(timestamp).toLocal()}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Paystack Balance Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Paystack Balance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '₦${paystack['totalBalance']?.toStringAsFixed(2) ?? '0.00'}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  Text(
                    paystack['currency'] ?? 'NGN',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Withdrawals Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.money_off, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Pending Withdrawals',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reserve Needed:',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      Text(
                        '₦${withdrawals['reserveNeeded']?.toStringAsFixed(2) ?? '0.00'}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pending Count:',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      Text(
                        '${withdrawals['pendingCount'] ?? 0}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Recommendations Card
          Card(
            color: recommendations['status'] == 'safe_to_payout'
                ? Colors.green.shade50
                : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        recommendations['status'] == 'safe_to_payout'
                            ? Icons.check_circle
                            : Icons.warning,
                        color: recommendations['status'] == 'safe_to_payout'
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Recommendations',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: recommendations['status'] == 'safe_to_payout'
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (recommendations['status'] == 'safe_to_payout') ...[
                    Text(
                      'Safe to transfer to bank: ₦${recommendations['safeToTransferToBank']?.toStringAsFixed(2) ?? '0.00'}',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '✅ You can safely transfer excess funds to your bank account while keeping enough for pending withdrawals.',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ] else ...[
                    Text(
                      'Hold in Paystack: ₦${recommendations['shouldHoldInPaystack']?.toStringAsFixed(2) ?? '0.00'}',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '⚠️ Keep sufficient balance in Paystack for pending withdrawals. Consider transferring funds from bank to Paystack.',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showFundingGuidance,
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Funding Guidance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loadBalanceReport,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Pending Withdrawals List
          if (withdrawals['details'] != null &&
              withdrawals['details'].isNotEmpty) ...[
            Text(
              'Pending Withdrawals (${withdrawals['pendingCount']})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...withdrawals['details']
                .map<Widget>(
                  (withdrawal) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: withdrawal['status'] == 'pending'
                            ? Colors.orange
                            : Colors.blue,
                        child: Text(
                          '₦',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(withdrawal['accountName'] ?? 'Unknown'),
                      subtitle: Text(
                        'Status: ${withdrawal['status']?.toUpperCase() ?? 'UNKNOWN'}',
                      ),
                      trailing: Text(
                        '₦${withdrawal['amount']?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                )
                .toList(),
          ],
        ],
      ),
    );
  }

  Future<void> _showFundingGuidance() async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getFundingGuidance')
          .call();
      final guidance = result.data;

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('💰 Funding Guidance'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guidance['currentSituation']['shortfall'] > 0
                        ? 'FUNDING REQUIRED'
                        : 'SUFFICIENT BALANCE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: guidance['currentSituation']['shortfall'] > 0
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paystack Balance: ₦${guidance['currentSituation']['paystackBalance']?.toStringAsFixed(2)}',
                  ),
                  Text(
                    'Pending Withdrawals: ₦${guidance['currentSituation']['pendingWithdrawals']?.toStringAsFixed(2)}',
                  ),
                  if (guidance['currentSituation']['shortfall'] > 0)
                    Text(
                      'Required Transfer: ₦${guidance['currentSituation']['shortfall']?.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (guidance['guidance']['steps'] != null) ...[
                    const Text(
                      'Steps:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...guidance['guidance']['steps'].map<Widget>(
                      (step) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(step.toString()),
                      ),
                    ),
                  ],
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get funding guidance: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
