import 'package:grpc/grpc.dart';
import 'package:uuid/uuid.dart';

import '/common/di/service_locator.dart';
import '/features/profile/data/services/active_user_tracker.dart';
import '/src/generated/auth.pb.dart';

import '../database/database.dart';
import '../session/app_caches.dart';
import '../session/app_session.dart';
import '../session/authentication_info.dart';
import '../session/log_level.dart';
import 'ip_utils.dart';

/// Expresión regular precompilada para extracción eficiente.
final RegExp _bearerExtractionRegex = RegExp(r'^Bearer\s+(.+)$', caseSensitive: false);

/// Envoltura para ejecutar código dentro de un ámbito de petición gRPC.
Future<T> withRequestScope<T>(ServiceCall call, Future<T> Function() computation) async {
  final scopeName = 'request_scope_${const Uuid().v4()}';
  locator.pushNewScope(scopeName: scopeName);

  try {
    // 1. Extraer token de autorización (si existe)
    final authHeader = call.clientMetadata?['authorization'];
    final token = authHeader != null
        ? _bearerExtractionRegex.firstMatch(authHeader)?.group(1)
        : null;

    // 2. Extraer datos inyectados por el interceptor
    final userIdString = call.clientMetadata?['user_id'];
    final scopesString = call.clientMetadata?['scopes'];
    final tokenIdString = call.clientMetadata?['token_id'];

    final authInfo = userIdString != null
        ? AuthenticationInfo(
            userId: UuidValue.fromString(userIdString),
            scopes: scopesString != null && scopesString.isNotEmpty
                ? scopesString
                    .split(',')
                    .map((idStr) => int.tryParse(idStr))
                    .whereType<int>()
                    .map((id) => Scope.valueOf(id))
                    .whereType<Scope>()
                    .toSet()
                : const <Scope>{},
            tokenId: tokenIdString != null ? UuidValue.fromString(tokenIdString) : null,
          )
        : null;

    // Extraer Idioma e IP
    final rawAcceptLanguage = call.clientMetadata?['accept-language'] ?? 'en';
    final locale = rawAcceptLanguage.split(',').first.split('-').first.toLowerCase().trim();
    final rawIp = call.clientMetadata?['x-forwarded-for'] ?? call.clientMetadata?['x-real-ip'];

    final session = AppSession(
      db: locator<AppDatabase>(),
      caches: locator<AppCaches>(),
      clientIp: IpUtils.normalizeIp(rawIp),
      userAgent: call.clientMetadata?['user-agent'],
      locale: locale,
      authenticationKey: token,
      authenticated: authInfo,
    );

    // 4. Registrar la sesión en GetIt
    locator.registerSingleton<AppSession>(session);

    session.log('Starting gRPC request scope', level: LogLevel.debug);

    // Rastrear actividad usando el RateLimiter interno
    if (authInfo != null && locator.isRegistered<ActiveUserTracker>()) {
      locator<ActiveUserTracker>().recordActive(authInfo.userId);
    }

    // 5. Ejecutar Mediator / Use Case
    return await computation();
  } catch (e, stackTrace) {
    // Si la operación falla, permitimos que la sesión registre el fallo
    if (locator.isRegistered<AppSession>()) {
      await locator<AppSession>().close(error: e, stackTrace: stackTrace);
    }
    rethrow;
  } finally {
    // 6. Destrucción segura del scope y flush de la sesión
    if (locator.isRegistered<AppSession>()) {
      await locator<AppSession>().close();
    }
    await locator.popScope();
  }
}
