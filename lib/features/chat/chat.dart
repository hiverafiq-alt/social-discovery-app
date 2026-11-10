import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../design/theme.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.invitationId});
  final String invitationId;
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final text = TextEditingController();
  bool sending = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (text.text.trim().isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await ref
          .read(repositoryProvider)
          .sendMessage(widget.invitationId, text.text);
      text.clear();
      ref.invalidate(messagesProvider(widget.invitationId));
    } catch (_) {
      if (mounted && context.mounted) {
        notice(
          context,
          'Message not sent. Your connection may be unavailable.',
        );
      }
    }
    if (mounted && context.mounted) setState(() => sending = false);
  }

  Future<void> safety(String action) async {
    final items = await ref.read(repositoryProvider).invitations();
    final invitation = items.firstWhere((i) => i.id == widget.invitationId);
    final repo = ref.read(repositoryProvider);
    final other = invitation.senderId == repo.userId
        ? invitation.receiverId
        : invitation.senderId;
    if (action == 'block') {
      await repo.block(other);
    } else if (action == 'report') {
      await repo.report(other, 'Conversation review requested');
    } else {
      await repo.unmatch(widget.invitationId);
    }
    if (mounted && context.mounted) {
      notice(
        context,
        action == 'report'
            ? 'Report received for review.'
            : 'Connection closed.',
      );
      if (action != 'report') Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your conversation'),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Conversation safety',
          onSelected: (a) async {
            try {
              await safety(a);
            } catch (_) {
              if (mounted && context.mounted) {
                notice(context, 'Please try again.');
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'report', child: Text('Report')),
            PopupMenuItem(value: 'block', child: Text('Block member')),
            PopupMenuItem(value: 'unmatch', child: Text('End connection')),
          ],
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'A mutual hello. Go at your own pace.',
                  style: TextStyle(color: P.mist),
                ),
              ),
              Expanded(
                child: ref
                    .watch(messagesProvider(widget.invitationId))
                    .when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const Center(
                        child: Text('This conversation is unavailable.'),
                      ),
                      data: (items) => items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Monogram(size: 64),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Start with a little hello.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.all(20),
                              itemCount: items.length,
                              itemBuilder: (_, index) {
                                final m = items[items.length - 1 - index];
                                return Align(
                                  alignment: m.mine
                                      ? AlignmentDirectional.centerEnd
                                      : AlignmentDirectional.centerStart,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 340,
                                    ),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: m.mine ? P.plum : P.surface,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(m.body),
                                  ),
                                );
                              },
                            ),
                    ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: text,
                        maxLength: 2000,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'A little hello…',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      onPressed: sending ? null : send,
                      icon: const Icon(Icons.arrow_upward),
                      tooltip: 'Send message',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
