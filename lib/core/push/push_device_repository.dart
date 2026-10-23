abstract interface class PushDeviceRepository {
  Future<void> register({
    required String installationId,
    required String token,
  });

  Future<void> remove(String installationId);
}
