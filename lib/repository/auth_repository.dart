import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthRepository {
  static const _baseUrl = 'http://10.0.2.2:8080/secure';

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/login');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['accessToken'] as String;
    } else {
      throw Exception('Błąd logowania (${resp.statusCode})');
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final uri = Uri.parse('$_baseUrl/register');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Błąd rejestracji (${resp.statusCode})');
    }
  }
}
