import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

class AccountCreationException implements Exception {
  final String message;

  const AccountCreationException(this.message);

  @override
  String toString() => message;
}

class LoginException implements Exception {
  final String message;

  const LoginException(this.message);

  @override
  String toString() => message;
}

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  AppUser? _profile;
  String _userRole = '';
  bool _isLoadingProfile = false;
  bool _isSigningUp = false;

  User? get user => _user;
  AppUser? get profile => _profile;
  bool get isAuthenticated => _user != null;
  String get userRole => _userRole;
  bool get isLoadingProfile => _isLoadingProfile;
  bool get isApprovedRider =>
      _userRole == 'rider' && _profile?.riderStatus == 'approved';

  bool _isEmail(String value) => value.contains('@');

  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('234')) return '+$digits';
    if (digits.startsWith('0') && digits.length >= 10) {
      return '+234${digits.substring(1)}';
    }
    if (digits.isNotEmpty) return '+$digits';
    return '';
  }

  String _phoneAuthEmail(String phone) {
    final digits = _normalizePhone(phone).replaceAll(RegExp(r'\D'), '');
    return 'phone-$digits@phone.carrygo.local';
  }

  String _phoneLookupKey(String phone) {
    return _normalizePhone(phone).replaceAll(RegExp(r'\D'), '');
  }

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _isLoadingProfile = true;
        notifyListeners();
        _loadUserRole();
      } else {
        _userRole = '';
        _profile = null;
        _isLoadingProfile = false;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserRole() async {
    final user = _user;
    if (user == null) return;
    if (_isSigningUp) return;

    final token = await user.getIdTokenResult(true);
    final claims = token.claims ?? {};
    final claimRole = _normalizeRole(claims['role'] as String? ?? '');
    final hasAdminClaim = claims['admin'] == true || claimRole == 'admin';
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final riderDoc = await _firestore.collection('riders').doc(user.uid).get();

    if (doc.exists) {
      final data = doc.data() ?? {};
      final resolvedRole = _resolveRole(
        profileData: data,
        claimRole: claimRole,
        hasAdminClaim: hasAdminClaim,
        hasRiderProfile: riderDoc.exists,
        displayName: user.displayName ?? '',
      );
      if (resolvedRole.isEmpty) {
        _profile = null;
        _userRole = '';
        _isLoadingProfile = false;
        notifyListeners();
        return;
      }
      data['role'] = resolvedRole;
      if (resolvedRole == 'rider' && riderDoc.exists) {
        final riderData = riderDoc.data() ?? {};
        data['riderStatus'] = data['riderStatus'] ??
            riderData['verificationStatus'] ??
            (riderData['isVerified'] == true ? 'approved' : 'pending');
        data['isApproved'] = data['isApproved'] ??
            (riderData['isVerified'] == true ||
                data['riderStatus'] == 'approved');
      }
      _profile = AppUser.fromMap(user.uid, data);
      _userRole = resolvedRole;
      _isLoadingProfile = false;
      notifyListeners();
      return;
    }

    _userRole = _resolveRole(
      profileData: const {},
      claimRole: claimRole,
      hasAdminClaim: hasAdminClaim,
      hasRiderProfile: riderDoc.exists,
      displayName: user.displayName ?? '',
    );
    if (_userRole.isEmpty) {
      _profile = null;
      _isLoadingProfile = false;
      notifyListeners();
      return;
    }
    _profile = AppUser(
      id: user.uid,
      email: user.email ?? '',
      fullName: user.email?.split('@').first ?? 'CarryGo User',
      phone: '',
      phoneNormalized: '',
      role: _userRole,
      city: 'Lagos',
      isApproved: _userRole != 'rider',
    );
    if (_userRole != 'admin') {
      await _firestore.collection('users').doc(user.uid).set(_profile!.toMap());
    }
    _isLoadingProfile = false;
    notifyListeners();
  }

  Future<void> signIn(String identifier, String password) async {
    final cleanIdentifier = identifier.trim();
    if (cleanIdentifier.isEmpty || password.isEmpty) {
      throw const LoginException('Enter your login detail and password.');
    }
    var authEmail = cleanIdentifier.toLowerCase();

    if (!_isEmail(cleanIdentifier)) {
      final normalizedPhone = _normalizePhone(cleanIdentifier);
      final phoneKey = _phoneLookupKey(cleanIdentifier);
      final phoneLogin =
          await _firestore.collection('phone_logins').doc(phoneKey).get();
      if (phoneLogin.exists) {
        final data = phoneLogin.data() ?? {};
        authEmail =
            data['authEmail'] as String? ?? _phoneAuthEmail(cleanIdentifier);
      } else {
        authEmail = _phoneAuthEmail(normalizedPhone);
      }
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
      _user = credential.user;
      _profile = null;
      _userRole = '';
      _isLoadingProfile = true;
      notifyListeners();
      await _loadUserRole();
      if (_userRole.isEmpty) {
        await _auth.signOut();
        throw const LoginException(
          'This account has no CarryGo profile. Contact support.',
        );
      }
    } on FirebaseAuthException catch (e) {
      _user = null;
      _profile = null;
      _userRole = '';
      _isLoadingProfile = false;
      notifyListeners();
      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'user-not-found') {
        throw const LoginException('Invalid login details or password.');
      }
      if (e.code == 'too-many-requests') {
        throw const LoginException(
            'Too many attempts. Please try again later.');
      }
      throw LoginException(e.message ?? 'Login failed. Please try again.');
    }
  }

  String _normalizeRole(String role) {
    final value = role.toLowerCase().trim();
    if (value == 'admin' || value == 'administrator' || value == 'superadmin') {
      return 'admin';
    }
    if (value == 'rider' ||
        value == 'delivery' ||
        value == 'delivery_person' ||
        value == 'delivery person' ||
        value == 'driver' ||
        value == 'courier') {
      return 'rider';
    }
    if (value == 'customer' || value == 'user' || value == 'client') {
      return 'customer';
    }
    return '';
  }

  String _resolveRole({
    required Map<String, dynamic> profileData,
    required String claimRole,
    required bool hasAdminClaim,
    required bool hasRiderProfile,
    required String displayName,
  }) {
    if (hasAdminClaim) return 'admin';
    if (profileData['isAdmin'] == true || profileData['admin'] == true) {
      return 'admin';
    }
    final role = _normalizeRole(profileData['role'] as String? ?? '');
    if (role == 'admin' || claimRole == 'admin') return 'admin';
    if (hasRiderProfile) return 'rider';
    if (role.isNotEmpty) return role;
    if (claimRole.isNotEmpty) return claimRole;
    return _normalizeRole(displayName);
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signUp({
    required String identifier,
    required String password,
    required String role,
    required String fullName,
    required String phone,
    required String city,
    String bikePlateNumber = '',
    String profilePhotoUrl = '',
    String idCardUrl = '',
    String bikeModel = '',
    String bikeColor = '',
    String riderLicenseUrl = '',
    String bankName = '',
    String bankAccountNumber = '',
    String bankAccountName = '',
    List<String> documentUrls = const [],
  }) async {
    final cleanIdentifier = identifier.trim();
    final identifierIsEmail = _isEmail(cleanIdentifier);
    final displayEmail = identifierIsEmail ? cleanIdentifier.toLowerCase() : '';
    final displayPhone = identifierIsEmail ? phone.trim() : cleanIdentifier;
    final phoneNormalized = _normalizePhone(displayPhone);
    final authEmail = identifierIsEmail
        ? cleanIdentifier.toLowerCase()
        : _phoneAuthEmail(cleanIdentifier);

    if (!identifierIsEmail && phoneNormalized.isEmpty) {
      throw const AccountCreationException('Enter a valid phone number.');
    }

    if (cleanIdentifier.isEmpty ||
        password.isEmpty ||
        fullName.trim().isEmpty) {
      throw const AccountCreationException(
        'Enter your name, login detail, and password to create an account.',
      );
    }
    if (role == 'rider' &&
        (bikePlateNumber.trim().isEmpty ||
            bikeModel.trim().isEmpty ||
            bikeColor.trim().isEmpty)) {
      throw const AccountCreationException(
        'Enter bike plate number, bike make/model, and bike color.',
      );
    }

    if (phoneNormalized.isNotEmpty) {
      final phoneLogin = await _firestore
          .collection('phone_logins')
          .doc(_phoneLookupKey(displayPhone))
          .get();
      if (phoneLogin.exists) {
        throw const AccountCreationException(
          'That phone number already has a CarryGo account. Please sign in instead.',
        );
      }
    }

    _isSigningUp = true;
    User? user;
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
      await result.user?.updateDisplayName(role);
      user = result.user;
    } on FirebaseAuthException catch (e) {
      _isSigningUp = false;
      if (e.code == 'email-already-in-use') {
        throw AccountCreationException(
          identifierIsEmail
              ? 'That email already has a CarryGo account. Please sign in instead.'
              : 'That phone number already has a CarryGo account. Please sign in instead.',
        );
      }
      if (e.code == 'invalid-email') {
        throw AccountCreationException(
          identifierIsEmail
              ? 'Enter a valid email address.'
              : 'Enter a valid phone number.',
        );
      }
      if (e.code == 'weak-password') {
        throw const AccountCreationException(
          'Use a stronger password with at least 6 characters.',
        );
      }
      throw AccountCreationException(
        e.message ?? 'We could not create your account. Please try again.',
      );
    } catch (_) {
      _isSigningUp = false;
      rethrow;
    }
    if (user == null) {
      _isSigningUp = false;
      return;
    }

    try {
      _profile = AppUser(
        id: user.uid,
        email: displayEmail,
        fullName: fullName,
        phone: displayPhone,
        phoneNormalized: phoneNormalized,
        role: role,
        city: city,
        riderStatus: role == 'rider' ? 'pending' : 'not_applicable',
        profilePhotoUrl: profilePhotoUrl,
        idCardUrl: idCardUrl,
        bikePlateNumber: bikePlateNumber,
        bikeModel: bikeModel,
        bikeColor: bikeColor,
        isApproved: role != 'rider',
      );
      await _firestore.collection('users').doc(user.uid).set({
        ..._profile!.toMap(),
        'authEmail': authEmail,
        'authMethod': identifierIsEmail ? 'email' : 'phone',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (phoneNormalized.isNotEmpty) {
        await _firestore
            .collection('phone_logins')
            .doc(_phoneLookupKey(displayPhone))
            .set({
          'uid': user.uid,
          'authEmail': authEmail,
          'phoneNormalized': phoneNormalized,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (role == 'rider') {
        await _firestore.collection('riders').doc(user.uid).set({
          'userId': user.uid,
          'name': fullName,
          'fullName': fullName,
          'phone': displayPhone,
          'city': city,
          'status': 'offline',
          'isOnline': false,
          'adminApprovalStatus': 'pending',
          'verificationStatus': 'awaiting_admin_approval',
          'isVerified': false,
          'bikeNumber': bikePlateNumber,
          'bikePlateNumber': bikePlateNumber,
          'bikeModel': bikeModel,
          'bikeColor': bikeColor,
          'idCardUrl': '',
          'idCardType': 'NIN',
          'riderLicenseUrl': '',
          'documentUrls': const [],
          'profileCompleted': false,
          'currentLatitude': null,
          'currentLongitude': null,
          'ratingAverage': 0,
          'completedOrders': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await _queueAccountMessage(
          userId: user.uid,
          role: 'rider',
          email: displayEmail,
          phone: displayPhone,
          title: 'Rider account received',
          body:
              'Your CarryGo rider account has been created. Admin approval is required before you can complete verification and start receiving orders.',
        );
      } else {
        await _queueAccountMessage(
          userId: user.uid,
          role: 'customer',
          email: displayEmail,
          phone: displayPhone,
          title: 'CarryGo account opened successfully',
          body:
              'Welcome to CarryGo. Your customer account has been opened successfully.',
        );
      }
      _userRole = role;
      _isLoadingProfile = false;
      notifyListeners();
    } finally {
      _isSigningUp = false;
    }
  }

  Future<void> approveRider(String riderId) async {
    final adminId = _user?.uid ?? 'system';
    final riderDoc = await _firestore.collection('riders').doc(riderId).get();
    final userDoc = await _firestore.collection('users').doc(riderId).get();
    final riderData = riderDoc.data() ?? {};
    final userData = userDoc.data() ?? {};
    await _firestore.collection('users').doc(riderId).update({
      'riderStatus': 'approved',
      'isApproved': true,
    });
    await _firestore.collection('riders').doc(riderId).set({
      'adminApprovalStatus': 'approved',
      'verificationStatus': 'profile_incomplete',
      'isVerified': false,
      'approvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _queueAccountMessage(
      userId: riderId,
      role: 'rider',
      email: userData['email'] as String? ?? '',
      phone:
          userData['phone'] as String? ?? riderData['phone'] as String? ?? '',
      title: 'CarryGo rider account approved',
      body:
          'Your CarryGo rider account has been approved. Please log in and complete your NIN and verification document uploads before going online.',
    );
    await _firestore.collection('admin_logs').add({
      'adminId': adminId,
      'action': 'approve_rider',
      'entityType': 'riders',
      'entityId': riderId,
      'before': {'verificationStatus': 'pending'},
      'after': {'verificationStatus': 'approved'},
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (_profile?.id == riderId) {
      _profile = AppUser(
        id: _profile!.id,
        email: _profile!.email,
        fullName: _profile!.fullName,
        phone: _profile!.phone,
        phoneNormalized: _profile!.phoneNormalized,
        role: _profile!.role,
        city: _profile!.city,
        riderStatus: 'approved',
        isApproved: true,
        profilePhotoUrl: _profile!.profilePhotoUrl,
        idCardUrl: _profile!.idCardUrl,
        bikePlateNumber: _profile!.bikePlateNumber,
        bikeModel: _profile!.bikeModel,
        bikeColor: _profile!.bikeColor,
        riderLicenseUrl: _profile!.riderLicenseUrl,
        bankName: _profile!.bankName,
        bankAccountNumber: _profile!.bankAccountNumber,
        bankAccountName: _profile!.bankAccountName,
        documentUrls: _profile!.documentUrls,
      );
      notifyListeners();
    }
  }

  Future<void> rejectRider(String riderId, String reason) async {
    final adminId = _user?.uid ?? 'system';
    await _firestore.collection('users').doc(riderId).update({
      'riderStatus': 'rejected',
      'isApproved': false,
      'rejectionReason': reason,
      'accountStatus': 'active',
    });
    await _firestore.collection('riders').doc(riderId).set({
      'verificationStatus': 'rejected',
      'isVerified': false,
      'rejectionReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _firestore.collection('admin_logs').add({
      'adminId': adminId,
      'action': 'reject_rider',
      'entityType': 'riders',
      'entityId': riderId,
      'after': {
        'verificationStatus': 'rejected',
        'reason': reason,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> suspendUser(String userId, String reason) async {
    final adminId = _user?.uid ?? 'system';
    await _firestore.collection('users').doc(userId).update({
      'accountStatus': 'suspended',
      'suspensionReason': reason,
      'suspendedAt': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('admin_logs').add({
      'adminId': adminId,
      'action': 'suspend_user',
      'entityType': 'users',
      'entityId': userId,
      'after': {'accountStatus': 'suspended', 'reason': reason},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reinstateUser(String userId, String role) async {
    final adminId = _user?.uid ?? 'system';
    await _firestore.collection('users').doc(userId).set({
      'accountStatus': 'active',
      'suspensionReason': '',
      if (role == 'rider') 'riderStatus': 'approved',
      if (role == 'rider') 'isApproved': true,
      'reinstatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (role == 'rider') {
      await _firestore.collection('riders').doc(userId).set({
        'status': 'offline',
        'isOnline': false,
        'verificationStatus': 'approved',
        'isVerified': true,
        'suspensionReason': '',
        'reinstatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await _firestore.collection('admin_logs').add({
      'adminId': adminId,
      'action': role == 'rider' ? 'reinstate_rider' : 'reinstate_user',
      'entityType': role == 'rider' ? 'riders' : 'users',
      'entityId': userId,
      'after': {'accountStatus': 'active', 'role': role},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> suspendRider(String riderId, String reason) async {
    final adminId = _user?.uid ?? 'system';
    await _firestore.collection('users').doc(riderId).update({
      'accountStatus': 'suspended',
      'riderStatus': 'suspended',
      'isApproved': false,
      'suspensionReason': reason,
      'suspendedAt': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('riders').doc(riderId).set({
      'status': 'suspended',
      'isOnline': false,
      'verificationStatus': 'suspended',
      'isVerified': false,
      'suspensionReason': reason,
      'suspendedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _firestore.collection('admin_logs').add({
      'adminId': adminId,
      'action': 'suspend_rider',
      'entityType': 'riders',
      'entityId': riderId,
      'after': {
        'status': 'suspended',
        'verificationStatus': 'suspended',
        'reason': reason,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRiderProfile(
    String riderId,
  ) {
    return _firestore.collection('riders').doc(riderId).snapshots();
  }

  Future<void> completeRiderVerificationProfile({
    required String riderId,
    required String ninNumber,
    required String ninDocumentUrl,
    required String verificationDocumentUrl,
  }) async {
    if (ninNumber.trim().isEmpty ||
        ninDocumentUrl.isEmpty ||
        verificationDocumentUrl.isEmpty) {
      throw const AccountCreationException(
        'Enter your NIN number and upload your NIN and licence documents.',
      );
    }
    await _firestore.collection('riders').doc(riderId).set({
      'ninNumber': ninNumber.trim(),
      'idCardUrl': ninDocumentUrl,
      'idCardType': 'NIN',
      'riderLicenseUrl': verificationDocumentUrl,
      'documentUrls': [ninDocumentUrl, verificationDocumentUrl],
      'profileCompleted': true,
      'verificationStatus': 'pending_document_review',
      'documentReviewStatus': 'pending',
      'ninStatus': 'pending',
      'licenseStatus': 'pending',
      'isVerified': false,
      'documentReviewSubmittedAt': FieldValue.serverTimestamp(),
      'profileCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _firestore.collection('users').doc(riderId).set({
      'ninNumber': ninNumber.trim(),
      'idCardUrl': ninDocumentUrl,
      'riderLicenseUrl': verificationDocumentUrl,
      'documentUrls': [ninDocumentUrl, verificationDocumentUrl],
      'documentReviewStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> approveRiderDocuments(String riderId) async {
    final adminId = _user?.uid ?? 'system';
    final userDoc = await _firestore.collection('users').doc(riderId).get();
    final userData = userDoc.data() ?? {};
    await _firestore.collection('riders').doc(riderId).set({
      'verificationStatus': 'approved',
      'documentReviewStatus': 'approved',
      'ninStatus': 'approved',
      'licenseStatus': 'approved',
      'isVerified': true,
      'documentsApprovedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _firestore.collection('users').doc(riderId).set({
      'riderStatus': 'approved',
      'isApproved': true,
      'documentReviewStatus': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _queueAccountMessage(
      userId: riderId,
      role: 'rider',
      email: userData['email'] as String? ?? '',
      phone: userData['phone'] as String? ?? '',
      title: 'CarryGo rider account active',
      body:
          'Your CarryGo rider documents have been approved. Your account is now active and you can go online to receive orders.',
    );
    await _firestore.collection('admin_logs').add({
      'adminId': adminId,
      'action': 'approve_rider_documents',
      'entityType': 'riders',
      'entityId': riderId,
      'after': {'documentReviewStatus': 'approved'},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectRiderDocuments(String riderId, String reason) async {
    final adminId = _user?.uid ?? 'system';
    final userDoc = await _firestore.collection('users').doc(riderId).get();
    final userData = userDoc.data() ?? {};
    await _firestore.collection('riders').doc(riderId).set({
      'verificationStatus': 'documents_rejected',
      'documentReviewStatus': 'rejected',
      'ninStatus': 'rejected',
      'licenseStatus': 'rejected',
      'isVerified': false,
      'profileCompleted': false,
      'documentRejectionReason': reason,
      'documentsRejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _firestore.collection('users').doc(riderId).set({
      'riderStatus': 'documents_rejected',
      'isApproved': true,
      'documentReviewStatus': 'rejected',
      'documentRejectionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _queueAccountMessage(
      userId: riderId,
      role: 'rider',
      email: userData['email'] as String? ?? '',
      phone: userData['phone'] as String? ?? '',
      title: 'CarryGo rider document review',
      body:
          'Your rider documents were rejected. Please log in, correct the issue, and upload again. Reason: $reason',
    );
    await _firestore.collection('admin_logs').add({
      'adminId': adminId,
      'action': 'reject_rider_documents',
      'entityType': 'riders',
      'entityId': riderId,
      'after': {'documentReviewStatus': 'rejected', 'reason': reason},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setRiderOnline(String riderId, bool isOnline) async {
    final riderDoc = await _firestore.collection('riders').doc(riderId).get();
    final riderData = riderDoc.data() ?? {};
    final profileComplete = riderData['profileCompleted'] == true &&
        (riderData['idCardUrl'] as String? ?? '').isNotEmpty &&
        (riderData['riderLicenseUrl'] as String? ?? '').isNotEmpty &&
        riderData['documentReviewStatus'] == 'approved' &&
        riderData['isVerified'] == true;
    if (isOnline && !profileComplete) {
      throw const AccountCreationException(
        'Your NIN and licence documents must be approved before going online.',
      );
    }
    await _firestore.collection('riders').doc(riderId).set({
      'status': isOnline ? 'available' : 'offline',
      'isOnline': isOnline,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _firestore.collection('public_riders').doc(riderId).set({
      'riderId': riderId,
      'city': riderData['city'] ?? _profile?.city ?? 'Lagos',
      'name': riderData['fullName'] ??
          riderData['name'] ??
          _profile?.fullName ??
          '',
      'phone': riderData['phone'] ?? _profile?.phone ?? '',
      'isVerified': profileComplete,
      'isOnline': isOnline,
      'status': isOnline ? 'available' : 'offline',
      'bikeModel': riderData['bikeModel'] ?? '',
      'bikePlateNumber': riderData['bikePlateNumber'] ?? '',
      'bikeColor': riderData['bikeColor'] ?? '',
      'currentLatitude': riderData['currentLatitude'],
      'currentLongitude': riderData['currentLongitude'],
      'ratingAverage': riderData['ratingAverage'] ?? 0,
      'completedOrders': riderData['completedOrders'] ?? 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _queueAccountMessage({
    required String userId,
    required String role,
    required String email,
    required String phone,
    required String title,
    required String body,
  }) async {
    await _firestore.collection('notifications').add({
      'userId': userId,
      'role': role,
      'title': title,
      'body': body,
      'type': 'account',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (email.isNotEmpty) {
      await _firestore.collection('email_queue').add({
        'userId': userId,
        'to': email,
        'subject': title,
        'body': body,
        'status': 'queued',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    if (phone.isNotEmpty) {
      await _firestore.collection('sms_queue').add({
        'userId': userId,
        'to': phone,
        'body': body,
        'status': 'queued',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<List<AppUser>> usersByRole(String role) {
    final normalizedRole = _normalizeRole(role);
    return _firestore
        .collection('users')
        .where('role', isEqualTo: normalizedRole)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppUser.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<List<AppUser>> watchAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) => snapshot
        .docs
        .map((doc) => AppUser.fromMap(doc.id, doc.data()))
        .toList());
  }

  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    final profile = _profile;
    if (user == null || profile == null) {
      throw const LoginException('Sign in to continue.');
    }
    if (password.isEmpty) {
      throw const LoginException('Enter your password to delete account.');
    }
    final authEmail = user.email ?? profile.email;
    if (authEmail.isEmpty) {
      throw const LoginException(
        'This account cannot be deleted here. Please contact support.',
      );
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: authEmail,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'user-mismatch') {
        throw const LoginException('Invalid login details or password.');
      }
      throw LoginException(e.message ?? 'Re-authentication failed.');
    }

    final batch = _firestore.batch();
    final uid = user.uid;
    final phoneKey = _phoneLookupKey(profile.phone);
    if (phoneKey.isNotEmpty) {
      batch.delete(_firestore.collection('phone_logins').doc(phoneKey));
    }
    final authPhoneMatch =
        RegExp(r'^phone-(\d+)@phone\.carrygo\.local$').firstMatch(authEmail);
    if (authPhoneMatch != null) {
      batch.delete(
        _firestore.collection('phone_logins').doc(authPhoneMatch.group(1)!),
      );
    }
    batch.delete(_firestore.collection('users').doc(uid));
    batch.delete(_firestore.collection('riders').doc(uid));
    batch.delete(_firestore.collection('public_riders').doc(uid));

    Future<void> deleteOwnedDocs(String collection) async {
      final snapshot = await _firestore
          .collection(collection)
          .where('userId', isEqualTo: uid)
          .limit(100)
          .get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
    }

    await deleteOwnedDocs('notifications');
    await deleteOwnedDocs('email_queue');
    await deleteOwnedDocs('sms_queue');
    await batch.commit();
    await user.delete();
    _user = null;
    _profile = null;
    _userRole = '';
    _isLoadingProfile = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
