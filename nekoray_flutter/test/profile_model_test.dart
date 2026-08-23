import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekoray/core/models/profile.dart';

void main() {
  group('ProxyEntity wire format', () {
    test('round-trips the Go core shape', () {
      final source = {
        'type': 'vmess',
        'id': 7,
        'gid': 3,
        'latency': 42,
        'bean': {
          'name': 'node',
          'addr': 'example.com',
          'port': 443,
          'id': 'uuid-1234',
          'aid': 0,
          'stream': {
            'net': 'ws',
            'sec': 'tls',
            'path': '/ws',
            'host': 'cdn.example.com',
            'sni': 'example.com',
          },
        },
      };

      final entity = ProxyEntity.fromJson(source);
      expect(entity.id, 7);
      expect(entity.gid, 3);
      expect(entity.type, 'vmess');
      expect(entity.name, 'node');
      expect(entity.serverAddress, 'example.com');
      expect(entity.serverPort, 443);

      final out = entity.toJson();
      expect(out['bean'], isA<Map>());
      final bean = out['bean'] as Map;
      expect(bean['addr'], 'example.com');
      expect(bean['port'], 443);

      // The transport settings must survive; the old model dropped everything
      // it did not have a typed field for.
      final stream = bean['stream'] as Map;
      expect(stream['net'], 'ws');
      expect(stream['path'], '/ws');
      expect(stream['host'], 'cdn.example.com');
    });

    test('preserves bean keys the UI does not know about', () {
      final entity = ProxyEntity.fromJson({
        'type': 'wireguard',
        'id': 1,
        'bean': {
          'addr': '1.2.3.4',
          'port': 51820,
          'privateKey': 'secret',
          'peerReserved': '0,0,0',
          'someFutureField': 'keep me',
        },
      });

      final bean = entity.toJson()['bean'] as Map;
      expect(bean['someFutureField'], 'keep me');
      expect(bean['peerReserved'], '0,0,0');
    });

    test('stamps the discriminator the core reads', () {
      Map beanOf(String type) =>
          ProxyEntity(id: 1, type: type, bean: {'addr': 'a', 'port': 1})
              .toJson()['bean'] as Map;

      expect(beanOf('vless')['proxy_type'], BeanDiscriminator.vless);
      expect(beanOf('trojan')['proxy_type'], BeanDiscriminator.trojan);
      expect(beanOf('hysteria2')['proxy_type'], BeanDiscriminator.hysteria2);
      expect(beanOf('tuic')['proxy_type'], BeanDiscriminator.tuic);
      expect(beanOf('socks')['socks_http_type'], BeanDiscriminator.socksTypeSocks);
      expect(beanOf('http')['socks_http_type'], BeanDiscriminator.socksTypeHttp);
    });

    test('migrates a beta-era flat profile', () {
      final entity = ProxyEntity.fromJson({
        'id': 5,
        'type': 'vmess',
        'name': 'legacy',
        'server': 'old.example.com',
        'server_port': 8443,
        'uuid': 'abcd',
        'stream': {
          'network': 'ws',
          'security': 'tls',
          'ws_path': '/old',
          'allow_insecure': true,
        },
      });

      expect(entity.serverAddress, 'old.example.com');
      expect(entity.serverPort, 8443);
      final stream = entity.stream!;
      expect(stream['net'], 'ws');
      expect(stream['sec'], 'tls');
      expect(stream['path'], '/old');
      expect(stream['insecure'], true);
    });

    test('brackets IPv6 literals in address', () {
      final entity = ProxyEntity(
        id: 1,
        type: 'trojan',
        bean: {'addr': '2001:db8::1', 'port': 443},
      );
      expect(entity.address, '[2001:db8::1]:443');
    });

    test('copyWith does not alias the original bean', () {
      final a = ProxyEntity(id: 1, type: 'trojan', bean: {'addr': 'x', 'port': 1});
      final b = a.copyWith();
      (b.bean)['addr'] = 'changed';
      expect(a.bean['addr'], 'x');
    });
  });

  group('ProfileGroup', () {
    test('encodes archive as a bool for the core', () {
      final json = ProfileGroup(id: 1, name: 'g').toJson();
      expect(json['archive'], isA<bool>());
      expect(jsonEncode(json), contains('"archive":false'));
    });

    test('accepts the beta-era int encoding', () {
      final g = ProfileGroup.fromJson({'id': 2, 'archive': 1, 'name': 'g'});
      expect(g.archive, isTrue);
    });
  });
}
