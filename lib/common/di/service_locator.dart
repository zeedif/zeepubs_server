import 'package:get_it/get_it.dart';
import 'package:yaml/yaml.dart';

import '/features/auth/core/configs/auth_config.dart';
import '/features/auth/core/configs/fido2_config.dart';
import '/features/auth/core/configs/jwt_config.dart';
import '/features/auth/core/configs/oidc_config.dart';
import '/features/auth/core/configs/security_config.dart';
import '/features/auth/core/configs/session_config.dart';
import '/features/auth/core/repositories/auth_repo.dart';
import '/features/auth/core/use_cases/classic/create_user.dart';
import '/features/auth/core/use_cases/classic/sign_in.dart';
import '/features/auth/core/use_cases/classic/sign_up.dart';
import '/features/auth/core/use_cases/email_otp/finish_email_otp_sign_in.dart';
import '/features/auth/core/use_cases/email_otp/start_email_otp_sign_in.dart';
import '/features/auth/core/use_cases/email_verification/finish_email_verification.dart';
import '/features/auth/core/use_cases/email_verification/start_email_verification.dart';
import '/features/auth/core/use_cases/passkey/finish_fido2_authentication.dart';
import '/features/auth/core/use_cases/passkey/finish_fido2_registration.dart';
import '/features/auth/core/use_cases/passkey/generate_fido2_authentication_challenge.dart';
import '/features/auth/core/use_cases/passkey/generate_fido2_registration_challenge.dart';
import '/features/auth/core/use_cases/password_reset/finish_password_reset.dart';
import '/features/auth/core/use_cases/password_reset/force_password_change.dart';
import '/features/auth/core/use_cases/password_reset/start_password_reset.dart';
import '/features/auth/core/use_cases/sessions/get_active_sessions.dart';
import '/features/auth/core/use_cases/sessions/reauthenticate.dart';
import '/features/auth/core/use_cases/sessions/sign_out_all_devices.dart';
import '/features/auth/core/use_cases/sessions/sign_out_all_other_devices.dart';
import '/features/auth/core/use_cases/sessions/sign_out_device.dart';
import '/features/auth/core/use_cases/sessions/sign_out_other_device.dart';
import '/features/auth/data/repositories/auth_repo_impl.dart';
import '/features/auth/data/services/auth_token_manager.dart';
import '/features/auth/data/services/fido2_handler.dart';
import '/features/auth/data/services/hasher.dart';
import '/features/auth/data/services/oidc_handler.dart';
import '/features/auth/data/services/security.dart';
import '/features/profile/core/repositories/profile_repo.dart';
import '/features/profile/core/use_cases/commands/add_profile_contact_link.dart';
import '/features/profile/core/use_cases/commands/approve_profile_merge_request.dart';
import '/features/profile/core/use_cases/commands/create_profile_merge_request.dart';
import '/features/profile/core/use_cases/commands/reject_profile_merge_request.dart';
import '/features/profile/core/use_cases/commands/remove_profile_contact_link.dart';
import '/features/profile/core/use_cases/commands/reorder_profile_contact_links.dart';
import '/features/profile/core/use_cases/commands/update_profile.dart';
import '/features/profile/core/use_cases/commands/update_profile_contact_link.dart';
import '/features/profile/core/use_cases/queries/get_profile_id.dart';
import '/features/profile/core/use_cases/queries/get_profile_merge_requests.dart';
import '/features/profile/core/use_cases/queries/get_profile_uuid.dart';
import '/features/profile/core/use_cases/queries/get_profiles.dart';
import '/features/profile/data/repositories/profile_repo_impl.dart';
import '/src/generated/auth.pb.dart';
import '/src/generated/profile.pb.dart';

import '../config/app_config.dart';
import '../database/database.dart';
import '../database/drift_tx.dart';
import '../database/transactional.dart';
import '../mail/fake_email_service.dart';
import '../mediator/mediator.dart';

final locator = GetIt.instance;

void setupLocator(YamlMap config) {
  // 1. Base de datos
  final database = connectToDatabase();
  locator.registerSingleton<AppDatabase>(database);
  locator.registerSingleton<Transactional>(DriftTx(database));

  // 2. Inyectar configuraciones
  AppConfigLoader.loadConfigs(config, <T extends Object>(T instance) {
    locator.registerSingleton<T>(instance);
  });

  // 3. Servicios de Datos (Data services)

  // 3.1 Criptografía
  locator.registerLazySingleton<Hasher>(() => Hasher());

  locator.registerLazySingleton<Security>(
    () => Security(
      hasher: locator<Hasher>(),
      securityConfig: locator<SecurityConfig>(),
      sessionConfig: locator<SessionConfig>(),
    ),
  );

  // 3.2 Gestión de tokens para JWT y SAS
  locator.registerLazySingleton<AuthTokenManager>(
    () => AuthTokenManager(
      locator<AppDatabase>(),
      locator<Security>(),
      jwtConfig: locator<JwtConfig>(),
      securityConfig: locator<SecurityConfig>(),
      sessionConfig: locator<SessionConfig>(),
    ),
  );

  // 3.3 OIDC
  if (locator.isRegistered<OidcConfig>()) {
    locator.registerLazySingleton<OidcHandler>(() => OidcHandler(locator<OidcConfig>(), locator<AppDatabase>()));
  }

  // 3.4 FIDO2
  if (locator.isRegistered<Fido2Config>()) {
    locator.registerLazySingleton<Fido2Handler>(() => Fido2Handler(locator<Fido2Config>()));
  }

  // 4. Repositorios (Data implementations bound to Domain contracts)
  locator.registerLazySingleton<IAuthRepository>(
    () => AuthRepositoryImpl(
      locator<AppDatabase>(),
      locator<AuthTokenManager>(),
      locator<Security>(),
      locator<AuthConfig>(),
      locator<FakeEmailService>(),
      locator.isRegistered<OidcConfig>() ? locator<OidcHandler>() : null,
      locator.isRegistered<Fido2Config>() ? locator<Fido2Handler>() : null,
    ),
  );

  // Repositorios del Módulo Perfil
  locator.registerLazySingleton<IProfileRepository>(
    () => ProfileRepositoryImpl(locator<AppDatabase>()),
  );

  // 5. Mediator
  locator.registerLazySingleton<Mediator>(() {
    final mediator = Mediator(locator);

    // --- Flujo de Registro ---
    mediator.registerHandler<SignUpCommand, AuthSuccess, SignUpHandler>();
    mediator.registerHandler<CreateUserCommand, CreateUserResponse, CreateUserHandler>();

    // --- Flujos de Inicio de Sesión ---
    mediator.registerHandler<SignInCommand, AuthSuccess, SignInHandler>();
    mediator.registerHandler<StartEmailOtpSignInCommand, void, StartEmailOtpSignInHandler>();
    mediator.registerHandler<FinishEmailOtpSignInCommand, AuthSuccess, FinishEmailOtpSignInHandler>();

    // --- Flujos de Passkey (FIDO2) ---
    mediator.registerHandler<GenerateFido2RegistrationChallengeQuery, Fido2ChallengeResponse, GenerateFido2RegistrationChallengeHandler>();
    mediator.registerHandler<FinishFido2RegistrationCommand, void, FinishFido2RegistrationHandler>();
    mediator.registerHandler<GenerateFido2AuthenticationChallengeQuery, Fido2ChallengeResponse, GenerateFido2AuthenticationChallengeHandler>();
    mediator.registerHandler<FinishFido2AuthenticationCommand, AuthSuccess, FinishFido2AuthenticationHandler>();

    // --- Gestión de Contraseña y Correo ---
    mediator.registerHandler<StartPasswordResetCommand, void, StartPasswordResetHandler>();
    mediator.registerHandler<FinishPasswordResetCommand, AuthSuccess, FinishPasswordResetHandler>();
    mediator.registerHandler<ForcePasswordChangeCommand, void, ForcePasswordChangeHandler>();
    mediator.registerHandler<StartEmailVerificationCommand, void, StartEmailVerificationHandler>();
    mediator.registerHandler<FinishEmailVerificationCommand, void, FinishEmailVerificationHandler>();

    // --- Gestión de Sesiones y Seguridad (Step-Up) ---
    mediator.registerHandler<GetActiveSessionsQuery, ActiveSessionsResponse, GetActiveSessionsHandler>();
    mediator.registerHandler<ReauthenticateCommand, void, ReauthenticateHandler>();
    mediator.registerHandler<SignOutDeviceCommand, void, SignOutDeviceHandler>();
    mediator.registerHandler<SignOutOtherDeviceCommand, void, SignOutOtherDeviceHandler>();
    mediator.registerHandler<SignOutAllDevicesCommand, void, SignOutAllDevicesHandler>();
    mediator.registerHandler<SignOutAllOtherDevicesCommand, void, SignOutAllOtherDevicesHandler>();

    // --- Módulo: Perfiles Públicos ---
    mediator.registerHandler<GetProfileByIdQuery, PublicProfile, GetProfileByIdHandler>();
    mediator.registerHandler<GetProfileByUuidQuery, PublicProfile, GetProfileByUuidHandler>();
    mediator.registerHandler<UpdateProfileCommand, PublicProfile, UpdateProfileHandler>();
    mediator.registerHandler<GetProfilesQuery, PaginatedProfilesData, GetProfilesHandler>();

    // --- Módulo: Enlaces de Contacto ---
    mediator.registerHandler<AddProfileContactLinkCommand, ProfileContactLink, AddProfileContactLinkHandler>();
    mediator.registerHandler<RemoveProfileContactLinkCommand, void, RemoveProfileContactLinkHandler>();
    mediator.registerHandler<UpdateProfileContactLinkCommand, ProfileContactLink, UpdateProfileContactLinkHandler>();
    mediator.registerHandler<ReorderProfileContactLinksCommand, void, ReorderProfileContactLinksHandler>();

    // --- Módulo: Fusión de Perfiles ---
    mediator.registerHandler<CreateProfileMergeRequestCommand, ProfileMergeRequest, CreateProfileMergeRequestHandler>();
    mediator.registerHandler<GetProfileMergeRequestsQuery, List<ProfileMergeRequest>, GetProfileMergeRequestsHandler>();
    mediator.registerHandler<ApproveProfileMergeRequestCommand, ProfileMergeRequest, ApproveProfileMergeRequestHandler>();
    mediator.registerHandler<RejectProfileMergeRequestCommand, ProfileMergeRequest, RejectProfileMergeRequestHandler>();

    return mediator;
  });

  // 6. RequestHandlers (Features)

  // Auth Handlers - Flujo de Registro
  locator.registerFactory(() => SignUpHandler(locator<Transactional>(), locator<IAuthRepository>()));
  locator.registerFactory(() => CreateUserHandler(locator<Transactional>(), locator<IAuthRepository>()));

  // Auth Handlers - Flujos de Inicio de Sesión
  locator.registerFactory(() => SignInHandler(locator<Transactional>(), locator<IAuthRepository>()));
  locator.registerFactory(() => StartEmailOtpSignInHandler(locator<Transactional>(), locator<IAuthRepository>()));
  locator.registerFactory(() => FinishEmailOtpSignInHandler(locator<Transactional>(), locator<IAuthRepository>()));

  // Auth Handlers - Flujos de Passkey (FIDO2)
  locator.registerFactory(
    () => GenerateFido2RegistrationChallengeHandler(locator<Transactional>(), locator<IAuthRepository>()),
  );
  locator.registerFactory(() => FinishFido2RegistrationHandler(locator<IAuthRepository>()));
  locator.registerFactory(
    () => GenerateFido2AuthenticationChallengeHandler(locator<Transactional>(), locator<IAuthRepository>()),
  );
  locator.registerFactory(() => FinishFido2AuthenticationHandler(locator<Transactional>(), locator<IAuthRepository>()));

  // Auth Handlers - Gestión de Contraseña y Correo
  locator.registerFactory(() => StartPasswordResetHandler(locator<Transactional>(), locator<IAuthRepository>()));
  locator.registerFactory(() => FinishPasswordResetHandler(locator<Transactional>(), locator<IAuthRepository>()));
  locator.registerFactory(() => ForcePasswordChangeHandler(locator<Transactional>(), locator<IAuthRepository>()));
  locator.registerFactory(() => StartEmailVerificationHandler(locator<Transactional>(), locator<IAuthRepository>()));
  locator.registerFactory(() => FinishEmailVerificationHandler(locator<Transactional>(), locator<IAuthRepository>()));

  // Auth Handlers - Gestión de Sesiones y Seguridad (Step-Up)
  locator.registerFactory(() => GetActiveSessionsHandler(locator<IAuthRepository>()));
  locator.registerFactory(() => ReauthenticateHandler(locator<IAuthRepository>()));
  locator.registerFactory(() => SignOutDeviceHandler(locator<IAuthRepository>()));
  locator.registerFactory(() => SignOutOtherDeviceHandler(locator<IAuthRepository>()));
  locator.registerFactory(() => SignOutAllDevicesHandler(locator<IAuthRepository>()));
  locator.registerFactory(() => SignOutAllOtherDevicesHandler(locator<IAuthRepository>()));

  // Profile Handlers - Perfiles Públicos
  locator.registerFactory(() => GetProfileByIdHandler(locator<IProfileRepository>()));
  locator.registerFactory(() => GetProfileByUuidHandler(locator<IProfileRepository>()));
  locator.registerFactory(() => UpdateProfileHandler(locator<Transactional>(), locator<IProfileRepository>()));
  locator.registerFactory(() => GetProfilesHandler(locator<IProfileRepository>()));

  locator.registerFactory(() => AddProfileContactLinkHandler(locator<Transactional>(), locator<IProfileRepository>()));
  locator.registerFactory(() => RemoveProfileContactLinkHandler(locator<Transactional>(), locator<IProfileRepository>()));
  locator.registerFactory(() => UpdateProfileContactLinkHandler(locator<Transactional>(), locator<IProfileRepository>()));
  locator.registerFactory(() => ReorderProfileContactLinksHandler(locator<Transactional>(), locator<IProfileRepository>()));

  locator.registerFactory(() => CreateProfileMergeRequestHandler(locator<Transactional>(), locator<IProfileRepository>()));
  locator.registerFactory(() => GetProfileMergeRequestsHandler(locator<IProfileRepository>()));
  locator.registerFactory(() => ApproveProfileMergeRequestHandler(locator<Transactional>(), locator<IProfileRepository>()));
  locator.registerFactory(() => RejectProfileMergeRequestHandler(locator<Transactional>(), locator<IProfileRepository>()));
}
