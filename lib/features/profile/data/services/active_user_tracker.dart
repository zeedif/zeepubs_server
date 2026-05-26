import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '/common/database/database.dart';
import '/common/security/rate_limit_registry.dart';
import '/common/security/rate_limiter.dart';

/// Rastrea la actividad de los usuarios y envía las actualizaciones a la base de datos en lotes.
class ActiveUserTracker {
  final AppDatabase _db;
  final RateLimiter _limiter;

  // Almacena las actualizaciones pendientes en memoria
  final Map<UuidValue, DateTime> _pendingUpdates = {};

  ActiveUserTracker(this._db, RateLimitRegistry registry)
    : _limiter = registry.getLimiter(RateLimitPolicy.internalActivityTracker);

  /// Registra que un usuario está activo si el RateLimiter lo permite.
  void recordActive(UuidValue userId) {
    if (_limiter.tryAcquire(userId.toString())) {
      _pendingUpdates[userId] = DateTime.now().toUtc();
    }
  }

  /// Limpia (flushes) _pendingUpdates al escribirlas en la base de datos.
  Future<void> flush() async {
    if (_pendingUpdates.isEmpty) return;

    // Snapshot y vaciado seguro de la colección para evitar condiciones de carrera durante el 'await'
    final updatesSnapshot = Map<UuidValue, DateTime>.from(_pendingUpdates);
    _pendingUpdates.clear();

    final userIdsToUpdate = updatesSnapshot.keys.toList();
    final updateTime = DateTime.now().toUtc();

    try {
      // Actualización masiva de la última fecha de actividad global de usuarios
      await (_db.update(_db.authUsers)
        ..where((u) => u.id.isIn(userIdsToUpdate)))
        .write(AuthUsersCompanion(lastActiveAt: Value(updateTime)));
    } catch (e) {
      print('❌ [ActiveUserTracker] Error actualizando actividad de usuarios: $e');
      // En caso de error, intentamos reincorporar los registros no guardados si no han sido actualizados de nuevo
      updatesSnapshot.forEach((key, value) {
        _pendingUpdates.putIfAbsent(key, () => value);
      });
    }
  }
}
