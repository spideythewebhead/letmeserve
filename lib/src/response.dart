import 'package:letmeserve/src/request.dart';

class Response {
  final int statusCode;
  final Map<String, String> headers;
  final dynamic data;
  final Request? request;

  Response({
    required this.statusCode,
    this.request,
    this.data,
    Map<String, String>? headers,
  }) : headers = {...?headers};

  Response copyWith({
    required Request request,
  }) {
    return Response(
      statusCode: statusCode,
      headers: headers,
      data: data,
      request: request,
    );
  }
}
