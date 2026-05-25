import '/common/database/transactional.dart';
import '/common/mediator/interfaces.dart';

import '../../repositories/auth_repo.dart';

// Command
class StartPasswordResetCommand implements IRequest<void> {
  final String email;
  StartPasswordResetCommand({required this.email});
}

// Handler
class StartPasswordResetHandler implements IRequestHandler<StartPasswordResetCommand, void> {
  final IAuthRepository _authRepository;
  final Transactional _tx;

  StartPasswordResetHandler(this._tx, this._authRepository);

  @override
  Future<void> handle(StartPasswordResetCommand request) {
    return _tx(() async {
      return await _authRepository.startPasswordReset(request: request);
    });
  }
}
