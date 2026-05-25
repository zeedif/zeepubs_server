import 'package:uuid/uuid.dart';
import '/common/mediator/interfaces.dart';
import '../../repositories/auth_repo.dart';

class SignOutAllOtherDevicesCommand implements IRequest<void> {
  final UuidValue userId;
  final UuidValue currentTokenId;

  SignOutAllOtherDevicesCommand({required this.userId, required this.currentTokenId});
}

class SignOutAllOtherDevicesHandler implements IRequestHandler<SignOutAllOtherDevicesCommand, void> {
  final IAuthRepository _authRepository;

  SignOutAllOtherDevicesHandler(this._authRepository);

  @override
  Future<void> handle(SignOutAllOtherDevicesCommand request) async {
    await _authRepository.signOutAllOtherDevices(userId: request.userId, currentTokenId: request.currentTokenId);
  }
}