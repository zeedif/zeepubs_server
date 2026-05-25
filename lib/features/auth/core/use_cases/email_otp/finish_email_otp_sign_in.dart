import '/common/database/transactional.dart';
import '/common/mediator/interfaces.dart';
import '/src/generated/auth.pb.dart';

import '../../repositories/auth_repo.dart';

// Command
class FinishEmailOtpSignInCommand implements IRequest<AuthSuccess> {
  final String email;
  final String otp;
  final AuthStrategy strategy;

  FinishEmailOtpSignInCommand({
    required this.email,
    required this.otp,
    required this.strategy,
  });
}

// Handler
class FinishEmailOtpSignInHandler implements IRequestHandler<FinishEmailOtpSignInCommand, AuthSuccess> {
  final IAuthRepository _authRepository;
  final Transactional _tx;

  FinishEmailOtpSignInHandler(this._tx, this._authRepository);

  @override
  Future<AuthSuccess> handle(FinishEmailOtpSignInCommand request) {
    return _tx(() async {
      return await _authRepository.finishEmailOtpSignIn(request: request, strategy: request.strategy);
    });
  }
}
