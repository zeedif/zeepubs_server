import '/common/database/transactional.dart';
import '/common/mediator/interfaces.dart';
import '/src/generated/auth.pb.dart';

import '../../repositories/auth_repo.dart';

// Command
class SignInWithOidcCommand implements IRequest<AuthSuccess> {
  final String issuer;
  final String subject;
  final String? email;
  final String? nickname;
  final String? avatarUrl;
  final AuthStrategy strategy;

  SignInWithOidcCommand({
    required this.issuer,
    required this.subject,
    this.email,
    this.nickname,
    this.avatarUrl,
    required this.strategy,
  });
}

// Handler
class SignInWithOidcHandler implements IRequestHandler<SignInWithOidcCommand, AuthSuccess> {
  final IAuthRepository _authRepository;
  final Transactional _tx;

  SignInWithOidcHandler(this._tx, this._authRepository);

  @override
  Future<AuthSuccess> handle(SignInWithOidcCommand request) {
    return _tx(() async {
      return await _authRepository.signInWithOidc(request: request);
    });
  }
}
