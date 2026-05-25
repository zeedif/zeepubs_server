import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '/common/database/uuid_custom_type.dart';
import '/src/generated/auth.pb.dart';

/// Conversor para almacenar Sets de permisos (Scopes) como una cadena de índices enteros (ej. "1,2,21") y viceversa.
class SetScopeConverter extends TypeConverter<Set<Scope>, String> {
  const SetScopeConverter();

  @override
  Set<Scope> fromSql(String fromDb) {
    if (fromDb.isEmpty) return {};
    return fromDb
        .split(',')
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .map((index) => Scope.valueOf(index))
        .whereType<Scope>()
        .toSet();
  }

  @override
  String toSql(Set<Scope> value) {
    return value.map((scope) => scope.value).join(',');
  }
}

/// Tabla de Usuarios
@DataClassName('AuthUserRow')
class AuthUsers extends Table {
  Column<UuidValue> get id => customType(uuidCustomType).clientDefault(() => const Uuid().v4obj())();
  TextColumn get username => text().unique()();
  TextColumn get email => text().nullable().unique()();
  TextColumn get passwordHash => text().nullable()();
  TextColumn get passwordSalt => text().nullable()();
  TextColumn get scopes => text().map(const SetScopeConverter())();
  BoolColumn get blocked => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get emailVerifiedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now().toUtc())();
  IntColumn get failedAttempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lockedUntil => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- FLUJOS DE VERIFICACIÓN Y RECUPERACIÓN ---

/// Tabla para solicitudes de inicio de sesión sin contraseña (Email OTP)
@DataClassName('EmailOtpRequestRow')
class EmailOtpRequests extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get email => text()();
  TextColumn get otpHash => text()();
  TextColumn get otpSalt => text()();
  DateTimeColumn get expiresAt => dateTime()();
}

/// Tabla para solicitudes de verificación de cuenta nueva (Email Verification)
@DataClassName('EmailVerificationRequestRow')
class EmailVerificationRequests extends Table {
  IntColumn get id => integer().autoIncrement()();
  Column<UuidValue> get userId => customType(uuidCustomType).references(AuthUsers, #id, onDelete: KeyAction.cascade)();
  TextColumn get verificationCodeHash => text()();
  TextColumn get verificationCodeSalt => text()();
  DateTimeColumn get expiresAt => dateTime()();
}

/// Tabla para solicitudes de restablecimiento de contraseña olvidada (Password Reset)
@DataClassName('PasswordResetRequestRow')
class PasswordResetRequests extends Table {
  IntColumn get id => integer().autoIncrement()();
  Column<UuidValue> get userId => customType(uuidCustomType).references(AuthUsers, #id, onDelete: KeyAction.cascade)();
  TextColumn get verificationCodeHash => text()();
  TextColumn get verificationCodeSalt => text()();
  DateTimeColumn get expiresAt => dateTime()();
}

// --- PERSISTENCIA DE SESIONES Y TOKENS ---

/// Tabla de Sesiones (SAS)
@DataClassName('AuthSessionRow')
class AuthSessions extends Table {
  Column<UuidValue> get id => customType(uuidCustomType).clientDefault(() => const Uuid().v4obj())();
  Column<UuidValue> get userId => customType(uuidCustomType).references(AuthUsers, #id, onDelete: KeyAction.cascade)();
  TextColumn get scopes => text().map(const SetScopeConverter())();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get lastUsedAt => dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  IntColumn get expireAfterUnusedForSeconds => integer().nullable()();
  BlobColumn get sessionKeyHash => blob()();
  BlobColumn get sessionKeySalt => blob()();
  TextColumn get method => text()();

  // Metadatos de Dispositivo y Red
  TextColumn get clientName => text()();
  TextColumn get clientType => text()();
  TextColumn get ipAddress => text()();

  // Re-verificación de Seguridad (Step-Up Auth)
  DateTimeColumn get lastReauthenticatedAt => dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tabla para Refresh Tokens (JWT)
@DataClassName('RefreshTokenRow')
class RefreshTokens extends Table {
  Column<UuidValue> get id => customType(uuidCustomType).clientDefault(() => const Uuid().v4obj())();
  Column<UuidValue> get userId => customType(uuidCustomType).references(AuthUsers, #id, onDelete: KeyAction.cascade)();
  TextColumn get scopes => text().map(const SetScopeConverter())();
  TextColumn get method => text()();
  BlobColumn get fixedSecret => blob()();
  BlobColumn get rotatingSecretHash => blob()();
  BlobColumn get rotatingSecretSalt => blob()();
  DateTimeColumn get lastUpdatedAt => dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now().toUtc())();

  // Metadatos de Dispositivo y Red
  TextColumn get clientName => text()();
  TextColumn get clientType => text()();
  TextColumn get ipAddress => text()();

  // Re-verificación de Seguridad (Step-Up Auth)
  DateTimeColumn get lastReauthenticatedAt => dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column> get primaryKey => {id};
}

// --- FEDERACIÓN EXTERNA Y PASSWORDLESS (FIDO2) ---

/// Tabla para vinculación con proveedores de identidad externos
@DataClassName('OidcAccountRow')
class OidcAccounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  Column<UuidValue> get userId => customType(uuidCustomType).references(AuthUsers, #id, onDelete: KeyAction.cascade)();
  TextColumn get issuer => text()();
  TextColumn get subject => text()();

  @override
  List<Set<Column>> get uniqueKeys => [{issuer, subject}];
}

/// Tabla temporal para mantener la integridad de los flujos OAuth2
@DataClassName('OidcStateRow')
class OidcStates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get state => text().unique()();
  TextColumn get nonce => text()();
  TextColumn get authStrategy => text()(); // 'JWT' o 'SESSION'
  DateTimeColumn get expiresAt => dateTime()();
}

/// Tabla para credenciales biométricas y llaves de seguridad
@DataClassName('PasskeyAccountRow')
class PasskeyAccounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  Column<UuidValue> get userId => customType(uuidCustomType).references(AuthUsers, #id, onDelete: KeyAction.cascade)();
  BlobColumn get credentialId => blob()();
  TextColumn get credentialIdBase64 => text().unique()();
  TextColumn get publicKey => text()(); // JSON (CborMap codificado)
  IntColumn get signCount => integer()();
  TextColumn get transports => text().nullable()(); // Almacenado como JSON/String
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now().toUtc())();
}

/// Tabla temporal para desafíos criptográficos de WebAuthn (Passkey Challenges)
@DataClassName('PasskeyChallengeRow')
class PasskeyChallenges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get challenge => text()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now().toUtc())();
}
