import 'package:drift/drift.dart';
import 'package:drift_postgres/drift_postgres.dart';
import 'package:uuid/uuid.dart';

import '/features/auth/data/database/auth_tables.dart';

@DataClassName('PublicProfileRow')
class PublicProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  Column<UuidValue> get userId => customType(PgTypes.uuid).nullable().unique().references(AuthUsers, #id)();
  TextColumn get nickname => text()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get bio => text().nullable()();
}

@DataClassName('ProfileContactLinkRow')
class ProfileContactLinks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(PublicProfiles, #id)();
  IntColumn get nextContactLinkId => integer().nullable()();
  TextColumn get platform => text()();
  TextColumn get url => text()();
}

@DataClassName('ProfileMergeRequestRow')
class ProfileMergeRequests extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get targetProfileId => integer().references(PublicProfiles, #id)();
  IntColumn get sourceProfileId => integer().references(PublicProfiles, #id)();
  @ReferenceName('requestedMergeRequests')
  Column<UuidValue> get requesterId => customType(PgTypes.uuid).references(AuthUsers, #id)();
  @ReferenceName('resolvedMergeRequests')
  Column<UuidValue> get resolvedById => customType(PgTypes.uuid).nullable().references(AuthUsers, #id)();
  IntColumn get status => integer().withDefault(const Constant(0))(); // 0: Pending, 1: Approved, 2: Rejected
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
}
