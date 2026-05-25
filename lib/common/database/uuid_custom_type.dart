import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

// Tipo para SQLite (Fallback) - Guarda como TEXT
class UuidSqliteType implements CustomSqlType<UuidValue> {
  const UuidSqliteType();

  @override
  String mapToSqlLiteral(UuidValue dartValue) => "'${dartValue.uuid}'";

  @override
  Object mapToSqlParameter(UuidValue dartValue) => dartValue.uuid;

  @override
  UuidValue read(Object fromSql) => UuidValue.fromString(fromSql as String);

  @override
  String sqlTypeName(GenerationContext context) => 'text';
}

// Tipo para Postgres - Guarda nativamente como UUID
class UuidPostgresType implements CustomSqlType<UuidValue> {
  const UuidPostgresType();

  @override
  String mapToSqlLiteral(UuidValue dartValue) => "'${dartValue.uuid}'";

  @override
  Object mapToSqlParameter(UuidValue dartValue) => dartValue.uuid;

  @override
  UuidValue read(Object fromSql) => UuidValue.fromString(fromSql as String);

  @override
  String sqlTypeName(GenerationContext context) => 'uuid';
}

// Tipo consciente del dialecto
const uuidCustomType = DialectAwareSqlType<UuidValue>.via(
  fallback: UuidSqliteType(),
  overrides: {SqlDialect.postgres: UuidPostgresType()},
);
