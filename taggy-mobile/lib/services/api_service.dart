import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://taggy-api.onrender.com';

  // =====================================================
  // HEADERS CON JWT
  // =====================================================

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('taggy_token');

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static dynamic _decode(http.Response response) {
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(response.body);
    } catch (_) {
      return <String, dynamic>{'mensaje': 'Respuesta invÃ¡lida del servidor'};
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
      throw Exception(_mensajeError(data, 'No se pudo crear la cuenta'));
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
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(_mensajeError(data, 'No se pudo iniciar sesiÃ³n'));
    }

    if (data is! Map) {
      throw Exception('Respuesta invÃ¡lida del servidor');
    }

    final token = data['token'];

    if (token == null || token.toString().isEmpty) {
      throw Exception('El servidor no devolviÃ³ un token');
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
      throw Exception(_mensajeError(data, 'No se pudo cargar el perfil'));
    }

    if (data is! Map || data['usuario'] is! Map) {
      throw Exception('Respuesta de perfil invÃ¡lida');
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
    String? fotoUrl,
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
        'foto_url': fotoUrl,
      }),
    );

    final data = _decode(response);

    if (response.statusCode != 201) {
      throw Exception(_mensajeError(data, 'No se pudo registrar la mascota'));
    }

    if (data is! Map || data['mascota'] is! Map) {
      throw Exception('Respuesta de mascota invÃ¡lida');
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
    String? fotoUrl,
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
        'foto_url': fotoUrl,
      }),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(_mensajeError(data, 'No se pudo actualizar la mascota'));
    }

    if (data is! Map || data['mascota'] is! Map) {
      throw Exception('Respuesta de mascota invÃ¡lida');
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
      throw Exception(_mensajeError(data, 'No se pudo eliminar la mascota'));
    }
  }

  // =====================================================
  // MODO EXTRAVÃO
  // =====================================================

  static Future<Map<String, dynamic>> cambiarModoExtravio({
    required int id,
    required bool extraviada,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/mascotas/$id/extravio'),
      headers: await _headers(),
      body: jsonEncode({'extraviada': extraviada}),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        _mensajeError(data, 'No se pudo actualizar el modo extravÃ­o'),
      );
    }

    if (data is! Map || data['mascota'] is! Map) {
      throw Exception('Respuesta de mascota invÃ¡lida');
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
      throw Exception(_mensajeError(data, 'No se pudo generar el QR'));
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

    throw Exception('El servidor no devolviÃ³ el token del QR');
  }

  // =====================================================
  // EVENTOS / ALERTAS DE UNA MASCOTA
  // =====================================================

  static Future<List<Map<String, dynamic>>> obtenerEventosMascota(
    int mascotaId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/mascotas/$mascotaId/eventos'),
      headers: await _headers(),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(_mensajeError(data, 'No se pudieron cargar las alertas'));
    }

    if (data is Map && data['eventos'] is List) {
      return (data['eventos'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    return <Map<String, dynamic>>[];
  }

  // =====================================================
  // ÃšLTIMA UBICACIÃ“N REAL DE UNA MASCOTA
  // =====================================================

  static Future<Map<String, dynamic>> obtenerUltimaUbicacion(
    int mascotaId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/mascotas/$mascotaId/ultima-ubicacion'),
      headers: await _headers(),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        _mensajeError(data, 'No se pudo obtener la Ãºltima ubicaciÃ³n'),
      );
    }

    if (data is! Map) {
      throw Exception('Respuesta de ubicaciÃ³n invÃ¡lida');
    }

    return Map<String, dynamic>.from(data);
  }

  // =====================================================
  // ESTADO ACTUAL DEL COLLAR - SIN CACHE
  // =====================================================

  static Future<Map<String, dynamic>> obtenerEstadoActualCollar(
    int mascotaId,
  ) async {
    final uri = Uri.parse('$baseUrl/api/mascotas/$mascotaId/ultima-ubicacion')
        .replace(
          queryParameters: {
            '_t': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );

    final response = await http.get(
      uri,
      headers: {...await _headers(), 'Cache-Control': 'no-cache'},
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        _mensajeError(data, 'No se pudo consultar el estado del collar'),
      );
    }

    if (data is! Map) {
      throw Exception('Respuesta de estado del collar invÃ¡lida');
    }

    return Map<String, dynamic>.from(data);
  }

  // =====================================================
  // WEB PUSH
  // =====================================================

  static Future<void> registrarSuscripcionPush(
    Map<String, dynamic> suscripcion,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/push/subscribe'),
      headers: await _headers(),
      body: jsonEncode(suscripcion),
    );

    final data = _decode(response);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        _mensajeError(data, 'No se pudieron activar las notificaciones'),
      );
    }
  }

  static Future<void> enviarPushPrueba() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/push/test'),
      headers: await _headers(),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        _mensajeError(data, 'No se pudo enviar la notificaciÃ³n de prueba'),
      );
    }
  }

  // =====================================================
  // HISTORIAL GPS DE UNA MASCOTA
  // =====================================================

  static Future<List<Map<String, dynamic>>> obtenerHistorialUbicaciones(
    int mascotaId, {
    required int horas,
    int limite = 1000,
  }) async {
    final uri = Uri.parse('$baseUrl/api/mascotas/$mascotaId/ubicaciones')
        .replace(
          queryParameters: {
            'horas': horas.toString(),
            'limite': limite.toString(),
            '_t': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );

    final response = await http.get(
      uri,
      headers: {...await _headers(), 'Cache-Control': 'no-cache'},
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        _mensajeError(data, 'No se pudo cargar el historial GPS'),
      );
    }

    if (data is Map && data['ubicaciones'] is List) {
      return (data['ubicaciones'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    return <Map<String, dynamic>>[];
  }

  // =====================================================
  // ZONA SEGURA / GEOCERCA
  // =====================================================

  static Future<Map<String, dynamic>?> obtenerGeocerca(int mascotaId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/mascotas/$mascotaId/geocerca'),
      headers: await _headers(),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        _mensajeError(data, 'No se pudo consultar la zona segura'),
      );
    }

    if (data is Map && data['geocerca'] is Map) {
      return Map<String, dynamic>.from(data['geocerca'] as Map);
    }

    return null;
  }

  static Future<Map<String, dynamic>> guardarGeocerca({
    required int mascotaId,
    required double latitud,
    required double longitud,
    required int radioMetros,
    String nombre = 'Casa',
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/mascotas/$mascotaId/geocerca'),
      headers: await _headers(),
      body: jsonEncode({
        'nombre': nombre,
        'latitud': latitud,
        'longitud': longitud,
        'radio_metros': radioMetros,
      }),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(_mensajeError(data, 'No se pudo guardar la zona segura'));
    }

    if (data is! Map || data['geocerca'] is! Map) {
      throw Exception('Respuesta de geocerca invÃ¡lida');
    }

    return Map<String, dynamic>.from(data['geocerca'] as Map);
  }
}
