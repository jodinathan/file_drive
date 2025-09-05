import 'dart:developer' as developer;
import 'dart:io';

/// Sistema de logging para debug e monitoramento
/// Segue as melhores práticas do Dart usando dart:developer
class AppLogger {
  static const String _tag = 'FileCloud';
  
  static bool _debugMode = true;
  
  /// Habilita modo debug (mostra logs no terminal além do DevTools)
  static void enableDebugMode() {
    _debugMode = true;
  }
  
  /// Desabilita modo debug (apenas DevTools)
  static void disableDebugMode() {
    _debugMode = false;
  }
  
  /// Log de informação
  static void info(String message, {String? component}) {
    final logMessage = component != null ? '[$component] $message' : message;
    developer.log(logMessage, name: _tag, level: 800);
    if (_debugMode) {
      stdout.writeln('🔵 $_tag: $logMessage');
    }
  }
  
  /// Log de erro
  static void error(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    final logMessage = component != null ? '[$component] $message' : message;
    developer.log(
      logMessage, 
      name: _tag, 
      level: 1000, 
      error: error, 
      stackTrace: stackTrace,
    );
    if (_debugMode) {
      stderr.writeln('🔴 $_tag: $logMessage');
      if (error != null) stderr.writeln('   Error: $error');
      if (stackTrace != null) stderr.writeln('   StackTrace: $stackTrace');
    }
  }
  
  /// Log de warning
  static void warning(String message, {String? component}) {
    final logMessage = component != null ? '[$component] $message' : message;
    developer.log(logMessage, name: _tag, level: 900);
    if (_debugMode) {
      stdout.writeln('🟡 $_tag: $logMessage');
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
  static void fileOperation(String operation, String fileName, {String? result, Object? error}) {
    if (error != null) {
      AppLogger.error('File $operation failed: $fileName', component: 'FileOps', error: error);
    } else {
      AppLogger.success('File $operation: $fileName ${result ?? ''}', component: 'FileOps');
    }
  }
  
  /// Log de inicialização do sistema
  static void systemInit(String message) {
    info('System Init: $message', component: 'System');
  }
}