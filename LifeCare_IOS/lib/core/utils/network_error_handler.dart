// Network Error Handler Utility
// Provides user-friendly error messages and network error detection

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

class NetworkErrorHandler {
  /// Check if an error is network-related
  static bool isNetworkError(dynamic error) {
    if (error == null) return false;

    final errorString = error.toString().toLowerCase();

    // Common network error patterns
    return errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('socket') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('no internet') ||
        errorString.contains('unreachable') ||
        errorString.contains('offline');
  }

  /// Get user-friendly error message
  static String getUserFriendlyMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred';

    // Network errors
    if (isNetworkError(error)) {
      return 'Poor internet connection. Please check your network and try again.';
    }

    // Firebase errors
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to perform this action.';
        case 'not-found':
          return 'The requested data was not found.';
        case 'already-exists':
          return 'This item already exists.';
        case 'resource-exhausted':
          return 'Too many requests. Please try again later.';
        case 'failed-precondition':
          return 'Operation cannot be performed at this time.';
        case 'aborted':
          return 'Operation was cancelled. Please try again.';
        case 'out-of-range':
          return 'Invalid data range.';
        case 'unimplemented':
          return 'This feature is not yet implemented.';
        case 'internal':
          return 'Internal server error. Please try again.';
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again.';
        case 'data-loss':
          return 'Data may be lost. Please contact support.';
        case 'unauthenticated':
          return 'Please sign in to continue.';
        default:
          return error.message ?? 'An error occurred. Please try again.';
      }
    }

    // Generic error message
    final errorString = error.toString();
    if (errorString.length > 100) {
      return 'An error occurred. Please try again.';
    }

    return errorString;
  }

  /// Show error snackbar with network-aware messaging
  static void showErrorSnackbar(
    BuildContext context,
    dynamic error, {
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    final message = getUserFriendlyMessage(error);
    final isNetwork = isNetworkError(error);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isNetwork ? Icons.wifi_off : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: isNetwork
            ? Colors.orange.shade700
            : Colors.red.shade700,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Execute an async operation with network error handling
  static Future<T?> executeWithNetworkHandling<T>(
    BuildContext context,
    Future<T> Function() operation, {
    String? loadingMessage,
    String? successMessage,
    bool showLoadingIndicator = false,
  }) async {
    BuildContext? dialogContext;

    try {
      // Show loading indicator if requested
      if (showLoadingIndicator && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            dialogContext = ctx;
            return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                content: Row(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 20),
                    Expanded(child: Text(loadingMessage ?? 'Processing...')),
                  ],
                ),
              ),
            );
          },
        );
      }

      // Execute operation
      final result = await operation();

      // Close loading indicator
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }

      // Show success message if provided
      if (successMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    successMessage,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return result;
    } catch (error) {
      // Close loading indicator
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }

      // Show error message
      if (context.mounted) {
        showErrorSnackbar(context, error);
      }

      return null;
    }
  }
}
