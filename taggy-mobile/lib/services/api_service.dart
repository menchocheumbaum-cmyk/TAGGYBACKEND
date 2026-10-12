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

  static dynamic _decode(http.Response response) {
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(response.body);
    } catch (_) {
      return <String, dynamic>{
        'mensaje': 'Respuesta inválida del servidor',
      };
    }
  }

  static String _mensajeError(dynamic data, String fallback) {
    if (data is Map && data['mensaje'] != null) {
      return data['mensaje'].toString();
    }
    return fallback;
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
      headers: const {
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

    final data = _decode(response);

    if (response.statusCode != 201) {
      throw Exception(
        _mensajeError(data, 'No se pudo crear la cuenta'),
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
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        _mensajeError(data, 'No se pudo iniciar sesión'),
      );
    }

    if (data is! Map) {
      throw Exception('Respuesta inválida del servidor');
    }

    final token = data['token'];

    if (token == null || token.toString().isEmpty) {
      throw Exception('El servidor no devolvió un token');
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('taggy_token', token.toString());
    await prefs.setBool('taggy_logged_in', true);

    final usuario = data['usuario'];

    if (usuario is Map) {
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
  // LOGOUT
  // =====================================================

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

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

  static Future<Map<String, dynamic>> obtenerPerfil() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/perfil'),
      headers: await _headers(),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        _mensajeError(data, 'No se pudo cargar el perfil'),
      );
    }

    if (data is! Map || data['usuario'] is! Map) {
      throw Exception('Respuesta de perfil inválida');
    }

    return Map<String, dynamic>.from(data['usuario']);
  }

  // =====================================================
  // MASCOTAS - CREAR
  // =====================================================

  static Future<Map<String, dynamic>> crearMascota({
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

    final data = _decode(response);

    if (response.statusCode != 201) {
      throw Exception(
        _mensajeError(data, 'No se pudo registrar la mascota'),
      );
    }

    if (data is! Map || data['mascota'] is! Map) {
      throw Exception('Respuesta de mascota inválida');
    }

    return Map<String, dynamic>.from(data['mascota']);
  }

  // =====================================================
  // MASCOTAS - LISTAR
  // =====================================================

  static Future<List<dynamic>> obtenerMascotas() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/mascotas'),
      headers: await _headers(),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        _mensajeError(data, 'No se pudieron obtener las mascotas'),
      );
    }

    if (data is List) {
      return data;
    }

    if (data is Map && data['mascotas'] is List) {
      return data['mascotas'] as List<dynamic>;
    }

    return [];
  }

  // =====================================================
  // MASCOTAS - EDITAR
  // =====================================================

  static Future<Map<String, dynamic>> editarMascota({
    required int id,
    required String nombre,
    required String especie,
    String? raza,
    String? sexo,
    String? color,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/mascotas/$id'),
      headers: await _headers(),
      body: jsonEncode({
        'nombre': nombre,
        'especie': especie,
        'raza': raza,
        'sexo': sexo,
        'color': color,
      }),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        _mensajeError(data, 'No se pudo actualizar la mascota'),
      );
    }

    if (data is! Map || data['mascota'] is! Map) {
      throw Exception('Respuesta de mascota inválida');
    }

    return Map<String, dynamic>.from(data['mascota']);
  }

  // =====================================================
  // MASCOTAS - ELIMINAR
  // =====================================================

  static Future<void> eliminarMascota(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/mascotas/$id'),
      headers: await _headers(),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        _mensajeError(data, 'No se pudo eliminar la mascota'),
      );
    }
  }

  // =====================================================
  // MODO EXTRAVÍO
  // =====================================================

  static Future<Map<String, dynamic>> cambiarModoExtravio({
    required int id,
    required bool extraviada,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/mascotas/$id/extravio'),
      headers: await _headers(),
      body: jsonEncode({
        'extraviada': extraviada,
      }),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        _mensajeError(data, 'No se pudo actualizar el modo extravío'),
      );
    }

    if (data is! Map || data['mascota'] is! Map) {
      throw Exception('Respuesta de mascota inválida');
    }

    return Map<String, dynamic>.from(data['mascota']);
  }

  // =====================================================
  // QR
  // =====================================================

  static Future<String> generarQr(int mascotaId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/mascotas/$mascotaId/qr'),
      headers: await _headers(),
    );

    final data = _decode(response);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        _mensajeError(data, 'No se pudo generar el QR'),
      );
    }

    if (data is Map) {
      final tokenExistente = data['token']?.toString();
      if (tokenExistente != null && tokenExistente.isNotEmpty) {
        return tokenExistente;
      }

      final qr = data['qr'];
      if (qr is Map) {
        final tokenNuevo = qr['token']?.toString();
        if (tokenNuevo != null && tokenNuevo.isNotEmpty) {
          return tokenNuevo;
        }
      }
    }

    throw Exception('El servidor no devolvió el token del QR');
  }
}
