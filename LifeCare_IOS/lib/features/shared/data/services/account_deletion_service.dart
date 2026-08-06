import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for handling account deletion requests requiring admin approval
class AccountDeletionService {
  static final _firestore = FirebaseFirestore.instance;

  /// Submit an account deletion request (for CHW, Doctor, Facility)
  /// Returns the request ID on success
  static Future<String> submitDeletionRequest({
    required String userId,
    required String userRole,
    required String userName,
    required String userEmail,
    String? reason,
  }) async {
    try {
      // Check if there's already a pending request
      final existingRequest = await _firestore
          .collection('account_deletion_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('You already have a pending deletion request');
      }

      // Create the deletion request
      final requestRef = await _firestore
          .collection('account_deletion_requests')
          .add({
            'userId': userId,
            'userRole': userRole,
            'userName': userName,
            'userEmail': userEmail,
            'reason': reason ?? '',
            'status': 'pending', // pending, approved, rejected
            'requestedAt': FieldValue.serverTimestamp(),
            'requestedBy': userId,
            'approvedAt': null,
            'approvedBy': null,
            'rejectionReason': null,
            'processedAt': null,
          });

      // Notify admins about the new deletion request
      await _notifyAdmins(
        userId: userId,
        userName: userName,
        userRole: userRole,
        requestId: requestRef.id,
      );

      return requestRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user has a pending deletion request
  static Future<Map<String, dynamic>?> getPendingRequest(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('account_deletion_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return {'id': doc.id, ...doc.data()};
    } catch (e) {
      return null;
    }
  }

  /// Cancel a pending deletion request
  static Future<void> cancelDeletionRequest(String requestId) async {
    try {
      await _firestore
          .collection('account_deletion_requests')
          .doc(requestId)
          .update({
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      rethrow;
    }
  }

  /// Get all pending deletion requests (Admin only)
  static Stream<QuerySnapshot<Map<String, dynamic>>> getPendingRequests() {
    return _firestore
        .collection('account_deletion_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots();
  }

  /// Get deletion request history (Admin only)
  static Stream<QuerySnapshot<Map<String, dynamic>>> getProcessedRequests() {
    return _firestore
        .collection('account_deletion_requests')
        .where('status', whereIn: ['approved', 'rejected', 'cancelled'])
        .orderBy('processedAt', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Approve a deletion request (Admin only)
  static Future<void> approveDeletionRequest({
    required String requestId,
    required String adminId,
    required String adminName,
  }) async {
    try {
      final requestDoc = await _firestore
          .collection('account_deletion_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Deletion request not found');
      }

      final requestData = requestDoc.data()!;
      final userId = requestData['userId'] as String;
      final userEmail = requestData['userEmail'] as String;
      final userName = requestData['userName'] as String;

      // Update request status
      await _firestore
          .collection('account_deletion_requests')
          .doc(requestId)
          .update({
            'status': 'approved',
            'approvedAt': FieldValue.serverTimestamp(),
            'approvedBy': adminId,
            'approvedByName': adminName,
            'processedAt': FieldValue.serverTimestamp(),
          });

      // Notify user about approval
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Account Deletion Approved',
        'message':
            'Your account deletion request has been approved by an admin. Your account will be deleted within 24 hours.',
        'type': 'account_deletion',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create audit log
      await _firestore.collection('account_deletion_audit').add({
        'requestId': requestId,
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'action': 'approved',
        'actionBy': adminId,
        'actionByName': adminName,
        'actionAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Reject a deletion request (Admin only)
  static Future<void> rejectDeletionRequest({
    required String requestId,
    required String adminId,
    required String adminName,
    required String rejectionReason,
  }) async {
    try {
      final requestDoc = await _firestore
          .collection('account_deletion_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Deletion request not found');
      }

      final requestData = requestDoc.data()!;
      final userId = requestData['userId'] as String;

      // Update request status
      await _firestore
          .collection('account_deletion_requests')
          .doc(requestId)
          .update({
            'status': 'rejected',
            'rejectionReason': rejectionReason,
            'rejectedBy': adminId,
            'rejectedByName': adminName,
            'processedAt': FieldValue.serverTimestamp(),
          });

      // Notify user about rejection
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Account Deletion Request Rejected',
        'message':
            'Your account deletion request has been rejected. Reason: $rejectionReason',
        'type': 'account_deletion',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create audit log
      await _firestore.collection('account_deletion_audit').add({
        'requestId': requestId,
        'userId': userId,
        'action': 'rejected',
        'actionBy': adminId,
        'actionByName': adminName,
        'rejectionReason': rejectionReason,
        'actionAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Notify all admins about new deletion request
  static Future<void> _notifyAdmins({
    required String userId,
    required String userName,
    required String userRole,
    required String requestId,
  }) async {
    try {
      // Get all admin users
      final adminsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      // Create notification for each admin
      final batch = _firestore.batch();
      for (final adminDoc in adminsSnapshot.docs) {
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': adminDoc.id,
          'title': 'New Account Deletion Request',
          'message': '$userName ($userRole) has requested account deletion',
          'type': 'account_deletion_request',
          'requestId': requestId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      // Don't fail the request if notification fails
      print('Failed to notify admins: $e');
    }
  }
}
