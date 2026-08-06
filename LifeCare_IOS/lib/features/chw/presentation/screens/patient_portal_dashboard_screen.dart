import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Patient Portal Dashboard - View health records
class PatientPortalDashboardScreen extends StatefulWidget {
  const PatientPortalDashboardScreen({super.key});

  @override
  State<PatientPortalDashboardScreen> createState() =>
      _PatientPortalDashboardScreenState();
}

class _PatientPortalDashboardScreenState
    extends State<PatientPortalDashboardScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  String? _patientId;
  String? _patientName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadPatientProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final profileDoc = await _firestore
          .collection('patient_profiles')
          .doc(user.uid)
          .get();

      if (profileDoc.exists) {
        setState(() {
          _patientId = profileDoc.data()?['patientId'];
          _patientName = profileDoc.data()?['name'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading patient profile: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_patientId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('Unable to load patient profile'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
                child: Text('Logout'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('My Health Records'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              // TODO: Navigate to profile settings
            },
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.calendar_today), text: 'Appointments'),
            Tab(icon: Icon(Icons.pregnant_woman), text: 'ANC'),
            Tab(icon: Icon(Icons.child_care), text: 'PNC'),
            Tab(icon: Icon(Icons.vaccines), text: 'Immunizations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildAppointmentsTab(),
          _buildANCTab(),
          _buildPNCTab(),
          _buildImmunizationsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            color: Colors.teal.shade50,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.teal,
                        child: Icon(
                          Icons.person,
                          size: 35,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.teal.shade700,
                              ),
                            ),
                            Text(
                              _patientName ?? 'Patient',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 24),

          Text(
            'Recent Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),

          // Upcoming Appointments
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('chw_patient_records')
                .doc(_patientId)
                .collection('appointments')
                .where('status', isEqualTo: 'scheduled')
                .orderBy('appointmentDateTime')
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error loading appointments');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final appointments = snapshot.data?.docs ?? [];

              if (appointments.isEmpty) {
                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.grey),
                        SizedBox(width: 12),
                        Text('No upcoming appointments'),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: appointments.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final appointmentType =
                      data['appointmentType'] ?? 'Appointment';
                  final dateTime = (data['appointmentDateTime'] as Timestamp?)
                      ?.toDate();
                  final location = data['location'] ?? 'Health Facility';

                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo.shade100,
                        child: Icon(Icons.calendar_today, color: Colors.indigo),
                      ),
                      title: Text(appointmentType),
                      subtitle: dateTime != null
                          ? Text(
                              '${DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime)}\n$location',
                            )
                          : Text(location),
                      isThreeLine: true,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chw_patient_records')
          .doc(_patientId)
          .collection('appointments')
          .orderBy('appointmentDateTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading appointments'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final appointments = snapshot.data?.docs ?? [];

        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No appointments found'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final data = appointments[index].data() as Map<String, dynamic>;
            return _buildAppointmentCard(data);
          },
        );
      },
    );
  }

  Widget _buildANCTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chw_patient_records')
          .doc(_patientId)
          .collection('anc_visits')
          .orderBy('visitDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading ANC records'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final visits = snapshot.data?.docs ?? [];

        if (visits.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pregnant_woman, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No ANC visits recorded'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: visits.length,
          itemBuilder: (context, index) {
            final data = visits[index].data() as Map<String, dynamic>;
            return _buildANCCard(data);
          },
        );
      },
    );
  }

  Widget _buildPNCTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chw_patient_records')
          .doc(_patientId)
          .collection('pnc_visits')
          .orderBy('visitDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading PNC records'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final visits = snapshot.data?.docs ?? [];

        if (visits.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.child_care, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No PNC visits recorded'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: visits.length,
          itemBuilder: (context, index) {
            final data = visits[index].data() as Map<String, dynamic>;
            return _buildPNCCard(data);
          },
        );
      },
    );
  }

  Widget _buildImmunizationsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chw_patient_records')
          .doc(_patientId)
          .collection('immunizations')
          .orderBy('vaccinationDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading immunization records'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final immunizations = snapshot.data?.docs ?? [];

        if (immunizations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.vaccines, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No immunization records found'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: immunizations.length,
          itemBuilder: (context, index) {
            final data = immunizations[index].data() as Map<String, dynamic>;
            return _buildImmunizationCard(data);
          },
        );
      },
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> data) {
    final appointmentType = data['appointmentType'] ?? 'Appointment';
    final dateTime = (data['appointmentDateTime'] as Timestamp?)?.toDate();
    final location = data['location'] ?? 'Health Facility';
    final status = data['status'] ?? 'scheduled';
    final reason = data['reason'];

    Color statusColor;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.blue;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.indigo),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appointmentType,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            if (dateTime != null)
              Text(
                DateFormat('EEEE, MMMM dd, yyyy - hh:mm a').format(dateTime),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            Text(location, style: TextStyle(color: Colors.grey.shade600)),
            if (reason != null && reason.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                'Reason: $reason',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildANCCard(Map<String, dynamic> data) {
    final visitDate = (data['visitDate'] as Timestamp?)?.toDate();
    final gestationalAge = data['gestationalAge'];
    final weight = data['weight'];
    final bloodPressure = data['bloodPressure'];

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      color: Colors.pink.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pregnant_woman, color: Colors.pink),
                SizedBox(width: 8),
                Text(
                  'ANC Visit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            if (visitDate != null)
              Text(
                DateFormat('MMMM dd, yyyy').format(visitDate),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            if (gestationalAge != null)
              Text('Gestational Age: $gestationalAge weeks'),
            if (weight != null) Text('Weight: $weight kg'),
            if (bloodPressure != null) Text('BP: $bloodPressure mmHg'),
          ],
        ),
      ),
    );
  }

  Widget _buildPNCCard(Map<String, dynamic> data) {
    final visitDate = (data['visitDate'] as Timestamp?)?.toDate();
    final daysPostpartum = data['daysPostpartum'];

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      color: Colors.purple.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.child_care, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'PNC Visit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            if (visitDate != null)
              Text(
                DateFormat('MMMM dd, yyyy').format(visitDate),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            if (daysPostpartum != null)
              Text('Days Postpartum: $daysPostpartum days'),
          ],
        ),
      ),
    );
  }

  Widget _buildImmunizationCard(Map<String, dynamic> data) {
    final vaccinationDate = (data['vaccinationDate'] as Timestamp?)?.toDate();
    final vaccineType = data['vaccineType'];
    final doseNumber = data['doseNumber'];

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      color: Colors.teal.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.vaccines, color: Colors.teal),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vaccineType ?? 'Vaccination',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            if (vaccinationDate != null)
              Text(
                DateFormat('MMMM dd, yyyy').format(vaccinationDate),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            if (doseNumber != null) Text('Dose: $doseNumber'),
          ],
        ),
      ),
    );
  }
}
