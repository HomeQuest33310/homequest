import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/family.dart';
import '../domain/family_invitation.dart';
import '../domain/family_member.dart';
import 'family_repository.dart';

class SupabaseFamilyRepository implements FamilyRepository {
  SupabaseFamilyRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Family> createFamily({
    required String familyName,
    required String kingdomName,
    required String primaryDomainName,
    required String ownerId,
  }) async {
    final data = await _client.rpc(
      'create_kingdom',
      params: {
        'p_family_name': familyName,
        'p_kingdom_name': kingdomName,
        'p_primary_domain_name': primaryDomainName,
      },
    );

    return Family.fromMap(
      Map<String, dynamic>.from(data as Map),
    );
  }

  @override
  Future<Family?> getCurrentUserFamily(String userId) async {
    final now = DateTime.now().toUtc().toIso8601String();

    final memberships = await _client
        .from('family_members')
        .select('family_id')
        .eq('user_id', userId)
        .eq('is_active', true)
        .or('expires_at.is.null,expires_at.gt.$now')
        .limit(1);

    if (memberships.isEmpty) {
      return null;
    }

    final familyId = memberships.first['family_id'] as String;

    final data = await _client
        .from('families')
        .select()
        .eq('id', familyId)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return Family.fromMap(
      Map<String, dynamic>.from(data),
    );
  }

  @override
  Future<Family?> getFamilyById(String familyId) async {
    final data = await _client
        .from('families')
        .select()
        .eq('id', familyId)
        .maybeSingle();

    if (data == null) return null;
    return Family.fromMap(Map<String, dynamic>.from(data));
  }

  @override
  Future<List<FamilyMember>> getMembers(String kingdomId) async {
    final data = await _client.from('kingdom_members').select('''
          role,
          expires_at,
          is_active,
          member:family_members!kingdom_members_member_id_fkey!inner(
            id,
            user_id,
            level,
            xp,
            gold,
            is_active,
            profile:profiles!family_members_user_id_fkey(
              id,
              display_name,
              avatar_key
            )
          )
        ''')
        .eq('kingdom_id', kingdomId)
        .eq('is_active', true)
        .order('joined_at');

    return (data as List).where((item) {
      final membership = Map<String, dynamic>.from(item as Map);
      final expiresAt = membership['expires_at'] as String?;
      if (expiresAt != null &&
          !DateTime.parse(expiresAt).isAfter(DateTime.now())) {
        return false;
      }
      final member = Map<String, dynamic>.from(membership['member'] as Map);
      return member['is_active'] == true;
    }).map((item) {
      final membershipData = Map<String, dynamic>.from(item as Map);
      final memberData = Map<String, dynamic>.from(
        membershipData['member'] as Map,
      );
      memberData['role'] = membershipData['role'];
      final profileData = Map<String, dynamic>.from(
        memberData['profile'] as Map,
      );

      return _memberFromData(
        memberData: memberData,
        profileData: profileData,
      );
    }).toList();
  }

  @override
  Future<FamilyMember> changeMemberRole({
    required String memberId,
    required String newRole,
  }) async {
    final data = await _client.rpc(
      'change_family_member_role',
      params: {
        'p_member_id': memberId,
        'p_new_role': newRole,
      },
    );

    return _loadMemberFromRpcResult(data);
  }

  @override
  Future<FamilyMember> deactivateMember(String memberId) async {
    final data = await _client.rpc(
      'deactivate_family_member',
      params: {
        'p_member_id': memberId,
      },
    );

    return _loadMemberFromRpcResult(data);
  }

  Future<FamilyMember> _loadMemberFromRpcResult(dynamic data) async {
    final memberData = Map<String, dynamic>.from(data as Map);

    final profileData = await _client
        .from('profiles')
        .select('display_name, avatar_key')
        .eq('id', memberData['user_id'])
        .single();

    return _memberFromData(
      memberData: memberData,
      profileData: Map<String, dynamic>.from(profileData),
    );
  }

  FamilyMember _memberFromData({
    required Map<String, dynamic> memberData,
    required Map<String, dynamic> profileData,
  }) {
    return FamilyMember(
      id: memberData['id'] as String,
      userId: memberData['user_id'] as String,
      displayName: profileData['display_name'] as String,
      avatarKey: profileData['avatar_key'] as String?,
      role: memberData['role'] as String,
      level: memberData['level'] as int,
      xp: memberData['xp'] as int,
      gold: memberData['gold'] as int,
      isActive: memberData['is_active'] as bool,
      membershipScope: memberData['membership_scope'] as String? ?? 'kingdom',
      domainId: memberData['domain_id'] as String?,
      expiresAt: memberData['expires_at'] == null
          ? null
          : DateTime.parse(memberData['expires_at'] as String),
    );
  }

  @override
  Future<List<FamilyInvitation>> getInvitations(String kingdomId) async {
    final data = await _client
        .from('family_invitations')
        .select()
        .eq('kingdom_id', kingdomId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (data as List)
        .map(
          (item) => FamilyInvitation.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  @override
  Future<FamilyInvitation?> getInvitationByToken(String token) async {
    final data = await _client
        .from('family_invitations')
        .select()
        .eq('token', token)
        .maybeSingle();

    if (data == null) return null;
    return FamilyInvitation.fromMap(Map<String, dynamic>.from(data));
  }

  @override
  Future<FamilyInvitation> inviteMember({
    required String familyId,
    required String kingdomId,
    required String email,
    required String role,
    required String membershipScope,
    String? domainId,
    int expiresInDays = 7,
  }) async {
    final response = await _client.functions.invoke(
      'send-family-invitation',
      body: {
        'family_id': familyId,
        'kingdom_id': kingdomId,
        'email': email,
        'role': role,
        'membership_scope': membershipScope,
        'domain_id': domainId,
        'expires_in_days': expiresInDays,
      },
    );

    final payload = Map<String, dynamic>.from(response.data as Map);
    if (payload['error'] != null) {
      throw AuthException(payload['error'] as String);
    }
    final invitation = Map<String, dynamic>.from(payload['invitation'] as Map);
    invitation['email_sent'] = payload['email_sent'];
    invitation['email_error'] = payload['email_error'];
    return FamilyInvitation.fromMap(
      invitation,
    );
  }

  @override
  Future<void> cancelInvitation(String invitationId) async {
    await _client.rpc(
      'cancel_family_invitation',
      params: {'p_invitation_id': invitationId},
    );
  }

  @override
  Future<void> acceptInvitation(String token) async {
    await _client.rpc(
      'accept_family_invitation',
      params: {'p_token': token},
    );
  }
}
