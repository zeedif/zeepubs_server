import '/common/database/transactional.dart';
import '/common/di/service_locator.dart';
import '/common/mediator/interfaces.dart';
import '/common/session/app_session.dart';
import '/common/session/permission_validator.dart';
import '/src/generated/auth.pb.dart';
import '/src/generated/profile.pb.dart';

import '../../repositories/profile_repo.dart';

// Command
class UpdateProfileContactLinkCommand implements IRequest<ProfileContactLink> {
  final int contactLinkId;
  final String? platform;
  final String? url;

  UpdateProfileContactLinkCommand({
    required this.contactLinkId,
    this.platform,
    this.url,
  });
}

// Handler
class UpdateProfileContactLinkHandler implements IRequestHandler<UpdateProfileContactLinkCommand, ProfileContactLink> {
  final IProfileRepository _profileRepository;
  final Transactional _tx;

  UpdateProfileContactLinkHandler(this._tx, this._profileRepository);

  @override
  Future<ProfileContactLink> handle(UpdateProfileContactLinkCommand request) async {
    final session = locator<AppSession>();
    final canManageAll = session.hasScope(Scope.SYSTEM_MANAGE_PROFILES);

    return _tx(() async {
      return await _profileRepository.updateContactLink(
        request: request,
        enforceOwnershipId: canManageAll ? null : session.authenticated!.userId,
      );
    });
  }
}
