import '/common/database/transactional.dart';
import '/common/mediator/interfaces.dart';
import '/src/generated/auth.pb.dart';

import '../../repositories/auth_repo.dart';

// Query
class GenerateFido2AuthenticationChallengeQuery implements IRequest<Fido2ChallengeResponse> {}

// Handler
class GenerateFido2AuthenticationChallengeHandler implements IRequestHandler<GenerateFido2AuthenticationChallengeQuery, Fido2ChallengeResponse> {
  final IAuthRepository _authRepository;
  final Transactional _tx;

  GenerateFido2AuthenticationChallengeHandler(this._tx, this._authRepository);

  @override
  Future<Fido2ChallengeResponse> handle(GenerateFido2AuthenticationChallengeQuery request) {
    return _tx(() async {
      return await _authRepository.generateFido2AuthenticationChallenge();
    });
  }
}
