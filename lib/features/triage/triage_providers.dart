import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/network/network_providers.dart';
import 'package:rogsheba_mobile/core/services/cache_service.dart';
import 'package:rogsheba_mobile/features/triage/data/dio_triage_remote_data_source.dart';
import 'package:rogsheba_mobile/features/triage/data/shared_preferences_triage_local_data_source.dart';
import 'package:rogsheba_mobile/features/triage/data/triage_local_data_source.dart';
import 'package:rogsheba_mobile/features/triage/data/triage_remote_data_source.dart';
import 'package:rogsheba_mobile/features/triage/data/triage_repository_impl.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_repository.dart';
import 'package:rogsheba_mobile/features/triage/domain/use_cases/submit_follow_up_use_case.dart';
import 'package:rogsheba_mobile/features/triage/domain/use_cases/submit_symptoms_use_case.dart';

// ---------------------------------------------------------------------------
// Data sources
// ---------------------------------------------------------------------------

final triageRemoteDataSourceProvider = Provider<TriageRemoteDataSource>(
  (ref) => DioTriageRemoteDataSource(api: ref.watch(apiClientProvider)),
);

final triageLocalDataSourceProvider = FutureProvider<TriageLocalDataSource>(
  (ref) async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return SharedPreferencesTriageLocalDataSource(prefs: prefs);
  },
);

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

final triageRepositoryProvider = FutureProvider<TriageRepository>(
  (ref) async {
    final remote = ref.watch(triageRemoteDataSourceProvider);
    final local = await ref.watch(triageLocalDataSourceProvider.future);
    return TriageRepositoryImpl(remote: remote, local: local);
  },
);

// ---------------------------------------------------------------------------
// Use cases
// ---------------------------------------------------------------------------

final submitSymptomsUseCaseProvider = FutureProvider<SubmitSymptomsUseCase>(
  (ref) async {
    final repo = await ref.watch(triageRepositoryProvider.future);
    return SubmitSymptomsUseCase(repository: repo);
  },
);

final submitFollowUpUseCaseProvider = FutureProvider<SubmitFollowUpUseCase>(
  (ref) async {
    final repo = await ref.watch(triageRepositoryProvider.future);
    return SubmitFollowUpUseCase(repository: repo);
  },
);
