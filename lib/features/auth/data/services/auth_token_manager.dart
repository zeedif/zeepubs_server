import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '/common/database/database.dart';
import '/common/session/authentication_info.dart';
import '/common/utils/crypto_utils.dart';
import '/src/generated/auth.pb.dart';

import '../../core/configs/jwt_config.dart';
import '../../core/configs/security_config.dart';
import '../../core/configs/session_config.dart';
import '../../core/exceptions/auth_exceptions.dart';
import '../utils/jwt_util.dart';
import '../utils/sas_util.dart';
import 'security.dart';

class AuthTokenManager {
  final AppDatabase _db;
  final Security _security;
  final JwtConfig _jwtConfig;
  final SecurityConfig _securityConfig;
  final SessionConfig _sessionConfig;

  AuthTokenManager(
    this._db,
    this._security, {
    required JwtConfig jwtConfig,
    required SecurityConfig securityConfig,
    required SessionConfig sessionConfig,
  }) : _jwtConfig = jwtConfig,
       _securityConfig = securityConfig,
       _sessionConfig = sessionConfig;

  // =========================================================================
  // --- VALIDACIÓN DE TOKENS ---
  // =========================================================================

  /// Valida un token crudo y retorna la identidad del usuario si es válido.
  Future<AuthenticationInfo?> validateToken(String token) async {
    try {
      AuthenticationInfo? info;

      // 'eyJ' es '{"' en Base64, que es el inicio de JWT.
      if (token.startsWith(SasUtil.prefixBase64)) {
        info = await _validateSas(token);
      } else if (token.startsWith('eyJ')) {
        info = await _validateJwt(token);
      } else {
        return null; // Token no reconocido
      }

      if (info == null) return null;

      // Verificar que el usuario sigue existiendo y no está bloqueado
      final user = await (_db.select(_db.authUsers)..where((t) => t.id.equals(info!.userId))).getSingleOrNull();
      if (user == null || user.blocked || !user.isActive) return null;

      return info;
    } catch (_) {
      return null;
    }
  }

  Future<AuthenticationInfo?> _validateSas(String token) async {
    final parsed = SasUtil.parseSessionToken(token);
    if (parsed == null) return null;

    final sessionRow = await (_db.select(_db.authSessions)..where((t) => t.id.equals(parsed.id))).getSingleOrNull();
    if (sessionRow == null) return null;

    final now = DateTime.now().toUtc();
    if (sessionRow.expiresAt != null && now.isAfter(sessionRow.expiresAt!)) return null;
    
    if (sessionRow.expireAfterUnusedForSeconds != null) {
      final expireDate = sessionRow.lastUsedAt.add(Duration(seconds: sessionRow.expireAfterUnusedForSeconds!));
      if (now.isAfter(expireDate)) return null;
    }

    if (!_security.validateSasHash(parsed.secret, sessionRow.sessionKeyHash, sessionRow.sessionKeySalt)) {
      return null;
    }

    // Actualiza el timestamp si pasó más de un minuto
    if (now.difference(sessionRow.lastUsedAt).inMinutes >= 1) {
      await (_db.update(_db.authSessions)..where((t) => t.id.equals(sessionRow.id)))
          .write(AuthSessionsCompanion(lastUsedAt: Value(now)));
    }

    return AuthenticationInfo(
      userId: sessionRow.userId, 
      scopes: sessionRow.scopes,
      tokenId: sessionRow.id,
    );
  }

  Future<AuthenticationInfo?> _validateJwt(String token) async {
    final payload = JwtUtil.verifyJwt(token, _jwtConfig);
    if (payload == null) return null;
    return AuthenticationInfo(
      userId: payload.userId, 
      scopes: payload.scopes,
      tokenId: payload.refreshTokenId,
    );
  }

  // =========================================================================
  // --- CREACIÓN Y ROTACIÓN DE TOKENS ---
  // =========================================================================

  /// Emite un nuevo par de tokens JWT.
  Future<AuthSuccess> issueJwtTokens(
    UuidValue authUserId, 
    String method, 
    Set<Scope> scopes,
    String clientName,
    String clientType,
    String ipAddress,
  ) async {
    final fixedSecret = _security.generateCryptoRandomBytes(_securityConfig.refreshTokenFixedSecretLength);
    final rotatingSecret = _security.generateCryptoRandomBytes(_securityConfig.refreshTokenRotatingSecretLength);
    final hashResult = await _security.createRefreshTokenHash(rotatingSecret);

    final now = DateTime.now().toUtc();

    final refreshTokenRow = await _db.into(_db.refreshTokens).insertReturning(
      RefreshTokensCompanion.insert(
        userId: authUserId,
        scopes: scopes,
        method: method,
        fixedSecret: fixedSecret,
        rotatingSecretHash: hashResult.hash,
        rotatingSecretSalt: hashResult.salt,
        createdAt: Value(now),
        lastUpdatedAt: Value(now),
        lastReauthenticatedAt: Value(now),
        clientName: clientName,
        clientType: clientType,
        ipAddress: ipAddress,
      ),
    );

    final accessToken = JwtUtil.createJwt(authUserId, refreshTokenRow.id, scopes, _jwtConfig);
    final refreshTokenStr = JwtUtil.buildRefreshTokenString(refreshTokenRow.id, fixedSecret, rotatingSecret);

    return AuthSuccess(
      authStrategy: AuthStrategy.JWT.name,
      token: accessToken,
      refreshToken: refreshTokenStr,
      userId: authUserId.toString(),
      scopeIds: scopes.map((s) => s.value), 
    );
  }

  /// Rota un Refresh Token (Invalida el anterior y genera un nuevo par Access/Refresh).
  Future<AuthSuccess> rotateRefreshToken(String refreshTokenStr) async {
    final parsed = JwtUtil.parseRefreshTokenString(refreshTokenStr);
    
    final row = await (_db.select(_db.refreshTokens)..where((t) => t.id.equals(parsed.id))).getSingleOrNull();
    if (row == null || !uint8ListAreEqual(row.fixedSecret, parsed.fixedSecret)) {
      throw RefreshTokenInvalidException();
    }

    // Verificar expiración del refresh token
    final oldestValid = DateTime.now().toUtc().subtract(_securityConfig.refreshTokenLifetime);
    if (row.lastUpdatedAt.isBefore(oldestValid)) {
      await destroyRefreshToken(row.id);
      throw RefreshTokenExpiredException();
    }

    final isValidHash = await _security.validateRefreshToken(
      parsed.rotatingSecret, 
      row.rotatingSecretHash, 
      row.rotatingSecretSalt
    );

    if (!isValidHash) {
      await destroyRefreshToken(row.id);
      throw RefreshTokenCompromisedException();
    }

    // Generar nuevo secreto rotativo
    final newSecret = _security.generateCryptoRandomBytes(_securityConfig.refreshTokenRotatingSecretLength);
    final newHash = await _security.createRefreshTokenHash(newSecret);

    final _ = await (_db.update(_db.refreshTokens)..where((t) => t.id.equals(row.id))).writeReturning(
      RefreshTokensCompanion(
        rotatingSecretHash: Value(newHash.hash),
        rotatingSecretSalt: Value(newHash.salt),
        lastUpdatedAt: Value(DateTime.now().toUtc()),
      ),
    );

    final accessToken = JwtUtil.createJwt(row.userId, row.id, row.scopes, _jwtConfig);
    final newRefreshTokenStr = JwtUtil.buildRefreshTokenString(row.id, row.fixedSecret, newSecret);

    return AuthSuccess(
      authStrategy: AuthStrategy.JWT.name,
      token: accessToken,
      refreshToken: newRefreshTokenStr,
      userId: row.userId.toString(),
      scopeIds: row.scopes.map((s) => s.value),
    );
  }

  /// Emite un nuevo token SAS.
  Future<AuthSuccess> issueSasToken(
    UuidValue authUserId, 
    String method, 
    Set<Scope> scopes,
    String clientName,
    String clientType,
    String ipAddress,
  ) async {
    final secret = _security.generateCryptoRandomBytes(_sessionConfig.secretLength);
    final hashResult = _security.createSasHash(secret);
    final now = DateTime.now().toUtc();

    final sessionRow = await _db.into(_db.authSessions).insertReturning(
      AuthSessionsCompanion.insert(
        userId: authUserId,
        scopes: scopes,
        method: method,
        sessionKeyHash: hashResult.hash,
        sessionKeySalt: hashResult.salt,
        createdAt: Value(now),
        lastUsedAt: Value(now),
        lastReauthenticatedAt: Value(now),
        expiresAt: Value(now.add(_sessionConfig.lifetime)),
        expireAfterUnusedForSeconds: Value(_sessionConfig.inactivityTimeout.inSeconds),
        clientName: clientName,
        clientType: clientType,
        ipAddress: ipAddress,
      ),
    );

    final token = SasUtil.buildSessionToken(sessionRow.id, secret);

    return AuthSuccess(
      authStrategy: AuthStrategy.SESSION.name,
      token: token,
      userId: authUserId.toString(),
      scopeIds: scopes.map((s) => s.value),
    );
  }

  // =========================================================================
  // --- REVOCACIÓN Y LIMPIEZA ---
  // =========================================================================

  Future<void> destroyRefreshToken(UuidValue tokenId) async {
    await (_db.delete(_db.refreshTokens)..where((t) => t.id.equals(tokenId))).go();
  }

  Future<void> destroyAllRefreshTokens(UuidValue userId) async {
    await (_db.delete(_db.refreshTokens)..where((t) => t.userId.equals(userId))).go();
  }

  Future<void> destroySession(UuidValue sessionId) async {
    await (_db.delete(_db.authSessions)..where((t) => t.id.equals(sessionId))).go();
  }

  Future<void> destroyAllSessions(UuidValue userId) async {
    await (_db.delete(_db.authSessions)..where((t) => t.userId.equals(userId))).go();
  }

  /// Función para CronJobs: Limpia tokens expirados de la BD
  Future<void> cleanupExpiredTokens() async {
    final now = DateTime.now().toUtc();
    final expiredJwtLimit = now.subtract(_securityConfig.refreshTokenLifetime);

    await (_db.delete(_db.refreshTokens)..where((t) => t.lastUpdatedAt.isSmallerThanValue(expiredJwtLimit))).go();
    
    // Para las sesiones SAS que tengan fecha de expiración absoluta
    await (_db.delete(_db.authSessions)..where((t) => t.expiresAt.isNotNull() & t.expiresAt.isSmallerThanValue(now))).go();
  }
}
