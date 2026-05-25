import 'package:uuid/uuid.dart';

import '/src/generated/auth.pb.dart';

class AuthenticationInfo {
  final UuidValue userId;
  final Set<Scope> scopes;
  final UuidValue? tokenId; // El ID de la sesión SAS o el Refresh Token JWT actual

  const AuthenticationInfo({
    required this.userId,
    this.scopes = const {},
    this.tokenId,
  });
}
