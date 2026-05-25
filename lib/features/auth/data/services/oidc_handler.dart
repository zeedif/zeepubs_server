import 'dart:math';

import 'package:openid_client/openid_client_io.dart';

import '/common/database/database.dart';

import '../../core/configs/oidc_config.dart';

class OidcHandler {
  final OidcConfig _config;
  final AppDatabase _db;
  Issuer? _issuer;
  Client? _client;
  bool _isInitialized = false;

  OidcHandler(this._config, this._db);

  Future<void> initialize() async {
    if (_isInitialized) return;
    _issuer = await Issuer.discover(Uri.parse(_config.authority));
    _client = Client(
      _issuer!,
      _config.clientId,
      clientSecret: _config.clientSecret,
    );
    _isInitialized = true;
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<Uri> generateAuthorizationUrl(String strategy) async {
    await initialize();

    final state = _generateRandomString(32);
    final nonce = _generateRandomString(32);

    await _db.into(_db.oidcStates).insert(
      OidcStatesCompanion.insert(
        state: state,
        nonce: nonce,
        authStrategy: strategy,
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      ),
    );

    final authUrl = _issuer!.metadata.authorizationEndpoint.replace(
      queryParameters: {
        'client_id': _config.clientId,
        'response_type': 'code',
        'redirect_uri': _config.redirectUri,
        'scope': 'openid email profile',
        'state': state,
        'nonce': nonce,
      },
    );

    return authUrl;
  }

  Future<({Credential credential, String authStrategy})> processCallback(Map<String, String> queryParams) async {
    await initialize();

    final state = queryParams['state'];
    if (state == null) throw Exception('El parámetro "state" de OIDC es nulo.');

    // Validar estado en DB
    final storedState = await (_db.select(_db.oidcStates)..where((o) => o.state.equals(state))).getSingleOrNull();

    if (storedState == null || storedState.expiresAt.isBefore(DateTime.now().toUtc())) {
      if (storedState != null) await (_db.delete(_db.oidcStates)..where((o) => o.id.equals(storedState.id))).go();
      throw Exception('El "state" de OIDC es inválido o ha expirado.');
    }

    // Consumir el estado
    await (_db.delete(_db.oidcStates)..where((o) => o.id.equals(storedState.id))).go();

    final flow = Flow.authorizationCode(_client!);
    final credential = await flow.callback(queryParams);

    final claims = credential.idToken.claims;
    final tokenNonce = claims['nonce'] as String?;

    if (tokenNonce != storedState.nonce) throw Exception('El "nonce" de OIDC no coincide.');

    return (credential: credential, authStrategy: storedState.authStrategy);
  }
}
