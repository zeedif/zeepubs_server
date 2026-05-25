import '/common/database/transactional.dart';
import '/common/mediator/interfaces.dart';
import '/src/generated/auth.pb.dart';

import '../../repositories/auth_repo.dart';

// Query
class GenerateFido2RegistrationChallengeQuery implements IRequest<Fido2ChallengeResponse> {
  final String username;
  GenerateFido2RegistrationChallengeQuery({required this.username});
}

// Handler
class GenerateFido2RegistrationChallengeHandler implements IRequestHandler<GenerateFido2RegistrationChallengeQuery, Fido2ChallengeResponse> {
  final IAuthRepository _authRepository;
  final Transactional _tx;

  GenerateFido2RegistrationChallengeHandler(this._tx, this._authRepository);

  @override
  Future<Fido2ChallengeResponse> handle(GenerateFido2RegistrationChallengeQuery request) {
    return _tx(() async {
      return await _authRepository.generateFido2RegistrationChallenge(request: request);
    });
  }
}
