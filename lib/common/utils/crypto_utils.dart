import 'dart:math';
import 'dart:typed_data';

/// Genera una secuencia de bytes aleatorios criptográficamente seguros.
Uint8List generateRandomBytes(int length) {
  final random = Random.secure();
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

/// Compara dos arreglos de bytes en tiempo constante (Constant-Time).
/// Esto es crucial para comparar hashes y secretos, ya que previene
/// ataques de tiempo (timing attacks) donde un atacante puede deducir
/// el secreto midiendo cuánto tarda la función en retornar 'false'.
bool uint8ListAreEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }

  var result = 0;
  for (var i = 0; i < a.length; i++) {
    // Usamos XOR (^). Si los bytes son iguales, a ^ b es 0.
    // Acumulamos las diferencias usando OR (|).
    result |= a[i] ^ b[i];
  }

  // Si el resultado final es 0, significa que todos los bytes fueron exactamente iguales.
  return result == 0;
}
