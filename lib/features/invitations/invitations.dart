import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../design/theme.dart';
import '../../domain/models.dart';

class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Invitations')),
    body: ref
        .watch(invitationsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(invitationsProvider),
              child: const Text('Reconnect to your invitations'),
            ),
          ),
          data: (items) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Eyebrow('A door, never an obligation'),
              const SizedBox(height: 12),
              Text(
                'Something could\nstart here.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 24),
              if (items.isEmpty)
                const Panel(
                  child: Text('Your next hello is still on its way.'),
                ),
              ...items.reversed.map(
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InvitationTile(invitation: i),
                ),
              ),
            ],
          ),
        ),
  );
}

class InvitationTile extends ConsumerStatefulWidget {
  const InvitationTile({super.key, required this.invitation});
  final Invitation invitation;
  @override
  ConsumerState<InvitationTile> createState() => _InvitationTileState();
}

class _InvitationTileState extends ConsumerState<InvitationTile> {
  bool busy = false;
  Future<void> decide(InvitationState state) async {
    setState(() => busy = true);
    try {
      await ref.read(repositoryProvider).decide(widget.invitation.id, state);
      ref.invalidate(invitationsProvider);
    } catch (_) {
      if (mounted && context.mounted) {
        notice(
          context,
          'This invitation may have changed. Refresh and try again.',
        );
      }
    }
    if (mounted && context.mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.invitation;
    final incoming = i.receiverId == ref.read(repositoryProvider).userId;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: P.plum,
                foregroundColor: P.lilac,
                child: Text(i.memberName[0]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.memberName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      incoming ? 'A hello for you' : 'Your invitation',
                      style: const TextStyle(color: P.mist),
                    ),
                  ],
                ),
              ),
              Text(
                i.state.name,
                style: TextStyle(
                  color: i.state == InvitationState.accepted ? P.teal : P.mist,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            i.requestId == null
                ? 'Free connection. Mutual choice.'
                : 'Simulation only · ${switch (i.contribution) {
                    ContributionState.simulatedAuthorized => 'Illustrative authorization pending',
                    ContributionState.simulatedCaptured => 'Illustrative contribution completed',
                    ContributionState.simulatedVoided => 'Illustrative authorization voided',
                  }}',
            style: const TextStyle(color: P.mist),
          ),
          if (i.state == InvitationState.pending) ...[
            const SizedBox(height: 12),
            Text(
              'Expires ${i.expiresAt.toLocal().toString().substring(0, 16)}',
              style: const TextStyle(fontSize: 12, color: P.mist),
            ),
            const SizedBox(height: 20),
            if (incoming)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => decide(InvitationState.declined),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: busy
                          ? null
                          : () => decide(InvitationState.accepted),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => decide(InvitationState.cancelled),
                child: const Text('Cancel invitation'),
              ),
          ],
          if (i.chatAllowed) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.push('/chat/${i.id}'),
              child: const Text('Open conversation'),
            ),
          ],
        ],
      ),
    );
  }
}
