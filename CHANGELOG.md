## [2.1.3] - 2026-08-03

### Changed
- **Zero app setup.** The guard starts itself when the app listens to `onAudioRouteChanged`, and stops (dropping pending state) when the last listener cancels. No `start()` / `stop()` / `applyPendingSelection()` calls needed — the whole fix now lives in the plugin.
- **`onAudioRouteChanged` is now the *effective* route.** While a user pick is being defended, transient drops caused by a call SDK reconfiguring the audio session are no longer emitted, so the UI does not flicker to receiver and back. Our own re-asserts are never emitted either. If the pick cannot be held, the real route is emitted so the UI stops lying.

### Added
- `onEnforcement` / `lastEnforcementResult`: `RouteEnforcementResult(target, actual, succeeded, attempts, gaveUp)` for each enforce run — the result feed for apps that want to know what happened.
- `rawAudioRouteChanged`: the previous unfiltered `onAudioRouteChanged` behaviour, for debugging.

