import '../domain/models.dart';

abstract interface class SocialDiscoveryRepository {
  String get userId;
  Future<List<Member>> discover({
    Set<String> genders = const {},
    int minAge = 18,
    int maxAge = 65,
  });
  Future<void> interact(String memberId, bool interested);
  Future<List<BillRequest>> requests({String? ownerId});
  Future<String> submitBill({
    required String title,
    required String merchant,
    required int amountMinor,
    required String currency,
    required String category,
    required List<int> bytes,
    required String extension,
  });
  Future<List<Invitation>> invitations();
  Future<void> invite(
    Member member,
    BillRequest? request,
    String idempotencyKey,
  );
  Future<void> decide(String id, InvitationState decision);
  Future<List<ChatMessage>> messages(String invitationId);
  Stream<void> changes();
  Future<void> sendMessage(String invitationId, String body);
  Future<void> block(String memberId);
  Future<void> report(String memberId, String reason);
  Future<void> unmatch(String invitationId);
  Future<Map<String, dynamic>> ownProfile();
  Future<void> saveProfile(Map<String, dynamic> fields);
  Future<void> deleteAccount();
  Future<List<Map<String, dynamic>>> gallery(String memberId);
  Future<Uri> playback(String videoId);
}
