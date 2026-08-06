import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class QueueManagementScreen extends StatefulWidget {
  final String facilityId;
  final String staffId;
  final String staffName;

  const QueueManagementScreen({
    super.key,
    required this.facilityId,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<QueueManagementScreen> createState() => _QueueManagementScreenState();
}

class _QueueManagementScreenState extends State<QueueManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _departments = [
    'OPD',
    'Laboratory',
    'Radiology',
    'Pharmacy',
    'Nursing',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _departments.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue Management'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: _departments.map((dept) => Tab(text: dept)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _departments
            .map((dept) => _buildDepartmentQueue(dept))
            .toList(),
      ),
    );
  }

  Widget _buildDepartmentQueue(String department) {
    return Column(
      children: [
        // Queue Statistics
        _buildQueueStats(department),

        // Queue List
        Expanded(child: _buildQueueList(department)),
      ],
    );
  }

  Widget _buildQueueStats(String department) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('queue')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('department', isEqualTo: department)
          .where(
            'date',
            isEqualTo: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        final waiting = docs.where((d) => d['status'] == 'waiting').length;
        final inProgress = docs
            .where((d) => d['status'] == 'in-progress')
            .length;
        final completed = docs.where((d) => d['status'] == 'completed').length;
        final total = docs.length;

        // Calculate average wait time
        double avgWaitTime = 0;
        if (completed > 0) {
          final completedDocs = docs.where((d) => d['status'] == 'completed');
          int totalWaitMinutes = 0;
          for (var doc in completedDocs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['calledAt'] != null && data['joinedAt'] != null) {
              final joined = (data['joinedAt'] as Timestamp).toDate();
              final called = (data['calledAt'] as Timestamp).toDate();
              totalWaitMinutes += called.difference(joined).inMinutes;
            }
          }
          avgWaitTime = totalWaitMinutes / completed;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Waiting',
                      waiting.toString(),
                      Colors.orange,
                      Icons.schedule,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'In Progress',
                      inProgress.toString(),
                      Colors.blue,
                      Icons.play_circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'Completed',
                      completed.toString(),
                      Colors.green,
                      Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'Total',
                      total.toString(),
                      Colors.grey,
                      Icons.people,
                    ),
                  ),
                ],
              ),
              if (avgWaitTime > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, size: 20, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text(
                        'Average Wait Time: ${avgWaitTime.toStringAsFixed(0)} minutes',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(String department) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('queue')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('department', isEqualTo: department)
          .where(
            'date',
            isEqualTo: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          )
          .orderBy('queueNumber', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.queue, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No patients in queue',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _showAddToQueueDialog(department),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Patient to Queue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
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
            final status = data['status'] as String;
            final joinedAt = data['joinedAt'] as Timestamp?;
            final calledAt = data['calledAt'] as Timestamp?;
            final priority = data['priority'] as String? ?? 'normal';

            Color statusColor;
            IconData statusIcon;
            switch (status) {
              case 'waiting':
                statusColor = Colors.orange;
                statusIcon = Icons.schedule;
                break;
              case 'in-progress':
                statusColor = Colors.blue;
                statusIcon = Icons.play_circle;
                break;
              case 'completed':
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
                break;
              default:
                statusColor = Colors.grey;
                statusIcon = Icons.help;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: status == 'in-progress' ? 4 : 1,
              child: ListTile(
                leading: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: priority == 'urgent' ? Colors.red : Colors.teal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#${data['queueNumber']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (priority == 'urgent') ...[
                      const SizedBox(height: 4),
                      const Icon(
                        Icons.priority_high,
                        color: Colors.red,
                        size: 16,
                      ),
                    ],
                  ],
                ),
                title: Text(
                  data['patientName'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (joinedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Joined: ${DateFormat('hh:mm a').format(joinedAt.toDate())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    if (calledAt != null) ...[
                      Text(
                        'Called: ${DateFormat('hh:mm a').format(calledAt.toDate())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    if (status == 'waiting' && joinedAt != null) ...[
                      Text(
                        'Waiting: ${DateTime.now().difference(joinedAt.toDate()).inMinutes} min',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: _buildQueueActions(doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQueueActions(String queueId, Map<String, dynamic> data) {
    final status = data['status'] as String;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) => _handleQueueAction(queueId, data, value),
      itemBuilder: (context) {
        List<PopupMenuEntry<String>> items = [];

        if (status == 'waiting') {
          items.addAll([
            const PopupMenuItem(
              value: 'call',
              child: Row(
                children: [
                  Icon(Icons.call, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Call Patient'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'priority',
              child: Row(
                children: [
                  Icon(Icons.priority_high, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Mark Urgent'),
                ],
              ),
            ),
          ]);
        }

        if (status == 'in-progress') {
          items.add(
            const PopupMenuItem(
              value: 'complete',
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Mark Complete'),
                ],
              ),
            ),
          );
        }

        items.add(
          const PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Remove from Queue'),
              ],
            ),
          ),
        );

        return items;
      },
    );
  }

  void _handleQueueAction(
    String queueId,
    Map<String, dynamic> data,
    String action,
  ) async {
    try {
      final queueRef = FirebaseFirestore.instance
          .collection('queue')
          .doc(queueId);

      switch (action) {
        case 'call':
          await queueRef.update({
            'status': 'in-progress',
            'calledAt': FieldValue.serverTimestamp(),
            'calledBy': widget.staffName,
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Called ${data['patientName']}'),
                backgroundColor: Colors.blue,
              ),
            );
          }
          break;

        case 'complete':
          await queueRef.update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
            'completedBy': widget.staffName,
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Completed ${data['patientName']}'),
                backgroundColor: Colors.green,
              ),
            );
          }
          break;

        case 'priority':
          await queueRef.update({'priority': 'urgent'});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Marked ${data['patientName']} as urgent'),
                backgroundColor: Colors.red,
              ),
            );
          }
          break;

        case 'remove':
          await queueRef.delete();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Removed ${data['patientName']} from queue'),
                backgroundColor: Colors.grey,
              ),
            );
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddToQueueDialog(String department) async {
    // Fetch patients from facility
    final patientsSnapshot = await FirebaseFirestore.instance
        .collection('facility_patients')
        .where('facilityId', isEqualTo: widget.facilityId)
        .orderBy('fullName')
        .get();

    if (!mounted) return;

    String? selectedPatientId;
    String? selectedPatientName;
    String priority = 'normal';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add to $department Queue'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Patient:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedPatientId,
                  hint: const Text('Choose patient'),
                  items: patientsSnapshot.docs.map((doc) {
                    final data = doc.data();
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(data['fullName'] ?? 'Unknown'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedPatientId = value;
                      final patientDoc = patientsSnapshot.docs.firstWhere(
                        (d) => d.id == value,
                      );
                      selectedPatientName = patientDoc.data()['fullName'];
                    });
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Priority:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: priority,
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      priority = value ?? 'normal';
                    });
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedPatientId == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _addToQueue(
                        department,
                        selectedPatientId!,
                        selectedPatientName!,
                        priority,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add to Queue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToQueue(
    String department,
    String patientId,
    String patientName,
    String priority,
  ) async {
    try {
      // Get next queue number for today
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final queueSnapshot = await FirebaseFirestore.instance
          .collection('queue')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('department', isEqualTo: department)
          .where('date', isEqualTo: today)
          .orderBy('queueNumber', descending: true)
          .limit(1)
          .get();

      int nextQueueNumber = 1;
      if (queueSnapshot.docs.isNotEmpty) {
        nextQueueNumber =
            (queueSnapshot.docs.first.data()['queueNumber'] as int) + 1;
      }

      // Add to queue
      await FirebaseFirestore.instance.collection('queue').add({
        'facilityId': widget.facilityId,
        'department': department,
        'patientId': patientId,
        'patientName': patientName,
        'queueNumber': nextQueueNumber,
        'status': 'waiting',
        'priority': priority,
        'date': today,
        'joinedAt': FieldValue.serverTimestamp(),
        'addedBy': widget.staffName,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$patientName added to $department queue (#$nextQueueNumber)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to queue: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
