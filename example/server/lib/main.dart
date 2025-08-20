import 'dart:developer' as developer;
import 'oauth_server.dart';

void main() async {
  developer.log('🌟 File Cloud - Servidor OAuth de Exemplo', name: 'FileCloudServer');
  developer.log('==========================================', name: 'FileCloudServer');
  
  final server = OAuthServer();
  await server.start();
}