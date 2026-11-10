import 'dart:async';
import '../domain/models.dart';
import 'repository.dart';

// Fixture identities are fictional. No stock portrait is represented as a real member.
class DemoRepository implements SocialDiscoveryRepository {
  @override
  String get userId => 'self';
  final _events = StreamController<void>.broadcast();
  final _blocked = <String>{}, _seen = <String>{};
  final _members = const [
    Member(
      id: 'maya',
      name: 'Maya',
      age: 27,
      region: 'London',
      gender: 'woman',
      bio: 'A book in my bag. A new place on my mind.',
      interests: ['Art after hours', 'Slow Sundays', 'Coffee'],
    ),
    Member(
      id: 'alex',
      name: 'Alex',
      age: 29,
      region: 'Paris',
      gender: 'nonbinary',
      bio: 'Collecting little moments, never things.',
      interests: ['Film photography', 'Design', 'Travel'],
    ),
    Member(
      id: 'noah',
      name: 'Noah',
      age: 31,
      region: 'Dubai',
      gender: 'man',
      bio: 'Good food, better company. Always curious.',
      interests: ['Cooking', 'Architecture', 'The sea'],
    ),
  ];
  final _bills = <BillRequest>[
    const BillRequest(
      id: 'b1',
      ownerId: 'maya',
      title: 'Coffee, a book, a little pause',
      amountMinor: 2400,
      status: 'demo',
      category: 'Everyday',
      merchant: 'Fictional café',
    ),
    const BillRequest(
      id: 'b2',
      ownerId: 'alex',
      title: 'A week of creative possibility',
      amountMinor: 3600,
      currency: 'EUR',
      status: 'demo',
      category: 'Learning',
    ),
  ];
  late final _invites = <Invitation>[
    Invitation(
      id: 'sample-incoming',
      senderId: 'alex',
      receiverId: 'self',
      memberName: 'Alex',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 72)),
    ),
  ];
  final _messages = <String, List<ChatMessage>>{};
  void _emit() => _events.add(null);
  @override
  Future<List<Member>> discover({
    Set<String> genders = const {},
    int minAge = 18,
    int maxAge = 65,
  }) async => _members
      .where(
        (m) =>
            !_blocked.contains(m.id) &&
            !_seen.contains(m.id) &&
            m.age >= minAge &&
            m.age <= maxAge &&
            (genders.isEmpty || genders.contains(m.gender)),
      )
      .toList();
  @override
  Future<void> interact(String memberId, bool interested) async {
    _seen.add(memberId);
  }

  @override
  Future<List<BillRequest>> requests({String? ownerId}) async => _bills
      .where(
        (b) => ownerId == null ? b.ownerId == userId : b.ownerId == ownerId,
      )
      .toList();
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
    final id = 'draft-${_bills.length}';
    _bills.add(
      BillRequest(
        id: id,
        ownerId: userId,
        title: title,
        merchant: merchant,
        amountMinor: amountMinor,
        currency: currency,
        category: category,
      ),
    );
    _emit();
    return id;
  }

  @override
  Future<List<Invitation>> invitations() async {
    for (var i = 0; i < _invites.length; i++) {
      if (_invites[i].state == InvitationState.pending &&
          !DateTime.now().isBefore(_invites[i].expiresAt)) {
        _invites[i] = _invites[i].decide(
          InvitationState.expired,
          DateTime.now(),
        );
      }
    }
    return _invites
        .where(
          (i) =>
              !_blocked.contains(i.senderId) &&
              !_blocked.contains(i.receiverId),
        )
        .toList();
  }

  @override
  Future<void> invite(
    Member member,
    BillRequest? request,
    String idempotencyKey,
  ) async {
    if (_invites.any((i) => i.id == idempotencyKey)) return;
    if (_blocked.contains(member.id)) {
      throw StateError('Connection unavailable');
    }
    _invites.add(
      Invitation(
        id: idempotencyKey,
        senderId: userId,
        receiverId: member.id,
        memberName: member.name,
        requestId: request?.id,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 72)),
      ),
    );
    _emit();
  }

  @override
  Future<void> decide(String id, InvitationState decision) async {
    final index = _invites.indexWhere((i) => i.id == id);
    if (index < 0) throw StateError('Invitation unavailable');
    final invite = _invites[index];
    if (invite.receiverId != userId && decision != InvitationState.cancelled) {
      throw StateError('Only the recipient may decide');
    }
    _invites[index] = invite.decide(decision, DateTime.now());
    _emit();
  }

  void _requireChat(String id) {
    final invite = _invites.firstWhere((i) => i.id == id);
    if (!invite.chatAllowed ||
        _blocked.contains(invite.senderId) ||
        _blocked.contains(invite.receiverId)) {
      throw StateError('This conversation is unavailable');
    }
  }

  @override
  Future<List<ChatMessage>> messages(String invitationId) async {
    _requireChat(invitationId);
    return List.of(_messages[invitationId] ?? []);
  }

  @override
  Future<void> sendMessage(String invitationId, String body) async {
    _requireChat(invitationId);
    if (body.trim().isEmpty || body.length > 2000) {
      throw ArgumentError('Message must contain 1 to 2000 characters');
    }
    (_messages[invitationId] ??= []).add(
      ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        body: body.trim(),
        mine: true,
        at: DateTime.now(),
      ),
    );
    _emit();
  }

  @override
  Stream<void> changes() => _events.stream;
  @override
  Future<void> block(String memberId) async {
    _blocked.add(memberId);
    _emit();
  }

  @override
  Future<void> report(String memberId, String reason) async {
    _emit();
  }

  @override
  Future<void> unmatch(String invitationId) async {
    final i = _invites.indexWhere((e) => e.id == invitationId);
    final old = _invites[i];
    _invites[i] = Invitation(
      id: old.id,
      senderId: old.senderId,
      receiverId: old.receiverId,
      memberName: old.memberName,
      createdAt: old.createdAt,
      expiresAt: old.expiresAt,
      state: InvitationState.cancelled,
      contribution: old.contribution,
    );
    _emit();
  }

  final _self = <String, dynamic>{
    'bio': '',
    'pronouns': '',
    'interests': <String>[],
    'role_mode': 'both',
  };
  @override
  Future<Map<String, dynamic>> ownProfile() async => Map.of(_self);
  @override
  Future<void> saveProfile(Map<String, dynamic> fields) async {
    _self.addAll(fields);
  }

  @override
  Future<void> deleteAccount() async {
    _bills.clear();
    _invites.clear();
    _messages.clear();
    _emit();
  }

  @override
  Future<List<Map<String, dynamic>>> gallery(String memberId) async => [];
  @override
  Future<Uri> playback(String videoId) => throw StateError(
    'No fixture video. Record an introduction or configure Bunny.',
  );
}
