import 'package:letmeserve/src/request.dart';
import 'package:letmeserve/src/response.dart';

abstract class Middleware {
  Future<Request?> onRequest(
    Request request,
    void Function(Response response) abort,
  ) async {
    return request;
  }

  Future<Response> onResponse(Response response) async => response;
}
