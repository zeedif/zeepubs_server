import 'package:uuid/uuid.dart';
import '/common/mediator/interfaces.dart';
import '../../repositories/auth_repo.dart';

class SignOutOtherDeviceCommand implements IRequest<void> {
  final UuidValue userId;
  final UuidValue targetTokenId;

  SignOutOtherDeviceCommand({required this.userId, required this.targetTokenId});
}

class SignOutOtherDeviceHandler implements IRequestHandler<SignOutOtherDeviceCommand, void> {
  final IAuthRepository _authRepository;

  SignOutOtherDeviceHandler(this._authRepository);

  @override
  Future<void> handle(SignOutOtherDeviceCommand request) async {
    await _authRepository.signOutOtherDevice(userId: request.userId, targetTokenId: request.targetTokenId);
  }
}
