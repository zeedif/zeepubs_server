import '/common/database/transactional.dart';
import '/common/di/service_locator.dart';
import '/common/mediator/interfaces.dart';
import '/common/session/app_session.dart';
import '/common/session/permission_validator.dart';
import '/src/generated/auth.pb.dart';
import '/src/generated/profile.pb.dart';

import '../../repositories/profile_repo.dart';

// Command
class UpdateProfileCommand implements IRequest<PublicProfile> {
  final int profileId;
  final String? nickname;
  final String? avatarUrl;
  final String? bio;

  UpdateProfileCommand({
    required this.profileId,
    this.nickname,
    this.avatarUrl,
    this.bio,
  });
}

// Handler
class UpdateProfileHandler implements IRequestHandler<UpdateProfileCommand, PublicProfile> {
  final IProfileRepository _profileRepository;
  final Transactional _tx;

  UpdateProfileHandler(this._tx, this._profileRepository);

  @override
  Future<PublicProfile> handle(UpdateProfileCommand request) async {
    final session = locator<AppSession>();
    final canManageAll = session.hasScope(Scope.SYSTEM_MANAGE_PROFILES);
    final canEditUnassociated = canManageAll || session.hasScope(Scope.PROFILE_EDIT_UNASSOCIATED);

    return _tx(() async {
      return await _profileRepository.updateProfile(
        request: request,
        enforceOwnershipId: canManageAll ? null : session.authenticated!.userId,
        allowUnassociated: canEditUnassociated,
      );
    });
  }
}
