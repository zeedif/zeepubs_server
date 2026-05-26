import 'rate_limiter.dart';

enum RateLimitPolicy {
  /// Límite estricto para peticiones de autenticación (Ej. 5 por minuto por IP)
  authentication,
  
  /// Límite global estándar para llamadas API generales (Ej. 100 por minuto por IP)
  apiGlobal,
  
  /// Límite interno usado para evitar sobreescribir la BD (como ActiveUserTracker)
  internalActivityTracker,
}

class RateLimitRegistry {
  // 1. Política de Autenticación (Prevenir Fuerza Bruta antes de tocar la DB)
  // 5 intentos cada 1 minuto
  final RateLimiter _authenticationLimiter = RateLimiter(
    maxRequests: 5,
    duration: const Duration(minutes: 1),
    refillBetween: false,
  );

  // 2. Política Global API gRPC/REST
  // 150 peticiones por minuto
  final RateLimiter _apiGlobalLimiter = RateLimiter(
    maxRequests: 150,
    duration: const Duration(minutes: 1),
    refillBetween: true,
  );

  // 3. Política Interna de ActiveUserTracker
  // 1 petición aceptada cada 5 minutos por Usuario.
  final RateLimiter _internalActivityTrackerLimiter = RateLimiter(
    maxRequests: 1,
    duration: const Duration(minutes: 5),
    refillBetween: false,
  );

  /// Retorna el limitador correspondiente al enum.
  RateLimiter getLimiter(RateLimitPolicy policy) => switch (policy) {
    RateLimitPolicy.authentication => _authenticationLimiter,
    RateLimitPolicy.apiGlobal => _apiGlobalLimiter,
    RateLimitPolicy.internalActivityTracker => _internalActivityTrackerLimiter,
  };
}
