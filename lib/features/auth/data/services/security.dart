import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../../common/utils/crypto_utils.dart';
import '../../core/configs/security_config.dart';
import '../../core/configs/session_config.dart';
import 'hasher.dart';

export 'hasher.dart' show HashResult;

/// Orquesta los métodos criptográficos, garantizando transparencia
/// en los algoritmos empleados (Argon2id y SHA-512) y encapsulando
/// el uso de los peppers correctos para cada operación.
class Security {
  final Hasher _hasher;
  final SecurityConfig _securityConfig;
  final SessionConfig _sessionConfig;

  Security({
    required Hasher hasher,
    required SecurityConfig securityConfig,
    required SessionConfig sessionConfig,
  }) : _hasher = hasher,
       _securityConfig = securityConfig,
       _sessionConfig = sessionConfig;

  // =========================================================================
  // --- UTILIDADES GENERALES ---
  // =========================================================================

  /// Genera un código de 6 dígitos puramente numérico (Ej: OTP para correos).
  String generateVerificationCode() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10).toString()).join();
  }

  /// Genera una secuencia de bytes criptográficamente seguros.
  Uint8List generateCryptoRandomBytes(int length) {
    return generateRandomBytes(length);
  }

  // =========================================================================
  // --- ARGON 2 ID ---
  // =========================================================================

  // --- Contraseñas ---
  Future<HashResult> createPasswordHash(String password) {
    return _hasher.createArgon2Hash(utf8.encode(password), pepper: _securityConfig.passwordHashPepper);
  }

  Future<bool> validatePassword(String password, Uint8List hash, Uint8List salt) {
    return _hasher.validateArgon2Hash(utf8.encode(password), _securityConfig.passwordHashPepper, hash, salt);
  }

  // --- OTP de Inicio de Sesión ---
  Future<HashResult> createEmailOtpHash(String otp) {
    return _hasher.createArgon2Hash(utf8.encode(otp), pepper: _securityConfig.emailOtpHashPepper);
  }

  Future<bool> validateEmailOtp(String otp, Uint8List hash, Uint8List salt) {
    return _hasher.validateArgon2Hash(utf8.encode(otp), _securityConfig.emailOtpHashPepper, hash, salt);
  }

  // --- Código de Verificación de Email ---
  Future<HashResult> createEmailVerificationHash(String code) {
    return _hasher.createArgon2Hash(utf8.encode(code), pepper: _securityConfig.emailVerificationHashPepper);
  }

  Future<bool> validateEmailVerificationCode(String code, Uint8List hash, Uint8List salt) {
    return _hasher.validateArgon2Hash(utf8.encode(code), _securityConfig.emailVerificationHashPepper, hash, salt);
  }

  // --- Código de Reseteo de Contraseña ---
  Future<HashResult> createPasswordResetHash(String code) {
    return _hasher.createArgon2Hash(utf8.encode(code), pepper: _securityConfig.passwordResetHashPepper);
  }

  Future<bool> validatePasswordResetCode(String code, Uint8List hash, Uint8List salt) {
    return _hasher.validateArgon2Hash(utf8.encode(code), _securityConfig.passwordResetHashPepper, hash, salt);
  }

  // --- Refresh Tokens (usando bytes directamente) ---
  Future<HashResult> createRefreshTokenHash(Uint8List rotatingSecret) {
    return _hasher.createArgon2Hash(rotatingSecret, pepper: _securityConfig.refreshTokenHashPepper);
  }

  Future<bool> validateRefreshToken(Uint8List rotatingSecret, Uint8List hash, Uint8List salt) {
    return _hasher.validateArgon2Hash(rotatingSecret, _securityConfig.refreshTokenHashPepper, hash, salt);
  }

  // =========================================================================
  // --- SHA-512 (Sesiones SAS) ---
  // =========================================================================

  /// Crea un hash rápido SHA-512 combinado con el pepper de la configuración de sesión.
  /// Usado estrictamente para los tokens de sesión de corta duración.
  ({Uint8List hash, Uint8List salt}) createSasHash(Uint8List secret, {Uint8List? salt}) {
    final pepperBytes = utf8.encode(_sessionConfig.hashPepper);
    final actualSalt = salt ?? generateRandomBytes(16);
    final hash = Uint8List.fromList(sha512.convert([...secret, ...pepperBytes, ...actualSalt]).bytes);
    return (hash: hash, salt: actualSalt);
  }

  /// Valida un token de sesión SAS comparando su hash SHA-512 en tiempo constante.
  bool validateSasHash(Uint8List secret, Uint8List hash, Uint8List salt) {
    final calculated = createSasHash(secret, salt: salt);
    return uint8ListAreEqual(hash, calculated.hash);
  }
}
