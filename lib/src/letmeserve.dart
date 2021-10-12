import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';
import 'dart:typed_data';

import 'package:letmeserve/src/annotations/middleware.dart';
import 'package:letmeserve/src/annotations/route.dart';
import 'package:letmeserve/src/common_responses.dart' as common_responses;
import 'package:letmeserve/src/middleware.dart';
import 'package:letmeserve/src/request.dart';
import 'package:letmeserve/src/response.dart';
import 'package:letmeserve/src/router.dart';
import 'package:letmeserve/src/typedefs.dart';

class LetMeServe {
  final String host;
  final int port;

  final _routers = <Router>[];

  final _cacheRouters = <Type, ClassMirror>{};

  final _cacheMiddlewares = <Type, Middleware>{};

  late HttpServer _server;
  StreamSubscription? _serverSubscription;

  LetMeServe({
    required this.host,
    required this.port,
  });

  void addRouter(Router router) {
    _routers.add(router);
  }

  Future<void> listen(VoidCallback? onReady) async {
    _server = await HttpServer.bind(host, port);

    _serverSubscription = _server.listen(_handleRequest);

    onReady?.call();
  }

  Future<void> close({bool force = false}) async {
    await _serverSubscription?.cancel();
    await _server.close(force: force);
  }

  void _handleRequest(HttpRequest request) async {
    final chunks = <Uint8List>[];

    request.listen((chunk) {
      chunks.add(chunk);
    }, onDone: () async {
      Router? matchRouter;
      _RouterMethod? methodWrapper;
      late ClassMirror routerClazz;

      for (final router in _routers) {
        if (request.uri.path.startsWith(router.prefix)) {
          final routerType = router.runtimeType;

          if (!_cacheRouters.containsKey(routerType)) {
            _cacheRouters[routerType] = reflectClass(routerType);
          }

          routerClazz = _cacheRouters[routerType]!;

          methodWrapper = _findRouterMethod(
            method: request.method,
            path: request.uri.path,
            prefix: router.prefix,
            clazz: routerClazz,
          );

          if (methodWrapper != null) {
            matchRouter = router;
            break;
          }
        }
      }

      if (matchRouter == null || methodWrapper == null) {
        return common_responses.response404(request.response);
      } else if (!_isFutureResponseSignature(methodWrapper.method.returnType.reflectedType)) {
        return common_responses.response500(request.response);
      }

      dynamic body;

      if (request.method != 'GET' && request.headers.contentLength > 0) {
        body = _getBody(request.headers.contentType?.value ?? '', chunks);
      }

      final params = _extractParams(request.uri.path, matchRouter.prefix + methodWrapper.route.path);
      final queryParams = request.uri.queryParameters;

      var appRequest = _toApplicationRequest(
        request,
        params: params,
        queryParams: queryParams,
        body: body,
      );

      try {
        appRequest = await _callOnRequestMiddlewares(routerClazz, methodWrapper.method, appRequest);
      } on Response catch (response) {
        return await _fromApplicationResponse(request.response, response).close();
      } catch (e) {
        return await common_responses.response500(request.response);
      }

      try {
        Response appResponse =
            await reflect(matchRouter).invoke(methodWrapper.method.simpleName, [appRequest]).reflectee;
        appResponse = appResponse.copyWith(request: appRequest);

        appResponse = await _callOnResponseMiddlewares(routerClazz, methodWrapper.method, appResponse);

        await _fromApplicationResponse(request.response, appResponse).close();
      } on Response catch (response) {
        return await _fromApplicationResponse(request.response, response).close();
      } catch (e) {
        return await common_responses.response500(request.response);
      }
    });
  }

  bool _isFutureResponseSignature(Type type) {
    return type.toString().startsWith('Future<Response');
  }

  _RouterMethod? _findRouterMethod({
    required String method,
    required String path,
    required String prefix,
    required ClassMirror clazz,
  }) {
    for (final pair in clazz.declarations.entries) {
      if (pair.value.metadata.isNotEmpty) {
        for (final meta in pair.value.metadata) {
          if (meta.reflectee is Route) {
            final route = meta.reflectee as Route;

            if (route.method == method) {
              /// checks if path is fully matched

              final routeParts = (prefix + route.path).split('/');
              final pathParts = path.split('/');

              if (routeParts.length != pathParts.length) {
                continue;
              }

              var skip = false;
              for (var p = 0; p < routeParts.length; ++p) {
                if (routeParts[p].isEmpty) continue;

                if (routeParts[p][0] == ':') {
                  if (pathParts[p].isEmpty) {
                    skip = true;
                    break;
                  }
                } else if (routeParts[p] != pathParts[p]) {
                  skip = true;
                  break;
                }
              }

              if (skip) {
                continue;
              }

              return _RouterMethod(
                route: route,
                method: pair.value as MethodMirror,
              );
            }
          }
        }
      }
    }

    return null;
  }

  Future<Request> _callOnRequestMiddlewares(
    ClassMirror clazz,
    MethodMirror method,
    Request request,
  ) async {
    void onAbort(Response response) {
      throw response;
    }

    Future<void> onFoundMiddleware(Type middleware) async {
      if (_cacheMiddlewares[middleware] == null) {
        ClassMirror middlewareClazz = reflectClass(middleware);
        _cacheMiddlewares[middleware] = middlewareClazz.newInstance(Symbol.empty, const []).reflectee;
      }

      final chainRequest = await _cacheMiddlewares[middleware]!.onRequest(request, onAbort);
      request = chainRequest!;
    }

    for (final meta in clazz.metadata) {
      if (meta.reflectee is AddMiddleware) {
        try {
          await onFoundMiddleware((meta.reflectee as AddMiddleware).middleware);
        } on Response {
          rethrow;
        }
      }
    }

    for (final meta in method.metadata) {
      if (meta.reflectee is AddMiddleware) {
        try {
          await onFoundMiddleware((meta.reflectee as AddMiddleware).middleware);
        } catch (e) {
          rethrow;
        }
      }
    }

    return request;
  }

  Future<Response> _callOnResponseMiddlewares(
    ClassMirror clazz,
    MethodMirror method,
    Response response,
  ) async {
    Future<void> onFoundMiddleware(Type middleware) async {
      if (_cacheMiddlewares[middleware] == null) {
        ClassMirror middlewareClazz = reflectClass(middleware);
        _cacheMiddlewares[middleware] = middlewareClazz.newInstance(Symbol.empty, const []).reflectee;
      }

      response = await _cacheMiddlewares[middleware]!.onResponse(response);
    }

    for (final meta in clazz.metadata) {
      if (meta.reflectee is AddMiddleware) {
        try {
          await onFoundMiddleware((meta.reflectee as AddMiddleware).middleware);
        } catch (e) {
          rethrow;
        }
      }
    }

    for (final meta in method.metadata) {
      if (meta.reflectee is AddMiddleware) {
        try {
          await onFoundMiddleware((meta.reflectee as AddMiddleware).middleware);
        } on Response {
          rethrow;
        }
      }
    }

    return response;
  }
}

class _RouterMethod {
  /// route method (GET, POST, etc)
  final Route route;

  /// which method to call
  final MethodMirror method;

  _RouterMethod({
    required this.route,
    required this.method,
  });
}

Params _extractParams(
  String path,
  String routePath,
) {
  final routeParts = routePath.split('/');
  final pathParts = path.split('/');
  final Params params = {};

  if (routeParts.length != pathParts.length) {
    return {};
  }

  for (var p = 0; p < routeParts.length; ++p) {
    if (routeParts[p].isEmpty) continue;

    if (routeParts[p][0] == ':') {
      params[routeParts[p].substring(1)] = pathParts[p];
    }
  }

  return params;
}

dynamic _getBody(String contentType, List<Uint8List> chunks) {
  if (contentType.startsWith('application/json')) {
    final buffer = StringBuffer();

    for (final chunk in chunks) {
      buffer.write(utf8.decode(chunk));
    }

    return jsonDecode(buffer.toString());
  }

  if (contentType.startsWith('text/')) {
    final buffer = StringBuffer();

    for (final chunk in chunks) {
      buffer.write(utf8.decode(chunk));
    }

    return buffer.toString();
  }
}

Request _toApplicationRequest(
  HttpRequest request, {
  required Params params,
  required QueryParams queryParams,
  dynamic body,
}) {
  final headers = <String, String>{};

  request.headers.forEach((name, values) {
    headers[name] = values.join(';');
  });

  return Request(
    method: request.method,
    headers: headers,
    params: params,
    queryParams: queryParams,
    body: body,
    uri: request.uri,
  );
}

HttpResponse _fromApplicationResponse(
  HttpResponse httpResponse,
  Response response,
) {
  if (!(response.headers.containsKey('content-type') || response.headers.containsKey('Content-Type'))) {
    String contentType = '';

    if (response.data is JsonMap || response.data is JsonArray) {
      contentType = 'application/json; charset=UTF-8';
    } else if (response.data is List<int>) {
      contentType = 'application/octet-stream';
    } else {
      contentType = 'text/plain';
    }

    response.headers['Content-Type'] = contentType;
  }

  late List<int> data;

  if (response.data is JsonMap || response.data is JsonArray) {
    data = utf8.encode(jsonEncode(response.data));
  } else if (response.data is List<int>) {
    data = response.data as List<int>;
  } else {
    data = utf8.encode(response.data.toString());
  }

  for (final header in response.headers.entries) {
    httpResponse.headers.add(header.key, header.value);
  }

  httpResponse
    ..statusCode = response.statusCode
    ..contentLength = data.length
    ..add(data);

  return httpResponse;
}
