import 'package:uuid/uuid.dart';

import '../database/database.dart';
import 'app_caches.dart';
import 'authentication_info.dart';
import 'log_level.dart';
import 'session_log_manager.dart';

class AppSession {
  // 1. Identidad y Ciclo de vida
  final UuidValue sessionId;
  final DateTime startTime;
  final String locale;
  final String? clientIp;
  final String? userAgent;

  // 2. Autenticación
  final String? authenticationKey; // El token crudo enviado por el cliente
  AuthenticationInfo? authenticated; // Información decodificada del usuario

  bool get isAuthenticated => authenticated != null;

  // 3. Recursos
  final AppDatabase db;
  final AppCaches caches;
  late final SessionLogManager logManager;

  bool _closed = false;

  AppSession({
    required this.db,
    required this.caches,
    required this.locale,
    this.clientIp,
    this.userAgent,
    this.authenticationKey,
    this.authenticated,
  })  : sessionId = const Uuid().v4obj(),
        startTime = DateTime.now().toUtc() {
    logManager = SessionLogManager();
  }

  // Getter para medir el tiempo transcurrido desde el inicio de la petición.
  Duration get duration => DateTime.now().toUtc().difference(startTime);

  /// Método para agregar registros al flujo de la sesión actual.
  void log(String message, {LogLevel level = LogLevel.info}) {
    logManager.log(message, level: level);
  }

  // Se llama al finalizar la petición en el request_scope, consolidando los logs.
  Future<void> close({dynamic error, StackTrace? stackTrace}) async {
    if (_closed) return;
    _closed = true;

    // Finaliza los logs, escribe en DB si es necesario, etc.
    await logManager.finalizeLogs(duration: duration, error: error);
  }
}
