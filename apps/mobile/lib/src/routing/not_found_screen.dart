import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/string_hardcoded.dart';
import 'app_route.dart';

/// Shown by the router's `errorBuilder` when a location matches no route.
///
/// In practice this is reached by a stale deep link or a notification tapped
/// after the task it pointed at was deleted — so it offers a way out rather
/// than only stating the problem. It deliberately does not print the path the
/// user asked for: that is a developer's detail, and it would be the only
/// place in the app where a URL appears on screen.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "That page doesn't exist.".hardcoded,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.goNamed(AppRoute.home.name),
                child: Text('Go home'.hardcoded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
