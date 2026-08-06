class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final String phoneNormalized;
  final String role;
  final String city;
  final String riderStatus;
  final String profilePhotoUrl;
  final String idCardUrl;
  final String bikePlateNumber;
  final String bikeModel;
  final String bikeColor;
  final String riderLicenseUrl;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountName;
  final List<String> documentUrls;
  final String accountStatus;
  final String suspensionReason;
  final bool isApproved;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    this.phoneNormalized = '',
    required this.role,
    required this.city,
    this.riderStatus = 'not_applicable',
    this.profilePhotoUrl = '',
    this.idCardUrl = '',
    this.bikePlateNumber = '',
    this.bikeModel = '',
    this.bikeColor = '',
    this.riderLicenseUrl = '',
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankAccountName = '',
    this.documentUrls = const [],
    this.accountStatus = 'active',
    this.suspensionReason = '',
    this.isApproved = false,
  });

  factory AppUser.fromMap(String id, Map<String, dynamic> data) {
    final role = data['role'] as String? ?? '';
    final approved = (data['isApproved'] as bool?) ??
        (data['riderStatus'] == 'approved' ||
            role == 'customer' ||
            role == 'admin');
    return AppUser(
      id: id,
      email: data['email'] as String? ?? '',
      fullName: data['fullName'] as String? ?? data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      phoneNormalized: data['phoneNormalized'] as String? ?? '',
      role: role,
      city: data['city'] as String? ?? 'Lagos',
      riderStatus: data['riderStatus'] as String? ??
          (role == 'rider'
              ? (approved ? 'approved' : 'pending')
              : 'not_applicable'),
      profilePhotoUrl: data['profilePhotoUrl'] as String? ?? '',
      idCardUrl: data['idCardUrl'] as String? ?? '',
      bikePlateNumber: data['bikePlateNumber'] as String? ??
          data['bikeNumber'] as String? ??
          '',
      bikeModel: data['bikeModel'] as String? ?? '',
      bikeColor: data['bikeColor'] as String? ?? '',
      riderLicenseUrl: data['riderLicenseUrl'] as String? ?? '',
      bankName: data['bankName'] as String? ?? '',
      bankAccountNumber: data['bankAccountNumber'] as String? ?? '',
      bankAccountName: data['bankAccountName'] as String? ?? '',
      documentUrls:
          List<String>.from(data['documentUrls'] as List? ?? const []),
      accountStatus: data['accountStatus'] as String? ?? 'active',
      suspensionReason: data['suspensionReason'] as String? ?? '',
      isApproved: approved,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': fullName,
      'fullName': fullName,
      'phone': phone,
      'phoneNormalized': phoneNormalized,
      'role': role,
      'isApproved': isApproved || role != 'rider' || riderStatus == 'approved',
      'city': city,
      'riderStatus': riderStatus,
      'profilePhotoUrl': profilePhotoUrl,
      'idCardUrl': idCardUrl,
      'bikeNumber': bikePlateNumber,
      'bikePlateNumber': bikePlateNumber,
      'bikeModel': bikeModel,
      'bikeColor': bikeColor,
      'riderLicenseUrl': riderLicenseUrl,
      'bankName': bankName,
      'bankAccountNumber': bankAccountNumber,
      'bankAccountName': bankAccountName,
      'documentUrls': documentUrls,
      'accountStatus': accountStatus,
      'suspensionReason': suspensionReason,
    };
  }
}
