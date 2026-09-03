// Profile editor dialog — creates or edits a ProxyEntity using DynamicForm.
//
// The dialog edits the bean map in place rather than rebuilding a typed entity
// from a hardcoded field list. The previous version reconstructed only the
// handful of fields it knew about, so saving a node discarded its transport
// settings (ws path, gRPC service name, reality keys on protocols it did not
// enumerate, and every wireguard/ssh/naive/anytls field).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n.dart';
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

  /// Working copy of the profile's bean; never replaced, only merged into, so
  /// keys the current schema does not render survive an edit.
  late Map<String, dynamic> _bean;

  final _formKey = GlobalKey<DynamicFormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? ProxyType.vmess;
    _bean = e == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(e.toJson()['bean'] as Map);
  }

  /// Flattens bean + stream into the key space the schema addresses.
  Map<String, dynamic> get _formValues {
    final values = <String, dynamic>{};
    for (final f in protocolSchemas[_type] ?? const <FieldSchema>[]) {
      if (f.group == FieldGroup.stream) {
        final stream = _bean['stream'];
        if (stream is Map) values[f.inputKey] = stream[f.key];
      } else {
        values[f.inputKey] = _bean[f.key];
      }
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final schema = protocolSchemas[_type] ?? const <FieldSchema>[];
    return AlertDialog(
      title: Text(widget.existing == null ? I18n.t('newProfile') : I18n.t('editProfile')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                decoration: InputDecoration(
                  labelText: I18n.t('protocol'),
                  border: const OutlineInputBorder(),
                ),
                items: protocolTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v == null || v == _type) return;
                        // Fold what is on screen back into the bean before the
                        // schema changes, so switching protocol and back does
                        // not lose typed values.
                        _mergeForm();
                        setState(() => _type = v);
                      },
              ),
              const SizedBox(height: 16),
              DynamicForm(
                // The GlobalKey both identifies this form (driving rebuilds
                // on protocol change via didUpdateWidget reconciliation) and
                // lets _mergeForm/_save collect the typed values. A plain
                // ValueKey here used to leave _formKey.currentState null, so
                // every edit was silently discarded and saved beans came out
                // empty (no name/address) — breaking the node on next start.
                key: _formKey,
                fields: schema,
                values: _formValues,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(I18n.t('cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(widget.existing == null ? I18n.t('create') : I18n.t('save')),
        ),
      ],
    );
  }

  /// Merges the visible form values into the bean, routing stream-group fields
  /// into the nested `stream` object.
  void _mergeForm() {
    final state = _formKey.currentState;
    final collected = state?.collect(includeEmptyOptional: true);
    if (collected == null) return;

    final schema = {
      for (final f in protocolSchemas[_type] ?? const <FieldSchema>[]) f.inputKey: f
    };

    for (final entry in collected.entries) {
      final field = schema[entry.key];
      if (field == null) continue;
      if (field.group == FieldGroup.stream) {
        final stream = _bean['stream'];
        final map = stream is Map
            ? Map<String, dynamic>.from(stream)
            : <String, dynamic>{};
        map[field.key] = entry.value;
        _bean['stream'] = map;
      } else {
        _bean[field.key] = entry.value;
      }
    }

    // Drop keys the user cleared, so the core sees an absent field rather than
    // an explicit empty value.
    _bean.removeWhere((k, v) => v is String && v.isEmpty && k != 'name');
    final stream = _bean['stream'];
    if (stream is Map) {
      stream.removeWhere((k, v) => v is String && v.isEmpty);
      if (stream.isEmpty) _bean.remove('stream');
    }
  }

  Future<void> _save() async {
    final formState = _formKey.currentState;
    final problem = formState?.validate();
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(problem), backgroundColor: Colors.red),
      );
      return;
    }

    _mergeForm();
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notifier = ref.read(profileListProvider.notifier);

    try {
      if (widget.existing == null) {
        await notifier.create(type: _type, bean: _bean);
      } else {
        await notifier.update(widget.existing!.copyWith(type: _type, bean: _bean));
      }
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
