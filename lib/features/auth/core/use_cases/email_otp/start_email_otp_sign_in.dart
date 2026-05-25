import '/common/database/transactional.dart';
import '/common/mediator/interfaces.dart';

import '../../repositories/auth_repo.dart';

// Command
class StartEmailOtpSignInCommand implements IRequest<void> {
  final String email;
  StartEmailOtpSignInCommand({required this.email});
}

// Handler
class StartEmailOtpSignInHandler implements IRequestHandler<StartEmailOtpSignInCommand, void> {
  final IAuthRepository _authRepository;
  final Transactional _tx;

  StartEmailOtpSignInHandler(this._tx, this._authRepository);

  @override
  Future<void> handle(StartEmailOtpSignInCommand request) {
    return _tx(() async {
      return await _authRepository.startEmailOtpSignIn(request: request);
    });
  }
}
