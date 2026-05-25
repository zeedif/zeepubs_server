import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JwtConfig {
  final String? issuer;
  final JWTAlgorithm algorithm;
  final JWTKey signKey;
  final JWTKey verificationKey;
  final Duration accessTokenLifetime;

  JwtConfig({
    required this.issuer,
    required this.algorithm,
    required this.signKey,
    required this.verificationKey,
    required this.accessTokenLifetime,
  });
}
