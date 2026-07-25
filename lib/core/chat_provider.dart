import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'branch_provider.dart';

final chatStreamProvider = Provider((ref) => ChatStreamService(ref));

class ChatStreamService {
  final Ref _ref;
  final _storage = const FlutterSecureStorage();

  ChatStreamService(this._ref);

  Stream<Map<String, dynamic>> sendQuery(String message) async* {
    final token = await _storage.read(key: 'jwt_token');
    
    final request = http.Request('POST', Uri.parse('http://127.0.0.1:8000/api/v1/chat'));
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Content-Type'] = 'application/json';
    
    final branchId = _ref.read(selectedBranchProvider);
    request.body = jsonEncode({
      'message': message,
      if (branchId != null) 'branch_id': branchId,
    });

    final client = http.Client();
    final response = await client.send(request);

    if (response.statusCode != 200) {
      yield {'type': 'error', 'message': 'HTTP ${response.statusCode}'};
      return;
    }

    await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      try {
        final data = jsonDecode(line);
        yield data;
      } catch (e) {
        // ignore malformed JSON
      }
    }
    client.close();
  }
}
