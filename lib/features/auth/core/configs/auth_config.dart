class AuthConfig {
  // --- Banderas de Registro (Sign Up) ---
  final bool publicEmailSignupEnabled;
  final bool publicPasswordOnlySignupEnabled;
  final bool allowOidcSignup;           // ¿Se permiten nuevos registros vía Google/Microsoft?
  final bool allowPasskeyRegistration;  // ¿Se permite registrar Passkeys/WebAuthn?

  // --- Banderas de Inicio de Sesión (Sign In) ---
  final bool allowEmailOtpSignIn;       // ¿Se permite hacer login recibiendo un código por correo?
  final bool allowOidcSignIn;           // ¿Se permite iniciar sesión con OIDC?
  
  // --- Banderas de Verificación y Seguridad ---
  final bool requireEmailVerification;  // ¿Se bloquea el login de un usuario hasta que verifique su email?
  
  // --- Políticas de Límite y Prevención de Fuerza Bruta ---
  final int maxActiveSessionsPerUser;   // Máximo de dispositivos/sesiones activas concurrentes
  final int maxFailedLoginAttempts;     // Intentos fallidos antes de aplicar un bloqueo temporal
  final Duration accountLockoutDuration;// Duración del bloqueo temporal por intentos fallidos

  AuthConfig({
    required this.publicEmailSignupEnabled,
    required this.publicPasswordOnlySignupEnabled,
    required this.allowOidcSignup,
    required this.allowPasskeyRegistration,
    required this.allowEmailOtpSignIn,
    required this.allowOidcSignIn,
    required this.requireEmailVerification,
    required this.maxActiveSessionsPerUser,
    required this.maxFailedLoginAttempts,
    required this.accountLockoutDuration,
  });

  /// Factory para construir las reglas desde el archivo YAML (parseado como Map)
  factory AuthConfig.load(Map<String, dynamic>? yamlConfig) {
    final map = yamlConfig ?? {};

    return AuthConfig(
      publicEmailSignupEnabled: map['publicEmailSignupEnabled'] ?? false,
      publicPasswordOnlySignupEnabled: map['publicPasswordOnlySignupEnabled'] ?? false,
      allowOidcSignup: map['allowOidcSignup'] ?? true,
      allowPasskeyRegistration: map['allowPasskeyRegistration'] ?? true,
      allowEmailOtpSignIn: map['allowEmailOtpSignIn'] ?? true,
      allowOidcSignIn: map['allowOidcSignIn'] ?? true,
      requireEmailVerification: map['requireEmailVerification'] ?? true,
      
      maxActiveSessionsPerUser: map['maxActiveSessionsPerUser'] ?? 5,
      maxFailedLoginAttempts: map['maxFailedLoginAttempts'] ?? 5,
      accountLockoutDuration: Duration(minutes: map['accountLockoutMinutes'] ?? 15),
    );
  }
}
