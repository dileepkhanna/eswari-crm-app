import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class ApiService {
  static Future<Map<String, dynamic>> request({
    required String endpoint,
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    print('🌐 API: ${method} ${ApiConfig.baseUrl}$endpoint');
    
    String? token = await AuthService.getAccessToken();
    http.Response res = await _makeRequest(endpoint, method, body, token);

    print('🌐 API: Response status: ${res.statusCode}');
    print('🌐 API: Response body length: ${res.body.length}');
    print('🌐 API: Response body preview: ${res.body.substring(0, res.body.length > 200 ? 200 : res.body.length)}');

    // Auto-refresh on 401
    if (res.statusCode == 401) {
      print('🌐 API: Got 401, attempting token refresh...');
      final refreshed = await AuthService.refreshToken();
      if (refreshed) {
        token = await AuthService.getAccessToken();
        res = await _makeRequest(endpoint, method, body, token);
        print('🌐 API: Retry response status: ${res.statusCode}');
      }
    }

    return {
      'status': res.statusCode,
      'data': res.body.isNotEmpty ? jsonDecode(res.body) : null,
      'success': res.statusCode >= 200 && res.statusCode < 300,
    };
  }

  static Future<http.Response> _makeRequest(
    String endpoint,
    String method,
    Map<String, dynamic>? body,
    String? token,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final encoded = body != null ? jsonEncode(body) : null;

    switch (method.toUpperCase()) {
      case 'POST':   return await http.post(uri,   headers: headers, body: encoded);
      case 'PUT':    return await http.put(uri,    headers: headers, body: encoded);
      case 'PATCH':  return await http.patch(uri,  headers: headers, body: encoded);
      case 'DELETE': return await http.delete(uri, headers: headers);
      default:       return await http.get(uri,    headers: headers);
    }
  }

  static Future<Map<String, dynamic>> get(String endpoint) =>
      request(endpoint: endpoint);

  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) =>
      request(endpoint: endpoint, method: 'POST', body: body);

  static Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> body) =>
      request(endpoint: endpoint, method: 'PUT', body: body);

  static Future<Map<String, dynamic>> delete(String endpoint) =>
      request(endpoint: endpoint, method: 'DELETE');

  // Multipart upload for files
  static Future<Map<String, dynamic>> postWithFile(
    String endpoint,
    Map<String, dynamic> fields,
    File file,
    String fileFieldName,
  ) async {
    try {
      String? token = await AuthService.getAccessToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      
      final request = http.MultipartRequest('POST', uri);
      
      // Add headers
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      // Add fields
      fields.forEach((key, value) {
        request.fields[key] = value.toString();
      });
      
      // Add file
      final fileName = file.path.split('/').last;
      final fileExtension = fileName.split('.').last.toLowerCase();
      
      MediaType? contentType;
      if (fileExtension == 'pdf') {
        contentType = MediaType('application', 'pdf');
      } else if (fileExtension == 'jpg' || fileExtension == 'jpeg') {
        contentType = MediaType('image', 'jpeg');
      } else if (fileExtension == 'png') {
        contentType = MediaType('image', 'png');
      }
      
      request.files.add(await http.MultipartFile.fromPath(
        fileFieldName,
        file.path,
        contentType: contentType,
      ));
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      // Handle 401 and retry with refreshed token
      if (response.statusCode == 401) {
        final refreshed = await AuthService.refreshToken();
        if (refreshed) {
          token = await AuthService.getAccessToken();
          
          // Recreate request with new token
          final retryRequest = http.MultipartRequest('POST', uri);
          if (token != null) {
            retryRequest.headers['Authorization'] = 'Bearer $token';
          }
          fields.forEach((key, value) {
            retryRequest.fields[key] = value.toString();
          });
          retryRequest.files.add(await http.MultipartFile.fromPath(
            fileFieldName,
            file.path,
            contentType: contentType,
          ));
          
          final retryStreamedResponse = await retryRequest.send();
          final retryResponse = await http.Response.fromStream(retryStreamedResponse);
          
          return {
            'status': retryResponse.statusCode,
            'data': retryResponse.body.isNotEmpty ? jsonDecode(retryResponse.body) : null,
            'success': retryResponse.statusCode >= 200 && retryResponse.statusCode < 300,
          };
        }
      }
      
      return {
        'status': response.statusCode,
        'data': response.body.isNotEmpty ? jsonDecode(response.body) : null,
        'success': response.statusCode >= 200 && response.statusCode < 300,
      };
    } catch (e) {
      return {
        'status': 500,
        'data': {'error': e.toString()},
        'success': false,
      };
    }
  }
}
