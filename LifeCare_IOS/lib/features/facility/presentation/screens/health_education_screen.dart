// Health Education Screen
// Health education planning, delivery, and tracking
// Community outreach and health promotion
// Following WHO Health Promotion Best Practices

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HealthEducationScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const HealthEducationScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<HealthEducationScreen> createState() => _HealthEducationScreenState();
}

class _HealthEducationScreenState extends State<HealthEducationScreen>
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
        title: const Text('Health Education'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Sessions'),
            Tab(text: 'Topics Library'),
            Tab(text: 'Outreach'),
            Tab(text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSessionsTab(),
          _buildTopicsLibraryTab(),
          _buildOutreachTab(),
          _buildReportsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewSessionForm(context),
        backgroundColor: Colors.teal.shade700,
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
      ),
    );
  }

  // Sessions Tab
  Widget _buildSessionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('health_education_sessions')
          .where('facilityId', isEqualTo: widget.facilityId)
          .orderBy('sessionDate', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final sessions = snapshot.data?.docs ?? [];

        return Column(
          children: [
            // Statistics Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    'This Week',
                    '${sessions.length}',
                    Colors.blue,
                  ),
                  _buildStatColumn('This Month', '0', Colors.orange),
                  _buildStatColumn('Total Reach', '0', Colors.green),
                ],
              ),
            ),

            // Sessions List
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.school,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No education sessions yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to create a new session',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final data =
                            sessions[index].data() as Map<String, dynamic>;
                        return _buildSessionCard(data);
                      },
                    ),
            ),
          ],
        );
      },
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

  Widget _buildSessionCard(Map<String, dynamic> data) {
    final topic = data['topic'] ?? 'Unknown Topic';
    final venue = data['venue'] ?? 'Unknown';
    final participants = data['participants'] ?? 0;
    final date = (data['sessionDate'] as Timestamp?)?.toDate();
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
          backgroundColor: Colors.teal.shade100,
          child: Icon(Icons.school, color: Colors.teal.shade700),
        ),
        title: Text(topic, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Venue: $venue'),
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
        onTap: () {
          // View session details
        },
      ),
    );
  }

  // Topics Library Tab
  Widget _buildTopicsLibraryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Priority Health Topics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        const Text(
          'Communicable Diseases',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        _buildTopicCard(
          topic: 'Malaria Prevention & Control',
          description:
              'Use of mosquito nets, environmental management, early treatment',
          icon: Icons.pest_control,
          color: Colors.red,
          keyMessages: [
            'Sleep under insecticide-treated nets',
            'Eliminate stagnant water',
            'Seek treatment within 24 hours of fever',
          ],
        ),
        _buildTopicCard(
          topic: 'HIV/AIDS Prevention',
          description: 'ABC approach, testing, stigma reduction, ART adherence',
          icon: Icons.medical_services,
          color: Colors.purple,
          keyMessages: [
            'Know your HIV status - get tested',
            'Use condoms consistently',
            'Adhere to antiretroviral therapy if positive',
          ],
        ),
        _buildTopicCard(
          topic: 'Tuberculosis Awareness',
          description: 'TB symptoms, transmission, treatment completion',
          icon: Icons.air,
          color: Colors.orange,
          keyMessages: [
            'Cough for 2+ weeks? Get screened for TB',
            'Complete 6-month treatment course',
            'Cover mouth when coughing',
          ],
        ),
        _buildTopicCard(
          topic: 'COVID-19 Prevention',
          description: 'Vaccination, hand hygiene, respiratory etiquette',
          icon: Icons.masks,
          color: Colors.blue,
          keyMessages: [
            'Get vaccinated and boosted',
            'Wash hands frequently',
            'Wear masks in crowded spaces',
          ],
        ),

        const SizedBox(height: 20),
        const Text(
          'Non-Communicable Diseases',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        _buildTopicCard(
          topic: 'Hypertension Management',
          description:
              'Blood pressure control, medication adherence, lifestyle',
          icon: Icons.monitor_heart,
          color: Colors.red,
          keyMessages: [
            'Check blood pressure regularly',
            'Reduce salt intake',
            'Take medications as prescribed',
          ],
        ),
        _buildTopicCard(
          topic: 'Diabetes Control',
          description: 'Blood sugar monitoring, diet, exercise, foot care',
          icon: Icons.bloodtype,
          color: Colors.orange,
          keyMessages: [
            'Monitor blood sugar levels',
            'Eat balanced meals, limit sugar',
            'Inspect feet daily for wounds',
          ],
        ),

        const SizedBox(height: 20),
        const Text(
          'Maternal & Child Health',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.pink,
          ),
        ),
        const SizedBox(height: 8),
        _buildTopicCard(
          topic: 'Antenatal Care',
          description: 'Importance of ANC visits, nutrition, danger signs',
          icon: Icons.pregnant_woman,
          color: Colors.pink,
          keyMessages: [
            'Attend at least 4 ANC visits',
            'Take folic acid and iron supplements',
            'Recognize pregnancy danger signs',
          ],
        ),
        _buildTopicCard(
          topic: 'Exclusive Breastfeeding',
          description: 'Benefits, techniques, duration (0-6 months)',
          icon: Icons.child_care,
          color: Colors.green,
          keyMessages: [
            'Breastfeed exclusively for 6 months',
            'No water or other foods needed',
            'Breastfeeding protects baby from infections',
          ],
        ),
        _buildTopicCard(
          topic: 'Child Immunization',
          description: 'Importance of vaccines, schedule compliance',
          icon: Icons.vaccines,
          color: Colors.blue,
          keyMessages: [
            'Immunize your child on time',
            'Vaccines prevent deadly diseases',
            'Keep immunization card safe',
          ],
        ),

        const SizedBox(height: 20),
        const Text(
          'Environmental Health',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        _buildTopicCard(
          topic: 'Water, Sanitation & Hygiene (WASH)',
          description: 'Safe water, handwashing, proper sanitation',
          icon: Icons.wash,
          color: Colors.blue,
          keyMessages: [
            'Drink safe, treated water',
            'Wash hands with soap at critical times',
            'Use improved latrines',
          ],
        ),
        _buildTopicCard(
          topic: 'Food Safety',
          description: 'Safe food handling, storage, preparation',
          icon: Icons.restaurant,
          color: Colors.brown,
          keyMessages: [
            'Keep food clean and covered',
            'Cook food thoroughly',
            'Separate raw and cooked foods',
          ],
        ),

        const SizedBox(height: 20),
        const Text(
          'Lifestyle & Wellness',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 8),
        _buildTopicCard(
          topic: 'Nutrition & Healthy Eating',
          description: 'Balanced diet, portion control, local foods',
          icon: Icons.restaurant_menu,
          color: Colors.green,
          keyMessages: [
            'Eat variety of foods daily',
            'Include fruits and vegetables',
            'Limit sugary and fatty foods',
          ],
        ),
        _buildTopicCard(
          topic: 'Physical Activity',
          description: 'Exercise benefits, recommended activity levels',
          icon: Icons.directions_run,
          color: Colors.orange,
          keyMessages: [
            '30 minutes of activity daily',
            'Exercise prevents chronic diseases',
            'Stay active at any age',
          ],
        ),
        _buildTopicCard(
          topic: 'Substance Abuse Prevention',
          description: 'Tobacco, alcohol, drug abuse dangers',
          icon: Icons.smoke_free,
          color: Colors.red,
          keyMessages: [
            'Avoid tobacco in all forms',
            'Drink alcohol responsibly if at all',
            'Say no to drugs',
          ],
        ),
      ],
    );
  }

  Widget _buildTopicCard({
    required String topic,
    required String description,
    required IconData icon,
    required Color color,
    required List<String> keyMessages,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(topic, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Key Messages:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...keyMessages.map(
                  (message) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message,
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
                      _showNewSessionForm(context, preSelectedTopic: topic),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Plan Session on This Topic'),
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

  // Outreach Tab
  Widget _buildOutreachTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Community Outreach Activities',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        _buildOutreachCard(
          activity: 'Health Talks',
          description:
              'Group education sessions in communities, schools, churches',
          icon: Icons.campaign,
          color: Colors.blue,
        ),
        _buildOutreachCard(
          activity: 'Home Visits',
          description: 'One-on-one health education and counseling at homes',
          icon: Icons.home,
          color: Colors.green,
        ),
        _buildOutreachCard(
          activity: 'School Health Programs',
          description: 'Health education and screening in schools',
          icon: Icons.school,
          color: Colors.orange,
        ),
        _buildOutreachCard(
          activity: 'Market Outreach',
          description: 'Health promotion at markets and public gatherings',
          icon: Icons.shopping_bag,
          color: Colors.purple,
        ),
        _buildOutreachCard(
          activity: 'Mass Media Campaigns',
          description: 'Radio, TV, social media health messages',
          icon: Icons.radio,
          color: Colors.red,
        ),
        _buildOutreachCard(
          activity: 'Health Fairs',
          description: 'Community health screening and education events',
          icon: Icons.festival,
          color: Colors.teal,
        ),

        const SizedBox(height: 20),
        const Text(
          'Outreach Checklist',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        _buildChecklistItem('Identify target audience and community'),
        _buildChecklistItem('Select appropriate health topic'),
        _buildChecklistItem('Prepare educational materials (posters, flyers)'),
        _buildChecklistItem('Coordinate with community leaders'),
        _buildChecklistItem('Arrange logistics (venue, equipment, supplies)'),
        _buildChecklistItem('Conduct session with community participation'),
        _buildChecklistItem('Distribute IEC materials'),
        _buildChecklistItem('Document attendance and feedback'),
        _buildChecklistItem('Follow-up and evaluation'),
      ],
    );
  }

  Widget _buildOutreachCard({
    required String activity,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          activity,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  Widget _buildChecklistItem(String item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.check_box_outline_blank, color: Colors.teal),
        title: Text(item, style: const TextStyle(fontSize: 13)),
        dense: true,
      ),
    );
  }

  // Reports Tab
  Widget _buildReportsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('health_education_sessions')
          .where('facilityId', isEqualTo: widget.facilityId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allSessions = snapshot.data?.docs ?? [];

        // Calculate statistics
        final now = DateTime.now();
        final thisMonth = allSessions.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final sessionDate = (data['sessionDate'] as Timestamp?)?.toDate();
          return sessionDate != null &&
              sessionDate.year == now.year &&
              sessionDate.month == now.month;
        }).toList();

        final thisYear = allSessions.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final sessionDate = (data['sessionDate'] as Timestamp?)?.toDate();
          return sessionDate != null && sessionDate.year == now.year;
        }).toList();

        final completedSessions = allSessions.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'Completed';
        }).toList();

        int totalParticipants = 0;
        int monthlyParticipants = 0;
        final Map<String, int> topicFrequency = {};
        final Map<String, int> venueFrequency = {};

        for (var doc in allSessions) {
          final data = doc.data() as Map<String, dynamic>;
          final participants = data['participants'] ?? 0;
          totalParticipants += participants as int;

          final topic = data['topic'] ?? 'Unknown';
          topicFrequency[topic] = (topicFrequency[topic] ?? 0) + 1;

          final venue = data['venue'] ?? 'Unknown';
          venueFrequency[venue] = (venueFrequency[venue] ?? 0) + 1;
        }

        for (var doc in thisMonth) {
          final data = doc.data() as Map<String, dynamic>;
          monthlyParticipants += (data['participants'] ?? 0) as int;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Health Education Reports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Overview Statistics
            Card(
              color: Colors.teal.shade50,
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
                          'Total Sessions',
                          '${allSessions.length}',
                          Colors.blue,
                        ),
                        _buildStatColumn(
                          'Completed',
                          '${completedSessions.length}',
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
                          'Total Reach',
                          '$totalParticipants',
                          Colors.purple,
                        ),
                        _buildStatColumn(
                          'This Month',
                          '$monthlyParticipants',
                          Colors.teal,
                        ),
                        _buildStatColumn(
                          'This Year',
                          '${thisYear.length}',
                          Colors.indigo,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Monthly Activity Report
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  child: const Icon(Icons.calendar_month, color: Colors.blue),
                ),
                title: const Text(
                  'Monthly Activity Report',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${thisMonth.length} sessions this month'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showMonthlyReport(context, thisMonth),
              ),
            ),
            const SizedBox(height: 8),

            // Topic Coverage Report
            Card(
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  child: const Icon(Icons.topic, color: Colors.orange),
                ),
                title: const Text(
                  'Topic Coverage Report',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${topicFrequency.length} different topics'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: topicFrequency.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(entry.key)),
                              Chip(
                                label: Text('${entry.value} sessions'),
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

            // Venue Analysis
            Card(
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.withOpacity(0.2),
                  child: const Icon(Icons.location_on, color: Colors.purple),
                ),
                title: const Text(
                  'Venue Analysis',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${venueFrequency.length} different venues'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: venueFrequency.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(entry.key)),
                              Chip(
                                label: Text('${entry.value} times'),
                                backgroundColor: Colors.purple.shade100,
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

            // Reach & Impact Analysis
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withOpacity(0.2),
                  child: const Icon(Icons.people, color: Colors.green),
                ),
                title: const Text(
                  'Reach & Impact Analysis',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('$totalParticipants total participants reached'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () =>
                    _showReachAnalysis(context, allSessions, totalParticipants),
              ),
            ),
            const SizedBox(height: 8),

            // Annual Summary
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.withOpacity(0.2),
                  child: const Icon(Icons.summarize, color: Colors.red),
                ),
                title: const Text(
                  'Annual Summary',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${thisYear.length} sessions this year'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showAnnualSummary(context, thisYear),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMonthlyReport(
    BuildContext context,
    List<QueryDocumentSnapshot> sessions,
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
                  'Total Sessions: ${sessions.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sessions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...sessions.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(data['topic'] ?? 'Unknown'),
                      subtitle: Text(
                        '${data['participants'] ?? 0} participants',
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

  void _showReachAnalysis(
    BuildContext context,
    List<QueryDocumentSnapshot> sessions,
    int totalParticipants,
  ) {
    final avgParticipants = sessions.isEmpty
        ? 0
        : totalParticipants / sessions.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reach & Impact Analysis'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReportRow(
                'Total Participants Reached',
                '$totalParticipants people',
              ),
              _buildReportRow(
                'Total Sessions Conducted',
                '${sessions.length} sessions',
              ),
              _buildReportRow(
                'Average Attendance',
                '${avgParticipants.toStringAsFixed(0)} per session',
              ),
              const Divider(),
              const Text(
                'Impact Indicators:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildReportRow('Communities Engaged', 'Multiple venues'),
              _buildReportRow('Health Topics Covered', 'Comprehensive'),
              _buildReportRow('IEC Materials Distributed', 'Yes'),
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

  void _showAnnualSummary(
    BuildContext context,
    List<QueryDocumentSnapshot> sessions,
  ) {
    final now = DateTime.now();
    int totalParticipants = 0;
    for (var doc in sessions) {
      final data = doc.data() as Map<String, dynamic>;
      totalParticipants += (data['participants'] ?? 0) as int;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Annual Summary - ${now.year}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReportRow('Total Sessions', '${sessions.length}'),
            _buildReportRow('Total Participants', '$totalParticipants'),
            _buildReportRow(
              'Average per Session',
              sessions.isEmpty
                  ? '0'
                  : (totalParticipants / sessions.length).toStringAsFixed(0),
            ),
            const Divider(),
            const Text(
              'Annual Achievements:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('✓ Community health awareness improved'),
            const Text('✓ Multiple health topics addressed'),
            const Text('✓ Wide community reach achieved'),
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

  void _showNewSessionForm(BuildContext context, {String? preSelectedTopic}) {
    final topicController = TextEditingController(text: preSelectedTopic ?? '');
    final venueController = TextEditingController();
    final targetAudienceController = TextEditingController();
    final expectedParticipantsController = TextEditingController();
    final objectivesController = TextEditingController();
    final materialsController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedStatus = 'Planned';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Plan Health Education Session'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: topicController,
                    decoration: const InputDecoration(
                      labelText: 'Topic *',
                      hintText: 'e.g., Malaria Prevention',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: venueController,
                    decoration: const InputDecoration(
                      labelText: 'Venue *',
                      hintText: 'e.g., Community Hall, Church',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetAudienceController,
                    decoration: const InputDecoration(
                      labelText: 'Target Audience *',
                      hintText: 'e.g., Pregnant women, Youth',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: expectedParticipantsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Expected Participants',
                      hintText: 'Enter number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Session Date'),
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
                    controller: objectivesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Learning Objectives',
                      hintText: 'What participants should learn',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: materialsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Materials/IEC Distributed',
                      hintText: 'Posters, flyers, booklets, etc.',
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
                if (topicController.text.trim().isEmpty ||
                    venueController.text.trim().isEmpty ||
                    targetAudienceController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill required fields'),
                    ),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('health_education_sessions')
                      .add({
                        'facilityId': widget.facilityId,
                        'facilityName': widget.facilityName,
                        'topic': topicController.text.trim(),
                        'venue': venueController.text.trim(),
                        'targetAudience': targetAudienceController.text.trim(),
                        'expectedParticipants':
                            int.tryParse(
                              expectedParticipantsController.text.trim(),
                            ) ??
                            0,
                        'participants': 0,
                        'sessionDate': Timestamp.fromDate(selectedDate),
                        'status': selectedStatus,
                        'objectives': objectivesController.text.trim(),
                        'materials': materialsController.text.trim(),
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
                        content: Text('Health education session created'),
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
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Session'),
            ),
          ],
        ),
      ),
    );
  }
}
