import 'package:grpc/grpc.dart';
import 'package:uuid/uuid.dart';

import '/common/di/service_locator.dart';
import '/common/localization/localizer.dart';
import '/common/mediator/mediator.dart';
import '/common/session/app_session.dart';
import '/common/utils/request_scope.dart';
import '/src/generated/auth.pbgrpc.dart';

import '../core/exceptions/auth_exceptions.dart';
import '../core/repositories/auth_repo.dart';
import '../core/use_cases/classic/create_user.dart';
import '../core/use_cases/classic/sign_in.dart';
import '../core/use_cases/classic/sign_up.dart';
import '../core/use_cases/email_otp/finish_email_otp_sign_in.dart';
import '../core/use_cases/email_otp/start_email_otp_sign_in.dart';
import '../core/use_cases/email_verification/finish_email_verification.dart';
import '../core/use_cases/email_verification/start_email_verification.dart';
import '../core/use_cases/oidc/sign_in_with_oidc.dart';
import '../core/use_cases/passkey/finish_fido2_authentication.dart';
import '../core/use_cases/passkey/finish_fido2_registration.dart';
import '../core/use_cases/passkey/generate_fido2_authentication_challenge.dart';
import '../core/use_cases/passkey/generate_fido2_registration_challenge.dart';
import '../core/use_cases/password_reset/finish_password_reset.dart';
import '../core/use_cases/password_reset/start_password_reset.dart';
import '../core/use_cases/sessions/get_active_sessions.dart';
import '../core/use_cases/sessions/reauthenticate.dart';
import '../core/use_cases/sessions/sign_out_all_devices.dart';
import '../core/use_cases/sessions/sign_out_all_other_devices.dart';
import '../core/use_cases/sessions/sign_out_device.dart';
import '../core/use_cases/sessions/sign_out_other_device.dart';

class AuthServiceImpl extends AuthServiceBase {
  /// Mapea excepciones de negocio a errores gRPC.
  GrpcError _mapExceptionToGrpcError(Object e, StackTrace? stack) {
    String locale = 'en';
    try {
      if (locator.isRegistered<AppSession>()) {
        locale = locator<AppSession>().locale;
      }
    } catch (_) {}

    switch (e) {
      // --- Excepciones de Autenticación y Credenciales de Acceso ---
      case InvalidCredentialsException():
        return GrpcError.unauthenticated(L10n.strings.authInvalidCredentials(locale));

      case UserNotFoundException():
        return GrpcError.notFound(L10n.strings.authUserNotFound(locale));

      case AccountLockedException(:final lockedUntil):
        final lockedUntilFormatted = lockedUntil.toLocal().toString();
        return GrpcError.permissionDenied(
          L10n.strings.authAccountLocked(locale, lockedUntilFormatted),
        );

      case AuthUserBlockedException():
        return GrpcError.permissionDenied(L10n.strings.authUserBlocked(locale));

      case AccessDeniedException():
        return GrpcError.permissionDenied(L10n.strings.authAccessDenied(locale));

      case ReauthenticationRequiredException():
        return GrpcError.permissionDenied(L10n.strings.authReauthenticationRequired(locale));

      // --- Excepciones de Registro y Alta de Usuarios ---
      case UsernameAlreadyInUseException():
        return GrpcError.alreadyExists(L10n.strings.authUsernameInUse(locale));

      case EmailAlreadyInUseException():
        return GrpcError.alreadyExists(L10n.strings.authEmailInUse(locale));

      case PublicSignupDisabledException():
        return GrpcError.failedPrecondition(L10n.strings.authPublicSignupDisabled(locale));

      case RegistrationCredentialsRequiredException():
        return GrpcError.invalidArgument(L10n.strings.authRegistrationCredentialsRequired(locale));

      // --- Excepciones de Verificación de Cuentas ---
      case EmailVerificationRequiredException():
        return GrpcError.failedPrecondition(L10n.strings.authEmailVerificationRequired(locale));

      case VerificationException():
        return GrpcError.failedPrecondition(L10n.strings.authVerificationFailed(locale));

      case NoEmailToVerifyException():
        return GrpcError.failedPrecondition(L10n.strings.authNoEmailToVerify(locale));

      // --- Excepciones de Autenticación Externa / OIDC ---
      case OidcNotConfiguredException():
        return GrpcError.failedPrecondition(L10n.strings.authOidcNotConfigured(locale));

      case OidcSignInDisabledException():
        return GrpcError.permissionDenied(L10n.strings.authOidcSigninDisabled(locale));

      case OidcSignupDisabledException():
        return GrpcError.permissionDenied(L10n.strings.authOidcSignupDisabled(locale));

      case OidcUserNotFoundException():
        return GrpcError.notFound(L10n.strings.authOidcUserNotFound(locale));

      // --- Excepciones de MFA, OTP y Seguridad FIDO2/Passkeys ---
      case OtpSignInDisabledException():
        return GrpcError.permissionDenied(L10n.strings.authOtpSigninDisabled(locale));

      case InvalidOtpException():
        return GrpcError.invalidArgument(L10n.strings.authInvalidOtp(locale));

      case Fido2NotConfiguredException():
        return GrpcError.failedPrecondition(L10n.strings.authFido2NotConfigured(locale));

      case PasskeyRegistrationDisabledException():
        return GrpcError.failedPrecondition(L10n.strings.authPasskeyRegistrationDisabled(locale));

      case PasskeySignInDisabledException():
        return GrpcError.permissionDenied(L10n.strings.authPasskeySigninDisabled(locale));

      case ExpiredOrInvalidChallengeException():
        return GrpcError.invalidArgument(L10n.strings.authExpiredOrInvalidChallenge(locale));

      // --- Excepciones de Sesiones y Ciclo de Vida de Tokens ---
      case RefreshTokenInvalidException():
        return GrpcError.unauthenticated(L10n.strings.authRefreshTokenInvalid(locale));

      case RefreshTokenExpiredException():
        return GrpcError.unauthenticated(L10n.strings.authRefreshTokenExpired(locale));

      case RefreshTokenCompromisedException():
        return GrpcError.permissionDenied(L10n.strings.authAccessDenied(locale));

      // --- Excepciones Estándar del Core de Dart ---
      case UnimplementedError(:final message):
        return GrpcError.unimplemented(message ?? 'Unimplemented operation.');

      case UnsupportedError(:final message):
        return GrpcError.unimplemented(message ?? 'Unsupported operation.');

      case ArgumentError(:final message):
        return GrpcError.invalidArgument(message?.toString() ?? 'Invalid argument.');

      case StateError(:final message):
        return GrpcError.failedPrecondition(message);

      // Caso por defecto (Excepciones no controladas)
      default:
        print('🚨 [Unhandled Error in gRPC]: $e\n$stack');
        return GrpcError.internal(L10n.strings.commonGenericInternalError(locale));
    }
  }

  // =========================================================================
  // --- CATEGORÍA: FLUJO DE REGISTRO (SIGN UP) ---
  // =========================================================================

  @override
  Future<AuthSuccess> signUp(ServiceCall call, SignUpRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = SignUpCommand(
          username: request.username,
          email: request.hasEmail() ? request.email : null,
          password: request.hasPassword() ? request.password : null,
          strategy: request.strategy,
        );
        return await locator<Mediator>().send(command);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<CreateUserResponse> createUser(ServiceCall call, CreateUserRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = CreateUserCommand(
          username: request.username,
          email: request.hasEmail() ? request.email : null,
          password: request.hasPassword() ? request.password : null,
        );
        return await locator<Mediator>().send(command);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  // =========================================================================
  // --- CATEGORÍA: FLUJOS DE INICIO DE SESIÓN (SIGN IN) ---
  // =========================================================================

  @override
  Future<AuthSuccess> signIn(ServiceCall call, SignInRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = SignInCommand(
          userOrEmail: request.userOrEmail,
          password: request.password,
          strategy: request.strategy,
        );
        return await locator<Mediator>().send(command);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<EmptyResponse> startEmailOtpSignIn(ServiceCall call, StartEmailOtpSignInRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = StartEmailOtpSignInCommand(email: request.email);
        await locator<Mediator>().send(command);
        return EmptyResponse();
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<AuthSuccess> finishEmailOtpSignIn(ServiceCall call, FinishEmailOtpSignInRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = FinishEmailOtpSignInCommand(
          email: request.email,
          otp: request.otp,
          strategy: request.strategy,
        );
        return await locator<Mediator>().send(command);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<AuthSuccess> signInWithOidc(ServiceCall call, SignInWithOidcRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = SignInWithOidcCommand(
          issuer: request.issuer,
          subject: request.subject,
          email: request.hasEmail() ? request.email : null,
          nickname: request.hasNickname() ? request.nickname : null,
          avatarUrl: request.hasAvatarUrl() ? request.avatarUrl : null,
          strategy: request.strategy,
        );
        return await locator<Mediator>().send(command);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  // =========================================================================
  // --- CATEGORÍA: FLUJOS DE PASSKEY (FIDO2) ---
  // =========================================================================

  @override
  Future<Fido2ChallengeResponse> generateFido2RegistrationChallenge(
    ServiceCall call,
    GenerateFido2RegistrationChallengeRequest request,
  ) async {
    return withRequestScope(call, () async {
      try {
        final query = GenerateFido2RegistrationChallengeQuery(username: request.username);
        return await locator<Mediator>().send(query);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<EmptyResponse> finishFido2Registration(ServiceCall call, FinishFido2RegistrationRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = FinishFido2RegistrationCommand(
          challengeId: request.challengeId,
          attestationObject: request.attestationObject,
          clientDataJSON: request.clientDataJson,
        );
        await locator<Mediator>().send(command);
        return EmptyResponse();
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<Fido2ChallengeResponse> generateFido2AuthenticationChallenge(ServiceCall call, EmptyResponse request) async {
    return withRequestScope(call, () async {
      try {
        final query = GenerateFido2AuthenticationChallengeQuery();
        return await locator<Mediator>().send(query);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<AuthSuccess> finishFido2Authentication(ServiceCall call, FinishFido2AuthenticationRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = FinishFido2AuthenticationCommand(
          challengeId: request.challengeId,
          credentialId: request.credentialId,
          authenticatorData: request.authenticatorData,
          clientDataJSON: request.clientDataJson,
          signature: request.signature,
          strategy: request.strategy,
        );
        return await locator<Mediator>().send(command);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  // =========================================================================
  // --- CATEGORÍA: GESTIÓN DE CONTRASEÑA Y CORREO ---
  // =========================================================================

  @override
  Future<EmptyResponse> startPasswordReset(ServiceCall call, StartPasswordResetRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = StartPasswordResetCommand(email: request.email);
        await locator<Mediator>().send(command);
        return EmptyResponse();
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<AuthSuccess> finishPasswordReset(ServiceCall call, FinishPasswordResetRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = FinishPasswordResetCommand(
          requestId: request.requestId,
          verificationCode: request.verificationCode,
          newPassword: request.newPassword,
          strategy: request.strategy,
        );
        return await locator<Mediator>().send(command);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<EmptyResponse> forcePasswordChange(ServiceCall call, ForcePasswordChangeRequest request) async {
    return withRequestScope(call, () async {
      try {
        // TODO: Crear un caso de uso y eliminar la dependencia al repositorio.
        await locator<IAuthRepository>().forcePasswordChange(
          authUserId: UuidValue.fromString(request.authUserId),
          newPassword: request.newPassword,
        );
        return EmptyResponse();
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<EmptyResponse> startEmailVerification(ServiceCall call, EmptyResponse request) async {
    return withRequestScope(call, () async {
      try {
        final session = locator<AppSession>();

        final command = StartEmailVerificationCommand(authUserId: session.authenticated!.userId);
        await locator<Mediator>().send(command);

        return EmptyResponse();
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<EmptyResponse> finishEmailVerification(ServiceCall call, FinishEmailVerificationRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = FinishEmailVerificationCommand(
          requestId: request.requestId,
          verificationCode: request.verificationCode,
        );
        await locator<Mediator>().send(command);
        return EmptyResponse();
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  // =========================================================================
  // --- CATEGORÍA: GESTIÓN DE SESIONES Y SEGURIDAD (STEP-UP) ---
  // =========================================================================

  @override
  Future<ActiveSessionsResponse> getActiveSessions(ServiceCall call, EmptyResponse request) async {
    return withRequestScope(call, () async {
      try {
        final session = locator<AppSession>();

        final query = GetActiveSessionsQuery(
          userId: session.authenticated!.userId,
          currentTokenId: session.authenticated!.tokenId!,
        );

        return await locator<Mediator>().send(query);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<EmptyResponse> reauthenticate(ServiceCall call, ReauthenticateRequest request) async {
    return withRequestScope(call, () async {
      try {
        final session = locator<AppSession>();

        final command = ReauthenticateCommand(
          userId: session.authenticated!.userId,
          currentTokenId: session.authenticated!.tokenId!,
          password: request.password,
        );

        await locator<Mediator>().send(command);
        return EmptyResponse();
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<EmptyResponse> signOutDevice(ServiceCall call, EmptyResponse request) async {
    return withRequestScope(call, () async {
      try {
        final session = locator<AppSession>();

        final rawToken = session.authenticationKey ?? '';
        final strategy = rawToken.startsWith('sas:') ? AuthStrategy.SESSION : AuthStrategy.JWT;

        final command = SignOutDeviceCommand(
          tokenId: session.authenticated!.tokenId!,
          strategy: strategy,
        );

        await locator<Mediator>().send(command);
        return EmptyResponse();
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<EmptyResponse> signOutOtherDevice(ServiceCall call, SignOutOtherDeviceRequest request) async {
    return withRequestScope(call, () async {
      try {
        final session = locator<AppSession>();

        final command = SignOutOtherDeviceCommand(
          userId: session.authenticated!.userId,
          targetTokenId: UuidValue.fromString(request.targetTokenId),
        );

        await locator<Mediator>().send(command);
        return EmptyResponse();
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<EmptyResponse> signOutAllDevices(ServiceCall call, SignOutAllDevicesRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = SignOutAllDevicesCommand(userId: UuidValue.fromString(request.authUserId));
        await locator<Mediator>().send(command);
        return EmptyResponse();
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<EmptyResponse> signOutAllOtherDevices(ServiceCall call, EmptyResponse request) async {
    return withRequestScope(call, () async {
      try {
        final session = locator<AppSession>();

        final command = SignOutAllOtherDevicesCommand(
          userId: session.authenticated!.userId,
          currentTokenId: session.authenticated!.tokenId!,
        );

        await locator<Mediator>().send(command);
        return EmptyResponse();
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }
}
