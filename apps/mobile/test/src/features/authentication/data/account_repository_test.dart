import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saidly/src/exceptions/app_exception.dart';
import 'package:saidly/src/features/authentication/data/account_repository.dart';

class MockDio extends Mock implements Dio {}

final _request = RequestOptions(path: '/me');

Response<T> _response<T>(int status, T data) =>
    Response<T>(requestOptions: _request, statusCode: status, data: data);

DioException _failure(DioExceptionType type, {Response<dynamic>? response}) =>
    DioException(requestOptions: _request, type: type, response: response);

void main() {
  late MockDio dio;
  late AccountRepository repository;

  setUp(() {
    dio = MockDio();
    repository = AccountRepository(dio);
  });

  void givenServerAnswers(Response<Map<String, dynamic>> response) {
    when(() => dio.get<Map<String, dynamic>>('/me'))
        .thenAnswer((_) async => response);
  }

  void givenServerFails(DioException error) {
    when(() => dio.get<Map<String, dynamic>>('/me')).thenThrow(error);
  }

  group('on success', () {
    test('returns the userId the API read out of the token', () async {
      givenServerAnswers(_response(200, {'userId': 'TVzaerBktk'}));

      expect(await repository.myUserId(), 'TVzaerBktk');
    });
  });

  group('when the API refuses the token', () {
    test('a 401 is a session that ended, not a server fault', () async {
      // The interceptor has already refreshed and retried by the time this
      // arrives, so a 401 here means the token is genuinely no good.
      givenServerFails(
        _failure(
          DioExceptionType.badResponse,
          response: _response<dynamic>(401, {
            'error': {'code': 'unauthorized'},
          }),
        ),
      );

      await expectLater(
        repository.myUserId(),
        throwsA(const SessionExpiredException()),
      );
    });
  });

  group('when the phone cannot reach the API', () {
    test('a connection error reads as no connection', () async {
      givenServerFails(_failure(DioExceptionType.connectionError));

      await expectLater(
        repository.myUserId(),
        throwsA(const NetworkException()),
      );
    });

    test('so does a timeout', () async {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      ]) {
        givenServerFails(_failure(type));

        await expectLater(
          repository.myUserId(),
          throwsA(const NetworkException()),
          reason: '$type should read as no connection',
        );
      }
    });
  });

  group('when the API is broken', () {
    test('keeps the API error code for the log', () async {
      givenServerFails(
        _failure(
          DioExceptionType.badResponse,
          response: _response<dynamic>(500, {
            'error': {'code': 'internal_error'},
          }),
        ),
      );

      await expectLater(
        repository.myUserId(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'internal_error')
              .having((e) => e.message, 'message', isNot(contains('internal'))),
        ),
      );
    });

    test('survives a response with no error code at all', () async {
      givenServerFails(
        _failure(
          DioExceptionType.badResponse,
          response: _response<dynamic>(502, 'Bad Gateway'),
        ),
      );

      await expectLater(repository.myUserId(), throwsA(isA<ApiException>()));
    });

    test('a 200 without a userId is not a success', () async {
      // The API is as untrusted as the model is: a body that does not have
      // what it promised must not become an empty string on screen.
      givenServerAnswers(_response(200, <String, dynamic>{}));

      await expectLater(repository.myUserId(), throwsA(isA<ApiException>()));
    });
  });

  test('a DioException never escapes the repository', () async {
    givenServerFails(_failure(DioExceptionType.unknown));

    await expectLater(
      repository.myUserId(),
      throwsA(isNot(isA<DioException>())),
    );
  });
}
