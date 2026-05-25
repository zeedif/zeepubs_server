import '/common/database/transactional.dart';
import '/common/mediator/interfaces.dart';
import '/src/generated/auth.pb.dart';

import '../../repositories/auth_repo.dart';

// Command
class SignInCommand implements IRequest<AuthSuccess> {
  final String userOrEmail;
  final String password;
  final AuthStrategy strategy;

  SignInCommand({
    required this.userOrEmail,
    required this.password,
    required this.strategy,
  });
}

// Handler
class SignInHandler implements IRequestHandler<SignInCommand, AuthSuccess> {
  final IAuthRepository _authRepository;
  final Transactional _tx;

  SignInHandler(this._tx, this._authRepository);

  @override
  Future<AuthSuccess> handle(SignInCommand request) {
    return _tx(() async {
      return await _authRepository.signIn(request: request, strategy: request.strategy);
    });
  }
}
