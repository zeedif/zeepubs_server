import 'package:uuid/uuid.dart';

import '/src/generated/profile.pb.dart';

import '../use_cases/commands/add_profile_contact_link.dart';
import '../use_cases/commands/reorder_profile_contact_links.dart';
import '../use_cases/commands/update_profile.dart';
import '../use_cases/commands/update_profile_contact_link.dart';

abstract class IProfileRepository {
  // --- Gestión de Perfiles ---
  Future<PublicProfile?> getProfileById({required int profileId});
  Future<PublicProfile?> getProfileByUuid({required UuidValue authUserId});
  Future<PublicProfile> updateProfile({
    required UpdateProfileCommand request,
    UuidValue? enforceOwnershipId,
    bool allowUnassociated = false,
  });
  Future<PaginatedProfilesData> getProfiles({
    required int pageSize,
    String? cursor,
    String? searchQuery,
  });

  // --- Gestión de Enlaces de Contacto ---
  Future<ProfileContactLink> addContactLink({
    required AddProfileContactLinkCommand request,
    UuidValue? enforceOwnershipId,
    bool allowUnassociated = false,
  });
  Future<void> removeContactLink({
    required int contactLinkId,
    UuidValue? enforceOwnershipId,
    bool allowUnassociated = false,
  });
  Future<ProfileContactLink> updateContactLink({
    required UpdateProfileContactLinkCommand request,
    UuidValue? enforceOwnershipId,
    bool allowUnassociated = false,
  });
  Future<void> reorderContactLink({
    required ReorderProfileContactLinksCommand request,
    UuidValue? enforceOwnershipId,
    bool allowUnassociated = false,
  });

  // --- Fusión de Perfiles ---
  Future<ProfileMergeRequest> createMergeRequest({
    required int targetProfileId,
    required UuidValue requesterAuthUserId,
  });
  Future<List<ProfileMergeRequest>> getMergeRequestsByStatus({
    ProfileMergeRequestStatus? status,
  });
  Future<ProfileMergeRequest> approveMergeRequest({
    required int requestId,
    required UuidValue resolverAuthUserId,
  });
  Future<ProfileMergeRequest> rejectMergeRequest({
    required int requestId,
    required UuidValue resolverAuthUserId,
  });
}
