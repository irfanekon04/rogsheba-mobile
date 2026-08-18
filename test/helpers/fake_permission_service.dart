import 'package:rogsheba_mobile/core/services/permission_service.dart';

/// Hand-written fake for widget tests: `permission_handler` crosses platform
/// channels and cannot run under `flutter_test`.
///
/// Defaults to granting both permissions so existing tests that merely render
/// screens keep working; tests exercising the rationale/settings flows set the
/// statuses they need and inspect [settingsCalls].
class FakePermissionService implements PermissionService {
  FakePermissionService({
    this.microphone = PermissionState.granted,
    this.location = PermissionState.granted,
  });

  PermissionState microphone;
  PermissionState location;

  /// Number of times [openAppSettings] was invoked.
  int settingsCalls = 0;

  @override
  Future<PermissionState> microphoneStatus() async => microphone;

  @override
  Future<PermissionState> locationStatus() async => location;

  @override
  Future<bool> openAppSettings() async {
    settingsCalls++;
    return true;
  }
}
