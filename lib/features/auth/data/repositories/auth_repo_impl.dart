import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart';
import 'package:uuid/uuid.dart';

import '/common/database/database.dart';
import '/common/di/service_locator.dart';
import '/common/localization/localizer.dart';
import '/common/mail/fake_email_service.dart';
import '/common/session/app_session.dart';
import '/src/generated/auth.pb.dart';

import '../../core/configs/auth_config.dart';
import '../../core/exceptions/auth_exceptions.dart';
import '../../core/repositories/auth_repo.dart';
import '../../core/use_cases/classic/create_user.dart';
import '../../core/use_cases/classic/sign_in.dart';
import '../../core/use_cases/classic/sign_up.dart';
import '../../core/use_cases/email_otp/finish_email_otp_sign_in.dart';
import '../../core/use_cases/email_otp/start_email_otp_sign_in.dart';
import '../../core/use_cases/email_verification/finish_email_verification.dart';
import '../../core/use_cases/email_verification/start_email_verification.dart';
import '../../core/use_cases/oidc/sign_in_with_oidc.dart';
import '../../core/use_cases/passkey/finish_fido2_authentication.dart';
import '../../core/use_cases/passkey/finish_fido2_registration.dart';
import '../../core/use_cases/passkey/generate_fido2_registration_challenge.dart';
import '../../core/use_cases/password_reset/finish_password_reset.dart';
import '../../core/use_cases/password_reset/start_password_reset.dart';
import '../services/auth_token_manager.dart';
import '../services/fido2_handler.dart';
import '../services/oidc_handler.dart';
import '../services/security.dart';
import '../utils/client_metadata_extractor.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final AppDatabase _db;
  final AuthTokenManager _tokenManager;
  final Security _security;
  final AuthConfig _config;
  final FakeEmailService _emailService;
  final OidcHandler? _oidcHandler;
  final Fido2Handler? _fido2Handler;

  AuthRepositoryImpl(
    this._db,
    this._tokenManager,
    this._security,
    this._config,
    this._emailService,
    this._oidcHandler,
    this._fido2Handler,
  );

  /// Helper para emitir el token correcto según la estrategia solicitada
  Future<AuthSuccess> _createToken(UuidValue userId, String method, Set<Scope> scopeNames, AuthStrategy strategy) {
    final session = locator<AppSession>();
    final parsedMeta = ClientMetadataExtractor.extract(session.userAgent);

    if (strategy == AuthStrategy.SESSION) {
      return _tokenManager.issueSasToken(
        userId,
        method,
        scopeNames,
        parsedMeta.clientNameKey,
        parsedMeta.clientTypeKey,
        session.clientIp ?? 'client.ip_unknown',
      );
    } else {
      return _tokenManager.issueJwtTokens(
        userId,
        method,
        scopeNames,
        parsedMeta.clientNameKey,
        parsedMeta.clientTypeKey,
        session.clientIp ?? 'client.ip_unknown',
      );
    }
  }

  // --- Flujo de Registro ---

  @override
  Future<AuthSuccess> signUp({required SignUpCommand request, required AuthStrategy strategy}) async {
    // 1. Validar configuración de registro público
    if (request.email != null && !_config.publicEmailSignupEnabled) {
      throw const PublicSignupDisabledException();
    }
    if (request.email == null && !_config.publicPasswordOnlySignupEnabled) {
      throw const PublicSignupDisabledException();
    }
    if (request.email == null && request.password == null) {
      throw const RegistrationCredentialsRequiredException();
    }

    // 2. Crear entidades de usuario
    final newUser = await _createUserEntities(
      username: request.username,
      email: request.email,
      password: request.password,
      emailIsVerified: !_config.requireEmailVerification,
    );

    // 3. Evaluar verificación de correo
    if (_config.requireEmailVerification && request.email != null) {
      await _startEmailVerificationInternal(authUserId: newUser.id);
      throw const EmailVerificationRequiredException();
    } else {
      // 4. Retornar token
      return await _createToken(newUser.id, 'classic_signup', newUser.scopes, strategy);
    }
  }

  @override
  Future<CreateUserResponse> createUser({required CreateUserCommand request}) async {
    final newUser = await _createUserEntities(
      username: request.username,
      email: request.email,
      password: request.password,
      emailIsVerified: false,
    );
    return CreateUserResponse(userId: newUser.id.toString());
  }

  /// Método helper interno para la creación base del usuario en DB
  Future<AuthUser> _createUserEntities({
    required String username,
    String? email,
    String? password,
    required bool emailIsVerified,
  }) async {
    final normalizedEmail = email?.toLowerCase();

    final existing = await (_db.select(_db.authUsers)
      ..where((u) => u.username.equals(username) |
        (normalizedEmail != null ? u.email.equals(normalizedEmail) : const Constant(false)))
    ).getSingleOrNull();

    if (existing != null) {
      if (existing.username.toLowerCase() == username.toLowerCase()) throw const UsernameAlreadyInUseException();
      if (existing.email == normalizedEmail) throw const EmailAlreadyInUseException();
    }

    String? passwordHash, passwordSalt;
    if (password != null) {
      final hashResult = await _security.createPasswordHash(password);
      passwordHash = base64Encode(hashResult.hash);
      passwordSalt = base64Encode(hashResult.salt);
    }

    final user = await _db.into(_db.authUsers).insertReturning(AuthUsersCompanion.insert(
      username: username,
      email: Value(normalizedEmail),
      passwordHash: Value(passwordHash),
      passwordSalt: Value(passwordSalt),
      emailVerifiedAt: Value(emailIsVerified ? DateTime.now().toUtc() : null),
      scopes: {},
    ));

    await _db.into(_db.publicProfiles).insert(PublicProfilesCompanion.insert(
      userId: Value(user.id),
      nickname: user.username,
    ));

    return user;
  }

  // --- Flujos de Inicio de Sesión ---

  @override
  Future<AuthSuccess> signIn({required SignInCommand request, required AuthStrategy strategy}) async {
    final normalizedIdentifier = request.userOrEmail.toLowerCase();
    final user = await (_db.select(_db.authUsers)
      ..where((u) => u.username.equals(request.userOrEmail) | u.email.equals(normalizedIdentifier))
    ).getSingleOrNull();

    if (user == null || user.passwordHash == null || user.passwordSalt == null) {
      throw const InvalidCredentialsException();
    }

    // 1. Validar Fuerza Bruta (Lockout activo)
    final now = DateTime.now().toUtc();
    if (user.lockedUntil != null && user.lockedUntil!.isAfter(now)) {
      throw AccountLockedException(user.lockedUntil!);
    }

    // 2. Validar contraseña
    final isValid = await _security.validatePassword(
      request.password,
      base64Decode(user.passwordHash!),
      base64Decode(user.passwordSalt!)
    );

    if (!isValid) {
      // Registrar intento fallido
      final newFailedAttempts = user.failedAttempts + 1;
      final shouldLock = newFailedAttempts >= _config.maxFailedLoginAttempts;
      final lockUntilTime = shouldLock ? now.add(_config.accountLockoutDuration) : null;

      await (_db.update(_db.authUsers)..where((u) => u.id.equals(user.id))).write(
        AuthUsersCompanion(
          failedAttempts: Value(newFailedAttempts),
          lockedUntil: Value(lockUntilTime),
        ),
      );

      if (shouldLock) {
        throw AccountLockedException(lockUntilTime!);
      }
      throw const InvalidCredentialsException();
    }

    // 3. Login exitoso -> Limpiar contadores de intentos fallidos
    await (_db.update(_db.authUsers)..where((u) => u.id.equals(user.id))).write(
      const AuthUsersCompanion(
        failedAttempts: Value(0),
        lockedUntil: Value(null),
      ),
    );

    if (_config.requireEmailVerification && user.email != null && user.emailVerifiedAt == null) {
      await _startEmailVerificationInternal(authUserId: user.id);
      throw const EmailVerificationRequiredException();
    }

    if (user.blocked) throw const AuthUserBlockedException();

    return await _createToken(user.id, 'classic_signin', user.scopes, strategy);
  }

  @override
  Future<void> startEmailOtpSignIn({required StartEmailOtpSignInCommand request}) async {
    if (!_config.allowEmailOtpSignIn) throw const OtpSignInDisabledException();

    final normalizedEmail = request.email.toLowerCase();
    final user = await (_db.select(_db.authUsers)..where((u) => u.email.equals(normalizedEmail))).getSingleOrNull();

    // Por seguridad, no revelamos si el usuario existe o no mediante errores
    if (user == null || user.passwordHash != null) return;

    // Limpiar peticiones OTP viejas de este correo
    await (_db.delete(_db.emailOtpRequests)..where((r) => r.email.equals(normalizedEmail))).go();

    final otp = _security.generateVerificationCode();
    final hashResult = await _security.createEmailOtpHash(otp);

    await _db.into(_db.emailOtpRequests).insert(EmailOtpRequestsCompanion.insert(
      email: normalizedEmail,
      otpHash: base64Encode(hashResult.hash),
      otpSalt: base64Encode(hashResult.salt),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    ));

    _emailService.sendOtpSignInEmail(session: locator<AppSession>(), toEmail: request.email, otp: otp);
  }

  @override
  Future<AuthSuccess> finishEmailOtpSignIn({required FinishEmailOtpSignInCommand request, required AuthStrategy strategy}) async {
    final normalizedEmail = request.email.toLowerCase();
    final otpRequest = await (_db.select(_db.emailOtpRequests)..where((r) => r.email.equals(normalizedEmail))).getSingleOrNull();

    if (otpRequest == null || otpRequest.expiresAt.isBefore(DateTime.now().toUtc())) {
      if (otpRequest != null) await (_db.delete(_db.emailOtpRequests)..where((r) => r.id.equals(otpRequest.id))).go();
      throw const VerificationException();
    }

    final isValid = await _security.validateEmailOtp(
      request.otp,
      base64Decode(otpRequest.otpHash),
      base64Decode(otpRequest.otpSalt)
    );

    // Consumir el OTP siempre para que no se reutilice
    await (_db.delete(_db.emailOtpRequests)..where((r) => r.id.equals(otpRequest.id))).go();

    if (!isValid) throw const VerificationException();

    final user = await (_db.select(_db.authUsers)..where((u) => u.email.equals(normalizedEmail))).getSingleOrNull();
    if (user == null) throw const UserNotFoundException();
    if (user.blocked) throw const AuthUserBlockedException();

    // Si inició sesión con correo, lo damos por verificado
    if (user.emailVerifiedAt == null) {
      await (_db.update(_db.authUsers)..where((u) => u.id.equals(user.id))).write(
        AuthUsersCompanion(emailVerifiedAt: Value(DateTime.now().toUtc()))
      );
    }

    return await _createToken(user.id, 'email_otp', user.scopes, strategy);
  }

  @override
  Future<AuthSuccess> signInWithOidc({required SignInWithOidcCommand request}) async {
    if (_oidcHandler == null) throw const OidcNotConfiguredException();
    if (!_config.allowOidcSignIn) throw const OidcSignInDisabledException();

    final oidcAccount = await (_db.select(_db.oidcAccounts)
          ..where((o) => o.issuer.equals(request.issuer) & o.subject.equals(request.subject)))
        .getSingleOrNull();

    UuidValue userId;

    if (oidcAccount != null) {
      userId = oidcAccount.userId;
      final user = await (_db.select(_db.authUsers)..where((u) => u.id.equals(userId))).getSingleOrNull();
      if (user == null) throw const OidcUserNotFoundException();
      if (user.blocked) throw const AuthUserBlockedException();
    } else {
      if (!_config.allowOidcSignup) throw const OidcSignupDisabledException();

      AuthUser? user;
      if (request.email != null) {
        user = await (_db.select(_db.authUsers)..where((u) => u.email.equals(request.email!.toLowerCase()))).getSingleOrNull();
      }

      if (user != null) {
        userId = user.id;
      } else {
        final newUserId = const Uuid().v4obj();
        await _db.into(_db.authUsers).insert(
          AuthUsersCompanion.insert(
            id: Value(newUserId),
            username: request.nickname ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
            email: Value(request.email?.toLowerCase()),
            emailVerifiedAt: Value(DateTime.now().toUtc()),
            scopes: {},
          ),
        );
        userId = newUserId;

        await _db.into(_db.publicProfiles).insert(
          PublicProfilesCompanion.insert(
            userId: Value(userId),
            nickname: request.nickname ?? 'Nuevo Usuario',
            avatarUrl: Value(request.avatarUrl),
          ),
        );
      }

      await _db.into(_db.oidcAccounts).insert(
        OidcAccountsCompanion.insert(
          userId: userId,
          issuer: request.issuer,
          subject: request.subject,
        ),
      );
    }

    final finalUser = await (_db.select(_db.authUsers)..where((u) => u.id.equals(userId))).getSingle();
    return await _createToken(finalUser.id, 'oidc', finalUser.scopes, request.strategy);
  }

  // --- Flujos de Passkey (FIDO2) ---

  @override
  Future<Fido2ChallengeResponse> generateFido2RegistrationChallenge({required GenerateFido2RegistrationChallengeQuery request}) async {
    if (_fido2Handler == null) throw const Fido2NotConfiguredException();
    if (!_config.allowPasskeyRegistration) throw const PasskeyRegistrationDisabledException();

    final options = _fido2Handler.generateRegistrationOptions(
      username: request.username,
      userDisplayName: request.username,
    );
    final challenge = options['challenge'] as String;

    final row = await _db.into(_db.passkeyChallenges).insertReturning(
      PasskeyChallengesCompanion.insert(challenge: challenge),
    );
    return Fido2ChallengeResponse(challenge: challenge, challengeId: row.id);
  }

  @override
  Future<void> finishFido2Registration({required FinishFido2RegistrationCommand request}) async {
    if (_fido2Handler == null) throw const Fido2NotConfiguredException();

    final storedChallenge = await (_db.select(_db.passkeyChallenges)..where((c) => c.id.equals(request.challengeId))).getSingleOrNull();

    if (storedChallenge == null || storedChallenge.createdAt.isBefore(DateTime.now().toUtc().subtract(const Duration(minutes: 5)))) {
      if (storedChallenge != null) await (_db.delete(_db.passkeyChallenges)..where((c) => c.id.equals(storedChallenge.id))).go();
      throw const ExpiredOrInvalidChallengeException();
    }

    final session = locator<AppSession>();
    final userId = session.authenticated?.userId;
    if (userId == null) throw const AccessDeniedException();

    final regResult = _fido2Handler.completeRegistration(
      clientDataBase64: request.clientDataJSON,
      attestationObjectBase64: request.attestationObject,
      expectedChallenge: storedChallenge.challenge,
    );

    await _db.into(_db.passkeyAccounts).insert(
      PasskeyAccountsCompanion.insert(
        userId: userId,
        credentialId: regResult.credentialId.buffer.asUint8List(),
        credentialIdBase64: base64Url.encode(regResult.credentialId),
        publicKey: jsonEncode(regResult.credentialPublicKey.toJson()),
        signCount: 0,
      ),
    );

    await (_db.delete(_db.passkeyChallenges)..where((c) => c.id.equals(storedChallenge.id))).go();
  }

  @override
  Future<Fido2ChallengeResponse> generateFido2AuthenticationChallenge() async {
    if (_fido2Handler == null) throw const Fido2NotConfiguredException();

    final options = _fido2Handler.generateAuthenticationOptions();
    final challenge = options['challenge'] as String;

    final row = await _db.into(_db.passkeyChallenges).insertReturning(
      PasskeyChallengesCompanion.insert(challenge: challenge),
    );
    return Fido2ChallengeResponse(challenge: challenge, challengeId: row.id);
  }

  @override
  Future<AuthSuccess> finishFido2Authentication({
    required FinishFido2AuthenticationCommand request,
    required AuthStrategy strategy,
  }) async {
    if (_fido2Handler == null) throw const Fido2NotConfiguredException();

    final passkey = await (_db.select(_db.passkeyAccounts)..where((p) => p.credentialIdBase64.equals(request.credentialId))).getSingleOrNull();
    if (passkey == null) throw const InvalidCredentialsException();

    final storedChallenge = await (_db.select(_db.passkeyChallenges)..where((c) => c.id.equals(request.challengeId))).getSingleOrNull();
    if (storedChallenge == null || storedChallenge.createdAt.isBefore(DateTime.now().toUtc().subtract(const Duration(minutes: 5)))) {
      if (storedChallenge != null) await (_db.delete(_db.passkeyChallenges)..where((c) => c.id.equals(storedChallenge.id))).go();
      throw const ExpiredOrInvalidChallengeException();
    }

    final verification = await _fido2Handler.completeAuthentication(
      clientDataBase64: request.clientDataJSON,
      authenticatorDataBase64: request.authenticatorData,
      signatureBase64: request.signature,
      expectedChallenge: storedChallenge.challenge,
      credentialPublicKey: passkey.publicKey,
      storedSignCount: passkey.signCount,
    );

    await (_db.update(_db.passkeyAccounts)..where((p) => p.id.equals(passkey.id))).write(
      PasskeyAccountsCompanion(signCount: Value(verification.signCount)),
    );
    await (_db.delete(_db.passkeyChallenges)..where((c) => c.id.equals(storedChallenge.id))).go();

    final user = await (_db.select(_db.authUsers)..where((u) => u.id.equals(passkey.userId))).getSingle();
    if (user.blocked) throw const AuthUserBlockedException();

    return await _createToken(user.id, 'passkey', user.scopes, strategy);
  }

  // --- Gestión de Contraseña y Correo ---

  @override
  Future<void> startPasswordReset({required StartPasswordResetCommand request}) async {
    final normalizedEmail = request.email.toLowerCase();
    final user = await (_db.select(_db.authUsers)..where((u) => u.email.equals(normalizedEmail))).getSingleOrNull();

    if (user == null) return;

    await (_db.delete(_db.passwordResetRequests)..where((r) => r.userId.equals(user.id))).go();

    final verificationCode = _security.generateVerificationCode();
    final hashResult = await _security.createPasswordResetHash(verificationCode);

    await _db.into(_db.passwordResetRequests).insert(PasswordResetRequestsCompanion.insert(
      userId: user.id,
      verificationCodeHash: base64Encode(hashResult.hash),
      verificationCodeSalt: base64Encode(hashResult.salt),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
    ));

    _emailService.sendPasswordResetEmail(session: locator<AppSession>(), toEmail: request.email, verificationCode: verificationCode);
  }

  @override
  Future<AuthSuccess> finishPasswordReset({required FinishPasswordResetCommand request, required AuthStrategy strategy}) async {
    final resetRequest = await (_db.select(_db.passwordResetRequests)..where((r) => r.id.equals(request.requestId))).getSingleOrNull();

    if (resetRequest == null || resetRequest.expiresAt.isBefore(DateTime.now().toUtc())) {
      if (resetRequest != null) await (_db.delete(_db.passwordResetRequests)..where((r) => r.id.equals(resetRequest.id))).go();
      throw const VerificationException();
    }

    final isValid = await _security.validatePasswordResetCode(
      request.verificationCode,
      base64Decode(resetRequest.verificationCodeHash),
      base64Decode(resetRequest.verificationCodeSalt)
    );

    await (_db.delete(_db.passwordResetRequests)..where((r) => r.id.equals(resetRequest.id))).go();

    if (!isValid) throw const VerificationException();

    // Cambiar contraseña real
    final hashResult = await _security.createPasswordHash(request.newPassword);
    await (_db.update(_db.authUsers)..where((u) => u.id.equals(resetRequest.userId))).write(AuthUsersCompanion(
      passwordHash: Value(base64Encode(hashResult.hash)),
      passwordSalt: Value(base64Encode(hashResult.salt)),
    ));

    // Destruir todas las sesiones previas
    await _tokenManager.destroyAllRefreshTokens(resetRequest.userId);
    await _tokenManager.destroyAllSessions(resetRequest.userId);

    final user = await (_db.select(_db.authUsers)..where((u) => u.id.equals(resetRequest.userId))).getSingle();
    return await _createToken(user.id, 'password_reset', user.scopes, strategy);
  }

  @override
  Future<void> forcePasswordChange({required UuidValue authUserId, required String newPassword}) async {
    final user = await (_db.select(_db.authUsers)..where((u) => u.id.equals(authUserId))).getSingleOrNull();
    if (user == null) throw const UserNotFoundException();

    final hashResult = await _security.createPasswordHash(newPassword);

    await (_db.update(_db.authUsers)..where((u) => u.id.equals(authUserId))).write(AuthUsersCompanion(
      passwordHash: Value(base64Encode(hashResult.hash)),
      passwordSalt: Value(base64Encode(hashResult.salt)),
    ));
  }

  @override
  Future<void> startEmailVerification({required StartEmailVerificationCommand request}) async {
    await _startEmailVerificationInternal(authUserId: request.authUserId);
  }

  Future<void> _startEmailVerificationInternal({required UuidValue authUserId}) async {
    final user = await (_db.select(_db.authUsers)..where((u) => u.id.equals(authUserId))).getSingleOrNull();
    if (user?.email == null) throw const NoEmailToVerifyException();

    await (_db.delete(_db.emailVerificationRequests)..where((r) => r.userId.equals(authUserId))).go();

    final verificationCode = _security.generateVerificationCode();
    final hashResult = await _security.createEmailVerificationHash(verificationCode);

    await _db.into(_db.emailVerificationRequests).insert(EmailVerificationRequestsCompanion.insert(
      userId: authUserId,
      verificationCodeHash: base64Encode(hashResult.hash),
      verificationCodeSalt: base64Encode(hashResult.salt),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
    ));

    _emailService.sendEmailVerificationEmail(session: locator<AppSession>(), toEmail: user!.email!, verificationCode: verificationCode);
  }

  @override
  Future<void> finishEmailVerification({required FinishEmailVerificationCommand request}) async {
    final verificationRequest = await (_db.select(_db.emailVerificationRequests)..where((r) => r.id.equals(request.requestId))).getSingleOrNull();

    if (verificationRequest == null || verificationRequest.expiresAt.isBefore(DateTime.now().toUtc())) {
      if (verificationRequest != null) await (_db.delete(_db.emailVerificationRequests)..where((r) => r.id.equals(verificationRequest.id))).go();
      throw const VerificationException();
    }

    final isValid = await _security.validateEmailVerificationCode(
      request.verificationCode,
      base64Decode(verificationRequest.verificationCodeHash),
      base64Decode(verificationRequest.verificationCodeSalt)
    );

    await (_db.delete(_db.emailVerificationRequests)..where((r) => r.id.equals(verificationRequest.id))).go();

    if (!isValid) throw const VerificationException();

    await (_db.update(_db.authUsers)..where((u) => u.id.equals(verificationRequest.userId))).write(
      AuthUsersCompanion(emailVerifiedAt: Value(DateTime.now().toUtc()))
    );
  }

  // --- Gestión de Sesiones y Seguridad (Step-Up) ---

  /// Validador de Step-Up Authentication (Obliga al cliente a re-identificarse si pasaron más de 15 minutos)
  Future<void> _ensureStepUpVerified(UuidValue userId, UuidValue currentTokenId) async {
    final now = DateTime.now().toUtc();
    DateTime? lastReauth;

    // Buscar en SAS
    final sas = await (_db.select(_db.authSessions)..where((t) => t.id.equals(currentTokenId))).getSingleOrNull();
    if (sas != null) {
      lastReauth = sas.lastReauthenticatedAt;
    } else {
      // Buscar en RefreshToken
      final rt = await (_db.select(_db.refreshTokens)..where((t) => t.id.equals(currentTokenId))).getSingleOrNull();
      if (rt != null) {
        lastReauth = rt.lastReauthenticatedAt;
      }
    }

    if (lastReauth == null || now.difference(lastReauth).inMinutes > 15) {
      throw const ReauthenticationRequiredException();
    }
  }

  @override
  Future<ActiveSessionsResponse> getActiveSessions({required UuidValue userId, required UuidValue currentTokenId}) async {
    final session = locator<AppSession>();
    final locale = session.locale;

    final response = ActiveSessionsResponse();

    // 1. Obtener sesiones SAS activas
    final sasSessions = await (_db.select(_db.authSessions)..where((s) => s.userId.equals(userId))).get();
    response.sessions.addAll(
      sasSessions.map((s) => ActiveSession(
        tokenId: s.id.toString(),
        clientName: AppLocalizer.getString(s.clientName, locale),
        clientType: AppLocalizer.getString(s.clientType, locale),
        ipAddress: s.ipAddress.startsWith('client.')
            ? AppLocalizer.getString(s.ipAddress, locale)
            : s.ipAddress,
        createdAt: Timestamp.fromDateTime(s.createdAt),
        lastUsedAt: Timestamp.fromDateTime(s.lastUsedAt),
        isCurrent: s.id == currentTokenId,
      )),
    );

    // 2. Obtener refresh tokens activos (JWT)
    final jwtSessions = await (_db.select(_db.refreshTokens)..where((s) => s.userId.equals(userId))).get();
    response.sessions.addAll(
      jwtSessions.map((s) => ActiveSession(
        tokenId: s.id.toString(),
        clientName: AppLocalizer.getString(s.clientName, locale),
        clientType: AppLocalizer.getString(s.clientType, locale),
        ipAddress: s.ipAddress.startsWith('client.')
            ? AppLocalizer.getString(s.ipAddress, locale)
            : s.ipAddress,
        createdAt: Timestamp.fromDateTime(s.createdAt),
        lastUsedAt: Timestamp.fromDateTime(s.lastUpdatedAt),
        isCurrent: s.id == currentTokenId,
      )),
    );

    return response;
  }

  @override
  Future<void> reauthenticate({required UuidValue userId, required UuidValue currentTokenId, required String password}) async {
    final user = await (_db.select(_db.authUsers)..where((u) => u.id.equals(userId))).getSingleOrNull();
    if (user == null || user.passwordHash == null || user.passwordSalt == null) {
      throw const InvalidCredentialsException();
    }

    final isValid = await _security.validatePassword(
      password,
      base64Decode(user.passwordHash!),
      base64Decode(user.passwordSalt!)
    );
    if (!isValid) throw const InvalidCredentialsException();

    final now = DateTime.now().toUtc();

    // Renovar ventana de seguridad de 15 minutos en la base de datos
    await (_db.update(_db.authSessions)..where((t) => t.id.equals(currentTokenId)))
        .write(AuthSessionsCompanion(lastReauthenticatedAt: Value(now)));
    await (_db.update(_db.refreshTokens)..where((t) => t.id.equals(currentTokenId)))
        .write(RefreshTokensCompanion(lastReauthenticatedAt: Value(now)));
  }

  @override
  Future<void> signOutDevice({required UuidValue tokenId, required AuthStrategy strategy}) async {
    if (strategy == AuthStrategy.SESSION) {
      await _tokenManager.destroySession(tokenId);
    } else {
      await _tokenManager.destroyRefreshToken(tokenId);
    }
  }

  @override
  Future<void> signOutOtherDevice({required UuidValue userId, required UuidValue targetTokenId}) async {
    final session = locator<AppSession>();
    final currentTokenId = session.authenticated?.tokenId;
    if (currentTokenId == null) throw const AccessDeniedException();

    // Validar re-identificación fresca
    await _ensureStepUpVerified(userId, currentTokenId);

    // Impedir que un usuario intente borrar una sesión que no le pertenece (Validando ownership)
    await (_db.delete(_db.refreshTokens)..where((t) => t.id.equals(targetTokenId) & t.userId.equals(userId))).go();
    await (_db.delete(_db.authSessions)..where((t) => t.id.equals(targetTokenId) & t.userId.equals(userId))).go();
  }

  @override
  Future<void> signOutAllDevices({required UuidValue userId}) async {
    await _tokenManager.destroyAllRefreshTokens(userId);
    await _tokenManager.destroyAllSessions(userId);
  }

  @override
  Future<void> signOutAllOtherDevices({required UuidValue userId, required UuidValue currentTokenId}) async {
    // Validar re-identificación fresca
    await _ensureStepUpVerified(userId, currentTokenId);

    // Eliminar todas las sesiones excepto la que está realizando la petición
    await (_db.delete(_db.refreshTokens)..where((t) => t.userId.equals(userId) & t.id.equals(currentTokenId).not())).go();
    await (_db.delete(_db.authSessions)..where((t) => t.userId.equals(userId) & t.id.equals(currentTokenId).not())).go();
  }
}
