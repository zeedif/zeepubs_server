import 'dart:convert';

import 'package:cbor/cbor.dart';
import 'package:fido2/fido2.dart';

import '../../core/configs/fido2_config.dart' as f;

class Fido2Handler {
  final f.Fido2Config _config;
  late final Fido2Server _fido2server;

  Fido2Handler(this._config) {
    _fido2server = Fido2Server(Fido2Config(rpId: _config.rpId, rpName: _config.rpName));
  }

  Map<String, dynamic> generateRegistrationOptions({required String username, required String userDisplayName}) {
    return _fido2server.generateRegistrationOptions(username, userDisplayName);
  }

  RegistrationResult completeRegistration({
    required String clientDataBase64,
    required String attestationObjectBase64,
    required String expectedChallenge,
  }) {
    return _fido2server.completeRegistration(clientDataBase64, attestationObjectBase64, expectedChallenge);
  }

  Map<String, dynamic> generateAuthenticationOptions() {
    return _fido2server.generateVerificationOptions();
  }

  Future<VerificationResult> completeAuthentication({
    required String clientDataBase64,
    required String authenticatorDataBase64,
    required String signatureBase64,
    required String expectedChallenge,
    required String credentialPublicKey, 
    required int storedSignCount,
  }) async {
    final Map<String, dynamic> publicKeyJson = jsonDecode(credentialPublicKey);
    final Map<int, dynamic> coseKeyMap = publicKeyJson.map((key, value) => MapEntry(int.parse(key), value));
    final cborMap = CborValue(coseKeyMap) as CborMap;

    return _fido2server.completeVerification(
      clientDataBase64,
      authenticatorDataBase64,
      signatureBase64,
      expectedChallenge,
      cborMap,
      storedSignCount,
    );
  }
}
