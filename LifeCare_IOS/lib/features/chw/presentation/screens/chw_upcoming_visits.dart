import 'package:flutter/material.dart';

class CHWUpcomingVisitsScreen extends StatelessWidget {
  const CHWUpcomingVisitsScreen({super.key});

  // Sample data - replace with dynamic data later
  final List<Map<String, String>> visits = const [
    {
      'patientName': 'Jane Doe',
      'date': '2025-07-10',
      'visitType': 'ANC Visit 3',
    },
    {
      'patientName': 'Mary Smith',
      'date': '2025-07-12',
      'visitType': 'PNC Visit 1',
    },
    {
      'patientName': 'Amina Yusuf',
      'date': '2025-07-15',
      'visitType': 'ANC Visit 5',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Visits'),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: visits.length,
        itemBuilder: (context, index) {
          final visit = visits[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.teal),
              title: Text(visit['patientName'] ?? 'Unknown Patient'),
              subtitle: Text('${visit['visitType']} - ${visit['date']}'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Placeholder for visit details
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(visit['patientName'] ?? 'Details'),
                    content: Text(
                      'Visit Type: ${visit['visitType']}\nDate: ${visit['date']}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// This code defines a Flutter screen for displaying upcoming visits for Community Health Workers (CHWs).
