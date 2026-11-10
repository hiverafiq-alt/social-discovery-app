import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/providers.dart';
import '../../core/config.dart';
import '../../design/theme.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Your world')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Eyebrow('Always on your terms'),
            const SizedBox(height: 16),
            Text(
              'A little more you.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 28),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Monogram(size: 64),
                  const SizedBox(height: 20),
                  Text(
                    'Your first impression, alive.',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Record 5 to 10 seconds, directly in Social Discovery. Your introduction is reviewed before it becomes discoverable.',
                    style: TextStyle(color: P.mist),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => context.push('/record'),
                    child: const Text('Open camera studio'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              title: const Text('Supporting moments'),
              subtitle: const Text('Photos and secondary videos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/gallery'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Edit your story'),
              subtitle: const Text('Bio, pronouns and interests'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => sheet(context, const EditProfile()),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data Saver'),
              subtitle: const Text('Play introductions only when you tap'),
              value: ref.watch(dataSaverProvider),
              onChanged: (v) => ref.read(dataSaverProvider.notifier).state = v,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Haptic feedback'),
              value: ref.watch(hapticsProvider),
              onChanged: (v) => ref.read(hapticsProvider.notifier).state = v,
            ),
            const Divider(height: 36),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Safety and community'),
              leading: const Icon(Icons.shield_outlined),
              onTap: () => sheet(
                context,
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow('Your safety comes first'),
                    SizedBox(height: 20),
                    Text(
                      'Respect is the starting point.',
                      style: TextStyle(fontSize: 28),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Social Discovery is for adults. No coercion, exploitation, sexual services, harassment, impersonation or forged bills. You can decline, report, block or end a connection at any time.',
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Reviews reduce risk; they do not guarantee authenticity. Never share private financial details or send money outside the app.',
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Closed test: moderation staffing, support contact, privacy policy and jurisdiction approval must be completed before public release.',
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Privacy'),
              leading: const Icon(Icons.lock_outline),
              onTap: () => sheet(
                context,
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow('Less data. More trust.'),
                    SizedBox(height: 20),
                    Text(
                      'Your birthday and original bills are private. Profiles display only your age and broad region. No precise location is collected.',
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Gender and discovery preferences are used for discovery, never to assign a financial role. Reports and restricted evidence are accessible only for authorized safety review.',
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Public privacy terms, export workflow and retention schedules are release gates. This closed test is not open for public enrollment.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow('No real money', color: P.amber),
                  SizedBox(height: 12),
                  Text(
                    'Every contribution status is simulated. No wallet, card collection or settlement is enabled.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () async {
                if (!AppConfig.demo) {
                  await Supabase.instance.client.auth.signOut();
                }
                if (context.mounted) context.go('/');
              },
              child: const Text('Sign out'),
            ),
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete your account?'),
                    content: const Text(
                      'Your profile will be hidden immediately. A deletion job removes evidence and media. This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep account'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete account'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await ref.read(repositoryProvider).deleteAccount();
                    if (context.mounted) context.go('/');
                  } catch (_) {
                    if (context.mounted) {
                      notice(
                        context,
                        'Deletion request could not complete. Try again.',
                      );
                    }
                  }
                }
              },
              child: const Text('Delete account'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Social Discovery 0.1.0 · Closed development build',
              style: TextStyle(color: P.mist, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class EditProfile extends ConsumerStatefulWidget {
  const EditProfile({super.key});
  @override
  ConsumerState<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends ConsumerState<EditProfile> {
  final bio = TextEditingController(),
      pronouns = TextEditingController(),
      interests = TextEditingController();
  bool busy = false;
  String role = 'both';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final profile = await ref.read(repositoryProvider).ownProfile();
      if (!mounted) return;
      bio.text = profile['bio'] ?? '';
      pronouns.text = profile['pronouns'] ?? '';
      interests.text = List<String>.from(profile['interests'] ?? []).join(', ');
      role = profile['role_mode'] ?? 'both';
    } catch (_) {
      if (mounted) {
        notice(
          context,
          'Your story could not load. Reopen this form to retry.',
        );
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    bio.dispose();
    pronouns.dispose();
    interests.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Eyebrow('Your story'),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        children: ['support', 'share', 'both']
            .map(
              (r) => ChoiceChip(
                label: Text(r == 'share' ? 'Share requests' : r),
                selected: role == r,
                onSelected: (_) => setState(() => role = r),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: bio,
        maxLength: 240,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'A little about you'),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: pronouns,
        maxLength: 40,
        decoration: const InputDecoration(labelText: 'Pronouns, optional'),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: interests,
        maxLength: 160,
        decoration: const InputDecoration(
          labelText: 'Interests, separated by commas',
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                try {
                  await ref.read(repositoryProvider).saveProfile({
                    'role_mode': role,
                    'bio': bio.text.trim(),
                    'pronouns': pronouns.text.trim(),
                    'interests': interests.text
                        .split(',')
                        .map((i) => i.trim())
                        .where((i) => i.isNotEmpty)
                        .take(8)
                        .toList(),
                  });
                  if (context.mounted) Navigator.pop(context);
                } catch (_) {
                  if (mounted && context.mounted) {
                    setState(() => busy = false);
                    notice(context, 'Your changes could not be saved.');
                  }
                }
              },
        child: const Text('Save for review'),
      ),
    ],
  );
}
