import '/common/database/transactional.dart';
import '/common/mediator/interfaces.dart';
import '/src/generated/auth.pb.dart';

import '../../repositories/auth_repo.dart';

// Command
class FinishFido2AuthenticationCommand implements IRequest<AuthSuccess> {
  final int challengeId;
  final String credentialId; // base64url
  final String authenticatorData; // base64url
  final String clientDataJSON; // base64url
  final String signature; // base64url
  final AuthStrategy strategy;

  FinishFido2AuthenticationCommand({
    required this.challengeId,
    required this.credentialId,
    required this.authenticatorData,
    required this.clientDataJSON,
    required this.signature,
    required this.strategy,
  });
}

// Handler
class FinishFido2AuthenticationHandler implements IRequestHandler<FinishFido2AuthenticationCommand, AuthSuccess> {
  final IAuthRepository _authRepository;
  final Transactional _tx;

  FinishFido2AuthenticationHandler(this._tx, this._authRepository);

  @override
  Future<AuthSuccess> handle(FinishFido2AuthenticationCommand request) {
    return _tx(() async {
      return await _authRepository.finishFido2Authentication(request: request, strategy: request.strategy);
    });
  }
}
