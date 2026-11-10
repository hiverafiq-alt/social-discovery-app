import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models.dart';
import 'repository.dart';

class SupabaseSocialDiscoveryRepository implements SocialDiscoveryRepository {
  SupabaseSocialDiscoveryRepository(this.client);
  final SupabaseClient client;
  @override
  String get userId => client.auth.currentUser!.id;
  @override
  Future<List<Member>> discover({
    Set<String> genders = const {},
    int minAge = 18,
    int maxAge = 65,
  }) async {
    final rows = await client.rpc(
      'discover_members',
      params: {
        'p_genders': genders.toList(),
        'p_min_age': minAge,
        'p_max_age': maxAge,
      },
    );
    return (rows as List)
        .map((j) => Member.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  @override
  Future<void> interact(String memberId, bool interested) async {
    await client.rpc(
      'record_interaction',
      params: {'p_subject': memberId, 'p_interested': interested},
    );
  }

  @override
  Future<List<BillRequest>> requests({String? ownerId}) async {
    final rows = await client
        .from('bill_requests')
        .select()
        .eq('owner_id', ownerId ?? userId);
    return rows.map(BillRequest.fromJson).toList();
  }

  @override
  Future<String> submitBill({
    required String title,
    required String merchant,
    required int amountMinor,
    required String currency,
    required String category,
    required List<int> bytes,
    required String extension,
  }) async {
    if (!['jpg', 'jpeg', 'png', 'pdf'].contains(extension)) {
      throw ArgumentError('Unsupported evidence type');
    }
    if (bytes.length > 10 * 1024 * 1024) {
      throw ArgumentError('Evidence must be under 10 MB');
    }
    final id =
        await client.rpc(
              'create_bill_draft',
              params: {
                'p_title': title,
                'p_merchant': merchant,
                'p_amount': amountMinor,
                'p_currency': currency,
                'p_category': category,
              },
            )
            as String;
    final path = '$userId/$id/evidence.$extension';
    await client.storage
        .from('bill-evidence')
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: extension == 'pdf'
                ? 'application/pdf'
                : extension == 'png'
                ? 'image/png'
                : 'image/jpeg',
          ),
        );
    await client.rpc(
      'attach_bill_evidence',
      params: {'p_bill': id, 'p_path': path},
    );
    return id;
  }

  @override
  Future<List<Invitation>> invitations() async {
    final rows = await client.rpc('list_invitations');
    return (rows as List)
        .map((j) => Invitation.fromJson(Map<String, dynamic>.from(j), userId))
        .toList();
  }

  @override
  Future<void> invite(
    Member member,
    BillRequest? request,
    String idempotencyKey,
  ) async {
    await client.rpc(
      'create_invitation',
      params: {
        'p_receiver': member.id,
        'p_request': request?.id,
        'p_key': idempotencyKey,
      },
    );
  }

  @override
  Future<void> decide(String id, InvitationState decision) async {
    await client.rpc(
      'decide_invitation',
      params: {'p_invitation': id, 'p_decision': decision.name},
    );
  }

  Future<String> _conversation(String invitationId) async => (await client
      .from('conversations')
      .select('id')
      .eq('invitation_id', invitationId)
      .single())['id'];
  @override
  Future<List<ChatMessage>> messages(String invitationId) async {
    final id = await _conversation(invitationId);
    final rows = await client
        .from('messages')
        .select()
        .eq('conversation_id', id)
        .order('created_at')
        .limit(100);
    return rows
        .map(
          (j) => ChatMessage(
            id: j['id'],
            body: j['body'],
            mine: j['sender_id'] == userId,
            at: DateTime.parse(j['created_at']),
          ),
        )
        .toList();
  }

  @override
  Stream<void> changes() {
    final stream = StreamController<void>();
    final channel = client.channel('member-events-$userId');
    for (final table in [
      'invitations',
      'messages',
      'conversations',
      'bill_requests',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => stream.add(null),
      );
    }
    channel.subscribe();
    stream.onCancel = () async {
      await client.removeChannel(channel);
    };
    return stream.stream;
  }

  @override
  Future<void> sendMessage(String invitationId, String body) async {
    await client.rpc(
      'send_message',
      params: {'p_invitation': invitationId, 'p_body': body},
    );
  }

  @override
  Future<void> block(String memberId) async {
    await client.rpc('block_member', params: {'p_subject': memberId});
  }

  @override
  Future<void> report(String memberId, String reason) async {
    await client.from('reports').insert({
      'reporter_id': userId,
      'subject_id': memberId,
      'reason': reason,
    });
  }

  @override
  Future<void> unmatch(String invitationId) async {
    await client.rpc(
      'close_conversation',
      params: {'p_invitation': invitationId},
    );
  }

  @override
  Future<Map<String, dynamic>> ownProfile() async {
    final profile = await client
        .from('profiles')
        .select('bio,pronouns,interests')
        .eq('id', userId)
        .single();
    final preference = await client
        .from('preferences')
        .select('role_mode')
        .eq('account_id', userId)
        .single();
    return {...profile, ...preference};
  }

  @override
  Future<void> saveProfile(Map<String, dynamic> fields) async {
    await client.rpc('save_profile', params: {'p_fields': fields});
  }

  @override
  Future<void> deleteAccount() async {
    final r = await client.functions.invoke('account-delete');
    if (r.status != 200) throw StateError('Could not request account deletion');
    await client.auth.signOut();
  }

  @override
  Future<List<Map<String, dynamic>>> gallery(String memberId) async =>
      List<Map<String, dynamic>>.from(
        await client.rpc('profile_gallery', params: {'p_owner': memberId}),
      );
  @override
  Future<Uri> playback(String videoId) async {
    final r = await client.functions.invoke(
      'playback-grant',
      body: {'media_id': videoId},
    );
    if (r.status != 200) throw StateError('Video access unavailable');
    return Uri.parse(r.data['url']);
  }
}
