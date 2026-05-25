import '/common/database/transactional.dart';
import '/common/mediator/interfaces.dart';
import '/src/generated/auth.pb.dart';

import '../../repositories/auth_repo.dart';

// Command
class SignUpCommand implements IRequest<AuthSuccess> {
  final String username;
  final String? email;
  final String? password;
  final AuthStrategy strategy;

  SignUpCommand({
    required this.username,
    this.email,
    this.password,
    required this.strategy,
  });
}

// Handler
class SignUpHandler implements IRequestHandler<SignUpCommand, AuthSuccess> {
  final IAuthRepository _authRepository;
  final Transactional _tx;

  SignUpHandler(this._tx, this._authRepository);

  @override
  Future<AuthSuccess> handle(SignUpCommand request) {
    return _tx(() async {
      return await _authRepository.signUp(request: request, strategy: request.strategy);
    });
  }
}
