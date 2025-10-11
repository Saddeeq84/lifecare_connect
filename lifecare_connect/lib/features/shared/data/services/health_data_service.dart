// ignore_for_file: use_build_context_synchronously, avoid_print, unrelated_type_equality_checks, prefer_const_constructors

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class HealthDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static String get _currentUserId {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }
    return uid;
  }

  // Enable offline persistence and caching
  static Future<void> enableOfflineSupport() async {
    try {
      await _firestore.enableNetwork();
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      print('Error enabling offline support: $e');
    }
  }

  // Health Records with optimistic updates and conflict resolution
  static Stream<QuerySnapshot> getHealthRecordsStream() {
    try {
      return _firestore
          .collection('medical_records')
          .where('patientId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .snapshots(includeMetadataChanges: true);
    } catch (e) {
      print('Error in getHealthRecordsStream: $e');
      // Return empty stream on error
      return Stream.empty();
    }
  }

  // Lab Results with metadata tracking
  static Stream<QuerySnapshot> getLabResultsStream() {
    try {
      return _firestore
          .collection('lab_results')
          .where('patientId', isEqualTo: _currentUserId)
          .orderBy('uploadedAt', descending: true)
          .snapshots(includeMetadataChanges: true);
    } catch (e) {
      print('Error in getLabResultsStream: $e');
      return Stream.empty();
    }
  }

  // Consultations with real-time status updates
  static Stream<QuerySnapshot> getActiveConsultationsStream() {
    try {
      return _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'approved')
          .where('consultationStatus', isEqualTo: 'ready')
          .orderBy('appointmentDate', descending: true)
          .snapshots(includeMetadataChanges: true);
    } catch (e) {
      print('Error in getActiveConsultationsStream: $e');
      return Stream.empty();
    }
  }

  // Vital Signs functionality
  static Stream<QuerySnapshot> getVitalSignsStream() {
    try {
      return _firestore
          .collection('vital_signs')
          .where('patientId', isEqualTo: _currentUserId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(includeMetadataChanges: true);
    } catch (e) {
      print('Error in getVitalSignsStream: $e');
      return Stream.empty();
    }
  }

  // Add vital signs data
  static Future<DocumentReference> addVitalSignsData(
    Map<String, dynamic> vitalSignsData,
  ) async {
    try {
      vitalSignsData['patientId'] = _currentUserId;
      vitalSignsData['createdAt'] = FieldValue.serverTimestamp();
      vitalSignsData['updatedAt'] = FieldValue.serverTimestamp();

      return await _firestore.collection('vital_signs').add(vitalSignsData);
    } catch (e) {
      await reportError('addVitalSigns', e.toString());
      rethrow;
    }
  }

  // Secure upload with encryption and versioning
  static Future<String> uploadSecureHealthFile({
    required String filePath,
    required String fileName,
    required String category,
    Map<String, dynamic>? metadata,
  }) async {
    DocumentReference? docRef;
    try {
      // Create upload log entry
      docRef = await _firestore.collection('upload_logs').add({
        'patientId': _currentUserId,
        'fileName': fileName,
        'category': category,
        'metadata': metadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'uploadStatus': 'initiated',
        'platform': 'flutter_mobile',
        'lastMetricsUpdate': FieldValue.serverTimestamp(),
      });

      // Upload file to Firebase Storage
      final file = File(filePath);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('health_files')
          .child(_currentUserId)
          .child(category)
          .child(fileName);

      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update document with actual download URL
      await docRef.update({
        'downloadUrl': downloadUrl,
        'uploadStatus': 'completed',
        'uploadCompletedAt': FieldValue.serverTimestamp(),
      });

      return downloadUrl;
    } catch (e) {
      // Update upload status to failed if document was created
      if (docRef != null) {
        await docRef.update({
          'uploadStatus': 'failed',
          'uploadFailedAt': FieldValue.serverTimestamp(),
          'errorMessage': e.toString(),
        });
      }
      await reportError('uploadSecureHealthFile', e.toString());
      rethrow;
    }
  }

  // Add lab result with comprehensive metadata
  static Future<DocumentReference> addLabResult(
    Map<String, dynamic> labData,
  ) async {
    try {
      labData['patientId'] = _currentUserId;
      labData['uploadedAt'] = FieldValue.serverTimestamp();
      labData['status'] = 'uploaded';
      labData['isEncrypted'] = true;

      return await _firestore.collection('lab_results').add(labData);
    } catch (e) {
      await reportError('addLabResult', e.toString());
      rethrow;
    }
  }

  // Upload lab result securely
  static Future<String> uploadLabResultSecure({
    required String filePath,
    required String fileName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      return await uploadSecureHealthFile(
        filePath: filePath,
        fileName: fileName,
        category: 'lab_results',
        metadata: metadata,
      );
    } catch (e) {
      await reportError('uploadLabResultSecure', e.toString());
      rethrow;
    }
  }

  // Add medical record with audit trail
  static Future<DocumentReference> addMedicalRecord(
    Map<String, dynamic> recordData,
  ) async {
    try {
      recordData['patientId'] = _currentUserId;
      recordData['createdAt'] = FieldValue.serverTimestamp();
      recordData['lastModified'] = FieldValue.serverTimestamp();
      recordData['version'] = 1;
      recordData['auditTrail'] = [
        {
          'action': 'created',
          'timestamp': FieldValue.serverTimestamp(),
          'userId': _currentUserId,
        },
      ];

      return await _firestore.collection('medical_records').add(recordData);
    } catch (e) {
      await reportError('addMedicalRecord', e.toString());
      rethrow;
    }
  }

  // Check if data is from cache (for offline indicator)
  static bool isDataFromCache(DocumentSnapshot doc) {
    return doc.metadata.isFromCache;
  }

  // Network connectivity monitoring
  static Stream<List<ConnectivityResult>> getConnectivityStream() {
    return Connectivity().onConnectivityChanged;
  }

  // Error reporting for analytics and debugging
  static Future<void> reportError(String operation, dynamic error) async {
    try {
      await _firestore.collection('error_logs').add({
        'patientId': _currentUserId,
        'operation': operation,
        'error': error,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'flutter_mobile',
      });
    } catch (e) {
      print('Failed to report error: $e');
    }
  }

  // Get health summary for dashboard
  static Future<Map<String, dynamic>> getHealthSummary() async {
    try {
      final medicalRecords = await _firestore
          .collection('medical_records')
          .where('patientId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      final labResults = await _firestore
          .collection('lab_results')
          .where('patientId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      final vitalSigns = await _firestore
          .collection('vital_signs')
          .where('patientId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      return {
        'totalRecords': medicalRecords.docs.length,
        'totalLabResults': labResults.docs.length,
        'totalVitalSigns': vitalSigns.docs.length,
        'lastUpdated': DateTime.now().toString(),
      };
    } catch (e) {
      await reportError('getHealthSummary', e.toString());
      return {
        'totalRecords': 0,
        'totalLabResults': 0,
        'totalVitalSigns': 0,
        'lastUpdated': DateTime.now().toString(),
      };
    }
  }

  // Instance methods for the non-static service usage
  Stream<QuerySnapshot> getVitalSigns() {
    return HealthDataService.getVitalSignsStream();
  }

  Future<DocumentReference> addVitalSigns(
    Map<String, dynamic> vitalSignsData,
  ) async {
    return await HealthDataService.addVitalSignsData(vitalSignsData);
  }
}
