import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saidly/src/data/dio_provider.dart';
import 'package:saidly/src/features/authentication/data/auth_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// Answers with a scripted list of status codes and records what it was sent,
/// so the tests never touch the network.
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.statuses);

  final List<int> statuses;

  /// The Authorization header as it was AT THE MOMENT of the call.
  ///
  /// Not the RequestOptions object: the interceptor mutates it in place when
  /// it retries, so holding a reference would show the retry's header on the
  /// first call too — and the test would be reading the future.
  final List<String?> sentAuth = [];
  int _call = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sentAuth.add(options.headers['Authorization'] as String?);
    final status = statuses[_call.clamp(0, statuses.length - 1)];
    _call++;
    return ResponseBody.fromString(
      jsonEncode({'userId': 'abc123'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  String? authOf(int call) => sentAuth[call];
  int get calls => sentAuth.length;
}

void main() {
  late MockAuthRepository auth;

  setUp(() => auth = MockAuthRepository());

  /// Builds the same Dio the provider builds, without a ProviderContainer.
  (Dio, ScriptedAdapter) buildDio(List<int> statuses) {
    final dio = createDio(auth);
    final adapter = ScriptedAdapter(statuses);
    dio.httpClientAdapter = adapter;
    return (dio, adapter);
  }

  group('the token', () {
    test('rides along as a Bearer header', () async {
      when(() => auth.idToken()).thenAnswer((_) async => 'jwt-1');
      final (dio, adapter) = buildDio([200]);

      await dio.get<dynamic>('/me');

      expect(adapter.authOf(0), 'Bearer jwt-1');
    });

    test('is asked for without forcing a refresh', () async {
      // Firebase caches for an hour. Forcing a refresh on every request would
      // turn one API call into two network round trips.
      when(() => auth.idToken()).thenAnswer((_) async => 'jwt-1');
      final (dio, _) = buildDio([200]);

      await dio.get<dynamic>('/me');

      verify(() => auth.idToken()).called(1);
      verifyNever(() => auth.idToken(forceRefresh: true));
    });

    test('is simply absent when nobody is signed in', () async {
      // No header rather than "Bearer null". The API answers 401 either way,
      // but a malformed header is the kind of thing that wastes an evening.
      when(() => auth.idToken()).thenAnswer((_) async => null);
      final (dio, adapter) = buildDio([200]);

      await dio.get<dynamic>('/me');

      expect(adapter.authOf(0), isNull);
    });
  });

  group('on 401', () {
    test('refreshes once and retries with the new token', () async {
      when(() => auth.idToken()).thenAnswer((_) async => 'stale');
      when(() => auth.idToken(forceRefresh: true))
          .thenAnswer((_) async => 'fresh');
      final (dio, adapter) = buildDio([401, 200]);

      final response = await dio.get<dynamic>('/me');

      expect(response.statusCode, 200);
      expect(adapter.calls, 2);
      expect(adapter.authOf(0), 'Bearer stale');
      expect(adapter.authOf(1), 'Bearer fresh');
    });

    test('gives up after the second 401', () async {
      // A second rejection means the token is not the problem. Retrying again
      // would loop against a server that has already said no twice.
      when(() => auth.idToken()).thenAnswer((_) async => 'stale');
      when(() => auth.idToken(forceRefresh: true))
          .thenAnswer((_) async => 'fresh');
      final (dio, adapter) = buildDio([401, 401]);

      await expectLater(
        dio.get<dynamic>('/me'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            401,
          ),
        ),
      );
      expect(adapter.calls, 2);
    });

    test('does not retry when there is no user to refresh for', () async {
      when(() => auth.idToken()).thenAnswer((_) async => null);
      when(() => auth.idToken(forceRefresh: true))
          .thenAnswer((_) async => null);
      final (dio, adapter) = buildDio([401]);

      await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));
      expect(adapter.calls, 1);
    });
  });

  group('other failures', () {
    test('a 500 is not retried — it is not about the token', () async {
      when(() => auth.idToken()).thenAnswer((_) async => 'jwt-1');
      final (dio, adapter) = buildDio([500]);

      await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));

      expect(adapter.calls, 1);
      verifyNever(() => auth.idToken(forceRefresh: true));
    });
  });

  group('configuration', () {
    test('points at the API and gives up rather than hanging', () async {
      final dio = createDio(auth);

      expect(dio.options.baseUrl, isNotEmpty);
      expect(dio.options.connectTimeout, isNotNull);
      expect(dio.options.receiveTimeout, isNotNull);
    });
  });
}
