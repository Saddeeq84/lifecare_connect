import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'facility_consultation_screen.dart';

/// Specialist Patients Screen
/// Shows patients assigned to specialist departments for consultation
/// Reuses existing FacilityConsultationScreen to avoid code duplication
class SpecialistPatientsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String specialistId;
  final String specialistName;
  final String?
  department; // Specialist department (e.g., pediatrics, cardiology)

  const SpecialistPatientsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.specialistId,
    required this.specialistName,
    this.department,
  });

  @override
  State<SpecialistPatientsScreen> createState() =>
      _SpecialistPatientsScreenState();
}

class _SpecialistPatientsScreenState extends State<SpecialistPatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDepartment = 'all';

  // Specialist departments
  final List<Map<String, String>> _departments = [
    {'value': 'all', 'label': 'All Departments'},
    {'value': 'emergency', 'label': 'Emergency'},
    {'value': 'pediatrics', 'label': 'Pediatrics'},
    {'value': 'obstetrics', 'label': 'Obstetrics & Gynecology'},
    {'value': 'cardiology', 'label': 'Cardiology'},
    {'value': 'neurology', 'label': 'Neurology'},
    {'value': 'surgery', 'label': 'Surgery'},
    {'value': 'orthopedic', 'label': 'Orthopedic'},
    {'value': 'dermatology', 'label': 'Dermatology'},
    {'value': 'ophthalmology', 'label': 'Ophthalmology'},
    {'value': 'ent', 'label': 'ENT'},
    {'value': 'dental', 'label': 'Dental'},
    {'value': 'physiotherapy', 'label': 'Physiotherapy'},
    {'value': 'mental_health', 'label': 'Mental Health'},
  ];

  @override
  void initState() {
    super.initState();
    // If specialist has specific department, filter by it
    if (widget.department != null && widget.department!.isNotEmpty) {
      _selectedDepartment = widget.department!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getPatientsStream() {
    // Get facility patients who are registered for specialist services
    Query query = FirebaseFirestore.instance
        .collection('facility_patients')
        .where('facilityId', isEqualTo: widget.facilityId)
        .where(
          'registrationType',
          isEqualTo: 'individual',
        ); // Individual patients for specialist care

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  List<DocumentSnapshot> _filterPatients(List<DocumentSnapshot> patients) {
    if (_searchQuery.isEmpty) return patients;

    return patients.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['patientName'] ?? '').toString().toLowerCase();
      final id = doc.id.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || id.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Specialist Consultations'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by patient name or ID...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Department Filter (if not specific department)
                if (widget.department == null || widget.department!.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDepartment,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down),
                        items: _departments.map((dept) {
                          return DropdownMenuItem(
                            value: dept['value'],
                            child: Text(dept['label']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedDepartment = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Patients List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getPatientsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No patients registered yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Patients will appear here once registered',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final allPatients = snapshot.data!.docs;
                final filteredPatients = _filterPatients(allPatients);

                if (filteredPatients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No patients found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredPatients.length,
                  itemBuilder: (context, index) {
                    final patientDoc = filteredPatients[index];
                    final patientData =
                        patientDoc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          // Navigate to consultation screen (reusing OPD consultation screen)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FacilityConsultationScreen(
                                patientId: patientDoc.id,
                                patientName:
                                    patientData['patientName'] ??
                                    'Unknown Patient',
                                facilityId: widget.facilityId,
                                clinicianId: widget.specialistId,
                                clinicianName: widget.specialistName,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.teal.shade100,
                                child: Text(
                                  (patientData['patientName'] ?? 'U')
                                      .toString()
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Patient Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      patientData['patientName'] ??
                                          'Unknown Patient',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Age: ${patientData['age'] ?? 'N/A'}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Icon(
                                          patientData['gender'] == 'male'
                                              ? Icons.male
                                              : Icons.female,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          patientData['gender'] ?? 'N/A',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (patientData['phoneNumber'] != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone,
                                            size: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            patientData['phoneNumber'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Action Icon
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.teal.shade700,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
