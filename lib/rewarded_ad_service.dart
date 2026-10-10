/// Boundary for a future Android or Web rewarded-ad implementation.
/// No provider or reward button is installed in this version.
abstract interface class RewardedAdService {
  /// Returns a provider-verified receipt only after a completed view.
  Future<RewardedAdReceipt?> showAndVerify();
}

class RewardedAdReceipt {
  const RewardedAdReceipt({
    required this.provider,
    required this.transactionId,
  });
  final String provider;
  final String transactionId;
}

abstract interface class RewardedAdGrantService {
  /// Applies a verified transaction once; a duplicate receipt earns nothing.
  Future<bool> grantVerified(RewardedAdReceipt receipt);
}
