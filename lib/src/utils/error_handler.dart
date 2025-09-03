import 'package:flutter/material.dart';
import 'app_logger.dart';
import '../providers/base_cloud_provider.dart';

/// Unified error handling system for consistent error reporting
class ErrorHandler {
  /// Handle error with unified logging, console output, and user feedback
  /// 
  /// [context] - BuildContext for showing SnackBar (optional)
  /// [error] - The error object
  /// [operation] - Description of what operation failed (e.g., "delete file", "add account")
  /// [component] - Component name for AppLogger (e.g., "FileOps", "Auth")
  /// [showToast] - Whether to show SnackBar to user (default: true)
  /// [toastDuration] - Duration for SnackBar (default: 5 seconds)
  /// [additionalData] - Extra debug information to print
  static void handleError({
    BuildContext? context,
    required Object error,
    required String operation,
    String component = 'General',
    bool showToast = true,
    Duration toastDuration = const Duration(seconds: 5),
    Map<String, dynamic>? additionalData,
  }) {
    // 1. Print detailed error to console (always)
    print('🚨 ERROR IN $operation');
    print('Component: $component');
    print('Error: $error');
    print('Error type: ${error.runtimeType}');
    
    if (error is CloudProviderException) {
      print('Status code: ${error.statusCode}');
      print('Error message: ${error.message}');
    }
    
    if (additionalData != null) {
      print('Additional data:');
      additionalData.forEach((key, value) {
        print('  $key: $value');
      });
    }
    print('---');

    // 2. Log with AppLogger
    AppLogger.error(
      'Error in $operation: $error',
      component: component,
      error: error,
    );

    // 3. Show user-friendly toast (if context provided and enabled)
    if (context != null && showToast && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro em $operation: $error'),
          duration: toastDuration,
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Simplified wrapper for common file operations
  static void handleFileError({
    BuildContext? context,
    required Object error,
    required String fileName,
    required String operation, // "delete", "upload", "download", etc.
    Map<String, dynamic>? additionalData,
  }) {
    final data = {
      'fileName': fileName,
      ...?additionalData,
    };
    
    handleError(
      context: context,
      error: error,
      operation: '$operation $fileName',
      component: 'FileOps',
      additionalData: data,
    );
  }

  /// Simplified wrapper for authentication operations
  static void handleAuthError({
    BuildContext? context,
    required Object error,
    required String operation, // "add account", "authenticate", "refresh token", etc.
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
      operation: operation,
      component: 'Auth',
      additionalData: data,
    );
  }

  /// Execute operation with unified error handling
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
    } catch (error) {
      handleError(
        context: context,
        error: error,
        operation: operationName,
        component: component,
        additionalData: additionalData,
        showToast: showToast,
      );
      return null;
    }
  }
}

