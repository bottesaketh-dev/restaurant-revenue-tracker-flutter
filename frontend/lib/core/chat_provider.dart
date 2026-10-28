import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import 'branch_provider.dart';
import 'restaurant_provider.dart';

final chatStreamProvider = Provider((ref) => ChatStreamService(ref));

class ChatStreamService {
  final Ref _ref;
  final _storage = const FlutterSecureStorage();

  ChatStreamService(this._ref);

  String get _baseUrl {
    final dio = _ref.read(dioProvider);
    return dio.options.baseUrl;
  }

  Stream<Map<String, dynamic>> sendQuery(String message) async* {
    final token = await _storage.read(key: 'jwt_token');

    final request =
        http.Request('POST', Uri.parse('$_baseUrl/chat'));
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Content-Type'] = 'application/json';

    final restaurantId = _ref.read(selectedRestaurantIdProvider);
    if (restaurantId != null) {
      request.headers['X-Restaurant-ID'] = restaurantId.toString();
    }

    final branchId = _ref.read(selectedBranchProvider);
    request.body = jsonEncode({
      'message': message,
      if (restaurantId != null) 'restaurant_id': restaurantId,
      if (branchId != null) 'branch_id': branchId,
    });

    final client = http.Client();
    final response = await client.send(request);

    if (response.statusCode != 200) {
      yield {'type': 'error', 'message': 'HTTP ${response.statusCode}'};
      return;
    }

    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      try {
        final data = jsonDecode(line);
        yield data;
      } catch (e) {
        debugPrint('Error decoding AI stream line: $e');
        debugPrint('Offending line: $line');
      }
    }
    client.close();
  }
}
