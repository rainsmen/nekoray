import 'package:flutter_test/flutter_test.dart';
import 'package:nekoray/core/process/core_process.dart';

void main() {
  test('generateToken produces distinct, long tokens', () {
    final tokens = {for (var i = 0; i < 100; i++) CoreProcess.generateToken()};
    expect(tokens.length, 100, reason: 'tokens must not repeat');
    for (final t in tokens) {
      // 32 random bytes, base64url, padding stripped.
      expect(t.length, greaterThanOrEqualTo(40));
      expect(t, isNot(contains('=')));
    }
  });

  test('the listen line printed by the core is parsed', () {
    final re = CoreProcessTestHooks.listenPattern;
    final m = re.firstMatch('nekobox_core listening on 127.0.0.1:41234');
    expect(m, isNotNull);
    expect(m!.group(2), '41234');

    final v6 = re.firstMatch('nekobox_core listening on [::1]:5000');
    expect(v6, isNotNull);
    expect(v6!.group(2), '5000');

    expect(re.firstMatch('some other log line'), isNull);
  });
}
