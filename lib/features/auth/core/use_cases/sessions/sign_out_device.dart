import 'package:uuid/uuid.dart';
import '/common/mediator/interfaces.dart';
import '/src/generated/auth.pb.dart';
import '../../repositories/auth_repo.dart';

class SignOutDeviceCommand implements IRequest<void> {
  final UuidValue tokenId;
  final AuthStrategy strategy;

  SignOutDeviceCommand({required this.tokenId, required this.strategy});
}

class SignOutDeviceHandler implements IRequestHandler<SignOutDeviceCommand, void> {
  final IAuthRepository _authRepository;

  SignOutDeviceHandler(this._authRepository);

  @override
  Future<void> handle(SignOutDeviceCommand request) async {
    await _authRepository.signOutDevice(tokenId: request.tokenId, strategy: request.strategy);
  }
}
