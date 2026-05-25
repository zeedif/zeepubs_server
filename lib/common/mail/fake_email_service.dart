import '../session/app_session.dart';
import '../session/log_level.dart';

/// Un servicio de correo falso que registra los correos en el LogManager de la sesión actual.
/// Ideal para desarrollo y pruebas sin configurar un servidor SMTP real.
class FakeEmailService {

  void sendPasswordResetEmail({
    required AppSession session,
    required String toEmail,
    required String verificationCode,
  }) {
    session.log(
      '📧 [FAKE EMAIL] Restablecimiento de contraseña enviado a: $toEmail (Código: $verificationCode)',
      level: LogLevel.info,
    );
  }

  void sendEmailVerificationEmail({
    required AppSession session,
    required String toEmail,
    required String verificationCode,
  }) {
    session.log(
      '📧 [FAKE EMAIL] Verificación de correo enviada a: $toEmail (Código: $verificationCode)',
      level: LogLevel.info,
    );
  }

  void sendOtpSignInEmail({
    required AppSession session,
    required String toEmail,
    required String otp,
  }) {
    session.log(
      '📧 [FAKE EMAIL] OTP de inicio de sesión enviado a: $toEmail (Código: $otp)',
      level: LogLevel.info,
    );
  }
}
