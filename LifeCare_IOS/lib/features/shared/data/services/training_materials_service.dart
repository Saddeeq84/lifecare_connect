// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class TrainingMaterial {
  final String id;
  final String title;
  final String description;
  final String url;
  final String type;
  final String targetRole;
  final String fileName;
  final int fileSize;
  final DateTime uploadedAt;
  final String uploadedBy;
  final int version;
  final bool isActive;
  final int downloadCount;
  final List<String> tags;
  final String
  syncStatus; // 'synced', 'pending_download', 'downloaded', 'offline_only'

  TrainingMaterial({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.type,
    required this.targetRole,
    required this.fileName,
    required this.fileSize,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.version,
    required this.isActive,
    required this.downloadCount,
    required this.tags,
    required this.syncStatus,
  });

  factory TrainingMaterial.fromFirestore(Map<String, dynamic> data) {
    return TrainingMaterial(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      url: data['url'] ?? '',
      type: data['type'] ?? '',
      targetRole: data['targetRole'] ?? '',
      fileName: data['fileName'] ?? '',
      fileSize: data['fileSize'] ?? 0,
      uploadedAt:
          (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      uploadedBy: data['uploadedBy'] ?? '',
      version: data['version'] ?? 1,
      isActive: data['isActive'] ?? true,
      downloadCount: data['downloadCount'] ?? 0,
      tags: List<String>.from(data['tags'] ?? []),
      syncStatus: data['syncStatus'] ?? 'synced',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'url': url,
      'type': type,
      'targetRole': targetRole,
      'fileName': fileName,
      'fileSize': fileSize,
      'uploadedAt': uploadedAt.toIso8601String(),
      'uploadedBy': uploadedBy,
      'version': version,
      'isActive': isActive,
      'downloadCount': downloadCount,
      'tags': tags,
      'syncStatus': syncStatus,
    };
  }

  factory TrainingMaterial.fromJson(Map<String, dynamic> json) {
    return TrainingMaterial(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      url: json['url'] ?? '',
      type: json['type'] ?? '',
      targetRole: json['targetRole'] ?? '',
      fileName: json['fileName'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      uploadedAt: DateTime.parse(
        json['uploadedAt'] ?? DateTime.now().toIso8601String(),
      ),
      uploadedBy: json['uploadedBy'] ?? '',
      version: json['version'] ?? 1,
      isActive: json['isActive'] ?? true,
      downloadCount: json['downloadCount'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      syncStatus: json['syncStatus'] ?? 'synced',
    );
  }
}

class TrainingMaterialsService {
  static const String _materialsKey = 'training_materials_cache';
  static const String _downloadedFilesKey = 'downloaded_files';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();

  /// Get training materials for a specific role with offline support
  Future<List<TrainingMaterial>> getMaterialsForRole(String role) async {
    try {
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      bool isOnline =
          connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);

      if (isOnline) {
        // Fetch from Firebase and update cache
        return await _fetchFromFirebaseAndCache(role);
      } else {
        // Load from local cache
        return await _loadFromCache(role);
      }
    } catch (e) {
      print('Error getting materials: $e');
      // Fallback to cache on error
      return await _loadFromCache(role);
    }
  }

  /// Fetch materials from Firebase and update local cache
  Future<List<TrainingMaterial>> _fetchFromFirebaseAndCache(String role) async {
    try {
      final snapshot = await _firestore
          .collection('training_materials')
          .where('targetRole', isEqualTo: role)
          .where('isActive', isEqualTo: true)
          .orderBy('uploadedAt', descending: true)
          .get();

      List<TrainingMaterial> materials = snapshot.docs
          .map((doc) => TrainingMaterial.fromFirestore(doc.data()))
          .toList();

      // Cache the materials
      await _cacheNaterials(materials);
      return materials;
    } catch (e) {
      print('Error fetching from Firebase: $e');
      return await _loadFromCache(role);
    }
  }

  /// Load materials from local cache
  Future<List<TrainingMaterial>> _loadFromCache(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_materialsKey);

      if (cachedData != null) {
        final List<dynamic> jsonList = json.decode(cachedData);
        List<TrainingMaterial> allMaterials = jsonList
            .map((json) => TrainingMaterial.fromJson(json))
            .toList();

        // Filter by role
        return allMaterials
            .where((material) => material.targetRole == role)
            .toList();
      }

      return [];
    } catch (e) {
      print('Error loading from cache: $e');
      return [];
    }
  }

  /// Cache materials locally
  Future<void> _cacheNaterials(List<TrainingMaterial> materials) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing cache
      List<TrainingMaterial> existingMaterials = [];
      final cachedData = prefs.getString(_materialsKey);
      if (cachedData != null) {
        final List<dynamic> jsonList = json.decode(cachedData);
        existingMaterials = jsonList
            .map((json) => TrainingMaterial.fromJson(json))
            .toList();
      }

      // Merge new materials with existing ones
      Map<String, TrainingMaterial> materialMap = {
        for (var material in existingMaterials) material.id: material,
      };

      for (var material in materials) {
        materialMap[material.id] = material;
      }

      // Save updated cache
      final jsonList = materialMap.values
          .map((material) => material.toJson())
          .toList();
      await prefs.setString(_materialsKey, json.encode(jsonList));
    } catch (e) {
      print('Error caching materials: $e');
    }
  }

  /// Download material file for offline access
  Future<String?> downloadMaterialFile(TrainingMaterial material) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/training_materials/${material.targetRole}/${material.fileName}';
      final file = File(filePath);

      // Create directory if it doesn't exist
      await file.parent.create(recursive: true);

      // Download file
      final response = await http.get(Uri.parse(material.url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);

        // Update download tracking
        await _trackDownload(material.id, filePath);

        return filePath;
      }

      return null;
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }

  /// Track downloaded files
  Future<void> _trackDownload(String materialId, String localPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadedFiles = prefs.getStringList(_downloadedFilesKey) ?? [];

      final downloadInfo = json.encode({
        'materialId': materialId,
        'localPath': localPath,
        'downloadedAt': DateTime.now().toIso8601String(),
      });

      downloadedFiles.add(downloadInfo);
      await prefs.setStringList(_downloadedFilesKey, downloadedFiles);
    } catch (e) {
      print('Error tracking download: $e');
    }
  }

  /// Check if material is downloaded
  Future<String?> getLocalFilePath(String materialId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadedFiles = prefs.getStringList(_downloadedFilesKey) ?? [];

      for (String downloadInfo in downloadedFiles) {
        final info = json.decode(downloadInfo);
        if (info['materialId'] == materialId) {
          final localPath = info['localPath'];
          if (await File(localPath).exists()) {
            return localPath;
          }
        }
      }

      return null;
    } catch (e) {
      print('Error checking local file: $e');
      return null;
    }
  }

  /// Sync pending changes when online
  Future<void> syncWhenOnline() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult.isEmpty ||
          connectivityResult.contains(ConnectivityResult.none)) {
        return;
      }

      // Implement sync logic for any pending uploads or updates
      print('Syncing training materials...');

      // This would handle any offline-created materials or updates
      // For now, just refresh the cache
      await _fetchFromFirebaseAndCache('chw');
      await _fetchFromFirebaseAndCache('doctor');
      await _fetchFromFirebaseAndCache('patient');
    } catch (e) {
      print('Error during sync: $e');
    }
  }

  /// Clear cache (for debugging or storage management)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_materialsKey);
      await prefs.remove(_downloadedFilesKey);

      // Also clear downloaded files
      final directory = await getApplicationDocumentsDirectory();
      final trainingDir = Directory('${directory.path}/training_materials');
      if (await trainingDir.exists()) {
        await trainingDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  /// Get storage usage information
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadedFiles = prefs.getStringList(_downloadedFilesKey) ?? [];

      int totalSize = 0;
      int fileCount = 0;

      for (String downloadInfo in downloadedFiles) {
        final info = json.decode(downloadInfo);
        final localPath = info['localPath'];
        final file = File(localPath);
        if (await file.exists()) {
          totalSize += await file.length();
          fileCount++;
        }
      }

      return {
        'totalSize': totalSize,
        'fileCount': fileCount,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      print('Error getting storage info: $e');
      return {'totalSize': 0, 'fileCount': 0, 'totalSizeMB': '0.00'};
    }
  }
}
