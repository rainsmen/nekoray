// nekoray Flutter desktop client entry point.
//
// Phase 2: replaces the legacy C++/Qt UI with a modern Flutter app that talks
// to the Go nekobox_core via gRPC.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  runApp(const ProviderScope(child: NekoRayApp()));
}
