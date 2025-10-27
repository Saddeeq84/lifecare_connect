// ignore_for_file: empty_catches

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SearchablePatientSelector extends StatefulWidget {
  final String? selectedPatientId;
  final String? selectedPatientName;
  final Function(String? patientId, String? patientName) onPatientSelected;
  final String? currentUserRole; // 'chw', 'doctor', 'admin'
  final bool isRequired;
  final String? hintText;

  const SearchablePatientSelector({
    super.key,
    this.selectedPatientId,
    this.selectedPatientName,
    required this.onPatientSelected,
    this.currentUserRole,
    this.isRequired = true,
    this.hintText,
  });

  @override
  State<SearchablePatientSelector> createState() =>
      _SearchablePatientSelectorState();
}

class _SearchablePatientSelectorState extends State<SearchablePatientSelector> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _allPatients = [];
  List<Map<String, dynamic>> _filteredPatients = [];
  Timer? _searchDebouncer;
  bool _isLoading = false;
  bool _showDropdown = false;
  String? _selectedPatientId;
  String? _selectedPatientName;

  @override
  void initState() {
    super.initState();
    _selectedPatientId = widget.selectedPatientId;
    _selectedPatientName = widget.selectedPatientName;

    if (_selectedPatientName != null) {
      _searchController.text = _selectedPatientName!;
    }

    _loadPatients();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebouncer?.cancel();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_searchFocusNode.hasFocus) {
      setState(() {
        _showDropdown = true;
        if (_searchController.text.isEmpty) {
          _filteredPatients = List.from(_allPatients);
        }
      });
    }
  }

  void _onSearchChanged() {
    if (_searchDebouncer?.isActive ?? false) _searchDebouncer!.cancel();
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () {
      _filterPatients(_searchController.text);
    });
  }

  void _filterPatients(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPatients = List.from(_allPatients);
      } else {
        _filteredPatients = _allPatients.where((patient) {
          final name = (patient['name'] as String? ?? '').toLowerCase();
          final email = (patient['email'] as String? ?? '').toLowerCase();
          final phone = (patient['phone'] as String? ?? '').toLowerCase();
          final searchQuery = query.toLowerCase();

          return name.contains(searchQuery) ||
              email.contains(searchQuery) ||
              phone.contains(searchQuery);
        }).toList();
      }
      _showDropdown = _filteredPatients.isNotEmpty && _searchFocusNode.hasFocus;
    });
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final patients = await _fetchPatients();
      setState(() {
        _allPatients = patients;
        _filteredPatients = List.from(patients);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading patients: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPatients() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    try {
      final Set<String> patientIds = <String>{};
      final List<Map<String, dynamic>> patients = [];

      if (widget.currentUserRole == 'admin') {
        // Admin can see all patients
        final allPatientsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'patient')
            .orderBy('name')
            .get();
        for (final doc in allPatientsSnapshot.docs) {
          final data = doc.data();
          patients.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unnamed Patient',
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? '',
            'createdBy': data['createdBy'] ?? '',
            'registeredBy': data['registeredBy'] ?? '',
          });
        }
      } else {
        // For CHW, doctor, facility: use the same logic as patient_list_widget.dart
        // 1. Patients registered by this user
        final registeredPatients = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'patient')
            .where('createdBy', isEqualTo: currentUser.uid)
            .get();
        for (final doc in registeredPatients.docs) {
          patientIds.add(doc.id);
        }

        // 2. Patients from health records (consultations, ANC visits, etc.)
        final healthRecords = await FirebaseFirestore.instance
            .collection('health_records')
            .where('providerId', isEqualTo: currentUser.uid)
            .get();
        for (final doc in healthRecords.docs) {
          final data = doc.data();
          if (data['patientUid'] != null) {
            patientIds.add(data['patientUid']);
          }
        }

        // 3. Patients from appointments (approved, completed, attended)
        try {
          final appointments = await FirebaseFirestore.instance
              .collection('appointments')
              .where('providerId', isEqualTo: currentUser.uid)
              .where('status', whereIn: ['approved', 'completed', 'attended'])
              .get();
          for (final doc in appointments.docs) {
            final data = doc.data();
            final patientId = data['patientUid'] ?? data['patientId'];
            if (patientId != null) {
              patientIds.add(patientId);
            }
          }
        } catch (e) {}

        // 3b. Patients from consultations (approved status)
        try {
          final consultations = await FirebaseFirestore.instance
              .collection('consultations')
              .where('providerId', isEqualTo: currentUser.uid)
              .where('status', isEqualTo: 'approved')
              .get();
          for (final doc in consultations.docs) {
            final data = doc.data();
            final patientId = data['patientUid'] ?? data['patientId'];
            if (patientId != null) {
              patientIds.add(patientId);
            }
          }
        } catch (e) {}

        // 4. Patients from referrals (if user referred or received patients)
        try {
          final referrals = await FirebaseFirestore.instance
              .collection('referrals')
              .where('referredById', isEqualTo: currentUser.uid)
              .get();
          for (final doc in referrals.docs) {
            final data = doc.data();
            if (data['patientId'] != null) {
              patientIds.add(data['patientId']);
            }
          }
          final receivedReferrals = await FirebaseFirestore.instance
              .collection('referrals')
              .where('referredToId', isEqualTo: currentUser.uid)
              .get();
          for (final doc in receivedReferrals.docs) {
            final data = doc.data();
            if (data['patientId'] != null) {
              patientIds.add(data['patientId']);
            }
          }
        } catch (e) {}

        // If no interactions found, return empty result
        if (patientIds.isEmpty) {
          return [];
        }

        // Get all patients that match these IDs (handle Firestore 'in' limitation)
        final List<String> patientIdsList = patientIds.toList();
        const int batchSize = 10;
        for (int i = 0; i < patientIdsList.length; i += batchSize) {
          final batch = patientIdsList.sublist(
            i,
            i + batchSize > patientIdsList.length
                ? patientIdsList.length
                : i + batchSize,
          );
          final batchQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'patient')
              .where(FieldPath.documentId, whereIn: batch)
              .get();
          for (final doc in batchQuery.docs) {
            final data = doc.data();
            patients.add({
              'id': doc.id,
              'name': data['name'] ?? 'Unnamed Patient',
              'email': data['email'] ?? '',
              'phone': data['phone'] ?? '',
              'createdBy': data['createdBy'] ?? '',
              'registeredBy': data['registeredBy'] ?? '',
            });
          }
        }
      }

      // Sort patients alphabetically by name
      patients.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );
      return patients;
    } catch (e) {
      debugPrint('Error fetching patients: $e');
      return [];
    }
  }

  void _selectPatient(Map<String, dynamic> patient) {
    setState(() {
      _selectedPatientId = patient['id'] as String;
      _selectedPatientName = patient['name'] as String;
      _searchController.text = _selectedPatientName!;
      _showDropdown = false;
    });

    _searchFocusNode.unfocus();
    widget.onPatientSelected(_selectedPatientId, _selectedPatientName);
  }

  void _clearSelection() {
    setState(() {
      _selectedPatientId = null;
      _selectedPatientName = null;
      _searchController.clear();
      _showDropdown = false;
    });

    widget.onPatientSelected(null, null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Field
        TextFormField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            labelText: widget.hintText ?? 'Search Patients',
            hintText: 'Search by name, email, or phone',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _selectedPatientId != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSelection,
                  )
                : _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          validator: widget.isRequired
              ? (value) {
                  if (_selectedPatientId == null) {
                    return 'Please select a patient';
                  }
                  return null;
                }
              : null,
          onTap: () {
            setState(() {
              _showDropdown = true;
              if (_searchController.text.isEmpty) {
                _filteredPatients = List.from(_allPatients);
              }
            });
          },
        ),

        // Selected Patient Info Card
        if (_selectedPatientId != null) ...[
          const SizedBox(height: 8),
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected: $_selectedPatientName',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        if (_selectedPatientId != null &&
                            _allPatients.isNotEmpty)
                          Builder(
                            builder: (context) {
                              final selectedPatient = _allPatients.firstWhere(
                                (p) => p['id'] == _selectedPatientId,
                                orElse: () => {},
                              );
                              if (selectedPatient.isNotEmpty) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Email: ${selectedPatient['email'] ?? 'N/A'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                    if (selectedPatient['phone'] != null &&
                                        selectedPatient['phone']
                                            .toString()
                                            .isNotEmpty)
                                      Text(
                                        'Phone: ${selectedPatient['phone']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade600,
                                        ),
                                      ),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Dropdown Results
        if (_showDropdown && _filteredPatients.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredPatients.length,
              itemBuilder: (context, index) {
                final patient = _filteredPatients[index];
                final isSelected = patient['id'] == _selectedPatientId;

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: isSelected
                        ? Colors.green
                        : Colors.blue.shade100,
                    child: Text(
                      (patient['name'] as String? ?? 'U')[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.blue.shade700,
                      ),
                    ),
                  ),
                  title: Text(
                    patient['name'] as String? ?? 'Unnamed Patient',
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? Colors.green.shade700 : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (patient['email'] != null &&
                          (patient['email'] as String).isNotEmpty)
                        Text(
                          patient['email'] as String,
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (patient['phone'] != null &&
                          (patient['phone'] as String).isNotEmpty)
                        Text(
                          patient['phone'] as String,
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: Colors.green.shade700)
                      : null,
                  onTap: () => _selectPatient(patient),
                );
              },
            ),
          ),
        ],

        // No Results Message
        if (_showDropdown && _filteredPatients.isEmpty && !_isLoading) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: Text(
              _searchController.text.isEmpty
                  ? 'No patients available'
                  : 'No patients found matching "${_searchController.text}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
