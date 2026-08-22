// Dynamic form rendered from FieldSchema list.
//
// Task 11: schema-driven protocol editor. Adding a new protocol type only
// requires registering a schema — no UI code changes.

import 'package:flutter/material.dart';

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
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, dynamic> _local;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _local = Map<String, dynamic>.from(widget.values);
    for (final f in widget.fields) {
      _controllers[f.key] = TextEditingController(text: _str(_local[f.key]));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _str(dynamic v) {
    if (v == null) return '';
    if (v is bool) return '';
    return v.toString();
  }

  /// Collects current field values into a map.
  Map<String, dynamic> collect() {
    final out = <String, dynamic>{};
    for (final f in widget.fields) {
      final raw = _controllers[f.key]!.text;
      switch (f.type) {
        case FieldType.number:
          out[f.key] = int.tryParse(raw) ?? 0;
          break;
        case FieldType.bool_:
          out[f.key] = _local[f.key] == true;
          break;
        default:
          out[f.key] = raw;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: widget.fields.map((f) => _buildField(f)).toList(),
    );
  }

  Widget _buildField(FieldSchema f) {
    switch (f.type) {
      case FieldType.text:
      case FieldType.password:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: _controllers[f.key],
            decoration: InputDecoration(
              labelText: f.label,
              hintText: f.hint,
              border: const OutlineInputBorder(),
            ),
            obscureText: f.type == FieldType.password,
            maxLines: f.multiline ? 4 : 1,
          ),
        );
      case FieldType.number:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: _controllers[f.key],
            decoration: InputDecoration(
              labelText: f.label,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        );
      case FieldType.combo:
        final options = f.options ?? [];
        final current = _controllers[f.key]!.text;
        final dropdownValue = options.contains(current) || current.isEmpty
            ? (current.isEmpty && options.isNotEmpty ? options.first : current)
            : options.firstOrNull;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: dropdownValue,
            decoration: InputDecoration(
              labelText: f.label,
              border: const OutlineInputBorder(),
            ),
            items: options
                .map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(o.isEmpty ? '(none)' : o),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) _controllers[f.key]!.text = v;
            },
          ),
        );
      case FieldType.bool_:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CheckboxListTile(
            value: _local[f.key] == true,
            title: Text(f.label),
            onChanged: (v) {
              setState(() {
                _local[f.key] = v ?? false;
              });
            },
          ),
        );
      case FieldType.tls:
      case FieldType.stream:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: _controllers[f.key],
            decoration: InputDecoration(
              labelText: f.label,
              border: const OutlineInputBorder(),
            ),
          ),
        );
    }
  }
}
