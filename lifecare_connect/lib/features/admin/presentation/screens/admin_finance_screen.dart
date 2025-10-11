import 'admin_withdrawal_approvals_screen.dart';
import 'package:flutter/material.dart';
import 'admin_wallet_screen.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
        title: const Text('Finance'),
        backgroundColor: Colors.indigo,
        actions: [
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
          tabs: const [
            Tab(text: 'Admin Wallet', icon: Icon(Icons.account_balance_wallet)),
            Tab(text: 'Financial Reports', icon: Icon(Icons.bar_chart)),
            Tab(text: 'Balance Sheet', icon: Icon(Icons.receipt_long)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AdminWalletTab(),
          _FinancialReportsTab(),
          _BalanceSheetTab(),
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

class _FinancialReportsTab extends StatelessWidget {
  const _FinancialReportsTab();

  @override
  Widget build(BuildContext context) {
    // TODO: Implement user income tracking and summary reports (daily, weekly, monthly, annually)
    return Center(
      child: Text('Financial Reports (User Income, Summaries)'),
    );
  }
}

class _BalanceSheetTab extends StatelessWidget {
  const _BalanceSheetTab();

  @override
  Widget build(BuildContext context) {
    // TODO: Implement payments, deposits, and summary financial report (daily, weekly, monthly, annually)
    return Center(
      child: Text('Balance Sheet (Payments, Deposits, Summary)'),
    );
  }
}
