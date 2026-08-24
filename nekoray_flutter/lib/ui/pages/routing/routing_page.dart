import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.finalOutbound = 'direct',
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
      finalOutbound: (j['finalOutbound'] as String?) ?? 'direct',
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

RoutingConfig getPresetBypassMainland() {
  return RoutingConfig(
    finalOutbound: 'proxy',
    rules: [
      RoutingRule(
        domains: ['geosite:category-ads-all'],
        outbound: 'block',
      ),
      RoutingRule(
        domains: ['geosite:private'],
        ip: ['geoip:private'],
        outbound: 'direct',
      ),
      RoutingRule(
        domains: ['geosite:cn'],
        ip: ['geoip:cn'],
        outbound: 'direct',
      ),
    ],
  );
}

RoutingConfig getPresetBypassGFW() {
  return RoutingConfig(
    finalOutbound: 'direct',
    rules: [
      RoutingRule(
        domains: ['geosite:category-ads-all'],
        outbound: 'block',
      ),
      RoutingRule(
        domains: ['geosite:private'],
        ip: ['geoip:private'],
        outbound: 'direct',
      ),
      RoutingRule(
        domains: ['geosite:gfw'],
        outbound: 'proxy',
      ),
    ],
  );
}

RoutingConfig getPresetBypassForeign() {
  return RoutingConfig(
    finalOutbound: 'direct',
    rules: [
      RoutingRule(
        domains: ['geosite:category-ads-all'],
        outbound: 'block',
      ),
      RoutingRule(
        domains: ['geosite:cn'],
        ip: ['geoip:cn'],
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
        domains: ['geosite:category-ads-all'],
        outbound: 'block',
      ),
    ],
  );
}

RoutingConfig getPresetGlobalDirect() {
  return RoutingConfig(
    finalOutbound: 'direct',
    rules: [
      RoutingRule(
        domains: ['geosite:category-ads-all'],
        outbound: 'block',
      ),
    ],
  );
}

String _detectPresetName(RoutingConfig config) {
  if (config.finalOutbound == 'proxy' &&
      config.rules.length == 3 &&
      config.rules[2].domains.contains('geosite:cn')) {
    return 'bypass_cn';
  }
  if (config.finalOutbound == 'direct' &&
      config.rules.length == 3 &&
      config.rules[2].domains.contains('geosite:gfw')) {
    return 'bypass_gfw';
  }
  if (config.finalOutbound == 'direct' &&
      config.rules.length == 2 &&
      config.rules[1].domains.contains('geosite:cn')) {
    return 'bypass_foreign';
  }
  if (config.finalOutbound == 'proxy' && config.rules.length == 1) {
    return 'global_proxy';
  }
  if (config.finalOutbound == 'direct' && config.rules.length == 1) {
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
  final String format; // 'binary' | 'source'
  final String defaultOutbound;
  bool isUpdating;
  String? lastUpdated;
  String? error;

  RuleSetItem({
    required this.tag,
    required this.description,
    required this.url,
    this.format = 'binary',
    this.defaultOutbound = 'direct',
    this.isUpdating = false,
    this.lastUpdated,
    this.error,
  });
}

class RoutingPage extends StatefulWidget {
  const RoutingPage({super.key});

  @override
  State<RoutingPage> createState() => _RoutingPageState();
}

class _RoutingPageState extends State<RoutingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<RuleSetItem> _ruleSets = [
    RuleSetItem(
      tag: 'geosite-cn',
      description: '中国大陆常用域名规则集 (China mainland domains)',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs',
      defaultOutbound: 'direct',
    ),
    RuleSetItem(
      tag: 'geoip-cn',
      description: '中国大陆 IP 地址段规则集 (China mainland IP CIDRs)',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs',
      defaultOutbound: 'direct',
    ),
    RuleSetItem(
      tag: 'geosite-geolocation-!cn',
      description: '非中国大陆地区域名规则集 (Non-China foreign domains)',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-geolocation-!cn.srs',
      defaultOutbound: 'proxy',
    ),
    RuleSetItem(
      tag: 'geosite-category-ads-all',
      description: '全网广告与隐私追踪过滤规则集 (Ad & privacy tracker block)',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs',
      defaultOutbound: 'block',
    ),
    RuleSetItem(
      tag: 'geosite-google',
      description: 'Google 全球服务域名规则集 (Google services & domains)',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-google.srs',
      defaultOutbound: 'proxy',
    ),
    RuleSetItem(
      tag: 'geosite-github',
      description: 'GitHub 常用域名规则集 (GitHub services & assets)',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-github.srs',
      defaultOutbound: 'proxy',
    ),
    RuleSetItem(
      tag: 'geosite-openai',
      description: 'OpenAI / ChatGPT 访问规则集 (ChatGPT domain endpoints)',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-openai.srs',
      defaultOutbound: 'proxy',
    ),
    RuleSetItem(
      tag: 'geoip-private',
      description: '私有局域网与回环地址规则集 (Private LAN addresses)',
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-private.srs',
      defaultOutbound: 'direct',
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
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ));
      await dio.head(item.url);
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

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final config = ref.watch(routingConfigProvider);
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
                icon: const Icon(Icons.add),
                tooltip: I18n.t('create'),
                onPressed: () => _addRule(context, ref),
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: 路由规则 (Routing Rules)
              config.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (c) => Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            const Text('Preset:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: _detectPresetName(c),
                              items: const [
                                DropdownMenuItem(
                                    value: 'bypass_cn',
                                    child: Text('Bypass Mainland China (绕过国内)')),
                                DropdownMenuItem(
                                    value: 'bypass_gfw',
                                    child: Text('Bypass GFW (绕过GFW)')),
                                DropdownMenuItem(
                                    value: 'bypass_foreign',
                                    child: Text('Bypass Foreign (绕过国外)')),
                                DropdownMenuItem(
                                    value: 'global_proxy',
                                    child: Text('Global Proxy (全局代理)')),
                                DropdownMenuItem(
                                    value: 'global_direct',
                                    child: Text('Global Direct (全局直连)')),
                                DropdownMenuItem(
                                    value: 'custom',
                                    child: Text('Custom (自定义)')),
                              ],
                              onChanged: (val) {
                                if (val == null) return;
                                final notifier =
                                    ref.read(routingConfigProvider.notifier);
                                switch (val) {
                                  case 'bypass_cn':
                                    notifier
                                        .applyPreset(getPresetBypassMainland());
                                    break;
                                  case 'bypass_gfw':
                                    notifier.applyPreset(getPresetBypassGFW());
                                    break;
                                  case 'bypass_foreign':
                                    notifier
                                        .applyPreset(getPresetBypassForeign());
                                    break;
                                  case 'global_proxy':
                                    notifier
                                        .applyPreset(getPresetGlobalProxy());
                                    break;
                                  case 'global_direct':
                                    notifier
                                        .applyPreset(getPresetGlobalDirect());
                                    break;
                                }
                              },
                            ),
                            const Spacer(),
                            const Text('Default:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: c.finalOutbound,
                              items: const [
                                DropdownMenuItem(
                                    value: 'direct', child: Text('Direct (直连)')),
                                DropdownMenuItem(
                                    value: 'proxy', child: Text('Proxy (代理)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  ref
                                      .read(routingConfigProvider.notifier)
                                      .updateFinalOutbound(val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: c.rules.isEmpty
                          ? Center(child: Text(I18n.t('noRoutingRules')))
                          : ListView.separated(
                              itemCount: c.rules.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final r = c.rules[i];
                                return ListTile(
                                  leading: const Icon(Icons.route),
                                  title: Text(r.domains.isNotEmpty
                                      ? r.domains.join(', ')
                                      : r.ip.isNotEmpty
                                          ? r.ip.join(', ')
                                          : 'Rule ${i + 1}'),
                                  subtitle: Text(
                                    '→ ${r.outbound}'
                                    '${r.protocol.isNotEmpty ? '  proto=${r.protocol}' : ''}'
                                    '${r.network.isNotEmpty ? '  net=${r.network}' : ''}',
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => ref
                                        .read(routingConfigProvider.notifier)
                                        .removeRule(i),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),

              // Tab 2: 规则集管理 (Rule-Sets) - armwall style
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                          bottom: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant)),
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
                        final scheme = Theme.of(context).colorScheme;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: scheme.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: scheme.primaryContainer,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.tag,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: scheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerHighest,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.format.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: item.isUpdating
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2),
                                            )
                                          : const Icon(Icons.sync, size: 18),
                                      tooltip: 'Update',
                                      onPressed: item.isUpdating
                                          ? null
                                          : () => _updateRuleSet(item),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.description,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.url,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.lastUpdated != null ||
                                    item.error != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    item.error ??
                                        'Last checked: ${item.lastUpdated}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: item.error != null
                                          ? scheme.error
                                          : Colors.green,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _addRule(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const _RuleEditDialog(),
    ).then((rule) {
      if (rule is RoutingRule) {
        ref.read(routingConfigProvider.notifier).addRule(rule);
      }
    });
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
      final name = d.substring(8);
      if (name == 'private') {
        ipIsPrivate = true;
      } else {
        ruleSet.add('geosite-$name');
      }
    } else if (d.startsWith('full:')) {
      domainFull.add(d.substring(5));
    } else if (d.startsWith('domain:')) {
      domainSuffix.add(d.substring(7));
    } else if (d.startsWith('keyword:')) {
      domainKeyword.add(d.substring(8));
    } else if (d.startsWith('regexp:')) {
      domainRegexp.add(d.substring(7));
    } else {
      domainSuffix.add(d);
    }
  }

  final ipCidr = <String>[];
  for (final ip in rule.ip) {
    if (ip.startsWith('geoip:')) {
      final name = ip.substring(6);
      if (name == 'private') {
        ipIsPrivate = true;
      } else {
        ruleSet.add('geoip-$name');
      }
    } else {
      ipCidr.add(ip);
    }
  }

  if (ruleSet.isNotEmpty) map['rule_set'] = ruleSet;
  if (ipIsPrivate) map['ip_is_private'] = true;
  if (domainFull.isNotEmpty) map['domain'] = domainFull;
  if (domainSuffix.isNotEmpty) map['domain_suffix'] = domainSuffix;
  if (domainKeyword.isNotEmpty) map['domain_keyword'] = domainKeyword;
  if (domainRegexp.isNotEmpty) map['domain_regex'] = domainRegexp;
  if (ipCidr.isNotEmpty) map['ip_cidr'] = ipCidr;

  if (rule.port.isNotEmpty) {
    _applyPorts(map, 'port', 'port_range', rule.port);
  }
  if (rule.source.isNotEmpty) {
    map['source_ip_cidr'] = rule.source;
  }
  if (rule.sourcePort.isNotEmpty) {
    _applyPorts(map, 'source_port', 'source_port_range', rule.sourcePort);
  }
  if (rule.protocol.isNotEmpty) {
    map['protocol'] = [rule.protocol];
  }
  if (rule.network.isNotEmpty) {
    map['network'] = [rule.network];
  }

  map['outbound'] = rule.outbound;
  return map;
}

void _applyPorts(
  Map<String, dynamic> map,
  String singleKey,
  String rangeKey,
  List<String> entries,
) {
  final single = <int>[];
  final ranges = <String>[];

  for (final raw in entries) {
    final entry = raw.trim();
    if (entry.isEmpty) continue;

    final sep = entry.contains('-') ? '-' : (entry.contains(':') ? ':' : null);
    if (sep != null) {
      final parts = entry.split(sep);
      if (parts.length != 2) continue;
      final lo = _port(parts[0]);
      final hi = _port(parts[1]);
      if (lo == null || hi == null || lo > hi) continue;
      ranges.add('$lo:$hi');
      continue;
    }

    final p = _port(entry);
    if (p != null) single.add(p);
  }

  if (single.isNotEmpty) map[singleKey] = single;
  if (ranges.isNotEmpty) map[rangeKey] = ranges;
}

int? _port(String s) {
  final n = int.tryParse(s.trim());
  if (n == null || n < 0 || n > 65535) return null;
  return n;
}

class _RuleEditDialog extends StatefulWidget {
  const _RuleEditDialog();

  @override
  State<_RuleEditDialog> createState() => _RuleEditDialogState();
}

class _RuleEditDialogState extends State<_RuleEditDialog> {
  final _domains = TextEditingController();
  final _ip = TextEditingController();
  final _outbound = TextEditingController(text: 'direct');
  String _protocol = '';
  String _network = '';

  @override
  void dispose() {
    _domains.dispose();
    _ip.dispose();
    _outbound.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Routing Rule'),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _domains,
              decoration: const InputDecoration(
                labelText: 'Domains (comma-separated)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ip,
              decoration: const InputDecoration(
                labelText: 'IP/CIDR (comma-separated)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _outbound,
              decoration: const InputDecoration(
                labelText: 'Outbound',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _protocol.isEmpty ? 'any' : _protocol,
                    decoration: const InputDecoration(
                      labelText: 'Protocol',
                      border: OutlineInputBorder(),
                    ),
                    items: const ['any', 'tcp', 'udp']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _protocol = v == 'any' ? '' : v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _network.isEmpty ? 'any' : _network,
                    decoration: const InputDecoration(
                      labelText: 'Network',
                      border: OutlineInputBorder(),
                    ),
                    items: const ['any', 'tcp', 'udp']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _network = v == 'any' ? '' : v!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final rule = RoutingRule(
              domains: _domains.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList(),
              ip: _ip.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList(),
              outbound: _outbound.text,
              protocol: _protocol,
              network: _network,
            );
            Navigator.pop(context, rule);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
