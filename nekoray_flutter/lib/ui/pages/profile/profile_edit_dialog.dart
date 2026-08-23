// Profile editor dialog — creates or edits a ProxyEntity using DynamicForm.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/profile.dart';
import '../../../core/state/providers.dart';
import '../../components/dynamic_form.dart';
import '../../schema/protocol_schema.dart';

class ProfileEditDialog extends ConsumerStatefulWidget {
  final ProxyEntity? existing; // null = new

  const ProfileEditDialog({super.key, this.existing});

  @override
  ConsumerState<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends ConsumerState<ProfileEditDialog> {
  late String _type;
  late final Map<String, dynamic> _values;
  final _formKey = GlobalKey<DynamicFormState>();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? 'vmess';
    _values = e?.toJson() ?? <String, dynamic>{};
    // flatten bean fields into the values map for the form
    _values['server'] = e?.bean.serverAddress ?? '';
    _values['server_port'] = e?.bean.serverPort ?? 0;
    _values['password'] = e?.bean.password;
    _values['uuid'] = e?.bean.uuid;
    _values['id'] = e?.bean.id;
    _values['alter_id'] = e?.bean.alterId;
    _values['method'] = e?.bean.method;
    _values['sni'] = e?.bean.sni;
    _values['net'] = e?.bean.net;
    _values['tls'] = e?.bean.tls;
    _values['path'] = e?.bean.path;
    _values['host'] = e?.bean.host;
    _values['flow'] = e?.bean.flow;
    _values['up_mbps'] = e?.bean.upMbps;
    _values['down_mbps'] = e?.bean.downMbps;
    _values['obfs_password'] = e?.bean.obfsPassword;
    _values['congestion_control'] = e?.bean.congestionControl;
    _values['udp_relay_mode'] = e?.bean.udpRelayMode;
    _values['username'] = e?.bean.username ?? '';
    _values['allow_insecure'] = e?.bean.stream?.allowInsecure ?? false;
    _values['public_key'] = e?.bean.stream?.publicKey;
    _values['short_id'] = e?.bean.stream?.shortId;
    _values['fingerprint'] = e?.bean.stream?.fingerprint;
    _values['custom_config'] = e?.bean.customConfig;
  }

  @override
  Widget build(BuildContext context) {
    final schema = protocolSchemas[_type] ?? [];
    return AlertDialog(
      title: Text(widget.existing == null ? 'New Profile' : 'Edit Profile'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Protocol',
                  border: OutlineInputBorder(),
                ),
                items: protocolTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
              const SizedBox(height: 16),
              DynamicForm(
                key: _formKey,
                fields: schema,
                values: _values,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.existing == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  void _save() {
    final collected = _formKey.currentState?.collect() ?? {};
    _values.addAll(collected);
    final entity = _buildEntity();
    if (widget.existing == null) {
      ref.read(profileListProvider.notifier).add(entity);
    } else {
      ref.read(profileListProvider.notifier).update(entity);
    }
    Navigator.pop(context);
  }

  ProxyEntity _buildEntity() {
    final name = _values['name'] as String? ?? '';
    final server = _values['server'] as String? ?? '';
    final port = (_values['server_port'] as num?)?.toInt() ?? 0;

    final stream = StreamSettings(
      allowInsecure: _values['allow_insecure'] == true,
      publicKey: _values['public_key'] as String?,
      shortId: _values['short_id'] as String?,
      fingerprint: _values['fingerprint'] as String?,
      sni: _values['sni'] as String?,
    );

    final bean = AbstractBean(
      serverAddress: server,
      serverPort: port,
      password: _values['password'] as String?,
      uuid: _values['uuid'] as String?,
      id: _values['id'] as String?,
      alterId: (_values['alter_id'] as num?)?.toInt() ?? 0,
      method: _values['method'] as String?,
      sni: _values['sni'] as String?,
      net: _values['net'] as String?,
      tls: _values['tls'] as String?,
      path: _values['path'] as String?,
      host: _values['host'] as String?,
      flow: _values['flow'] as String?,
      upMbps: (_values['up_mbps'] as num?)?.toInt(),
      downMbps: (_values['down_mbps'] as num?)?.toInt(),
      obfsPassword: _values['obfs_password'] as String?,
      congestionControl: _values['congestion_control'] as String?,
      udpRelayMode: _values['udp_relay_mode'] as String?,
      username: _values['username'] as String? ?? '',
      customConfig: _values['custom_config'] as String?,
      stream: stream,
    );

    final id = widget.existing?.id ??
        DateTime.now().millisecondsSinceEpoch.remainder(1000000);

    return ProxyEntity(
      id: id,
      gid: widget.existing?.gid ?? 0,
      type: _type,
      name: name,
      bean: bean,
      stream: stream,
    );
  }
}
