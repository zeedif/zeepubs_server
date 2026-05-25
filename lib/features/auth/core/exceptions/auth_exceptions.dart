// --- Autenticación y Credenciales de Acceso ---

/// Lanzada cuando el usuario o la contraseña provistos son incorrectos.
class InvalidCredentialsException implements Exception {
  const InvalidCredentialsException();
}

/// Lanzada cuando no se encuentra un usuario durante un flujo de recuperación de credenciales.
class UserNotFoundException implements Exception {
  const UserNotFoundException();
}

/// Lanzada cuando la cuenta se bloquea temporalmente debido a exceder los intentos fallidos.
class AccountLockedException implements Exception {
  final DateTime lockedUntil;
  const AccountLockedException(this.lockedUntil);
}

/// Lanzada si la cuenta de usuario se encuentra bloqueada permanentemente.
class AuthUserBlockedException implements Exception {
  const AuthUserBlockedException();
}

/// Lanzada cuando el cliente no posee los ámbitos (scopes) o permisos necesarios para la operación.
class AccessDeniedException implements Exception {
  const AccessDeniedException();
}

/// Lanzada si se requiere una re-autenticación fresca (Step-Up Auth) para realizar una acción sensible.
class ReauthenticationRequiredException implements Exception {
  const ReauthenticationRequiredException();
}

// --- Registro y Alta de Usuarios ---

/// Lanzada cuando el nombre de usuario ya está registrado en el sistema.
class UsernameAlreadyInUseException implements Exception {
  const UsernameAlreadyInUseException();
}

/// Lanzada cuando la dirección de correo electrónico ya está registrada en el sistema.
class EmailAlreadyInUseException implements Exception {
  const EmailAlreadyInUseException();
}

/// Lanzada si el registro público está deshabilitado en la configuración.
class PublicSignupDisabledException implements Exception {
  const PublicSignupDisabledException();
}

/// Lanzada cuando el cliente intenta registrarse sin proveer email o contraseña.
class RegistrationCredentialsRequiredException implements Exception {
  const RegistrationCredentialsRequiredException();
}

// --- Verificación de Cuentas ---

/// Lanzada cuando se intenta iniciar sesión pero se requiere verificación de correo previa.
class EmailVerificationRequiredException implements Exception {
  const EmailVerificationRequiredException();
}

/// Lanzada cuando un código OTP o código de verificación de contraseña es inválido o ha expirado.
class VerificationException implements Exception {
  final String? message;
  const VerificationException([this.message]);
}

/// Lanzada al intentar enviar un correo de verificación a un usuario que no tiene email registrado.
class NoEmailToVerifyException implements Exception {
  const NoEmailToVerifyException();
}

// --- Autenticación Externa / OIDC (OpenID Connect) ---

/// Lanzada si se intenta usar flujos federados pero el servidor carece de configuración OIDC.
class OidcNotConfiguredException implements Exception {
  const OidcNotConfiguredException();
}

/// Lanzada si el inicio de sesión vía OIDC está deshabilitado en las políticas del servidor.
class OidcSignInDisabledException implements Exception {
  const OidcSignInDisabledException();
}

/// Lanzada si el registro automático de nuevas cuentas vía OIDC está deshabilitado en el servidor.
class OidcSignupDisabledException implements Exception {
  const OidcSignupDisabledException();
}

/// Lanzada cuando la cuenta de OIDC validada no tiene un usuario local vinculado en nuestra base de datos.
class OidcUserNotFoundException implements Exception {
  const OidcUserNotFoundException();
}

// --- MFA, OTP y Seguridad FIDO2/Passkeys ---

/// Lanzada cuando el inicio de sesión rápido por email (Email OTP) está deshabilitado.
class OtpSignInDisabledException implements Exception {
  const OtpSignInDisabledException();
}

/// Lanzada cuando el código OTP provisto es inválido o ha expirado.
class InvalidOtpException implements Exception {
  const InvalidOtpException();
}

/// Lanzada si se intentan usar características FIDO2 pero el servidor no tiene la configuración activa.
class Fido2NotConfiguredException implements Exception {
  const Fido2NotConfiguredException();
}

/// Lanzada si el registro de nuevas llaves de acceso (Passkeys) está deshabilitado en el servidor.
class PasskeyRegistrationDisabledException implements Exception {
  const PasskeyRegistrationDisabledException();
}

/// Lanzada si el inicio de sesión mediante llaves de acceso (Passkeys) está deshabilitado en el servidor.
class PasskeySignInDisabledException implements Exception {
  const PasskeySignInDisabledException();
}

/// Lanzada cuando el desafío criptográfico provisto por WebAuthn ha expirado o es incorrecto.
class ExpiredOrInvalidChallengeException implements Exception {
  const ExpiredOrInvalidChallengeException();
}

// --- Sesiones y Ciclo de Vida de Tokens ---

/// Lanzada cuando el token de refresco provisto es inválido o no existe en la base de datos.
class RefreshTokenInvalidException implements Exception {
  const RefreshTokenInvalidException();
}

/// Lanzada cuando el tiempo de vida del token de refresco ha expirado.
class RefreshTokenExpiredException implements Exception {
  const RefreshTokenExpiredException();
}

/// Lanzada cuando el secreto rotativo del token falla, sugiriendo un posible compromiso de seguridad.
class RefreshTokenCompromisedException implements Exception {
  const RefreshTokenCompromisedException();
}
