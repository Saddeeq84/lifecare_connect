import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_facilities_list_screen.dart';

class RegisteredFacilitiesMenuScreen extends StatefulWidget {
  const RegisteredFacilitiesMenuScreen({super.key});

  @override
  State<RegisteredFacilitiesMenuScreen> createState() =>
      _RegisteredFacilitiesMenuScreenState();
}

class _RegisteredFacilitiesMenuScreenState
    extends State<RegisteredFacilitiesMenuScreen> {
  bool isLoading = true;
  int totalFacilities = 0;
  int totalTrainings = 0;
  Map<String, int> facilityCategories = {
    'hospitals': 0,
    'laboratories': 0,
    'pharmacies': 0,
    'scan_centers': 0,
    'others': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadFacilityStats();
  }

  Future<void> _loadFacilityStats() async {
    try {
      print('📊 [FACILITY ANALYTICS] Loading facility statistics...');

      // Get health facilities from healthFacilities collection
      final healthFacilitiesSnapshot = await FirebaseFirestore.instance
          .collection('healthFacilities')
          .get();

      // Get facility users from users collection with role 'facility'
      final facilityUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'facility')
          .get();

      // Get training sessions
      final trainingsSnapshot = await FirebaseFirestore.instance
          .collection('trainings')
          .get();

      print(
        '✅ [FACILITY ANALYTICS] Found ${healthFacilitiesSnapshot.docs.length} healthFacilities documents',
      );
      print(
        '✅ [FACILITY ANALYTICS] Found ${facilityUsersSnapshot.docs.length} facility user documents',
      );

      // Initialize category counters
      Map<String, int> categories = {
        'hospitals': 0,
        'laboratories': 0,
        'pharmacies': 0,
        'scan_centers': 0,
        'others': 0,
      };

      // Process healthFacilities collection
      for (var doc in healthFacilitiesSnapshot.docs) {
        final data = doc.data();
        final type = (data['type'] ?? '').toString().toLowerCase().trim();

        print('🔍 [healthFacilities] ${data['name']}: type="$type"');

        if (type.contains('hospital') ||
            type.contains('clinic') ||
            type.contains('phc')) {
          categories['hospitals'] = (categories['hospitals'] ?? 0) + 1;
        } else if (type.contains('laboratory') || type.contains('lab')) {
          categories['laboratories'] = (categories['laboratories'] ?? 0) + 1;
        } else if (type.contains('pharmacy') || type.contains('drug')) {
          categories['pharmacies'] = (categories['pharmacies'] ?? 0) + 1;
        } else if (type.contains('scan') ||
            type.contains('imaging') ||
            type.contains('diagnostic') ||
            type.contains('radiology')) {
          categories['scan_centers'] = (categories['scan_centers'] ?? 0) + 1;
        } else if (type.isNotEmpty) {
          categories['others'] = (categories['others'] ?? 0) + 1;
        }
      }

      // Process facility users collection
      for (var doc in facilityUsersSnapshot.docs) {
        final data = doc.data();
        final type = (data['type'] ?? '').toString().toLowerCase().trim();
        final profession = (data['profession'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        final facilityType = (data['facilityType'] ?? '')
            .toString()
            .toLowerCase()
            .trim();

        // Use whichever field has data (type, profession, or facilityType)
        final effectiveType = type.isNotEmpty
            ? type
            : (profession.isNotEmpty ? profession : facilityType);

        print(
          '🔍 [users] ${data['name']}: type="$type", profession="$profession", facilityType="$facilityType" → effectiveType="$effectiveType"',
        );

        if (effectiveType.contains('hospital') ||
            effectiveType.contains('clinic') ||
            effectiveType.contains('phc')) {
          categories['hospitals'] = (categories['hospitals'] ?? 0) + 1;
        } else if (effectiveType.contains('laboratory') ||
            effectiveType.contains('lab')) {
          categories['laboratories'] = (categories['laboratories'] ?? 0) + 1;
        } else if (effectiveType.contains('pharmacy') ||
            effectiveType.contains('drug')) {
          categories['pharmacies'] = (categories['pharmacies'] ?? 0) + 1;
        } else if (effectiveType.contains('scan') ||
            effectiveType.contains('imaging') ||
            effectiveType.contains('diagnostic') ||
            effectiveType.contains('radiology')) {
          categories['scan_centers'] = (categories['scan_centers'] ?? 0) + 1;
        } else if (effectiveType.isNotEmpty) {
          categories['others'] = (categories['others'] ?? 0) + 1;
        }
      }

      final totalCount =
          healthFacilitiesSnapshot.docs.length +
          facilityUsersSnapshot.docs.length;

      print('📊 [FACILITY ANALYTICS] Summary:');
      print('   Total Facilities: $totalCount');
      print('   Hospitals/Clinics: ${categories['hospitals']}');
      print('   Laboratories: ${categories['laboratories']}');
      print('   Pharmacies: ${categories['pharmacies']}');
      print('   Scan Centers: ${categories['scan_centers']}');
      print('   Others: ${categories['others']}');

      setState(() {
        totalFacilities = totalCount;
        totalTrainings = trainingsSnapshot.docs.length;
        facilityCategories = categories;
        isLoading = false;
      });
    } catch (e) {
      print('❌ [FACILITY ANALYTICS] Error loading stats: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registered Facilities'),
        backgroundColor: Colors.indigo.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Facility Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage health facilities and registrations',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _buildMenuCard(
                    context,
                    icon: Icons.business,
                    title: 'Facilities List',
                    subtitle:
                        'View all registered facilities (pending & approved)',
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AdminFacilitiesListScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    context,
                    icon: Icons.add_business,
                    title: 'Register New Facility',
                    subtitle: 'Add a new health facility to the system',
                    color: Colors.teal,
                    onTap: () {
                      context.push('/admin_dashboard/register_facility');
                    },
                  ),
                  const SizedBox(height: 24),
                  // Facilities Analytics Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.analytics,
                                color: Colors.indigo.shade700,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Facilities Analytics',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (isLoading)
                            const Center(child: CircularProgressIndicator())
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Total facilities and trainings
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatBox(
                                        'Total Facilities',
                                        totalFacilities.toString(),
                                        Icons.local_hospital,
                                        Colors.teal,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatBox(
                                        'Training Programs',
                                        totalTrainings.toString(),
                                        Icons.school,
                                        Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Facility categories
                                Text(
                                  'Facility Categories',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 2.5,
                                  children: [
                                    _buildCategoryCard(
                                      'Hospitals/Clinics',
                                      facilityCategories['hospitals'] ?? 0,
                                      Icons.local_hospital,
                                      Colors.red,
                                    ),
                                    _buildCategoryCard(
                                      'Laboratories',
                                      facilityCategories['laboratories'] ?? 0,
                                      Icons.biotech,
                                      Colors.purple,
                                    ),
                                    _buildCategoryCard(
                                      'Pharmacies',
                                      facilityCategories['pharmacies'] ?? 0,
                                      Icons.local_pharmacy,
                                      Colors.orange,
                                    ),
                                    _buildCategoryCard(
                                      'Scan Centers',
                                      facilityCategories['scan_centers'] ?? 0,
                                      Icons.medical_services,
                                      Colors.blue,
                                    ),
                                  ],
                                ),

                                // Others category if there are any
                                if ((facilityCategories['others'] ?? 0) >
                                    0) ...[
                                  const SizedBox(height: 12),
                                  _buildCategoryCard(
                                    'Other Facilities',
                                    facilityCategories['others'] ?? 0,
                                    Icons.business,
                                    Colors.grey,
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    String label,
    int value,
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
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
