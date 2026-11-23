import 'design/taggy_design_system.dart';

import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

import 'services/api_service.dart';
import 'services/push_service.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:video_player/video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaggyApp());
}

// ======================================================
// COLORES TAGGY
// ======================================================

// ======================================================
// MODELO MASCOTA
// ======================================================

class Mascota {
  int? id;
  String nombre;
  String especie;
  String raza;
  String edad;
  String sexo;
  String color;
  String peso;
  String idTaggy;
  bool extraviada;
  String? imagenPath;

  Mascota({
    this.id,
    required this.nombre,
    required this.especie,
    required this.raza,
    required this.edad,
    required this.sexo,
    required this.color,
    required this.peso,
    required this.idTaggy,
    this.extraviada = false,
    this.imagenPath,
  });

  Mascota copyWith({
    int? id,
    String? nombre,
    String? especie,
    String? raza,
    String? edad,
    String? sexo,
    String? color,
    String? peso,
    String? idTaggy,
    bool? extraviada,
    String? imagenPath,
  }) {
    return Mascota(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      especie: especie ?? this.especie,
      raza: raza ?? this.raza,
      edad: edad ?? this.edad,
      sexo: sexo ?? this.sexo,
      color: color ?? this.color,
      peso: peso ?? this.peso,
      idTaggy: idTaggy ?? this.idTaggy,
      extraviada: extraviada ?? this.extraviada,
      imagenPath: imagenPath ?? this.imagenPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'especie': especie,
      'raza': raza,
      'edad': edad,
      'sexo': sexo,
      'color': color,
      'peso': peso,
      'idTaggy': idTaggy,
      'extraviada': extraviada,
      'imagenPath': imagenPath,
    };
  }

  factory Mascota.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

    return Mascota(
      id: id,
      nombre: json['nombre']?.toString() ?? '',
      especie: json['especie']?.toString() ?? 'Perro',
      raza: json['raza']?.toString() ?? '',
      edad: json['edad']?.toString() ?? '',
      sexo: json['sexo']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      peso: json['peso']?.toString() ?? '',
      idTaggy:
          json['device_uid']?.toString() ??
          json['idTaggy']?.toString() ??
          'TAGGY-${json['id'] ?? ''}',
      extraviada: json['modo_extravio'] == true || json['extraviada'] == true,
      imagenPath:
          json['foto_url']?.toString() ?? json['imagenPath']?.toString(),
    );
  }
}

// ======================================================
// FOTOS DE MASCOTAS// ======================================================
// FOTOS DE MASCOTAS
// ======================================================

// ======================================================
// FOTOS DE MASCOTAS
// ======================================================

Future<String?> seleccionarYGuardarImagen(BuildContext context) async {
  try {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: TaggyColors.surface,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Foto de la mascota',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: TaggyColors.lightBlue,
                  ),
                  title: const Text('Elegir de la galería'),
                  onTap: () {
                    Navigator.pop(sheetContext, ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: TaggyColors.cyan,
                  ),
                  title: const Text('Tomar una foto'),
                  onTap: () {
                    Navigator.pop(sheetContext, ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      return null;
    }

    final picker = ImagePicker();

    final imagen = await picker.pickImage(
      source: source,
      imageQuality: 68,
      maxWidth: 900,
      maxHeight: 900,
    );

    if (imagen == null) {
      return null;
    }

    final bytes = await imagen.readAsBytes();

    // Para no superar el limite JSON del servidor.
    if (bytes.lengthInBytes > 3 * 1024 * 1024) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La imagen es demasiado grande. Selecciona otra foto.',
            ),
          ),
        );
      }
      return null;
    }

    final nombre = imagen.name.toLowerCase();

    String mime = 'image/jpeg';

    if (nombre.endsWith('.png')) {
      mime = 'image/png';
    } else if (nombre.endsWith('.webp')) {
      mime = 'image/webp';
    } else if (nombre.endsWith('.gif')) {
      mime = 'image/gif';
    }

    final contenido = base64Encode(bytes);

    return 'data:$mime;base64,$contenido';
  } catch (e) {
    debugPrint('ERROR FOTO TAGGY: $e');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar la imagen: $e')),
      );
    }

    return null;
  }
}
// ======================================================
// APP
// ======================================================

class TaggyApp extends StatelessWidget {
  const TaggyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TAGGY',
      theme: TaggyTheme.light,
      home: const IntroVideoPage(),
    );
  }
}
// ======================================================
// CONTROL DE SESIÃ“N
// ======================================================

class IntroVideoPage extends StatefulWidget {
  const IntroVideoPage({super.key});

  @override
  State<IntroVideoPage> createState() => _IntroVideoPageState();
}

class _IntroVideoPageState extends State<IntroVideoPage> {
  VideoPlayerController? _controller;
  bool _listo = false;
  bool _terminado = false;

  @override
  void initState() {
    super.initState();
    _iniciarIntro();
  }

  Future<void> _iniciarIntro() async {
    try {
      final controller = VideoPlayerController.asset(
        'assets/video/taggy_intro_3s.mp4',
      );

      _controller = controller;

      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(false);

      if (!mounted) return;

      setState(() {
        _listo = true;
      });

      await controller.play();

      await Future.delayed(const Duration(seconds: 3));

      _entrarApp();
    } catch (e) {
      debugPrint('Error cargando intro TAGGY: $e');

      await Future.delayed(const Duration(seconds: 1));

      _entrarApp();
    }
  }

  void _entrarApp() {
    if (!mounted || _terminado) return;

    _terminado = true;

    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: _listo && controller != null && controller.value.isInitialized
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}

// ======================================================
// CONTROL DE SESION
// ======================================================

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool cargando = true;
  bool sesionIniciada = false;

  @override
  void initState() {
    super.initState();
    revisarSesion();
  }

  Future<void> revisarSesion() async {
    final prefs = await SharedPreferences.getInstance();

    final sesion = prefs.getBool('taggy_logged_in') ?? false;

    if (!mounted) return;

    setState(() {
      sesionIniciada = sesion;
      cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (sesionIniciada) {
      return const HomePage();
    }

    return const LoginPage();
  }
}

// ======================================================
// INICIAR SESIÃ“N
// ======================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final correoController = TextEditingController();

  final passwordController = TextEditingController();

  bool ocultarPassword = true;

  Future<void> iniciarSesion() async {
    final correo = correoController.text.trim();
    final password = passwordController.text.trim();

    if (correo.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu correo y contraseÃ±a.')),
      );
      return;
    }

    try {
      await ApiService.login(email: correo, password: password);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicio de sesiÃ³n correcto')),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  void dispose() {
    correoController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                Container(
                  width: 95,
                  height: 95,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [TaggyColors.blue, TaggyColors.cyan],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.pets, size: 55, color: Colors.white),
                ),

                const SizedBox(height: 20),

                const Text(
                  'TAGGY',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'ProtecciÃ³n inteligente para tu mascota',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: TaggyColors.textSecondary),
                ),

                const SizedBox(height: 40),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Iniciar sesiÃ³n',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrÃ³nico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),

                const SizedBox(height: 15),

                TextField(
                  controller: passwordController,
                  obscureText: ocultarPassword,
                  decoration: InputDecoration(
                    labelText: 'ContraseÃ±a',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          ocultarPassword = !ocultarPassword;
                        });
                      },
                      icon: Icon(
                        ocultarPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton(
                    onPressed: iniciarSesion,
                    child: const Text(
                      'Iniciar sesiÃ³n',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Â¿No tienes cuenta?'),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegistroPage(),
                          ),
                        );
                      },
                      child: const Text('Crear cuenta'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================
// CREAR CUENTA
// ======================================================

class RegistroPage extends StatefulWidget {
  const RegistroPage({super.key});

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  final nombreController = TextEditingController();

  final correoController = TextEditingController();

  final telefonoController = TextEditingController();

  final passwordController = TextEditingController();

  final confirmarController = TextEditingController();

  Future<void> crearCuenta() async {
    final nombre = nombreController.text.trim();
    final correo = correoController.text.trim();
    final telefono = telefonoController.text.trim();
    final password = passwordController.text;
    final confirmar = confirmarController.text;

    if (nombre.isEmpty ||
        correo.isEmpty ||
        telefono.isEmpty ||
        password.isEmpty ||
        confirmar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos.')),
      );
      return;
    }

    if (password != confirmar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseÃ±as no coinciden.')),
      );
      return;
    }

    try {
      await ApiService.registrarUsuario(
        nombre: nombre,
        email: correo,
        password: password,
        telefono: telefono,
      );

      await ApiService.login(email: correo, password: password);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta creada correctamente')),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    correoController.dispose();
    telefonoController.dispose();
    passwordController.dispose();
    confirmarController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(25),
        children: [
          const Text(
            'Crear cuenta TAGGY',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 25),

          TextField(
            controller: nombreController,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: correoController,
            decoration: const InputDecoration(
              labelText: 'Correo electrÃ³nico',
              prefixIcon: Icon(Icons.email),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: telefonoController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'TelÃ©fono',
              prefixIcon: Icon(Icons.phone),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'ContraseÃ±a',
              prefixIcon: Icon(Icons.lock),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: confirmarController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseÃ±a',
              prefixIcon: Icon(Icons.lock_reset),
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            height: 55,
            child: FilledButton.icon(
              onPressed: crearCuenta,
              icon: const Icon(Icons.person_add),
              label: const Text('Crear cuenta'),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// HOME GENERAL
// ======================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String storageKey = 'taggy_mascotas';

  int paginaActual = 0;
  bool cargando = true;

  List<Mascota> mascotas = [];

  @override
  void initState() {
    super.initState();
    cargarMascotas();
  }

  Mascota get mascotaInicial {
    return Mascota(
      nombre: 'Max',
      especie: 'Perro',
      raza: 'Labrador',
      edad: '3 aÃ±os',
      sexo: 'Macho',
      color: 'Amarillo',
      peso: '28 kg',
      idTaggy: 'TAGGY-X72F82',
    );
  }

  Future<void> cargarMascotas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final datosLocales = prefs.getString(storageKey);

      final Map<int, Mascota> localesPorId = {};

      if (datosLocales != null && datosLocales.isNotEmpty) {
        try {
          final listaLocal = jsonDecode(datosLocales) as List<dynamic>;
          for (final item in listaLocal) {
            final local = Mascota.fromJson(Map<String, dynamic>.from(item));
            if (local.id != null) {
              localesPorId[local.id!] = local;
            }
          }
        } catch (_) {
          // Ignoramos datos locales antiguos o daÃ±ados.
        }
      }

      final lista = await ApiService.obtenerMascotas();

      mascotas = lista.map((item) {
        var remota = Mascota.fromJson(Map<String, dynamic>.from(item));

        final local = remota.id == null ? null : localesPorId[remota.id!];

        if (local != null) {
          remota = remota.copyWith(
            edad: local.edad,
            peso: local.peso,
            imagenPath:
                remota.imagenPath != null && remota.imagenPath!.isNotEmpty
                ? remota.imagenPath
                : local.imagenPath,
          );
        }

        return remota;
      }).toList();

      await guardarMascotas();

      debugPrint('Mascotas recibidas del backend: ${mascotas.length}');
    } catch (e) {
      debugPrint('ERROR AL CARGAR MASCOTAS: $e');

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudieron cargar las mascotas: $e')),
          );
        });
      }
    }

    if (mounted) {
      setState(() {
        cargando = false;
      });
    }
  }

  Future<void> guardarMascotas() async {
    final prefs = await SharedPreferences.getInstance();

    final datos = mascotas.map((mascota) => mascota.toJson()).toList();

    await prefs.setString(storageKey, jsonEncode(datos));
  }

  Future<void> agregarMascota(Mascota mascota) async {
    try {
      final data = await ApiService.crearMascota(
        nombre: mascota.nombre,
        especie: mascota.especie,
        raza: mascota.raza,
        sexo: mascota.sexo,
        color: mascota.color,
        fotoUrl: mascota.imagenPath,
      );

      final creada = Mascota.fromJson(data).copyWith(
        edad: mascota.edad,
        peso: mascota.peso,
        imagenPath: mascota.imagenPath,
      );

      if (!mounted) return;

      setState(() {
        mascotas.insert(0, creada);
      });

      await guardarMascotas();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      rethrow;
    }
  }

  Future<void> editarMascota(int index, Mascota mascotaActualizada) async {
    if (index < 0 || index >= mascotas.length) return;

    final original = mascotas[index];

    if (original.id == null) {
      throw Exception('La mascota no tiene un ID vÃ¡lido.');
    }

    try {
      final data = await ApiService.editarMascota(
        id: original.id!,
        nombre: mascotaActualizada.nombre,
        especie: mascotaActualizada.especie,
        raza: mascotaActualizada.raza,
        sexo: mascotaActualizada.sexo,
        color: mascotaActualizada.color,
        fotoUrl: mascotaActualizada.imagenPath,
      );

      final actualizada = Mascota.fromJson(data).copyWith(
        edad: mascotaActualizada.edad,
        peso: mascotaActualizada.peso,
        imagenPath: mascotaActualizada.imagenPath,
        idTaggy: original.idTaggy,
      );

      if (!mounted) return;

      setState(() {
        mascotas[index] = actualizada;
      });

      await guardarMascotas();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      rethrow;
    }
  }

  Future<void> eliminarMascota(int index) async {
    if (index < 0 || index >= mascotas.length) return;

    final mascota = mascotas[index];

    if (mascota.id == null) {
      throw Exception('La mascota no tiene un ID vÃ¡lido.');
    }

    try {
      await ApiService.eliminarMascota(mascota.id!);

      if (!mounted) return;

      setState(() {
        mascotas.removeAt(index);
      });

      await guardarMascotas();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      rethrow;
    }
  }

  Future<void> cambiarEstadoExtravio(int index, bool extraviada) async {
    if (index < 0 || index >= mascotas.length) return;

    final mascota = mascotas[index];

    if (mascota.id == null) {
      throw Exception('La mascota no tiene un ID vÃ¡lido.');
    }

    try {
      final data = await ApiService.cambiarModoExtravio(
        id: mascota.id!,
        extraviada: extraviada,
      );

      final actualizada = Mascota.fromJson(data).copyWith(
        edad: mascota.edad,
        peso: mascota.peso,
        imagenPath: mascota.imagenPath,
        idTaggy: mascota.idTaggy,
      );

      if (!mounted) return;

      setState(() {
        mascotas[index] = actualizada;
      });

      await guardarMascotas();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      rethrow;
    }
  }

  void cambiarPagina(int index) {
    setState(() {
      paginaActual = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final paginas = [
      InicioPage(
        mascotas: mascotas,
        onCambiarPagina: cambiarPagina,
        onEstadoExtravio: cambiarEstadoExtravio,
      ),
      MascotasPage(
        mascotas: mascotas,
        onAgregarMascota: agregarMascota,
        onEditarMascota: editarMascota,
        onEliminarMascota: eliminarMascota,
        onEstadoExtravio: cambiarEstadoExtravio,
      ),
      UbicacionPage(mascotas: mascotas),
      AlertasPage(mascotas: mascotas),
      const PerfilPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: paginaActual, children: paginas),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: TaggyColors.surface,
          border: Border(top: BorderSide(color: Color(0xFFE5E5EA))),
        ),
        child: NavigationBar(
          backgroundColor: TaggyColors.surface,
          indicatorColor: Colors.transparent,
          selectedIndex: paginaActual,
          onDestinationSelected: cambiarPagina,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: TaggyColors.blue),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.pets_outlined),
              selectedIcon: Icon(Icons.pets, color: TaggyColors.lightBlue),
              label: 'Mascotas',
            ),
            NavigationDestination(
              icon: Icon(Icons.location_on_outlined),
              selectedIcon: Icon(Icons.location_on, color: TaggyColors.blue),
              label: 'UbicaciÃ³n',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications, color: TaggyColors.blue),
              label: 'Alertas',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: TaggyColors.lightBlue),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// INICIO
// ======================================================

class InicioPage extends StatelessWidget {
  final List<Mascota> mascotas;

  final Function(int) onCambiarPagina;

  final Future<void> Function(int index, bool extraviada) onEstadoExtravio;

  const InicioPage({
    super.key,
    required this.mascotas,
    required this.onCambiarPagina,
    required this.onEstadoExtravio,
  });

  @override
  Widget build(BuildContext context) {
    final Mascota? mascota = mascotas.isNotEmpty ? mascotas.first : null;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 35),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inicio',
                      style: TextStyle(
                        color: TaggyColors.textPrimary,
                        fontSize: 34,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Tu mascota, siempre cerca.',
                      style: TextStyle(
                        color: TaggyColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: TaggyColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: TaggyColors.separator),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.pets_rounded,
                  color: TaggyColors.blue,
                  size: 23,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          if (mascota == null)
            EmptyMascotasCard(
              onPressed: () {
                onCambiarPagina(1);
              },
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mascota.extraviada
                    ? TaggyColors.red.withValues(alpha: 0.09)
                    : TaggyColors.green.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    mascota.extraviada
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded,
                    color: mascota.extraviada
                        ? TaggyColors.red
                        : TaggyColors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      mascota.extraviada
                          ? 'ExtravÃ­o activo para ${mascota.nombre}'
                          : '${mascota.nombre} estÃ¡ segura',
                      style: TextStyle(
                        color: mascota.extraviada
                            ? TaggyColors.red
                            : const Color(0xFF248A3D),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            MascotaPrincipalCard(mascota: mascota),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      onCambiarPagina(2);
                    },
                    icon: const Icon(Icons.location_on_rounded, size: 20),
                    label: const Text('UbicaciÃ³n'),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TaggyColors.red,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExtravioPage(
                            mascota: mascota,
                            onEstadoChanged: (estado) {
                              return onEstadoExtravio(0, estado);
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.warning_amber_rounded, size: 20),
                    label: Text(mascota.extraviada ? 'ExtravÃ­o' : 'Reportar'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            const Text(
              'MÃ¡s',
              style: TextStyle(
                color: TaggyColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 14),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                QuickActionCard(
                  titulo: 'CÃ³digo QR',
                  subtitulo: 'Perfil pÃºblico',
                  icono: Icons.qr_code_2_rounded,
                  color: TaggyColors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QrPage(mascota: mascota),
                      ),
                    );
                  },
                ),
                QuickActionCard(
                  titulo: 'Seguridad',
                  subtitulo: 'ProtecciÃ³n TAGGY',
                  icono: Icons.shield_outlined,
                  color: TaggyColors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SeguridadPage()),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ======================================================
// MASCOTAS
// ======================================================

class MascotasPage extends StatelessWidget {
  final List<Mascota> mascotas;

  final Future<void> Function(Mascota mascota) onAgregarMascota;

  final Future<void> Function(int index, Mascota mascota) onEditarMascota;

  final Future<void> Function(int index) onEliminarMascota;

  final Future<void> Function(int index, bool extraviada) onEstadoExtravio;

  const MascotasPage({
    super.key,
    required this.mascotas,
    required this.onAgregarMascota,
    required this.onEditarMascota,
    required this.onEliminarMascota,
    required this.onEstadoExtravio,
  });

  Future<void> abrirAgregarMascota(BuildContext context) async {
    final nuevaMascota = await Navigator.push<Mascota>(
      context,
      MaterialPageRoute(builder: (_) => const AgregarMascotaPage()),
    );

    if (nuevaMascota == null) {
      return;
    }

    try {
      await onAgregarMascota(nuevaMascota);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: TaggyColors.surfaceLight,
            content: Text('${nuevaMascota.nombre} fue agregada correctamente.'),
          ),
        );
      }
    } catch (_) {
      // El callback ya muestra el mensaje del backend.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TaggyLogo(),

            const SizedBox(height: 25),

            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mis mascotas',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Administra tus mascotas',
                        style: TextStyle(color: TaggyColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: TaggyColors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${mascotas.length}',
                    style: const TextStyle(
                      color: TaggyColors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Expanded(
              child: mascotas.isEmpty
                  ? const Center(
                      child: Text(
                        'No tienes mascotas registradas.',
                        style: TextStyle(color: TaggyColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: mascotas.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final mascota = mascotas[index];

                        return MascotaListCard(
                          mascota: mascota,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetalleMascotaPage(
                                  mascota: mascota,
                                  onEditar: (actualizada) {
                                    return onEditarMascota(index, actualizada);
                                  },
                                  onEliminar: () {
                                    return onEliminarMascota(index);
                                  },
                                  onEstadoChanged: (estado) {
                                    return onEstadoExtravio(index, estado);
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () {
                  abrirAgregarMascota(context);
                },
                icon: const Icon(Icons.add),
                label: const Text(
                  'Agregar mascota',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// AGREGAR MASCOTA
// ======================================================

class AgregarMascotaPage extends StatefulWidget {
  const AgregarMascotaPage({super.key});

  @override
  State<AgregarMascotaPage> createState() => _AgregarMascotaPageState();
}

class _AgregarMascotaPageState extends State<AgregarMascotaPage> {
  final formKey = GlobalKey<FormState>();

  final nombreController = TextEditingController();

  final razaController = TextEditingController();

  final edadController = TextEditingController();

  final colorController = TextEditingController();

  final pesoController = TextEditingController();

  String especie = 'Perro';
  String sexo = 'Macho';
  String? imagenPath;

  Future<void> agregarFoto() async {
    final nuevaImagen = await seleccionarYGuardarImagen(context);

    if (nuevaImagen == null || !mounted) {
      return;
    }

    setState(() {
      imagenPath = nuevaImagen;
    });
  }

  void guardar() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    final codigo = timestamp.substring(timestamp.length - 6);

    final mascota = Mascota(
      nombre: nombreController.text.trim(),
      especie: especie,
      raza: razaController.text.trim(),
      edad: edadController.text.trim(),
      sexo: sexo,
      color: colorController.text.trim(),
      peso: pesoController.text.trim(),
      idTaggy: 'TAGGY-$codigo',
      imagenPath: imagenPath,
    );

    Navigator.pop(context, mascota);
  }

  @override
  void dispose() {
    nombreController.dispose();
    razaController.dispose();
    edadController.dispose();
    colorController.dispose();
    pesoController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva mascota')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: agregarFoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        PetAvatar(size: 118, imagenPath: imagenPath),
                        Positioned(
                          right: -2,
                          bottom: 2,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: TaggyColors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: TaggyColors.background,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: agregarFoto,
                    icon: Icon(
                      imagenPath == null
                          ? Icons.add_photo_alternate_outlined
                          : Icons.edit_outlined,
                    ),
                    label: Text(
                      imagenPath == null ? 'Agregar foto' : 'Cambiar foto',
                    ),
                  ),
                  const Text(
                    'Puedes elegir una imagen de tu galerÃ­a o usar la cÃ¡mara.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: TaggyColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            CampoMascota(
              controller: nombreController,
              label: 'Nombre',
              icono: Icons.pets,
              requerido: true,
            ),

            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              initialValue: especie,
              decoration: const InputDecoration(
                labelText: 'Especie',
                prefixIcon: Icon(Icons.pets),
              ),
              items: const [
                DropdownMenuItem(value: 'Perro', child: Text('Perro')),
                DropdownMenuItem(value: 'Gato', child: Text('Gato')),
                DropdownMenuItem(value: 'Otro', child: Text('Otro')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    especie = value;
                  });
                }
              },
            ),

            const SizedBox(height: 15),

            CampoMascota(
              controller: razaController,
              label: 'Raza',
              icono: Icons.category_outlined,
              requerido: true,
            ),

            const SizedBox(height: 15),

            CampoMascota(
              controller: edadController,
              label: 'Edad',
              hint: 'Ejemplo: 3 aÃ±os',
              icono: Icons.cake_outlined,
            ),

            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              initialValue: sexo,
              decoration: const InputDecoration(
                labelText: 'Sexo',
                prefixIcon: Icon(Icons.info_outline),
              ),
              items: const [
                DropdownMenuItem(value: 'Macho', child: Text('Macho')),
                DropdownMenuItem(value: 'Hembra', child: Text('Hembra')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    sexo = value;
                  });
                }
              },
            ),

            const SizedBox(height: 15),

            CampoMascota(
              controller: colorController,
              label: 'Color',
              icono: Icons.palette_outlined,
            ),

            const SizedBox(height: 15),

            CampoMascota(
              controller: pesoController,
              label: 'Peso',
              hint: 'Ejemplo: 28 kg',
              icono: Icons.monitor_weight_outlined,
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 55,
              child: FilledButton.icon(
                onPressed: guardar,
                icon: const Icon(Icons.save),
                label: const Text(
                  'Guardar mascota',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// DETALLE
// ======================================================

class DetalleMascotaPage extends StatefulWidget {
  final Mascota mascota;

  final Future<void> Function(Mascota mascota) onEditar;

  final Future<void> Function() onEliminar;

  final Future<void> Function(bool estado) onEstadoChanged;

  const DetalleMascotaPage({
    super.key,
    required this.mascota,
    required this.onEditar,
    required this.onEliminar,
    required this.onEstadoChanged,
  });

  @override
  State<DetalleMascotaPage> createState() => _DetalleMascotaPageState();
}

class _DetalleMascotaPageState extends State<DetalleMascotaPage> {
  late Mascota mascota;

  @override
  void initState() {
    super.initState();
    mascota = widget.mascota;
  }

  Future<void> editar() async {
    final actualizada = await Navigator.push<Mascota>(
      context,
      MaterialPageRoute(builder: (_) => EditarMascotaPage(mascota: mascota)),
    );

    if (actualizada == null) {
      return;
    }

    try {
      await widget.onEditar(actualizada);

      if (mounted) {
        setState(() {
          mascota = actualizada;
        });
      }
    } catch (_) {
      // El callback ya muestra el error.
    }
  }

  Future<void> cambiarExtravio() async {
    final nuevoEstado = !mascota.extraviada;

    try {
      await widget.onEstadoChanged(nuevoEstado);

      if (mounted) {
        setState(() {
          mascota = mascota.copyWith(extraviada: nuevoEstado);
        });
      }
    } catch (_) {
      // El callback ya muestra el error.
    }
  }

  Future<void> eliminar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: TaggyColors.surface,
          title: const Text('Eliminar mascota'),
          content: Text('Â¿Seguro que deseas eliminar a ${mascota.nombre}?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: TaggyColors.red),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmado != true) {
      return;
    }

    try {
      await widget.onEliminar();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      // El callback ya muestra el error.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(mascota.nombre)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: PetAvatar(size: 120, imagenPath: mascota.imagenPath)),

          const SizedBox(height: 20),

          Center(
            child: Text(
              mascota.nombre,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 8),

          Center(child: StatusBadge(extraviada: mascota.extraviada)),

          const SizedBox(height: 30),

          InfoCard(
            icono: Icons.category,
            titulo: 'Raza',
            valor: valorSeguro(mascota.raza),
          ),

          InfoCard(
            icono: Icons.cake,
            titulo: 'Edad',
            valor: valorSeguro(mascota.edad),
          ),

          InfoCard(
            icono: Icons.info_outline,
            titulo: 'Sexo',
            valor: valorSeguro(mascota.sexo),
          ),

          InfoCard(
            icono: Icons.palette,
            titulo: 'Color',
            valor: valorSeguro(mascota.color),
          ),

          InfoCard(
            icono: Icons.monitor_weight,
            titulo: 'Peso',
            valor: valorSeguro(mascota.peso),
          ),

          InfoCard(
            icono: Icons.badge,
            titulo: 'ID TAGGY',
            valor: mascota.idTaggy,
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: editar,
              icon: const Icon(Icons.edit),
              label: const Text('Editar mascota'),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 52,
            child: FilledButton.tonalIcon(
              onPressed: cambiarExtravio,
              icon: Icon(
                mascota.extraviada ? Icons.check_circle : Icons.warning_amber,
              ),
              label: Text(
                mascota.extraviada
                    ? 'Marcar como encontrada'
                    : 'Marcar como extraviada',
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: TaggyColors.red,
                side: const BorderSide(color: TaggyColors.red),
              ),
              onPressed: eliminar,
              icon: const Icon(Icons.delete),
              label: const Text('Eliminar mascota'),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// EDITAR MASCOTA
// ======================================================

class EditarMascotaPage extends StatefulWidget {
  final Mascota mascota;

  const EditarMascotaPage({super.key, required this.mascota});

  @override
  State<EditarMascotaPage> createState() => _EditarMascotaPageState();
}

class _EditarMascotaPageState extends State<EditarMascotaPage> {
  final formKey = GlobalKey<FormState>();

  late TextEditingController nombreController;
  late TextEditingController razaController;
  late TextEditingController edadController;
  late TextEditingController colorController;
  late TextEditingController pesoController;

  late String especie;
  late String sexo;
  String? imagenPath;

  @override
  void initState() {
    super.initState();

    nombreController = TextEditingController(text: widget.mascota.nombre);

    razaController = TextEditingController(text: widget.mascota.raza);

    edadController = TextEditingController(text: widget.mascota.edad);

    colorController = TextEditingController(text: widget.mascota.color);

    pesoController = TextEditingController(text: widget.mascota.peso);

    especie = widget.mascota.especie.isEmpty ? 'Perro' : widget.mascota.especie;

    sexo = widget.mascota.sexo == 'Hembra' ? 'Hembra' : 'Macho';

    imagenPath = widget.mascota.imagenPath;
  }

  Future<void> cambiarFoto() async {
    final nuevaImagen = await seleccionarYGuardarImagen(context);

    if (nuevaImagen == null || !mounted) {
      return;
    }

    setState(() {
      imagenPath = nuevaImagen;
    });
  }

  void guardar() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final actualizada = widget.mascota.copyWith(
      nombre: nombreController.text.trim(),
      especie: especie,
      raza: razaController.text.trim(),
      edad: edadController.text.trim(),
      sexo: sexo,
      color: colorController.text.trim(),
      peso: pesoController.text.trim(),
      imagenPath: imagenPath,
    );

    Navigator.pop(context, actualizada);
  }

  @override
  void dispose() {
    nombreController.dispose();
    razaController.dispose();
    edadController.dispose();
    colorController.dispose();
    pesoController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar mascota')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: cambiarFoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        PetAvatar(size: 112, imagenPath: imagenPath),
                        Positioned(
                          right: -2,
                          bottom: 2,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: TaggyColors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: TaggyColors.background,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: cambiarFoto,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      imagenPath == null ? 'Agregar foto' : 'Cambiar foto',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            CampoMascota(
              controller: nombreController,
              label: 'Nombre',
              icono: Icons.pets,
              requerido: true,
            ),

            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              initialValue: especie,
              decoration: const InputDecoration(
                labelText: 'Especie',
                prefixIcon: Icon(Icons.pets),
              ),
              items: const [
                DropdownMenuItem(value: 'Perro', child: Text('Perro')),
                DropdownMenuItem(value: 'Gato', child: Text('Gato')),
                DropdownMenuItem(value: 'Otro', child: Text('Otro')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    especie = value;
                  });
                }
              },
            ),

            const SizedBox(height: 15),

            CampoMascota(
              controller: razaController,
              label: 'Raza',
              icono: Icons.category_outlined,
              requerido: true,
            ),

            const SizedBox(height: 15),

            CampoMascota(
              controller: edadController,
              label: 'Edad',
              icono: Icons.cake_outlined,
            ),

            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              initialValue: sexo,
              decoration: const InputDecoration(
                labelText: 'Sexo',
                prefixIcon: Icon(Icons.info_outline),
              ),
              items: const [
                DropdownMenuItem(value: 'Macho', child: Text('Macho')),
                DropdownMenuItem(value: 'Hembra', child: Text('Hembra')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    sexo = value;
                  });
                }
              },
            ),

            const SizedBox(height: 15),

            CampoMascota(
              controller: colorController,
              label: 'Color',
              icono: Icons.palette_outlined,
            ),

            const SizedBox(height: 15),

            CampoMascota(
              controller: pesoController,
              label: 'Peso',
              icono: Icons.monitor_weight_outlined,
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: guardar,
                icon: const Icon(Icons.save),
                label: const Text('Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// UBICACIÃ“N
// ======================================================

class UbicacionPage extends StatefulWidget {
  final List<Mascota> mascotas;

  const UbicacionPage({super.key, required this.mascotas});

  @override
  State<UbicacionPage> createState() => _UbicacionPageState();
}

class _UbicacionPageState extends State<UbicacionPage> {
  Timer? _timerUbicacion;
  Mascota? mascotaSeleccionada;
  Map<String, dynamic>? datosUbicacion;
  Map<String, dynamic>? geocerca;
  bool guardandoZona = false;
  bool seleccionandoCentroZona = false;
  List<Map<String, dynamic>> historialUbicaciones = [];
  int? horasHistorial;
  bool cargandoHistorial = false;

  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();

    _timerUbicacion = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || cargando) {
        return;
      }

      if (mascotaSeleccionada != null) {
        cargarUbicacion();
      }
    });

    if (widget.mascotas.isNotEmpty) {
      mascotaSeleccionada = widget.mascotas.first;
      cargarUbicacion();
    } else {
      cargando = false;
    }
  }

  @override
  void didUpdateWidget(covariant UbicacionPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.mascotas.isEmpty) {
      setState(() {
        mascotaSeleccionada = null;
        datosUbicacion = null;
        cargando = false;
        error = null;
      });

      return;
    }

    final idActual = mascotaSeleccionada?.id;

    final sigueExistiendo = widget.mascotas.any(
      (mascota) => mascota.id == idActual,
    );

    if (!sigueExistiendo) {
      mascotaSeleccionada = widget.mascotas.first;
      cargarUbicacion();
    }
  }

  @override
  void dispose() {
    _timerUbicacion?.cancel();
    super.dispose();
  }

  Future<void> cargarUbicacion() async {
    final mascota = mascotaSeleccionada;

    if (mascota == null || mascota.id == null) {
      if (!mounted) return;

      setState(() {
        cargando = false;
        datosUbicacion = null;
        error = 'La mascota todavÃ­a no tiene un ID vÃ¡lido.';
      });

      return;
    }

    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final datos = await ApiService.obtenerUltimaUbicacion(mascota.id!);

      Map<String, dynamic>? zona;

      try {
        zona = await ApiService.obtenerGeocerca(mascota.id!);
      } catch (_) {
        zona = geocerca;
      }

      if (!mounted) return;

      setState(() {
        datosUbicacion = datos;
        geocerca = zona;
        cargando = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        datosUbicacion = null;
        cargando = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> cargarHistorial() async {
    final mascota = mascotaSeleccionada;
    final horas = horasHistorial;

    if (mascota == null || mascota.id == null || horas == null) {
      return;
    }

    setState(() {
      cargandoHistorial = true;
    });

    try {
      final datos = await ApiService.obtenerHistorialUbicaciones(
        mascota.id!,
        horas: horas,
      );

      if (!mounted) return;

      setState(() {
        historialUbicaciones = datos;
        cargandoHistorial = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        historialUbicaciones = [];
        cargandoHistorial = false;
      });

      debugPrint('ERROR HISTORIAL GPS: $e');
    }
  }

  Future<void> seleccionarPeriodo(int? horas) async {
    setState(() {
      horasHistorial = horas;

      if (horas == null) {
        historialUbicaciones = [];
        cargandoHistorial = false;
      }
    });

    if (horas != null) {
      await cargarHistorial();
    }
  }

  DateTime? _parsearFecha(dynamic valor) {
    if (valor == null) return null;

    try {
      return DateTime.parse(valor.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _tiempoRelativo(DateTime? fecha) {
    if (fecha == null) {
      return 'Sin dato';
    }

    var diferencia = DateTime.now().difference(fecha);

    if (diferencia.isNegative) {
      diferencia = Duration.zero;
    }

    if (diferencia.inSeconds < 60) {
      return 'Ahora';
    }

    if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} min';
    }

    if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours} h';
    }

    if (diferencia.inDays == 1) {
      return 'Ayer';
    }

    return 'Hace ${diferencia.inDays} dÃ­as';
  }

  String _textoBateria(dynamic bateria) {
    if (bateria == null) {
      return 'Sin dato';
    }

    final numero = num.tryParse(bateria.toString());

    if (numero == null) {
      return 'Sin dato';
    }

    return '${numero.round()}%';
  }

  bool _conexionReciente(DateTime? fecha) {
    if (fecha == null) {
      return false;
    }

    final diferencia = DateTime.now().difference(fecha);

    return !diferencia.isNegative && diferencia.inMinutes <= 10;
  }

  void _activarSeleccionCentroZona() {
    setState(() {
      seleccionandoCentroZona = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Toca en el mapa donde quieres colocar Casa.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _abrirConfigZonaSegura([LatLng? centroElegido]) async {
    final mascota = mascotaSeleccionada;
    final mascotaId = mascota?.id;

    if (mascotaId == null) {
      return;
    }

    final raw = datosUbicacion?['ubicacion'];

    final latitud =
        centroElegido?.latitude ??
        (raw is Map ? double.tryParse(raw['latitud']?.toString() ?? '') : null);

    final longitud =
        centroElegido?.longitude ??
        (raw is Map
            ? double.tryParse(raw['longitud']?.toString() ?? '')
            : null);

    if (latitud == null || longitud == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener una ubicaciÃ³n vÃ¡lida.'),
        ),
      );

      return;
    }

    int radioSeleccionado =
        int.tryParse(geocerca?['radio_metros']?.toString() ?? '') ?? 100;

    final guardar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: TaggyColors.blue),
                        SizedBox(width: 10),
                        Text(
                          'Configurar zona segura',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'El punto elegido en el mapa serÃ¡ el centro de la zona segura.',
                      style: const TextStyle(color: TaggyColors.textSecondary),
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      'Radio de seguridad',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final radio in [50, 100, 200, 500])
                          ChoiceChip(
                            label: Text('$radio m'),
                            selected: radioSeleccionado == radio,
                            onSelected: (_) {
                              setModalState(() {
                                radioSeleccionado = radio;
                              });
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Guardar zona segura'),
                      ),
                    ),

                    const SizedBox(height: 6),

                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context, false);
                        },
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (guardar != true || !mounted) {
      return;
    }

    setState(() {
      guardandoZona = true;
    });

    try {
      final zona = await ApiService.guardarGeocerca(
        mascotaId: mascotaId,
        latitud: latitud,
        longitud: longitud,
        radioMetros: radioSeleccionado,
        nombre: 'Casa',
      );

      if (!mounted) return;

      setState(() {
        geocerca = zona;
        guardandoZona = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zona segura de $radioSeleccionado m guardada.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        guardandoZona = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  LatLng? _centroZonaSegura() {
    final zona = geocerca;

    if (zona == null) {
      return null;
    }

    final latitud = double.tryParse(zona['latitud']?.toString() ?? '');

    final longitud = double.tryParse(zona['longitud']?.toString() ?? '');

    if (latitud == null || longitud == null) {
      return null;
    }

    return LatLng(latitud, longitud);
  }

  @override
  Widget build(BuildContext context) {
    final ubicacionRaw = datosUbicacion?['ubicacion'];

    final dispositivoRaw = datosUbicacion?['dispositivo'];

    final ubicacion = ubicacionRaw is Map
        ? Map<String, dynamic>.from(ubicacionRaw)
        : <String, dynamic>{};

    final dispositivo = dispositivoRaw is Map
        ? Map<String, dynamic>.from(dispositivoRaw)
        : <String, dynamic>{};

    final latitud = ubicacion['latitud']?.toString();

    final longitud = ubicacion['longitud']?.toString();

    final altitud = ubicacion['altitud']?.toString();

    final fechaRecepcion = _parsearFecha(ubicacion['fecha_recepcion']);

    final ultimaConexion = _parsearFecha(dispositivo['ultima_conexion']);

    final tieneUbicacion =
        latitud != null &&
        latitud.isNotEmpty &&
        longitud != null &&
        longitud.isNotEmpty;

    final cuatroGConectado = _conexionReciente(ultimaConexion);

    final modo = dispositivo['modo']?.toString().trim() ?? '';

    final bateria = _textoBateria(dispositivo['bateria']);
    final puntosHistorial = <LatLng>[];

    for (final punto in historialUbicaciones) {
      final lat = double.tryParse(punto['latitud']?.toString() ?? '');

      final lon = double.tryParse(punto['longitud']?.toString() ?? '');

      if (lat != null && lon != null) {
        puntosHistorial.add(LatLng(lat, lon));
      }
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: cargarUbicacion,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const TaggyLogo(),

            const SizedBox(height: 25),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'UbicaciÃ³n',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar ubicaciÃ³n',
                  onPressed: cargando ? null : cargarUbicacion,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),

            const SizedBox(height: 5),

            const Text(
              'Seguimiento GPS real del collar',
              style: TextStyle(color: TaggyColors.textSecondary),
            ),

            const SizedBox(height: 18),

            if (widget.mascotas.length > 1)
              DropdownButtonFormField<Mascota>(
                value: mascotaSeleccionada,
                decoration: const InputDecoration(
                  labelText: 'Mascota',
                  prefixIcon: Icon(Icons.pets),
                ),
                items: widget.mascotas
                    .map(
                      (mascota) => DropdownMenuItem<Mascota>(
                        value: mascota,
                        child: Text(mascota.nombre),
                      ),
                    )
                    .toList(),
                onChanged: (mascota) {
                  if (mascota == null) return;

                  setState(() {
                    mascotaSeleccionada = mascota;
                  });

                  cargarUbicacion();
                },
              ),

            if (widget.mascotas.length > 1) const SizedBox(height: 18),

            if (widget.mascotas.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: TaggyColors.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.pets_outlined,
                      size: 45,
                      color: TaggyColors.textSecondary,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Agrega una mascota para consultar su ubicaciÃ³n.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: TaggyColors.textSecondary),
                    ),
                  ],
                ),
              )
            else if (cargando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: TaggyColors.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      size: 48,
                      color: TaggyColors.orange,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: TaggyColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: cargarUbicacion,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            else ...[
              if (tieneUbicacion) ...[
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<int>(value: 0, label: Text('Ahora')),
                    ButtonSegment<int>(value: 24, label: Text('24 h')),
                    ButtonSegment<int>(value: 168, label: Text('7 dÃ­as')),
                  ],
                  selected: <int>{horasHistorial ?? 0},
                  onSelectionChanged: (seleccion) {
                    final valor = seleccion.first;

                    seleccionarPeriodo(valor == 0 ? null : valor);
                  },
                ),

                const SizedBox(height: 12),

                if (horasHistorial != null)
                  Text(
                    cargandoHistorial
                        ? 'Cargando historial...'
                        : 'Historial del recorrido: ${puntosHistorial.length} puntos GPS',
                    style: const TextStyle(
                      color: TaggyColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),

                if (horasHistorial != null) const SizedBox(height: 10),

                if (cargandoHistorial) const LinearProgressIndicator(),

                if (cargandoHistorial) const SizedBox(height: 10),

                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 350,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: TaggyColors.blue.withValues(alpha: 0.35),
                      ),
                    ),
                    child: FlutterMap(
                      key: ValueKey('map-$latitud-$longitud'),
                      options: MapOptions(
                        initialCenter: LatLng(
                          double.parse(latitud!),
                          double.parse(longitud!),
                        ),
                        initialZoom: 17,
                        minZoom: 3,
                        maxZoom: 19,
                        onTap: (tapPosition, point) {
                          if (!seleccionandoCentroZona) {
                            return;
                          }

                          setState(() {
                            seleccionandoCentroZona = false;
                          });

                          _abrirConfigZonaSegura(point);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.taggy.app',
                          maxNativeZoom: 19,
                        ),
                        // RECORRIDO HISTORICO TAGGY
                        if (puntosHistorial.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: puntosHistorial,
                                strokeWidth: 5,
                                color: TaggyColors.cyan,
                              ),
                            ],
                          ),

                        if (puntosHistorial.isNotEmpty)
                          MarkerLayer(
                            markers: [
                              if (_centroZonaSegura() != null)
                                Marker(
                                  key: const ValueKey('taggy-marcador-casa'),
                                  point: _centroZonaSegura()!,
                                  width: 52,
                                  height: 52,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: TaggyColors.green,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.20,
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.home_rounded,
                                      color: TaggyColors.green,
                                      size: 28,
                                    ),
                                  ),
                                ),

                              Marker(
                                point: puntosHistorial.first,
                                width: 42,
                                height: 42,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: TaggyColors.green,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.flag_rounded,
                                    color: Colors.white,
                                    size: 21,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                double.parse(latitud!),
                                double.parse(longitud!),
                              ),
                              width: 76,
                              height: 76,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: mascotaSeleccionada?.extraviada == true
                                      ? TaggyColors.red
                                      : TaggyColors.blue,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.pets,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 7),

                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Â© OpenStreetMap contributors',
                    style: TextStyle(
                      color: TaggyColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],

              Row(
                children: [
                  Expanded(
                    child: MiniStatusCard(
                      icono: Icons.gps_fixed,
                      titulo: 'GPS',
                      valor: tieneUbicacion ? 'Activo' : 'Sin seÃ±al',
                      color: tieneUbicacion
                          ? TaggyColors.green
                          : TaggyColors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MiniStatusCard(
                      icono: Icons.signal_cellular_alt,
                      titulo: '4G',
                      valor: cuatroGConectado ? 'Conectado' : 'Sin reporte',
                      color: cuatroGConectado
                          ? TaggyColors.blue
                          : TaggyColors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MiniStatusCard(
                      icono: Icons.battery_5_bar,
                      titulo: 'BaterÃ­a',
                      valor: bateria,
                      color: TaggyColors.cyan,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TaggyColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: TaggyColors.blue.withValues(alpha: 0.16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: TaggyColors.blue.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: TaggyColors.blue,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Zona segura',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                geocerca == null
                                    ? 'Sin configurar'
                                    : '${geocerca?['nombre'] ?? 'Casa'} Â· ${geocerca?['radio_metros'] ?? 100} m',
                                style: TextStyle(
                                  color: TaggyColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: guardandoZona
                            ? null
                            : _activarSeleccionCentroZona,
                        icon: const Icon(Icons.edit_location_alt_outlined),
                        label: Text(
                          guardandoZona
                              ? 'Guardando...'
                              : geocerca == null
                              ? 'Configurar zona segura'
                              : 'Editar zona segura',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              InfoCard(
                icono: Icons.access_time,
                titulo: 'Ãšltima ubicaciÃ³n',
                valor: _tiempoRelativo(fechaRecepcion),
              ),

              InfoCard(
                icono: Icons.router_outlined,
                titulo: 'Ãšltima conexiÃ³n del collar',
                valor: _tiempoRelativo(ultimaConexion),
              ),

              InfoCard(
                icono: Icons.settings_remote_outlined,
                titulo: 'Modo del collar',
                valor: modo.isEmpty ? 'Sin dato' : modo,
              ),

              const SizedBox(height: 8),

              const Text(
                'Desliza hacia abajo o usa el botÃ³n de actualizar para consultar la posiciÃ³n mÃ¡s reciente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TaggyColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// ALERTAS
// ======================================================

class _TaggyAlerta {
  final String tipo;
  final String titulo;
  final String descripcion;
  final DateTime fecha;
  final IconData icono;
  final Color color;

  const _TaggyAlerta({
    required this.tipo,
    required this.titulo,
    required this.descripcion,
    required this.fecha,
    required this.icono,
    required this.color,
  });
}

class AlertasPage extends StatefulWidget {
  final List<Mascota> mascotas;

  const AlertasPage({super.key, required this.mascotas});

  @override
  State<AlertasPage> createState() => _AlertasPageState();
}

class _AlertasPageState extends State<AlertasPage> {
  bool cargando = true;
  String? error;
  List<_TaggyAlerta> alertas = [];

  @override
  void initState() {
    super.initState();
    cargarAlertas();
  }

  @override
  void didUpdateWidget(covariant AlertasPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final idsAnteriores = oldWidget.mascotas
        .map((mascota) => mascota.id)
        .whereType<int>()
        .join(',');

    final idsActuales = widget.mascotas
        .map((mascota) => mascota.id)
        .whereType<int>()
        .join(',');

    if (idsAnteriores != idsActuales) {
      cargarAlertas();
    }
  }

  Future<void> cargarAlertas() async {
    if (mounted && alertas.isEmpty) {
      setState(() {
        cargando = true;
        error = null;
      });
    }

    try {
      final nuevasAlertas = <_TaggyAlerta>[];

      for (final mascota in widget.mascotas) {
        if (mascota.id == null) {
          continue;
        }

        // ==================================================
        // EVENTOS REALES GUARDADOS EN POSTGRESQL
        // ==================================================

        try {
          final eventos = await ApiService.obtenerEventosMascota(mascota.id!);

          for (final evento in eventos) {
            nuevasAlertas.add(_crearAlerta(evento: evento, mascota: mascota));
          }
        } catch (e) {
          debugPrint(
            'No se pudieron cargar eventos de '
            '${mascota.nombre}: $e',
          );
        }

        // ==================================================
        // ESTADO ACTUAL REAL DEL COLLAR
        // ==================================================

        try {
          final estado = await ApiService.obtenerEstadoActualCollar(
            mascota.id!,
          );

          final dispositivoRaw = estado['dispositivo'];

          if (dispositivoRaw is Map) {
            final dispositivo = Map<String, dynamic>.from(dispositivoRaw);

            // ==============================================
            // BATERIA BAJA
            // ==============================================

            final bateria = int.tryParse(
              dispositivo['bateria']?.toString() ?? '',
            );

            final ultimaConexionTexto = dispositivo['ultima_conexion']
                ?.toString();

            DateTime? ultimaConexion;

            if (ultimaConexionTexto != null && ultimaConexionTexto.isNotEmpty) {
              ultimaConexion = DateTime.tryParse(ultimaConexionTexto)
                  ?.toLocal();
            }

            if (bateria != null && bateria <= 20) {
              nuevasAlertas.add(
                _TaggyAlerta(
                  tipo: 'BATERIA_BAJA_ACTUAL',
                  titulo: bateria <= 10 ? 'BaterÃ­a crÃ­tica' : 'BaterÃ­a baja',
                  descripcion:
                      'El collar de ${mascota.nombre} '
                      'tiene $bateria% de baterÃ­a.',
                  fecha: ultimaConexion ?? DateTime.now(),
                  icono: Icons.battery_alert_rounded,
                  color: bateria <= 10 ? TaggyColors.red : TaggyColors.orange,
                ),
              );
            }

            // ==============================================
            // COLLAR OFFLINE
            // ==============================================

            final modo =
                dispositivo['modo']?.toString().toLowerCase() ?? 'normal';

            Duration limiteOffline;

            switch (modo) {
              case 'extravio':
                limiteOffline = const Duration(minutes: 2);
                break;

              case 'mantenimiento':
                limiteOffline = const Duration(minutes: 30);
                break;

              default:
                limiteOffline = const Duration(minutes: 7);
            }

            if (ultimaConexion != null) {
              final diferencia = DateTime.now().difference(ultimaConexion);

              if (diferencia > limiteOffline) {
                nuevasAlertas.add(
                  _TaggyAlerta(
                    tipo: 'COLLAR_OFFLINE',
                    titulo: 'Collar sin conexiÃ³n',
                    descripcion:
                        'TAGGY no ha recibido datos '
                        'del collar de '
                        '${mascota.nombre} durante '
                        '${_duracionOffline(diferencia)}.',
                    fecha: ultimaConexion,
                    icono: Icons.signal_wifi_connected_no_internet_4_rounded,
                    color: TaggyColors.red,
                  ),
                );
              }
            }
          }
        } catch (e) {
          debugPrint(
            'No se pudo comprobar el estado de '
            '${mascota.nombre}: $e',
          );
        }
      }

      nuevasAlertas.sort((a, b) => b.fecha.compareTo(a.fecha));

      if (!mounted) {
        return;
      }

      setState(() {
        alertas = nuevasAlertas;
        cargando = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        cargando = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _duracionOffline(Duration diferencia) {
    if (diferencia.inMinutes < 60) {
      return '${diferencia.inMinutes} minutos';
    }

    if (diferencia.inHours < 24) {
      return '${diferencia.inHours} horas';
    }

    return '${diferencia.inDays} dÃ­as';
  }

  _TaggyAlerta _crearAlerta({
    required Map<String, dynamic> evento,
    required Mascota mascota,
  }) {
    final tipo = evento['tipo']?.toString().toUpperCase() ?? 'EVENTO';

    final descripcionServidor = evento['descripcion']?.toString().trim() ?? '';

    final datosRaw = evento['datos'];
    final datos = datosRaw is Map
        ? Map<String, dynamic>.from(datosRaw)
        : <String, dynamic>{};

    final fecha = _parsearFecha(
      evento['fecha_evento'] ?? evento['fecha_recepcion'],
    );

    switch (tipo) {
      case 'QR_SCAN':
        return _TaggyAlerta(
          tipo: tipo,
          titulo: 'CÃ³digo QR escaneado',
          descripcion:
              'Se consultÃ³ el perfil pÃºblico de ${mascota.nombre} mediante su cÃ³digo QR.',
          fecha: fecha,
          icono: Icons.qr_code_2_rounded,
          color: TaggyColors.cyan,
        );

      case 'AVISTAMIENTO':
        final nombre = datos['nombre_reportante']?.toString().trim() ?? '';

        final telefono = datos['telefono_reportante']?.toString().trim() ?? '';

        final mensaje = datos['mensaje']?.toString().trim() ?? '';

        final latitud = evento['latitud'];
        final longitud = evento['longitud'];

        final partes = <String>[];

        partes.add(
          '${nombre.isEmpty ? 'Alguien' : nombre} reportÃ³ un avistamiento de ${mascota.nombre}.',
        );

        if (telefono.isNotEmpty) {
          partes.add('TelÃ©fono: $telefono.');
        }

        if (mensaje.isNotEmpty) {
          partes.add('Mensaje: $mensaje.');
        }

        if (latitud != null && longitud != null) {
          partes.add(
            'UbicaciÃ³n: ${latitud.toString()}, ${longitud.toString()}.',
          );
        }

        return _TaggyAlerta(
          tipo: tipo,
          titulo: 'Avistamiento reportado',
          descripcion: partes.join(' '),
          fecha: fecha,
          icono: Icons.visibility_outlined,
          color: TaggyColors.orange,
        );

      case 'MODO_EXTRAVIO':
        final activado = datos['extraviada'] == true;
        final esHembra = mascota.sexo.trim().toLowerCase() == 'hembra';

        return _TaggyAlerta(
          tipo: tipo,
          titulo: activado
              ? 'Modo extravÃ­o activado'
              : 'Modo extravÃ­o desactivado',
          descripcion: activado
              ? '${mascota.nombre} fue marcada como ${esHembra ? 'extraviada' : 'extraviado'}.'
              : '${mascota.nombre} fue marcada como ${esHembra ? 'encontrada' : 'encontrado'}.',
          fecha: fecha,
          icono: activado
              ? Icons.warning_amber_rounded
              : Icons.check_circle_outline_rounded,
          color: activado ? TaggyColors.red : TaggyColors.green,
        );

      case 'MANIPULACION':
        return _TaggyAlerta(
          tipo: tipo,
          titulo: 'Posible manipulaciÃ³n',
          descripcion: descripcionServidor.isNotEmpty
              ? descripcionServidor
              : 'El collar de ${mascota.nombre} detectÃ³ una posible manipulaciÃ³n.',
          fecha: fecha,
          icono: Icons.shield_outlined,
          color: TaggyColors.red,
        );

      case 'BATERIA_BAJA':
      case 'LOW_BATTERY':
        return _TaggyAlerta(
          tipo: tipo,
          titulo: 'BaterÃ­a baja',
          descripcion: descripcionServidor.isNotEmpty
              ? descripcionServidor
              : 'El collar de ${mascota.nombre} reportÃ³ baterÃ­a baja.',
          fecha: fecha,
          icono: Icons.battery_alert_rounded,
          color: TaggyColors.orange,
        );

      case 'UBICACION':
      case 'LOCATION':
        return _TaggyAlerta(
          tipo: tipo,
          titulo: 'Nueva ubicaciÃ³n',
          descripcion: descripcionServidor.isNotEmpty
              ? descripcionServidor
              : 'Se recibiÃ³ una nueva ubicaciÃ³n de ${mascota.nombre}.',
          fecha: fecha,
          icono: Icons.location_on_outlined,
          color: TaggyColors.blue,
        );

      default:
        return _TaggyAlerta(
          tipo: tipo,
          titulo: tipo
              .replaceAll('_', ' ')
              .toLowerCase()
              .split(' ')
              .where((parte) => parte.isNotEmpty)
              .map((parte) => '${parte[0].toUpperCase()}${parte.substring(1)}')
              .join(' '),
          descripcion: descripcionServidor.isNotEmpty
              ? descripcionServidor
              : 'Se registrÃ³ actividad de ${mascota.nombre}.',
          fecha: fecha,
          icono: Icons.notifications_outlined,
          color: TaggyColors.blue,
        );
    }
  }

  DateTime _parsearFecha(dynamic valor) {
    if (valor == null) {
      return DateTime.now();
    }

    try {
      return DateTime.parse(valor.toString()).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  String _tiempoRelativo(DateTime fecha) {
    var diferencia = DateTime.now().difference(fecha);

    if (diferencia.isNegative) {
      diferencia = Duration.zero;
    }

    if (diferencia.inSeconds < 60) {
      return 'Ahora';
    }

    if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} min';
    }

    if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours} h';
    }

    if (diferencia.inDays == 1) {
      return 'Ayer';
    }

    if (diferencia.inDays < 7) {
      return 'Hace ${diferencia.inDays} dÃ­as';
    }

    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    final algunaExtraviada = widget.mascotas.any(
      (mascota) => mascota.extraviada,
    );

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: cargarAlertas,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const TaggyLogo(),

            const SizedBox(height: 25),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Alertas',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar alertas',
                  onPressed: cargarAlertas,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),

            const SizedBox(height: 5),

            const Text(
              'Actividad real registrada por TAGGY',
              style: TextStyle(color: TaggyColors.textSecondary),
            ),

            const SizedBox(height: 22),

            if (algunaExtraviada)
              const AlertaCard(
                icono: Icons.warning_amber_rounded,
                titulo: 'Modo extravÃ­o activo',
                descripcion:
                    'Una de tus mascotas estÃ¡ marcada como extraviada.',
                color: TaggyColors.red,
                tiempo: 'Ahora',
              ),

            if (cargando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 35),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: TaggyColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 38,
                      color: TaggyColors.orange,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: TaggyColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: cargarAlertas,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            else if (alertas.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: TaggyColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 45,
                      color: TaggyColors.textSecondary,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'TodavÃ­a no hay actividad registrada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: TaggyColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ...alertas.map(
                (alerta) => AlertaCard(
                  icono: alerta.icono,
                  titulo: alerta.titulo,
                  descripcion: alerta.descripcion,
                  color: alerta.color,
                  tiempo: _tiempoRelativo(alerta.fecha),
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// PERFIL
// ======================================================

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  bool cargando = true;

  String nombre = '';
  String apellido = '';
  String correo = '';
  String telefono = '';

  @override
  void initState() {
    super.initState();
    cargarPerfil();
  }

  Future<void> cargarPerfil() async {
    try {
      final usuario = await ApiService.obtenerPerfil();

      if (!mounted) return;

      setState(() {
        nombre = usuario['nombre']?.toString() ?? '';
        apellido = usuario['apellido']?.toString() ?? '';
        correo = usuario['email']?.toString() ?? '';
        telefono = usuario['telefono']?.toString() ?? '';
        cargando = false;
      });
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        nombre = prefs.getString('taggy_user_name') ?? '';
        apellido = prefs.getString('taggy_user_lastname') ?? '';
        correo = prefs.getString('taggy_user_email') ?? '';
        telefono = prefs.getString('taggy_user_phone') ?? '';
        cargando = false;
      });

      debugPrint('ERROR PERFIL: $e');
    }
  }

  bool activandoNotificaciones = false;
  String estadoNotificaciones = 'Toca para activar';

  Future<void> activarNotificacionesPush() async {
    if (activandoNotificaciones) return;

    setState(() {
      activandoNotificaciones = true;
    });

    try {
      final suscripcion = await PushService.crearSuscripcion();

      await ApiService.registrarSuscripcionPush(suscripcion);

      if (!mounted) return;

      setState(() {
        estadoNotificaciones = 'Activadas';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notificaciones activadas correctamente.'),
        ),
      );

      await ApiService.enviarPushPrueba();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        estadoNotificaciones = 'No activadas';
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudieron activar: $e')));
    } finally {
      if (mounted) {
        setState(() {
          activandoNotificaciones = false;
        });
      }
    }
  }

  Future<void> cerrarSesion() async {
    await ApiService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }

    final nombreCompleto = '$nombre $apellido'.trim();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: cargarPerfil,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const TaggyLogo(),
            const SizedBox(height: 25),
            const Text(
              'Mi perfil',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 25),
            Center(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [TaggyColors.blue, TaggyColors.cyan],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: TaggyColors.blue.withOpacity(0.25),
                      blurRadius: 25,
                    ),
                  ],
                ),
                child: const Icon(Icons.person, size: 60, color: Colors.white),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                nombreCompleto.isEmpty ? 'Usuario TAGGY' : nombreCompleto,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),
            InfoCard(
              icono: Icons.email_outlined,
              titulo: 'Correo',
              valor: correo.isEmpty ? 'Sin correo' : correo,
            ),
            InfoCard(
              icono: Icons.phone_outlined,
              titulo: 'TelÃ©fono',
              valor: telefono.isEmpty ? 'Sin telÃ©fono' : telefono,
            ),
            InfoCard(
              icono: Icons.notifications_outlined,
              titulo: 'Notificaciones',
              valor: estadoNotificaciones,
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: activandoNotificaciones
                    ? null
                    : activarNotificacionesPush,
                icon: activandoNotificaciones
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.notifications_active_outlined),
                label: Text(
                  activandoNotificaciones
                      ? 'Activando...'
                      : 'Activar notificaciones',
                ),
              ),
            ),
            const SizedBox(height: 11),
            const InfoCard(
              icono: Icons.security_outlined,
              titulo: 'Seguridad',
              valor: 'ProtecciÃ³n activa',
            ),
            const SizedBox(height: 25),
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: TaggyColors.red,
                  side: const BorderSide(color: TaggyColors.red),
                ),
                onPressed: cerrarSesion,
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Cerrar sesiÃ³n',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// EXTRAVÃO// ======================================================
// EXTRAVÃO
// ======================================================

class ExtravioPage extends StatefulWidget {
  final Mascota mascota;

  final Future<void> Function(bool estado) onEstadoChanged;

  const ExtravioPage({
    super.key,
    required this.mascota,
    required this.onEstadoChanged,
  });

  @override
  State<ExtravioPage> createState() => _ExtravioPageState();
}

class _ExtravioPageState extends State<ExtravioPage> {
  late bool extraviada;

  @override
  void initState() {
    super.initState();
    extraviada = widget.mascota.extraviada;
  }

  Future<void> cambiarEstado() async {
    final nuevoEstado = !extraviada;

    try {
      await widget.onEstadoChanged(nuevoEstado);

      if (mounted) {
        setState(() {
          extraviada = nuevoEstado;
        });
      }
    } catch (_) {
      // El callback ya muestra el error.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modo extravÃ­o')),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: extraviada
                    ? TaggyColors.red.withOpacity(0.15)
                    : TaggyColors.green.withOpacity(0.15),
              ),
              child: Icon(
                extraviada ? Icons.warning_rounded : Icons.check_circle,
                size: 100,
                color: extraviada ? TaggyColors.red : TaggyColors.green,
              ),
            ),

            const SizedBox(height: 30),

            Text(
              extraviada
                  ? '${widget.mascota.nombre} estÃ¡ ${widget.mascota.sexo.trim().toLowerCase() == 'hembra' ? 'extraviada' : 'extraviado'}'
                  : '${widget.mascota.nombre} estÃ¡ ${widget.mascota.sexo.trim().toLowerCase() == 'hembra' ? 'segura' : 'seguro'}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Text(
              extraviada
                  ? 'El perfil pÃºblico mostrarÃ¡ que la mascota estÃ¡ perdida.'
                  : 'No hay ningÃºn reporte de extravÃ­o activo.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: TaggyColors.textSecondary),
            ),

            const SizedBox(height: 35),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: extraviada
                      ? TaggyColors.green
                      : TaggyColors.red,
                ),
                onPressed: cambiarEstado,
                icon: Icon(extraviada ? Icons.check : Icons.warning),
                label: Text(
                  extraviada
                      ? 'Marcar como encontrada'
                      : 'Marcar como extraviada',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// QR
// ======================================================

class QrPage extends StatefulWidget {
  final Mascota mascota;

  const QrPage({super.key, required this.mascota});

  @override
  State<QrPage> createState() => _QrPageState();
}

class _QrPageState extends State<QrPage> {
  bool cargando = true;
  String? token;
  String? error;

  @override
  void initState() {
    super.initState();
    cargarQr();
  }

  Future<void> cargarQr() async {
    if (widget.mascota.id == null) {
      setState(() {
        cargando = false;
        error = 'La mascota todavÃ­a no tiene un ID vÃ¡lido.';
      });
      return;
    }

    try {
      final valor = await ApiService.generarQr(widget.mascota.id!);

      if (!mounted) return;

      setState(() {
        token = valor;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final urlPublica = token == null ? null : '${ApiService.baseUrl}/p/$token';

    final urlQr = token == null
        ? null
        : '${ApiService.baseUrl}/api/public/qr/$token.png';

    return Scaffold(
      appBar: AppBar(title: const Text('CÃ³digo QR')),
      body: ListView(
        padding: const EdgeInsets.all(25),
        children: [
          const SizedBox(height: 20),
          if (cargando)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(60),
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: TaggyColors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: TaggyColors.red,
                    size: 50,
                  ),
                  const SizedBox(height: 10),
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 15),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        cargando = true;
                        error = null;
                      });
                      cargarQr();
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: TaggyColors.blue.withOpacity(0.25),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Image.network(
                urlQr!,
                width: 230,
                height: 230,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) {
                  return const Icon(
                    Icons.qr_code_2,
                    color: Colors.black,
                    size: 230,
                  );
                },
              ),
            ),
            const SizedBox(height: 25),
            Center(
              child: Text(
                widget.mascota.nombre,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              urlPublica!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: TaggyColors.cyan),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 53,
              child: FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: urlPublica!));

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enlace pÃºblico copiado')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar enlace pÃºblico'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 53,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PerfilPublicoPage(mascota: widget.mascota),
                    ),
                  );
                },
                icon: const Icon(Icons.public),
                label: const Text('Vista previa del perfil'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ======================================================
// PERFIL PÃšBLICO// ======================================================
// PERFIL PÃšBLICO
// ======================================================

class PerfilPublicoPage extends StatelessWidget {
  final Mascota mascota;

  const PerfilPublicoPage({super.key, required this.mascota});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TAGGY')),
      body: ListView(
        padding: const EdgeInsets.all(25),
        children: [
          Center(child: PetAvatar(size: 125, imagenPath: mascota.imagenPath)),

          const SizedBox(height: 20),

          Center(
            child: Text(
              mascota.nombre,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 8),

          Center(child: StatusBadge(extraviada: mascota.extraviada)),

          const SizedBox(height: 25),

          InfoCard(
            icono: Icons.pets,
            titulo: 'Raza',
            valor: valorSeguro(mascota.raza),
          ),

          InfoCard(
            icono: Icons.cake,
            titulo: 'Edad',
            valor: valorSeguro(mascota.edad),
          ),

          InfoCard(
            icono: Icons.palette,
            titulo: 'Color',
            valor: valorSeguro(mascota.color),
          ),

          const SizedBox(height: 18),

          SizedBox(
            height: 53,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contactando al propietario...'),
                  ),
                );
              },
              icon: const Icon(Icons.phone),
              label: const Text('Contactar propietario'),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 53,
            child: FilledButton.tonalIcon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Avistamiento enviado (simulaciÃ³n).'),
                  ),
                );
              },
              icon: const Icon(Icons.location_on),
              label: const Text('Reportar avistamiento'),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// SEGURIDAD
// ======================================================

class SeguridadPage extends StatefulWidget {
  const SeguridadPage({super.key});

  @override
  State<SeguridadPage> createState() => _SeguridadPageState();
}

class _SeguridadPageState extends State<SeguridadPage> {
  bool proteccion = true;
  bool mantenimiento = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seguridad')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF102A46), Color(0xFF0C192A)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  proteccion ? Icons.shield : Icons.shield_outlined,
                  size: 75,
                  color: proteccion ? TaggyColors.green : TaggyColors.red,
                ),

                const SizedBox(height: 12),

                Text(
                  proteccion ? 'ProtecciÃ³n activa' : 'ProtecciÃ³n desactivada',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          SwitchListTile(
            tileColor: TaggyColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            value: proteccion,
            onChanged: (value) {
              setState(() {
                proteccion = value;
              });
            },
            title: const Text('ProtecciÃ³n antirrobo'),
            subtitle: const Text('Activa las alertas de manipulaciÃ³n'),
          ),

          const SizedBox(height: 12),

          const InfoCard(
            icono: Icons.lock_outline,
            titulo: 'Sensor de carcasa',
            valor: 'Normal',
          ),

          const InfoCard(
            icono: Icons.link_outlined,
            titulo: 'Sensor de broche',
            valor: 'Cerrado',
          ),

          const InfoCard(
            icono: Icons.cell_tower,
            titulo: 'Ãšltima comunicaciÃ³n',
            valor: 'Hace 30 segundos',
          ),

          const SizedBox(height: 15),

          SwitchListTile(
            tileColor: TaggyColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            value: mantenimiento,
            onChanged: (value) {
              setState(() {
                mantenimiento = value;
              });
            },
            title: const Text('Modo mantenimiento'),
            subtitle: const Text('Evita alertas mientras manipulas el collar'),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// COMPONENTES DE DISEÃ‘O
// ======================================================

class TaggyLogo extends StatelessWidget {
  const TaggyLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [TaggyColors.blue, TaggyColors.cyan],
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.pets, color: Colors.white),
        ),

        const SizedBox(width: 12),

        const Text(
          'TAGGY',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class PetAvatar extends StatelessWidget {
  final double size;
  final String? imagenPath;

  const PetAvatar({super.key, this.size = 90, this.imagenPath});

  ImageProvider<Object>? _obtenerImagen() {
    final valor = imagenPath?.trim();

    if (valor == null || valor.isEmpty) {
      return null;
    }

    try {
      if (valor.startsWith('data:image/')) {
        final coma = valor.indexOf(',');

        if (coma == -1) {
          return null;
        }

        final base64Data = valor.substring(coma + 1);

        return MemoryImage(base64Decode(base64Data));
      }

      if (valor.startsWith('http://') || valor.startsWith('https://')) {
        return NetworkImage(valor);
      }
    } catch (e) {
      debugPrint('ERROR MOSTRANDO FOTO TAGGY: $e');
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imagen = _obtenerImagen();
    final existeImagen = imagen != null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: existeImagen
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [TaggyColors.blue, TaggyColors.cyan],
              ),
        image: existeImagen
            ? DecorationImage(image: imagen, fit: BoxFit.cover)
            : null,
        border: Border.all(
          color: TaggyColors.blue.withValues(alpha: 0.28),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: TaggyColors.blue.withValues(alpha: 0.22),
            blurRadius: 25,
          ),
        ],
      ),
      child: existeImagen
          ? null
          : Icon(Icons.pets, size: size * 0.52, color: Colors.white),
    );
  }
}

class MascotaPrincipalCard extends StatefulWidget {
  final Mascota mascota;

  const MascotaPrincipalCard({super.key, required this.mascota});

  @override
  State<MascotaPrincipalCard> createState() => _MascotaPrincipalCardState();
}

class _MascotaPrincipalCardState extends State<MascotaPrincipalCard> {
  bool cargando = true;

  bool gpsActivo = false;
  bool cuatroGOnline = false;

  String bateria = 'Sin dato';

  @override
  void initState() {
    super.initState();
    cargarEstadoReal();
  }

  @override
  void didUpdateWidget(covariant MascotaPrincipalCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.mascota.id != widget.mascota.id) {
      cargarEstadoReal();
    }
  }

  DateTime? _parsearFecha(dynamic valor) {
    if (valor == null) {
      return null;
    }

    try {
      return DateTime.parse(valor.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  bool _esReciente(DateTime? fecha, {int minutos = 10}) {
    if (fecha == null) {
      return false;
    }

    final diferencia = DateTime.now().difference(fecha);

    if (diferencia.isNegative) {
      return true;
    }

    return diferencia.inMinutes <= minutos;
  }

  String _formatearBateria(dynamic valor) {
    if (valor == null) {
      return 'Sin dato';
    }

    final numero = num.tryParse(valor.toString());

    if (numero == null) {
      return 'Sin dato';
    }

    return '${numero.round()}%';
  }

  Future<void> cargarEstadoReal() async {
    final mascotaId = widget.mascota.id;

    if (mascotaId == null) {
      if (!mounted) return;

      setState(() {
        cargando = false;
        gpsActivo = false;
        cuatroGOnline = false;
        bateria = 'Sin dato';
      });

      return;
    }

    if (mounted) {
      setState(() {
        cargando = true;
      });
    }

    try {
      final datos = await ApiService.obtenerUltimaUbicacion(mascotaId);

      final dispositivoRaw = datos['dispositivo'];

      final ubicacionRaw = datos['ubicacion'];

      final dispositivo = dispositivoRaw is Map
          ? Map<String, dynamic>.from(dispositivoRaw)
          : <String, dynamic>{};

      final ubicacion = ubicacionRaw is Map
          ? Map<String, dynamic>.from(ubicacionRaw)
          : <String, dynamic>{};

      final ultimaConexion = _parsearFecha(dispositivo['ultima_conexion']);

      final ultimaUbicacion = _parsearFecha(ubicacion['fecha_recepcion']);

      final latitud = ubicacion['latitud'];

      final longitud = ubicacion['longitud'];

      final tieneCoordenadas = latitud != null && longitud != null;

      if (!mounted) return;

      setState(() {
        cuatroGOnline = _esReciente(ultimaConexion, minutos: 10);

        gpsActivo =
            tieneCoordenadas && _esReciente(ultimaUbicacion, minutos: 10);

        bateria = _formatearBateria(dispositivo['bateria']);

        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargando = false;
        gpsActivo = false;
        cuatroGOnline = false;
        bateria = 'Sin dato';
      });

      debugPrint('ERROR ESTADO INICIO: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mascota = widget.mascota;

    final textoGps = cargando
        ? '...'
        : gpsActivo
        ? 'Activo'
        : 'Sin seÃ±al';

    final texto4G = cargando
        ? '...'
        : cuatroGOnline
        ? 'Online'
        : 'Offline';

    final textoBateria = cargando ? '...' : bateria;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF7F7F9)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: mascota.extraviada
              ? TaggyColors.red.withOpacity(0.5)
              : TaggyColors.blue.withOpacity(0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: TaggyColors.blue.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              PetAvatar(size: 72, imagenPath: mascota.imagenPath),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mascota.nombre,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${mascota.raza} â€¢ ${mascota.edad}',
                      style: const TextStyle(color: TaggyColors.textSecondary),
                    ),

                    const SizedBox(height: 9),

                    StatusBadge(extraviada: mascota.extraviada),
                  ],
                ),
              ),

              IconButton(
                tooltip: 'Actualizar estado',
                onPressed: cargando ? null : cargarEstadoReal,
                icon: cargando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: TaggyColors.textSecondary,
                      ),
              ),
            ],
          ),

          const SizedBox(height: 23),

          Row(
            children: [
              Expanded(
                child: MiniStatusCard(
                  icono: Icons.gps_fixed,
                  titulo: 'GPS',
                  valor: textoGps,
                  color: gpsActivo ? TaggyColors.green : TaggyColors.orange,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: MiniStatusCard(
                  icono: Icons.signal_cellular_alt,
                  titulo: '4G',
                  valor: texto4G,
                  color: cuatroGOnline ? TaggyColors.blue : TaggyColors.orange,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: MiniStatusCard(
                  icono: Icons.battery_5_bar,
                  titulo: 'BaterÃ­a',
                  valor: textoBateria,
                  color: TaggyColors.cyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MascotaListCard extends StatelessWidget {
  final Mascota mascota;
  final VoidCallback onTap;

  const MascotaListCard({
    super.key,
    required this.mascota,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TaggyColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              PetAvatar(size: 62, imagenPath: mascota.imagenPath),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mascota.nombre,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      '${mascota.raza} â€¢ ${mascota.edad}',
                      style: const TextStyle(color: TaggyColors.textSecondary),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      mascota.extraviada ? 'â— Extraviada' : 'â— Segura',
                      style: TextStyle(
                        color: mascota.extraviada
                            ? TaggyColors.red
                            : TaggyColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right, color: TaggyColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;
  final VoidCallback? onTap;

  const QuickActionCard({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TaggyColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: color),
              ),

              const Spacer(),

              Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitulo,
                style: const TextStyle(
                  color: TaggyColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MiniStatusCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  final Color color;

  const MiniStatusCard({
    super.key,
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: TaggyColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            titulo,
            style: const TextStyle(
              color: TaggyColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;

  const InfoCard({
    super.key,
    required this.icono,
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: TaggyColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF182B44)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: TaggyColors.blue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, color: TaggyColors.lightBlue),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: TaggyColors.textSecondary,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  valor,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AlertaCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final Color color;
  final String tiempo;

  const AlertaCard({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.color,
    required this.tiempo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TaggyColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icono, color: color),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  descripcion,
                  style: const TextStyle(
                    color: TaggyColors.textSecondary,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  tiempo,
                  style: TextStyle(color: color.withOpacity(0.9), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final bool extraviada;

  const StatusBadge({super.key, required this.extraviada});

  @override
  Widget build(BuildContext context) {
    final color = extraviada ? TaggyColors.red : TaggyColors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        extraviada ? 'â— EXTRAVIADA' : 'â— SEGURA',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String titulo;

  const SectionTitle({super.key, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Text(
      titulo,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
    );
  }
}

class CampoMascota extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icono;
  final bool requerido;

  const CampoMascota({
    super.key,
    required this.controller,
    required this.label,
    required this.icono,
    this.hint,
    this.requerido = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icono),
      ),
      validator: (value) {
        if (requerido && (value == null || value.trim().isEmpty)) {
          return 'Este campo es obligatorio';
        }

        return null;
      },
    );
  }
}

class DeviceStatusCard extends StatelessWidget {
  const DeviceStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TaggyColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(Icons.memory, color: TaggyColors.cyan, size: 34),

          SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Collar TAGGY',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),

                SizedBox(height: 3),

                Text(
                  'TAGGY-X72F82',
                  style: TextStyle(color: TaggyColors.textSecondary),
                ),
              ],
            ),
          ),

          StatusDot(),
        ],
      ),
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: const BoxDecoration(
        color: TaggyColors.green,
        shape: BoxShape.circle,
      ),
    );
  }
}

class EmptyMascotasCard extends StatelessWidget {
  final VoidCallback onPressed;

  const EmptyMascotasCard({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: TaggyColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(Icons.pets, size: 60, color: TaggyColors.textSecondary),

          const SizedBox(height: 15),

          const Text(
            'No tienes mascotas registradas',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add),
            label: const Text('Agregar mascota'),
          ),
        ],
      ),
    );
  }
}

String valorSeguro(String valor) {
  if (valor.trim().isEmpty) {
    return 'No especificado';
  }

  return valor;
}
