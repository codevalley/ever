import 'dart:async';
import 'package:http/http.dart' as http;

/// HTTP client wrapper that adds timeout functionality
class TimeoutClient extends http.BaseClient {
  final http.Client _inner;
  final Duration timeout;

  TimeoutClient(this._inner, {this.timeout = const Duration(seconds: 10)});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      return await _inner.send(request).timeout(timeout);
    } on TimeoutException {
      _inner.close();
      throw http.ClientException('Request timed out after ${timeout.inSeconds} seconds', request.url);
    }
  }

  @override
  void close() {
    _inner.close();
  }
} 