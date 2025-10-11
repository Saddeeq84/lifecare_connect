import 'package:intl/intl.dart';

/// Utility functions for data formatting and validation
class DataHelpers {
  /// Format date for display
  static String formatDate(DateTime date, {String pattern = 'MMM dd, yyyy'}) {
    return DateFormat(pattern).format(date);
  }

  /// Format time for display
  static String formatTime(DateTime time, {String pattern = 'HH:mm'}) {
    return DateFormat(pattern).format(time);
  }

  /// Format datetime for display
  static String formatDateTime(
    DateTime dateTime, {
    String pattern = 'MMM dd, yyyy HH:mm',
  }) {
    return DateFormat(pattern).format(dateTime);
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate phone number (basic validation)
  static bool isValidPhoneNumber(String phone) {
    return RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(phone);
  }

  /// Validate password strength
  static bool isValidPassword(String password) {
    // At least 8 characters, contains uppercase, lowercase, number
    return RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d@$!%*?&]{8,}$',
    ).hasMatch(password);
  }

  /// Capitalize first letter of each word
  static String capitalizeWords(String text) {
    return text
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? word[0].toUpperCase() + word.substring(1).toLowerCase()
              : word,
        )
        .join(' ');
  }

  /// Truncate text with ellipsis
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Calculate age from date of birth
  static int calculateAge(DateTime dateOfBirth) {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  /// Format file size
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (bytes.bitLength - 1) ~/ 10;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Generate random ID
  static String generateId({int length = 8}) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (index) =>
          chars[(DateTime.now().millisecondsSinceEpoch + index) % chars.length],
    ).join();
  }

  /// Clean phone number (remove non-digits)
  static String cleanPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }

  /// Check if string is empty or null
  static bool isEmpty(String? text) {
    return text == null || text.trim().isEmpty;
  }

  /// Get initials from name
  static String getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.isEmpty) return '';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[words.length - 1][0]}'.toUpperCase();
  }
}
