import 'audio_model.dart';

/// Outcome of one attempt to keep the user's route choice.
///
/// Emitted on `OutputRouteMiddleware.onEnforcement` so the app can observe what
/// the middleware did without having to watch every transient route change.
class RouteEnforcementResult {
  /// The route the user picked and the middleware tried to hold.
  final AudioModel target;

  /// The route that is actually active when the run finished.
  final AudioModel? actual;

  /// `true` when [actual] is [target] — the choice was kept.
  final bool succeeded;

  /// How many re-assert attempts the run needed.
  final int attempts;

  /// `true` when the run stopped because it ran out of attempts or time, rather
  /// than because the route settled. A `false` [succeeded] with this set means
  /// the device is likely gone or the OS refuses the route.
  final bool gaveUp;

  const RouteEnforcementResult({
    required this.target,
    required this.actual,
    required this.succeeded,
    required this.attempts,
    required this.gaveUp,
  });

  @override
  String toString() =>
      'RouteEnforcementResult(target: ${target.title}, actual: ${actual?.title}, '
      'succeeded: $succeeded, attempts: $attempts, gaveUp: $gaveUp)';
}
