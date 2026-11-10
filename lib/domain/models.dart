enum RoleMode { support, share, both }

enum InvitationState { pending, accepted, declined, expired, cancelled }

enum ContributionState {
  simulatedAuthorized,
  simulatedCaptured,
  simulatedVoided,
}

class Member {
  const Member({
    required this.id,
    required this.name,
    required this.age,
    required this.region,
    required this.bio,
    required this.interests,
    this.gender = 'nonbinary',
    this.videoId,
    this.posterUrl,
    this.reviewed = false,
  });
  final String id, name, region, bio, gender;
  final int age;
  final List<String> interests;
  final String? videoId, posterUrl;
  final bool reviewed;
  factory Member.fromJson(Map<String, dynamic> j) => Member(
    id: j['id'],
    name: j['display_name'],
    age: j['age'],
    region: j['region'],
    bio: j['bio'] ?? '',
    gender: j['gender'] ?? 'nonbinary',
    interests: List<String>.from(j['interests'] ?? []),
    videoId: j['video_id'],
    posterUrl: j['poster_url'],
    reviewed: j['reviewed'] == true,
  );
}

class BillRequest {
  const BillRequest({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.amountMinor,
    this.currency = 'GBP',
    this.status = 'pending',
    this.category = 'Everyday',
    this.merchant = '',
  });
  final String id, ownerId, title, currency, status, category, merchant;
  final int amountMinor;
  String get amount => '$currency ${(amountMinor / 100).toStringAsFixed(2)}';
  factory BillRequest.fromJson(Map<String, dynamic> j) => BillRequest(
    id: j['id'],
    ownerId: j['owner_id'],
    title: j['safe_title'],
    amountMinor: j['amount_minor'],
    currency: j['currency'],
    status: j['status'],
    category: j['category'],
    merchant: j['merchant'] ?? '',
  );
}

class Invitation {
  const Invitation({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.memberName,
    required this.createdAt,
    required this.expiresAt,
    this.state = InvitationState.pending,
    this.contribution = ContributionState.simulatedAuthorized,
    this.requestId,
  });
  final String id, senderId, receiverId, memberName;
  final String? requestId;
  final DateTime createdAt, expiresAt;
  final InvitationState state;
  final ContributionState contribution;
  Invitation decide(InvitationState decision, DateTime now) {
    if (state != InvitationState.pending) {
      throw StateError('Invitation already resolved');
    }
    if (!{
      InvitationState.accepted,
      InvitationState.declined,
      InvitationState.cancelled,
      InvitationState.expired,
    }.contains(decision)) {
      throw StateError('Invalid invitation decision');
    }
    final next = !now.isBefore(expiresAt) ? InvitationState.expired : decision;
    return Invitation(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      memberName: memberName,
      createdAt: createdAt,
      expiresAt: expiresAt,
      requestId: requestId,
      state: next,
      contribution: next == InvitationState.accepted
          ? ContributionState.simulatedCaptured
          : ContributionState.simulatedVoided,
    );
  }

  bool get chatAllowed => state == InvitationState.accepted;
  factory Invitation.fromJson(Map<String, dynamic> j, String self) =>
      Invitation(
        id: j['id'],
        senderId: j['sender_id'],
        receiverId: j['receiver_id'],
        memberName: j['peer_name'] ?? 'Connection',
        requestId: j['request_id'],
        createdAt: DateTime.parse(j['created_at']),
        expiresAt: DateTime.parse(j['expires_at']),
        state: InvitationState.values.byName(j['state']),
        contribution: j['state'] == 'accepted'
            ? ContributionState.simulatedCaptured
            : j['state'] == 'pending'
            ? ContributionState.simulatedAuthorized
            : ContributionState.simulatedVoided,
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.mine,
    required this.at,
  });
  final String id, body;
  final bool mine;
  final DateTime at;
}

abstract final class IntroPolicy {
  static bool valid(Duration d) =>
      d >= const Duration(seconds: 5) && d <= const Duration(seconds: 10);
  static bool adult(DateTime dob, DateTime now) {
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age >= 18 && age <= 120 && !dob.isAfter(now);
  }
}
