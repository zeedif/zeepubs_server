import 'dart:async';

import 'package:grpc/grpc.dart';

import '/common/di/service_locator.dart';
import '/common/utils/ip_utils.dart';

import '../security/rate_limit_registry.dart';

/// Define qué métodos pertenecen a la política estricta de autenticación.
const _authMethods = [
  '/zeepubs.auth.AuthService/SignIn',
  '/zeepubs.auth.AuthService/StartEmailOtpSignIn',
  '/zeepubs.auth.AuthService/StartPasswordReset',
  '/zeepubs.auth.AuthService/GenerateFido2AuthenticationChallenge',
];

FutureOr<GrpcError?> rateLimitInterceptor(ServiceCall call, ServiceMethod method) {
  final registry = locator<RateLimitRegistry>();

  // 1. Intentar extraer IP de los headers (Proxy)
  final rawIp = call.clientMetadata?['x-forwarded-for'] ?? call.clientMetadata?['x-real-ip'];
  String? clientIp = IpUtils.normalizeIp(rawIp);

  // NOTA: En gRPC Dart, obtener la IP del socket es complejo si no pasas un custom handler.
  // Pero si estás detrás de un reverse proxy en producción, los headers NUNCA deberían fallar.
  final isAuthMethod = _authMethods.contains(method.name);

  if (clientIp == null) {
    if (isAuthMethod) {
      // Por SEGURIDAD: Si es un método de Auth y no podemos rastrear la IP, rechazamos la petición.
      // De lo contrario, un atacante sin IP podría evadir el ban y atacar infinitamente.
      return GrpcError.failedPrecondition('Client IP address could not be determined for security tracking.');
    }
    // Fallback seguro para la API global
    clientIp = 'internal_network';
  }

  // 2. Determinar política a aplicar
  final policy = isAuthMethod ? RateLimitPolicy.authentication : RateLimitPolicy.apiGlobal;
  final limiter = registry.getLimiter(policy);

  // La clave (key) será una combinación de la Política y la IP
  final key = '${policy.name}_$clientIp';

  if (!limiter.tryAcquire(key)) {
    // Si la tasa es excedida, retornamos RESOURCE_EXHAUSTED (equivalente a 429)
    return GrpcError.resourceExhausted(
      'Too Many Requests. Rate limit exceeded for ${isAuthMethod ? 'authentication' : 'API'}.'
    );
  }

  return null; // Bien, continuar con el siguiente interceptor
}
