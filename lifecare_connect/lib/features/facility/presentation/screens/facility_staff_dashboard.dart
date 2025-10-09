import 'package:flutter/material.dart';

class FacilityStaffDashboardScreen extends StatelessWidget {
  const FacilityStaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        leading: const BackButton(),
        actions: [
          IconButton(icon: const Icon(Icons.person), onPressed: () {}),
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
          IconButton(icon: const Icon(Icons.logout), onPressed: () {}),
        ],
      ),
      body: ListView(
        children: [
          ListTile(leading: const Icon(Icons.calendar_today), title: const Text('Appointments'), onTap: () {}),
          ListTile(leading: const Icon(Icons.people), title: const Text('My Patients'), onTap: () {}),
          ListTile(leading: const Icon(Icons.medical_services), title: const Text('Consultations'), onTap: () {}),
          ListTile(leading: const Icon(Icons.bar_chart), title: const Text('Reports & Analytics'), onTap: () {}),
        ],
      ),
    );
  }
}
