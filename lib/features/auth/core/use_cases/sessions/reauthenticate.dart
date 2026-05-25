import 'package:uuid/uuid.dart';
import '/common/mediator/interfaces.dart';
import '../../repositories/auth_repo.dart';

class ReauthenticateCommand implements IRequest<void> {
  final UuidValue userId;
  final UuidValue currentTokenId;
  final String password;

  ReauthenticateCommand({required this.userId, required this.currentTokenId, required this.password});
}

class ReauthenticateHandler implements IRequestHandler<ReauthenticateCommand, void> {
  final IAuthRepository _authRepository;

  ReauthenticateHandler(this._authRepository);

  @override
  Future<void> handle(ReauthenticateCommand request) async {
    await _authRepository.reauthenticate(
      userId: request.userId,
      currentTokenId: request.currentTokenId,
      password: request.password,
    );
  }
}
