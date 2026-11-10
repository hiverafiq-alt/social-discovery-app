import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config.dart';
import '../../design/theme.dart';
import '../../domain/models.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});
  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController(),
      region = TextEditingController();
  DateTime? dob;
  bool consent = false, busy = false, login = false;
  int step = 0;
  RoleMode role = RoleMode.both;
  String gender = 'nonbinary';
  final country = TextEditingController();
  final selected = <String>{};
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    region.dispose();
    country.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted && context.mounted) {
        notice(
          context,
          'We could not complete this step. Check your details and try again.',
        );
      }
    }
    if (mounted && context.mounted) setState(() => busy = false);
  }

  Future<void> authenticate() async {
    if (!AppConfig.configured && !AppConfig.demo) {
      notice(context, 'Service configuration is required before signing in.');
      return;
    }
    if (AppConfig.demo) {
      setState(() => step = 2);
      return;
    }
    final auth = Supabase.instance.client.auth;
    await run(() async {
      if (login) {
        await auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
        final account = await Supabase.instance.client
            .from('accounts')
            .select('id')
            .maybeSingle();
        if (mounted && context.mounted) {
          if (account == null) {
            setState(() => step = 2);
          } else {
            context.go('/discover');
          }
        }
      } else {
        final response = await auth.signUp(
          email: email.text.trim(),
          password: password.text,
        );
        if (!mounted) return;
        if (response.session == null) {
          notice(
            context,
            'Check your email to verify your account, then sign in.',
          );
          setState(() => login = true);
        } else {
          setState(() => step = 2);
        }
      }
    });
  }

  Future<void> finish() async {
    if (dob == null ||
        !IntroPolicy.adult(dob!, DateTime.now()) ||
        !consent ||
        name.text.trim().isEmpty ||
        region.text.trim().isEmpty) {
      notice(
        context,
        'Add your name, region, adult date of birth, and community agreement.',
      );
      return;
    }
    await run(() async {
      if (!AppConfig.demo) {
        await Supabase.instance.client.rpc(
          'complete_onboarding',
          params: {
            'p_name': name.text.trim(),
            'p_dob': dob!.toIso8601String().substring(0, 10),
            'p_region': region.text.trim(),
            'p_country': country.text.trim().toUpperCase(),
            'p_role': role.name,
            'p_gender': gender,
            'p_genders': selected.toList(),
            'p_terms': 'draft-2026-10-28',
          },
        );
      }
      if (mounted && context.mounted) context.go('/discover');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                child: step == 0
                    ? intro(context)
                    : step == 1
                    ? authForm(context)
                    : setup(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget intro(BuildContext context) => Column(
    key: const ValueKey('intro'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Monogram(size: 60), Eyebrow('A little spark')],
      ),
      const SizedBox(height: 68),
      Text(
        'A hello worth\nremembering.',
        style: Theme.of(context).textTheme.displayLarge,
      ),
      const SizedBox(height: 28),
      const Text(
        'See the person.\nFeel the connection.',
        style: TextStyle(fontSize: 23, height: 1.45, color: P.mist),
      ),
      const SizedBox(height: 44),
      const Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow('Real presence. Mutual choice.'),
            SizedBox(height: 14),
            Text(
              'Short introductions. Thoughtful connections. Always on your terms.',
            ),
            SizedBox(height: 16),
            Text(
              '18+ only. Respect, consent and privacy come first.',
              style: TextStyle(color: P.mist),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => setState(() => step = 1),
          child: const Text('Find your spark'),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        AppConfig.demo
            ? 'STUDIO PREVIEW  ·  Fictional members  ·  No payments'
            : 'Private by design. Support is never a promise of attention.',
        style: const TextStyle(color: P.mist, fontSize: 12),
      ),
    ],
  );
  Widget authForm(BuildContext context) => Column(
    key: const ValueKey('auth'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Monogram(),
      const SizedBox(height: 40),
      Text(
        login ? 'Welcome back.' : 'Your first chapter.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 12),
      const Text(
        'An introduction starts with you.',
        style: TextStyle(color: P.mist),
      ),
      const SizedBox(height: 32),
      if (!AppConfig.demo) ...[
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email address'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        const SizedBox(height: 20),
      ],
      FilledButton(
        onPressed: busy ? null : authenticate,
        child: Text(
          busy
              ? 'One moment…'
              : AppConfig.demo
              ? 'Enter studio preview'
              : login
              ? 'Sign in'
              : 'Create account',
        ),
      ),
      if (!AppConfig.demo) ...[
        TextButton(
          onPressed: () => setState(() => login = !login),
          child: Text(
            login ? 'Create an account' : 'Already a member? Sign in',
          ),
        ),
        TextButton(
          onPressed: !AppConfig.configured
              ? null
              : () => run(() async {
                  await Supabase.instance.client.auth.resetPasswordForEmail(
                    email.text.trim(),
                  );
                  if (mounted && context.mounted) {
                    notice(
                      context,
                      'Check your email for recovery instructions.',
                    );
                  }
                }),
          child: const Text('Forgot password?'),
        ),
      ],
      const SizedBox(height: 16),
      const Text(
        'Service access is limited to approved launch regions. No money can be sent in this build.',
        style: TextStyle(color: P.mist),
      ),
    ],
  );
  Widget setup(BuildContext context) => Column(
    key: const ValueKey('setup'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Eyebrow('01 / Your world'),
      const SizedBox(height: 16),
      Text(
        'Come as you are.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 28),
      TextField(
        controller: name,
        maxLength: 40,
        decoration: const InputDecoration(labelText: 'First name'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: region,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'City or broad region'),
      ),
      if (!AppConfig.demo) ...[
        const SizedBox(height: 12),
        TextField(
          controller: country,
          maxLength: 2,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Approved country code, for example FR',
          ),
        ),
      ],
      OutlinedButton(
        onPressed: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime(2000),
            firstDate: DateTime(1906),
            lastDate: DateTime.now(),
          );
          if (date != null && mounted) setState(() => dob = date);
        },
        child: Text(
          dob == null
              ? 'Date of birth, private'
              : '${dob!.day} / ${dob!.month} / ${dob!.year}',
        ),
      ),
      const SizedBox(height: 24),
      const Text('How would you like to take part?'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: RoleMode.values
            .map(
              (r) => ChoiceChip(
                label: Text(switch (r) {
                  RoleMode.support => 'Support',
                  RoleMode.share => 'Share requests',
                  RoleMode.both => 'Both',
                }),
                selected: role == r,
                onSelected: (_) => setState(() => role = r),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 24),
      const Text('Your gender, never a payment role'),
      DropdownButton<String>(
        isExpanded: true,
        value: gender,
        items: const [
          DropdownMenuItem(value: 'woman', child: Text('Woman')),
          DropdownMenuItem(value: 'man', child: Text('Man')),
          DropdownMenuItem(value: 'nonbinary', child: Text('Nonbinary')),
          DropdownMenuItem(
            value: 'self-described',
            child: Text('Self described'),
          ),
        ],
        onChanged: (v) => setState(() => gender = v!),
      ),
      const SizedBox(height: 16),
      const Text('Who would you like to discover?'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: ['woman', 'man', 'nonbinary', 'self-described']
            .map(
              (g) => FilterChip(
                label: Text(g),
                selected: selected.contains(g),
                onSelected: (v) => setState(() {
                  v ? selected.add(g) : selected.remove(g);
                }),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 20),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: consent,
        title: const Text(
          'I am 18 or older and agree to respectful, consensual connections.',
        ),
        subtitle: const Text(
          'No harassment, coercion, sexual services or fraudulent requests. Draft terms apply to this closed test.',
        ),
        onChanged: (v) => setState(() => consent = v!),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: busy ? null : finish,
        child: const Text('Continue to Social Discovery'),
      ),
      const SizedBox(height: 12),
      const Text(
        'Record your introduction from You before publishing. New profiles remain under review.',
        style: TextStyle(color: P.mist),
      ),
    ],
  );
}
