import 'package:flutter/material.dart';
import 'app_logger.dart';
import '../providers/base_cloud_provider.dart';

/// Unified error handling system for consistent error reporting
class ErrorHandler {
  /// Handle error with unified logging, console output, and user feedback
  ///
  /// [context] - BuildContext for showing SnackBar (optional)
  /// [error] - The error object
  /// [stackTrace] - Stack trace from catch block (should always be provided)
  /// [operation] - Description of what operation failed (e.g., "delete file", "add account")
  /// [component] - Component name for AppLogger (e.g., "FileOps", "Auth")
  /// [showToast] - Whether to show SnackBar to user (default: true)
  /// [toastDuration] - Duration for SnackBar (default: 5 seconds)
  /// [additionalData] - Extra debug information to print
  static void handleError({
    BuildContext? context,
    required Object error,
    StackTrace? stackTrace,
    required String operation,
    String component = 'General',
    bool showToast = true,
    Duration toastDuration = const Duration(seconds: 5),
    Map<String, dynamic>? additionalData,
  }) {
    // Build additional data with CloudProviderException details if applicable
    final enhancedData = <String, dynamic>{
      ...?additionalData,
      if (error is CloudProviderException) ...{
        'statusCode': error.statusCode,
        'errorMessage': error.message,
      },
    };

    // Log with AppLogger using the new exception method
    AppLogger.exception(
      'Error in $operation',
      error,
      stackTrace ?? StackTrace.current,
      component: component,
      additionalData: enhancedData.isNotEmpty ? enhancedData : null,
    );

    // Show user-friendly toast (if context provided and enabled)
    if (context != null && showToast && context.mounted) {
      final userMessage = _getUserFriendlyMessage(error, operation);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessage),
          duration: toastDuration,
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Gets a user-friendly error message
  static String _getUserFriendlyMessage(Object error, String operation) {
    if (error is CloudProviderException) {
      return 'Erro em $operation: ${error.message}';
    }
    return 'Erro em $operation: $error';
  }

  /// Simplified wrapper for common file operations
  static void handleFileError({
    BuildContext? context,
    required Object error,
    StackTrace? stackTrace,
    required String fileName,
    required String operation,
    Map<String, dynamic>? additionalData,
  }) {
    final data = {
      'fileName': fileName,
      ...?additionalData,
    };

    handleError(
      context: context,
      error: error,
      stackTrace: stackTrace,
      operation: '$operation $fileName',
      component: 'FileOps',
      additionalData: data,
    );
  }

  /// Simplified wrapper for authentication operations
  static void handleAuthError({
    BuildContext? context,
    required Object error,
    StackTrace? stackTrace,
    required String operation,
    String? provider,
    Map<String, dynamic>? additionalData,
  }) {
    final data = {
      if (provider != null) 'provider': provider,
      ...?additionalData,
    };

    handleError(
      context: context,
      error: error,
      stackTrace: stackTrace,
      operation: operation,
      component: 'Auth',
      additionalData: data,
    );
  }

  /// Execute operation with unified error handling
  ///
  /// This method automatically captures and logs stack traces from exceptions.
  static Future<T?> execute<T>({
    required Future<T> Function() operation,
    required String operationName,
    BuildContext? context,
    String component = 'General',
    Map<String, dynamic>? additionalData,
    bool showToast = true,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      handleError(
        context: context,
        error: error,
        stackTrace: stackTrace,
        operation: operationName,
        component: component,
        additionalData: additionalData,
        showToast: showToast,
      );
      return null;
    }
  }

  /// Execute synchronous operation with unified error handling
  static T? executeSync<T>({
    required T Function() operation,
    required String operationName,
    BuildContext? context,
    String component = 'General',
    Map<String, dynamic>? additionalData,
    bool showToast = true,
  }) {
    try {
      return operation();
    } catch (error, stackTrace) {
      handleError(
        context: context,
        error: error,
        stackTrace: stackTrace,
        operation: operationName,
        component: component,
        additionalData: additionalData,
        showToast: showToast,
      );
      return null;
    }
  }
}

