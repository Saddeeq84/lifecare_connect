// Facility Household Management Screen
// For Lifecare Insurance facilities to register and manage households

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'household_dashboard_screen.dart';

class FacilityHouseholdScreen extends StatefulWidget {
  final String? facilityId;

  const FacilityHouseholdScreen({super.key, this.facilityId});

  @override
  State<FacilityHouseholdScreen> createState() =>
      _FacilityHouseholdScreenState();
}

class _FacilityHouseholdScreenState extends State<FacilityHouseholdScreen> {
  String? _currentFacilityId;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeFacilityId();
  }

  Future<void> _initializeFacilityId() async {
    // If facilityId is provided as parameter, use it
    if (widget.facilityId != null) {
      setState(() {
        _currentFacilityId = widget.facilityId;
      });
      return;
    }

    // Otherwise, get from current user (for facility admin)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentFacilityId = user.uid;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Households'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RegisterHouseholdScreen(facilityId: _currentFacilityId),
            ),
          );
          if (result == true && mounted) {
            setState(() {});
          }
        },
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.home_work),
        label: const Text('Register Household'),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search households...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Households List
          Expanded(
            child: _currentFacilityId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('households')
                        .where('facilityId', isEqualTo: _currentFacilityId)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: Colors.teal.shade800,
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error,
                                size: 64,
                                color: Colors.red[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading households: ${snapshot.error}',
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => setState(() {}),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.home_work_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No households registered',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the button below to register a household',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      // Filter households based on search query
                      final households = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final householdName = (data['householdName'] ?? '')
                            .toString()
                            .toLowerCase();
                        final householdLeader = (data['householdLeader'] ?? '')
                            .toString()
                            .toLowerCase();
                        final community = (data['community'] ?? '')
                            .toString()
                            .toLowerCase();
                        return householdName.contains(searchQuery) ||
                            householdLeader.contains(searchQuery) ||
                            community.contains(searchQuery);
                      }).toList();

                      if (households.isEmpty && searchQuery.isNotEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No households match your search',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: households.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final doc = households[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final beneficiaryCount =
                              data['beneficiaryCount'] ?? 0;
                          final maxBeneficiaries = 6;
                          final isAtCapacity =
                              beneficiaryCount >= maxBeneficiaries;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: isAtCapacity
                                    ? Colors.red.shade100
                                    : Colors.teal.shade100,
                                radius: 28,
                                child: Icon(
                                  Icons.home,
                                  color: isAtCapacity
                                      ? Colors.red.shade700
                                      : Colors.teal.shade700,
                                  size: 28,
                                ),
                              ),
                              title: Text(
                                data['householdName'] ?? 'Unknown Household',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'Leader: ${data['householdLeader'] ?? 'N/A'}',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                  Text(
                                    'Community: ${data['community'] ?? 'N/A'}',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                  if (data['phoneNumber'] != null)
                                    Text(
                                      'Phone: ${data['phoneNumber']}',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isAtCapacity
                                              ? Colors.red[100]
                                              : Colors.green[100],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          '$beneficiaryCount/$maxBeneficiaries Beneficiaries',
                                          style: TextStyle(
                                            color: isAtCapacity
                                                ? Colors.red[700]
                                                : Colors.green[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (isAtCapacity) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange[100],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            'AT CAPACITY',
                                            style: TextStyle(
                                              color: Colors.orange[700],
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) => _handleHouseholdAction(
                                  context,
                                  doc.id,
                                  data,
                                  value,
                                ),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'open_dashboard',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.dashboard,
                                          color: Colors.teal,
                                        ),
                                        SizedBox(width: 8),
                                        Text('Open Dashboard'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'view_details',
                                    child: Row(
                                      children: [
                                        Icon(Icons.info),
                                        SizedBox(width: 8),
                                        Text('View Details'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'view_beneficiaries',
                                    child: Row(
                                      children: [
                                        Icon(Icons.people),
                                        SizedBox(width: 8),
                                        Text('View Beneficiaries'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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

  void _handleHouseholdAction(
    BuildContext context,
    String householdId,
    Map<String, dynamic> data,
    String action,
  ) {
    switch (action) {
      case 'open_dashboard':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HouseholdDashboardScreen(
              householdId: householdId,
              facilityId: _currentFacilityId!,
            ),
          ),
        );
        break;
      case 'view_details':
        _showHouseholdDetails(context, data);
        break;
      case 'view_beneficiaries':
        _showBeneficiaries(context, householdId, data);
        break;
      case 'edit':
        _editHousehold(context, householdId, data);
        break;
      case 'delete':
        _deleteHousehold(context, householdId, data);
        break;
    }
  }

  void _showHouseholdDetails(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.shade100,
                  radius: 30,
                  child: Icon(
                    Icons.home,
                    color: Colors.teal.shade700,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['householdName'] ?? 'Unknown Household',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                        ),
                      ),
                      Text(
                        'Household Details',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow('Contact Name', data['householdLeader']),
            _buildDetailRow('Community', data['community']),
            _buildDetailRow('Address', data['address']),
            _buildDetailRow('Lifecare Number', data['meterNumber']),
            _buildDetailRow('Phone Number', data['phoneNumber']),
            _buildDetailRow(
              'Beneficiaries',
              '${data['beneficiaryCount'] ?? 0}/6',
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'Not provided',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showBeneficiaries(
    BuildContext context,
    String householdId,
    Map<String, dynamic> householdData,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Beneficiaries - ${householdData['householdName']}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade800,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('facility_patients')
                      .where('facilityId', isEqualTo: _currentFacilityId)
                      .where('householdId', isEqualTo: householdId)
                      .where('isActive', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('No beneficiaries registered yet'),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final patient = snapshot.data!.docs[index];
                        final patientData =
                            patient.data() as Map<String, dynamic>;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.shade100,
                              child: Text(
                                _getInitials(patientData['fullName'] ?? 'U'),
                                style: TextStyle(
                                  color: Colors.teal.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              patientData['fullName'] ?? 'Unknown Patient',
                            ),
                            subtitle: Text(patientData['phone'] ?? 'No phone'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _editHousehold(
    BuildContext context,
    String householdId,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterHouseholdScreen(
          householdId: householdId,
          initialData: data,
          facilityId: _currentFacilityId,
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        setState(() {});
      }
    });
  }

  void _deleteHousehold(
    BuildContext context,
    String householdId,
    Map<String, dynamic> data,
  ) async {
    // Check if household has beneficiaries
    final beneficiaryCount = data['beneficiaryCount'] ?? 0;
    if (beneficiaryCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete household with $beneficiaryCount beneficiaries. Remove beneficiaries first.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Household'),
        content: Text(
          'Are you sure you want to delete "${data['householdName']}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('households')
            .doc(householdId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Household deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete household: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// Register/Edit Household Screen
class RegisterHouseholdScreen extends StatefulWidget {
  final String? householdId;
  final Map<String, dynamic>? initialData;
  final String? facilityId;

  const RegisterHouseholdScreen({
    super.key,
    this.householdId,
    this.initialData,
    this.facilityId,
  });

  @override
  State<RegisterHouseholdScreen> createState() =>
      _RegisterHouseholdScreenState();
}

class _RegisterHouseholdScreenState extends State<RegisterHouseholdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _householdNameController = TextEditingController();
  final _householdLeaderController = TextEditingController();
  final _communityController = TextEditingController();
  final _addressController = TextEditingController();
  final _meterNumberController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _householdNameController.text =
          widget.initialData!['householdName'] ?? '';
      _householdLeaderController.text =
          widget.initialData!['householdLeader'] ?? '';
      _communityController.text = widget.initialData!['community'] ?? '';
      _addressController.text = widget.initialData!['address'] ?? '';
      _meterNumberController.text = widget.initialData!['meterNumber'] ?? '';
      _phoneNumberController.text = widget.initialData!['phoneNumber'] ?? '';
    }
  }

  @override
  void dispose() {
    _householdNameController.dispose();
    _householdLeaderController.dispose();
    _communityController.dispose();
    _addressController.dispose();
    _meterNumberController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _saveHousehold() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get facilityId from parameter or current user
      String? facilityId = widget.facilityId;

      final householdData = {
        'householdName': _householdNameController.text.trim(),
        'householdLeader': _householdLeaderController.text.trim(),
        'community': _communityController.text.trim(),
        'address': _addressController.text.trim(),
        'meterNumber': _meterNumberController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'facilityId': facilityId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.householdId != null) {
        // Update existing household
        await FirebaseFirestore.instance
            .collection('households')
            .doc(widget.householdId)
            .update(householdData);
      } else {
        // Create new household
        householdData['beneficiaryCount'] = 0;
        householdData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('households')
            .add(householdData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.householdId != null
                  ? 'Household updated successfully!'
                  : 'Household registered successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save household: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.householdId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Household' : 'Register Household'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isSubmitting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal.shade800),
                  const SizedBox(height: 16),
                  Text(
                    isEditing
                        ? 'Updating household...'
                        : 'Registering household...',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Information banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        border: Border.all(color: Colors.teal.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.teal.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Each household can have up to 6 beneficiaries (patients)',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.teal.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Household Information Section
                    Text(
                      'Household Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Household Name
                    TextFormField(
                      controller: _householdNameController,
                      decoration: InputDecoration(
                        labelText: 'Household Name *',
                        prefixIcon: const Icon(Icons.home),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter household name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Contact Name
                    TextFormField(
                      controller: _householdLeaderController,
                      decoration: InputDecoration(
                        labelText: 'Contact Name *',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter contact name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Community
                    TextFormField(
                      controller: _communityController,
                      decoration: InputDecoration(
                        labelText: 'Community *',
                        prefixIcon: const Icon(Icons.location_city),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter community';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Address
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Address *',
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Lifecare Number
                    TextFormField(
                      controller: _meterNumberController,
                      decoration: InputDecoration(
                        labelText: 'Lifecare Number *',
                        prefixIcon: const Icon(Icons.electric_meter),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter Lifecare number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    TextFormField(
                      controller: _phoneNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number *',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter phone number';
                        }
                        if (value.trim().length < 10) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _saveHousehold,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade800,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isEditing ? 'Update Household' : 'Register Household',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}
