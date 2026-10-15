import 'dart:convert';
import 'package:http/http.dart' as http;
import '../local/local_store.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String _tokenKey = 'auth_jwt_token';
  static const String _customBaseUrlKey = 'custom_backend_url';

  // Default to local Cloudflare Worker port 8787
  String get baseUrl {
    final custom = LocalStore.instance.settings.get(_customBaseUrlKey);
    if (custom is String && custom.isNotEmpty) return custom;
    return 'http://127.0.0.1:8787';
  }

  set baseUrl(String url) {
    LocalStore.instance.settings.put(_customBaseUrlKey, url);
  }

  String? get token => LocalStore.instance.settings.get(_tokenKey) as String?;

  set token(String? val) {
    if (val == null) {
      LocalStore.instance.settings.delete(_tokenKey);
    } else {
      LocalStore.instance.settings.put(_tokenKey, val);
    }
  }

  Map<String, String> _headers([String? userId]) {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token!.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    if (userId != null && userId.isNotEmpty) {
      map['X-User-Id'] = userId;
    }
    return map;
  }

  /// Sign in with phone & OTP
  Future<Map<String, dynamic>> login({
    required String phone,
    required String otp,
    required String name,
    required String role,
  }) async {
    final url = Uri.parse('$baseUrl/api/v1/delivery/auth/login');
    final res = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'phone': phone,
        'otp': otp,
        'name': name,
        'role': role,
      }),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['token'] != null) {
        token = data['token'] as String;
      }
      return data;
    }
    throw Exception('Login failed: ${res.statusCode} ${res.body}');
  }

  /// Hydrates all data for milkman or subscriber in 1 call
  Future<Map<String, dynamic>> syncData({String? dateKey, String? userId}) async {
    final uri = Uri.parse('$baseUrl/api/v1/delivery/sync').replace(
      queryParameters: dateKey != null ? {'date_key': dateKey} : null,
    );
    final res = await http.get(uri, headers: _headers(userId));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Sync failed: ${res.statusCode} ${res.body}');
  }

  /// Flushes queued offline operations in bulk
  Future<int> drainQueue(List<Map<String, dynamic>> items, {String? userId}) async {
    if (items.isEmpty) return 0;
    final url = Uri.parse('$baseUrl/api/v1/delivery/sync/drain');
    final res = await http.post(
      url,
      headers: _headers(userId),
      body: jsonEncode({'items': items}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return (body['applied'] as num?)?.toInt() ?? 0;
    }
    throw Exception('Drain queue failed: ${res.statusCode} ${res.body}');
  }

  /// Batch update daily deliveries
  Future<void> batchDeliveries(List<Map<String, dynamic>> list, {String? userId}) async {
    final url = Uri.parse('$baseUrl/api/v1/delivery/deliveries/batch');
    final res = await http.post(
      url,
      headers: _headers(userId),
      body: jsonEncode({'deliveries': list}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Batch delivery failed: ${res.statusCode} ${res.body}');
    }
  }

  /// Create a change request (subscriber)
  Future<Map<String, dynamic>> createChangeRequest(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/api/v1/delivery/change-requests');
    final res = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode(data),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Create change request failed: ${res.statusCode} ${res.body}');
  }

  /// Resolve change request (milkman)
  Future<void> resolveChangeRequest(String id, String action) async {
    final url = Uri.parse('$baseUrl/api/v1/delivery/change-requests/$id/resolve');
    final res = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({'action': action}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Resolve change request failed: ${res.statusCode} ${res.body}');
    }
  }

  /// Create an absence
  Future<Map<String, dynamic>> createAbsence(Map<String, dynamic> data, {String? userId}) async {
    final url = Uri.parse('$baseUrl/api/v1/delivery/absences');
    final res = await http.post(
      url,
      headers: _headers(userId),
      body: jsonEncode(data),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Create absence failed: ${res.statusCode} ${res.body}');
  }

  /// Delete absence
  Future<void> deleteAbsence(String id, {String? userId}) async {
    final url = Uri.parse('$baseUrl/api/v1/delivery/absences/$id');
    final res = await http.delete(url, headers: _headers(userId));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Delete absence failed: ${res.statusCode} ${res.body}');
    }
  }
}
