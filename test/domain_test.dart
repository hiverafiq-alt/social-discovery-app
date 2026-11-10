import 'package:flutter_test/flutter_test.dart';
import 'package:social_discovery/domain/models.dart';
import 'package:social_discovery/data/demo_repository.dart';

void main() {
  final now = DateTime.utc(2026, 10, 28, 12);
  Invitation pending({DateTime? expiry}) => Invitation(
    id: 'i',
    senderId: 'a',
    receiverId: 'b',
    memberName: 'B',
    createdAt: now,
    expiresAt: expiry ?? now.add(const Duration(hours: 72)),
  );
  test(
    'intro rejects imports by contract and enforces duration boundaries',
    () {
      expect(IntroPolicy.valid(const Duration(milliseconds: 4999)), false);
      expect(IntroPolicy.valid(const Duration(seconds: 5)), true);
      expect(IntroPolicy.valid(const Duration(seconds: 10)), true);
      expect(IntroPolicy.valid(const Duration(milliseconds: 10001)), false);
    },
  );
  test('adult threshold handles exact birthday and tomorrow', () {
    expect(IntroPolicy.adult(DateTime(2008, 10, 28), now), true);
    expect(IntroPolicy.adult(DateTime(2008, 10, 29), now), false);
    expect(IntroPolicy.adult(DateTime(2030), now), false);
  });
  test('acceptance opens chat with simulated capture only', () {
    final accepted = pending().decide(InvitationState.accepted, now);
    expect(accepted.chatAllowed, true);
    expect(accepted.contribution, ContributionState.simulatedCaptured);
  });
  for (final state in [
    InvitationState.declined,
    InvitationState.cancelled,
    InvitationState.expired,
  ]) {
    test('$state voids the illustrative authorization and closes chat', () {
      final result = pending().decide(state, now);
      expect(result.chatAllowed, false);
      expect(result.contribution, ContributionState.simulatedVoided);
    });
  }
  test('expiry wins over simultaneous acceptance at the boundary', () {
    final result = pending(expiry: now).decide(InvitationState.accepted, now);
    expect(result.state, InvitationState.expired);
    expect(result.chatAllowed, false);
  });
  test('terminal invitation cannot be changed', () {
    final resolved = pending().decide(InvitationState.declined, now);
    expect(
      () => resolved.decide(InvitationState.accepted, now),
      throwsStateError,
    );
  });
  test('pending cannot be its own decision', () {
    expect(
      () => pending().decide(InvitationState.pending, now),
      throwsStateError,
    );
  });
  test('demo prevents messages before recipient acceptance', () async {
    final repo = DemoRepository();
    await expectLater(
      repo.sendMessage('sample-incoming', 'hello'),
      throwsStateError,
    );
    await repo.decide('sample-incoming', InvitationState.accepted);
    await repo.sendMessage('sample-incoming', 'hello');
    expect((await repo.messages('sample-incoming')).single.body, 'hello');
  });
  test('block revokes chat and removes discovery', () async {
    final repo = DemoRepository();
    await repo.decide('sample-incoming', InvitationState.accepted);
    await repo.block('alex');
    await expectLater(
      repo.sendMessage('sample-incoming', 'hello'),
      throwsStateError,
    );
    expect((await repo.discover()).any((m) => m.id == 'alex'), false);
  });
  test('repeat invite request is idempotent', () async {
    final repo = DemoRepository();
    final member = (await repo.discover()).first;
    await repo.invite(member, null, 'stable-key');
    await repo.invite(member, null, 'stable-key');
    expect(
      (await repo.invitations()).where((i) => i.id == 'stable-key').length,
      1,
    );
  });
  test('recipient only decides incoming invitations', () async {
    final repo = DemoRepository();
    final member = (await repo.discover()).first;
    await repo.invite(member, null, 'sent');
    await expectLater(
      repo.decide('sent', InvitationState.accepted),
      throwsStateError,
    );
  });
  test('gender preferences are independent from role and age', () async {
    final repo = DemoRepository();
    final results = await repo.discover(
      genders: {'man'},
      minAge: 30,
      maxAge: 35,
    );
    expect(results.map((m) => m.name), ['Noah']);
  });
  test('editing demo story preserves values for reopening the form', () async {
    final repo = DemoRepository();
    await repo.saveProfile({'bio': 'A new story', 'role_mode': 'share'});
    final profile = await repo.ownProfile();
    expect(profile['bio'], 'A new story');
    expect(profile['role_mode'], 'share');
  });
}
