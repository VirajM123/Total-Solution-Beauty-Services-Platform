import 'dart:async';
import 'package:http/http.dart' as http;

/// Each deadline aborts its actual request. Closing also cancels outstanding I/O.
class CancellableHttp {
  CancellableHttp(this.client);
  final http.Client client;
  final Set<Completer<void>> _pending = {};
  bool _closed = false;

  Future<http.Response> request(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? body,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (_closed) throw http.ClientException('Request cancelled.', uri);
    final abort = Completer<void>();
    _pending.add(abort);
    var timedOut = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      if (!abort.isCompleted) abort.complete();
    });
    final request = http.AbortableRequest(
      method,
      uri,
      abortTrigger: abort.future,
    )..headers.addAll(headers);
    if (body != null) request.body = body;
    try {
      // Future.timeout also bounds injected clients that do not support Abortable.
      return await http.Response.fromStream(
        await client.send(request),
      ).timeout(timeout);
    } on http.RequestAbortedException {
      if (timedOut) throw TimeoutException('Request timed out.', timeout);
      rethrow;
    } on TimeoutException {
      if (!abort.isCompleted) abort.complete();
      rethrow;
    } finally {
      timer.cancel();
      _pending.remove(abort);
    }
  }

  void close() {
    _closed = true;
    for (final abort in _pending.toList()) {
      if (!abort.isCompleted) abort.complete();
    }
    client.close();
  }
}
