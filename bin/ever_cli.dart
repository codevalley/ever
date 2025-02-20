import 'package:http/http.dart' as http;
import 'package:http/http.dart';

// HTTP Client with timeout
final client = TimeoutClient(
  http.Client(),
  timeout: const Duration(seconds: 30),  // Increased timeout
);

// Local Cache 