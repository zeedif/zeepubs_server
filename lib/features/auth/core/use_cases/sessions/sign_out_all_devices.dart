import 'package:uuid/uuid.dart';

import '/common/di/service_locator.dart';
import '/common/mediator/interfaces.dart';
import '/common/session/app_session.dart';
import '/common/session/permission_validator.dart';
import '/src/generated/auth.pb.dart';

import '../../repositories/auth_repo.dart';

class SignOutAllDevicesCommand implements IRequest<void> {
  final UuidValue userId;
  SignOutAllDevicesCommand({required this.userId});
}

class SignOutAllDevicesHandler implements IRequestHandler<SignOutAllDevicesCommand, void> {
  final IAuthRepository _authRepository;

  SignOutAllDevicesHandler(this._authRepository);

  @override
  Future<void> handle(SignOutAllDevicesCommand request) async {
    final session = locator<AppSession>();
    session.requireScope(Scope.SYSTEM_MANAGE_USERS);

    await _authRepository.signOutAllDevices(userId: request.userId);
  }
}
