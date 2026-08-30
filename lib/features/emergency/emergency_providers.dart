import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/network/network_providers.dart';
import 'package:rogsheba_mobile/core/services/cache_service.dart';
import 'package:rogsheba_mobile/features/emergency/data/dio_emergency_remote_data_source.dart';
import 'package:rogsheba_mobile/features/emergency/data/emergency_local_data_source.dart';
import 'package:rogsheba_mobile/features/emergency/data/emergency_remote_data_source.dart';
import 'package:rogsheba_mobile/features/emergency/data/emergency_repository_impl.dart';
import 'package:rogsheba_mobile/features/emergency/data/shared_preferences_emergency_local_data_source.dart';
import 'package:rogsheba_mobile/features/emergency/domain/emergency_repository.dart';
import 'package:rogsheba_mobile/features/emergency/domain/use_cases/fetch_emergency_contacts_use_case.dart';

final emergencyRemoteDataSourceProvider =
    Provider<EmergencyRemoteDataSource>(
  (ref) => DioEmergencyRemoteDataSource(api: ref.watch(apiClientProvider)),
);

final emergencyLocalDataSourceProvider =
    FutureProvider<EmergencyLocalDataSource>(
  (ref) async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return SharedPreferencesEmergencyLocalDataSource(prefs: prefs);
  },
);

final emergencyRepositoryProvider = FutureProvider<EmergencyRepository>(
  (ref) async {
    final remote = ref.watch(emergencyRemoteDataSourceProvider);
    final local = await ref.watch(emergencyLocalDataSourceProvider.future);
    return EmergencyRepositoryImpl(remote: remote, local: local);
  },
);

final fetchEmergencyContactsUseCaseProvider =
    FutureProvider<FetchEmergencyContactsUseCase>(
  (ref) async {
    final repo = await ref.watch(emergencyRepositoryProvider.future);
    return FetchEmergencyContactsUseCase(repository: repo);
  },
);
