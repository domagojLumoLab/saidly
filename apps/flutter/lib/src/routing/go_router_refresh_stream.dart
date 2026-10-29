import 'dart:async';

import 'package:flutter/foundation.dart';

/// Turns a `Stream` into the `Listenable` that `GoRouter.refreshListenable`
/// wants.
///
/// The auth guard lives in `redirect`, and go_router only re-runs `redirect`
/// when it is told something changed. Without this, signing out would leave
/// the user sitting on a screen they are no longer allowed to see until they
/// navigated by hand.
///
/// It ignores the events themselves — `redirect` re-reads the current user
/// when it runs, so the stream is a bell, not a message.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<Object?> stream) {
    // Listening directly, NOT through asBroadcastStream(). The broadcast
    // wrapper subscribes to the source and stays subscribed after its last
    // listener leaves, so cancelling below would not reach firebase_auth and
    // the subscription would outlive the router. Measured: with the wrapper,
    // the source controller still reports hasListener after dispose.
    //
    // Nothing else listens to this stream — the repository hands out a fresh
    // mapped stream per call — so one direct listener is all that is needed.
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    // Without this the subscription outlives the router and calls
    // notifyListeners() on a disposed ChangeNotifier, which throws.
    _subscription.cancel();
    super.dispose();
  }
}
