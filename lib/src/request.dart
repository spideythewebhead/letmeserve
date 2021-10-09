import 'package:letmeserve/src/typedefs.dart';

class Request {
  final String method;
  final Map<String, String> headers;
  final dynamic body;
  final Params params;
  final QueryParams queryParams;
  final Uri uri;

  Request({
    required this.method,
    required this.headers,
    required this.params,
    required this.queryParams,
    required this.uri,
    this.body,
  });
}
