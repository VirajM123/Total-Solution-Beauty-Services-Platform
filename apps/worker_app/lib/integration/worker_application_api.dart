import '../features/home/worker_profile_data.dart';
import 'worker_api.dart';

/// Private upload handles must come from an authenticated upload service.
/// Local file paths and public URLs are never accepted as document authority.
class WorkerApplicationInput {
  WorkerApplicationInput({
    required this.profile,
    required List<String> serviceIds,
    required List<String> serviceAreaIds,
    required this.privateIdentityUploadId,
  }) : serviceIds = List.unmodifiable(serviceIds),
       serviceAreaIds = List.unmodifiable(serviceAreaIds);
  final WorkerProfile profile;
  final List<String> serviceIds;
  final List<String> serviceAreaIds;
  final String privateIdentityUploadId;
}

abstract interface class WorkerApplicationApi {
  Future<WorkerIdentity> submit(
    WorkerApplicationInput application, {
    required String idempotencyKey,
  });
}

class PendingWorkerApplicationApi implements WorkerApplicationApi {
  const PendingWorkerApplicationApi();
  @override
  Future<WorkerIdentity> submit(
    WorkerApplicationInput application, {
    required String idempotencyKey,
  }) => Future.error(
    const WorkerIntegrationPending('Worker registration and private upload'),
  );
}
