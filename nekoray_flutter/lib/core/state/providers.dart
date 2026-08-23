import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../grpc/generated/libcore.pb.dart';
import '../grpc/grpc_client.dart';
import '../models/profile.dart';
import '../storage/local_store.dart';

/// All profiles loaded from disk.
final profileListProvider =
    StateNotifierProvider<ProfileListNotifier, AsyncValue<List<ProxyEntity>>>(
  (ref) => ProfileListNotifier(),
);

/// Paths of profile files that failed to parse, surfaced in the UI instead of
/// being swallowed.
final corruptProfilesProvider = StateProvider<List<String>>((ref) => const []);

const _maxSubscriptionBytes = 8 << 20;

class ProfileListNotifier
    extends StateNotifier<AsyncValue<List<ProxyEntity>>> {
  ProfileListNotifier() : super(const AsyncValue.loading());

  Future<void> load() async {
    try {
      final corrupt = <String>[];
      final raw = await LocalStore.loadProfiles(corrupt: corrupt);
      final profiles = raw.map(ProxyEntity.fromJson).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      state = AsyncValue.data(profiles);
      _corrupt = corrupt;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  List<String> _corrupt = const [];
  List<String> get corruptFiles => _corrupt;

  /// Creates a profile with a freshly allocated, collision-free id.
  Future<ProxyEntity> create({
    required String type,
    required Map<String, dynamic> bean,
    int gid = 0,
  }) async {
    final ids = await LocalStore.allocateProfileIds(1);
    final entity = ProxyEntity(id: ids.first, type: type, bean: bean, gid: gid);
    await LocalStore.saveProfile(entity.toJson());
    await load();
    return entity;
  }

  Future<void> update(ProxyEntity profile) async {
    await LocalStore.saveProfile(profile.toJson());
    await load();
  }

  Future<void> delete(int id) async {
    await LocalStore.deleteProfile(id);
    await load();
  }

  /// Imports share links from the clipboard.
  ///
  /// All nodes are parsed and written as one batch: a failure part-way through
  /// rolls back, rather than leaving half an import on disk.
  Future<String?> importFromClipboard(GrpcClient client) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return 'Clipboard is empty';
    return _importContent(client, text, groupName: null, url: null);
  }

  /// Downloads and imports a subscription URL.
  Future<String?> importSubscription(
    String url,
    String name,
    GrpcClient client,
  ) async {
    if (url.isEmpty || name.isEmpty) return 'URL and name cannot be empty';
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return 'Subscription URL must be http(s)';
    }

    final String content;
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.plain,
        // A subscription is text; refuse anything implausibly large.
        maxRedirects: 5,
      ));
      final response = await dio.getUri<String>(uri);
      content = response.data ?? '';
      if (content.length > _maxSubscriptionBytes) {
        return 'Subscription content exceeds 8 MiB';
      }
    } on DioException catch (e) {
      return 'Download failed: ${e.message ?? e.type.name}';
    } catch (e) {
      return 'Download failed: $e';
    }

    if (content.trim().isEmpty) return 'Subscription content is empty';
    return _importContent(client, content, groupName: name, url: url);
  }

  Future<String?> _importContent(
    GrpcClient client,
    String content, {
    required String? groupName,
    required String? url,
  }) async {
    final List<Map<String, dynamic>> parsed;
    final String parseError;
    try {
      final resp = await client.parseSubscription(
        ParseSubReq(content: content, format: 'auto'),
      );
      parseError = resp.error;
      parsed = resp.profiles
          .map((b) => jsonDecode(utf8.decode(b)))
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      return 'Core rejected the content: $e';
    }

    if (parsed.isEmpty) {
      return parseError.isNotEmpty ? parseError : 'No valid nodes found';
    }

    try {
      // Allocate every id up front from a single scan of the directory, so
      // nodes imported in the same millisecond cannot share an id.
      final ids = await LocalStore.allocateProfileIds(parsed.length);
      var gid = 0;
      ProfileGroup? group;

      if (groupName != null) {
        gid = (await LocalStore.allocateGroupIds(1)).first;
      }

      final entities = <ProxyEntity>[];
      for (var i = 0; i < parsed.length; i++) {
        final j = parsed[i];
        final entity = ProxyEntity.fromJson(j);
        entities.add(ProxyEntity(
          id: ids[i],
          gid: gid,
          type: entity.type,
          bean: entity.bean,
          latency: entity.latency,
        ));
      }

      await LocalStore.saveProfiles([for (final e in entities) e.toJson()]);

      if (groupName != null) {
        group = ProfileGroup(
          id: gid,
          name: groupName,
          url: url ?? '',
          subLastUpdate: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          order: ids,
        );
        try {
          await LocalStore.saveGroup(group.toJson());
        } catch (e) {
          // The group is the index for these profiles; without it they would
          // be orphaned, so undo the batch.
          for (final id in ids) {
            await LocalStore.deleteProfile(id);
          }
          return 'Failed to save group: $e';
        }
      }

      await load();
      if (parseError.isNotEmpty) {
        return 'Imported ${entities.length} node(s); some entries failed: $parseError';
      }
      return null;
    } catch (e) {
      return 'Import failed: $e';
    }
  }
}

/// All groups loaded from disk.
final groupListProvider =
    StateNotifierProvider<GroupListNotifier, AsyncValue<List<ProfileGroup>>>(
  (ref) => GroupListNotifier(),
);

class GroupListNotifier extends StateNotifier<AsyncValue<List<ProfileGroup>>> {
  GroupListNotifier() : super(const AsyncValue.loading());

  Future<void> load() async {
    try {
      final raw = await LocalStore.loadGroups();
      final groups = raw.map(ProfileGroup.fromJson).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      state = AsyncValue.data(groups);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<ProfileGroup> add({required String name, String url = ''}) async {
    final id = (await LocalStore.allocateGroupIds(1)).first;
    final group = ProfileGroup(id: id, name: name, url: url);
    await LocalStore.saveGroup(group.toJson());
    await load();
    return group;
  }

  Future<void> delete(int id) async {
    await LocalStore.deleteGroup(id);
    await load();
  }
}

/// Currently selected group filter (0 = all).
final selectedGroupProvider = StateProvider<int>((ref) => 0);

/// Search query for filtering profiles.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered profiles based on selected group + search query.
final filteredProfilesProvider = Provider<List<ProxyEntity>>((ref) {
  final profiles = ref.watch(profileListProvider).valueOrNull ?? const [];
  final groupId = ref.watch(selectedGroupProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  return profiles.where((p) {
    if (groupId != 0 && p.gid != groupId) return false;
    if (query.isEmpty) return true;
    final hay = '${p.name} ${p.type} ${p.address}'.toLowerCase();
    return hay.contains(query);
  }).toList();
});
