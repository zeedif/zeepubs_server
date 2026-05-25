import '/common/session/app_session.dart';
import '/features/auth/core/exceptions/auth_exceptions.dart';
import '/src/generated/auth.pb.dart';

extension PermissionValidator on AppSession {
  /// Verifica si el usuario tiene un scope específico sin lanzar excepción.
  bool hasScope(Scope scope) {
    return authenticated?.scopes.contains(scope) ?? false;
  }

  /// Verifica si el usuario tiene al menos uno de los scopes sin lanzar excepción.
  bool hasAnyScope(List<Scope> scopes) {
    return authenticated?.scopes.any((s) => scopes.contains(s)) ?? false;
  }

  /// Verifica si el usuario actual tiene permisos administrativos de sistema.
  bool isSystemAdmin() {
    return hasAnyScope([
      Scope.SYSTEM_MANAGE_USERS,
      Scope.SYSTEM_MANAGE_PROFILES,
      Scope.SYSTEM_ASSIGN_PERMISSIONS,
      Scope.SYSTEM_MANAGE_WORKGROUPS,
    ]);
  }

  /// Asegura que el usuario de la sesión actual tiene un scope específico.
  /// Si no, lanza un [AccessDeniedException].
  void requireScope(Scope requiredScope) {
    if (!hasScope(requiredScope)) throw const AccessDeniedException();
  }

  /// Asegura que el usuario tiene al menos uno de los scopes de la lista.
  void requireAnyScope(List<Scope> requiredScopes) {
    if (!hasAnyScope(requiredScopes)) throw const AccessDeniedException();
  }

  /// Lanza excepción si el usuario no tiene permisos de administración global.
  void requireSystemAdmin() {
    if (!isSystemAdmin()) throw const AccessDeniedException();
  }
}
