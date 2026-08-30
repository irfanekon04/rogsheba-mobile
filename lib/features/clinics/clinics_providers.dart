import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/network/network_providers.dart';
import 'package:rogsheba_mobile/features/clinics/data/clinics_remote_data_source.dart';
import 'package:rogsheba_mobile/features/clinics/data/clinics_repository_impl.dart';
import 'package:rogsheba_mobile/features/clinics/data/dio_clinics_remote_data_source.dart';
import 'package:rogsheba_mobile/features/clinics/domain/clinics_repository.dart';
import 'package:rogsheba_mobile/features/clinics/domain/use_cases/fetch_nearby_clinics_use_case.dart';

final clinicsRemoteDataSourceProvider = Provider<ClinicsRemoteDataSource>(
  (ref) => DioClinicsRemoteDataSource(api: ref.watch(apiClientProvider)),
);

final clinicsRepositoryProvider = Provider<ClinicsRepository>(
  (ref) => ClinicsRepositoryImpl(
    remote: ref.watch(clinicsRemoteDataSourceProvider),
  ),
);

final fetchNearbyClinicsUseCaseProvider =
    Provider<FetchNearbyClinicsUseCase>(
  (ref) => FetchNearbyClinicsUseCase(
    repository: ref.watch(clinicsRepositoryProvider),
  ),
);
