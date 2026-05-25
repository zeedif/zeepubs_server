import '/common/database/transactional.dart';
import '/common/mediator/interfaces.dart';

import '../../repositories/auth_repo.dart';

// Command
class FinishEmailVerificationCommand implements IRequest<void> {
  final int requestId;
  final String verificationCode;

  FinishEmailVerificationCommand({
    required this.requestId,
    required this.verificationCode,
  });
}

// Handler
class FinishEmailVerificationHandler implements IRequestHandler<FinishEmailVerificationCommand, void> {
  final IAuthRepository _authRepository;
  final Transactional _tx;

  FinishEmailVerificationHandler(this._tx, this._authRepository);

  @override
  Future<void> handle(FinishEmailVerificationCommand request) {
    return _tx(() async {
      return await _authRepository.finishEmailVerification(request: request);
    });
  }
}
