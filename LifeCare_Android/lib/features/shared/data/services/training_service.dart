// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/training_material.dart';

class TrainingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Safe conversion of dynamic values to double
  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Create a new training material
  static Future<String> createTrainingMaterial({
    required String title,
    required String description,
    String? content,
    String? fileUrl,
    String? thumbnailUrl,
    required String type,
    required String category,
    required List<String> targetRoles,
    required String difficulty,
    required int estimatedDurationMinutes,
    required List<String> tags,
    required String language,
    Map<String, dynamic>? metadata,
    required String createdBy,
    bool isRequired = false,
    DateTime? expirationDate,
    List<String>? prerequisites,
  }) async {
    try {
      final trainingData = {
        'title': title,
        'description': description,
        'content': content,
        'fileUrl': fileUrl,
        'thumbnailUrl': thumbnailUrl,
        'type': type,
        'category': category,
        'targetRoles': targetRoles,
        'difficulty': difficulty,
        'estimatedDurationMinutes': estimatedDurationMinutes,
        'tags': tags,
        'status': 'draft', // Start as draft
        'version': 1,
        'language': language,
        'metadata': metadata,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
        'downloadCount': 0,
        'viewCount': 0,
        'ratingCount': 0,
        'isRequired': isRequired,
        'expirationDate': expirationDate != null
            ? Timestamp.fromDate(expirationDate)
            : null,
        'prerequisites': prerequisites,
      };

      final docRef = await _firestore
          .collection('training_materials')
          .add(trainingData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create training material: $e');
    }
  }

  /// Upload file to Firebase Storage and get URL
  static Future<String> uploadFile({
    required File file,
    required String fileName,
    required String type,
  }) async {
    try {
      final storageRef = _storage.ref().child(
        'training_materials/$type/$fileName',
      );
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  /// Update training material
  static Future<void> updateTrainingMaterial({
    required String materialId,
    String? title,
    String? description,
    String? content,
    String? fileUrl,
    String? thumbnailUrl,
    String? type,
    String? category,
    List<String>? targetRoles,
    String? difficulty,
    int? estimatedDurationMinutes,
    List<String>? tags,
    String? status,
    String? language,
    Map<String, dynamic>? metadata,
    String? updatedBy,
    bool? isRequired,
    DateTime? expirationDate,
    List<String>? prerequisites,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': ?updatedBy,
      };

      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (content != null) updateData['content'] = content;
      if (fileUrl != null) updateData['fileUrl'] = fileUrl;
      if (thumbnailUrl != null) updateData['thumbnailUrl'] = thumbnailUrl;
      if (type != null) updateData['type'] = type;
      if (category != null) updateData['category'] = category;
      if (targetRoles != null) updateData['targetRoles'] = targetRoles;
      if (difficulty != null) updateData['difficulty'] = difficulty;
      if (estimatedDurationMinutes != null) {
        updateData['estimatedDurationMinutes'] = estimatedDurationMinutes;
      }
      if (tags != null) updateData['tags'] = tags;
      if (status != null) updateData['status'] = status;
      if (language != null) updateData['language'] = language;
      if (metadata != null) updateData['metadata'] = metadata;
      if (isRequired != null) updateData['isRequired'] = isRequired;
      if (expirationDate != null) {
        updateData['expirationDate'] = Timestamp.fromDate(expirationDate);
      }
      if (prerequisites != null) updateData['prerequisites'] = prerequisites;

      await _firestore
          .collection('training_materials')
          .doc(materialId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update training material: $e');
    }
  }

  /// Publish training material
  static Future<void> publishTrainingMaterial({
    required String materialId,
    required String publishedBy,
  }) async {
    await updateTrainingMaterial(
      materialId: materialId,
      status: 'published',
      updatedBy: publishedBy,
    );
  }

  /// Archive training material
  static Future<void> archiveTrainingMaterial({
    required String materialId,
    required String archivedBy,
  }) async {
    await updateTrainingMaterial(
      materialId: materialId,
      status: 'archived',
      updatedBy: archivedBy,
    );
  }

  /// Delete training material
  static Future<void> deleteTrainingMaterial(String materialId) async {
    try {
      await _firestore
          .collection('training_materials')
          .doc(materialId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete training material: $e');
    }
  }

  /// Get training materials for admin
  static Stream<QuerySnapshot> getTrainingMaterials({
    String? status,
    String? category,
    String? type,
    String? targetRole,
    String? language,
  }) {
    Query query = _firestore
        .collection('training_materials')
        .orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    if (targetRole != null) {
      query = query.where('targetRoles', arrayContains: targetRole);
    }
    if (language != null) {
      query = query.where('language', isEqualTo: language);
    }

    return query.snapshots();
  }

  /// Get published training materials for users
  static Stream<QuerySnapshot> getPublishedTrainingMaterials({
    required String userRole,
    String? category,
    String? type,
    String? difficulty,
    String? language = 'en',
  }) {
    Query query = _firestore
        .collection('training_materials')
        .where('status', isEqualTo: 'published')
        .where('targetRoles', arrayContains: userRole.toLowerCase())
        .orderBy('createdAt', descending: true);

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    if (difficulty != null) {
      query = query.where('difficulty', isEqualTo: difficulty);
    }
    if (language != null) {
      query = query.where('language', isEqualTo: language);
    }

    return query.snapshots();
  }

  /// Get required training materials for a role
  static Stream<QuerySnapshot> getRequiredTrainingMaterials({
    required String userRole,
    String? language = 'en',
  }) {
    return _firestore
        .collection('training_materials')
        .where('status', isEqualTo: 'published')
        .where('targetRoles', arrayContains: userRole.toLowerCase())
        .where('isRequired', isEqualTo: true)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Search training materials
  static Future<List<TrainingMaterial>> searchTrainingMaterials({
    required String searchTerm,
    String? userRole,
    String? category,
    String? type,
    String? language = 'en',
  }) async {
    try {
      Query query = _firestore
          .collection('training_materials')
          .where('status', isEqualTo: 'published');

      if (userRole != null) {
        query = query.where(
          'targetRoles',
          arrayContains: userRole.toLowerCase(),
        );
      }
      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }
      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }
      if (language != null) {
        query = query.where('language', isEqualTo: language);
      }

      final snapshot = await query.get();

      final materials = snapshot.docs
          .map((doc) => TrainingMaterial.fromFirestore(doc))
          .where(
            (material) =>
                material.title.toLowerCase().contains(
                  searchTerm.toLowerCase(),
                ) ||
                material.description.toLowerCase().contains(
                  searchTerm.toLowerCase(),
                ) ||
                material.tags.any(
                  (tag) => tag.toLowerCase().contains(searchTerm.toLowerCase()),
                ),
          )
          .toList();

      return materials;
    } catch (e) {
      throw Exception('Failed to search training materials: $e');
    }
  }

  /// Increment view count
  static Future<void> incrementViewCount(
    String materialId, {
    String? userId,
  }) async {
    try {
      await _firestore.collection('training_materials').doc(materialId).update({
        'viewCount': FieldValue.increment(1),
      });

      // Log user activity for analytics
      if (userId != null) {
        await _firestore.collection('user_activities').add({
          'userId': userId,
          'action': 'view',
          'category': 'training_material',
          'materialId': materialId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Failed to increment view count: $e');
    }
  }

  /// Increment download count
  static Future<void> incrementDownloadCount(
    String materialId, {
    String? userId,
  }) async {
    try {
      await _firestore.collection('training_materials').doc(materialId).update({
        'downloadCount': FieldValue.increment(1),
      });

      // Log user activity for analytics
      if (userId != null) {
        await _firestore.collection('user_activities').add({
          'userId': userId,
          'action': 'download',
          'category': 'training_material',
          'materialId': materialId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Failed to increment download count: $e');
    }
  }

  /// Record user progress
  static Future<void> recordUserProgress({
    required String userId,
    required String materialId,
    required String status,
    required double progressPercentage,
    DateTime? startedAt,
    DateTime? completedAt,
    int? timeSpentMinutes,
    Map<String, dynamic>? data,
  }) async {
    try {
      final progressId = '${userId}_$materialId';
      final progressData = {
        'userId': userId,
        'materialId': materialId,
        'status': status,
        'progressPercentage': progressPercentage,
        'lastAccessedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (startedAt != null) {
        progressData['startedAt'] = Timestamp.fromDate(startedAt);
      }
      if (completedAt != null) {
        progressData['completedAt'] = Timestamp.fromDate(completedAt);
      }
      if (timeSpentMinutes != null) {
        progressData['timeSpentMinutes'] = timeSpentMinutes;
      }
      if (data != null) progressData['data'] = data;

      await _firestore
          .collection('user_progress')
          .doc(progressId)
          .set(progressData, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to record user progress: $e');
    }
  }

  /// Get user progress for materials
  static Stream<QuerySnapshot> getUserProgress({required String userId}) {
    return _firestore
        .collection('user_progress')
        .where('userId', isEqualTo: userId)
        .orderBy('lastAccessedAt', descending: true)
        .snapshots();
  }

  /// Get user progress for specific material
  static Future<UserProgress?> getUserProgressForMaterial({
    required String userId,
    required String materialId,
  }) async {
    try {
      final progressId = '${userId}_$materialId';
      final doc = await _firestore
          .collection('user_progress')
          .doc(progressId)
          .get();

      if (doc.exists) {
        return UserProgress.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user progress: $e');
    }
  }

  /// Rate training material
  static Future<void> rateTrainingMaterial({
    required String userId,
    required String materialId,
    required double rating,
    String? review,
  }) async {
    try {
      // Update user progress with rating
      final progressId = '${userId}_$materialId';
      await _firestore.collection('user_progress').doc(progressId).update({
        'userRating': rating,
        'userReview': review,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update material's average rating
      await _updateMaterialRating(materialId);
    } catch (e) {
      throw Exception('Failed to rate training material: $e');
    }
  }

  /// Private method to update material average rating
  static Future<void> _updateMaterialRating(String materialId) async {
    try {
      final progressSnapshot = await _firestore
          .collection('user_progress')
          .where('materialId', isEqualTo: materialId)
          .where('userRating', isGreaterThan: 0)
          .get();

      if (progressSnapshot.docs.isEmpty) return;

      double totalRating = 0;
      int ratingCount = 0;

      for (final doc in progressSnapshot.docs) {
        final data = doc.data();
        final rating = _safeToDouble(data['userRating']);
        if (rating > 0) {
          totalRating += rating;
          ratingCount++;
        }
      }

      if (ratingCount > 0) {
        final averageRating = totalRating / ratingCount;
        await _firestore
            .collection('training_materials')
            .doc(materialId)
            .update({
              'averageRating': averageRating,
              'ratingCount': ratingCount,
            });
      }
    } catch (e) {
      print('Failed to update material rating: $e');
    }
  }

  /// Get training statistics for admin
  static Future<Map<String, dynamic>> getTrainingStatistics() async {
    try {
      final materialsSnapshot = await _firestore
          .collection('training_materials')
          .get();
      final progressSnapshot = await _firestore
          .collection('user_progress')
          .get();

      final totalMaterials = materialsSnapshot.docs.length;
      final publishedMaterials = materialsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'published')
          .length;

      final totalUsers = progressSnapshot.docs
          .map((doc) => doc.data()['userId'])
          .toSet()
          .length;

      final completedCount = progressSnapshot.docs
          .where((doc) => doc.data()['status'] == 'completed')
          .length;

      return {
        'totalMaterials': totalMaterials,
        'publishedMaterials': publishedMaterials,
        'totalUsers': totalUsers,
        'totalCompletions': completedCount,
        'averageCompletionRate': totalUsers > 0
            ? (completedCount / totalUsers * 100)
            : 0,
      };
    } catch (e) {
      throw Exception('Failed to get training statistics: $e');
    }
  }
}
