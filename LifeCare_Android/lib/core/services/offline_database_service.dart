// Offline-first Local Database Service
// Provides SQLite storage for critical app data to enable offline functionality

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class OfflineDatabaseService {
  static final OfflineDatabaseService _instance =
      OfflineDatabaseService._internal();
  factory OfflineDatabaseService() => _instance;
  OfflineDatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'lifecare_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // User authentication table for offline login
    await db.execute('''
      CREATE TABLE users (
        uid TEXT PRIMARY KEY,
        email TEXT,
        name TEXT,
        role TEXT,
        phone TEXT,
        profileImageUrl TEXT,
        userData TEXT,
        lastSynced INTEGER,
        isActive INTEGER DEFAULT 1
      )
    ''');

    // Appointments table
    await db.execute('''
      CREATE TABLE appointments (
        id TEXT PRIMARY KEY,
        patientId TEXT,
        providerId TEXT,
        facilityId TEXT,
        appointmentDate INTEGER,
        status TEXT,
        type TEXT,
        notes TEXT,
        appointmentData TEXT,
        syncStatus TEXT DEFAULT 'pending',
        lastModified INTEGER,
        createdOffline INTEGER DEFAULT 0
      )
    ''');

    // Medical records table
    await db.execute('''
      CREATE TABLE medical_records (
        id TEXT PRIMARY KEY,
        patientId TEXT,
        providerId TEXT,
        recordType TEXT,
        recordDate INTEGER,
        recordData TEXT,
        fileUrls TEXT,
        syncStatus TEXT DEFAULT 'pending',
        lastModified INTEGER,
        createdOffline INTEGER DEFAULT 0
      )
    ''');

    // Patients table for CHWs
    await db.execute('''
      CREATE TABLE patients (
        uid TEXT PRIMARY KEY,
        name TEXT,
        email TEXT,
        phone TEXT,
        dateOfBirth TEXT,
        gender TEXT,
        address TEXT,
        chwId TEXT,
        patientData TEXT,
        syncStatus TEXT DEFAULT 'synced',
        lastModified INTEGER,
        createdOffline INTEGER DEFAULT 0
      )
    ''');

    // Training materials table
    await db.execute('''
      CREATE TABLE training_materials (
        id TEXT PRIMARY KEY,
        title TEXT,
        description TEXT,
        targetRole TEXT,
        type TEXT,
        url TEXT,
        localPath TEXT,
        fileSize INTEGER,
        materialData TEXT,
        downloadStatus TEXT DEFAULT 'pending',
        lastModified INTEGER
      )
    ''');

    // Sync queue table for pending operations
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operationType TEXT,
        entityType TEXT,
        entityId TEXT,
        operationData TEXT,
        priority INTEGER DEFAULT 0,
        retryCount INTEGER DEFAULT 0,
        maxRetries INTEGER DEFAULT 5,
        createdAt INTEGER,
        lastAttempt INTEGER,
        status TEXT DEFAULT 'pending'
      )
    ''');

    // Offline registration queue
    await db.execute('''
      CREATE TABLE registration_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT,
        password TEXT,
        userData TEXT,
        role TEXT,
        createdAt INTEGER,
        syncStatus TEXT DEFAULT 'pending',
        retryCount INTEGER DEFAULT 0
      )
    ''');

    // Settings and preferences
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT,
        lastModified INTEGER
      )
    ''');

    // Create indexes for faster queries
    await db.execute(
      'CREATE INDEX idx_appointments_patient ON appointments(patientId)',
    );
    await db.execute(
      'CREATE INDEX idx_appointments_provider ON appointments(providerId)',
    );
    await db.execute(
      'CREATE INDEX idx_appointments_status ON appointments(status)',
    );
    await db.execute(
      'CREATE INDEX idx_medical_records_patient ON medical_records(patientId)',
    );
    await db.execute('CREATE INDEX idx_patients_chw ON patients(chwId)');
    await db.execute(
      'CREATE INDEX idx_sync_queue_status ON sync_queue(status)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database schema upgrades
    if (oldVersion < 2) {
      // Future schema changes will go here
    }
  }

  // ===== USER METHODS =====

  Future<void> saveUser(Map<String, dynamic> userData) async {
    final db = await database;
    await db.insert('users', {
      'uid': userData['uid'],
      'email': userData['email'],
      'name': userData['name'],
      'role': userData['role'],
      'phone': userData['phone'] ?? '',
      'profileImageUrl': userData['profileImageUrl'] ?? '',
      'userData': jsonEncode(userData),
      'lastSynced': DateTime.now().millisecondsSinceEpoch,
      'isActive': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getUser(String uid) async {
    final db = await database;
    final results = await db.query('users', where: 'uid = ?', whereArgs: [uid]);

    if (results.isEmpty) return null;

    final userData = jsonDecode(results.first['userData'] as String);
    return userData as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'email = ? AND isActive = 1',
      whereArgs: [email],
    );

    if (results.isEmpty) return null;

    final userData = jsonDecode(results.first['userData'] as String);
    return userData as Map<String, dynamic>;
  }

  Future<void> deleteUser(String uid) async {
    final db = await database;
    await db.update(
      'users',
      {'isActive': 0},
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  // ===== APPOINTMENT METHODS =====

  Future<void> saveAppointment(Map<String, dynamic> appointmentData) async {
    final db = await database;
    await db.insert('appointments', {
      'id':
          appointmentData['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'patientId': appointmentData['patientId'],
      'providerId': appointmentData['providerId'],
      'facilityId': appointmentData['facilityId'] ?? '',
      'appointmentDate': appointmentData['appointmentDate'] is DateTime
          ? (appointmentData['appointmentDate'] as DateTime)
                .millisecondsSinceEpoch
          : appointmentData['appointmentDate'],
      'status': appointmentData['status'] ?? 'pending',
      'type': appointmentData['type'] ?? 'consultation',
      'notes': appointmentData['notes'] ?? '',
      'appointmentData': jsonEncode(appointmentData),
      'syncStatus': appointmentData['syncStatus'] ?? 'pending',
      'lastModified': DateTime.now().millisecondsSinceEpoch,
      'createdOffline': appointmentData['createdOffline'] ?? 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAppointments({
    String? patientId,
    String? providerId,
    String? status,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (patientId != null) {
      whereClause = 'patientId = ?';
      whereArgs.add(patientId);
    } else if (providerId != null) {
      whereClause = 'providerId = ?';
      whereArgs.add(providerId);
    }

    if (status != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND status = ?';
      } else {
        whereClause = 'status = ?';
      }
      whereArgs.add(status);
    }

    final results = await db.query(
      'appointments',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'appointmentDate DESC',
    );

    return results.map((row) {
      final appointmentData = jsonDecode(row['appointmentData'] as String);
      return appointmentData as Map<String, dynamic>;
    }).toList();
  }

  Future<void> updateAppointmentStatus(String id, String status) async {
    final db = await database;
    final appointment = await db.query(
      'appointments',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (appointment.isNotEmpty) {
      final data =
          jsonDecode(appointment.first['appointmentData'] as String)
              as Map<String, dynamic>;
      data['status'] = status;

      await db.update(
        'appointments',
        {
          'status': status,
          'appointmentData': jsonEncode(data),
          'syncStatus': 'pending',
          'lastModified': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // ===== PATIENT METHODS =====

  Future<void> savePatient(Map<String, dynamic> patientData) async {
    final db = await database;
    await db.insert('patients', {
      'uid':
          patientData['uid'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'name': patientData['name'],
      'email': patientData['email'] ?? '',
      'phone': patientData['phone'] ?? '',
      'dateOfBirth': patientData['dateOfBirth'] ?? '',
      'gender': patientData['gender'] ?? '',
      'address': patientData['address'] ?? '',
      'chwId': patientData['chwId'] ?? '',
      'patientData': jsonEncode(patientData),
      'syncStatus': patientData['syncStatus'] ?? 'pending',
      'lastModified': DateTime.now().millisecondsSinceEpoch,
      'createdOffline': patientData['createdOffline'] ?? 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getPatients({String? chwId}) async {
    final db = await database;
    final results = await db.query(
      'patients',
      where: chwId != null ? 'chwId = ?' : null,
      whereArgs: chwId != null ? [chwId] : null,
      orderBy: 'name ASC',
    );

    return results.map((row) {
      final patientData = jsonDecode(row['patientData'] as String);
      return patientData as Map<String, dynamic>;
    }).toList();
  }

  // ===== SYNC QUEUE METHODS =====

  Future<void> addToSyncQueue({
    required String operationType,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> operationData,
    int priority = 0,
  }) async {
    final db = await database;
    await db.insert('sync_queue', {
      'operationType': operationType,
      'entityType': entityType,
      'entityId': entityId,
      'operationData': jsonEncode(operationData),
      'priority': priority,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncOperations() async {
    final db = await database;
    final results = await db.query(
      'sync_queue',
      where: 'status = ? AND retryCount < maxRetries',
      whereArgs: ['pending'],
      orderBy: 'priority DESC, createdAt ASC',
    );

    return results.map((row) {
      return {
        'id': row['id'],
        'operationType': row['operationType'],
        'entityType': row['entityType'],
        'entityId': row['entityId'],
        'operationData': jsonDecode(row['operationData'] as String),
        'retryCount': row['retryCount'],
        'createdAt': row['createdAt'],
      };
    }).toList();
  }

  Future<void> markSyncComplete(int syncId) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'status': 'completed'},
      where: 'id = ?',
      whereArgs: [syncId],
    );
  }

  Future<void> incrementSyncRetry(int syncId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE sync_queue SET retryCount = retryCount + 1, lastAttempt = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch, syncId],
    );
  }

  // ===== REGISTRATION QUEUE =====

  Future<void> queueOfflineRegistration({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
    required String role,
  }) async {
    final db = await database;
    await db.insert('registration_queue', {
      'email': email,
      'password': password, // Note: Should be hashed in production
      'userData': jsonEncode(userData),
      'role': role,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'syncStatus': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getPendingRegistrations() async {
    final db = await database;
    final results = await db.query(
      'registration_queue',
      where: 'syncStatus = ? AND retryCount < 5',
      whereArgs: ['pending'],
      orderBy: 'createdAt ASC',
    );

    return results
        .map(
          (row) => {
            'id': row['id'],
            'email': row['email'],
            'password': row['password'],
            'userData': jsonDecode(row['userData'] as String),
            'role': row['role'],
            'createdAt': row['createdAt'],
          },
        )
        .toList();
  }

  Future<void> markRegistrationComplete(int registrationId) async {
    final db = await database;
    await db.delete(
      'registration_queue',
      where: 'id = ?',
      whereArgs: [registrationId],
    );
  }

  // ===== SETTINGS =====

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
      'lastModified': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final results = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );

    return results.isEmpty ? null : results.first['value'] as String?;
  }

  // ===== UTILITY METHODS =====

  Future<int> getPendingSyncCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sync_queue WHERE status = ?',
      ['pending'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('users');
    await db.delete('appointments');
    await db.delete('medical_records');
    await db.delete('patients');
    await db.delete('sync_queue');
    await db.delete('registration_queue');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
