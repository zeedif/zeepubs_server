import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '/common/di/service_locator.dart';
import '/common/mediator/mediator.dart';
import '/src/generated/auth.pb.dart';

import '../data/services/oidc_handler.dart';
import '../core/use_cases/oidc/sign_in_with_oidc.dart';

class OidcController {
  Router get router {
    final router = Router();
    router.get('/callback', _callbackHandler);
    return router;
  }

  Future<Response> _callbackHandler(Request request) async {
    try {
      if (!locator.isRegistered<OidcHandler>()) {
        throw Exception('OIDC no está configurado en el servidor.');
      }

      final queryParams = request.url.queryParameters;
      final oidcHandler = locator<OidcHandler>();

      final result = await oidcHandler.processCallback(queryParams);
      final credential = result.credential;
      final strategyName = result.authStrategy;

      final claims = credential.idToken.claims;
      final issuer = claims['iss'] as String?;
      if (issuer == null) throw Exception('Token OIDC sin issuer.');

      final userInfo = await credential.getUserInfo();

      final strategyEnum = AuthStrategy.values.firstWhere(
        (e) => e.name == strategyName.toUpperCase(),
        orElse: () => AuthStrategy.JWT,
      );

      final command = SignInWithOidcCommand(
        issuer: issuer,
        subject: userInfo.subject,
        email: userInfo.email,
        nickname: userInfo.givenName ?? userInfo.name,
        avatarUrl: userInfo.picture?.toString(),
        strategy: strategyEnum,
      );

      final authSuccess = await locator<Mediator>().send(command);

      final redirectUrl = Uri(
        scheme: 'zeepubs-app',
        host: 'auth',
        path: 'success',
        queryParameters: {
          'token': authSuccess.token,
          if (authSuccess.refreshToken.isNotEmpty)
            'refreshToken': authSuccess.refreshToken,
        },
      );

      return Response.found(redirectUrl.toString());
    } catch (e, stackTrace) {
      print('Error OIDC: $e\n$stackTrace');
      return Response.found('zeepubs-app://auth/error?message=${Uri.encodeComponent(e.toString())}');
    }
  }
}
