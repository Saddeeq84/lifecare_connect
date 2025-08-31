import 'package:flutter/material.dart';

class FacilityStaffDashboardScreen extends StatelessWidget {
  const FacilityStaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        leading: BackButton(),
        actions: [
          IconButton(icon: Icon(Icons.person), onPressed: () {}),
          IconButton(icon: Icon(Icons.settings), onPressed: () {}),
          IconButton(icon: Icon(Icons.logout), onPressed: () {}),
        ],
      ),
      body: ListView(
        children: [
          ListTile(leading: Icon(Icons.calendar_today), title: Text('Appointments'), onTap: () {}),
          ListTile(leading: Icon(Icons.people), title: Text('My Patients'), onTap: () {}),
          ListTile(leading: Icon(Icons.medical_services), title: Text('Consultations'), onTap: () {}),
          ListTile(leading: Icon(Icons.bar_chart), title: Text('Reports & Analytics'), onTap: () {}),
        ],
      ),
    );
  }
}
