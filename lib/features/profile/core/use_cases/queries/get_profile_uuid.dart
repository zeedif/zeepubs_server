import 'package:uuid/uuid.dart';

import '/common/mediator/interfaces.dart';
import '/src/generated/profile.pb.dart';

import '../../exceptions/profile_exceptions.dart';
import '../../repositories/profile_repo.dart';

// Query
class GetProfileByUuidQuery implements IRequest<PublicProfile> {
  final UuidValue authUserId;
  GetProfileByUuidQuery({required this.authUserId});
}

// Handler
class GetProfileByUuidHandler implements IRequestHandler<GetProfileByUuidQuery, PublicProfile> {
  final IProfileRepository _profileRepository;
  GetProfileByUuidHandler(this._profileRepository);

  @override
  Future<PublicProfile> handle(GetProfileByUuidQuery request) async {
    final profile = await _profileRepository.getProfileByUuid(authUserId: request.authUserId);
    if (profile == null) throw const UserProfileNotFoundException();
    return profile;
  }
}
