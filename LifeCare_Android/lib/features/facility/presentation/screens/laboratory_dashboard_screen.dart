import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'lab_results_entry_screen.dart';
import 'sample_management_screen.dart';
import 'laboratory_reports_analytics_screen.dart';
import '../widgets/staff_password_change_dialog.dart';
import '../../../shared/presentation/screens/ai_assistant_screen.dart';
import '../../../shared/presentation/widgets/resource_popup_button.dart';

/// Laboratory Department Dashboard
/// Accessible by: Lab Scientists, Lab Technicians, Lab Assistants, Phlebotomists, Pathologists, Lab Managers
class LaboratoryDashboardScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const LaboratoryDashboardScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<LaboratoryDashboardScreen> createState() =>
      _LaboratoryDashboardScreenState();
}

class _LaboratoryDashboardScreenState extends State<LaboratoryDashboardScreen> {
  // Navigation methods
  void _navigateToTestRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LabResultsEntryScreen(
          facilityId: widget.facilityId,
          laboratoryStaffId: widget.staffId,
          laboratoryStaffName: widget.staffName,
        ),
      ),
    );
  }

  void _navigateToSampleCollection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SampleManagementScreen(
          facilityId: widget.facilityId,
          staffId: widget.staffId,
          staffName: widget.staffName,
        ),
      ),
    );
  }

  void _navigateToReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LaboratoryReportsAnalyticsScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      try {
        await FirebaseAuth.instance.signOut();
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.facilityName} - Laboratory'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
          const ResourcePopupButton(assistantType: AIAssistantType.doctor),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => StaffPasswordChangeDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            const SizedBox(height: 24),
            Text(
              'Laboratory Services',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            _buildDashboardGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade700, Colors.purple.shade500],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.biotech, size: 32, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${widget.staffName}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Laboratory Department',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.purple.shade100,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid(BuildContext context) {
    final items = [
      {
        'title': 'Test Requests & Results',
        'subtitle': 'View requests and enter results',
        'icon': Icons.assignment,
        'color': Colors.purple,
        'onTap': _navigateToTestRequests,
      },
      {
        'title': 'Sample Collection',
        'subtitle': 'Manage sample collection',
        'icon': Icons.bloodtype,
        'color': Colors.red,
        'onTap': _navigateToSampleCollection,
      },
      {
        'title': 'Reports & Analytics',
        'subtitle': 'View statistics and reports',
        'icon': Icons.assessment,
        'color': Colors.green,
        'onTap': _navigateToReports,
      },
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildCard(
            context,
            item['title'] as String,
            item['subtitle'] as String,
            item['icon'] as IconData,
            item['color'] as Color,
            item['onTap'] as VoidCallback,
          ),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 28, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade400,
        ),
        onTap: onTap,
      ),
    );
  }
}
