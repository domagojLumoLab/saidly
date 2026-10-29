import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/dio_provider.dart';
import '../../../exceptions/app_exception.dart';

/// What the Saidly API knows about whoever is holding the token.
///
/// The only file that calls `GET /me`, and the only one that turns a
/// `DioException` into something a screen can show. Nothing above `data/`
/// imports Dio.
class AccountRepository {
  const AccountRepository(this._dio);

  final Dio _dio;

  /// The userId the API read out of the verified ID token.
  ///
  /// This is the acceptance test for spec 006: it must equal the uid
  /// firebase_auth gave the app locally. If the two agree, the token was
  /// issued by Firebase, attached by the interceptor, verified by `jose`
  /// against Google's JWKS, and its `sub` became a user — all of it.
  Future<String> myUserId() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/me');
      final userId = response.data?['userId'];

      // The API is untrusted input too. A body missing what it promised must
      // not quietly become an empty string on screen.
      if (userId is! String || userId.isEmpty) {
        throw const ApiException('invalid_response');
      }
      return userId;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  AppException _translate(DioException e) {
    // Nothing reached the server, or nothing came back in time. From the
    // user's side these are the same event: no connection.
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const NetworkException();
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      // Not a network failure: it fires while decoding a response that did
      // arrive. Telling the user to check their connection would send them
      // looking in the wrong place.
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        break;
    }

    if (e.response?.statusCode == 401) {
      // The interceptor already refreshed the token and was refused again, so
      // this is not a stale token — the session is over.
      return const SessionExpiredException();
    }

    // The API's own code when it sent one; otherwise the status, so a log can
    // still say what happened.
    final body = e.response?.data;
    final code = body is Map && body['error'] is Map
        ? body['error']['code']
        : null;
    return ApiException(
      code is String ? code : 'http_${e.response?.statusCode ?? 'unreachable'}',
    );
  }
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(dioProvider)),
);

/// What the account screen watches to show the server's answer beside the
/// local uid.
final myUserIdProvider = FutureProvider<String>(
  (ref) => ref.watch(accountRepositoryProvider).myUserId(),
);
