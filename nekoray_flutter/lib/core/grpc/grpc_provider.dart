// Wiring between the core child process and the gRPC client.
//
// `connectToCore` is the single entry point the UI uses: it starts the core if
// needed, obtains the token the core was launched with, and opens an
// authenticated channel. Previously the UI connected with an empty token to a
// core nobody had started, so every RPC failed with UNAUTHENTICATED.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../process/core_process.dart';
import 'grpc_client.dart';

/// Rolling buffer of core log lines, for the diagnostics view.
final coreLogProvider =
    StateNotifierProvider<CoreLogNotifier, List<String>>((ref) => CoreLogNotifier());

class CoreLogNotifier extends StateNotifier<List<String>> {
  CoreLogNotifier() : super(const []);

  static const _maxLines = 500;

  void add(String line) {
    final next = [...state, line];
    state = next.length > _maxLines
        ? next.sublist(next.length - _maxLines)
        : next;
  }

  void clear() => state = const [];
}

/// Supervisor for the nekobox_core child process.
final coreProcessProvider = Provider<CoreProcess>((ref) {
  final proc = CoreProcess(
    onLog: (line) => ref.read(coreLogProvider.notifier).add(line),
  );
  ref.onDispose(proc.stop);
  return proc;
});

/// Singleton gRPC client provider.
final grpcClientProvider = Provider<GrpcClient>((ref) {
  final client = GrpcClient();
  ref.onDispose(client.disconnect);
  return client;
});

/// Connection state as shown in the UI.
enum CoreConnectionState { disconnected, connecting, connected, failed }

class CoreConnection {
  final CoreConnectionState state;
  final String? error;
  final int? port;

  const CoreConnection(this.state, {this.error, this.port});

  bool get isConnected => state == CoreConnectionState.connected;
}

final coreConnectionProvider = StateProvider<CoreConnection>(
    (ref) => const CoreConnection(CoreConnectionState.disconnected));

/// Kept for call sites that only need a boolean.
final grpcConnectedProvider = Provider<bool>(
    (ref) => ref.watch(coreConnectionProvider).isConnected);

/// Starts the core (if needed) and opens an authenticated channel.
///
/// Returns null on success, or a human-readable error message.
Future<String?> connectToCore(
  Ref ref, {
  int requestedPort = 0,
  bool debug = false,
}) async {
  final connection = ref.read(coreConnectionProvider.notifier);
  connection.state = const CoreConnection(CoreConnectionState.connecting);

  final proc = ref.read(coreProcessProvider);
  final client = ref.read(grpcClientProvider);

  try {
    final endpoint =
        await proc.ensureStarted(requestedPort: requestedPort, debug: debug);
    await client.connect(
      host: endpoint.host,
      port: endpoint.port,
      token: endpoint.token,
    );
    connection.state =
        CoreConnection(CoreConnectionState.connected, port: endpoint.port);
    return null;
  } catch (e) {
    final message = e is CoreProcessException ? e.message : e.toString();
    connection.state =
        CoreConnection(CoreConnectionState.failed, error: message);
    return message;
  }
}

/// Ensures a usable channel, reconnecting when the core has died.
Future<String?> ensureConnected(Ref ref, {int requestedPort = 0}) async {
  final client = ref.read(grpcClientProvider);
  if (await client.checkHealth()) return null;
  return connectToCore(ref, requestedPort: requestedPort);
}

/// Disconnects and stops the core.
Future<void> disconnectFromCore(Ref ref) async {
  await ref.read(grpcClientProvider).disconnect();
  await ref.read(coreProcessProvider).stop();
  ref.read(coreConnectionProvider.notifier).state =
      const CoreConnection(CoreConnectionState.disconnected);
}
