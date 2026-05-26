import 'dart:io';

import 'package:shelf/shelf.dart';

import '/common/di/service_locator.dart';
import '/common/utils/ip_utils.dart';

import '../security/rate_limit_registry.dart';

/// Middleware de Shelf para proteger rutas REST y Webhooks
Middleware rateLimitMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final registry = locator<RateLimitRegistry>();
      final limiter = registry.getLimiter(RateLimitPolicy.apiGlobal);

      // 1. Intentar obtener IP de los headers (Proxy)
      final rawIp = request.headers['x-forwarded-for'] ?? request.headers['x-real-ip'];
      String? clientIp = IpUtils.normalizeIp(rawIp);

      // 2. Fallback a la IP del Socket TCP
      if (clientIp == null) {
        final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
        if (connectionInfo != null) {
          clientIp = IpUtils.normalizeIp(connectionInfo.remoteAddress.address);
        }
      }

      // 3. Fallback final seguro (Evitar el bucket de DoS)
      clientIp ??= '127.0.0.1';

      final key = 'shelf_api_$clientIp';

      if (!limiter.tryAcquire(key)) {
        // En HTTP, el código correcto es 429 Too Many Requests
        return Response(
          429,
          body: 'Too Many Requests',
          headers: {'Retry-After': '60'}, // Sugiere intentar en 60s
        );
      }

      return innerHandler(request);
    };
  };
}
