import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Comprehensive error handling service for production-ready error management
class ErrorHandler {
  static const String _tag = 'ErrorHandler';

  /// Handle and report errors with user-friendly messages
  static void handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    bool showToUser = true,
    BuildContext? buildContext,
  }) {
    // Log error for debugging
    _logError(error, stackTrace, context);

    // Show user-friendly message if context provided
    if (showToUser && buildContext != null) {
      _showUserFriendlyError(buildContext, error, context);
    }
  }

  /// Log error with detailed information
  static void _logError(
    dynamic error,
    StackTrace? stackTrace,
    String? context,
  ) {
    final timestamp = DateTime.now().toIso8601String();
    final contextStr = context != null ? ' [Context: $context]' : '';

    if (kDebugMode) {
      print('🚨 [$_tag] $timestamp$contextStr');
      print('Error: $error');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
      print('--- End Error ---');
    }

    // In production, you would send this to a logging service
    // For now, we'll store it locally for review
    _storeErrorLocally(error, stackTrace, context, timestamp);
  }

  /// Store error locally for later review
  static void _storeErrorLocally(
    dynamic error,
    StackTrace? stackTrace,
    String? context,
    String timestamp,
  ) {
    // This could be enhanced to store in SharedPreferences or local database
    // For production, consider implementing a local error queue that syncs when online
  }

  /// Show user-friendly error message
  static void _showUserFriendlyError(
    BuildContext context,
    dynamic error,
    String? errorContext,
  ) {
    final message = _getUserFriendlyMessage(error, errorContext);

    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
    }
  }

  /// Convert technical errors to user-friendly messages
  static String _getUserFriendlyMessage(dynamic error, String? context) {
    final errorStr = error.toString().toLowerCase();

    // Network errors
    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Network connection issue. Please check your internet and try again.';
    }

    // Permission errors
    if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return 'Permission required. Please check your app permissions in settings.';
    }

    // Authentication errors
    if (errorStr.contains('auth') || errorStr.contains('unauthorized')) {
      return 'Authentication issue. Please sign in again.';
    }

    // Firestore errors
    if (errorStr.contains('firestore') ||
        errorStr.contains('cloud-firestore')) {
      return 'Database connection issue. Please try again in a moment.';
    }

    // Firebase errors
    if (errorStr.contains('firebase')) {
      return 'Service temporarily unavailable. Please try again later.';
    }

    // File/Storage errors
    if (errorStr.contains('file') || errorStr.contains('storage')) {
      return 'File operation failed. Please check available storage space.';
    }

    // Validation errors
    if (errorStr.contains('invalid') || errorStr.contains('validation')) {
      return 'Invalid input provided. Please check your information and try again.';
    }

    // Context-specific messages
    if (context != null) {
      final contextStr = context.toLowerCase();
      if (contextStr.contains('login') || contextStr.contains('signin')) {
        return 'Sign in failed. Please check your credentials and try again.';
      }
      if (contextStr.contains('upload')) {
        return 'Upload failed. Please check your file and internet connection.';
      }
      if (contextStr.contains('save') || contextStr.contains('update')) {
        return 'Save operation failed. Please try again.';
      }
      if (contextStr.contains('load') || contextStr.contains('fetch')) {
        return 'Failed to load data. Please refresh and try again.';
      }
    }

    // Default message
    return 'An unexpected error occurred. Please try again or contact support if the problem persists.';
  }

  /// Handle specific Firebase errors with detailed messages
  static String getFirebaseErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered. Please use a different email or sign in.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'permission-denied':
        return 'Access denied. You don\'t have permission for this action.';
      case 'quota-exceeded':
        return 'Service quota exceeded. Please try again later.';
      case 'unauthenticated':
        return 'Please sign in to continue.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  /// Show loading indicator with error handling
  static Widget buildErrorWidget({
    required String message,
    VoidCallback? onRetry,
    IconData? icon,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon ?? Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ],
      ),
    );
  }

  /// Wrapper for async operations with error handling
  static Future<T?> safeAsyncCall<T>(
    Future<T> Function() operation, {
    required BuildContext context,
    required String operationName,
    bool showErrorToUser = true,
    T? fallbackValue,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      handleError(
        error,
        stackTrace: stackTrace,
        context: operationName,
        showToUser: showErrorToUser,
        buildContext: context,
      );
      return fallbackValue;
    }
  }

  /// Validate input and show user-friendly validation errors
  static String? validateInput(
    String? value, {
    required String fieldName,
    bool required = true,
    int? minLength,
    int? maxLength,
    String? pattern,
    bool isEmail = false,
    bool isPhone = false,
  }) {
    // Required check
    if (required && (value == null || value.trim().isEmpty)) {
      return '$fieldName is required';
    }

    if (value == null || value.trim().isEmpty) {
      return null; // Optional field that's empty
    }

    final trimmedValue = value.trim();

    // Length checks
    if (minLength != null && trimmedValue.length < minLength) {
      return '$fieldName must be at least $minLength characters long';
    }

    if (maxLength != null && trimmedValue.length > maxLength) {
      return '$fieldName must not exceed $maxLength characters';
    }

    // Email validation
    if (isEmail) {
      final emailRegex = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      );
      if (!emailRegex.hasMatch(trimmedValue)) {
        return 'Please enter a valid email address';
      }
    }

    // Phone validation
    if (isPhone) {
      final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
      if (!phoneRegex.hasMatch(
        trimmedValue.replaceAll(RegExp(r'[\s\-\(\)]'), ''),
      )) {
        return 'Please enter a valid phone number';
      }
    }

    // Custom pattern validation
    if (pattern != null) {
      final regex = RegExp(pattern);
      if (!regex.hasMatch(trimmedValue)) {
        return '$fieldName format is invalid';
      }
    }

    return null; // Valid
  }

  /// Show success message
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: duration,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Show warning message
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_outlined, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          duration: duration,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
