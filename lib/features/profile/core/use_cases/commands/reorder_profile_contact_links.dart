import '/common/database/transactional.dart';
import '/common/di/service_locator.dart';
import '/common/mediator/interfaces.dart';
import '/common/session/app_session.dart';
import '/common/session/permission_validator.dart';
import '/src/generated/auth.pb.dart';

import '../../repositories/profile_repo.dart';

// Command
class ReorderProfileContactLinksCommand implements IRequest<void> {
  final int contactLinkId;
  final int newIndex;

  ReorderProfileContactLinksCommand({
    required this.contactLinkId,
    required this.newIndex,
  });
}

// Handler
class ReorderProfileContactLinksHandler implements IRequestHandler<ReorderProfileContactLinksCommand, void> {
  final IProfileRepository _profileRepository;
  final Transactional _tx;

  ReorderProfileContactLinksHandler(this._tx, this._profileRepository);

  @override
  Future<void> handle(ReorderProfileContactLinksCommand request) async {
    final session = locator<AppSession>();
    final canManageAll = session.hasScope(Scope.SYSTEM_MANAGE_PROFILES);
    final canEditUnassociated = canManageAll || session.hasScope(Scope.PROFILE_EDIT_UNASSOCIATED);

    return _tx(() async {
      await _profileRepository.reorderContactLink(
        request: request,
        enforceOwnershipId: canManageAll ? null : session.authenticated!.userId,
        allowUnassociated: canEditUnassociated,
      );
    });
  }
}
