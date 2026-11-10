import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../design/theme.dart';
import '../../domain/models.dart';
import '../media/player.dart';
import '../media/gallery.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});
  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion;
  Animation<double>? movement;
  @override
  void initState() {
    super.initState();
    motion =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 240),
        )..addListener(() {
          if (mounted && movement != null) {
            setState(() => drag = movement!.value);
          }
        });
  }

  Future<void> move(double target) async {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => drag = target);
      return;
    }
    movement = Tween<double>(
      begin: drag,
      end: target,
    ).animate(CurvedAnimation(parent: motion, curve: Curves.easeOutCubic));
    await motion.forward(from: 0);
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  int index = 0;
  double drag = 0;
  bool modal = false, busy = false;
  Future<void> pass(Member m) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ref.read(repositoryProvider).interact(m.id, false);
      if (!mounted) return;
      await move(-MediaQuery.sizeOf(context).width);
      if (mounted && context.mounted) {
        setState(() {
          index++;
          drag = 0;
        });
      }
    } catch (_) {
      if (mounted && context.mounted) {
        setState(() => drag = 0);
        notice(context, 'Could not save your choice. Try again.');
      }
    }
    if (mounted && context.mounted) setState(() => busy = false);
  }

  Future<void> interest(Member m) async {
    if (busy) return;
    setState(() {
      modal = true;
      busy = true;
    });
    await move(0);
    if (!mounted) return;
    final sent = await sheet<bool>(context, InvitationDrawer(member: m));
    if (!mounted) return;
    if (sent == true) await move(MediaQuery.sizeOf(context).width);
    if (!mounted) return;
    setState(() {
      modal = false;
      busy = false;
      drag = 0;
      if (sent == true) index++;
    });
  }

  Future<void> filters() async {
    setState(() => modal = true);
    await sheet(context, const FiltersSheet());
    if (mounted && context.mounted) {
      setState(() {
        modal = false;
        index = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
        child: Row(
          children: [
            const Monogram(size: 36),
            const SizedBox(width: 10),
            const Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
              'discover',
              style: TextStyle(
                fontSize: 27,
                letterSpacing: -1,
                fontWeight: FontWeight.w600,
              ),
            ))),

            const SizedBox(width: 12),
            IconButton(
              onPressed: filters,
              icon: const Icon(Icons.tune),
              tooltip: 'Discovery preferences',
            ),
          ],
        ),
      ),
      Expanded(
        child: ref
            .watch(discoveryProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'A little pause. Your connection needs a moment.',
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(discoveryProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
              data: (members) {
                if (index >= members.length) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Monogram(size: 72),
                          const SizedBox(height: 32),
                          Text(
                            'Room for serendipity.',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'You’re all caught up. New introductions will find their way here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: P.mist),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => index = 0);
                              ref.invalidate(discoveryProvider);
                            },
                            child: const Text('Refresh introductions'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final m = members[index];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Column(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) => GestureDetector(
                                onHorizontalDragUpdate: busy
                                    ? null
                                    : (d) => setState(() => drag += d.delta.dx),
                                onHorizontalDragEnd: busy
                                    ? null
                                    : (_) {
                                        if (ref.read(hapticsProvider)) {
                                          HapticFeedback.selectionClick();
                                        }
                                        if (drag > constraints.maxWidth * .24) {
                                          interest(m);
                                        } else if (drag <
                                            -constraints.maxWidth * .24) {
                                          pass(m);
                                        } else {
                                          move(0);
                                        }
                                      },
                                child: Transform.translate(
                                  offset: Offset(drag, 0),
                                  child: Transform.rotate(
                                    angle:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? 0
                                        : (drag / 2500).clamp(-.15, .15),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(28),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (m.videoId == null)
                                            StudioPortrait(name: m.name)
                                          else
                                            LivingVideo(
                                              key: ValueKey(m.videoId),
                                              grant: () => ref
                                                  .read(repositoryProvider)
                                                  .playback(m.videoId!),
                                              posterUrl: m.posterUrl,
                                              paused: modal,
                                              tapToPlay: ref.watch(
                                                dataSaverProvider,
                                              ),
                                            ),
                                          const IgnorePointer(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  stops: [.32, .7, 1],
                                                  colors: [
                                                    Colors.transparent,
                                                    Color(0xB0090711),
                                                    P.ink,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: 24,
                                            right: 24,
                                            bottom: 24,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '${m.name}, ${m.age}',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .headlineLarge,
                                                      ),
                                                    ),
                                                    if (m.reviewed)
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              left: 8,
                                                            ),
                                                        child: Icon(
                                                          Icons
                                                              .verified_outlined,
                                                          color: P.teal,
                                                          size: 22,
                                                        ),
                                                      ),
                                                    IconButton(
                                                      onPressed: () =>
                                                          profile(m),
                                                      icon: const Icon(
                                                        Icons.arrow_outward,
                                                      ),
                                                      tooltip: 'Open profile',
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  m.region,
                                                  style: const TextStyle(
                                                    color: P.mist,
                                                  ),
                                                ),
                                                const SizedBox(height: 14),
                                                Text(
                                                  m.bio,
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    height: 1.4,
                                                  ),
                                                ),
                                                const SizedBox(height: 18),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: m.interests
                                                      .take(2)
                                                      .map(
                                                        (s) => Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 12,
                                                                vertical: 7,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            border: Border.all(
                                                              color: P.mist
                                                                  .withValues(
                                                                    alpha: .4,
                                                                  ),
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  30,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            s,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                                ),
                                                const SizedBox(height: 18),
                                                InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  onTap: () => interest(m),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: P.surface,
                                                      border: Border.all(
                                                        color: P.line,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            18,
                                                          ),
                                                    ),
                                                    child: const Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .auto_awesome_outlined,
                                                          size: 20,
                                                          color: P.lilac,
                                                        ),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                          child: Text(
                                                            'A little moment to share',
                                                          ),
                                                        ),
                                                        Icon(
                                                          Icons.chevron_right,
                                                          size: 20,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (drag.abs() > 30)
                                            Positioned(
                                              top: 100,
                                              left: 24,
                                              child: Opacity(
                                                opacity: math.min(
                                                  drag.abs() / 100,
                                                  1,
                                                ),
                                                child: Text(
                                                  drag > 0
                                                      ? 'A LITTLE SPARK'
                                                      : 'ANOTHER MOMENT',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: P.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                  onPressed: busy ? null : () => pass(m),
                                  icon: const Icon(Icons.close, size: 20),
                                  label: const Text('Pass'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                  onPressed: busy ? null : () => interest(m),
                                  icon: const Icon(
                                    Icons.auto_awesome_outlined,
                                    size: 20,
                                  ),
                                  label: const Text('Interested'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      ),
    ],
  );
  Future<void> profile(Member m) async {
    setState(() => modal = true);
    await sheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Beyond the introduction'),
          const SizedBox(height: 16),
          Text(
            '${m.name}, ${m.age}',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(m.region, style: const TextStyle(color: P.mist)),
          const SizedBox(height: 24),
          Text(m.bio),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: m.interests.map((i) => Chip(label: Text(i))).toList(),
          ),
          const SizedBox(height: 24),
          SupportingMoments(
            load: () => ref.read(repositoryProvider).gallery(m.id),
            grant: (id) => ref.read(repositoryProvider).playback(id),
          ),
          const Text(
            'A connection is always a choice. Support never guarantees attention.',
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () async {
              await ref
                  .read(repositoryProvider)
                  .report(m.id, 'Profile review requested');
              if (mounted && context.mounted) {
                if (mounted) Navigator.of(context).pop();
                notice(context, 'Report received for review.');
              }
            },
            child: const Text('Report profile'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(repositoryProvider).block(m.id);
              ref.invalidate(discoveryProvider);
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('Block member'),
          ),
        ],
      ),
    );
    if (mounted && context.mounted) setState(() => modal = false);
  }
}

class FiltersSheet extends ConsumerStatefulWidget {
  const FiltersSheet({super.key});
  @override
  ConsumerState<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<FiltersSheet> {
  late Set<String> genders;
  late RangeValues ages;
  @override
  void initState() {
    super.initState();
    final f = ref.read(filtersProvider);
    genders = {...f.genders};
    ages = RangeValues(f.minAge.toDouble(), f.maxAge.toDouble());
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Eyebrow('Your kind of connection'),
      const SizedBox(height: 16),
      Text(
        'Leave room for a spark.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 24),
      const Text('Discover'),
      Wrap(
        spacing: 8,
        children: ['woman', 'man', 'nonbinary', 'self-described']
            .map(
              (g) => FilterChip(
                label: Text(g),
                selected: genders.contains(g),
                onSelected: (v) => setState(() {
                  v ? genders.add(g) : genders.remove(g);
                }),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 24),
      Text('Age ${ages.start.round()} to ${ages.end.round()}'),
      RangeSlider(
        values: ages,
        min: 18,
        max: 80,
        divisions: 62,
        onChanged: (v) => setState(() => ages = v),
      ),
      const Text(
        'Your identity and support role are independent. An empty selection includes everyone.',
        style: TextStyle(color: P.mist),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () {
          ref.read(filtersProvider.notifier).state = DiscoveryFilters(
            genders: genders,
            minAge: ages.start.round(),
            maxAge: ages.end.round(),
          );
          Navigator.pop(context);
        },
        child: const Text('Apply preferences'),
      ),
    ],
  );
}

class InvitationDrawer extends ConsumerStatefulWidget {
  const InvitationDrawer({super.key, required this.member});
  final Member member;
  @override
  ConsumerState<InvitationDrawer> createState() => _InvitationDrawerState();
}

class _InvitationDrawerState extends ConsumerState<InvitationDrawer> {
  late final Future<List<BillRequest>> bills;
  final key = DateTime.now().microsecondsSinceEpoch.toString();
  BillRequest? chosen;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    bills = ref.read(repositoryProvider).requests(ownerId: widget.member.id);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Eyebrow('A thoughtful hello'),
      const SizedBox(height: 16),
      Text(
        'Connect with ${widget.member.name}.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      const Text(
        'They decide whether to connect. A gesture is always optional.',
        style: TextStyle(color: P.mist),
      ),
      const SizedBox(height: 24),
      FutureBuilder<List<BillRequest>>(
        future: bills,
        builder: (context, s) => s.hasError
            ? const Text(
                'Requests could not load. You can still send a free invitation.',
              )
            : Column(
                children: (s.data ?? [])
                    .map(
                      (b) => ListTile(
                        leading: Icon(
                          chosen?.id == b.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        contentPadding: EdgeInsets.zero,
                        title: Text(b.title),
                        subtitle: Text(
                          '${b.amount} · ${b.status == 'demo' ? 'Sample request, not verified' : 'Reviewed request'}',
                        ),
                        onTap: () => setState(() => chosen = b),
                      ),
                    )
                    .toList(),
              ),
      ),
      if (chosen != null) ...[
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Simulation only', color: P.amber),
              const SizedBox(height: 12),
              Text('Illustrative contribution: ${chosen!.amount}'),
              const Text(
                'Fees: 0.00 in this simulation. Nothing will be charged. Acceptance simulates capture; decline or expiry simulates a void.',
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => setState(() => chosen = null),
          child: const Text('Continue without support'),
        ),
      ],
      const SizedBox(height: 24),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                try {
                  await ref
                      .read(repositoryProvider)
                      .invite(widget.member, chosen, key);
                  if (context.mounted) {
                    Navigator.pop(context, true);
                    notice(context, 'Your invitation is on its way.');
                  }
                } catch (_) {
                  if (mounted && context.mounted) {
                    setState(() => busy = false);
                    notice(context, 'Invitation could not be sent. Try again.');
                  }
                }
              },
        child: Text(
          busy
              ? 'Sending…'
              : chosen == null
              ? 'Send a free invitation'
              : 'Send simulated invitation',
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'No cards. No balance. No real transactions.',
        textAlign: TextAlign.center,
        style: TextStyle(color: P.mist, fontSize: 12),
      ),
    ],
  );
}
