// Routing page — Karing & armwall inspired rule management & rule-set engine.
// Each rule and rule-set can have its outbound action (Direct / Proxy / Block)
// directly selected, toggled, and customized.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/grpc/generated/libcore.pb.dart';
import '../../../core/grpc/grpc_provider.dart';
import '../../../core/i18n.dart';
import '../../../core/models/profile.dart';
import '../../../core/storage/local_store.dart';

/// Routing config (loaded from routing_default.json).
final routingConfigProvider =
    StateNotifierProvider<RoutingConfigNotifier, AsyncValue<RoutingConfig>>(
  (ref) => RoutingConfigNotifier(),
);

class RoutingConfig {
  List<RoutingRule> rules;
  String finalOutbound;

  String remoteDns;
  String directDns;
  String remoteDnsStrategy;
  String directDnsStrategy;
  bool dnsRouting;
  bool fakeIp;
  String dnsFinalOut;
  String domainStrategy;
  String outboundDomainStrategy;
  int sniffingMode;

  RoutingConfig({
    List<RoutingRule>? rules,
    this.finalOutbound = 'proxy',
    this.remoteDns = 'https://dns.google/dns-query',
    this.directDns = 'https://223.5.5.5/dns-query',
    this.remoteDnsStrategy = 'ipv4_only',
    this.directDnsStrategy = 'ipv4_only',
    this.dnsRouting = true,
    this.fakeIp = false,
    this.dnsFinalOut = 'direct',
    this.domainStrategy = 'ipv4_only',
    this.outboundDomainStrategy = 'ipv4_only',
    this.sniffingMode = 2,
  }) : rules = rules ?? <RoutingRule>[];

  factory RoutingConfig.fromJson(Map<String, dynamic> j) {
    return RoutingConfig(
      rules: (j['rules'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(RoutingRule.fromJson)
              .toList() ??
          <RoutingRule>[],
      finalOutbound: (j['finalOutbound'] as String?) ?? 'proxy',
      remoteDns: (j['remote_dns'] as String?) ?? 'https://dns.google/dns-query',
      directDns: (j['direct_dns'] as String?) ?? 'https://223.5.5.5/dns-query',
      remoteDnsStrategy: (j['remote_dns_strategy'] as String?) ?? 'ipv4_only',
      directDnsStrategy: (j['direct_dns_strategy'] as String?) ?? 'ipv4_only',
      dnsRouting: j['dns_routing'] != false,
      fakeIp: j['fake_ip'] == true,
      dnsFinalOut: (j['dns_final_out'] as String?) ?? 'direct',
      domainStrategy: (j['domain_strategy'] as String?) ?? 'ipv4_only',
      outboundDomainStrategy:
          (j['outbound_domain_strategy'] as String?) ?? 'ipv4_only',
      sniffingMode: (j['sniffing_mode'] as num?)?.toInt() ?? 2,
    );
  }

  Map<String, dynamic> toJson() => {
        'rules': rules.map((r) => r.toJson()).toList(),
        'finalOutbound': finalOutbound,
        'remote_dns': remoteDns,
        'direct_dns': directDns,
        'remote_dns_strategy': remoteDnsStrategy,
        'direct_dns_strategy': directDnsStrategy,
        'dns_routing': dnsRouting,
        'fake_ip': fakeIp,
        'dns_final_out': dnsFinalOut,
        'domain_strategy': domainStrategy,
        'outbound_domain_strategy': outboundDomainStrategy,
        'sniffing_mode': sniffingMode,
      };

  RoutingConfig copyWith({
    List<RoutingRule>? rules,
    String? finalOutbound,
    String? remoteDns,
    String? directDns,
    String? remoteDnsStrategy,
    String? directDnsStrategy,
    bool? fakeIp,
    bool? dnsRouting,
  }) =>
      RoutingConfig(
        rules: rules ?? this.rules,
        finalOutbound: finalOutbound ?? this.finalOutbound,
        remoteDns: remoteDns ?? this.remoteDns,
        directDns: directDns ?? this.directDns,
        remoteDnsStrategy: remoteDnsStrategy ?? this.remoteDnsStrategy,
        directDnsStrategy: directDnsStrategy ?? this.directDnsStrategy,
        dnsRouting: dnsRouting ?? this.dnsRouting,
        fakeIp: fakeIp ?? this.fakeIp,
        dnsFinalOut: dnsFinalOut,
        domainStrategy: domainStrategy,
        outboundDomainStrategy: outboundDomainStrategy,
        sniffingMode: sniffingMode,
      );
}

/// Standard Karing-style default presets
RoutingConfig getPresetBypassMainland() {
  return RoutingConfig(
    finalOutbound: 'proxy',
    rules: [
      RoutingRule(
        name: '全网广告与隐私追踪过滤',
        domains: ['geosite:category-ads-all'],
        outbound: 'block',
      ),
      RoutingRule(
        name: '私有局域网与回环地址',
        domains: ['geosite:private'],
        ip: ['geoip:private'],
        outbound: 'direct',
      ),
      RoutingRule(
        name: 'Apple 苹果服务',
        domains: ['geosite:apple'],
        outbound: 'direct',
      ),
      RoutingRule(
        name: '中国大陆常用域名与IP',
        domains: ['geosite:cn'],
        ip: ['geoip:cn'],
        outbound: 'direct',
      ),
      RoutingRule(
        name: 'AI 智能服务 (OpenAI/Claude)',
        domains: ['geosite:openai', 'geosite:anthropic'],
        outbound: 'proxy',
      ),
    ],
  );
}

RoutingConfig getPresetBypassGFW() {
  return RoutingConfig(
    finalOutbound: 'direct',
    rules: [
      RoutingRule(
        name: '全网广告与隐私追踪过滤',
        domains: ['geosite:category-ads-all'],
        outbound: 'block',
      ),
      RoutingRule(
        name: '私有局域网与回环地址',
        domains: ['geosite:private'],
        ip: ['geoip:private'],
        outbound: 'direct',
      ),
      RoutingRule(
        name: 'GFW 代理域名列表',
        domains: ['geosite:gfw'],
        outbound: 'proxy',
      ),
    ],
  );
}

RoutingConfig getPresetGlobalProxy() {
  return RoutingConfig(
    finalOutbound: 'proxy',
    rules: [
      RoutingRule(
        name: '全网广告与隐私追踪过滤',
        domains: ['geosite:category-ads-all'],
        outbound: 'block',
      ),
      RoutingRule(
        name: '私有局域网与回环地址',
        domains: ['geosite:private'],
        ip: ['geoip:private'],
        outbound: 'direct',
      ),
    ],
  );
}

RoutingConfig getPresetGlobalDirect() {
  return RoutingConfig(
    finalOutbound: 'direct',
    rules: [
      RoutingRule(
        name: '全网广告与隐私追踪过滤',
        domains: ['geosite:category-ads-all'],
        outbound: 'block',
      ),
    ],
  );
}

String _detectPresetName(RoutingConfig config) {
  if (config.finalOutbound == 'proxy' &&
      config.rules.any((r) => r.domains.contains('geosite:cn'))) {
    return 'bypass_cn';
  }
  if (config.finalOutbound == 'direct' &&
      config.rules.any((r) => r.domains.contains('geosite:gfw'))) {
    return 'bypass_gfw';
  }
  if (config.finalOutbound == 'proxy' && config.rules.length <= 2) {
    return 'global_proxy';
  }
  if (config.finalOutbound == 'direct' && config.rules.length <= 2) {
    return 'global_direct';
  }
  return 'custom';
}

class RoutingConfigNotifier extends StateNotifier<AsyncValue<RoutingConfig>> {
  RoutingConfigNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final raw = await LocalStore.loadRouting('default');
      if (raw == null) {
        final config = getPresetBypassMainland();
        await LocalStore.saveRouting('default', config.toJson());
        state = AsyncValue.data(config);
      } else {
        state = AsyncValue.data(RoutingConfig.fromJson(raw));
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addRule(RoutingRule rule) async {
    final c = state.valueOrNull;
    if (c == null) return;
    final next = c.copyWith(rules: [...c.rules, rule]);
    await LocalStore.saveRouting('default', next.toJson());
    state = AsyncValue.data(next);
  }

  Future<void> updateRule(int index, RoutingRule rule) async {
    final c = state.valueOrNull;
    if (c == null) return;
    final rules = List<RoutingRule>.from(c.rules);
    if (index >= 0 && index < rules.length) {
      rules[index] = rule;
      final next = c.copyWith(rules: rules);
      await LocalStore.saveRouting('default', next.toJson());
      state = AsyncValue.data(next);
    }
  }

  Future<void> updateRuleOutbound(int index, String outbound) async {
    final c = state.valueOrNull;
    if (c == null) return;
    final rules = List<RoutingRule>.from(c.rules);
    if (index >= 0 && index < rules.length) {
      rules[index] = rules[index].copyWith(outbound: outbound);
      final next = c.copyWith(rules: rules);
      await LocalStore.saveRouting('default', next.toJson());
      state = AsyncValue.data(next);
    }
  }

  Future<void> toggleRuleEnabled(int index, bool enabled) async {
    final c = state.valueOrNull;
    if (c == null) return;
    final rules = List<RoutingRule>.from(c.rules);
    if (index >= 0 && index < rules.length) {
      rules[index] = rules[index].copyWith(enabled: enabled);
      final next = c.copyWith(rules: rules);
      await LocalStore.saveRouting('default', next.toJson());
      state = AsyncValue.data(next);
    }
  }

  Future<void> removeRule(int index) async {
    final c = state.valueOrNull;
    if (c == null) return;
    final rules = List<RoutingRule>.from(c.rules);
    if (index >= 0 && index < rules.length) {
      rules.removeAt(index);
      final next = c.copyWith(rules: rules);
      await LocalStore.saveRouting('default', next.toJson());
      state = AsyncValue.data(next);
    }
  }

  Future<void> setRuleForTag({
    required String tag,
    required String name,
    required String outbound, // 'direct' | 'proxy' | 'block' | 'disable'
  }) async {
    final c = state.valueOrNull;
    if (c == null) return;
    final rules = List<RoutingRule>.from(c.rules);

    final isDomain = tag.startsWith('geosite-') || tag.startsWith('geosite:');
    final isIP = tag.startsWith('geoip-') || tag.startsWith('geoip:');
    final cleanTag = tag.replaceFirst('geosite-', 'geosite:').replaceFirst('geoip-', 'geoip:');

    // Find if rule already exists
    final existingIdx = rules.indexWhere((r) =>
        (isDomain && r.domains.contains(cleanTag)) || (isIP && r.ip.contains(cleanTag)));

    if (outbound == 'disable') {
      if (existingIdx >= 0) {
        rules.removeAt(existingIdx);
      }
    } else {
      if (existingIdx >= 0) {
        rules[existingIdx] = rules[existingIdx].copyWith(
          outbound: outbound,
          enabled: true,
        );
      } else {
        rules.add(RoutingRule(
          name: name,
          domains: isDomain ? [cleanTag] : [],
          ip: isIP ? [cleanTag] : [],
          outbound: outbound,
          enabled: true,
        ));
      }
    }

    final next = c.copyWith(rules: rules);
    await LocalStore.saveRouting('default', next.toJson());
    state = AsyncValue.data(next);
  }

  Future<void> applyPreset(RoutingConfig preset) async {
    final current = state.valueOrNull;
    final next = preset.copyWith(
      remoteDns: current?.remoteDns,
      directDns: current?.directDns,
    );
    await LocalStore.saveRouting('default', next.toJson());
    state = AsyncValue.data(next);
  }

  Future<void> updateFinalOutbound(String outbound) async {
    final c = state.valueOrNull;
    if (c == null) return;
    final next = c.copyWith(finalOutbound: outbound);
    await LocalStore.saveRouting('default', next.toJson());
    state = AsyncValue.data(next);
  }

  Future<void> updateDns({
    String? remoteDns,
    String? directDns,
    bool? dnsRouting,
    bool? fakeIp,
  }) async {
    final c = state.valueOrNull;
    if (c == null) return;
    final next = c.copyWith(
      remoteDns: remoteDns,
      directDns: directDns,
      dnsRouting: dnsRouting,
      fakeIp: fakeIp,
    );
    await LocalStore.saveRouting('default', next.toJson());
    state = AsyncValue.data(next);
  }

  Future<void> updateDnsStrategy({String? remote, String? direct}) async {
    final c = state.valueOrNull;
    if (c == null) return;
    final next = c.copyWith(
      remoteDnsStrategy: remote,
      directDnsStrategy: direct,
    );
    await LocalStore.saveRouting('default', next.toJson());
    state = AsyncValue.data(next);
  }
}

class RuleSetItem {
  final String tag;
  final String description;
  final String url;
  final IconData icon;
  bool isUpdating;
  String? lastUpdated;
  String? error;

  RuleSetItem({
    required this.tag,
    required this.description,
    required this.url,
    required this.icon,
    this.isUpdating = false,
    this.lastUpdated,
    this.error,
  });
}

class RoutingPage extends ConsumerStatefulWidget {
  const RoutingPage({super.key});

  @override
  ConsumerState<RoutingPage> createState() => _RoutingPageState();
}

class _RoutingPageState extends ConsumerState<RoutingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<RuleSetItem> _ruleSets = [
    RuleSetItem(
      tag: 'geosite-cn',
      description: '中国大陆常用域名 (China mainland domains)',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs',
      icon: Icons.language,
    ),
    RuleSetItem(
      tag: 'geoip-cn',
      description: '中国大陆 IP 地址段 (China mainland IP CIDRs)',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs',
      icon: Icons.public,
    ),
    RuleSetItem(
      tag: 'geosite-apple',
      description: 'Apple 苹果服务 (App Store / iCloud / Apple ID)',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-apple.srs',
      icon: Icons.apple,
    ),
    RuleSetItem(
      tag: 'geosite-google',
      description: 'Google 全球服务 (Search / YouTube / Gmail / Play)',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-google.srs',
      icon: Icons.travel_explore,
    ),
    RuleSetItem(
      tag: 'geosite-openai',
      description: 'OpenAI / ChatGPT / Sora 智能服务',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-openai.srs',
      icon: Icons.smart_toy_outlined,
    ),
    RuleSetItem(
      tag: 'geosite-anthropic',
      description: 'Claude / Anthropic AI 模型服务',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-anthropic.srs',
      icon: Icons.psychology_outlined,
    ),
    RuleSetItem(
      tag: 'geosite-category-ads-all',
      description: '全网广告与隐私追踪过滤 (AdBlock & Trackers)',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs',
      icon: Icons.shield_outlined,
    ),
    RuleSetItem(
      tag: 'geosite-telegram',
      description: 'Telegram 社交网络 (Telegram CDN & Endpoints)',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-telegram.srs',
      icon: Icons.send_outlined,
    ),
    RuleSetItem(
      tag: 'geosite-github',
      description: 'GitHub 常用域名与静态资产 (GitHub Services)',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-github.srs',
      icon: Icons.code,
    ),
    RuleSetItem(
      tag: 'geosite-netflix',
      description: 'Netflix 奈飞全球流媒体服务',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-netflix.srs',
      icon: Icons.movie_outlined,
    ),
    RuleSetItem(
      tag: 'geoip-private',
      description: '私有局域网与回环地址 (Private LAN & Loopback)',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-private.srs',
      icon: Icons.home_outlined,
    ),
  ];

  bool _isUpdatingAll = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateRuleSet(RuleSetItem item) async {
    setState(() {
      item.isUpdating = true;
      item.error = null;
    });

    try {
      final client = ref.read(grpcClientProvider);
      final resp = await client.updateRuleSet(UpdateRuleSetReq(
        tag: item.tag,
        format: 'binary',
        url: item.url,
        download: true,
      ));
      if (resp.error.isNotEmpty) {
        throw Exception(resp.error);
      }
      if (mounted) {
        setState(() {
          item.isUpdating = false;
          item.lastUpdated = DateTime.now().toString().substring(0, 19);
          item.error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          item.isUpdating = false;
          item.error = 'Update failed: $e';
        });
      }
    }
  }

  Future<void> _updateAllRuleSets() async {
    if (_isUpdatingAll) return;
    setState(() => _isUpdatingAll = true);
    try {
      await Future.wait(_ruleSets.map(_updateRuleSet));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t('updateSuccess'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingAll = false);
      }
    }
  }

  void _openEditRuleDialog(BuildContext context, WidgetRef ref,
      {RoutingRule? existingRule, int? index}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _EditRuleDialog(
        existingRule: existingRule,
        onSave: (rule) {
          if (index != null && index >= 0) {
            ref.read(routingConfigProvider.notifier).updateRule(index, rule);
          } else {
            ref.read(routingConfigProvider.notifier).addRule(rule);
          }
        },
      ),
    );
  }

  String _getRuleStatusForTag(RoutingConfig config, String tag) {
    final cleanTag =
        tag.replaceFirst('geosite-', 'geosite:').replaceFirst('geoip-', 'geoip:');
    final match = config.rules.firstWhere(
      (r) =>
          r.enabled &&
          (r.domains.contains(cleanTag) || r.ip.contains(cleanTag)),
      orElse: () => RoutingRule(outbound: 'disabled', enabled: false),
    );
    if (!match.enabled || match.outbound == 'disabled') return 'disable';
    return match.outbound;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Consumer(
      builder: (context, ref, _) {
        final configAsync = ref.watch(routingConfigProvider);
        return Scaffold(
          appBar: AppBar(
            title: Text(I18n.t('routing')),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: const Icon(Icons.alt_route, size: 18),
                  text: I18n.t('rules'),
                ),
                Tab(
                  icon: const Icon(Icons.layers_outlined, size: 18),
                  text: I18n.t('ruleSets'),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: I18n.t('addCustomRule'),
                onPressed: () => _openEditRuleDialog(context, ref),
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: 路由规则 (Routing Rules - Karing style)
              configAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (c) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Top Preset & Default Outbound Card
                    Card(
                      elevation: isDark ? 0 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.tune, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  I18n.t('rulePresets'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _detectPresetName(c),
                              decoration: InputDecoration(
                                labelText: I18n.t('preset'),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'bypass_cn',
                                    child: Text('Bypass Mainland China (绕过国内)')),
                                DropdownMenuItem(
                                    value: 'bypass_gfw',
                                    child: Text('Bypass GFW (绕过GFW)')),
                                DropdownMenuItem(
                                    value: 'global_proxy',
                                    child: Text('Global Proxy (全局代理)')),
                                DropdownMenuItem(
                                    value: 'global_direct',
                                    child: Text('Global Direct (全局直连)')),
                                DropdownMenuItem(
                                    value: 'custom',
                                    child: Text('Custom (自定义规则)')),
                              ],
                              onChanged: (val) {
                                if (val == null) return;
                                final notifier =
                                    ref.read(routingConfigProvider.notifier);
                                switch (val) {
                                  case 'bypass_cn':
                                    notifier.applyPreset(getPresetBypassMainland());
                                    break;
                                  case 'bypass_gfw':
                                    notifier.applyPreset(getPresetBypassGFW());
                                    break;
                                  case 'global_proxy':
                                    notifier.applyPreset(getPresetGlobalProxy());
                                    break;
                                  case 'global_direct':
                                    notifier.applyPreset(getPresetGlobalDirect());
                                    break;
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Text(
                                  I18n.t('finalOutbound') + ':',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _buildOutboundChip(
                                  label: I18n.t('proxy'),
                                  isSelected: c.finalOutbound == 'proxy',
                                  color: scheme.primary,
                                  onTap: () => ref
                                      .read(routingConfigProvider.notifier)
                                      .updateFinalOutbound('proxy'),
                                ),
                                const SizedBox(width: 8),
                                _buildOutboundChip(
                                  label: I18n.t('direct'),
                                  isSelected: c.finalOutbound == 'direct',
                                  color: Colors.green.shade700,
                                  onTap: () => ref
                                      .read(routingConfigProvider.notifier)
                                      .updateFinalOutbound('direct'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Rules List Title
                    Row(
                      children: [
                        Text(
                          '${I18n.t("rules")} (${c.rules.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(I18n.t('addCustomRule')),
                          onPressed: () => _openEditRuleDialog(context, ref),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (c.rules.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            I18n.t('noRoutingRules'),
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    else
                      ...List.generate(c.rules.length, (i) {
                        final r = c.rules[i];
                        final ruleTitle = r.name.isNotEmpty
                            ? r.name
                            : (r.domains.isNotEmpty
                                ? r.domains.join(', ')
                                : (r.ip.isNotEmpty
                                    ? r.ip.join(', ')
                                    : 'Rule #${i + 1}'));

                        final ruleSubtitle = [
                          if (r.domains.isNotEmpty && r.name.isNotEmpty)
                            r.domains.join(', '),
                          if (r.ip.isNotEmpty && r.name.isNotEmpty)
                            r.ip.join(', '),
                          if (r.protocol.isNotEmpty) 'proto: ${r.protocol}',
                          if (r.network.isNotEmpty) 'net: ${r.network}',
                        ].join(' · ');

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: isDark ? 0 : 0.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getRuleIcon(r),
                                      size: 20,
                                      color: r.enabled
                                          ? scheme.primary
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        ruleTitle,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: r.enabled
                                              ? scheme.onSurface
                                              : Colors.grey,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Enabled Switch
                                    Switch(
                                      value: r.enabled,
                                      onChanged: (val) => ref
                                          .read(routingConfigProvider.notifier)
                                          .toggleRuleEnabled(i, val),
                                    ),
                                  ],
                                ),
                                if (ruleSubtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    ruleSubtitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 10),
                                const Divider(height: 1),
                                const SizedBox(height: 10),
                                // Outbound action selector & action buttons
                                Row(
                                  children: [
                                    Text(
                                      I18n.t('ruleAction') + ':',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildOutboundChip(
                                      label: I18n.t('direct'),
                                      isSelected: r.outbound == 'direct',
                                      color: Colors.green.shade700,
                                      onTap: () => ref
                                          .read(routingConfigProvider.notifier)
                                          .updateRuleOutbound(i, 'direct'),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildOutboundChip(
                                      label: I18n.t('proxy'),
                                      isSelected: r.outbound == 'proxy',
                                      color: scheme.primary,
                                      onTap: () => ref
                                          .read(routingConfigProvider.notifier)
                                          .updateRuleOutbound(i, 'proxy'),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildOutboundChip(
                                      label: I18n.t('block'),
                                      isSelected: r.outbound == 'block',
                                      color: Colors.red.shade700,
                                      onTap: () => ref
                                          .read(routingConfigProvider.notifier)
                                          .updateRuleOutbound(i, 'block'),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      tooltip: I18n.t('edit'),
                                      onPressed: () => _openEditRuleDialog(
                                          context, ref,
                                          existingRule: r, index: i),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: Colors.red),
                                      tooltip: I18n.t('delete'),
                                      onPressed: () => ref
                                          .read(routingConfigProvider.notifier)
                                          .removeRule(i),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),

              // Tab 2: 规则集管理 (Rule-Sets - Karing / armwall style)
              configAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (c) => Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_sync_outlined, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            '${I18n.t("ruleSets")} (${_ruleSets.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const Spacer(),
                          FilledButton.tonalIcon(
                            icon: _isUpdatingAll
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh, size: 16),
                            label: Text(
                              _isUpdatingAll
                                  ? I18n.t('updating')
                                  : I18n.t('updateRuleSets'),
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed:
                                _isUpdatingAll ? null : _updateAllRuleSets,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _ruleSets.length,
                        itemBuilder: (context, index) {
                          final item = _ruleSets[index];
                          final currentStatus =
                              _getRuleStatusForTag(c, item.tag);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: isDark ? 0 : 0.5,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : const Color(0xFFCBD5E1),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(item.icon,
                                          size: 20, color: scheme.primary),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: scheme.primary.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.tag,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: scheme.primary,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      FilledButton.tonal(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: item.isUpdating
                                            ? null
                                            : () => _updateRuleSet(item),
                                        child: item.isUpdating
                                            ? const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: CircularProgressIndicator(
                                                    strokeWidth: 2),
                                              )
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(Icons.refresh, size: 14),
                                                  SizedBox(width: 4),
                                                  Text('Update',
                                                      style: TextStyle(
                                                          fontSize: 11)),
                                                ],
                                              ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.url,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant
                                          .withOpacity(0.7),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item.lastUpdated != null ||
                                      item.error != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      item.error ??
                                          'Last updated: ${item.lastUpdated}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: item.error != null
                                            ? Colors.red
                                            : Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),
                                  // Outbound Action Selector for this Rule-Set
                                  Row(
                                    children: [
                                      Text(
                                        I18n.t('outboundAction') + ':',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildOutboundChip(
                                        label: I18n.t('direct'),
                                        isSelected: currentStatus == 'direct',
                                        color: Colors.green.shade700,
                                        onTap: () => ref
                                            .read(routingConfigProvider.notifier)
                                            .setRuleForTag(
                                              tag: item.tag,
                                              name: item.description,
                                              outbound: 'direct',
                                            ),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildOutboundChip(
                                        label: I18n.t('proxy'),
                                        isSelected: currentStatus == 'proxy',
                                        color: scheme.primary,
                                        onTap: () => ref
                                            .read(routingConfigProvider.notifier)
                                            .setRuleForTag(
                                              tag: item.tag,
                                              name: item.description,
                                              outbound: 'proxy',
                                            ),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildOutboundChip(
                                        label: I18n.t('block'),
                                        isSelected: currentStatus == 'block',
                                        color: Colors.red.shade700,
                                        onTap: () => ref
                                            .read(routingConfigProvider.notifier)
                                            .setRuleForTag(
                                              tag: item.tag,
                                              name: item.description,
                                              outbound: 'block',
                                            ),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildOutboundChip(
                                        label: I18n.t('disabled'),
                                        isSelected: currentStatus == 'disable',
                                        color: Colors.grey.shade600,
                                        onTap: () => ref
                                            .read(routingConfigProvider.notifier)
                                            .setRuleForTag(
                                              tag: item.tag,
                                              name: item.description,
                                              outbound: 'disable',
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOutboundChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? color.withOpacity(0.3) : color.withOpacity(0.15))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  IconData _getRuleIcon(RoutingRule r) {
    final text = '${r.name} ${r.domains.join(" ")} ${r.ip.join(" ")}'.toLowerCase();
    if (text.contains('apple')) return Icons.apple;
    if (text.contains('google')) return Icons.travel_explore;
    if (text.contains('openai') || text.contains('ai') || text.contains('claude')) {
      return Icons.smart_toy_outlined;
    }
    if (text.contains('ad') || text.contains('block') || text.contains('shield')) {
      return Icons.shield_outlined;
    }
    if (text.contains('cn') || text.contains('china') || text.contains('国内')) {
      return Icons.language;
    }
    if (text.contains('telegram')) return Icons.send_outlined;
    if (text.contains('github') || text.contains('code')) return Icons.code;
    if (text.contains('netflix') || text.contains('youtube') || text.contains('media')) {
      return Icons.movie_outlined;
    }
    if (text.contains('private') || text.contains('lan')) return Icons.home_outlined;
    return Icons.route;
  }
}

/// Dialog for creating/editing a custom routing rule
class _EditRuleDialog extends StatefulWidget {
  final RoutingRule? existingRule;
  final ValueChanged<RoutingRule> onSave;

  const _EditRuleDialog({this.existingRule, required this.onSave});

  @override
  State<_EditRuleDialog> createState() => _EditRuleDialogState();
}

class _EditRuleDialogState extends State<_EditRuleDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _domainsCtrl;
  late TextEditingController _ipCtrl;
  late TextEditingController _portCtrl;
  late String _outbound;
  late String _network;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final r = widget.existingRule;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _domainsCtrl = TextEditingController(text: r?.domains.join('\n') ?? '');
    _ipCtrl = TextEditingController(text: r?.ip.join('\n') ?? '');
    _portCtrl = TextEditingController(text: r?.port.join(', ') ?? '');
    _outbound = r?.outbound.isNotEmpty == true ? r!.outbound : 'direct';
    _network = r?.network ?? '';
    _enabled = r?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _domainsCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingRule == null
          ? I18n.t('addCustomRule')
          : I18n.t('editRule')),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: I18n.t('ruleName'),
                  hintText: 'e.g. 苹果直连 / OpenAI代理',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _outbound,
                decoration: InputDecoration(
                  labelText: I18n.t('outboundAction'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                      value: 'direct',
                      child: Text('${I18n.t("direct")} (Direct)')),
                  DropdownMenuItem(
                      value: 'proxy',
                      child: Text('${I18n.t("proxy")} (Proxy)')),
                  DropdownMenuItem(
                      value: 'block',
                      child: Text('${I18n.t("block")} (Block)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _outbound = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _domainsCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: I18n.t('domains'),
                  hintText: 'geosite:cn\nexample.com\n*.domain.com',
                  border: const OutlineInputBorder(),
                  helperText: 'One per line or comma separated',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ipCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: I18n.t('ipCidr'),
                  hintText: 'geoip:cn\n192.168.1.0/24',
                  border: const OutlineInputBorder(),
                  helperText: 'One per line or comma separated',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _portCtrl,
                      decoration: InputDecoration(
                        labelText: I18n.t('portRange'),
                        hintText: '80, 443',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _network,
                      decoration: InputDecoration(
                        labelText: I18n.t('networkType'),
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('All (全部)')),
                        DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                        DropdownMenuItem(value: 'udp', child: Text('UDP')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _network = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(I18n.t('enabled')),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(I18n.t('cancel')),
        ),
        FilledButton(
          onPressed: () {
            final parseList = (String raw) => raw
                .split(RegExp(r'[\n,]'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();

            final rule = RoutingRule(
              name: _nameCtrl.text.trim(),
              outbound: _outbound,
              network: _network,
              enabled: _enabled,
              domains: parseList(_domainsCtrl.text),
              ip: parseList(_ipCtrl.text),
              port: parseList(_portCtrl.text),
            );

            widget.onSave(rule);
            Navigator.pop(context);
          },
          child: Text(I18n.t('save')),
        ),
      ],
    );
  }
}

Map<String, dynamic> toGrpcRouting(RoutingConfig config) {
  final directDomains = <String>[];
  final proxyDomains = <String>[];
  final blockDomains = <String>[];
  final directIPs = <String>[];
  final proxyIPs = <String>[];
  final blockIPs = <String>[];

  final customRules = <Map<String, dynamic>>[];

  for (final rule in config.rules) {
    if (!rule.enabled) continue;

    if (rule.protocol.isEmpty &&
        rule.network.isEmpty &&
        rule.inbound.isEmpty &&
        rule.port.isEmpty &&
        rule.source.isEmpty &&
        rule.sourcePort.isEmpty) {
      if (rule.outbound == 'direct' || rule.outbound == 'bypass') {
        directDomains.addAll(rule.domains);
        directIPs.addAll(rule.ip);
      } else if (rule.outbound == 'proxy') {
        proxyDomains.addAll(rule.domains);
        proxyIPs.addAll(rule.ip);
      } else if (rule.outbound == 'block') {
        blockDomains.addAll(rule.domains);
        blockIPs.addAll(rule.ip);
      } else {
        customRules.add(_compileRuleToSingBox(rule));
      }
    } else {
      customRules.add(_compileRuleToSingBox(rule));
    }
  }

  return {
    'direct_domain': directDomains.join('\n'),
    'proxy_domain': proxyDomains.join('\n'),
    'block_domain': blockDomains.join('\n'),
    'direct_ip': directIPs.join('\n'),
    'proxy_ip': proxyIPs.join('\n'),
    'block_ip': blockIPs.join('\n'),
    'def_outbound': config.finalOutbound,
    'custom': customRules.isEmpty ? '' : jsonEncode({'rules': customRules}),
    'remote_dns': config.remoteDns,
    'remote_dns_strategy': config.remoteDnsStrategy,
    'direct_dns': config.directDns,
    'direct_dns_strategy': config.directDnsStrategy,
    'dns_routing': config.dnsRouting,
    'use_dns_object': false,
    'dns_object': '',
    'dns_final_out': config.dnsFinalOut,
    'domain_strategy': config.domainStrategy,
    'outbound_domain_strategy': config.outboundDomainStrategy,
    'sniffing_mode': config.sniffingMode,
  };
}

Map<String, dynamic> _compileRuleToSingBox(RoutingRule rule) {
  final map = <String, dynamic>{};

  final ruleSet = <String>[];
  final domainFull = <String>[];
  final domainSuffix = <String>[];
  final domainKeyword = <String>[];
  final domainRegexp = <String>[];
  bool ipIsPrivate = false;

  for (final d in rule.domains) {
    if (d.startsWith('geosite:')) {
      final tag = d.substring('geosite:'.length);
      if (tag == 'private') {
        ipIsPrivate = true;
      } else {
        ruleSet.add('geosite-$tag');
      }
    } else if (d.startsWith('full:')) {
      domainFull.add(d.substring('full:'.length));
    } else if (d.startsWith('keyword:')) {
      domainKeyword.add(d.substring('keyword:'.length));
    } else if (d.startsWith('regexp:')) {
      domainRegexp.add(d.substring('regexp:'.length));
    } else if (d.startsWith('domain:')) {
      domainSuffix.add(d.substring('domain:'.length));
    } else {
      domainSuffix.add(d);
    }
  }

  final ipCIDR = <String>[];
  for (final ip in rule.ip) {
    if (ip.startsWith('geoip:')) {
      final tag = ip.substring('geoip:'.length);
      if (tag == 'private') {
        ipIsPrivate = true;
      } else {
        ruleSet.add('geoip-$tag');
      }
    } else {
      ipCIDR.add(ip);
    }
  }

  if (ruleSet.isNotEmpty) map['rule_set'] = ruleSet;
  if (domainFull.isNotEmpty) map['domain'] = domainFull;
  if (domainSuffix.isNotEmpty) map['domain_suffix'] = domainSuffix;
  if (domainKeyword.isNotEmpty) map['domain_keyword'] = domainKeyword;
  if (domainRegexp.isNotEmpty) map['domain_regex'] = domainRegexp;
  if (ipCIDR.isNotEmpty) map['ip_cidr'] = ipCIDR;
  if (ipIsPrivate) map['ip_is_private'] = true;

  if (rule.port.isNotEmpty) {
    final portInts = rule.port.map((p) => int.tryParse(p)).whereType<int>().toList();
    if (portInts.isNotEmpty) map['port'] = portInts;
  }
  if (rule.protocol.isNotEmpty) {
    map['protocol'] = rule.protocol.split(',').map((s) => s.trim()).toList();
  }
  if (rule.network.isNotEmpty) {
    map['network'] = rule.network;
  }
  if (rule.outbound.isNotEmpty) {
    map['outbound'] = rule.outbound;
  }

  return map;
}
