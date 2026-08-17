import 'dart:async';

import 'package:rogsheba_mobile/core/services/connectivity_service.dart';

/// Scriptable [ConnectivityService] for widget tests. Emits the configured
/// state immediately on listen (mirroring the real plugin's initial check),
/// then live-updates whenever [setOnline] flips it.
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.online = true});

  /// The current state; flips with [setOnline].
  bool online;

  final StreamController<bool> _controller = StreamController.broadcast();

  @override
  Stream<bool> get isOnline async* {
    yield online;
    yield* _controller.stream;
  }

  void setOnline({required bool online}) {
    this.online = online;
    _controller.add(online);
  }

  void dispose() => _controller.close();
}
