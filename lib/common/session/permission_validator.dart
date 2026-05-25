import '/common/session/app_session.dart';
import '/features/auth/core/exceptions/auth_exceptions.dart';
import '/src/generated/auth.pb.dart';

extension PermissionValidator on AppSession {
  /// Asegura que el usuario de la sesión actual tiene un scope específico.
  /// Si no, lanza un [AccessDeniedException].
  void requireScope(Scope requiredScope) {
    final userScopes = authenticated?.scopes;
    if (userScopes == null || !userScopes.contains(requiredScope)) {
      throw const AccessDeniedException();
    }
  }

  /// Asegura que el usuario tiene al menos uno de los scopes de la lista.
  void requireAnyScope(List<Scope> requiredScopes) {
    final userScopes = authenticated?.scopes;
    if (userScopes == null || !requiredScopes.any((scope) => userScopes.contains(scope))) {
      throw const AccessDeniedException();
    }
  }

  /// Verifica si el usuario actual tiene permisos administrativos de sistema.
  void requireSystemAdmin() {
    requireAnyScope([
      Scope.SYSTEM_MANAGE_USERS,
      Scope.SYSTEM_MANAGE_PROFILES,
      Scope.SYSTEM_ASSIGN_PERMISSIONS,
      Scope.SYSTEM_MANAGE_WORKGROUPS,
    ]);
  }
}
