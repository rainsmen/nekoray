import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'grpc_client.dart';

/// Singleton gRPC client provider.
final grpcClientProvider = Provider<GrpcClient>((ref) {
  final client = GrpcClient();
  ref.onDispose(client.disconnect);
  return client;
});

/// Whether the gRPC channel is currently open.
final grpcConnectedProvider = StateProvider<bool>((ref) => false);

/// Connects to the core and flips [grpcConnectedProvider].
Future<void> connectToCore(
  WidgetRef ref, {
  String host = '127.0.0.1',
  int port = 19821,
  String token = '',
}) async {
  final client = ref.read(grpcClientProvider);
  await client.connect(host: host, port: port, token: token);
  ref.read(grpcConnectedProvider.notifier).state = true;
}

/// Disconnects from the core.
Future<void> disconnectFromCore(WidgetRef ref) async {
  final client = ref.read(grpcClientProvider);
  await client.disconnect();
  ref.read(grpcConnectedProvider.notifier).state = false;
}
