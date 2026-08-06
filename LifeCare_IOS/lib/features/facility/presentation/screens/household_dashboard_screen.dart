// Household Dashboard Screen
// Main dashboard for household with Members and Wallet

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'household_members_screen.dart';
import 'household_wallet_screen.dart';

class HouseholdDashboardScreen extends StatefulWidget {
  final String householdId;
  final String facilityId;

  const HouseholdDashboardScreen({
    super.key,
    required this.householdId,
    required this.facilityId,
  });

  @override
  State<HouseholdDashboardScreen> createState() =>
      _HouseholdDashboardScreenState();
}

class _HouseholdDashboardScreenState extends State<HouseholdDashboardScreen> {
  Map<String, dynamic>? _householdData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHouseholdData();
  }

  Future<void> _loadHouseholdData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('households')
          .doc(widget.householdId)
          .get();

      if (doc.exists) {
        setState(() {
          _householdData = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading household: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_householdData?['householdName'] ?? 'Household Dashboard'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _householdData == null
          ? const Center(child: Text('Household not found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Household Info Card
                  Card(
                    elevation: 4,
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
                              Icon(
                                Icons.home,
                                size: 40,
                                color: Colors.teal.shade700,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _householdData!['householdName'] ?? 'N/A',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Leader: ${_householdData!['householdLeader'] ?? 'N/A'}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            Icons.location_on,
                            'Community',
                            _householdData!['community'] ?? 'N/A',
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.home_work,
                            'Address',
                            _householdData!['address'] ?? 'N/A',
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.phone,
                            'Phone',
                            _householdData!['phoneNumber'] ?? 'N/A',
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.electric_meter,
                            'Meter Number',
                            _householdData!['meterNumber'] ?? 'N/A',
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.group,
                            'Members',
                            '${_householdData!['beneficiaryCount'] ?? 0}/6',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Dashboard Items
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  Column(
                    children: [
                      _buildDashboardListItem(
                        icon: Icons.group,
                        label: 'Members',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HouseholdMembersScreen(
                                householdId: widget.householdId,
                                facilityId: widget.facilityId,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDashboardListItem(
                        icon: Icons.account_balance_wallet,
                        label: 'Wallet',
                        color: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HouseholdWalletScreen(
                                householdId: widget.householdId,
                                householdName:
                                    _householdData!['householdName'] ?? 'N/A',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
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

  Widget _buildDashboardListItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 28, color: color),
        ),
        title: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}
