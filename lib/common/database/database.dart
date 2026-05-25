import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_postgres/drift_postgres.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';
import 'package:yaml/yaml.dart';

import '/features/auth/data/database/auth_tables.dart';
import '/features/profile/data/database/profile_tables.dart';
import '/src/generated/auth.pb.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    AuthUsers,
    EmailOtpRequests,
    EmailVerificationRequests,
    PasswordResetRequests,
    AuthSessions,
    RefreshTokens,
    OidcAccounts,
    OidcStates,
    PasskeyAccounts,
    PasskeyChallenges,
    PublicProfiles,
    ProfileContactLinks,
    ProfileMergeRequests,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

AppDatabase connectToDatabase(YamlMap? config) {
  final dbConfig = config?['database'] as YamlMap?;

  // Prioriza variables de entorno, de lo contrario usa el YAML o valores por defecto
  final host = Platform.environment['DB_HOST'] ?? dbConfig?['host'] ?? '127.0.0.1';
  final port = int.tryParse(Platform.environment['DB_PORT'] ?? '') ?? dbConfig?['port'] ?? 5432;
  final dbName = Platform.environment['DB_NAME'] ?? dbConfig?['database'] ?? 'postgres';
  final username = Platform.environment['DB_USER'] ?? dbConfig?['username'] ?? 'postgres';
  final password = Platform.environment['DB_PASSWORD'] ?? dbConfig?['password'] ?? 'ExAdmin123';

  return AppDatabase(
    PgDatabase(
      endpoint: Endpoint(
        host: host,
        port: port,
        database: dbName,
        username: username,
        password: password,
      ),
      settings: ConnectionSettings(
        sslMode: SslMode.disable,
      ),
    ),
  );
}
