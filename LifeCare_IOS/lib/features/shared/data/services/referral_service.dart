// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/referral.dart';
import 'message_service.dart';

class ReferralService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new referral
  static Future<String> createReferral({
    required String patientId,
    required String patientName,
    required String fromProviderId,
    required String fromProviderName,
    required String fromProviderType,
    required String toProviderId,
    required String toProviderName,
    required String toProviderType,
    required String reason,
    required String urgency,
    String? notes,
    String? facilityId,
    String? facilityName,
    Map<String, dynamic>? medicalHistory,
    List<String>? attachments,
  }) async {
    try {
      final referralData = {
        'patientId': patientId,
        'patientName': patientName,
        'fromProviderId': fromProviderId,
        'fromProviderName': fromProviderName,
        'fromProviderType': fromProviderType,
        'toProviderId': toProviderId,
        'toProviderName': toProviderName,
        'toProviderType': toProviderType,
        'reason': reason,
        'urgency': urgency,
        'status': 'pending',
        'notes': notes,
        'facilityId': facilityId,
        'facilityName': facilityName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'medicalHistory': medicalHistory,
        'attachments': attachments,
      };

      final docRef = await _firestore.collection('referrals').add(referralData);

      // Send in-app and SMS notifications to receiving provider
      try {
        // In-app notification
        if (fromProviderType.toLowerCase() == 'chw' &&
            toProviderType.toLowerCase() == 'doctor') {
          await MessageService.notifyDoctorOfChwReferral(
            referralId: docRef.id,
            chwId: fromProviderId,
            doctorId: toProviderId,
            patientName: patientName,
            reason: reason,
            urgency: urgency,
          );
        } else if (fromProviderType.toLowerCase() == 'doctor' &&
            toProviderType.toLowerCase() == 'doctor') {
          await MessageService.notifyDoctorOfReferral(
            referralId: docRef.id,
            referringDoctorId: fromProviderId,
            referredDoctorId: toProviderId,
            patientName: patientName,
            reason: reason,
            specialty: toProviderType,
          );
        }

        // SMS notification via Cloud Function
        try {
          final functions = FirebaseFunctions.instance;
          await functions.httpsCallable('sendReferralNotificationSMS').call({
            'recipientId': toProviderId,
            'recipientType': toProviderType.toLowerCase(),
            'patientId': patientId, // Also notify patient
            'patientName': patientName,
            'referrerName': fromProviderName,
            'toProviderName': toProviderName, // For patient SMS message
            'reason': reason,
            'urgency': urgency,
            'notifyPatient': true, // Enable patient notification
            'isApproved': false, // New referral, not yet approved
          });
          print('✅ SMS notification sent for referral: ${docRef.id}');
        } catch (smsError) {
          print('⚠️ SMS notification failed (continuing): $smsError');
        }
      } catch (notificationError) {
        // Don't fail the referral creation if notification fails
        print('⚠️ Notification error (continuing): $notificationError');
      }

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create referral: $e');
    }
  }

  /// Update referral status (approve, reject, complete)
  static Future<void> updateReferralStatus({
    required String referralId,
    required String status,
    required String actionBy,
    String? actionNotes,
  }) async {
    try {
      final updateData = {
        'status': status,
        'actionBy': actionBy,
        'actionDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (actionNotes != null) {
        updateData['actionNotes'] = actionNotes;
      }

      await _firestore
          .collection('referrals')
          .doc(referralId)
          .update(updateData);

      // Send booking link to patient if approved or accepted, and a short message to the referrer
      if (status.toLowerCase() == 'approved' ||
          status.toLowerCase() == 'accepted') {
        final referralDoc = await _firestore
            .collection('referrals')
            .doc(referralId)
            .get();
        if (referralDoc.exists) {
          final data = referralDoc.data() as Map<String, dynamic>;
          final patientId = data['patientId'] as String?;
          final patientName = data['patientName'] as String?;
          final toProviderId = data['toProviderId'] as String?;
          final toProviderName = data['toProviderName'] as String?;
          final toProviderType = data['toProviderType'] as String?;
          final fromProviderId = data['fromProviderId'] as String?;
          final fromProviderName = data['fromProviderName'] as String?;
          final fromProviderType = data['fromProviderType'] as String?;
          final reason = data['reason'] as String?;

          // Check if patient exists in users collection (has an account)
          bool hasUserAccount = false;

          if (patientId != null &&
              toProviderId != null &&
              toProviderName != null) {
            final userDoc = await _firestore
                .collection('users')
                .doc(patientId)
                .get();
            hasUserAccount = userDoc.exists;

            if (hasUserAccount) {
              // Patient has an account - send them a booking link
              final bookingLink =
                  '/book-appointment?doctorId=$toProviderId&type=specialist_referral';
              final messageContent =
                  'Your referral to Dr. $toProviderName has been approved.\n\n'
                  'You can book your specialist consultation using this link: $bookingLink\n\n'
                  'Alternatively, you may also book your appointment by going to the "My Referrals" tab and clicking the "Book Appointment" button.';
              // Get or create conversation between doctor and patient
              final conversationId =
                  await MessageService.createOrGetConversation(
                    user1Id: toProviderId,
                    user1Name: toProviderName,
                    user1Role: toProviderType ?? 'doctor',
                    user2Id: patientId,
                    user2Name: patientName ?? '',
                    user2Role: 'patient',
                  );
              await MessageService.sendMessage(
                conversationId: conversationId,
                senderId: toProviderId,
                senderName: toProviderName,
                senderRole: toProviderType ?? 'doctor',
                receiverId: patientId,
                receiverName: patientName ?? '',
                receiverRole: 'patient',
                content: messageContent,
                type: 'referral_notification',
                priority: 'high',
              );

              // Also send SMS notification to patient
              try {
                final functions = FirebaseFunctions.instance;
                await functions
                    .httpsCallable('sendReferralNotificationSMS')
                    .call({
                      'recipientId':
                          toProviderId, // Still notify doctor (optional)
                      'recipientType':
                          toProviderType?.toLowerCase() ?? 'doctor',
                      'patientId': patientId,
                      'patientName': patientName,
                      'referrerName': fromProviderName ?? 'Your doctor',
                      'toProviderName': toProviderName,
                      'reason': reason ?? 'Specialist consultation',
                      'notifyPatient': true,
                      'isApproved': true, // Approved referral
                    });
                print(
                  '✅ SMS approval notification sent to patient: $patientId',
                );
              } catch (smsError) {
                print('⚠️ SMS approval notification failed: $smsError');
              }
            } else {
              // Patient has NO account (CHW registered patient) - auto-create appointment
              print(
                '🏥 Auto-creating appointment for CHW registered patient: $patientName',
              );

              const referralFee = 3000.0;

              // Fetch patient details from chw_patients collection
              final patientDoc = await _firestore
                  .collection('chw_patients')
                  .doc(patientId)
                  .get();

              final patientData = patientDoc.data() ?? {};
              final age = patientData['age'];
              final sex = patientData['gender'] ?? patientData['sex'];
              final phone = patientData['phone'] ?? patientData['phoneNumber'];
              final address = patientData['address'];

              // First, check if patient has sufficient balance in chw_patient_wallets
              final walletDoc = await _firestore
                  .collection('chw_patient_wallets')
                  .doc(patientId)
                  .get();

              final currentBalance =
                  (walletDoc.exists
                          ? (walletDoc.data()?['balance'] ?? 0.0)
                          : 0.0)
                      as num;

              if (currentBalance < referralFee) {
                throw Exception(
                  'Insufficient wallet balance. Patient has ₦${currentBalance.toStringAsFixed(2)}, but referral consultation fee is ₦${referralFee.toStringAsFixed(2)}. Please fund the patient wallet first.',
                );
              }

              // Deduct referral fee from patient wallet
              final now = DateTime.now();
              await _firestore
                  .collection('chw_patient_wallets')
                  .doc(patientId)
                  .set({
                    'balance': FieldValue.increment(-referralFee),
                    'lastUpdated': FieldValue.serverTimestamp(),
                    'transactions': FieldValue.arrayUnion([
                      {
                        'type': 'debit',
                        'amount': referralFee,
                        'description':
                            'Referral consultation fee to Dr. $toProviderName',
                        'timestamp': Timestamp.fromDate(now),
                        'referralId': referralId,
                        'doctorId': toProviderId,
                        'doctorName': toProviderName,
                      },
                    ]),
                  }, SetOptions(merge: true));

              print('💰 Charged ₦$referralFee from patient wallet');

              final appointmentData = {
                'patientId': patientId,
                'patientName': patientName,
                'age': age,
                'sex': sex,
                'phone': phone,
                'address': address,
                'providerId': toProviderId,
                'providerName': toProviderName,
                'providerType': toProviderType,
                'doctorId': toProviderId, // For doctor-specific queries
                'appointmentDate': Timestamp.fromDate(
                  DateTime.now().add(const Duration(days: 1)),
                ), // Tomorrow
                'reason': reason ?? 'Referral consultation',
                'referralReason': reason, // Mark as referred
                'notes': 'Auto-created from CHW referral',
                'status':
                    'approved', // Auto-approve since doctor already approved referral
                'referralId': referralId,
                'referredBy': fromProviderId, // CHW who referred
                'referredByName': fromProviderName,
                'referredByType': fromProviderType,
                'consultationFee':
                    referralFee, // Store fee for payment split later
                'paymentStatus': 'paid', // Already paid from wallet
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              };

              await _firestore.collection('appointments').add(appointmentData);
              print('✅ Appointment auto-created for referral: $referralId');

              // Send SMS notification to CHW patient
              try {
                final functions = FirebaseFunctions.instance;
                await functions.httpsCallable('sendReferralNotificationSMS').call(
                  {
                    'recipientId':
                        toProviderId, // Still notify doctor (optional)
                    'recipientType': toProviderType?.toLowerCase() ?? 'doctor',
                    'patientId': patientId,
                    'patientName': patientName,
                    'referrerName': fromProviderName ?? 'Your CHW',
                    'toProviderName': toProviderName,
                    'reason': reason ?? 'Specialist consultation',
                    'notifyPatient': true,
                    'isApproved':
                        true, // Approved referral with auto-created appointment
                  },
                );
                print(
                  '✅ SMS approval notification sent to CHW patient: $patientId',
                );
              } catch (smsError) {
                print(
                  '⚠️ SMS approval notification failed for CHW patient: $smsError',
                );
              }
            }
          }

          // Send a short message to the referrer (CHW or doctor)
          if (fromProviderId != null &&
              fromProviderName != null &&
              fromProviderType != null &&
              toProviderName != null) {
            final referrerMessage = !hasUserAccount
                ? 'Your referral to Dr. $toProviderName has been accepted. An appointment has been automatically created.'
                : 'Your referral to Dr. $toProviderName has been accepted.';
            await MessageService.sendMessage(
              conversationId: fromProviderId,
              senderId: toProviderId ?? '',
              senderName: toProviderName,
              senderRole: toProviderType ?? 'doctor',
              receiverId: fromProviderId,
              receiverName: fromProviderName,
              receiverRole: fromProviderType,
              content: referrerMessage,
              type: 'referral_update',
              priority: 'normal',
            );
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to update referral status: $e');
    }
  }

  /// Get referrals for a specific CHW (sent by them)
  static Stream<QuerySnapshot> getCHWReferrals({
    required String chwId,
    String? status,
    List<String>? statusList,
  }) {
    Query query = _firestore
        .collection('referrals')
        .where('fromProviderId', isEqualTo: chwId);

    if (status != null) {
      if (status == 'approved') {
        // Show both 'approved' and 'accepted' statuses for the approved tab
        query = query.where('status', whereIn: ['approved', 'accepted']);
      } else {
        query = query.where('status', isEqualTo: status);
      }
    } else if (statusList != null && statusList.isNotEmpty) {
      // If statusList contains 'approved', include both 'approved' and 'accepted'
      final expandedStatusList = statusList.contains('approved')
          ? (statusList.toSet()..add('accepted')).toList()
          : statusList;
      query = query.where('status', whereIn: expandedStatusList);
    }

    return query.snapshots();
  }

  /// Get referrals for a specific doctor (received by them)
  static Stream<QuerySnapshot> getDoctorReferrals({
    required String doctorId,
    String? status,
    List<String>? statusList,
  }) {
    Query query = _firestore
        .collection('referrals')
        .where('toProviderId', isEqualTo: doctorId);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    } else if (statusList != null && statusList.isNotEmpty) {
      query = query.where('status', whereIn: statusList);
    }

    return query.snapshots();
  }

  /// Get referrals for a specific patient (view only)
  static Stream<QuerySnapshot> getPatientReferrals({
    required String patientId,
    String? status,
    List<String>? statusList,
  }) {
    Query query = _firestore
        .collection('referrals')
        .where('patientId', isEqualTo: patientId);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    } else if (statusList != null && statusList.isNotEmpty) {
      query = query.where('status', whereIn: statusList);
    }

    return query.snapshots();
  }

  /// Get referrals for a specific facility
  static Stream<QuerySnapshot> getFacilityReferrals({
    required String facilityId,
    String? status,
    List<String>? statusList,
  }) {
    Query query = _firestore
        .collection('referrals')
        .where('facilityId', isEqualTo: facilityId);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    } else if (statusList != null && statusList.isNotEmpty) {
      query = query.where('status', whereIn: statusList);
    }

    return query.snapshots();
  }

  /// Get all referrals (admin view)
  static Stream<QuerySnapshot> getAllReferrals({
    String? status,
    List<String>? statusList,
    String? urgency,
  }) {
    Query query = _firestore.collection('referrals');

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    } else if (statusList != null && statusList.isNotEmpty) {
      query = query.where('status', whereIn: statusList);
    }

    if (urgency != null) {
      query = query.where('urgency', isEqualTo: urgency);
    }

    return query.snapshots();
  }

  /// Get referral by ID
  static Future<Referral?> getReferralById(String referralId) async {
    try {
      final doc = await _firestore
          .collection('referrals')
          .doc(referralId)
          .get();

      if (doc.exists) {
        return Referral.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get referral: $e');
    }
  }

  /// Update referral notes
  static Future<void> updateReferralNotes({
    required String referralId,
    required String notes,
  }) async {
    try {
      await _firestore.collection('referrals').doc(referralId).update({
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update referral notes: $e');
    }
  }

  /// Search referrals by patient name
  static Stream<QuerySnapshot> searchReferralsByPatient({
    required String searchTerm,
    String? fromProviderId,
    String? toProviderId,
  }) {
    Query query = _firestore
        .collection('referrals')
        .where('patientName', isGreaterThanOrEqualTo: searchTerm)
        .where('patientName', isLessThanOrEqualTo: '$searchTerm\uf8ff')
        .orderBy('patientName')
        .orderBy('createdAt', descending: true);

    if (fromProviderId != null) {
      query = query.where('fromProviderId', isEqualTo: fromProviderId);
    }

    if (toProviderId != null) {
      query = query.where('toProviderId', isEqualTo: toProviderId);
    }

    return query.snapshots();
  }

  /// Get referral statistics for a provider
  static Future<Map<String, int>> getReferralStats({
    required String providerId,
    required String providerType,
  }) async {
    try {
      final Query query;
      if (providerType == 'CHW') {
        query = _firestore
            .collection('referrals')
            .where('fromProviderId', isEqualTo: providerId);
      } else {
        query = _firestore
            .collection('referrals')
            .where('toProviderId', isEqualTo: providerId);
      }

      final snapshot = await query.get();
      final referrals = snapshot.docs;

      int pending = 0;
      int approved = 0;
      int rejected = 0;
      int completed = 0;

      for (final doc in referrals) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] as String;

        switch (status) {
          case 'pending':
            pending++;
            break;
          case 'approved':
            approved++;
            break;
          case 'rejected':
            rejected++;
            break;
          case 'completed':
            completed++;
            break;
        }
      }

      return {
        'total': referrals.length,
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
        'completed': completed,
      };
    } catch (e) {
      throw Exception('Failed to get referral statistics: $e');
    }
  }
}
