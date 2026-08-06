// lib/models/user_model.dart
class UserProfile {
  final String id;
  final String name;
  final String role; // 'Doctor', 'Patient', or 'CHW'

  UserProfile({required this.id, required this.name, required this.role});
}
