import 'dart:developer' as developer;

/// Sistema de logging para debug e monitoramento
class AppLogger {
  static const String _tag = 'FileCloud';
  
  /// Log de informação
  static void info(String message, {String? component}) {
    final logMessage = component != null ? '[$component] $message' : message;
    developer.log(logMessage, name: _tag, level: 800);
    print('🔵 $_tag: $logMessage');
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
    print('🔴 $_tag: $logMessage');
    if (error != null) print('   Error: $error');
    if (stackTrace != null) print('   StackTrace: $stackTrace');
  }
  
  /// Log de warning
  static void warning(String message, {String? component}) {
    final logMessage = component != null ? '[$component] $message' : message;
    developer.log(logMessage, name: _tag, level: 900);
    print('🟡 $_tag: $logMessage');
  }
  
  /// Log de debug
  static void debug(String message, {String? component}) {
    final logMessage = component != null ? '[$component] $message' : message;
    developer.log(logMessage, name: _tag, level: 700);
    print('🟢 $_tag: $logMessage');
  }
  
  /// Log de sucesso
  static void success(String message, {String? component}) {
    final logMessage = component != null ? '[$component] $message' : message;
    developer.log(logMessage, name: _tag, level: 800);
    print('✅ $_tag: $logMessage');
  }
  
  /// Log de operação OAuth
  static void oauth(String message, {Map<String, dynamic>? data}) {
    info('OAuth: $message', component: 'OAuth');
    if (data != null) {
      data.forEach((key, value) {
        // Mascarar tokens sensíveis
        if (key.toLowerCase().contains('token') && value is String && value.length > 10) {
          value = '${value.substring(0, 10)}...';
        }
        print('   $key: $value');
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