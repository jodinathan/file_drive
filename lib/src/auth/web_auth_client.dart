/// Web authentication client interface for OAuth flows
library;

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

/// Interface for web authentication clients
abstract class WebAuthClient {
  /// Authenticate with the given URL and callback scheme
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
  });
}

/// FlutterWebAuth2 implementation of WebAuthClient
class FlutterWebAuthClient implements WebAuthClient {
  const FlutterWebAuthClient();

  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
  }) async {
    final result = await FlutterWebAuth2.authenticate(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
    );
    return result;
  }
}