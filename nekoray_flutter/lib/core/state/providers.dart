// Riverpod providers for profile/group data, binding LocalStore to the UI.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../storage/local_store.dart';

/// All profiles loaded from disk.
final profileListProvider =
    StateNotifierProvider<ProfileListNotifier, AsyncValue<List<ProxyEntity>>>(
  (ref) => ProfileListNotifier(),
);

class ProfileListNotifier
    extends StateNotifier<AsyncValue<List<ProxyEntity>>> {
  ProfileListNotifier() : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final raw = await LocalStore.loadProfiles();
      final profiles = raw.map(ProxyEntity.fromJson).toList();
      profiles.sort((a, b) => a.id.compareTo(b.id));
      state = AsyncValue.data(profiles);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(ProxyEntity profile) async {
    await LocalStore.saveProfile(profile.toJson());
    await load();
  }

  Future<void> update(ProxyEntity profile) async {
    await LocalStore.saveProfile(profile.toJson());
    await load();
  }

  Future<void> delete(int id) async {
    await LocalStore.deleteProfile(id);
    await load();
  }
}

/// All groups loaded from disk.
final groupListProvider =
    StateNotifierProvider<GroupListNotifier, AsyncValue<List<ProfileGroup>>>(
  (ref) => GroupListNotifier(),
);

class GroupListNotifier
    extends StateNotifier<AsyncValue<List<ProfileGroup>>> {
  GroupListNotifier() : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final raw = await LocalStore.loadGroups();
      final groups = raw.map(ProfileGroup.fromJson).toList();
      groups.sort((a, b) => a.id.compareTo(b.id));
      state = AsyncValue.data(groups);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(ProfileGroup group) async {
    await LocalStore.saveGroup(group.toJson());
    await load();
  }
}

/// Currently selected group filter (0 = all).
final selectedGroupProvider = StateProvider<int>((ref) => 0);

/// Search query for filtering profiles.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered profiles based on selected group + search query.
final filteredProfilesProvider = Provider<List<ProxyEntity>>((ref) {
  final profiles = ref.watch(profileListProvider).valueOrNull ?? [];
  final groupId = ref.watch(selectedGroupProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();

  return profiles.where((p) {
    // group filter
    if (groupId != 0 && p.gid != groupId) return false;
    // search filter
    if (query.isNotEmpty) {
      final hay = '${p.name} ${p.type} ${p.address}'.toLowerCase();
      if (!hay.contains(query)) return false;
    }
    return true;
  }).toList();
});
