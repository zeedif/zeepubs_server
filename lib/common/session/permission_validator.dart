import '/common/session/app_session.dart';
import '/features/auth/core/exceptions/auth_exceptions.dart';
import '/src/generated/auth.pb.dart';

extension PermissionValidator on AppSession {
  /// Verifica si el usuario tiene un scope específico sin lanzar excepción.
  /// Si el usuario posee [Scope.SYSTEM_ADMIN], siempre devuelve true.
  bool hasScope(Scope scope) {
    final s = authenticated?.scopes;
    return s != null && (s.contains(Scope.SYSTEM_ADMIN) || s.contains(scope));
  }

  /// Verifica si el usuario tiene al menos uno de los scopes requeridos.
  /// Si el usuario posee [Scope.SYSTEM_ADMIN], siempre devuelve true.
  bool hasAnyScope(Iterable<Scope> scopes) {
    final s = authenticated?.scopes;
    return s != null && (s.contains(Scope.SYSTEM_ADMIN) || scopes.any(s.contains));
  }

  /// Asegura que el usuario de la sesión actual tiene un scope específico.
  /// Si no, lanza un [AccessDeniedException].
  void requireScope(Scope requiredScope) {
    if (!hasScope(requiredScope)) throw const AccessDeniedException();
  }

  /// Asegura que el usuario tiene al menos uno de los scopes del iterable.
  void requireAnyScope(Iterable<Scope> requiredScopes) {
    if (!hasAnyScope(requiredScopes)) throw const AccessDeniedException();
  }
}
