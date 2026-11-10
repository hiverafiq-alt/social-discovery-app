import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';
import '../data/repository.dart';
import '../data/demo_repository.dart';
import '../data/supabase_repository.dart';
import '../domain/models.dart';

final repositoryProvider = Provider<SocialDiscoveryRepository>(
  (ref) => AppConfig.demo
      ? DemoRepository()
      : SupabaseSocialDiscoveryRepository(Supabase.instance.client),
);
final refreshProvider = StreamProvider<void>(
  (ref) => ref.watch(repositoryProvider).changes(),
);
final filtersProvider = StateProvider<DiscoveryFilters>(
  (ref) => const DiscoveryFilters(),
);

class DiscoveryFilters {
  const DiscoveryFilters({
    this.genders = const {},
    this.minAge = 18,
    this.maxAge = 65,
  });
  final Set<String> genders;
  final int minAge, maxAge;
}

final discoveryProvider = FutureProvider<List<Member>>((ref) {
  final f = ref.watch(filtersProvider);
  return ref
      .watch(repositoryProvider)
      .discover(genders: f.genders, minAge: f.minAge, maxAge: f.maxAge);
});
final invitationsProvider = FutureProvider<List<Invitation>>((ref) {
  ref.watch(refreshProvider);
  return ref.watch(repositoryProvider).invitations();
});
final billsProvider = FutureProvider<List<BillRequest>>((ref) {
  ref.watch(refreshProvider);
  return ref.watch(repositoryProvider).requests();
});
final messagesProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, id) {
      ref.watch(refreshProvider);
      return ref.watch(repositoryProvider).messages(id);
    });
final dataSaverProvider = StateProvider<bool>((ref) => false);
final hapticsProvider = StateProvider<bool>((ref) => true);
