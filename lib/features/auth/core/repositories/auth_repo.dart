import 'package:uuid/uuid.dart';

import '/src/generated/auth.pb.dart';

import '../use_cases/classic/create_user.dart';
import '../use_cases/classic/sign_in.dart';
import '../use_cases/classic/sign_up.dart';
import '../use_cases/classic/update_user.dart';
import '../use_cases/email_otp/finish_email_otp_sign_in.dart';
import '../use_cases/email_otp/start_email_otp_sign_in.dart';
import '../use_cases/email_verification/finish_email_verification.dart';
import '../use_cases/email_verification/start_email_verification.dart';
import '../use_cases/oidc/sign_in_with_oidc.dart';
import '../use_cases/passkey/finish_fido2_authentication.dart';
import '../use_cases/passkey/finish_fido2_registration.dart';
import '../use_cases/passkey/generate_fido2_registration_challenge.dart';
import '../use_cases/password_reset/finish_password_reset.dart';
import '../use_cases/password_reset/start_password_reset.dart';

abstract class IAuthRepository {
  // --- Flujo de Registro ---
  Future<AuthSuccess> signUp({required SignUpCommand request, required AuthStrategy strategy});
  Future<CreateUserResponse> createUser({required CreateUserCommand request});
  Future<void> updateUser({required UpdateUserCommand request});

  // --- Flujos de Inicio de Sesión ---
  Future<AuthSuccess> signIn({required SignInCommand request, required AuthStrategy strategy});
  Future<void> startEmailOtpSignIn({required StartEmailOtpSignInCommand request});
  Future<AuthSuccess> finishEmailOtpSignIn({required FinishEmailOtpSignInCommand request, required AuthStrategy strategy});
  Future<AuthSuccess> signInWithOidc({required SignInWithOidcCommand request});

  // --- Flujos de Passkey (FIDO2) ---
  Future<Fido2ChallengeResponse> generateFido2RegistrationChallenge({required GenerateFido2RegistrationChallengeQuery request});
  Future<void> finishFido2Registration({required FinishFido2RegistrationCommand request});
  Future<Fido2ChallengeResponse> generateFido2AuthenticationChallenge();
  Future<AuthSuccess> finishFido2Authentication({required FinishFido2AuthenticationCommand request, required AuthStrategy strategy});

  // --- Gestión de Contraseña y Correo ---
  Future<void> startPasswordReset({required StartPasswordResetCommand request});
  Future<AuthSuccess> finishPasswordReset({required FinishPasswordResetCommand request, required AuthStrategy strategy});
  Future<void> forcePasswordChange({required UuidValue authUserId, required String newPassword});
  Future<void> startEmailVerification({required StartEmailVerificationCommand request});
  Future<void> finishEmailVerification({required FinishEmailVerificationCommand request});

  // --- Gestión de Sesiones y Seguridad (Step-Up) ---
  Future<ActiveSessionsResponse> getActiveSessions({required UuidValue userId, required UuidValue currentTokenId});
  Future<void> reauthenticate({required UuidValue userId, required UuidValue currentTokenId, required String password});
  Future<void> signOutDevice({required UuidValue tokenId, required AuthStrategy strategy});
  Future<void> signOutOtherDevice({required UuidValue userId, required UuidValue targetTokenId});
  Future<void> signOutAllDevices({required UuidValue userId});
  Future<void> signOutAllOtherDevices({required UuidValue userId, required UuidValue currentTokenId});
}
