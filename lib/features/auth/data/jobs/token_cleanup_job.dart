import 'dart:async';

import '/common/di/service_locator.dart';

import '../services/auth_token_manager.dart';

class TokenCleanupJob {
  static Timer? _timer;

  /// Inicia un proceso en segundo plano que limpia tokens expirados cada 24 horas.
  static void start() {
    if (_timer != null) return;

    // Ejecución inicial con delay mínimo
    Future.delayed(const Duration(minutes: 5), _executeCleanup);

    // Bucle recurrente cada 24 horas
    _timer = Timer.periodic(const Duration(hours: 24), (_) => _executeCleanup());
  }

  static Future<void> _executeCleanup() async {
    try {
      print('🧹 [Job] Iniciando limpieza periódica de sesiones y tokens expirados...');
      final tokenManager = locator<AuthTokenManager>();
      await tokenManager.cleanupExpiredTokens();
      print('✅ [Job] Limpieza de base de datos completada.');
    } catch (e, stack) {
      print('❌ [Job] Error durante la limpieza de tokens: $e\n$stack');
    }
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
