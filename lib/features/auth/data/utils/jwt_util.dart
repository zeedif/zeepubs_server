import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:uuid/uuid.dart';

import '/src/generated/auth.pb.dart';

import '../../core/configs/jwt_config.dart';

class JwtUtil {
  static const _prefix = 'zjwt';
  static const _claimScopes = 'dev.zeepubs.scopeNames';
  static const _claimRefreshId = 'dev.zeepubs.refreshTokenId';

  /// Construye el string base64 del Refresh Token
  static String buildRefreshTokenString(UuidValue id, Uint8List fixedSecret, Uint8List rotatingSecret) {
    return '$_prefix:${base64Url.encode(id.toBytes())}:${base64Url.encode(fixedSecret)}:${base64Url.encode(rotatingSecret)}';
  }

  /// Descompone el string del Refresh Token
  static ({UuidValue id, Uint8List fixedSecret, Uint8List rotatingSecret}) parseRefreshTokenString(String token) {
    final parts = token.split(':');
    if (parts.length != 4 || parts[0] != _prefix) {
      throw ArgumentError('Refresh token malformado o prefijo inválido.');
    }
    return (
      id: UuidValue.fromByteList(base64Url.decode(parts[1])),
      fixedSecret: base64Url.decode(parts[2]),
      rotatingSecret: base64Url.decode(parts[3]),
    );
  }

  /// Crea el Access Token JWT
  static String createJwt(UuidValue authUserId, UuidValue refreshTokenId, Set<Scope> scopes, JwtConfig config) {
    final jwt = JWT(
      {
        if (scopes.isNotEmpty) _claimScopes: scopes.map((s) => s.value).toList(),
        _claimRefreshId: refreshTokenId.toString(),
      },
      jwtId: const Uuid().v4obj().toString(),
      subject: authUserId.toString(),
      issuer: config.issuer,
    );
    return jwt.sign(
      config.signKey,
      algorithm: config.algorithm,
      expiresIn: config.accessTokenLifetime,
    );
  }

  /// Verifica la firma del JWT y extrae los datos. Retorna nulo si es inválido.
  static ({UuidValue userId, UuidValue refreshTokenId, Set<Scope> scopes, DateTime expiresAt})? verifyJwt(String token, JwtConfig config) {
    try {
      final jwt = JWT.verify(
        token,
        config.verificationKey,
        issuer: config.issuer,
      );
      final userId = UuidValue.fromString(jwt.subject!);
      final refreshTokenId = UuidValue.fromString(jwt.payload[_claimRefreshId] as String);
      final scopeIdsClaim = jwt.payload[_claimScopes] as List?;
      final Set<Scope> scopes = scopeIdsClaim?.map((e) => Scope.valueOf(e as int)).whereType<Scope>().toSet() ?? {};
      final exp = jwt.payload['exp'];
      final expiresAt = DateTime.fromMillisecondsSinceEpoch((exp * 1000).toInt(), isUtc: true);

      return (userId: userId, refreshTokenId: refreshTokenId, scopes: scopes, expiresAt: expiresAt);
    } catch (_) {
      return null;
    }
  }
}
