import 'oauth_server.dart';

void main() async {
  print('🌟 File Cloud - Servidor OAuth de Exemplo');
  print('==========================================');
  
  final server = OAuthServer();
  await server.start();
}