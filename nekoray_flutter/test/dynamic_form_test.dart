import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekoray/ui/components/dynamic_form.dart';
import 'package:nekoray/ui/schema/protocol_schema.dart';

/// Hosts a DynamicForm whose schema can be swapped, mirroring what the profile
/// dialog does when the protocol dropdown changes.
class _Host extends StatefulWidget {
  final GlobalKey<DynamicFormState> formKey;
  const _Host({required this.formKey});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String type = 'vmess';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () => setState(() => type = 'wireguard'),
                child: const Text('switch'),
              ),
              DynamicForm(
                key: widget.formKey,
                fields: protocolSchemas[type]!,
                values: const {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('switching protocol does not throw and collect() stays valid',
      (tester) async {
    final formKey = GlobalKey<DynamicFormState>();
    await tester.pumpWidget(_Host(formKey: formKey));

    // Before: vmess fields are present.
    expect(formKey.currentState, isNotNull);
    expect(formKey.currentState!.collect().containsKey('name'), isTrue);

    // The regression: the schema changes under a reused State, and the old
    // implementation threw a null-assertion in collect() for every new field.
    await tester.tap(find.text('switch'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final collected = formKey.currentState!.collect();
    // wireguard-only key must now be collectable...
    expect(collected.containsKey('privateKey'), isTrue);
    // ...and vmess-only keys must be gone.
    expect(collected.containsKey('aid'), isFalse);
  });

  testWidgets('typed values survive a schema swap for shared keys',
      (tester) async {
    final formKey = GlobalKey<DynamicFormState>();
    await tester.pumpWidget(_Host(formKey: formKey));

    await tester.enterText(find.widgetWithText(TextFormField, 'Address *'), 'host.example');
    await tester.tap(find.text('switch'));
    await tester.pumpAndSettle();

    expect(formKey.currentState!.collect()['addr'], 'host.example');
  });

  testWidgets('validate() reports a missing required field', (tester) async {
    final formKey = GlobalKey<DynamicFormState>();
    await tester.pumpWidget(_Host(formKey: formKey));

    expect(formKey.currentState!.validate(), isNotNull);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name *'), 'n');
    await tester.enterText(find.widgetWithText(TextFormField, 'Address *'), 'a');
    await tester.enterText(find.widgetWithText(TextFormField, 'Port *'), '443');
    await tester.enterText(find.widgetWithText(TextFormField, 'UUID *'), 'u');
    await tester.pump();

    expect(formKey.currentState!.validate(), isNull);
  });

  testWidgets('validate() rejects an out-of-range port', (tester) async {
    final formKey = GlobalKey<DynamicFormState>();
    await tester.pumpWidget(_Host(formKey: formKey));

    await tester.enterText(find.widgetWithText(TextFormField, 'Name *'), 'n');
    await tester.enterText(find.widgetWithText(TextFormField, 'Address *'), 'a');
    await tester.enterText(find.widgetWithText(TextFormField, 'Port *'), '99999');
    await tester.enterText(find.widgetWithText(TextFormField, 'UUID *'), 'u');
    await tester.pump();

    expect(formKey.currentState!.validate(), contains('Port'));
  });

  test('every schema key is unique within its protocol', () {
    protocolSchemas.forEach((type, fields) {
      final keys = fields.map((f) => f.inputKey).toList();
      expect(keys.toSet().length, keys.length,
          reason: 'duplicate field key in "$type" schema — the later field '
              'would shadow the earlier one in collect()');
    });
  });

  test('every protocol declares the common addressing fields', () {
    protocolSchemas.forEach((type, fields) {
      final keys = fields.map((f) => f.key).toSet();
      expect(keys, contains('name'), reason: '$type is missing "name"');
      if (type != 'custom') {
        expect(keys, contains('addr'), reason: '$type is missing "addr"');
        expect(keys, contains('port'), reason: '$type is missing "port"');
      }
    });
  });
}
