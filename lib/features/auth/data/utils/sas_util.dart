import 'dart:convert';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';

class SasUtil {
  static final _sessionKeyPrefix = utf8.encode('sas');

  /// Prefijo Base64 esperado del token.
  static final String prefixBase64 = base64Url.encode(_sessionKeyPrefix);

  /// Construye el token fusionando bytes y codificándolo en un solo Base64Url
  static String buildSessionToken(UuidValue sessionId, Uint8List secret) {
    final bytes = <int>[
      ..._sessionKeyPrefix,
      ...sessionId.toBytes(),
      ...secret,
    ];
    return base64Url.encode(bytes);
  }

  /// Descompone el token binario en UUID y Secreto
  static ({UuidValue id, Uint8List secret})? parseSessionToken(String token) {
    try {
      if (!token.startsWith(prefixBase64)) return null;

      final decoded = base64Url.decode(token);
      final prefixLength = _sessionKeyPrefix.length; // 3 bytes

      // El UUID siempre ocupa exactamente 16 bytes
      final uuidBytes = Uint8List.sublistView(decoded, prefixLength, prefixLength + 16);
      final serverSideSessionId = UuidValue.fromByteList(uuidBytes)..validate();

      // El secreto es el resto de los bytes
      final secret = Uint8List.sublistView(decoded, prefixLength + 16);

      return (id: serverSideSessionId, secret: secret);
    } catch (_) {
      return null;
    }
  }
}
