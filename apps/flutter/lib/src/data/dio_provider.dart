import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/authentication/data/auth_repository.dart';

/// Where the Saidly API lives.
///
/// Overridable at build time so a development run can point at a local
/// server without editing this file:
///
///   flutter run --dart-define=SAIDLY_API_URL=http://localhost:3000
///
/// The default is the deployed API, so a fresh clone works with no flags.
const apiBaseUrl = String.fromEnvironment(
  'SAIDLY_API_URL',
  defaultValue: 'https://divine-magic-production-a0d3.up.railway.app',
);

/// Attaches the Firebase ID token, and gets a fresh one when the API says the
/// current one is no good.
///
/// Lives here rather than in each repository because every call needs it and
/// forgetting it once produces a 401 that looks like a server problem.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.authRepository, required this.dio});

  final AuthRepository authRepository;

  /// The same Dio this interceptor is installed on, needed to replay a
  /// request after refreshing. Passing it in is the only way: the instance
  /// does not exist yet when the interceptor is constructed.
  final Dio dio;

  static const _retriedKey = 'saidly.retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // A retry already carries the freshly refreshed token. Asking again here
    // would overwrite it with the cached, rejected one — `dio.fetch` replays
    // the whole interceptor chain, so this method runs a second time.
    if (options.extra[_retriedKey] == true) {
      return handler.next(options);
    }

    final token = await authRepository.idToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    // No header at all when signed out, rather than "Bearer null". The API
    // answers 401 either way, but a malformed header is the kind of detail
    // that costs an evening to find.
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isAuthFailure = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;

    // Only a 401 is about the token. Retrying a 500 would double the load on
    // a server that is already unwell.
    if (!isAuthFailure || alreadyRetried) {
      return handler.next(err);
    }

    // Firebase caches the token for an hour, so a plain read would hand back
    // the same rejected string. This is the only caller that forces a refresh.
    final token = await authRepository.idToken(forceRefresh: true);
    if (token == null) {
      // Nobody is signed in. There is nothing to retry with, and the router's
      // guard is already on its way to the sign-in screen.
      return handler.next(err);
    }

    final options = err.requestOptions
      ..headers['Authorization'] = 'Bearer $token'
      ..extra[_retriedKey] = true;

    try {
      handler.resolve(await dio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      // A second 401 means the token was never the problem.
      handler.next(retryError);
    }
  }
}

/// Builds the configured Dio.
///
/// Separate from the provider so a test can build one without a
/// ProviderContainer and swap in a fake HTTP adapter.
Dio createDio(AuthRepository authRepository) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      // Without these, a request to an unreachable server waits on the OS
      // default — minutes — and the user sees a spinner that never stops.
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
    ),
  );
  dio.interceptors.add(
    AuthInterceptor(authRepository: authRepository, dio: dio),
  );
  return dio;
}

/// The one Dio instance. Only repositories are allowed to read it.
final dioProvider = Provider<Dio>(
  (ref) => createDio(ref.watch(authRepositoryProvider)),
);
