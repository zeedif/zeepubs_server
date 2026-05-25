import 'package:drift/drift.dart';
import 'package:drift_postgres/drift_postgres.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '/features/auth/data/database/auth_tables.dart';
import '/features/profile/data/database/profile_tables.dart';
import '/src/generated/auth.pb.dart';

import 'uuid_custom_type.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

AppDatabase connectToDatabase() {
  return AppDatabase(
    PgDatabase(
      endpoint: Endpoint(
        host: 'localhost',
        port: 8090,
        database: 'zeepubs_db',
        username: 'postgres',
        password: 'tu_password',
      ),
    ),
  );
}
