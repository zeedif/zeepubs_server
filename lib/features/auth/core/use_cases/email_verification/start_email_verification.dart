import 'package:uuid/uuid.dart';

import '/common/database/transactional.dart';
import '/common/mediator/interfaces.dart';

import '../../repositories/auth_repo.dart';

// Command
class StartEmailVerificationCommand implements IRequest<void> {
  final UuidValue authUserId;
  StartEmailVerificationCommand({required this.authUserId});
}

// Handler
class StartEmailVerificationHandler implements IRequestHandler<StartEmailVerificationCommand, void> {
  final IAuthRepository _authRepository;
  final Transactional _tx;

  StartEmailVerificationHandler(this._tx, this._authRepository);

  @override
  Future<void> handle(StartEmailVerificationCommand request) {
    return _tx(() async {
      return await _authRepository.startEmailVerification(request: request);
    });
  }
}
