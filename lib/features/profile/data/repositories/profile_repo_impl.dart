import 'package:drift/drift.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart';
import 'package:uuid/uuid.dart';

import '/common/database/database.dart';
import '/src/generated/profile.pb.dart';

import '../../core/exceptions/profile_exceptions.dart';
import '../../core/repositories/profile_repo.dart';
import '../../core/use_cases/commands/add_profile_contact_link.dart';
import '../../core/use_cases/commands/reorder_profile_contact_links.dart';
import '../../core/use_cases/commands/update_profile.dart';
import '../../core/use_cases/commands/update_profile_contact_link.dart';

class ProfileRepositoryImpl implements IProfileRepository {
  final AppDatabase _db;

  ProfileRepositoryImpl(this._db);

  // =========================================================================
  // --- HELPERS DE MAPEO ---
  // =========================================================================

  PublicProfile _mapProfile(PublicProfileRow row, List<ProfileContactLinkRow> links) {
    final profile = PublicProfile(
      id: row.id,
      nickname: row.nickname,
    );
    if (row.userId != null) {
      profile.userId = row.userId.toString();
    }
    if (row.avatarUrl != null) {
      profile.avatarUrl = row.avatarUrl!;
    }
    if (row.bio != null) {
      profile.bio = row.bio!;
    }
    profile.contactLinks.addAll(links.map(_mapContactLink));
    return profile;
  }

  ProfileContactLink _mapContactLink(ProfileContactLinkRow row) {
    final link = ProfileContactLink(
      id: row.id,
      platform: row.platform,
      url: row.url,
    );
    if (row.nextContactLinkId != null) {
      link.nextContactLinkId = row.nextContactLinkId!;
    }
    return link;
  }

  ProfileMergeRequest _mapMergeRequest(ProfileMergeRequestRow row) {
    final pbStatus = ProfileMergeRequestStatus.valueOf(row.status) ?? 
        ProfileMergeRequestStatus.MERGE_PENDING;
        
    final mr = ProfileMergeRequest(
      id: row.id,
      targetProfileId: row.targetProfileId,
      sourceProfileId: row.sourceProfileId,
      requesterId: row.requesterId.toString(),
      status: pbStatus,
      createdAt: Timestamp.fromDateTime(row.createdAt),
    );
    if (row.resolvedById != null) {
      mr.resolvedById = row.resolvedById.toString();
    }
    if (row.resolvedAt != null) {
      mr.resolvedAt = Timestamp.fromDateTime(row.resolvedAt!);
    }
    return mr;
  }

  /// Ordenador tolerante a ciclos para la cadena enlazada de links de contacto.
  List<ProfileContactLinkRow> _sortContactLinks(List<ProfileContactLinkRow> links) {
    if (links.isEmpty) return [];
    
    final map = {for (final link in links) link.id: link};
    final nextToPrev = {
      for (final link in links) 
        if (link.nextContactLinkId != null) link.nextContactLinkId!: link.id
    };

    final heads = links.where((l) => !nextToPrev.containsKey(l.id)).toList();
    final sorted = <ProfileContactLinkRow>[];
    final visited = <int>{};

    void traverse(ProfileContactLinkRow? node) {
      while (node != null && !visited.contains(node.id)) {
        visited.add(node.id);
        sorted.add(node);
        node = node.nextContactLinkId != null ? map[node.nextContactLinkId] : null;
      }
    }

    // Procesa cabeceras válidas
    for (final head in heads) {
      traverse(head);
    }
    // Procesa nodos huérfanos/cíclicos si los hay
    for (final link in links) {
      if (!visited.contains(link.id)) {
        traverse(link);
      }
    }

    return sorted;
  }

  /// Validador centralizado de propiedad del perfil (Enforce Ownership)
  Future<PublicProfileRow> _getAndAuthorizeProfile(
    int profileId, 
    UuidValue? enforceOwnershipId, 
  ) async {
    final profile = await (_db.select(_db.publicProfiles)..where((p) => p.id.equals(profileId))).getSingleOrNull();
    if (profile == null) throw const UserProfileNotFoundException();

    if (enforceOwnershipId != null && profile.userId != enforceOwnershipId) {
      throw const ProfileAccessDeniedException();
    }

    return profile;
  }

  Future<ProfileContactLinkRow> _getAndAuthorizeContactLink(
    int contactLinkId, 
    UuidValue? enforceOwnershipId, 
  ) async {
    final link = await (_db.select(_db.profileContactLinks)..where((l) => l.id.equals(contactLinkId))).getSingleOrNull();
    if (link == null) throw const ContactLinkNotFoundException();

    await _getAndAuthorizeProfile(link.profileId, enforceOwnershipId);
    return link;
  }

  // =========================================================================
  // --- GESTIÓN DE PERFILES ---
  // =========================================================================

  @override
  Future<PublicProfile?> getProfileById({required int profileId}) async {
    final query = _db.select(_db.publicProfiles).join([
      leftOuterJoin(
        _db.profileContactLinks,
        _db.profileContactLinks.profileId.equalsExp(_db.publicProfiles.id),
      )
    ])..where(_db.publicProfiles.id.equals(profileId));

    final rows = await query.get();
    if (rows.isEmpty) return null;

    final profileRow = rows.first.readTable(_db.publicProfiles);
    final links = rows
        .map((row) => row.readTableOrNull(_db.profileContactLinks))
        .whereType<ProfileContactLinkRow>()
        .toList();

    final sortedLinks = _sortContactLinks(links);
    return _mapProfile(profileRow, sortedLinks);
  }

  @override
  Future<PublicProfile?> getProfileByUuid({required UuidValue authUserId}) async {
    final query = _db.select(_db.publicProfiles).join([
      leftOuterJoin(
        _db.profileContactLinks,
        _db.profileContactLinks.profileId.equalsExp(_db.publicProfiles.id),
      )
    ])..where(_db.publicProfiles.userId.equals(authUserId));

    final rows = await query.get();
    if (rows.isEmpty) return null;

    final profileRow = rows.first.readTable(_db.publicProfiles);
    final links = rows
        .map((row) => row.readTableOrNull(_db.profileContactLinks))
        .whereType<ProfileContactLinkRow>()
        .toList();

    final sortedLinks = _sortContactLinks(links);
    return _mapProfile(profileRow, sortedLinks);
  }

  @override
  Future<PublicProfile> updateProfile({
    required UpdateProfileCommand request,
    UuidValue? enforceOwnershipId,
  }) async {
    final profile = await _getAndAuthorizeProfile(request.profileId, enforceOwnershipId);

    await (_db.update(_db.publicProfiles)..where((p) => p.id.equals(profile.id))).write(
      PublicProfilesCompanion(
        nickname: request.nickname != null ? Value(request.nickname!) : const Value.absent(),
        avatarUrl: request.avatarUrl != null ? Value(request.avatarUrl) : const Value.absent(),
        bio: request.bio != null ? Value(request.bio) : const Value.absent(),
      ),
    );

    return (await getProfileById(profileId: profile.id))!;
  }

  @override
  Future<PaginatedProfilesData> getProfiles({
    required int pageSize,
    String? cursor,
    String? searchQuery,
  }) async {
    final query = _db.select(_db.publicProfiles);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query.where((p) => p.nickname.like('%$searchQuery%'));
    }

    final cursorId = cursor != null ? int.tryParse(cursor) : null;
    if (cursorId != null) {
      query.where((p) => p.id.isBiggerThanValue(cursorId));
    }

    query.orderBy([(p) => OrderingTerm.asc(p.id)]);
    query.limit(pageSize + 1);

    final results = await query.get();
    final hasNext = results.length > pageSize;
    final profilesToReturn = hasNext ? results.sublist(0, pageSize) : results;
    final profileIds = profilesToReturn.map((p) => p.id).toList();
    final Map<int, List<ProfileContactLinkRow>> linksByProfileId = {};

    if (profileIds.isNotEmpty) {
      final allLinks = await (_db.select(_db.profileContactLinks)
            ..where((l) => l.profileId.isIn(profileIds)))
          .get();

      for (final link in allLinks) {
        linksByProfileId.putIfAbsent(link.profileId, () => []).add(link);
      }
    }

    final mappedProfiles = <PublicProfile>[];
    for (final p in profilesToReturn) {
      final links = linksByProfileId[p.id] ?? const <ProfileContactLinkRow>[];
      final sortedLinks = _sortContactLinks(links);
      mappedProfiles.add(_mapProfile(p, sortedLinks));
    }

    final nextCursor = hasNext && profilesToReturn.isNotEmpty
        ? profilesToReturn.last.id.toString()
        : null;

    final response = PaginatedProfilesData(profiles: mappedProfiles);
    if (nextCursor != null) {
      response.nextCursor = nextCursor;
    }
    return response;
  }

  // =========================================================================
  // --- GESTIÓN DE ENLACES DE CONTACTO ---
  // =========================================================================

  @override
  Future<ProfileContactLink> addContactLink({
    required AddProfileContactLinkCommand request,
    UuidValue? enforceOwnershipId,
  }) async {
    final profile = await _getAndAuthorizeProfile(request.profileId, enforceOwnershipId);

    final oldTail = await (_db.select(_db.profileContactLinks)
          ..where((l) => l.profileId.equals(profile.id) & l.nextContactLinkId.isNull()))
        .getSingleOrNull();

    final newLinkRow = await _db.into(_db.profileContactLinks).insertReturning(
      ProfileContactLinksCompanion.insert(
        profileId: profile.id,
        platform: request.platform,
        url: request.url,
      ),
    );

    if (oldTail != null) {
      await (_db.update(_db.profileContactLinks)..where((l) => l.id.equals(oldTail.id))).write(
        ProfileContactLinksCompanion(nextContactLinkId: Value(newLinkRow.id)),
      );
    }

    return _mapContactLink(newLinkRow);
  }

  @override
  Future<void> removeContactLink({
    required int contactLinkId,
    UuidValue? enforceOwnershipId,
  }) async {
    final linkToRemove = await _getAndAuthorizeContactLink(contactLinkId, enforceOwnershipId);

    final pointingLink = await (_db.select(_db.profileContactLinks)
          ..where((l) => l.nextContactLinkId.equals(linkToRemove.id)))
        .getSingleOrNull();

    if (pointingLink != null) {
      await (_db.update(_db.profileContactLinks)..where((l) => l.id.equals(pointingLink.id))).write(
        ProfileContactLinksCompanion(nextContactLinkId: Value(linkToRemove.nextContactLinkId)),
      );
    }

    await (_db.delete(_db.profileContactLinks)..where((l) => l.id.equals(linkToRemove.id))).go();
  }

  @override
  Future<ProfileContactLink> updateContactLink({
    required UpdateProfileContactLinkCommand request,
    UuidValue? enforceOwnershipId,
  }) async {
    final link = await _getAndAuthorizeContactLink(request.contactLinkId, enforceOwnershipId);

    await (_db.update(_db.profileContactLinks)..where((l) => l.id.equals(link.id))).write(
      ProfileContactLinksCompanion(
        platform: request.platform != null ? Value(request.platform!) : const Value.absent(),
        url: request.url != null ? Value(request.url!) : const Value.absent(),
      ),
    );

    final updated = await (_db.select(_db.profileContactLinks)..where((l) => l.id.equals(link.id))).getSingle();
    return _mapContactLink(updated);
  }

  @override
  Future<void> reorderContactLink({
    required ReorderProfileContactLinksCommand request,
    UuidValue? enforceOwnershipId,
  }) async {
    final linkToMove = await _getAndAuthorizeContactLink(request.contactLinkId, enforceOwnershipId);

    final links = await (_db.select(_db.profileContactLinks)..where((l) => l.profileId.equals(linkToMove.profileId))).get();
    final sorted = _sortContactLinks(links);

    final oldIndex = sorted.indexWhere((l) => l.id == linkToMove.id);
    if (oldIndex == -1 || oldIndex == request.newIndex) return;

    sorted.removeAt(oldIndex);
    final targetIndex = request.newIndex.clamp(0, sorted.length);
    sorted.insert(targetIndex, linkToMove);

    await _db.batch((batch) {
      for (var i = 0; i < sorted.length; i++) {
        final current = sorted[i];
        final nextId = (i + 1 < sorted.length) ? sorted[i + 1].id : null;
        
        batch.update(
          _db.profileContactLinks,
          ProfileContactLinksCompanion(nextContactLinkId: Value(nextId)),
          where: (l) => l.id.equals(current.id),
        );
      }
    });
  }

  // =========================================================================
  // --- FUSIÓN DE PERFILES (MERGING) ---
  // =========================================================================

  @override
  Future<ProfileMergeRequest> createMergeRequest({
    required int targetProfileId,
    required UuidValue requesterAuthUserId,
  }) async {
    final sourceProfile = await (_db.select(_db.publicProfiles)..where((p) => p.userId.equals(requesterAuthUserId))).getSingleOrNull();
    if (sourceProfile == null) throw const UserProfileNotFoundException();

    final targetProfile = await (_db.select(_db.publicProfiles)..where((p) => p.id.equals(targetProfileId))).getSingleOrNull();
    if (targetProfile == null) throw const UserProfileNotFoundException();

    if (sourceProfile.id == targetProfile.id) throw const InvalidMergeRequestException();

    final existing = await (_db.select(_db.profileMergeRequests)
          ..where((r) => r.sourceProfileId.equals(sourceProfile.id) & 
                         r.targetProfileId.equals(targetProfile.id) & 
                         r.status.equals(0)))
        .getSingleOrNull();

    if (existing != null) {
      return _mapMergeRequest(existing);
    }

    final newRow = await _db.into(_db.profileMergeRequests).insertReturning(
      ProfileMergeRequestsCompanion.insert(
        targetProfileId: targetProfile.id,
        sourceProfileId: sourceProfile.id,
        requesterId: requesterAuthUserId,
        status: const Value(0),
      ),
    );

    return _mapMergeRequest(newRow);
  }

  @override
  Future<List<ProfileMergeRequest>> getMergeRequestsByStatus({
    ProfileMergeRequestStatus? status,
  }) async {
    final query = _db.select(_db.profileMergeRequests);
    if (status != null) {
      query.where((r) => r.status.equals(status.value));
    }

    final results = await query.get();
    return results.map(_mapMergeRequest).toList();
  }

  @override
  Future<ProfileMergeRequest> approveMergeRequest({
    required int requestId,
    required UuidValue resolverAuthUserId,
  }) async {
    final req = await (_db.select(_db.profileMergeRequests)..where((r) => r.id.equals(requestId))).getSingleOrNull();
    if (req == null) throw const InvalidMergeRequestException();
    if (req.status != 0) throw const InvalidMergeRequestException();

    // 1. Fusionar las cadenas de enlaces de contacto
    final sourceLinks = await (_db.select(_db.profileContactLinks)..where((l) => l.profileId.equals(req.sourceProfileId))).get();
    final targetLinks = await (_db.select(_db.profileContactLinks)..where((l) => l.profileId.equals(req.targetProfileId))).get();

    final sortedSource = _sortContactLinks(sourceLinks);
    final sortedTarget = _sortContactLinks(targetLinks);

    if (sortedTarget.isNotEmpty && sortedSource.isNotEmpty) {
      final targetTail = sortedTarget.last;
      final sourceHead = sortedSource.first;

      await (_db.update(_db.profileContactLinks)..where((l) => l.id.equals(targetTail.id))).write(
        ProfileContactLinksCompanion(nextContactLinkId: Value(sourceHead.id)),
      );
    }

    await (_db.update(_db.profileContactLinks)..where((l) => l.profileId.equals(req.sourceProfileId))).write(
      ProfileContactLinksCompanion(profileId: Value(req.targetProfileId)),
    );

    // 2. Transferir la identidad del AuthUser de la cuenta origen a la cuenta destino
    final sourceProfile = await (_db.select(_db.publicProfiles)..where((p) => p.id.equals(req.sourceProfileId))).getSingle();
    final targetProfile = await (_db.select(_db.publicProfiles)..where((p) => p.id.equals(req.targetProfileId))).getSingle();

    if (sourceProfile.userId != null) {
      final sourceUserId = sourceProfile.userId!;

      await (_db.update(_db.publicProfiles)..where((p) => p.id.equals(sourceProfile.id))).write(
        const PublicProfilesCompanion(userId: Value(null)),
      );

      await (_db.update(_db.publicProfiles)..where((p) => p.id.equals(targetProfile.id))).write(
        PublicProfilesCompanion(userId: Value(sourceUserId)),
      );
    }

    // 3. Resolver la solicitud de fusión
    final updatedRow = await (_db.update(_db.profileMergeRequests)..where((r) => r.id.equals(requestId))).writeReturning(
      ProfileMergeRequestsCompanion(
        status: const Value(1),
        resolvedById: Value(resolverAuthUserId),
        resolvedAt: Value(DateTime.now().toUtc()),
      ),
    );

    // 4. Eliminar el perfil de origen, ahora completamente vacío
    await (_db.delete(_db.publicProfiles)..where((p) => p.id.equals(req.sourceProfileId))).go();

    return _mapMergeRequest(updatedRow.first);
  }

  @override
  Future<ProfileMergeRequest> rejectMergeRequest({
    required int requestId,
    required UuidValue resolverAuthUserId,
  }) async {
    final req = await (_db.select(_db.profileMergeRequests)..where((r) => r.id.equals(requestId))).getSingleOrNull();
    if (req == null) throw const InvalidMergeRequestException();
    if (req.status != 0) throw const InvalidMergeRequestException();

    final updatedRow = await (_db.update(_db.profileMergeRequests)..where((r) => r.id.equals(requestId))).writeReturning(
      ProfileMergeRequestsCompanion(
        status: const Value(2),
        resolvedById: Value(resolverAuthUserId),
        resolvedAt: Value(DateTime.now().toUtc()),
      ),
    );

    return _mapMergeRequest(updatedRow.first);
  }
}
