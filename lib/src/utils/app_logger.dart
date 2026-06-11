import 'dart:developer' as developer;
import 'dart:io';

/// Sistema de logging para debug e monitoramento
/// Segue as melhores práticas do Dart usando dart:developer
class AppLogger {
  static const String _tag = 'FileCloud';

  static bool _debugMode = true;

  /// Whether to show full stack traces (can be verbose)
  static bool showFullStackTraces = false;

  /// Maximum lines of stack trace to show when not showing full traces
  static int maxStackTraceLines = 10;

  /// Habilita modo debug (mostra logs no terminal além do DevTools)
  static void enableDebugMode() {
    _debugMode = true;
  }

  /// Desabilita modo debug (apenas DevTools)
  static void disableDebugMode() {
    _debugMode = false;
  }

  /// Formats a stack trace for display
  static String _formatStackTrace(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');
    if (showFullStackTraces || lines.length <= maxStackTraceLines) {
      return stackTrace.toString();
    }
    return '${lines.take(maxStackTraceLines).join('\n')}\n   ... (${lines.length - maxStackTraceLines} more lines)';
  }

  /// Log de informação
  static void info(String message, {String? component}) {
    final logMessage = component != null ? '[$component] $message' : message;
    developer.log(logMessage, name: _tag, level: 800);
    if (_debugMode) {
      stdout.writeln('🔵 $_tag: $logMessage');
    }
  }

  /// Log de erro with automatic stack trace capture
  static void error(
    String message, {
    String? component,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Auto-capture stack trace if not provided and there's an error
    final effectiveStackTrace = stackTrace ?? (error != null ? StackTrace.current : null);

    final logMessage = component != null ? '[$component] $message' : message;
    developer.log(
      logMessage,
      name: _tag,
      level: 1000,
      error: error,
      stackTrace: effectiveStackTrace,
    );
    if (_debugMode) {
      stderr.writeln('');
      stderr.writeln('╔══════════════════════════════════════════════════════════════');
      stderr.writeln('║ 🔴 $_tag ERROR ${component != null ? '[$component]' : ''}');
      stderr.writeln('╠══════════════════════════════════════════════════════════════');
      stderr.writeln('║ Message: $message');
      if (error != null) {
        stderr.writeln('║ Error Type: ${error.runtimeType}');
        stderr.writeln('║ Error: $error');
      }
      if (effectiveStackTrace != null) {
        stderr.writeln('╠──────────────────────────────────────────────────────────────');
        stderr.writeln('║ Stack Trace:');
        for (final line in _formatStackTrace(effectiveStackTrace).split('\n')) {
          stderr.writeln('║   $line');
        }
      }
      stderr.writeln('╚══════════════════════════════════════════════════════════════');
      stderr.writeln('');
    }
  }

  /// Log an exception with full context - convenience method for catch blocks
  static void exception(
    String context,
    Object error,
    StackTrace stackTrace, {
    String? component,
    Map<String, dynamic>? additionalData,
  }) {
    final logMessage = component != null ? '[$component] $context' : context;
    developer.log(
      logMessage,
      name: _tag,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
    if (_debugMode) {
      stderr.writeln('');
      stderr.writeln('╔══════════════════════════════════════════════════════════════');
      stderr.writeln('║ 🔴 $_tag EXCEPTION ${component != null ? '[$component]' : ''}');
      stderr.writeln('╠══════════════════════════════════════════════════════════════');
      stderr.writeln('║ Context: $context');
      stderr.writeln('║ Error Type: ${error.runtimeType}');
      stderr.writeln('║ Error: $error');
      if (additionalData != null && additionalData.isNotEmpty) {
        stderr.writeln('╠──────────────────────────────────────────────────────────────');
        stderr.writeln('║ Additional Data:');
        for (final entry in additionalData.entries) {
          stderr.writeln('║   ${entry.key}: ${entry.value}');
        }
      }
      stderr.writeln('╠──────────────────────────────────────────────────────────────');
      stderr.writeln('║ Stack Trace:');
      for (final line in _formatStackTrace(stackTrace).split('\n')) {
        stderr.writeln('║   $line');
      }
      stderr.writeln('╚══════════════════════════════════════════════════════════════');
      stderr.writeln('');
    }
  }

  /// Log de warning
  static void warning(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    final logMessage = component != null ? '[$component] $message' : message;
    developer.log(logMessage, name: _tag, level: 900, error: error, stackTrace: stackTrace);
    if (_debugMode) {
      stdout.writeln('🟡 $_tag: $logMessage');
      if (error != null) stdout.writeln('   Warning details: $error');
    }
  }

  /// Log de debug
  static void debug(String message, {String? component}) {
    final logMessage = component != null ? '[$component] $message' : message;
    developer.log(logMessage, name: _tag, level: 700);
    if (_debugMode) {
      stdout.writeln('🟢 $_tag: $logMessage');
    }
  }

  /// Log de sucesso
  static void success(String message, {String? component}) {
    final logMessage = component != null ? '[$component] $message' : message;
    developer.log(logMessage, name: _tag, level: 800);
    if (_debugMode) {
      stdout.writeln('✅ $_tag: $logMessage');
    }
  }

  /// Log de operação OAuth
  static void oauth(String message, {Map<String, dynamic>? data}) {
    info('OAuth: $message', component: 'OAuth');
    if (data != null && _debugMode) {
      data.forEach((key, value) {
        // Mascarar tokens sensíveis
        if (key.toLowerCase().contains('token') && value is String && value.length > 10) {
          value = '${value.substring(0, 10)}...';
        }
        stdout.writeln('   $key: $value');
      });
    }
  }

  /// Log de operação de arquivos
  static void fileOperation(
    String operation,
    String fileName, {
    String? result,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (error != null) {
      AppLogger.error(
        'File $operation failed: $fileName',
        component: 'FileOps',
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      AppLogger.success('File $operation: $fileName ${result ?? ''}', component: 'FileOps');
    }
  }

  /// Log de inicialização do sistema
  static void systemInit(String message) {
    info('System Init: $message', component: 'System');
  }
}