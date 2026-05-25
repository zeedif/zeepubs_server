import '/common/database/transactional.dart';
import '/common/mediator/interfaces.dart';
import '/src/generated/auth.pb.dart';

import '../../repositories/auth_repo.dart';

// Command
class FinishPasswordResetCommand implements IRequest<AuthSuccess> {
  final int requestId;
  final String verificationCode;
  final String newPassword;
  final AuthStrategy strategy;

  FinishPasswordResetCommand({
    required this.requestId,
    required this.verificationCode,
    required this.newPassword,
    required this.strategy,
  });
}

// Handler
class FinishPasswordResetHandler implements IRequestHandler<FinishPasswordResetCommand, AuthSuccess> {
  final IAuthRepository _authRepository;
  final Transactional _tx;

  FinishPasswordResetHandler(this._tx, this._authRepository);

  @override
  Future<AuthSuccess> handle(FinishPasswordResetCommand request) {
    return _tx(() async {
      return await _authRepository.finishPasswordReset(request: request, strategy: request.strategy);
    });
  }
}
