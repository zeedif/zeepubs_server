import '/common/mediator/interfaces.dart';

import '../../repositories/auth_repo.dart';

// Command
class FinishFido2RegistrationCommand implements IRequest<void> {
  final int challengeId;
  final String attestationObject; // base64url
  final String clientDataJSON; // base64url

  FinishFido2RegistrationCommand({
    required this.challengeId,
    required this.attestationObject,
    required this.clientDataJSON,
  });
}

// Handler
class FinishFido2RegistrationHandler implements IRequestHandler<FinishFido2RegistrationCommand, void> {
  final IAuthRepository _authRepository;

  FinishFido2RegistrationHandler(this._authRepository);

  @override
  Future<void> handle(FinishFido2RegistrationCommand request) {
    return _authRepository.finishFido2Registration(request: request);
  }
}
