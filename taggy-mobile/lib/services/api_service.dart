import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl =
      'https://taggy-api.onrender.com';

  // =====================================================
  // HEADERS CON JWT
  // =====================================================

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

  // =====================================================
  // REGISTRAR USUARIO
  // =====================================================

  static Future<void> registrarUsuario({
    required String nombre,
    required String email,
    required String password,
    required String telefono,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/usuarios'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'nombre': nombre,
        'email': email,
        'password': password,
        'telefono': telefono,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(
        data['mensaje'] ??
            'No se pudo crear la cuenta',
      );
    }
  }

  // =====================================================
  // LOGIN
  // =====================================================

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        data['mensaje'] ??
            'No se pudo iniciar sesión',
      );
    }

    final token = data['token'];

    if (token == null ||
        token.toString().isEmpty) {
      throw Exception(
        'El servidor no devolvió un token',
      );
    }

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      'taggy_token',
      token.toString(),
    );

    await prefs.setBool(
      'taggy_logged_in',
      true,
    );

    final usuario = data['usuario'];

    if (usuario != null) {
      await prefs.setString(
        'taggy_user_name',
        usuario['nombre']?.toString() ?? '',
      );

      await prefs.setString(
        'taggy_user_lastname',
        usuario['apellido']?.toString() ?? '',
      );

      await prefs.setString(
        'taggy_user_email',
        usuario['email']?.toString() ?? email,
      );

      await prefs.setString(
        'taggy_user_phone',
        usuario['telefono']?.toString() ?? '',
      );
    }
  }

  // =====================================================
  // CERRAR SESIÓN
  // =====================================================

  static Future<void> logout() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove('taggy_token');
    await prefs.remove('taggy_logged_in');

    await prefs.remove('taggy_user_name');
    await prefs.remove('taggy_user_lastname');
    await prefs.remove('taggy_user_email');
    await prefs.remove('taggy_user_phone');
  }

  // =====================================================
  // PERFIL
  // =====================================================

  static Future<Map<String, dynamic>>
      obtenerPerfil() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/perfil'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        data['mensaje'] ??
            'No se pudo cargar el perfil',
      );
    }

    return Map<String, dynamic>.from(
      data['usuario'],
    );
  }

  // =====================================================
  // CREAR MASCOTA
  // =====================================================

  static Future<Map<String, dynamic>>
      crearMascota({
    required String nombre,
    required String especie,
    String? raza,
    String? sexo,
    String? color,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/mascotas'),
      headers: await _headers(),
      body: jsonEncode({
        'nombre': nombre,
        'especie': especie,
        'raza': raza,
        'sexo': sexo,
        'color': color,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(
        data['mensaje'] ??
            'No se pudo registrar la mascota',
      );
    }

    return Map<String, dynamic>.from(
      data['mascota'],
    );
  }

  // =====================================================
  // OBTENER MASCOTAS
  // =====================================================

  static Future<List<dynamic>>
      obtenerMascotas() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/mascotas'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        data['mensaje'] ??
            'No se pudieron obtener las mascotas',
      );
    }

    if (data is List) {
      return data;
    }

    if (data['mascotas'] is List) {
      return data['mascotas'];
    }

    return [];
  }
}