import 'dart:async';

import 'package:grpc/grpc.dart';

import '/features/auth/data/services/auth_token_manager.dart';

import '../di/service_locator.dart';

const _publicMethods = [
  '/zeepubs.auth.AuthService/SignUp',
  '/zeepubs.auth.AuthService/SignIn',
  '/zeepubs.auth.AuthService/StartEmailOtpSignIn',
  '/zeepubs.auth.AuthService/CompleteEmailOtpSignIn',
];

/// Expresión regular precompilada para extraer el token Bearer.
/// Tolera espacios en blanco irregulares y es insensible a mayúsculas/minúsculas.
final RegExp _bearerTokenRegex = RegExp(r'^Bearer\s+(.+)$', caseSensitive: false);

/// Interceptor gRPC: Rechaza llamadas sin token válido o expirado.
FutureOr<GrpcError?> authInterceptor(ServiceCall call, ServiceMethod method) async {
  // 1. Si el método es público, pasar de largo inmediatamente.
  if (_publicMethods.contains(method.name)) return null;

  // 2. Extraer cabecera Authorization
  final authHeader = call.clientMetadata?['authorization'];
  if (authHeader == null) return GrpcError.unauthenticated('Token JWT o SAS requerido en la cabecera Authorization.');

  // 3. Extracción segura mediante RegEx
  final match = _bearerTokenRegex.firstMatch(authHeader);
  final token = match?.group(1);

  if (token == null || token.isEmpty) return GrpcError.unauthenticated('Formato de cabecera inválido. Use "Bearer <token>".');

  final tokenManager = locator<AuthTokenManager>();

  // Validación mediante el manager maestro
  final authInfo = await tokenManager.validateToken(token);

  if (authInfo == null) {
    return GrpcError.unauthenticated('Token inválido, expirado o cuenta bloqueada.');
  }

  // Inyectar la información resuelta en la metadata
  call.clientMetadata?['user_id'] = authInfo.userId.toString();
  call.clientMetadata?['scopes'] = authInfo.scopes.map((s) => s.value).join(',');
  if (authInfo.tokenId != null) {
    call.clientMetadata?['token_id'] = authInfo.tokenId.toString();
  }

  return null;
}
