class SecurityConfig {
  // --- Peppers Criptográficos ---
  final String passwordHashPepper;
  final String emailOtpHashPepper;
  final String emailVerificationHashPepper;
  final String passwordResetHashPepper;
  final String refreshTokenHashPepper;
  final String sessionHashPepper;

  // --- Propiedades Criptográficas de Refresh Tokens ---
  final int refreshTokenFixedSecretLength;
  final int refreshTokenRotatingSecretLength;
  final Duration refreshTokenLifetime;

  SecurityConfig({
    required this.passwordHashPepper,
    required this.emailOtpHashPepper,
    required this.emailVerificationHashPepper,
    required this.passwordResetHashPepper,
    required this.refreshTokenHashPepper,
    required this.sessionHashPepper,
    required this.refreshTokenFixedSecretLength,
    required this.refreshTokenRotatingSecretLength,
    required this.refreshTokenLifetime,
  });
}
