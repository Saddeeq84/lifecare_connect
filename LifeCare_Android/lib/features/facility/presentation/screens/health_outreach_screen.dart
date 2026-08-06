// Health Outreach Screen
// Community health outreach and mobile clinic services
// Following WHO Community Health Best Practices

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HealthOutreachScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const HealthOutreachScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<HealthOutreachScreen> createState() => _HealthOutreachScreenState();
}

class _HealthOutreachScreenState extends State<HealthOutreachScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        title: const Text('Health Outreach'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Outreach Activities'),
            Tab(text: 'Mobile Clinics'),
            Tab(text: 'Community Visits'),
            Tab(text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOutreachActivitiesTab(),
          _buildMobileClinicsTab(),
          _buildCommunityVisitsTab(),
          _buildReportsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewOutreachForm(context),
        backgroundColor: Colors.indigo.shade700,
        icon: const Icon(Icons.add),
        label: const Text('New Outreach'),
      ),
    );
  }

  Widget _buildOutreachActivitiesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Statistics Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('This Month', '0', Colors.blue),
              _buildStatColumn('Communities', '0', Colors.green),
              _buildStatColumn('People Reached', '0', Colors.orange),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Community Outreach Programs',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        _buildOutreachTypeCard(
          title: 'Mass Immunization Campaign',
          description:
              'Community-wide vaccination drives for children and adults',
          icon: Icons.vaccines,
          color: Colors.blue,
          services: [
            'Routine childhood immunization',
            'Maternal tetanus toxoid vaccination',
            'Mass measles vaccination',
            'COVID-19 vaccination drives',
          ],
        ),
        _buildOutreachTypeCard(
          title: 'Health Screening Programs',
          description: 'Free health screenings in communities',
          icon: Icons.health_and_safety,
          color: Colors.green,
          services: [
            'Blood pressure screening',
            'Diabetes screening',
            'Malaria testing',
            'HIV/AIDS screening',
            'Eye screening',
          ],
        ),
        _buildOutreachTypeCard(
          title: 'Mobile Clinic Services',
          description: 'Medical services in underserved areas',
          icon: Icons.local_hospital,
          color: Colors.orange,
          services: [
            'General consultations',
            'Maternal and child health',
            'Minor treatments',
            'Drug distribution',
          ],
        ),
        _buildOutreachTypeCard(
          title: 'Health Education Sessions',
          description: 'Community health talks and demonstrations',
          icon: Icons.school,
          color: Colors.purple,
          services: [
            'Disease prevention talks',
            'Nutrition education',
            'Hygiene promotion',
            'Family planning counseling',
          ],
        ),
        _buildOutreachTypeCard(
          title: 'Environmental Sanitation',
          description: 'Community clean-up and sanitation drives',
          icon: Icons.cleaning_services,
          color: Colors.teal,
          services: [
            'Community clean-up campaigns',
            'Waste management training',
            'Water source protection',
            'Latrine construction support',
          ],
        ),
        _buildOutreachTypeCard(
          title: 'Disease Outbreak Response',
          description: 'Emergency community interventions',
          icon: Icons.warning,
          color: Colors.red,
          services: [
            'Contact tracing',
            'Mass drug administration',
            'Isolation and quarantine support',
            'Community risk communication',
          ],
        ),

        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('health_outreach_activities')
              .where('facilityId', isEqualTo: widget.facilityId)
              .orderBy('activityDate', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final activities = snapshot.data?.docs ?? [];

            if (activities.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No outreach activities recorded'),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Activities',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...activities.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildActivityCard(data);
                }),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildOutreachTypeCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required List<String> services,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Services Provided:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...services.map(
                  (service) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check, size: 16, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            service,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showNewOutreachForm(context, activityType: title),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Plan This Activity'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> data) {
    final activity = data['activityType'] ?? 'Unknown';
    final location = data['location'] ?? 'Unknown';
    final participants = data['participantsReached'] ?? 0;
    final date = (data['activityDate'] as Timestamp?)?.toDate();
    final status = data['status'] ?? 'Planned';

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'ongoing':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade100,
          child: Icon(Icons.groups, color: Colors.indigo.shade700),
        ),
        title: Text(
          activity,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Location: $location'),
            Text('Participants: $participants'),
            if (date != null)
              Text('Date: ${DateFormat('MMM d, y').format(date)}'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildMobileClinicsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_hospital, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Mobile Clinic Operations',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Bringing healthcare services to hard-to-reach communities',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Mobile Clinic Services',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        _buildServiceCard(
          service: 'Antenatal Care (ANC)',
          description: 'Prenatal checkups for pregnant women',
          icon: Icons.pregnant_woman,
          color: Colors.pink,
        ),
        _buildServiceCard(
          service: 'Child Welfare Clinic',
          description: 'Growth monitoring and immunization',
          icon: Icons.child_care,
          color: Colors.blue,
        ),
        _buildServiceCard(
          service: 'Family Planning',
          description: 'Contraceptive counseling and provision',
          icon: Icons.family_restroom,
          color: Colors.purple,
        ),
        _buildServiceCard(
          service: 'Basic Curative Services',
          description: 'Treatment of minor ailments',
          icon: Icons.medical_services,
          color: Colors.green,
        ),
        _buildServiceCard(
          service: 'Chronic Disease Management',
          description: 'Hypertension and diabetes follow-up',
          icon: Icons.monitor_heart,
          color: Colors.red,
        ),
        _buildServiceCard(
          service: 'Laboratory Services',
          description: 'Basic diagnostic tests',
          icon: Icons.science,
          color: Colors.orange,
        ),
        _buildServiceCard(
          service: 'Pharmacy Services',
          description: 'Essential drug distribution',
          icon: Icons.medication,
          color: Colors.teal,
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required String service,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          service,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildCommunityVisitsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Community Visit Types',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        _buildVisitTypeCard(
          title: 'Door-to-Door Campaigns',
          description: 'House-to-house health education and service delivery',
          icon: Icons.home,
          color: Colors.blue,
          activities: [
            'Immunization defaulter tracing',
            'Malaria prevention (net distribution)',
            'TB case finding',
            'Health information dissemination',
          ],
        ),
        _buildVisitTypeCard(
          title: 'School Health Visits',
          description: 'Health programs in schools',
          icon: Icons.school,
          color: Colors.green,
          activities: [
            'Deworming campaigns',
            'Vision screening',
            'Hygiene education',
            'Adolescent health talks',
          ],
        ),
        _buildVisitTypeCard(
          title: 'Market Outreach',
          description: 'Health promotion at marketplaces',
          icon: Icons.shopping_bag,
          color: Colors.orange,
          activities: [
            'Health screening',
            'Food safety inspection',
            'Health education',
            'IEC material distribution',
          ],
        ),
        _buildVisitTypeCard(
          title: 'Religious Gathering Outreach',
          description: 'Health programs at places of worship',
          icon: Icons.church,
          color: Colors.purple,
          activities: [
            'Health talks after services',
            'Blood pressure screening',
            'Health awareness campaigns',
            'Referral to health facilities',
          ],
        ),
        _buildVisitTypeCard(
          title: 'Community Leader Engagement',
          description: 'Working with traditional and community leaders',
          icon: Icons.groups_3,
          color: Colors.brown,
          activities: [
            'Health advocacy meetings',
            'Community health planning',
            'Resource mobilization',
            'Health committee formation',
          ],
        ),
      ],
    );
  }

  Widget _buildVisitTypeCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required List<String> activities,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Activities:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...activities.map(
                  (activity) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.arrow_right, size: 16, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            activity,
                            style: const TextStyle(fontSize: 13),
                          ),
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
    );
  }

  Widget _buildReportsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('health_outreach_activities')
          .where('facilityId', isEqualTo: widget.facilityId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allActivities = snapshot.data?.docs ?? [];

        // Calculate statistics
        final now = DateTime.now();
        final thisMonth = allActivities.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final activityDate = (data['activityDate'] as Timestamp?)?.toDate();
          return activityDate != null &&
              activityDate.year == now.year &&
              activityDate.month == now.month;
        }).toList();

        final thisYear = allActivities.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final activityDate = (data['activityDate'] as Timestamp?)?.toDate();
          return activityDate != null && activityDate.year == now.year;
        }).toList();

        final completedActivities = allActivities.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'Completed';
        }).toList();

        int totalParticipants = 0;
        int monthlyParticipants = 0;
        final Map<String, int> activityTypeFrequency = {};
        final Map<String, int> locationFrequency = {};
        final Map<String, int> locationParticipants = {};

        for (var doc in allActivities) {
          final data = doc.data() as Map<String, dynamic>;
          final participants = data['participantsReached'] ?? 0;
          totalParticipants += participants as int;

          final activityType = data['activityType'] ?? 'Unknown';
          activityTypeFrequency[activityType] =
              (activityTypeFrequency[activityType] ?? 0) + 1;

          final location = data['location'] ?? 'Unknown';
          locationFrequency[location] = (locationFrequency[location] ?? 0) + 1;
          locationParticipants[location] =
              (locationParticipants[location] ?? 0) + participants;
        }

        for (var doc in thisMonth) {
          final data = doc.data() as Map<String, dynamic>;
          monthlyParticipants += (data['participantsReached'] ?? 0) as int;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Outreach Reports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Overview Statistics
            Card(
              color: Colors.indigo.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overview Statistics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          'Total Activities',
                          '${allActivities.length}',
                          Colors.blue,
                        ),
                        _buildStatColumn(
                          'Completed',
                          '${completedActivities.length}',
                          Colors.green,
                        ),
                        _buildStatColumn(
                          'This Month',
                          '${thisMonth.length}',
                          Colors.orange,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          'People Reached',
                          '$totalParticipants',
                          Colors.purple,
                        ),
                        _buildStatColumn(
                          'This Month',
                          '$monthlyParticipants',
                          Colors.teal,
                        ),
                        _buildStatColumn(
                          'Communities',
                          '${locationFrequency.length}',
                          Colors.indigo,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Monthly Outreach Summary
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  child: const Icon(Icons.calendar_month, color: Colors.blue),
                ),
                title: const Text(
                  'Monthly Outreach Summary',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${thisMonth.length} activities this month'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showMonthlyReport(context, thisMonth),
              ),
            ),
            const SizedBox(height: 8),

            // Community Coverage Report
            Card(
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withOpacity(0.2),
                  child: const Icon(Icons.map, color: Colors.green),
                ),
                title: const Text(
                  'Community Coverage Report',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${locationFrequency.length} communities reached',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: locationFrequency.entries.map((entry) {
                        final participants =
                            locationParticipants[entry.key] ?? 0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(entry.key),
                            subtitle: Text('$participants people reached'),
                            trailing: Chip(
                              label: Text('${entry.value} visits'),
                              backgroundColor: Colors.green.shade100,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Service Delivery Statistics
            Card(
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  child: const Icon(Icons.analytics, color: Colors.orange),
                ),
                title: const Text(
                  'Service Delivery Statistics',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${activityTypeFrequency.length} activity types',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: activityTypeFrequency.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(entry.key)),
                              Chip(
                                label: Text('${entry.value} times'),
                                backgroundColor: Colors.orange.shade100,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Beneficiary Register
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.withOpacity(0.2),
                  child: const Icon(Icons.people, color: Colors.purple),
                ),
                title: const Text(
                  'Beneficiary Register',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('$totalParticipants total beneficiaries'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showBeneficiaryRegister(
                  context,
                  allActivities,
                  totalParticipants,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Impact Assessment
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.withOpacity(0.2),
                  child: const Icon(Icons.thumbs_up_down, color: Colors.indigo),
                ),
                title: const Text(
                  'Impact Assessment',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Health outcomes and community feedback'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showImpactAssessment(
                  context,
                  allActivities,
                  totalParticipants,
                  locationFrequency.length,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Annual Report
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.withOpacity(0.2),
                  child: const Icon(Icons.summarize, color: Colors.teal),
                ),
                title: const Text(
                  'Annual Report',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${thisYear.length} activities this year'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showAnnualReport(context, thisYear),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMonthlyReport(
    BuildContext context,
    List<QueryDocumentSnapshot> activities,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Monthly Report - ${DateFormat('MMMM y').format(DateTime.now())}',
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Activities: ${activities.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Activities:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...activities.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(data['activityType'] ?? 'Unknown'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Location: ${data['location'] ?? 'Unknown'}'),
                          Text(
                            'Reached: ${data['participantsReached'] ?? 0} people',
                          ),
                        ],
                      ),
                      trailing: Chip(
                        label: Text(data['status'] ?? 'Unknown'),
                        backgroundColor: data['status'] == 'Completed'
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                      ),
                    ),
                  );
                }),
              ],
            ),
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

  void _showBeneficiaryRegister(
    BuildContext context,
    List<QueryDocumentSnapshot> activities,
    int totalParticipants,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Beneficiary Register'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReportRow(
                'Total Beneficiaries',
                '$totalParticipants people',
              ),
              _buildReportRow('Total Activities', '${activities.length}'),
              _buildReportRow(
                'Average per Activity',
                activities.isEmpty
                    ? '0'
                    : (totalParticipants / activities.length).toStringAsFixed(
                        0,
                      ),
              ),
              const Divider(),
              const Text(
                'Demographics:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Children, women, and general population'),
              const Text('• Multiple communities reached'),
              const Text('• Various target populations served'),
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

  void _showImpactAssessment(
    BuildContext context,
    List<QueryDocumentSnapshot> activities,
    int totalParticipants,
    int communitiesReached,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Impact Assessment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Outreach Impact:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildReportRow('People Reached', '$totalParticipants'),
            _buildReportRow('Communities Served', '$communitiesReached'),
            _buildReportRow('Activities Conducted', '${activities.length}'),
            const Divider(),
            const Text(
              'Key Achievements:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('✓ Improved health awareness in communities'),
            const Text('✓ Early disease detection and prevention'),
            const Text('✓ Increased healthcare accessibility'),
            const Text('✓ Strengthened community engagement'),
            const Divider(),
            const Text(
              'Community Feedback:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Positive community reception'),
            const Text('• Increased health-seeking behavior'),
            const Text('• Improved health knowledge'),
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

  void _showAnnualReport(
    BuildContext context,
    List<QueryDocumentSnapshot> activities,
  ) {
    final now = DateTime.now();
    int totalParticipants = 0;
    for (var doc in activities) {
      final data = doc.data() as Map<String, dynamic>;
      totalParticipants += (data['participantsReached'] ?? 0) as int;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Annual Report - ${now.year}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReportRow('Total Activities', '${activities.length}'),
            _buildReportRow('Total People Reached', '$totalParticipants'),
            _buildReportRow(
              'Average per Activity',
              activities.isEmpty
                  ? '0'
                  : (totalParticipants / activities.length).toStringAsFixed(0),
            ),
            const Divider(),
            const Text(
              'Annual Achievements:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('✓ Comprehensive community coverage'),
            const Text('✓ Multiple health interventions delivered'),
            const Text('✓ Significant population reach'),
            const Text('✓ Sustainable health impact created'),
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

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showNewOutreachForm(BuildContext context, {String? activityType}) {
    final activityTypeController = TextEditingController(
      text: activityType ?? '',
    );
    final locationController = TextEditingController();
    final targetPopulationController = TextEditingController();
    final participantsReachedController = TextEditingController();
    final servicesProvidedController = TextEditingController();
    final outcomesController = TextEditingController();
    final challengesController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedStatus = 'Planned';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Plan Outreach Activity'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: activityTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Activity Type *',
                      hintText: 'e.g., Mass Immunization Campaign',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location/Community *',
                      hintText: 'e.g., Kuje Community, Gwagwalada',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetPopulationController,
                    decoration: const InputDecoration(
                      labelText: 'Target Population *',
                      hintText:
                          'e.g., Children under 5, Women of childbearing age',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: participantsReachedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Participants Reached',
                      hintText: 'Number of people reached',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activity Date'),
                    subtitle: Text(
                      DateFormat('EEEE, MMM d, y').format(selectedDate),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 30),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => selectedDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Planned',
                        child: Text('Planned'),
                      ),
                      DropdownMenuItem(
                        value: 'Ongoing',
                        child: Text('Ongoing'),
                      ),
                      DropdownMenuItem(
                        value: 'Completed',
                        child: Text('Completed'),
                      ),
                      DropdownMenuItem(
                        value: 'Cancelled',
                        child: Text('Cancelled'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => selectedStatus = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: servicesProvidedController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Services Provided',
                      hintText: 'List all services provided during outreach',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: outcomesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Outcomes/Achievements',
                      hintText: 'Key outcomes and achievements',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: challengesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Challenges Encountered',
                      hintText: 'Any challenges faced during activity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Additional Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (activityTypeController.text.trim().isEmpty ||
                    locationController.text.trim().isEmpty ||
                    targetPopulationController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill required fields'),
                    ),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('health_outreach_activities')
                      .add({
                        'facilityId': widget.facilityId,
                        'facilityName': widget.facilityName,
                        'activityType': activityTypeController.text.trim(),
                        'location': locationController.text.trim(),
                        'targetPopulation': targetPopulationController.text
                            .trim(),
                        'participantsReached':
                            int.tryParse(
                              participantsReachedController.text.trim(),
                            ) ??
                            0,
                        'activityDate': Timestamp.fromDate(selectedDate),
                        'status': selectedStatus,
                        'servicesProvided': servicesProvidedController.text
                            .trim(),
                        'outcomes': outcomesController.text.trim(),
                        'challenges': challengesController.text.trim(),
                        'notes': notesController.text.trim(),
                        'conductedBy': widget.staffName,
                        'conductedById': widget.staffId,
                        'createdAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Outreach activity created'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Activity'),
            ),
          ],
        ),
      ),
    );
  }
}
