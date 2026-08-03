import 'dart:async';

import 'audio_device_type.dart';
import 'audio_model.dart';
import 'audio_route_change_source.dart';
import 'audio_route_event.dart';
import 'output_route_selector_platform.dart';
import 'route_enforcement_result.dart';

/// Middleware that keeps the user's audio route choice alive across audio
/// session reconfigurations.
///
/// ## Why it exists
///
/// A call SDK (Twilio, WebRTC, CallKit …) reconfigures `AVAudioSession` /
/// `AudioManager` every time the call changes state — dialing → ringing →
/// connected — and again whenever it restarts its audio unit. `setCategory`
/// alone clears an active speaker override and the preferred input, so a route
/// the user picked while the call was connecting is dropped a second later and
/// audio falls back to the receiver.
///
/// This middleware records **every** user selection, in any call state, and
/// keeps it enforced:
///
/// * every user pick becomes the pending selection — a system-driven change
///   never overwrites it;
/// * a system change that drops the pending selection is undone, re-asserted
///   until it sticks, and then watched for a settle window, because an SDK
///   typically resets the route more than once around a single state change;
/// * transient drops are **not** reported to the app: `onAudioRouteChanged`
///   emits the *effective* route, so the UI keeps showing what the user picked
///   instead of flickering to receiver and back while the fight is going on.
///   The outcome arrives on [onEnforcement], and the unfiltered feed stays
///   available on `OutputRouteSelector.onAudioRouteEvent`.
///
/// ## Zero-setup
///
/// Nothing needs to call [start]: the guard starts itself when the app listens
/// to `OutputRouteSelector.onAudioRouteChanged`, and stops (dropping pending
/// state) when the last listener cancels. [start]/[stop] remain for apps that
/// want explicit control.
///
/// ## Microphone
///
/// The plugin does not own the microphone — the call SDK does — so the mute
/// intent can only be stored here ([setPendingMicrophoneMuted]) and applied by
/// the app itself ([consumePendingMicrophoneMuted]).
class OutputRouteMiddleware {
  /// Singleton instance.
  static final OutputRouteMiddleware instance = OutputRouteMiddleware._();

  OutputRouteMiddleware._();

  final OutputRouteSelector _selector = OutputRouteSelector.instance;

  StreamSubscription<AudioRouteEvent>? _subscription;
  Timer? _enforceTimer;

  late final StreamController<AudioModel?> _effectiveController =
      StreamController<AudioModel?>.broadcast(
        onListen: _ensureStarted,
        onCancel: _handleLastListenerGone,
      );

  final StreamController<RouteEnforcementResult> _enforcementController =
      StreamController<RouteEnforcementResult>.broadcast();

  AudioModel? _pendingRoute;
  AudioModel? _currentRoute;
  AudioModel? _lastEmitted;
  bool? _pendingMicrophoneMuted;
  RouteEnforcementResult? _lastEnforcementResult;

  bool _guardEnabled = true;
  bool _isApplying = false;
  bool _isEnforcing = false;

  /// Default verification delays used by [applyPendingSelection].
  static const List<Duration> defaultVerifyDelays = [
    Duration(milliseconds: 400),
    Duration(milliseconds: 1000),
    Duration(milliseconds: 2000),
  ];

  /// How long to wait after a system route change before undoing it.
  ///
  /// Long enough for the SDK to finish reconfiguring the session — re-applying
  /// mid-reconfiguration is simply overwritten again — short enough to stay
  /// inaudible.
  static const Duration driftReapplyDelay = Duration(milliseconds: 300);

  /// Gap between re-assert attempts while the pending route has not stuck yet.
  static const Duration reassertInterval = Duration(milliseconds: 300);

  /// How many times the pending route is re-asserted before giving up on a
  /// single drift.
  ///
  /// A call SDK usually resets the route two or three times around one state
  /// change (category change → session activate → audio unit start), so a
  /// couple of tries is not enough. The cap still exists so a device that is
  /// gone (AirPods switched off) or a route the OS refuses (receiver while
  /// headphones are plugged in) does not loop forever.
  static const int maxReassertAttempts = 8;

  /// After the route sticks, keep polling for this long: the SDK can reset it
  /// once more shortly after, and that late reset produces no route-change
  /// notification on some devices.
  static const Duration settleWindow = Duration(seconds: 4);

  /// Poll interval used inside [settleWindow].
  static const Duration settlePollInterval = Duration(milliseconds: 400);

  /// Hard stop for one enforce run, counted from its start.
  static const Duration maxEnforceDuration = Duration(seconds: 20);

  /// The route the app should display.
  ///
  /// Filtered on purpose: while a pending selection is being defended, the
  /// transient drops are swallowed, so the UI does not flicker. If the fight is
  /// lost for good, the real route is emitted — the UI must not keep lying.
  ///
  /// Listening to this stream starts the guard; cancelling the last
  /// subscription stops it and drops pending state.
  Stream<AudioModel?> get effectiveRoute => _effectiveController.stream;

  /// Outcome of each enforce run: what was targeted, what is actually active,
  /// whether it was kept, and how many attempts it took.
  Stream<RouteEnforcementResult> get onEnforcement =>
      _enforcementController.stream;

  /// The most recent [RouteEnforcementResult], if any run has finished.
  RouteEnforcementResult? get lastEnforcementResult => _lastEnforcementResult;

  /// The last route the user picked, kept across call state changes.
  AudioModel? get pendingRoute => _pendingRoute;

  /// The real route, unfiltered — what the native session reports.
  AudioModel? get currentRoute => _currentRoute;

  /// The mute state the user asked for, if any. `null` means "nothing pending".
  bool? get pendingMicrophoneMuted => _pendingMicrophoneMuted;

  /// `true` when a user selection is being kept alive.
  bool get hasPendingRoute => _pendingRoute != null;

  /// `true` while system changes that drop the pending selection are undone.
  bool get isGuarding => _guardEnabled && _subscription != null;

  /// `true` while the middleware is re-asserting the pending route.
  bool get isEnforcing => _isEnforcing;

  /// `true` when the pending selection differs from the real route.
  bool get isPendingRouteDropped {
    final pending = _pendingRoute;
    if (pending == null) {
      return false;
    }
    return !_isSameDevice(pending, _currentRoute);
  }

  /// Route changes with their source, unfiltered.
  Stream<AudioRouteEvent> get onAudioRouteEvent => _selector.onAudioRouteEvent;

  /// Starts tracking route changes. Called automatically when [effectiveRoute]
  /// gains its first listener; only needed explicitly when an app wants the
  /// guard running without listening to the stream.
  ///
  /// Does **not** clear pending state; call [clearPending] for that.
  void start({bool guard = true}) {
    _guardEnabled = guard;
    _subscription?.cancel();
    _subscription = _selector.onAudioRouteEvent.listen(_handleEvent);
  }

  /// Stops tracking route changes and drops all pending state. Called
  /// automatically when the last [effectiveRoute] listener cancels.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _enforceTimer?.cancel();
    _enforceTimer = null;
    clearPending();
    _currentRoute = null;
    _lastEmitted = null;
  }

  /// Turns automatic undo of system route changes on/off without dropping the
  /// pending selection or the event subscription.
  void setGuardEnabled(bool enabled) {
    _guardEnabled = enabled;
    if (!enabled) {
      _enforceTimer?.cancel();
      _enforceTimer = null;
    }
  }

  /// Records the mute state the user asked for while the call was not ready to
  /// accept it yet.
  void setPendingMicrophoneMuted(bool muted) {
    _pendingMicrophoneMuted = muted;
  }

  /// Returns the pending mute state and clears it, so it is applied once.
  bool? consumePendingMicrophoneMuted() {
    final muted = _pendingMicrophoneMuted;
    _pendingMicrophoneMuted = null;
    return muted;
  }

  /// Overrides the pending route by hand — for apps that switch the route
  /// themselves and want that choice defended too.
  void setPendingRoute(AudioModel route) {
    _pendingRoute = route;
  }

  /// Drops the pending route and microphone state.
  void clearPending() {
    _pendingRoute = null;
    _pendingMicrophoneMuted = null;
    _enforceTimer?.cancel();
    _enforceTimer = null;
  }

  /// Re-applies the pending user selection, then verifies it stuck.
  ///
  /// The guard already does this on its own; this is for apps that want to force
  /// it at a known reconfiguration point. Returns the device that is active when
  /// verification finishes, or `null` when there is nothing pending.
  Future<AudioModel?> applyPendingSelection({
    List<Duration> verifyDelays = defaultVerifyDelays,
  }) async {
    final pending = _pendingRoute;
    if (pending == null) {
      return null;
    }

    var applied = await _applyRoute(pending);

    for (final delay in verifyDelays) {
      await Future<void>.delayed(delay);

      // Pending may have been cleared (call ended) or replaced (user picked
      // another device) while waiting — never fight the newer intent.
      final current = _pendingRoute;
      if (current == null || !_isSameDevice(current, pending)) {
        return applied;
      }

      final active = await _readCurrentRoute();
      if (_isSameDevice(pending, active)) {
        continue;
      }

      applied = await _applyRoute(pending);
    }

    if (_guardEnabled && !_isEnforcing && _pendingRoute != null) {
      unawaited(_enforcePendingRoute());
    }

    return applied;
  }

  void _ensureStarted() {
    if (_subscription == null) {
      start(guard: _guardEnabled);
    }
  }

  void _handleLastListenerGone() {
    // The app stopped caring (call screen closed) — do not keep a stale pick
    // alive into the next call.
    stop();
  }

  Future<AudioModel?> _applyRoute(AudioModel route) async {
    _isApplying = true;
    try {
      final applied = await _selector.selectAudioOutput(
        title: route.title,
        deviceType: _switchableDeviceType(route.deviceType),
      );

      if (applied != null) {
        _currentRoute = applied;
      }

      return applied;
    } finally {
      _isApplying = false;
    }
  }

  /// Reads the live route from the native session instead of trusting the last
  /// event: some resets (SDK restarting its audio unit) produce no notification.
  Future<AudioModel?> _readCurrentRoute() async {
    final active = await _selector.getCurrentRoute();
    if (active != null) {
      _currentRoute = active;
    }
    return active;
  }

  void _handleEvent(AudioRouteEvent event) {
    final device = event.device;
    if (device != null) {
      _currentRoute = device;
    }

    switch (event.source) {
      // The user's own pick, in whatever call state it happened. This is the
      // intent to protect from here on — and the only thing the UI follows.
      case AudioRouteChangeSource.userSelection:
        if (device != null) {
          _pendingRoute = device;
          _enforceTimer?.cancel();
          _enforceTimer = null;
          _emitEffective(device);
          // Start watching right away: the reset that follows a pick made
          // mid-connection can arrive without a route notification.
          if (_guardEnabled && !_isEnforcing) {
            unawaited(_enforcePendingRoute());
          }
        }

      // Someone else moved the route: call SDK reconfiguring on a state change,
      // Control Center, device plugged/unplugged.
      case AudioRouteChangeSource.system:
      case AudioRouteChangeSource.initial:
        if (_pendingRoute == null) {
          // Nothing to defend — this IS the truth for the UI.
          _emitEffective(device);
        } else if (_isSameDevice(_pendingRoute, device)) {
          _emitEffective(device);
        }
        // Otherwise: a drop we are about to undo. Stay silent so the icon does
        // not flicker; the app hears about it via onEnforcement if it is lost.
        _scheduleEnforce();

      // Our own re-assert. Never surfaced as a change: the UI already shows this
      // route, that is the whole point of the re-assert.
      case AudioRouteChangeSource.pendingRestore:
        break;
    }
  }

  void _emitEffective(AudioModel? device) {
    if (_isSameDevice(_lastEmitted, device)) {
      return;
    }
    _lastEmitted = device;
    if (!_effectiveController.isClosed) {
      _effectiveController.add(device);
    }
  }

  /// Debounces the start of an enforce run: a single SDK state change fires
  /// several route notifications in a row, and re-applying between them is
  /// pointless.
  void _scheduleEnforce() {
    if (!_guardEnabled || _isApplying || _isEnforcing) {
      return;
    }

    final pending = _pendingRoute;
    if (pending == null || _isSameDevice(pending, _currentRoute)) {
      return;
    }

    _enforceTimer?.cancel();
    _enforceTimer = Timer(driftReapplyDelay, () {
      _enforceTimer = null;
      unawaited(_enforcePendingRoute());
    });
  }

  /// Re-asserts the pending route until it sticks, then watches it for
  /// [settleWindow] and re-asserts again if it is dropped inside that window.
  Future<void> _enforcePendingRoute() async {
    if (_isEnforcing) {
      return;
    }
    _isEnforcing = true;

    final elapsed = Stopwatch()..start();
    var attempts = 0;
    AudioModel? target;

    try {
      while (attempts < maxReassertAttempts &&
          elapsed.elapsed < maxEnforceDuration) {
        target = _pendingRoute;

        // Pending cleared (call ended) or replaced (newer user pick) — stop.
        if (target == null || !_guardEnabled) {
          return;
        }

        final active = await _readCurrentRoute();

        if (_isSameDevice(target, active)) {
          _reportEnforcement(target, active, attempts, gaveUp: false);

          // Stuck for now. Watch it: the next reset may arrive without a
          // notification, and giving up here is how the choice got lost.
          final dropped = await _watchForDrift(target);
          if (!dropped) {
            return;
          }
          // A drop after a successful stick is a new drift (next call state),
          // so it gets a full re-assert budget.
          attempts = 0;
          elapsed.reset();
          continue;
        }

        attempts++;
        await _applyRoute(target);
        await Future<void>.delayed(reassertInterval);
      }

      // Out of attempts or time. Tell the app, and let the UI show the truth:
      // silently displaying a route that is not active is worse than a change.
      final finalTarget = target ?? _pendingRoute;
      if (finalTarget != null) {
        final active = await _readCurrentRoute();
        _reportEnforcement(finalTarget, active, attempts, gaveUp: true);
        if (!_isSameDevice(finalTarget, active)) {
          _emitEffective(active);
        }
      }
    } finally {
      _isEnforcing = false;
    }
  }

  /// Polls the live route for [settleWindow].
  ///
  /// Returns `true` if the pending route was dropped during the window (caller
  /// should re-assert), `false` if it held or is no longer relevant.
  Future<bool> _watchForDrift(AudioModel target) async {
    final pollCount =
        settleWindow.inMicroseconds ~/ settlePollInterval.inMicroseconds;

    for (var poll = 0; poll < pollCount; poll++) {
      await Future<void>.delayed(settlePollInterval);

      final pending = _pendingRoute;
      if (pending == null ||
          !_guardEnabled ||
          !_isSameDevice(pending, target)) {
        return false;
      }

      final active = await _readCurrentRoute();
      if (!_isSameDevice(target, active)) {
        return true;
      }
    }

    return false;
  }

  void _reportEnforcement(
    AudioModel target,
    AudioModel? actual,
    int attempts, {
    required bool gaveUp,
  }) {
    final result = RouteEnforcementResult(
      target: target,
      actual: actual,
      succeeded: _isSameDevice(target, actual),
      attempts: attempts,
      gaveUp: gaveUp,
    );

    _lastEnforcementResult = result;
    if (!_enforcementController.isClosed) {
      _enforcementController.add(result);
    }
  }

  /// Native switching is driven by three strategies; AirPods are Bluetooth as
  /// far as the OS is concerned, the split exists only for icons/labels.
  String _switchableDeviceType(AudioDeviceType type) {
    return switch (type) {
      AudioDeviceType.speaker => 'speaker',
      AudioDeviceType.receiver => 'receiver',
      AudioDeviceType.wiredHeadset => 'wiredHeadset',
      AudioDeviceType.bluetooth || AudioDeviceType.airpods => 'bluetooth',
    };
  }

  bool _isSameDevice(AudioModel? a, AudioModel? b) {
    if (a == null || b == null) {
      return false;
    }

    // isActive is ignored on purpose — it is always true in events, and a
    // route is identified by what/where it is, not by that flag.
    return a.title == b.title && a.deviceType == b.deviceType;
  }
}
