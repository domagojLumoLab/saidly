import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saidly/src/routing/go_router_refresh_stream.dart';

void main() {
  late StreamController<String> controller;
  late GoRouterRefreshStream refresh;
  late int notifications;

  setUp(() {
    controller = StreamController<String>();
    refresh = GoRouterRefreshStream(controller.stream);
    notifications = 0;
    refresh.addListener(() => notifications++);
  });

  tearDown(() async {
    await controller.close();
  });

  test('notifies once per event', () async {
    controller
      ..add('signed in')
      ..add('signed out');
    await pumpEventQueue();

    expect(notifications, 2);
  });

  test('a listener added after construction gets nothing until an event', () async {
    // Worth pinning down because go_router's own sample calls notifyListeners()
    // in the constructor. At that moment nobody is listening yet, so the call
    // cannot reach anyone — it is dead code, and this app does not copy it.
    await pumpEventQueue();

    expect(notifications, 0);
  });

  test('stops listening to the source once disposed', () async {
    expect(controller.hasListener, isTrue);

    refresh.dispose();

    expect(controller.hasListener, isFalse);
  });

  test('an event after dispose notifies nobody', () async {
    refresh.dispose();
    controller.add('too late');
    await pumpEventQueue();

    expect(notifications, 0);
  });

  test('accepts a single-subscription stream', () async {
    // firebase_auth's authStateChanges() is broadcast today, but a repository
    // is free to return a plain stream. A single direct listener works on
    // either kind, which is why no asBroadcastStream() is needed.
    final single = StreamController<String>();
    addTearDown(single.close);
    expect(single.stream.isBroadcast, isFalse, reason: 'precondition');

    final listenable = GoRouterRefreshStream(single.stream);
    addTearDown(listenable.dispose);
    var count = 0;
    listenable.addListener(() => count++);

    single.add('one');
    await pumpEventQueue();

    expect(count, 1);
  });
}
