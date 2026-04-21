import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();

  /// Login for both admin (email) and user (username/userID)
  static Future<Map<String, dynamic>> login({
    required String identifier, // email for admin, username for user
    required String password,
  }) async {
    try {
      print('DEBUG AUTH: Sending login request to ${ApiConfig.baseUrl}${ApiConfig.login}');
      print('DEBUG AUTH: Identifier: $identifier');
      
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': identifier, // backend accepts both email and username in this field
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('DEBUG AUTH: Login request timed out after 15 seconds');
          throw Exception('Request timeout');
        },
      );

      print('DEBUG AUTH: Response status: ${res.statusCode}');
      print('DEBUG AUTH: Response body: ${res.body}');

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        print('DEBUG AUTH: Login successful, saving tokens');
        await _storage.write(key: 'access_token',  value: data['access']);
        await _storage.write(key: 'refresh_token', value: data['refresh']);
        await _storage.write(key: 'user_role',     value: data['user']['role']);
        await _storage.write(key: 'user_name',     value: '${data['user']['first_name']} ${data['user']['last_name']}');
        // Save company code for splash routing
        final company = data['company'];
        if (company is Map) {
          await _storage.write(key: 'company_code', value: company['code'] ?? '');
        }
        print('DEBUG AUTH: Tokens saved successfully');
        return {'success': true, 'data': data};
      }

      print('DEBUG AUTH: Login failed with status ${res.statusCode}');
      return {
        'success': false,
        'error': data['error'] ?? data['detail'] ?? 'Invalid credentials. Please check your username and password.',
      };
    } catch (e) {
      print('DEBUG AUTH: Exception during login: $e');
      return {
        'success': false,
        'error': e.toString().contains('timeout') 
            ? 'Connection timeout. Please check your network and try again.'
            : 'Cannot connect to server. Please check your network.',
      };
    }
  }

  static Future<void> logout() async {
    await _storage.deleteAll();
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  static Future<String?> getUserRole() async {
    return await _storage.read(key: 'user_role');
  }

  static Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  static Future<bool> refreshToken() async {
    final refresh = await _storage.read(key: 'refresh_token');
    if (refresh == null) return false;

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tokenRefresh}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refresh}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await _storage.write(key: 'access_token', value: data['access']);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
