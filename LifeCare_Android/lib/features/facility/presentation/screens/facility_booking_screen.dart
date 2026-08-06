// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lifecare_connect/features/shared/data/services/message_service.dart';

class FacilityBookingScreen extends StatefulWidget {
  const FacilityBookingScreen({super.key});

  @override
  State<FacilityBookingScreen> createState() => _FacilityBookingScreenState();
}

class _FacilityBookingScreenState extends State<FacilityBookingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('Facility Bookings'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Approved', icon: Icon(Icons.check_circle)),
            Tab(text: 'Completed', icon: Icon(Icons.done_all)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PendingBookingsTab(facilityId: currentUserId),
          _ApprovedBookingsTab(facilityId: currentUserId),
          _CompletedBookingsTab(facilityId: currentUserId),
        ],
      ),
    );
  }
}

// Pending Bookings Tab
class _PendingBookingsTab extends StatelessWidget {
  final String facilityId;

  const _PendingBookingsTab({required this.facilityId});

  Stream<QuerySnapshot> _buildPendingQuery(String facilityId) {
    try {
      // Try the optimized query with ordering
      return FirebaseFirestore.instance
          .collection('service_requests')
          .where('facilityId', isEqualTo: facilityId)
          .where('status', isEqualTo: 'pending')
          .orderBy('requestDate', descending: true)
          .snapshots();
    } catch (e) {
      // Fallback to simple query without ordering
      return FirebaseFirestore.instance
          .collection('service_requests')
          .where('facilityId', isEqualTo: facilityId)
          .where('status', isEqualTo: 'pending')
          .snapshots();
    }
  }

  Widget _buildFallbackView(
    BuildContext context,
    String facilityId,
    String status,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('service_requests')
          .where('facilityId', isEqualTo: facilityId)
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                const Text(
                  'Firestore indexes are building. This may take a few minutes.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final bookings = snapshot.data?.docs ?? [];

        // Sort manually if needed (since we can't use orderBy yet)
        bookings.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate = aData['requestDate'] as Timestamp?;
          final bDate = bData['requestDate'] as Timestamp?;
          if (aDate == null || bDate == null) return 0;
          return bDate.compareTo(aDate); // Descending order
        });

        if (bookings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending bookings',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            final data = booking.data() as Map<String, dynamic>;

            return _BookingCard(
              booking: data,
              bookingId: booking.id,
              onApprove: () => _approveBooking(context, booking.id, data),
              onReject: () => _rejectBooking(context, booking.id, data),
              showActions: true,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildPendingQuery(facilityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          // If the ordered query fails (index not ready), show a fallback
          return _buildFallbackView(context, facilityId, 'pending');
        }

        final bookings = snapshot.data?.docs ?? [];

        if (bookings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending bookings',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            final data = booking.data() as Map<String, dynamic>;

            return _BookingCard(
              booking: data,
              bookingId: booking.id,
              onApprove: () => _approveBooking(context, booking.id, data),
              onReject: () => _rejectBooking(context, booking.id, data),
              showActions: true,
            );
          },
        );
      },
    );
  }

  Future<void> _approveBooking(
    BuildContext context,
    String bookingId,
    Map<String, dynamic> data,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Booking'),
        content: const Text('Are you sure you want to approve this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(bookingId)
          .update({
            'status': 'approved',
            'approvedAt': FieldValue.serverTimestamp(),
            'approvedBy': FirebaseAuth.instance.currentUser?.uid,
          });

      // Send automatic message to patient's normal messaging system
      try {
        final patientId = data['patientId'] ?? '';
        final patientName = data['patientName'] ?? 'Patient';
        final facilityId = FirebaseAuth.instance.currentUser?.uid ?? '';
        final facilityName = data['facilityName'] ?? 'Facility';
        if (patientId.isNotEmpty) {
          final conversationId = await MessageService.createOrGetConversation(
            user1Id: facilityId,
            user1Name: facilityName,
            user1Role: 'facility',
            user2Id: patientId,
            user2Name: patientName,
            user2Role: 'patient',
            title: 'Facility Booking',
            type: 'facility_booking',
            relatedId: bookingId,
          );
          await MessageService.sendMessage(
            conversationId: conversationId,
            senderId: facilityId,
            senderName: facilityName,
            senderRole: 'facility',
            receiverId: patientId,
            receiverName: patientName,
            receiverRole: 'patient',
            content:
                '✅ Great news! Your service request has been approved by $facilityName. One of our staff members will reach out to you shortly with more details about your appointment. You can also reply to this message if you have any questions.',
            type: 'facility_booking_approved',
            priority: 'high',
          );
        }
      } catch (e) {
        debugPrint(
          'Error sending booking approval message: '
          'Error: '
          'Error sending booking approval message: $e',
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Booking approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error approving booking: $e')));
      }
    }
  }

  Future<void> _rejectBooking(
    BuildContext context,
    String bookingId,
    Map<String, dynamic> data,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(bookingId)
          .update({
            'status': 'rejected',
            'rejectedAt': FieldValue.serverTimestamp(),
            'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
          });

      // Send automatic message to patient's normal messaging system
      try {
        final patientId = data['patientId'] ?? '';
        final patientName = data['patientName'] ?? 'Patient';
        final facilityId = FirebaseAuth.instance.currentUser?.uid ?? '';
        final facilityName = data['facilityName'] ?? 'Facility';
        if (patientId.isNotEmpty) {
          final conversationId = await MessageService.createOrGetConversation(
            user1Id: facilityId,
            user1Name: facilityName,
            user1Role: 'facility',
            user2Id: patientId,
            user2Name: patientName,
            user2Role: 'patient',
            title: 'Facility Booking',
            type: 'facility_booking',
            relatedId: bookingId,
          );
          await MessageService.sendMessage(
            conversationId: conversationId,
            senderId: facilityId,
            senderName: facilityName,
            senderRole: 'facility',
            receiverId: patientId,
            receiverName: patientName,
            receiverRole: 'patient',
            content:
                'Your service request has been declined. Please contact the facility for more information.',
            type: 'facility_booking_rejected',
            priority: 'high',
          );
        }
      } catch (e) {
        debugPrint('Error sending rejection message: $e');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Booking rejected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error rejecting booking: $e')));
      }
    }
  }
}

// Approved Bookings Tab
class _ApprovedBookingsTab extends StatelessWidget {
  final String facilityId;

  const _ApprovedBookingsTab({required this.facilityId});

  Stream<QuerySnapshot> _buildApprovedQuery(String facilityId) {
    try {
      // Try the optimized query with ordering
      return FirebaseFirestore.instance
          .collection('service_requests')
          .where('facilityId', isEqualTo: facilityId)
          .where('status', isEqualTo: 'approved')
          .orderBy('approvedAt', descending: true)
          .snapshots();
    } catch (e) {
      // Fallback to simple query without ordering
      return FirebaseFirestore.instance
          .collection('service_requests')
          .where('facilityId', isEqualTo: facilityId)
          .where('status', isEqualTo: 'approved')
          .snapshots();
    }
  }

  Widget _buildFallbackView(
    BuildContext context,
    String facilityId,
    String status,
    String orderField,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('service_requests')
          .where('facilityId', isEqualTo: facilityId)
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                const Text(
                  'Firestore indexes are building. This may take a few minutes.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final bookings = snapshot.data?.docs ?? [];

        // Sort manually if needed (since we can't use orderBy yet)
        bookings.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate = aData[orderField] as Timestamp?;
          final bDate = bData[orderField] as Timestamp?;
          if (aDate == null || bDate == null) return 0;
          return bDate.compareTo(aDate); // Descending order
        });

        if (bookings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No approved bookings',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            final data = booking.data() as Map<String, dynamic>;

            return _BookingCard(
              booking: data,
              bookingId: booking.id,
              onComplete: () => _completeBooking(context, booking.id),
              showCompleteAction: true,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildApprovedQuery(facilityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          // If the ordered query fails (index not ready), show a fallback
          return _buildFallbackView(
            context,
            facilityId,
            'approved',
            'approvedAt',
          );
        }

        final bookings = snapshot.data?.docs ?? [];

        if (bookings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No approved bookings',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            final data = booking.data() as Map<String, dynamic>;

            return _BookingCard(
              booking: data,
              bookingId: booking.id,
              onComplete: () => _completeBooking(context, booking.id),
              showCompleteAction: true,
            );
          },
        );
      },
    );
  }

  Future<void> _completeBooking(BuildContext context, String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Service'),
        content: const Text('Mark this booking as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(bookingId)
          .update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
            'completedBy': FirebaseAuth.instance.currentUser?.uid,
          });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Service completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error completing service: $e')));
      }
    }
  }
}

// Completed Bookings Tab
class _CompletedBookingsTab extends StatelessWidget {
  final String facilityId;

  const _CompletedBookingsTab({required this.facilityId});

  Stream<QuerySnapshot> _buildCompletedQuery(String facilityId) {
    try {
      // Try the optimized query with ordering
      return FirebaseFirestore.instance
          .collection('service_requests')
          .where('facilityId', isEqualTo: facilityId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .snapshots();
    } catch (e) {
      // Fallback to simple query without ordering
      return FirebaseFirestore.instance
          .collection('service_requests')
          .where('facilityId', isEqualTo: facilityId)
          .where('status', isEqualTo: 'completed')
          .snapshots();
    }
  }

  Widget _buildFallbackView(
    BuildContext context,
    String facilityId,
    String status,
    String orderField,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('service_requests')
          .where('facilityId', isEqualTo: facilityId)
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                const Text(
                  'Firestore indexes are building. This may take a few minutes.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final bookings = snapshot.data?.docs ?? [];

        // Sort manually if needed (since we can't use orderBy yet)
        bookings.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate = aData[orderField] as Timestamp?;
          final bDate = bData[orderField] as Timestamp?;
          if (aDate == null || bDate == null) return 0;
          return bDate.compareTo(aDate); // Descending order
        });

        if (bookings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.done_all, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No completed bookings',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            final data = booking.data() as Map<String, dynamic>;

            return _BookingCard(
              booking: data,
              bookingId: booking.id,
              showActions: false,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildCompletedQuery(facilityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          // If the ordered query fails (index not ready), show a fallback
          return _buildFallbackView(
            context,
            facilityId,
            'completed',
            'completedAt',
          );
        }

        final bookings = snapshot.data?.docs ?? [];

        if (bookings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.done_all, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No completed bookings',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            final data = booking.data() as Map<String, dynamic>;

            return _BookingCard(
              booking: data,
              bookingId: booking.id,
              showActions: false,
            );
          },
        );
      },
    );
  }
}

// Reusable Booking Card Widget
class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String bookingId;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onComplete;
  final bool showActions;
  final bool showCompleteAction;

  const _BookingCard({
    required this.booking,
    required this.bookingId,
    this.onApprove,
    this.onReject,
    this.onComplete,
    this.showActions = false,
    this.showCompleteAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final requestDate = booking['requestDate'] as Timestamp?;
    final preferredDate = booking['preferredDate'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with patient name and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking['patientName'] ?? 'Unknown Patient',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusChip(status: booking['status'] ?? 'pending'),
              ],
            ),

            const SizedBox(height: 12),

            // Service details
            _InfoRow(
              icon: Icons.medical_services,
              label: 'Service',
              value: booking['serviceType'] ?? 'Not specified',
            ),

            if (booking['description']?.toString().isNotEmpty == true)
              _InfoRow(
                icon: Icons.description,
                label: 'Description',
                value: booking['description'],
              ),

            if (preferredDate != null)
              _InfoRow(
                icon: Icons.calendar_today,
                label: 'Preferred Date',
                value: _formatDate(preferredDate),
              ),

            _InfoRow(
              icon: Icons.access_time,
              label: 'Requested',
              value: requestDate != null ? _formatDate(requestDate) : 'Unknown',
            ),

            if (booking['patientPhone']?.toString().isNotEmpty == true)
              _InfoRow(
                icon: Icons.phone,
                label: 'Contact',
                value: booking['patientPhone'],
              ),

            // Action buttons
            if (showActions) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (showCompleteAction) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.done),
                  label: const Text('Mark as Completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Info Row Widget
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.teal),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// Status Chip Widget
class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        icon = Icons.pending_actions;
        break;
      case 'approved':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        icon = Icons.check_circle;
        break;
      case 'completed':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        icon = Icons.done_all;
        break;
      case 'rejected':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        icon = Icons.cancel;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- End of Facility Booking Screen --------------------
// This code provides a booking screen for facilities, allowing users to select services and submit requests.
