import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import '../lib/integration/cancellable_http.dart';

class WaitingClient extends http.BaseClient {
  bool aborted = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await (request as http.Abortable).abortTrigger;
    aborted = true;
    throw http.RequestAbortedException(request.url);
  }
}

void main() {
  test('deadline aborts the underlying request', () async {
    final client = WaitingClient();
    final transport = CancellableHttp(client);
    await expectLater(
      transport.request(
        'GET',
        Uri.parse('https://example.test'),
        headers: {},
        timeout: const Duration(milliseconds: 20),
      ),
      throwsA(isA<TimeoutException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(client.aborted, isTrue);
    transport.close();
  });
  test('closing transport cancels outstanding requests', () async {
    final client = WaitingClient();
    final transport = CancellableHttp(client);
    final pending = transport.request(
      'GET',
      Uri.parse('https://example.test'),
      headers: {},
    );
    final expectation = expectLater(
      pending,
      throwsA(isA<http.RequestAbortedException>()),
    );
    transport.close();
    await expectation;
    expect(client.aborted, isTrue);
  });
}
