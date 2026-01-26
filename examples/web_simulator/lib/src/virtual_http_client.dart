import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' as shelf;

/// An [http.Client] that routes requests directly to a [shelf.Handler]
/// without any actual network calls.
class VirtualHttpClient extends http.BaseClient {
  final shelf.Handler handler;

  VirtualHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // 1. Convert http.BaseRequest to shelf.Request
    final bytes = await request.finalize().toBytes();

    final shelfRequest = shelf.Request(
      request.method,
      request.url,
      headers: request.headers,
      body: bytes,
    );

    // 2. Call the shelf handler
    final shelfResponse = await handler(shelfRequest);

    // 3. Convert shelf.Response to http.StreamedResponse
    final responseBodyBytes = await shelfResponse.read().toList();
    final flattenedBytes = responseBodyBytes.expand((x) => x).toList();

    return http.StreamedResponse(
      Stream.value(flattenedBytes),
      shelfResponse.statusCode,
      contentLength: flattenedBytes.length,
      headers: shelfResponse.headers,
      reasonPhrase: _reasonPhrases[shelfResponse.statusCode],
    );
  }
}

const _reasonPhrases = {
  200: 'OK',
  201: 'Created',
  400: 'Bad Request',
  401: 'Unauthorized',
  403: 'Forbidden',
  404: 'Not Found',
  409: 'Conflict',
  500: 'Internal Server Error',
};
