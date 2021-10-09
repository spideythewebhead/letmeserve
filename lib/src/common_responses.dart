import 'dart:io';

Future<void> response404(HttpResponse response) {
  return (response..statusCode = 404).close();
}

Future<void> response500(HttpResponse response) {
  return (response..statusCode = 500).close();
}
