import 'dart:io';

import 'package:grpc/grpc.dart' as grpc;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:yaml/yaml.dart';

import 'package:zeepubs_server/common/di/service_locator.dart';
import 'package:zeepubs_server/common/grpc/auth_interceptor.dart';
import 'package:zeepubs_server/common/mediator/mediator.dart';
import 'package:zeepubs_server/features/auth/core/use_cases/oidc/sign_in_with_oidc.dart';
import 'package:zeepubs_server/features/auth/data/jobs/token_cleanup_job.dart';
import 'package:zeepubs_server/features/auth/data/services/oidc_handler.dart';
import 'package:zeepubs_server/features/auth/presentation/auth_service_impl.dart';
import 'package:zeepubs_server/src/generated/auth.pb.dart';

import 'generate_l10n.dart';

void main(List<String> args) async {
  // 0. Ejecutar la tarea de pre-construcción de localización
  try {
    generateL10n();
  } catch (e) {
    print('❌ Error crítico en pre-construcción de L10n: $e');
    exit(1);
  }

  // Cargar configuración desde YAML
  final configFile = File('app_config.yaml');
  if (!await configFile.exists()) {
    print('❌ Error: El archivo de configuración "app_config.yaml" no fue encontrado.');
    exit(1);
  }
  final configString = await configFile.readAsString();
  final mapConfig = loadYaml(configString) as YamlMap;

  // 1. Iniciar Inyección de Dependencias
  setupLocator(mapConfig);

  // Iniciar el Job de Limpieza en segundo plano
  TokenCleanupJob.start();

  // 2. Levantar Servidor gRPC (Puerto 8080)
  final grpcServer = grpc.Server.create(
    services: [
      AuthServiceImpl(),
      // ProfileServiceImpl(),
    ],
    interceptors: [authInterceptor],
  );

  await grpcServer.serve(port: 8080);
  print('✅ Servidor gRPC escuchando en puerto ${grpcServer.port}...');

  // 3. Levantar Servidor HTTP/REST con Shelf (Puerto 8081 para OIDC y webhooks)
  final app = Router();

  app.get('/oidc/callback', (Request request) async {
    try {
      if (!locator.isRegistered<OidcHandler>()) {
        throw Exception('OIDC no está configurado en el servidor.');
      }

      final queryParams = request.url.queryParameters;
      final oidcHandler = locator<OidcHandler>();

      final result = await oidcHandler.processCallback(queryParams);
      final credential = result.credential;
      final strategyName = result.authStrategy;

      final claims = credential.idToken.claims;
      final issuer = claims['iss'] as String?;
      if (issuer == null) throw Exception('Token OIDC sin issuer.');

      final userInfo = await credential.getUserInfo();

      final strategyEnum = AuthStrategy.values.firstWhere(
        (e) => e.name == strategyName.toUpperCase(),
        orElse: () => AuthStrategy.JWT,
      );

      final command = SignInWithOidcCommand(
        issuer: issuer,
        subject: userInfo.subject,
        email: userInfo.email,
        nickname: userInfo.givenName ?? userInfo.name,
        avatarUrl: userInfo.picture?.toString(),
        strategy: strategyEnum,
      );

      final authSuccess = await locator<Mediator>().send(command);

      final redirectUrl = Uri(
        scheme: 'zeepubs-app',
        host: 'auth',
        path: 'success',
        queryParameters: {
          'token': authSuccess.token,
          if (authSuccess.refreshToken.isNotEmpty) 'refreshToken': authSuccess.refreshToken,
        },
      );

      return Response.found(redirectUrl.toString());
    } catch (e, stackTrace) {
      print('Error OIDC: $e\n$stackTrace');
      return Response.found(
        'zeepubs-app://auth/error?message=${Uri.encodeComponent(e.toString())}',
      );
    }
  });

  // Pipeline con CORS y Logs para la web
  final handler = Pipeline().addMiddleware(corsHeaders()).addMiddleware(logRequests()).addHandler(app.call);

  final httpServer = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    8081,
  );
  print(
    '✅ Servidor REST (OIDC/Webhooks) escuchando en puerto ${httpServer.port}...',
  );
}
