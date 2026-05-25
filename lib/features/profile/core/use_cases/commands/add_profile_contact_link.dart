import '/common/database/transactional.dart';
import '/common/di/service_locator.dart';
import '/common/mediator/interfaces.dart';
import '/common/session/app_session.dart';
import '/common/session/permission_validator.dart';
import '/src/generated/auth.pb.dart';
import '/src/generated/profile.pb.dart';

import '../../repositories/profile_repo.dart';

// Command
class AddProfileContactLinkCommand implements IRequest<ProfileContactLink> {
  final int profileId;
  final String platform;
  final String url;

  AddProfileContactLinkCommand({
    required this.profileId,
    required this.platform,
    required this.url,
  });
}

// Handler
class AddProfileContactLinkHandler implements IRequestHandler<AddProfileContactLinkCommand, ProfileContactLink> {
  final IProfileRepository _profileRepository;
  final Transactional _tx;

  AddProfileContactLinkHandler(this._tx, this._profileRepository);

  @override
  Future<ProfileContactLink> handle(AddProfileContactLinkCommand request) async {
    final session = locator<AppSession>();
    final canManageAll = session.hasScope(Scope.SYSTEM_MANAGE_PROFILES);

    return _tx(() async {
      return await _profileRepository.addContactLink(
        request: request,
        enforceOwnershipId: canManageAll ? null : session.authenticated!.userId,
      );
    });
  }
}
