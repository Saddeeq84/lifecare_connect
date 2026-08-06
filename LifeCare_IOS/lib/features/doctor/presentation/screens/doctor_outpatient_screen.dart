import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'doctor_consultation_screen.dart';

class DoctorOutpatientScreen extends StatefulWidget {
  const DoctorOutpatientScreen({super.key});

  @override
  State<DoctorOutpatientScreen> createState() => _DoctorOutpatientScreenState();
}

class _DoctorOutpatientScreenState extends State<DoctorOutpatientScreen> {
  final String doctorId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outpatients'),
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by patient name...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Colors.white54),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Colors.white54),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Optimized query with proper indexing for outpatients
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('providerId', isEqualTo: doctorId)
            .where('status', whereIn: ['approved', 'completed'])
            .orderBy('appointmentDate', descending: true)
            .snapshots(),
        builder: (context, appointmentSnapshot) {
          if (appointmentSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (appointmentSnapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${appointmentSnapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!appointmentSnapshot.hasData ||
              appointmentSnapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No outpatient records found'),
                  SizedBox(height: 8),
                  Text(
                    'Approved and completed appointments will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final allAppointments = appointmentSnapshot.data!.docs;

          // Filter by search query if provided
          final filteredAppointments = _searchQuery.isEmpty
              ? allAppointments
              : allAppointments.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final patientName = (data['patientName'] ?? '')
                      .toString()
                      .toLowerCase();
                  return patientName.contains(_searchQuery);
                }).toList();

          if (filteredAppointments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('No results found for "$_searchQuery"'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    child: const Text('Clear Search'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredAppointments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = filteredAppointments[index];
              final appointment = doc.data() as Map<String, dynamic>;
              appointment['id'] = doc.id;

              final status = appointment['status'] ?? 'unknown';
              final isCompleted = status == 'completed';

              return Card(
                elevation: 3,
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
                            isCompleted ? Icons.check_circle : Icons.schedule,
                            color: isCompleted ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              appointment['patientName'] ?? 'Unknown Patient',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: isCompleted
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Patient details
                      if (appointment['age'] != null)
                        _buildInfoRow('Age', appointment['age'].toString()),
                      if (appointment['sex'] != null)
                        _buildInfoRow('Sex', appointment['sex']),
                      if (appointment['phone'] != null)
                        _buildInfoRow('Phone', appointment['phone']),

                      // Appointment details
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Colors.grey.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            appointment['appointmentDate'] != null
                                ? appointment['appointmentDate']
                                      .toString()
                                      .split(' ')[0]
                                : 'Date not specified',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),

                      if (appointment['reason'] != null &&
                          appointment['reason'].toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                appointment['reason'],
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!isCompleted) ...[
                            ElevatedButton.icon(
                              icon: const Icon(
                                Icons.medical_services,
                                size: 18,
                              ),
                              label: const Text('Start Consultation'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyan,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        DoctorConsultationDetailScreen(
                                          appointment: appointment,
                                        ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                          OutlinedButton.icon(
                            icon: const Icon(Icons.visibility, size: 18),
                            label: const Text('View Details'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () async {
                              final patientId = appointment['patientId'];
                              if (patientId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No patient ID found for this appointment.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              // Show appointment details dialog
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('Appointment Details'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildInfoRow(
                                            'Patient Name',
                                            appointment['patientName'] ??
                                                'Unknown',
                                          ),
                                          _buildInfoRow(
                                            'Status',
                                            status.toUpperCase(),
                                          ),
                                          _buildInfoRow(
                                            'Date',
                                            appointment['appointmentDate']
                                                    ?.toString() ??
                                                'Not specified',
                                          ),
                                          if (appointment['reason'] != null)
                                            _buildInfoRow(
                                              'Reason',
                                              appointment['reason'],
                                            ),
                                          if (appointment['age'] != null)
                                            _buildInfoRow(
                                              'Age',
                                              appointment['age'].toString(),
                                            ),
                                          if (appointment['sex'] != null)
                                            _buildInfoRow(
                                              'Sex',
                                              appointment['sex'],
                                            ),
                                          if (appointment['phone'] != null)
                                            _buildInfoRow(
                                              'Phone',
                                              appointment['phone'],
                                            ),
                                          if (appointment['address'] != null)
                                            _buildInfoRow(
                                              'Address',
                                              appointment['address'],
                                            ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
