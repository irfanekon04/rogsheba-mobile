import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reports whether the device currently has a usable network connection, as a
/// stream so the offline banner can appear and disappear live.
///
/// `connectivity_plus` distinguishes "no connection" from "some interface",
/// which is the signal the offline slice needs: `none` means the user cannot
/// reach the API at all.
abstract interface class ConnectivityService {
  /// Emits `true` while a network interface exists, `false` when none do.
  Stream<bool> get isOnline;
}

class PluginConnectivityService implements ConnectivityService {
  @override
  Stream<bool> get isOnline async* {
    // Emit the current state first so the banner resolves immediately instead
    // of waiting for the first change event, then follow live changes.
    final current = await Connectivity().checkConnectivity();
    yield current.any((r) => r != ConnectivityResult.none);
    yield* Connectivity()
        .onConnectivityChanged
        .map((results) => results.any((r) => r != ConnectivityResult.none));
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => PluginConnectivityService(),
);

/// App-wide online/offline state. `null` only for the first instant before the
/// plugin's stream emits, which callers treat as "online" so a cold start
/// never flashes a banner.
final isOnlineProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).isOnline;
});
