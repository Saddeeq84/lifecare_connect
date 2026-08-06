import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'vitals_recording_screen.dart';
import 'patient_procedure_recording_screen.dart';
import 'patient_medical_records_viewer.dart';
import 'emergency_patient_transfer_screen.dart';
import 'patient_transfer_screen.dart';

class NursingInpatientsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final String? wardId; // Ward assignment for nursing staff
  final String? wardName; // Ward name for display
  final bool isViewOnly; // View-only mode for OPD dashboard
  final bool filterByEmergency; // Filter to show only emergency admissions
  final bool
  filterBySpecialistDepartments; // Filter to show only specialist department admissions
  final bool
  excludeEmergencyAdmissions; // Exclude emergency admissions (for nursing dashboard - show only regular wards)

  const NursingInpatientsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    this.wardId,
    this.wardName,
    this.isViewOnly = false, // Default to false for normal ward management
    this.filterByEmergency = false, // Default to false for general access
    this.filterBySpecialistDepartments =
        false, // Default to false for general access
    this.excludeEmergencyAdmissions =
        false, // Default to false - set true from nursing dashboard
  });

  @override
  State<NursingInpatientsScreen> createState() =>
      _NursingInpatientsScreenState();
}

class _NursingInpatientsScreenState extends State<NursingInpatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedWardId;
  List<Map<String, dynamic>> _wards = [];
  bool _loadingWards = true;

  @override
  void initState() {
    super.initState();
    _loadWards();
    // Initialize with staff's assigned ward if available
    _selectedWardId = widget.wardId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWards() async {
    try {
      final wardsSnapshot = await FirebaseFirestore.instance
          .collection('wards')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('isActive', isEqualTo: true)
          .orderBy('name', descending: false)
          .get();

      setState(() {
        _wards = wardsSnapshot.docs
            .map(
              (doc) => {
                'id': doc.id,
                'name': doc.data()['name'] ?? 'Unnamed Ward',
                'capacity': doc.data()['capacity'] ?? 0,
                'currentOccupancy': doc.data()['currentOccupancy'] ?? 0,
              },
            )
            .toList();
        _loadingWards = false;
      });
    } catch (e) {
      setState(() => _loadingWards = false);
      print('Error loading wards: $e');
    }
  }

  Stream<QuerySnapshot> _getInpatientsStream() {
    Query query = FirebaseFirestore.instance
        .collection('admissions')
        .where('facilityId', isEqualTo: widget.facilityId)
        .where('isActive', isEqualTo: true);

    // Filter by emergency admissions if required (Emergency Dashboard)
    if (widget.filterByEmergency) {
      query = query.where('admissionType', isEqualTo: 'emergency');
      // Show both admitted and pending admissions destined for emergency
      query = query.where(
        'status',
        whereIn: ['admitted', 'pending_acceptance'],
      );
    }
    // Exclude emergency admissions if required (Nursing Dashboard - show only regular wards)
    else if (widget.excludeEmergencyAdmissions) {
      query = query.where('admissionType', isNotEqualTo: 'emergency');
      // Show both admitted and pending admissions destined for regular wards
      query = query.where(
        'status',
        whereIn: ['admitted', 'pending_acceptance'],
      );
    } else {
      // For other dashboards, show admitted and pending
      query = query.where(
        'status',
        whereIn: ['admitted', 'pending_acceptance'],
      );
    }

    // Filter by specialist departments if required
    if (widget.filterBySpecialistDepartments) {
      query = query.where(
        'department',
        whereIn: [
          'Pediatrics',
          'Obstetrics & Gynecology',
          'Cardiology',
          'Neurology',
          'Surgery Department',
          'Orthopedics',
          'Dermatology',
          'Ophthalmology Department',
          'ENT Department',
          'Dental Department',
          'Physiotherapy',
          'Mental Health',
          'Specialist Department',
        ],
      );
    }

    // Filter by selected ward
    if (_selectedWardId != null && _selectedWardId!.isNotEmpty) {
      query = query.where('wardId', isEqualTo: _selectedWardId);
    }

    return query.orderBy('admittedAt', descending: true).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'In-Patients${widget.isViewOnly ? ' (View Only)' : ''}${widget.wardName != null ? ' - ${widget.wardName}' : ''}',
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // View-Only Info Banner (shown only in view-only mode)
          if (widget.isViewOnly)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber.shade900,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'View-Only Mode: You can view in-patients but cannot approve or cancel admissions.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Info Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: EdgeInsets.fromLTRB(16, widget.isViewOnly ? 8 : 16, 16, 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hotel, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'In-Patient Management',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.wardId != null
                      ? 'Manage patients admitted to your assigned ward'
                      : 'Manage all admitted patients in this facility',
                  style: TextStyle(color: Colors.blue.shade600, fontSize: 14),
                ),
              ],
            ),
          ),

          // Ward Selection Dropdown
          if (!_loadingWards && _wards.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Select Ward',
                  prefixIcon: const Icon(Icons.domain),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                value: _selectedWardId,
                hint: const Text('All Wards'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Wards'),
                  ),
                  ..._wards.map(
                    (ward) => DropdownMenuItem<String>(
                      value: ward['id'],
                      child: Text(
                        '${ward['name']} (${ward['currentOccupancy']}/${ward['capacity']})',
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedWardId = value;
                  });
                },
              ),
            ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText:
                    'Search patients by name, reg. number, or room number...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Patients List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getInpatientsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading patients',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: TextStyle(color: Colors.red.shade400),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading patients...'),
                      ],
                    ),
                  );
                }

                final patients = snapshot.data?.docs ?? [];

                // Filter patients based on search query
                final filteredPatients = patients.where((patient) {
                  final data = patient.data() as Map<String, dynamic>;
                  final patientName = (data['patientName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final patientId = (data['patientId'] ?? '')
                      .toString()
                      .toLowerCase();
                  final roomNumber = (data['roomNumber'] ?? '')
                      .toString()
                      .toLowerCase();

                  return _searchQuery.isEmpty ||
                      patientName.contains(_searchQuery) ||
                      patientId.contains(_searchQuery) ||
                      roomNumber.contains(_searchQuery);
                }).toList();

                if (filteredPatients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty
                              ? Icons.search_off
                              : Icons.hotel_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No patients found matching "$_searchQuery"'
                              : 'No admitted patients found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try adjusting your search criteria'
                              : widget.wardId != null
                              ? 'No patients are currently admitted to this ward'
                              : 'No patients are currently admitted to this facility',
                          style: TextStyle(color: Colors.grey.shade500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredPatients.length,
                  itemBuilder: (context, index) {
                    final patientDoc = filteredPatients[index];
                    final patient = patientDoc.data() as Map<String, dynamic>;

                    return _buildPatientCard(patient, patientDoc.id, index + 1);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(
    Map<String, dynamic> patient,
    String patientDocId,
    int index,
  ) {
    final admissionDate = (patient['admissionDate'] as Timestamp?)?.toDate();
    final patientName = patient['patientName'] ?? 'Unknown Patient';
    final patientId = patient['patientId'] ?? 'N/A';
    final roomNumber = patient['roomNumber'] ?? 'No Room';
    final bedNumber = patient['bedNumber'] ?? 'No Bed';
    final wardName = patient['wardName'] ?? 'General Ward';
    final diagnosis = patient['diagnosis'] ?? 'No diagnosis recorded';
    // Get the doctor who initiated the admission (admittedByName) not who accepted it
    final doctorName =
        patient['admittedByName'] ?? patient['doctorName'] ?? 'Unknown Doctor';
    final condition = patient['condition'] ?? 'stable';

    // Determine condition color
    Color conditionColor;
    IconData conditionIcon;
    switch (condition.toLowerCase()) {
      case 'critical':
        conditionColor = Colors.red;
        conditionIcon = Icons.warning;
        break;
      case 'serious':
        conditionColor = Colors.orange;
        conditionIcon = Icons.priority_high;
        break;
      case 'fair':
        conditionColor = Colors.yellow.shade700;
        conditionIcon = Icons.info;
        break;
      case 'stable':
      default:
        conditionColor = Colors.green;
        conditionIcon = Icons.check_circle;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewPatientRecords(patient, patientDocId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Header
              Row(
                children: [
                  // Index Number
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$index',
                      style: TextStyle(
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      patientName.isNotEmpty
                          ? patientName[0].toUpperCase()
                          : 'P',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'ID: $patientId',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status Badge or Transfer Button
                  if (patient['status'] == 'pending_acceptance')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.pending_actions,
                            size: 16,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'PENDING',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (patient['status'] == 'admitted' &&
                      !widget.isViewOnly &&
                      (widget.filterByEmergency ||
                          widget.excludeEmergencyAdmissions))
                    // Transfer Button for Emergency and Nursing dashboards
                    SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _transferPatient(patient, patientDocId),
                        icon: const Icon(
                          Icons.transfer_within_a_station,
                          size: 14,
                        ),
                        label: Text(
                          widget.filterByEmergency ? 'Transfer' : 'Transfer',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        ),
                      ),
                    )
                  else if (!widget.isViewOnly)
                    // Condition Badge (only shown in Ward Management, not Patient Management)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: conditionColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: conditionColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(conditionIcon, size: 16, color: conditionColor),
                          const SizedBox(width: 4),
                          Text(
                            condition.toUpperCase(),
                            style: TextStyle(
                              color: conditionColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Room & Ward Info
              Row(
                children: [
                  Icon(Icons.room, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Room $roomNumber - Bed $bedNumber',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.local_hospital,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    wardName,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Diagnosis
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.medical_services,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      diagnosis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Doctor & Admission Date
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Dr. $doctorName',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                  const Spacer(),
                  if (admissionDate != null) ...[
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${admissionDate.day}/${admissionDate.month}/${admissionDate.year}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),

              // Accept/Cancel Admission Button (for pending admissions/transfers)
              if (patient['status'] == 'pending_acceptance' &&
                  !widget.isViewOnly) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    // Check if this dashboard initiated the transfer
                    final isTransferInitiator =
                        patient['transferredBy'] == widget.staffId;
                    final isEmergencyTransfer =
                        patient['transferredFrom'] == 'Emergency Department';
                    final isEmergencyDashboard =
                        widget.filterByEmergency == true;

                    // Emergency dashboard can only cancel if they initiated the transfer
                    // Nursing dashboard can only cancel if they initiated the transfer
                    final canCancel =
                        isTransferInitiator ||
                        (isEmergencyDashboard && isEmergencyTransfer);

                    // Can only accept if NOT the initiator
                    final canAccept =
                        !isTransferInitiator &&
                        !(isEmergencyDashboard && isEmergencyTransfer);

                    return Row(
                      children: [
                        if (canCancel)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showCancelAdmissionDialog(
                                patientDocId,
                                patient,
                              ),
                              icon: const Icon(Icons.cancel, size: 18),
                              label: const Text('Cancel Transfer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        if (canCancel && canAccept) const SizedBox(width: 12),
                        if (canAccept)
                          Expanded(
                            flex: canCancel ? 2 : 1,
                            child: ElevatedButton.icon(
                              onPressed: () => _showAcceptAdmissionDialog(
                                patientDocId,
                                patient,
                              ),
                              icon: const Icon(Icons.check_circle, size: 18),
                              label: Text(
                                patient['transferredFrom'] != null ||
                                        patient['transferredBy'] != null
                                    ? 'Accept Transfer'
                                    : 'Accept Admission',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],

              // Action Buttons for Admitted Patients (Vitals, Records, and Procedures)
              if (patient['status'] == 'admitted' && !widget.isViewOnly) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _recordVitals(patient),
                        icon: const Icon(Icons.monitor_heart, size: 18),
                        label: const Text('Record Vitals'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _viewPatientRecords(patient, patientDocId),
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Patient Record'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _recordProcedure(patient),
                        icon: const Icon(Icons.medical_services, size: 18),
                        label: const Text('Procedure'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // View Records Button for View-Only Mode (from OPD)
              if (patient['status'] == 'admitted' && widget.isViewOnly) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _viewPatientRecords(patient, patientDocId),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Patient Records'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAcceptAdmissionDialog(
    String patientDocId,
    Map<String, dynamic> patient,
  ) {
    final admissionNotesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String? selectedWardService;
    double selectedServicePrice = 0.0;
    String? selectedServiceName;
    String? selectedServiceCategory;
    String? selectedBillingCycle;
    String? selectedAutoCharge;

    // Pre-filled data from admission request
    final wardName = patient['ward'] ?? patient['wardName'] ?? 'Not specified';
    final bedNumber = patient['bedNumber'] ?? 'Not specified';
    final admissionReason = patient['admissionReason'] ?? 'Not specified';
    final isTransfer =
        patient['transferredFrom'] != null || patient['transferredBy'] != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            isTransfer
                ? 'Accept Transfer - ${patient['patientName']}'
                : 'Accept Admission - ${patient['patientName']}',
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTransfer
                        ? 'Review transfer details and accept patient to this ward:'
                        : 'Review admission details and accept to start billing:',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Display transfer information if applicable
                  if (isTransfer) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.transfer_within_a_station,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Transfer Information',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (patient['transferredFrom'] != null) ...[
                            Text(
                              'From: ${patient['transferredFrom']}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (patient['transferredByName'] != null) ...[
                            Text(
                              'Transferred by: ${patient['transferredByName']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (patient['lastTransferReason'] != null) ...[
                            Text(
                              'Reason: ${patient['lastTransferReason']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Display pre-selected ward and bed (read-only)
                  Container(
                    padding: const EdgeInsets.all(12),
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
                            Icon(
                              Icons.local_hotel,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isTransfer
                                  ? 'New Ward Assignment'
                                  : 'Admission Details',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(width: 28),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reason: $admissionReason',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Ward: $wardName',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Bed Number: $bedNumber',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ward Service Dropdown (pulls from facility_service_prices)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('facility_service_prices')
                        .doc(widget.facilityId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }

                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No ward services configured. Please contact facility admin to set up ward services in Service Management.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final servicePrices =
                          snapshot.data!.data() as Map<String, dynamic>? ?? {};

                      // Define the service mappings (matching service_management_screen.dart)
                      final wardAccommodationServices = [
                        {
                          'id': 'general_ward_bed',
                          'name': 'General Ward Bed (Per Night)',
                        },
                        {
                          'id': 'general_ward_male',
                          'name': 'Male Ward Bed (Per Night)',
                        },
                        {
                          'id': 'general_ward_female',
                          'name': 'Female Ward Bed (Per Night)',
                        },
                        {
                          'id': 'pediatric_ward',
                          'name': 'Pediatric Ward Bed (Per Night)',
                        },
                        {
                          'id': 'semi_private_ward',
                          'name': 'Semi-Private Ward (2-4 Beds/Night)',
                        },
                        {
                          'id': 'private_ward_standard',
                          'name': 'Private Ward Standard (Per Night)',
                        },
                        {
                          'id': 'private_ward_ensuite',
                          'name': 'Private Ward En-suite (Per Night)',
                        },
                        {
                          'id': 'private_ward_deluxe',
                          'name': 'Private Ward Deluxe (Per Night)',
                        },
                        {'id': 'vip_ward', 'name': 'VIP Ward (Per Night)'},
                        {
                          'id': 'maternity_ward',
                          'name': 'Maternity Ward Bed (Per Night)',
                        },
                        {
                          'id': 'surgical_ward',
                          'name': 'Surgical Ward Bed (Per Night)',
                        },
                        {
                          'id': 'orthopedic_ward',
                          'name': 'Orthopedic Ward Bed (Per Night)',
                        },
                        {
                          'id': 'medical_ward',
                          'name': 'Medical Ward Bed (Per Night)',
                        },
                        {'id': 'icu_general', 'name': 'ICU Bed (Per Night)'},
                        {
                          'id': 'icu_neonatal',
                          'name': 'Neonatal ICU (NICU) Bed (Per Night)',
                        },
                        {
                          'id': 'icu_pediatric',
                          'name': 'Pediatric ICU (PICU) Bed (Per Night)',
                        },
                        {
                          'id': 'hdu',
                          'name': 'High Dependency Unit (HDU) Bed (Per Night)',
                        },
                        {
                          'id': 'isolation_ward',
                          'name': 'Isolation Ward Bed (Per Night)',
                        },
                        {
                          'id': 'emergency_observation',
                          'name': 'Emergency Observation Bed (Per Night)',
                        },
                        {
                          'id': 'short_stay_ward',
                          'name': 'Short Stay Ward (Per Night)',
                        },
                        {
                          'id': 'recovery_room',
                          'name': 'Recovery Room (Per Hour)',
                        },
                        {
                          'id': 'amenity_bed',
                          'name': 'Amenity Bed (Per Night)',
                        },
                        {
                          'id': 'parent_accommodation',
                          'name': 'Parent/Guardian Accommodation (Per Night)',
                        },
                      ];

                      final wardCareServices = [
                        {
                          'id': 'daily_nursing_care',
                          'name': 'Daily Nursing Care (24hrs)',
                        },
                        {
                          'id': 'vital_monitoring_ward',
                          'name': 'Vital Signs Monitoring (Per Day)',
                        },
                        {
                          'id': 'medication_administration',
                          'name': 'Medication Administration (Per Day)',
                        },
                        {
                          'id': 'personal_hygiene_assistance',
                          'name': 'Personal Hygiene Assistance',
                        },
                        {
                          'id': 'special_nursing_care',
                          'name': 'Special Nursing Care (1:1)',
                        },
                        {
                          'id': 'intensive_nursing',
                          'name': 'Intensive Nursing Care (Per Day)',
                        },
                        {
                          'id': 'post_op_care',
                          'name': 'Post-Operative Care (Per Day)',
                        },
                        {
                          'id': 'patient_feeding_standard',
                          'name': 'Patient Feeding - Standard Meal',
                        },
                        {
                          'id': 'patient_feeding_therapeutic',
                          'name': 'Patient Feeding - Therapeutic Diet',
                        },
                        {
                          'id': 'patient_feeding_liquid',
                          'name': 'Patient Feeding - Liquid Diet',
                        },
                        {
                          'id': 'nasogastric_feeding',
                          'name': 'Nasogastric Tube Feeding (Per Day)',
                        },
                        {
                          'id': 'oxygen_therapy',
                          'name': 'Oxygen Therapy (Per Day)',
                        },
                        {
                          'id': 'nebulization_ward',
                          'name': 'Nebulization Treatment (Per Session)',
                        },
                        {
                          'id': 'cardiac_monitoring',
                          'name': 'Cardiac Monitoring (Per Day)',
                        },
                        {
                          'id': 'iv_infusion_monitoring',
                          'name': 'IV Infusion Monitoring (Per Day)',
                        },
                        {
                          'id': 'physiotherapy_session',
                          'name': 'Physiotherapy Session',
                        },
                        {
                          'id': 'chest_physiotherapy',
                          'name': 'Chest Physiotherapy',
                        },
                        {
                          'id': 'occupational_therapy',
                          'name': 'Occupational Therapy Session',
                        },
                        {
                          'id': 'bed_linen_change',
                          'name': 'Bed Linen Change (Daily)',
                        },
                        {'id': 'bedpan_service', 'name': 'Bedpan Service'},
                        {'id': 'bed_bath', 'name': 'Bed Bath Service'},
                        {
                          'id': 'ward_rounds',
                          'name': 'Daily Ward Round (Doctor)',
                        },
                        {
                          'id': 'nursing_notes',
                          'name': 'Nursing Documentation (Per Day)',
                        },
                        {
                          'id': 'discharge_planning',
                          'name': 'Discharge Planning Services',
                        },
                      ];

                      // Build available ward services with prices
                      List<Map<String, dynamic>> availableServices = [];

                      for (var service in wardAccommodationServices) {
                        if (servicePrices.containsKey(service['id'])) {
                          final price = servicePrices[service['id']];
                          if (price != null && price > 0) {
                            availableServices.add({
                              'id': service['id'],
                              'name': service['name'],
                              'price': price,
                              'category': 'Accommodation',
                            });
                          }
                        }
                      }

                      for (var service in wardCareServices) {
                        if (servicePrices.containsKey(service['id'])) {
                          final price = servicePrices[service['id']];
                          if (price != null && price > 0) {
                            availableServices.add({
                              'id': service['id'],
                              'name': service['name'],
                              'price': price,
                              'category': 'Care Services',
                            });
                          }
                        }
                      }

                      if (availableServices.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No ward services configured yet. Contact facility admin to set up ward admission pricing in Service Management.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: selectedWardService,
                            decoration: const InputDecoration(
                              labelText: 'Select Ward Service *',
                              prefixIcon: Icon(Icons.payments),
                              border: OutlineInputBorder(),
                              helperText:
                                  'Prices are set by facility admin in Service Management',
                            ),
                            items: availableServices.map((service) {
                              return DropdownMenuItem<String>(
                                value: service['id'],
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            service['name'],
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            service['category'],
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₦${(service['price'] as num).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedWardService = value;
                                final selectedService = availableServices
                                    .firstWhere(
                                      (service) => service['id'] == value,
                                    );
                                selectedServicePrice =
                                    (selectedService['price'] as num)
                                        .toDouble();
                                selectedServiceName =
                                    selectedService['name'] as String?;
                                selectedServiceCategory =
                                    selectedService['category'] as String?;

                                // Get billing metadata from service_management_screen structure
                                // These will be used for automatic billing
                                if (selectedService['category'] ==
                                    'Accommodation') {
                                  selectedBillingCycle = 'daily';
                                  selectedAutoCharge = 'daily_if_admitted';
                                } else if (selectedService['category'] ==
                                    'Care Services') {
                                  selectedBillingCycle = 'per_service';
                                  selectedAutoCharge = 'manual';
                                } else {
                                  selectedBillingCycle = 'daily';
                                  selectedAutoCharge = 'manual';
                                }
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a ward service';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          if (selectedServicePrice > 0) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Rate: ₦${selectedServicePrice.toStringAsFixed(2)} per night',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Admission Notes
                  TextFormField(
                    controller: admissionNotesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Admission Notes',
                      hintText:
                          'Enter any critical information about the patient...',
                      prefixIcon: Icon(Icons.note_alt),
                      border: OutlineInputBorder(),
                      helperText:
                          'Important patient information for ward staff',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Billing will start daily at 11:59 PM after acceptance',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                if (selectedServicePrice == 0.0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a ward service'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );

                try {
                  final now = DateTime.now();
                  final batch = FirebaseFirestore.instance.batch();

                  // 1. Update admission record
                  final admissionRef = FirebaseFirestore.instance
                      .collection('admissions')
                      .doc(patientDocId);

                  // Preserve the original admitting doctor information
                  final admittedByName =
                      patient['admittedByName'] ??
                      patient['admittingDoctorName'] ??
                      patient['admittedBy'] ??
                      widget.staffName;

                  batch.update(admissionRef, {
                    'status': 'admitted',
                    'chargePerNight': selectedServicePrice,
                    'wardServiceId': selectedWardService,
                    'wardServiceName': selectedServiceName ?? 'Unknown Service',
                    'wardServiceCategory': selectedServiceCategory ?? 'Unknown',
                    'billingCycle': selectedBillingCycle ?? 'daily',
                    'admissionNotes': admissionNotesController.text.trim(),
                    'acceptedAt': FieldValue.serverTimestamp(),
                    'acceptedBy': widget.staffId,
                    'acceptedByName': widget.staffName,
                    'admittedByName':
                        admittedByName, // Preserve original admitting doctor
                    'totalChargedAmount': 0,
                    'chargeCount': 0,
                    'lastBillingDate': null,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  // 2. Create initial billing record (pending until service is rendered)
                  final billingRef = FirebaseFirestore.instance
                      .collection('patient_bills')
                      .doc();

                  batch.set(billingRef, {
                    'billId': billingRef.id,
                    'facilityId': widget.facilityId,
                    'patientId': patient['patientId'],
                    'patientName': patient['patientName'] ?? 'Unknown',
                    'inpatientDocId': patientDocId,
                    'serviceId': selectedWardService,
                    'serviceName': selectedServiceName ?? 'Unknown Service',
                    'serviceCategory': selectedServiceCategory ?? 'Unknown',
                    'billingCycle': selectedBillingCycle ?? 'daily',
                    'unitPrice': selectedServicePrice,
                    'quantity': 1,
                    'totalAmount': selectedServicePrice,
                    'status': 'pending', // pending, charged, failed
                    'billType':
                        'accommodation', // accommodation, care_service, procedure
                    'billedAt': FieldValue.serverTimestamp(),
                    'billedBy': widget.staffId,
                    'billedByName': widget.staffName,
                    'dueDate': Timestamp.fromDate(
                      now.add(const Duration(days: 1)),
                    ),
                    'chargedAt': null,
                    'notes':
                        'Initial admission billing for ${selectedServiceName ?? 'ward service'}',
                    'autoCharge': selectedAutoCharge ?? 'manual',
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  // 3. Create admission activity log
                  final activityRef = FirebaseFirestore.instance
                      .collection('admissions')
                      .doc(patientDocId)
                      .collection('billing_activities')
                      .doc();

                  batch.set(activityRef, {
                    'activityId': activityRef.id,
                    'type': 'admission_accepted',
                    'description':
                        'Admission accepted - ${selectedServiceName ?? 'ward service'} selected (₦${selectedServicePrice.toStringAsFixed(0)}/night)',
                    'serviceId': selectedWardService,
                    'serviceName': selectedServiceName ?? 'Unknown Service',
                    'amount': selectedServicePrice,
                    'performedBy': widget.staffId,
                    'performedByName': widget.staffName,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  // Execute batch
                  await batch.commit();

                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Admission accepted! Bill created: ${selectedServiceName ?? 'Ward Service'} - ₦${selectedServicePrice.toStringAsFixed(0)}',
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error accepting admission: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 20),
                  SizedBox(width: 8),
                  Text('Accept & Start Billing'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelAdmissionDialog(
    String patientDocId,
    Map<String, dynamic> patient,
  ) {
    final cancellationReasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Flexible(
              child: Text('Cancel Admission', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Patient Information
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient: ${patient['patientName'] ?? 'Unknown'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ward: ${patient['ward'] ?? 'N/A'} - Bed ${patient['bedNumber'] ?? 'N/A'}',
                      ),
                      if (patient['admissionReason'] != null)
                        Text('Reason: ${patient['admissionReason']}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Cancellation Reason (Required)
                const Text(
                  'Cancellation Reason *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: cancellationReasonController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText:
                        'Please provide a detailed reason for cancelling this admission...',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Cancellation reason is required';
                    }
                    if (value.trim().length < 10) {
                      return 'Please provide a detailed reason (minimum 10 characters)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  '⚠️ This action will:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('• Release the assigned bed'),
                const Text(
                  '• Return the patient to the originating department',
                ),
                const Text('• Notify the originating department'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                final String cancellationReason = cancellationReasonController
                    .text
                    .trim();
                final String? bedId = patient['bedId'];
                final String? wardId = patient['wardId'] ?? widget.wardId;
                final String? originatingDepartment = patient['admittedBy'];

                // 1. Update admission record to cancelled
                await FirebaseFirestore.instance
                    .collection('admissions')
                    .doc(patientDocId)
                    .update({
                      'status': 'cancelled',
                      'cancelledAt': FieldValue.serverTimestamp(),
                      'cancelledBy': widget.staffId,
                      'cancelledByName': widget.staffName,
                      'cancellationReason': cancellationReason,
                    });

                // 2. Release the bed
                if (bedId != null &&
                    bedId.isNotEmpty &&
                    wardId != null &&
                    wardId.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('facilities')
                      .doc(widget.facilityId)
                      .collection('wards')
                      .doc(wardId)
                      .collection('beds')
                      .doc(bedId)
                      .update({
                        'status': 'available',
                        'currentPatientId': FieldValue.delete(),
                        'currentPatientName': FieldValue.delete(),
                        'occupiedAt': FieldValue.delete(),
                      });
                }

                // 3. Send notification to originating department
                if (originatingDepartment != null &&
                    originatingDepartment.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('messages').add({
                    'facilityId': widget.facilityId,
                    'recipientId': originatingDepartment,
                    'recipientType': 'staff',
                    'senderId': widget.staffId,
                    'senderName': widget.staffName,
                    'senderType': 'staff',
                    'subject': 'Admission Cancelled',
                    'message':
                        'Admission for patient "${patient['patientName']}" has been cancelled.\n\n'
                        'Ward: ${patient['ward']}\n'
                        'Bed: ${patient['bedNumber']}\n\n'
                        'Reason: $cancellationReason\n\n'
                        'Cancelled by: ${widget.staffName}',
                    'type': 'system_alert',
                    'status': 'unread',
                    'createdAt': FieldValue.serverTimestamp(),
                    'priority': 'high',
                  });
                }

                if (mounted) {
                  Navigator.pop(context); // Close loading
                  Navigator.pop(context); // Close dialog

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Admission cancelled. Patient returned to ${originatingDepartment ?? 'originating department'}.',
                      ),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error cancelling admission: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cancel, size: 20),
                SizedBox(width: 8),
                Text('Confirm Cancellation'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _viewPatientRecords(
    Map<String, dynamic> patient,
    String admissionDocId,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientMedicalRecordsViewer(
          patientId: patient['patientId'] ?? '',
          patientName: patient['patientName'] ?? 'Unknown Patient',
          facilityId: widget.facilityId,
          isInpatient: true,
          hasAdmissionHistory: true,
          admissionData: patient,
        ),
      ),
    );
  }

  void _recordVitals(Map<String, dynamic> patient) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.monitor_heart, size: 48, color: Colors.red.shade600),
        title: const Text('Record Vital Signs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to record vital signs for:',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      patient['patientName'] ?? 'Unknown Patient',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.hotel, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'Ward: ${patient['wardName'] ?? 'N/A'} | Bed: ${patient['bedNumber'] ?? 'N/A'}',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continue'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VitalsRecordingScreen(
          facilityId: widget.facilityId,
          patientId: patient['patientId'] ?? '',
          patientName: patient['patientName'] ?? 'Unknown Patient',
        ),
      ),
    );
  }

  void _recordProcedure(Map<String, dynamic> patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientProcedureRecordingScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          staffName: widget.staffName,
          preSelectedPatientId: patient['patientId'] ?? '',
          preSelectedPatientName: patient['patientName'] ?? 'Unknown Patient',
        ),
      ),
    );
  }

  void _transferPatient(Map<String, dynamic> patient, String patientDocId) {
    // Use emergency-specific transfer for Emergency dashboard, general transfer for others
    if (widget.filterByEmergency) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmergencyPatientTransferScreen(
            facilityId: widget.facilityId,
            facilityName: widget.facilityName,
            staffId: widget.staffId,
            staffName: widget.staffName,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientTransferScreen(
            facilityId: widget.facilityId,
            facilityName: widget.facilityName,
            staffId: widget.staffId,
            staffName: widget.staffName,
          ),
        ),
      );
    }
  }
}
