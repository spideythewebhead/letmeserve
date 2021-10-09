_a learning purpose project, not for production use_

# LetMeServe

A tiny abstraction around HttpServer (still in progress)
Mostly for json requests

Provides simple usage for **Router**, **Controller** and **Middleware**
Also a **Json Validator**

#### Example usage

1. Create a controller

```dart
class TodosControllerV0 implements Controller {
    Future<Response> getTodoById(Request request) async {
        final id =  request.params['id'];
        ...
    }

    Future<Response> createTodo(Request request) async {
        final body = request.body;
        ...
    }
}
```

2. Create a router than forwards the requests to a controller

```dart
class TodosRouterV0 extends Router {
    final TodosControllerV0 controller;

    TodosRouterV0(
        this.controller,
    ): super(prefix: '/api/v0');

    @Route.get('/todo/:id')
    Future<Response> getTodoById(Request request) => controller.getTodoById(request);

    @Route.post('/todo') createTodo(Request request) => controller.createTodo(request);
}
```

3. Create the server

```dart
void main() {
    ...

    final server = LetMeServe(host: 'localhost', port: 3000);

    await server.listen(() => print('server running'));
}
```

4. Add middlware (Optional)

```dart
class LogMiddleware extends Middleware {
    @override
    Future<Request?> onRequest(Request request, void Function(Response response) abort) {
    }

    @override
    Future<Response> onResponse(Response response) {
    }
}

class AuthMiddlware implements Middlware { ... }

/// applies to all methods annotated with @Route.[method]
@AddMiddlware(LogMiddleware)
class MyRouter extends Router {
    /// applies to
    @AddMiddlware(AuthMiddlware)
    @Route.get('/path/to/my/route')
    Future<Response> myRoute(Request request) { ... }
}
```

5. Json Validator (Optional)

```dart
    final validator = JsonValidator()..isString('name', minLength: 3)..isInt('age', min: 18);

    final errors = validator.validate({'name': 'my name is', age: 26});
```
