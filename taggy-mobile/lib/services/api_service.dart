import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000';

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('taggy_token');

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        data['mensaje'] ?? 'No se pudo iniciar sesión',
      );
    }

    final token = data['token'];

    if (token == null || token.toString().isEmpty) {
      throw Exception('El servidor no devolvió un token');
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'taggy_token',
      token.toString(),
    );

    await prefs.setBool(
      'taggy_logged_in',
      true,
    );

    await prefs.setString(
      'taggy_user_email',
      email,
    );
  }

  static Future<List<dynamic>> obtenerMascotas() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/mascotas'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        data['mensaje'] ?? 'No se pudieron obtener las mascotas',
      );
    }

    if (data is List) {
      return data;
    }

    return data['mascotas'] ?? [];
  }
}