import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'package:rogsheba_mobile/core/services/cache_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// The permission states the UI cares about, narrowed from
/// `permission_handler`'s platform statuses. `notDetermined` is the "never
/// asked the OS yet" state — the OS maps it to `denied` internally, so the
/// rationale gate uses a persisted "already asked" flag to tell it apart from
/// a real denial (see [PermissionRationaleStore]).
enum PermissionState {
  granted,
  denied,
  deniedForever,
  notDetermined,
  restricted,
}

/// Seam for permission checks and the post-denial route to system settings.
/// UI and tests depend only on this contract, never on `permission_handler`
/// directly.
abstract interface class PermissionService {
  Future<PermissionState> microphoneStatus();
  Future<PermissionState> locationStatus();
  Future<bool> openAppSettings();
}

/// Real implementation backed by `permission_handler`.
class PluginPermissionService implements PermissionService {
  static PermissionState _map(ph.PermissionStatus status) {
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return PermissionState.granted;
    }
    if (status.isPermanentlyDenied) return PermissionState.deniedForever;
    if (status.isRestricted) return PermissionState.restricted;
    return PermissionState.denied;
  }

  @override
  Future<PermissionState> microphoneStatus() async =>
      _map(await ph.Permission.microphone.status);

  @override
  Future<PermissionState> locationStatus() async =>
      _map(await ph.Permission.locationWhenInUse.status);

  @override
  Future<bool> openAppSettings() => ph.openAppSettings();
}

/// Composition root. Tests override this with a hand-written fake.
final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PluginPermissionService(),
);

/// Remembers that the rationale for a permission was accepted, so the
/// rationale dialog is shown exactly once — before the first system prompt —
/// and never again after that.
///
/// This is what lets the UI distinguish "never asked the OS yet" from "the
/// user denied it": [PermissionState.denied] can mean either on some
/// platforms, but a persisted acceptance flag tells them apart.
class PermissionRationaleStore {
  const PermissionRationaleStore({required this.prefs});

  final SharedPreferences prefs;

  static const micKey = 'permission_rationale.mic';
  static const locationKey = 'permission_rationale.location';

  Future<bool> micAccepted() async => prefs.getBool(micKey) ?? false;

  Future<void> markMicAccepted() async => prefs.setBool(micKey, true);

  Future<bool> locationAccepted() async => prefs.getBool(locationKey) ?? false;

  Future<void> markLocationAccepted() async => prefs.setBool(locationKey, true);
}

/// Composition root. Reads the same SharedPreferences store the cache uses,
/// so a fresh install starts with neither rationale accepted.
final permissionRationaleStoreProvider =
    FutureProvider<PermissionRationaleStore>((ref) async {
      final prefs = await ref.watch(sharedPreferencesProvider.future);
      return PermissionRationaleStore(prefs: prefs);
    });
