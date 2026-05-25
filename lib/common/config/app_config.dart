import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:yaml/yaml.dart';

import '../../features/auth/core/configs/fido2_config.dart';
import '../../features/auth/core/configs/jwt_config.dart';
import '../../features/auth/core/configs/oidc_config.dart';
import '../../features/auth/core/configs/security_config.dart';
import '../../features/auth/core/configs/session_config.dart';

class AppConfigLoader {
  static const int _minPepperLength = 10;

  static void loadConfigs(
    YamlMap yaml,
    void Function<T extends Object>(T instance) register,
  ) {
    // Helper para leer valores requeridos
    T readRequired<T>(Map? map, String key, String section) {
      final value = map?[key];
      if (value == null) {
        throw ArgumentError(
          'Falta la configuración requerida "$key" en la sección "$section".',
        );
      }
      return value as T;
    }

    // Helper para leer y validar Peppers criptográficos
    String readRequiredPepper(Map? map, String key, String section) {
      final value = readRequired<String>(map, key, section);
      if (value.length < _minPepperLength) {
        throw ArgumentError(
          'El pepper "$key" en la sección "$section" debe tener al menos $_minPepperLength caracteres.',
        );
      }
      return value;
    }

    // 1. Parsear JWT
    final jwtMap = yaml['jwt'] as Map?;
    final jwtAlgo = jwtMap?['algorithm'] ?? 'HS512';
    JWTKey signKey, verificationKey;
    JWTAlgorithm algorithm;

    if (jwtAlgo == 'HS512') {
      final secret = readRequired<String>(jwtMap, 'secretKey', 'jwt');
      signKey = SecretKey(secret);
      verificationKey = SecretKey(secret);
      algorithm = JWTAlgorithm.HS512;
    } else {
      // Agregar soporte para ES512 si es necesario
      throw UnimplementedError(
        'Algoritmo JWT $jwtAlgo no implementado en el parser.',
      );
    }

    register<JwtConfig>(
      JwtConfig(
        issuer: jwtMap?['issuer'],
        algorithm: algorithm,
        signKey: signKey,
        verificationKey: verificationKey,
        accessTokenLifetime: Duration(
          minutes: jwtMap?['accessTokenMinutes'] ?? 15,
        ),
      ),
    );

    // 2. Parsear Session
    final sessionMap = yaml['session'] as Map?;
    register<SessionConfig>(
      SessionConfig(
        secretLength: sessionMap?['secretLength'] ?? 32,
        hashPepper: readRequiredPepper(sessionMap, 'hashPepper', 'session'),
        lifetime: Duration(days: sessionMap?['lifetimeDays'] ?? 30),
        inactivityTimeout: Duration(days: sessionMap?['inactivityDays'] ?? 7),
      ),
    );

    // 3. Parsear Security
    final rtMap = yaml['refreshToken'] as Map?;
    final secMap = yaml['security'] as Map?;
    register<SecurityConfig>(
      SecurityConfig(
        passwordHashPepper: readRequiredPepper(secMap, 'passwordHashPepper', 'security'),
        emailOtpHashPepper: readRequiredPepper(secMap, 'emailOtpHashPepper', 'security'),
        emailVerificationHashPepper: readRequiredPepper(secMap, 'emailVerificationHashPepper', 'security'),
        passwordResetHashPepper: readRequiredPepper(secMap, 'passwordResetHashPepper', 'security'),
        refreshTokenHashPepper: readRequiredPepper(rtMap, 'hashPepper', 'refreshToken'),
        sessionHashPepper: readRequiredPepper(sessionMap, 'hashPepper', 'session'),
        refreshTokenFixedSecretLength: rtMap?['fixedSecretLength'] ?? 16,
        refreshTokenRotatingSecretLength: rtMap?['rotatingSecretLength'] ?? 64,
        refreshTokenLifetime: Duration(days: rtMap?['lifetimeDays'] ?? 14),
      ),
    );

    // 4. Parsear OIDC (Opcional)
    final oidcMap = yaml['oidc'] as Map?;
    if (oidcMap != null) {
      register<OidcConfig>(
        OidcConfig(
          authority: readRequired<String>(oidcMap, 'authority', 'oidc'),
          clientId: readRequired<String>(oidcMap, 'clientId', 'oidc'),
          clientSecret: readRequired<String>(oidcMap, 'clientSecret', 'oidc'),
          redirectUri: readRequired<String>(oidcMap, 'redirectUri', 'oidc'),
        ),
      );
    }

    // 5. Parsear FIDO2 (Opcional)
    final fidoMap = yaml['fido2'] as Map?;
    if (fidoMap != null) {
      register<Fido2Config>(
        Fido2Config(
          rpId: readRequired<String>(fidoMap, 'rpId', 'fido2'),
          rpName: readRequired<String>(fidoMap, 'rpName', 'fido2'),
        ),
      );
    }
  }
}
