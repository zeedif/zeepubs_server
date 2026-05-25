import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/argon2.dart';

import '/common/utils/crypto_utils.dart';

/// Representa el resultado de una operación de hashing criptográfico.
class HashResult {
  final Uint8List hash;
  final Uint8List salt;

  HashResult({required this.hash, required this.salt});
}

/// Crea y valida hashes usando Argon2id.
class Hasher {
  final int _saltLength;

  Hasher({int saltLength = 16}) : _saltLength = saltLength;

  /// Crea un hash Argon2id desde bytes usando un pepper.
  /// Si no se proporciona un salt, genera uno nuevo.
  Future<HashResult> createArgon2Hash(Uint8List valueBytes, {required String pepper, Uint8List? salt}) async {
    final actualSalt = salt ?? generateRandomBytes(_saltLength);

    return Isolate.run(() {
      final params = Argon2Parameters(
        Argon2Parameters.ARGON2_id,
        actualSalt,
        desiredKeyLength: 32, // 32 bytes = 256 bits
        secret: utf8.encode(pepper),
        iterations: 4,
        memory: 65536, // 64 MB
      );

      final argon2 = Argon2BytesGenerator()..init(params);
      final hash = argon2.process(valueBytes);

      return HashResult(hash: hash, salt: actualSalt);
    });
  }

  /// Valida si unos bytes coinciden con un hash y salt de Argon2id.
  Future<bool> validateArgon2Hash(Uint8List valueBytes, String pepper, Uint8List hash, Uint8List salt) async {
    if (hash.isEmpty || salt.isEmpty) return false;

    final newHashResult = await createArgon2Hash(valueBytes, pepper: pepper, salt: salt);
    return uint8ListAreEqual(hash, newHashResult.hash);
  }
}
