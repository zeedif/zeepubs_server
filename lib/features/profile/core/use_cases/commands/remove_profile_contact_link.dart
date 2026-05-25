import '/common/database/transactional.dart';
import '/common/di/service_locator.dart';
import '/common/mediator/interfaces.dart';
import '/common/session/app_session.dart';
import '/common/session/permission_validator.dart';
import '/src/generated/auth.pb.dart';

import '../../repositories/profile_repo.dart';

// Command
class RemoveProfileContactLinkCommand implements IRequest<void> {
  final int contactLinkId;
  RemoveProfileContactLinkCommand({required this.contactLinkId});
}

// Handler
class RemoveProfileContactLinkHandler implements IRequestHandler<RemoveProfileContactLinkCommand, void> {
  final IProfileRepository _profileRepository;
  final Transactional _tx;

  RemoveProfileContactLinkHandler(this._tx, this._profileRepository);

  @override
  Future<void> handle(RemoveProfileContactLinkCommand request) async {
    final session = locator<AppSession>();
    final canManageAll = session.hasScope(Scope.SYSTEM_MANAGE_PROFILES);

    return _tx(() async {
      await _profileRepository.removeContactLink(
        contactLinkId: request.contactLinkId,
        enforceOwnershipId: canManageAll ? null : session.authenticated!.userId,
      );
    });
  }
}
