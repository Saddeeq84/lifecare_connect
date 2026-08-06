/// App-wide constants
class AppConstants {
  // App Info
  static const String appName = 'LifeCare Connect';
  static const String appVersion = '1.0.43';

  // API Constants
  static const String baseUrl = 'https://api.lifecare.com';
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Storage Keys
  static const String userTokenKey = 'user_token';
  static const String userDataKey = 'user_data';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String facilitiesCollection = 'facilities';
  static const String appointmentsCollection = 'appointments';
  static const String healthRecordsCollection = 'health_records';
  static const String trainingMaterialsCollection = 'training_materials';

  // User Roles
  static const String adminRole = 'admin';
  static const String doctorRole = 'doctor';
  static const String chwRole = 'chw';
  static const String patientRole = 'patient';
  static const String facilityRole = 'facility';

  // Validation
  static const int minPasswordLength = 8;
  static const int maxNameLength = 50;
  static const int maxEmailLength = 100;

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double iconSize = 24.0;
}
