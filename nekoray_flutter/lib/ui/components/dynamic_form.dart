// Dynamic form rendered from a FieldSchema list.
//
// The controller map is rebuilt in didUpdateWidget: the protocol dropdown
// swaps the schema under a form whose State is reused, and the previous
// implementation built controllers once in initState. Switching protocol then
// left `_controllers[key]` null for every new field and `collect()` threw on
// the null assertion — i.e. changing the protocol always crashed the dialog.

import 'package:flutter/material.dart';

import '../../core/i18n.dart';
import '../schema/protocol_schema.dart';

class DynamicForm extends StatefulWidget {
  final List<FieldSchema> fields;
  final Map<String, dynamic> values;

  const DynamicForm({
    super.key,
    required this.fields,
    required this.values,
  });

  @override
  State<DynamicForm> createState() => DynamicFormState();
}

/// Public state class so the parent can call [collect].
class DynamicFormState extends State<DynamicForm> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _bools = {};

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant DynamicForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.fields, widget.fields) ||
        !identical(oldWidget.values, widget.values)) {
      _sync();
    }
  }

  /// Reconciles controllers with the current schema: adds controllers for new
  /// fields, disposes those whose field disappeared, keeps the rest (so text
  /// typed into a field shared by two protocols survives a protocol switch).
  void _sync() {
    final wanted = {for (final f in widget.fields) f.inputKey: f};

    for (final key in _controllers.keys.toList()) {
      if (!wanted.containsKey(key)) {
        _controllers.remove(key)!.dispose();
      }
    }
    _bools.removeWhere((key, _) => !wanted.containsKey(key));

    wanted.forEach((key, f) {
      if (f.type == FieldType.bool_) {
        _bools.putIfAbsent(key, () => widget.values[key] == true);
        return;
      }
      final initial = _str(widget.values[key]);
      final existing = _controllers[key];
      if (existing == null) {
        _controllers[key] = TextEditingController(text: initial);
      } else if (existing.text.isEmpty && initial.isNotEmpty) {
        existing.text = initial;
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  String _str(dynamic v) {
    if (v == null) return '';
    if (v is bool) return '';
    return v.toString();
  }

  /// Collects current field values, keyed and typed per the schema.
  ///
  /// Empty optional fields are omitted rather than written as `""`, so the
  /// core's zero-value defaults apply instead of an explicit empty string.
  Map<String, dynamic> collect({bool includeEmptyOptional = false}) {
    final out = <String, dynamic>{};
    for (final f in widget.fields) {
      switch (f.type) {
        case FieldType.bool_:
          out[f.inputKey] = _bools[f.inputKey] ?? false;
          break;
        case FieldType.number:
          final raw = _controllers[f.inputKey]?.text.trim() ?? '';
          if (raw.isEmpty) {
            if (includeEmptyOptional && !f.required) out[f.inputKey] = '';
            break;
          }
          final n = int.tryParse(raw);
          if (n != null) out[f.inputKey] = n;
          break;
        default:
          final raw = _controllers[f.inputKey]?.text ?? '';
          if (raw.isEmpty && !f.required && !includeEmptyOptional) break;
          out[f.inputKey] = raw;
      }
    }
    return out;
  }

  /// Returns the first schema violation, or null when the form is valid.
  String? validate() {
    for (final f in widget.fields) {
      if (!f.required) continue;
      final label = schemaLabel(f);
      final raw = _controllers[f.inputKey]?.text.trim() ?? '';
      if (raw.isEmpty) return I18n.t('formFieldRequired', {'label': label});
      if (f.type == FieldType.number) {
        final n = int.tryParse(raw);
        if (n == null) return I18n.t('formMustBeNumber', {'label': label});
        if (f.key == 'port' && (n < 1 || n > 65535)) {
          return I18n.t('formPortRange');
        }
      }
    }
    // Port is validated even when not marked required.
    final portRaw = _controllers[widget.fields.firstWhere((f) => f.key == 'port', orElse: () => const FieldSchema('port', '', FieldType.number)).inputKey]?.text.trim();
    if (portRaw != null && portRaw.isNotEmpty) {
      final n = int.tryParse(portRaw);
      if (n == null || n < 1 || n > 65535) {
        return I18n.t('formPortRange');
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: widget.fields.map(_buildField).toList(),
    );
  }

  Widget _buildField(FieldSchema f) {
    switch (f.type) {
      case FieldType.text:
      case FieldType.password:
      case FieldType.multiline:
        return _padded(TextFormField(
          controller: _controllers[f.inputKey],
          decoration: InputDecoration(
            labelText:
                f.required ? '${schemaLabel(f)} *' : schemaLabel(f),
            hintText: f.hint,
            border: const OutlineInputBorder(),
          ),
          obscureText: f.type == FieldType.password,
          maxLines: f.multiline ? 4 : 1,
        ));

      case FieldType.number:
        return _padded(TextFormField(
          controller: _controllers[f.inputKey],
          decoration: InputDecoration(
            labelText:
                f.required ? '${schemaLabel(f)} *' : schemaLabel(f),
            hintText: f.hint,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ));

      case FieldType.combo:
        final options = f.options ?? const <String>[];
        final controller = _controllers[f.inputKey];
        final current = controller?.text ?? '';
        // Only feed the dropdown a value it actually offers; anything else
        // (e.g. a value imported from a share link) is preserved in the
        // controller and shown as the "custom" entry.
        final items = <String>[
          ...options,
          if (current.isNotEmpty && !options.contains(current)) current,
        ];
        final value = items.contains(current)
            ? current
            : (items.isNotEmpty ? items.first : null);
        return _padded(DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            labelText: schemaLabel(f),
            border: const OutlineInputBorder(),
          ),
          items: items
              .map((o) => DropdownMenuItem(
                    value: o,
                    child: Text(o.isEmpty ? '(none)' : o),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) controller?.text = v;
          },
        ));

      case FieldType.bool_:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CheckboxListTile(
            value: _bools[f.inputKey] ?? false,
            title: Text(schemaLabel(f)),
            subtitle: f.hint == null ? null : Text(f.hint!),
            onChanged: (v) => setState(() => _bools[f.inputKey] = v ?? false),
          ),
        );
    }
  }

  Widget _padded(Widget child) =>
      Padding(padding: const EdgeInsets.only(bottom: 12), child: child);
}
