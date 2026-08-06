// ignore_for_file: sort_child_properties_last, prefer_const_declarations, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifecare_connect/features/shared/data/services/message_service.dart';

// Top-level dialog function for user selection (only one definition)
void showUserSelectionDialog(BuildContext context, String role) {
  TextEditingController searchController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Select ${role[0].toUpperCase()}${role.substring(1)}'),
            content: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search $role...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: role)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final users = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['fullName'] ?? data['name'] ?? '')
                            .toString()
                            .toLowerCase();
                        final email = (data['email'] ?? '')
                            .toString()
                            .toLowerCase();
                        final query = searchController.text.toLowerCase();
                        return name.contains(query) || email.contains(query);
                      }).toList();
                      if (users.isEmpty) {
                        return const Text('No users found');
                      }
                      return SizedBox(
                        height: 250,
                        child: ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user =
                                users[index].data() as Map<String, dynamic>;
                            final userId = users[index].id;
                            final userName =
                                user['fullName'] ?? user['name'] ?? 'Unknown';
                            final userEmail = user['email'] ?? '';
                            return ListTile(
                              leading: CircleAvatar(child: Text(userName[0])),
                              title: Text(userName),
                              subtitle: Text(userEmail),
                              onTap: () async {
                                Navigator.pop(context);
                                final facilityId =
                                    FirebaseAuth.instance.currentUser?.uid ??
                                    '';
                                final facilityName = 'Facility';
                                if (role == 'patient') {
                                  // Create conversation in 'conversations' with correct patient info
                                  final conversationDoc =
                                      await FirebaseFirestore.instance
                                          .collection('conversations')
                                          .add({
                                            'participants': [
                                              facilityId,
                                              userId,
                                            ],
                                            'type': 'patient_facility',
                                            'patientId': userId,
                                            'patientName': userName,
                                            'facilityId': facilityId,
                                            'facilityName': facilityName,
                                            'lastMessage': '',
                                            'lastMessageTime':
                                                FieldValue.serverTimestamp(),
                                          });
                                  if (context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            FacilityConversationScreen(
                                              conversationId:
                                                  conversationDoc.id,
                                              conversationData: {
                                                'participantNames': {
                                                  facilityId: facilityName,
                                                  userId: userName,
                                                },
                                                'type': 'patient_facility',
                                                'patientName': userName,
                                              },
                                              currentUserId: facilityId,
                                            ),
                                      ),
                                    );
                                  }
                                } else {
                                  // ...existing code for doctor/chw...
                                  final conversationId =
                                      await MessageService.createOrGetConversation(
                                        user1Id: facilityId,
                                        user1Name: facilityName,
                                        user1Role: 'facility',
                                        user2Id: userId,
                                        user2Name: userName,
                                        user2Role: role,
                                        title: 'Private Chat',
                                        type: 'direct',
                                      );
                                  if (context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            FacilityConversationScreen(
                                              conversationId: conversationId,
                                              conversationData: {
                                                'participantNames': {
                                                  facilityId: facilityName,
                                                  userId: userName,
                                                },
                                                'type': 'direct',
                                              },
                                              currentUserId: facilityId,
                                            ),
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    },
  );
}

class FacilityMessagesScreen extends StatefulWidget {
  final bool isStaff;

  const FacilityMessagesScreen({super.key, this.isStaff = false});

  @override
  State<FacilityMessagesScreen> createState() => _FacilityMessagesScreenState();
}

class _FacilityMessagesScreenState extends State<FacilityMessagesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _externalTabController;
  String currentUserId = '';

  @override
  void initState() {
    super.initState();
    _externalTabController = TabController(length: 5, vsync: this);
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    if (widget.isStaff) {
      // For staff, load from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final staffId = prefs.getString('staff_id');

      if (mounted) {
        setState(() {
          currentUserId = staffId ?? '';
        });
      }
    } else {
      // For facility owners, use Firebase Auth UID
      currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    }
  }

  @override
  void dispose() {
    _externalTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showNewMessageDialog(context),
          ),
        ],
      ),
      body: _buildExternalUsersView(),
    );
  }

  Widget _buildExternalUsersView() {
    return Column(
      children: [
        // Sub Tab Bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _externalTabController,
            indicatorColor: Colors.purple.shade700,
            labelColor: Colors.purple.shade700,
            unselectedLabelColor: Colors.grey,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.campaign, size: 20), text: "Broadcast"),
              Tab(
                icon: Icon(Icons.admin_panel_settings, size: 20),
                text: "Admin",
              ),
              Tab(icon: Icon(Icons.local_hospital, size: 20), text: "Doctors"),
              Tab(icon: Icon(Icons.health_and_safety, size: 20), text: "CHWs"),
              Tab(icon: Icon(Icons.people, size: 20), text: "Patients"),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _externalTabController,
            children: [
              FacilityBroadcastMessagesTab(currentUserId: currentUserId),
              FacilityAdminMessagesTab(currentUserId: currentUserId),
              FacilityDoctorMessagesTab(currentUserId: currentUserId),
              FacilityCHWMessagesTab(currentUserId: currentUserId),
              FacilityPatientMessagesTab(currentUserId: currentUserId),
            ],
          ),
        ),
      ],
    );
  }

  void _showNewMessageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Message'),
        content: const Text(
          'Select a tab to compose a new message to the specific group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Facility Admin Messages Tab
class FacilityAdminMessagesTab extends StatefulWidget {
  final String currentUserId;

  const FacilityAdminMessagesTab({super.key, required this.currentUserId});

  @override
  State<FacilityAdminMessagesTab> createState() =>
      _FacilityAdminMessagesTabState();
}

class _FacilityAdminMessagesTabState extends State<FacilityAdminMessagesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: widget.currentUserId)
          .where('type', isEqualTo: 'admin_facility')
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No admin conversations yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Messages with admin will appear here',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New Message'),
                  onPressed: () => _showAdminSelectionDialog(context),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.deepPurple,
                  ),
                ),
                title: Text(
                  data['adminName'] ?? 'Admin',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      data['lastMessage'] ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(data['lastMessageTime']),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: data['unreadCount'] != null && data['unreadCount'] > 0
                    ? CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Text(
                          '${data['unreadCount']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
                isThreeLine: true,
                onTap: () => _openConversation(context, doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No messages';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showAdminSelectionDialog(BuildContext context) {
    showUserSelectionDialog(context, 'admin');
  }

  void _openConversation(
    BuildContext context,
    String conversationId,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityConversationScreen(
          conversationId: conversationId,
          conversationData: data,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }
}

// Facility Department Messages Tab (Department-to-Department Communication)
class FacilityDepartmentMessagesTab extends StatefulWidget {
  final String currentUserId;
  final String facilityName;

  const FacilityDepartmentMessagesTab({
    super.key,
    required this.currentUserId,
    required this.facilityName,
  });

  @override
  State<FacilityDepartmentMessagesTab> createState() =>
      _FacilityDepartmentMessagesTabState();
}

class _FacilityDepartmentMessagesTabState
    extends State<FacilityDepartmentMessagesTab> {
  String? _currentDepartment;

  @override
  void initState() {
    super.initState();
    _loadCurrentDepartment();
  }

  Future<void> _loadCurrentDepartment() async {
    final prefs = await SharedPreferences.getInstance();
    final department = prefs.getString('staff_department');
    if (mounted) {
      setState(() {
        _currentDepartment = department;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // List of all departments available for messaging
    final allDepartments = [
      {
        'name': 'Facility Admin',
        'icon': Icons.admin_panel_settings,
        'color': Colors.purple,
      },
      {'name': 'OPD', 'icon': Icons.local_hospital, 'color': Colors.blue},
      {
        'name': 'Nursing',
        'icon': Icons.health_and_safety,
        'color': Colors.pink,
      },
      {'name': 'Laboratory', 'icon': Icons.biotech, 'color': Colors.teal},
      {'name': 'Pharmacy', 'icon': Icons.medication, 'color': Colors.green},
      {
        'name': 'Specialist',
        'icon': Icons.medical_services,
        'color': Colors.indigo,
      },
      {
        'name': 'Medical Records',
        'icon': Icons.folder_shared,
        'color': Colors.orange,
      },
      {
        'name': 'Billing',
        'icon': Icons.account_balance_wallet,
        'color': Colors.amber,
      },
      {'name': 'Ward', 'icon': Icons.hotel, 'color': Colors.brown},
    ];

    // Filter out current department (don't show department they're already in)
    final departments = allDepartments.where((dept) {
      if (_currentDepartment == null) {
        return true; // Show all if department not loaded yet
      }

      // Map department names to match what's stored
      final deptName = dept['name'] as String;

      // Check for matches (case-insensitive and handle variations)
      if (_currentDepartment!.toLowerCase().contains('opd') &&
          deptName == 'OPD') {
        return false; // Exclude OPD if user is in OPD
      }
      if (_currentDepartment!.toLowerCase().contains('nursing') &&
          deptName == 'Nursing') {
        return false;
      }
      if (_currentDepartment!.toLowerCase().contains('lab') &&
          deptName == 'Laboratory') {
        return false;
      }
      if (_currentDepartment!.toLowerCase().contains('pharmacy') &&
          deptName == 'Pharmacy') {
        return false;
      }
      if (_currentDepartment!.toLowerCase().contains('specialist') &&
          deptName == 'Specialist') {
        return false;
      }
      if (_currentDepartment!.toLowerCase().contains('medical records') &&
          deptName == 'Medical Records') {
        return false;
      }
      if (_currentDepartment!.toLowerCase().contains('billing') &&
          deptName == 'Billing') {
        return false;
      }
      if (_currentDepartment!.toLowerCase().contains('ward') &&
          deptName == 'Ward') {
        return false;
      }

      return true; // Include all other departments
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.purple.shade50,
          child: Row(
            children: [
              Icon(Icons.business, color: Colors.purple.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.facilityName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_currentDepartment != null)
                      Text(
                        'Department: $_currentDepartment',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Active Conversations Section
        Expanded(
          child: _currentDepartment == null
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('conversations')
                      .where('type', isEqualTo: 'department')
                      .where('facilityName', isEqualTo: widget.facilityName)
                      .where(
                        'participants',
                        arrayContains: widget.currentUserId,
                      )
                      .orderBy('lastMessageTime', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final conversations = snapshot.data?.docs ?? [];

                    return CustomScrollView(
                      slivers: [
                        // Active Conversations Header
                        if (conversations.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.grey[100],
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.chat_bubble,
                                    color: Colors.grey[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Active Conversations',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Active Conversations List
                        if (conversations.isNotEmpty)
                          SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final convData =
                                  conversations[index].data()
                                      as Map<String, dynamic>;
                              final departments =
                                  convData['departments'] as List<dynamic>? ??
                                  [];

                              // Find the other department (not current one)
                              String otherDepartment = '';
                              for (var dept in departments) {
                                if (!_currentDepartment!.toLowerCase().contains(
                                      dept.toString().toLowerCase(),
                                    ) &&
                                    !dept.toString().toLowerCase().contains(
                                      _currentDepartment!.toLowerCase(),
                                    )) {
                                  otherDepartment = dept;
                                  break;
                                }
                              }

                              // Fallback: use receiverDepartment or senderDepartment
                              if (otherDepartment.isEmpty) {
                                final receiver =
                                    convData['receiverDepartment'] ?? '';
                                final sender =
                                    convData['senderDepartment'] ?? '';
                                otherDepartment = receiver == _currentDepartment
                                    ? sender
                                    : receiver;
                              }

                              final lastMessage = convData['lastMessage'] ?? '';
                              final deptInfo = allDepartments.firstWhere(
                                (d) => d['name'] == otherDepartment,
                                orElse: () => {
                                  'name': otherDepartment,
                                  'icon': Icons.message,
                                  'color': Colors.grey,
                                },
                              );

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        (deptInfo['color'] as Color)
                                            .withOpacity(0.2),
                                    child: Icon(
                                      deptInfo['icon'] as IconData,
                                      color: deptInfo['color'] as Color,
                                    ),
                                  ),
                                  title: Text(
                                    otherDepartment,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    lastMessage.isEmpty
                                        ? 'No messages yet'
                                        : lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            FacilityConversationScreen(
                                              conversationId:
                                                  conversations[index].id,
                                              conversationData: {
                                                'type': 'department',
                                                'departmentName':
                                                    otherDepartment,
                                                'facilityName':
                                                    widget.facilityName,
                                                'departmentIcon':
                                                    (deptInfo['icon']
                                                            as IconData)
                                                        .codePoint,
                                                'departmentColor':
                                                    (deptInfo['color'] as Color)
                                                        .value,
                                              },
                                              currentUserId:
                                                  widget.currentUserId,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }, childCount: conversations.length),
                          ),

                        // Start New Conversation Header
                        SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.grey[100],
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_comment,
                                  color: Colors.grey[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Start New Conversation',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Available Departments List
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildDepartmentCard(
                              context,
                              departments[index]['name'] as String,
                              departments[index]['icon'] as IconData,
                              departments[index]['color'] as Color,
                            ),
                            childCount: departments.length,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDepartmentCard(
    BuildContext context,
    String departmentName,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          departmentName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Send message to $departmentName',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () =>
            _openDepartmentConversation(context, departmentName, icon, color),
      ),
    );
  }

  void _openDepartmentConversation(
    BuildContext context,
    String departmentName,
    IconData icon,
    Color color,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final senderDepartment = prefs.getString('staff_department') ?? '';

      // Create or get conversation for department
      // For department conversations, we need a bidirectional approach
      // Sort department names to ensure consistent conversation ID regardless of who initiates
      final departments = [senderDepartment, departmentName]..sort();

      final conversationQuery = await FirebaseFirestore.instance
          .collection('conversations')
          .where('type', isEqualTo: 'department')
          .where('facilityName', isEqualTo: widget.facilityName)
          .where(
            'departments',
            isEqualTo: departments,
          ) // Use sorted array of both departments
          .limit(1)
          .get();

      String conversationId;

      if (conversationQuery.docs.isEmpty) {
        // Create new department conversation
        final newConversation = await FirebaseFirestore.instance
            .collection('conversations')
            .add({
              'type': 'department',
              'facilityName': widget.facilityName,
              'departments': departments, // Both departments
              'senderDepartment': senderDepartment, // Who initiated
              'receiverDepartment': departmentName, // Target department
              'participants': [
                widget.currentUserId,
              ], // Will be added to as others join
              'createdAt': FieldValue.serverTimestamp(),
              'lastMessage': '',
              'lastMessageTime': FieldValue.serverTimestamp(),
            });
        conversationId = newConversation.id;
      } else {
        conversationId = conversationQuery.docs.first.id;

        // Add current user to participants if not already there
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationId)
            .update({
              'participants': FieldValue.arrayUnion([widget.currentUserId]),
            });
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FacilityConversationScreen(
              conversationId: conversationId,
              conversationData: {
                'type': 'department',
                'departmentName': departmentName,
                'facilityName': widget.facilityName,
                'departmentIcon': icon.codePoint,
                'departmentColor': color.value,
              },
              currentUserId: widget.currentUserId,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Facility Staff Messages Tab (Individual - Keep for reference but not used for staff)
class FacilityStaffMessagesTab extends StatelessWidget {
  final String currentUserId;
  final String facilityName;

  const FacilityStaffMessagesTab({
    super.key,
    required this.currentUserId,
    required this.facilityName,
  });

  @override
  Widget build(BuildContext context) {
    final staffCollection =
        '${facilityName.toLowerCase().replaceAll(' ', '_')}_users';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('participants', arrayContains: currentUserId)
          .where('type', isEqualTo: 'facility_staff_internal')
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'No staff conversations yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  'Messages with your facility staff will appear here',
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Message Staff'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () =>
                      _showStaffSelectionDialog(context, staffCollection),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.shade100,
                  child: const Icon(Icons.person, color: Colors.purple),
                ),
                title: Text(
                  data['staffName'] ?? 'Staff',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      data['staffDepartment'] ?? 'Staff Member',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data['lastMessage'] ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(data['lastMessageTime']),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: data['unreadCount'] != null && data['unreadCount'] > 0
                    ? CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Text(
                          '${data['unreadCount']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
                isThreeLine: true,
                onTap: () => _openConversation(context, doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No messages';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showStaffSelectionDialog(BuildContext context, String staffCollection) {
    TextEditingController searchController = TextEditingController();

    // Debug: Print collection being queried

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select Staff Member'),
                  const SizedBox(height: 4),
                  Text(
                    facilityName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search staff...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection(staffCollection)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.error,
                                  color: Colors.red,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Error loading staff',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${snapshot.error}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Collection: $staffCollection',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Facility: $facilityName',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.people_outline,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No staff registered yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Collection: $staffCollection',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Facility: $facilityName',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Register staff from the Staff menu to message them here.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        // Filter staff: not restricted and matches search
                        final staff = snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final isRestricted = data['isRestricted'] ?? false;

                          // Skip restricted staff
                          if (isRestricted) return false;

                          // If no search query, include all non-restricted staff
                          if (searchController.text.isEmpty) return true;

                          // Apply search filter
                          final name = (data['fullName'] ?? '')
                              .toString()
                              .toLowerCase();
                          final department = (data['department'] ?? '')
                              .toString()
                              .toLowerCase();
                          final profession = (data['profession'] ?? '')
                              .toString()
                              .toLowerCase();
                          final query = searchController.text.toLowerCase();
                          return name.contains(query) ||
                              department.contains(query) ||
                              profession.contains(query);
                        }).toList();

                        if (staff.isEmpty) {
                          return Column(
                            children: [
                              const Icon(
                                Icons.search_off,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                searchController.text.isEmpty
                                    ? 'No active staff members'
                                    : 'No staff found matching "${searchController.text}"',
                                style: const TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        }
                        return SizedBox(
                          height: 250,
                          child: ListView.builder(
                            itemCount: staff.length,
                            itemBuilder: (context, index) {
                              final staffDoc = staff[index];
                              final staffData =
                                  staffDoc.data() as Map<String, dynamic>;
                              final staffId = staffDoc.id;
                              final staffName =
                                  staffData['fullName'] ?? 'Unknown';
                              final staffDepartment =
                                  staffData['department'] ?? '';
                              final staffProfession =
                                  staffData['profession'] ?? '';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.purple.shade100,
                                  child: Text(staffName[0]),
                                ),
                                title: Text(staffName),
                                subtitle: Text(
                                  '$staffProfession${staffDepartment.isNotEmpty ? ' • $staffDepartment' : ''}',
                                ),
                                onTap: () async {
                                  Navigator.pop(context);
                                  final facilityId = currentUserId;

                                  // Create conversation
                                  final conversationDoc =
                                      await FirebaseFirestore.instance
                                          .collection('messages')
                                          .add({
                                            'participants': [
                                              facilityId,
                                              staffId,
                                            ],
                                            'type': 'facility_staff_internal',
                                            'facilityId': facilityId,
                                            'facilityName': facilityName,
                                            'staffId': staffId,
                                            'staffName': staffName,
                                            'staffDepartment': staffDepartment,
                                            'staffProfession': staffProfession,
                                            'lastMessage': '',
                                            'lastMessageTime':
                                                FieldValue.serverTimestamp(),
                                            'unreadCount': 0,
                                          });

                                  if (context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            FacilityConversationScreen(
                                              conversationId:
                                                  conversationDoc.id,
                                              conversationData: {
                                                'participantNames': {
                                                  facilityId: facilityName,
                                                  staffId: staffName,
                                                },
                                                'type':
                                                    'facility_staff_internal',
                                                'staffName': staffName,
                                                'staffDepartment':
                                                    staffDepartment,
                                              },
                                              currentUserId: facilityId,
                                            ),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openConversation(
    BuildContext context,
    String conversationId,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityConversationScreen(
          conversationId: conversationId,
          conversationData: data,
          currentUserId: currentUserId,
        ),
      ),
    );
  }
}

// Facility Broadcast Messages Tab
class FacilityBroadcastMessagesTab extends StatefulWidget {
  final String currentUserId;

  const FacilityBroadcastMessagesTab({super.key, required this.currentUserId});

  @override
  State<FacilityBroadcastMessagesTab> createState() =>
      _FacilityBroadcastMessagesTabState();
}

class _FacilityBroadcastMessagesTabState
    extends State<FacilityBroadcastMessagesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where(
            'type',
            whereIn: ['broadcast', 'broadcast_message', 'personal_message'],
          )
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No broadcast messages yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  'Important announcements will appear here',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Manual filter for receiverId or participants
        // Accept messages where:
        // 1. receiverId matches current user (direct messages)
        // 2. participants array contains current user (broadcast messages)
        // 3. type is 'broadcast' (legacy broadcast messages for all users)
        final filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final messageType = data['type'] as String?;
          final receiverId = data['receiverId'];
          final participants = data['participants'] as List<dynamic>?;

          // Accept all 'broadcast' type messages (for all users)
          if (messageType == 'broadcast') {
            return true;
          }

          // Accept if receiverId matches
          if (receiverId == widget.currentUserId) {
            return true;
          }

          // Accept if current user is in participants array
          if (participants != null &&
              participants.contains(widget.currentUserId)) {
            return true;
          }

          return false;
        }).toList();

        if (filteredDocs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No broadcast messages yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  'Important announcements will appear here',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: const Icon(Icons.campaign, color: Colors.orange),
                ),
                title: Text(
                  _getPersonalizedSubject(data, widget.currentUserId),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      _getBroadcastContent(data, widget.currentUserId),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by admin • ${_formatTimestamp(data['timestamp'])}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                isThreeLine: true,
                onTap: () => _openMessage(context, doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  String _getBroadcastContent(Map<String, dynamic> data, String userId) {
    // Prefer 'message', fallback to 'content', fallback to 'content' for older messages
    String message = data['message'] ?? '';
    if (message.isEmpty && data['content'] != null) {
      message = data['content'];
    }
    if (message.isEmpty && data['content'] == null && data['content'] != null) {
      message = data['content'];
    }
    String userName =
        data['recipientNames'] != null && data['recipientNames'][userId] != null
        ? data['recipientNames'][userId]
        : '';
    if (userName.isNotEmpty) {
      message = message.replaceAll('{name}', userName);
    }
    return message.isNotEmpty
        ? message
        : (data['content'] ?? 'No message content');
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _openMessage(
    BuildContext context,
    String messageId,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityMessageDetailScreen(
          messageId: messageId,
          messageData: data,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }

  String _getPersonalizedSubject(Map<String, dynamic> data, String userId) {
    // Try to get subject from direct field
    String subject = data['subject'] ?? '';

    // If no direct subject field, try to extract from content
    if (subject.isEmpty) {
      final content = data['content'] ?? '';
      // Look for "Subject: " pattern in broadcast messages
      final subjectMatch = RegExp(
        r'Subject:\s*(.+?)(?:\n|$)',
      ).firstMatch(content);
      if (subjectMatch != null) {
        subject = subjectMatch.group(1)?.trim() ?? 'No Subject';
      } else {
        subject = 'Broadcast Message';
      }
    }

    // Replace name placeholder if present
    String userName =
        data['recipientNames'] != null && data['recipientNames'][userId] != null
        ? data['recipientNames'][userId]
        : '';
    if (userName.isNotEmpty) {
      subject = subject.replaceAll('{name}', userName);
    }
    return subject;
  }
}

// Facility Doctor Messages Tab
class FacilityDoctorMessagesTab extends StatefulWidget {
  final String currentUserId;

  const FacilityDoctorMessagesTab({super.key, required this.currentUserId});

  @override
  State<FacilityDoctorMessagesTab> createState() =>
      _FacilityDoctorMessagesTabState();
}

class _FacilityDoctorMessagesTabState extends State<FacilityDoctorMessagesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: widget.currentUserId)
          .where('type', isEqualTo: 'doctor_facility')
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_hospital, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No doctor conversations yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Messages with doctors will appear here',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New Message'),
                  onPressed: () => _showDoctorSelectionDialog(context),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.local_hospital, color: Colors.blue),
                ),
                title: Text(
                  data['doctorName'] ?? 'Doctor',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      data['lastMessage'] ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(data['lastMessageTime']),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: data['unreadCount'] != null && data['unreadCount'] > 0
                    ? CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Text(
                          '${data['unreadCount']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
                isThreeLine: true,
                onTap: () => _openConversation(context, doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No messages';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showDoctorSelectionDialog(BuildContext context) {
    showUserSelectionDialog(context, 'doctor');
  }

  void _openConversation(
    BuildContext context,
    String conversationId,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityConversationScreen(
          conversationId: conversationId,
          conversationData: data,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }
}

// Facility CHW Messages Tab
class FacilityCHWMessagesTab extends StatefulWidget {
  final String currentUserId;

  const FacilityCHWMessagesTab({super.key, required this.currentUserId});

  @override
  State<FacilityCHWMessagesTab> createState() => _FacilityCHWMessagesTabState();
}

class _FacilityCHWMessagesTabState extends State<FacilityCHWMessagesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: widget.currentUserId)
          .where('type', isEqualTo: 'chw_facility')
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.health_and_safety,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No CHW conversations yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Messages with Community Health Workers will appear here',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New Message'),
                  onPressed: () => _showCHWSelectionDialog(context),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.shade100,
                  child: const Icon(
                    Icons.health_and_safety,
                    color: Colors.teal,
                  ),
                ),
                title: Text(
                  data['chwName'] ?? 'CHW',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      data['lastMessage'] ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(data['lastMessageTime']),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: data['unreadCount'] != null && data['unreadCount'] > 0
                    ? CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Text(
                          '${data['unreadCount']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
                isThreeLine: true,
                onTap: () => _openConversation(context, doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No messages';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showCHWSelectionDialog(BuildContext context) {
    showUserSelectionDialog(context, 'chw');
  }

  void _openConversation(
    BuildContext context,
    String conversationId,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityConversationScreen(
          conversationId: conversationId,
          conversationData: data,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }
}

// Facility Patient Messages Tab
class FacilityPatientMessagesTab extends StatefulWidget {
  final String currentUserId;

  const FacilityPatientMessagesTab({super.key, required this.currentUserId});

  @override
  State<FacilityPatientMessagesTab> createState() =>
      _FacilityPatientMessagesTabState();
}

class _FacilityPatientMessagesTabState extends State<FacilityPatientMessagesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('participantIds', arrayContains: widget.currentUserId)
          .where(
            'participantRoles.${widget.currentUserId}',
            isEqualTo: 'facility',
          )
          .where('isActive', isEqualTo: true)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter conversations to show only those with patients
        final patientConversations = snapshot.hasData
            ? snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final participantRoles =
                    data['participantRoles'] as Map<String, dynamic>?;
                if (participantRoles == null) return false;
                // Check if any other participant is a patient
                return participantRoles.entries.any(
                  (entry) =>
                      entry.key != widget.currentUserId &&
                      entry.value == 'patient',
                );
              }).toList()
            : [];

        if (patientConversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No patient conversations yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Messages with patients will appear here',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New Message'),
                  onPressed: () => _showPatientSelectionDialog(context),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: patientConversations.length,
          itemBuilder: (context, index) {
            final doc = patientConversations[index];
            final data = doc.data() as Map<String, dynamic>;

            // Get patient information
            final participantNames =
                data['participantNames'] as Map<String, dynamic>?;
            final participantRoles =
                data['participantRoles'] as Map<String, dynamic>?;

            String patientName = 'Patient';

            if (participantNames != null && participantRoles != null) {
              participantRoles.forEach((id, role) {
                if (id != widget.currentUserId && role == 'patient') {
                  patientName = participantNames[id] ?? 'Patient';
                }
              });
            }

            // Get unread count for facility
            final unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;
            final unreadCount = unreadCounts?[widget.currentUserId] ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: const Icon(Icons.person, color: Colors.green),
                ),
                title: Text(
                  patientName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      data['lastMessage'] ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(data['lastMessageTime']),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: unreadCount > 0
                    ? CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
                isThreeLine: true,
                onTap: () => _openConversation(context, doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No messages';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showPatientSelectionDialog(BuildContext context) {
    showUserSelectionDialog(context, 'patient');
  }

  void _openConversation(
    BuildContext context,
    String conversationId,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityConversationScreen(
          conversationId: conversationId,
          conversationData: data,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }
}

// Facility Message Detail Screen for broadcast messages
class FacilityMessageDetailScreen extends StatefulWidget {
  final String messageId;
  final Map<String, dynamic> messageData;
  final String currentUserId;

  const FacilityMessageDetailScreen({
    super.key,
    required this.messageId,
    required this.messageData,
    required this.currentUserId,
  });

  @override
  State<FacilityMessageDetailScreen> createState() =>
      _FacilityMessageDetailScreenState();
}

class _FacilityMessageDetailScreenState
    extends State<FacilityMessageDetailScreen> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _markMessageAsRead();
  }

  Future<void> _markMessageAsRead() async {
    try {
      // Mark the message as read
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(widget.messageId)
          .update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.messageData['subject'] ?? 'Message'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Original Message
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.orange.shade100,
                                child: const Icon(
                                  Icons.admin_panel_settings,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Admin',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _formatTimestamp(
                                        widget.messageData['timestamp'],
                                      ),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.messageData['subject'] ?? 'No Subject',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            (widget.messageData['message'] ?? '').isNotEmpty
                                ? widget.messageData['message']
                                : (widget.messageData['content'] ??
                                      'No message content'),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Replies Section
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('messages')
                        .doc(widget.messageId)
                        .collection('replies')
                        .orderBy('timestamp', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Replies',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...snapshot.data!.docs.map((doc) {
                            final replyData =
                                doc.data() as Map<String, dynamic>;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor:
                                              Colors.purple.shade100,
                                          child: const Icon(
                                            Icons.business,
                                            size: 16,
                                            color: Colors.purple,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          replyData['senderName'] ?? 'Facility',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatTimestamp(
                                            replyData['timestamp'],
                                          ),
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(replyData['message'] ?? ''),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Reply Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: InputDecoration(
                      hintText: 'Type your reply...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.purple,
                  child: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendReply,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _sendReply() {
    if (_replyController.text.trim().isEmpty) return;

    FirebaseFirestore.instance
        .collection('messages')
        .doc(widget.messageId)
        .collection('replies')
        .add({
          'message': _replyController.text.trim(),
          'senderId': widget.currentUserId,
          'senderName':
              'Facility User', // You might want to get this from user profile
          'timestamp': FieldValue.serverTimestamp(),
        });

    _replyController.clear();

    // Scroll to bottom to show new reply
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }
}

// Facility Conversation Screen for direct messages
class FacilityConversationScreen extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic> conversationData;
  final String currentUserId;

  const FacilityConversationScreen({
    super.key,
    required this.conversationId,
    required this.conversationData,
    required this.currentUserId,
  });

  @override
  State<FacilityConversationScreen> createState() =>
      _FacilityConversationScreenState();
}

class _FacilityConversationScreenState
    extends State<FacilityConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _clearUnreadCount();
  }

  Future<void> _clearUnreadCount() async {
    try {
      // Clear unread count for this user in this conversation
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({'unreadCounts.${widget.currentUserId}': 0});
    } catch (e) {
      // Silently fail - unread count clearing is not critical
      print('Error clearing unread count: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getConversationTitle()),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .where('conversationId', isEqualTo: widget.conversationId)
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isCurrentUser =
                        data['senderId'] == widget.currentUserId;

                    return Align(
                      alignment: isCurrentUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrentUser
                              ? Colors.purple
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data['content'] ?? data['message'] ?? '',
                              style: TextStyle(
                                color: isCurrentUser
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(data['createdAt']),
                              style: TextStyle(
                                fontSize: 10,
                                color: isCurrentUser
                                    ? Colors.white70
                                    : Colors.grey.shade600,
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

          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.purple,
                  child: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getConversationTitle() {
    // Try to get participant name from participantNames
    final participantNames =
        widget.conversationData['participantNames'] as Map<String, dynamic>?;
    final participantRoles =
        widget.conversationData['participantRoles'] as Map<String, dynamic>?;

    if (participantNames != null && participantRoles != null) {
      // Find the other participant
      for (var entry in participantRoles.entries) {
        if (entry.key != widget.currentUserId) {
          final role = entry.value;
          final name = participantNames[entry.key] ?? 'User';

          // Return name with role indicator
          switch (role) {
            case 'patient':
              return name;
            case 'doctor':
              return 'Dr. $name';
            case 'chw':
              return 'CHW $name';
            case 'admin':
              return 'Admin $name';
            default:
              return name;
          }
        }
      }
    }

    // Fallback to old method
    final type = widget.conversationData['type'] ?? '';
    switch (type) {
      case 'department':
        return widget.conversationData['departmentName'] ?? 'Department';
      case 'doctor_facility':
        return widget.conversationData['doctorName'] ?? 'Doctor';
      case 'chw_facility':
        return widget.conversationData['chwName'] ?? 'CHW';
      case 'patient_facility':
        return widget.conversationData['patientName'] ?? 'Patient';
      case 'admin_facility':
        return widget.conversationData['adminName'] ?? 'Admin';
      case 'facility_staff_internal':
        final staffName = widget.conversationData['staffName'] ?? 'Staff';
        final staffDepartment =
            widget.conversationData['staffDepartment'] ?? '';
        return staffDepartment.isNotEmpty
            ? '$staffName ($staffDepartment)'
            : staffName;
      default:
        return 'Conversation';
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (now.difference(date).inDays == 0) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      final conversationType = widget.conversationData['type'] ?? '';

      // Handle department conversations
      if (conversationType == 'department') {
        final prefs = await SharedPreferences.getInstance();
        final senderDepartment = prefs.getString('staff_department') ?? '';
        final senderName = prefs.getString('staff_name') ?? 'Staff';
        final departmentName = widget.conversationData['departmentName'] ?? '';
        final facilityName = widget.conversationData['facilityName'] ?? '';

        // Add message directly to messages collection
        await FirebaseFirestore.instance.collection('messages').add({
          'conversationId': widget.conversationId,
          'senderId': widget.currentUserId,
          'senderName': senderName,
          'senderDepartment': senderDepartment,
          'receiverDepartment': departmentName,
          'facilityName': facilityName,
          'content': message,
          'message': message,
          'type': 'text',
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Get all participants except sender to update their unread counts
        final conversationDoc = await FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .get();

        final conversationData = conversationDoc.data();
        final participants =
            (conversationData?['participants'] as List<dynamic>?) ?? [];

        // Build unread count increments for all participants except sender
        Map<String, dynamic> unreadCountUpdates = {};
        for (var participantId in participants) {
          if (participantId != widget.currentUserId) {
            unreadCountUpdates['unreadCounts.$participantId'] =
                FieldValue.increment(1);
          }
        }

        // Update conversation last message and unread counts
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .update({
              'lastMessage': message,
              'lastMessageTime': FieldValue.serverTimestamp(),
              ...unreadCountUpdates,
            });
      }
      // Handle facility_staff_internal conversations differently
      else if (conversationType == 'facility_staff_internal') {
        // Get staff information from conversation data
        final staffId = widget.conversationData['staffId'];
        final staffName = widget.conversationData['staffName'] ?? 'Staff';
        final facilityName =
            widget.conversationData['facilityName'] ?? 'Facility';

        if (staffId == null) {
          throw Exception('Staff ID not found');
        }

        // Add message directly to messages collection
        await FirebaseFirestore.instance.collection('messages').add({
          'conversationId': widget.conversationId,
          'senderId': widget.currentUserId,
          'senderName': facilityName,
          'receiverId': staffId,
          'receiverName': staffName,
          'content': message,
          'message': message,
          'type': 'text',
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Update conversation last message
        await FirebaseFirestore.instance
            .collection('messages')
            .doc(widget.conversationId)
            .update({
              'lastMessage': message,
              'lastMessageTime': FieldValue.serverTimestamp(),
            });
      } else {
        // Handle other conversation types using MessageService
        final participantNames =
            widget.conversationData['participantNames']
                as Map<String, dynamic>?;
        final participantRoles =
            widget.conversationData['participantRoles']
                as Map<String, dynamic>?;

        if (participantNames == null || participantRoles == null) {
          throw Exception('Missing participant information');
        }

        // Find the receiver (other participant)
        String receiverId = '';
        String receiverName = '';
        String receiverRole = '';

        participantNames.forEach((id, name) {
          if (id != widget.currentUserId) {
            receiverId = id;
            receiverName = name;
            receiverRole = participantRoles[id] ?? 'patient';
          }
        });

        if (receiverId.isEmpty) {
          throw Exception('Receiver not found');
        }

        // Get sender information
        final senderDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.currentUserId)
            .get();
        final senderData = senderDoc.data() ?? {};
        final senderName =
            senderData['name'] ?? senderData['facilityName'] ?? 'Facility';

        // Send message using MessageService
        await MessageService.sendMessage(
          conversationId: widget.conversationId,
          senderId: widget.currentUserId,
          senderName: senderName,
          senderRole: 'facility',
          receiverId: receiverId,
          receiverName: receiverName,
          receiverRole: receiverRole,
          content: message,
          type: 'text',
        );
      }

      // Auto-scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
      }
    }
  }
}
