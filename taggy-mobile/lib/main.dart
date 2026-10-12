import 'services/api_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaggyApp());
}

// ======================================================
// COLORES TAGGY
// ======================================================

class TaggyColors {
  static const background = Color(0xFF07111F);
  static const surface = Color(0xFF0E1A2B);
  static const surfaceLight = Color(0xFF14243A);

  static const blue = Color(0xFF3B82F6);
  static const lightBlue = Color(0xFF38BDF8);
  static const cyan = Color(0xFF22D3EE);

  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF59E0B);

  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
}

// ======================================================
// MODELO MASCOTA
// ======================================================

class Mascota {
  String nombre;
  String raza;
  String edad;
  String sexo;
  String color;
  String peso;
  String idTaggy;
  bool extraviada;
  String? imagenPath;

  Mascota({
  required this.nombre,
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
    String? nombre,
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
    nombre: nombre ?? this.nombre,
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
      'nombre': nombre,
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
  return Mascota(
    nombre: json['nombre']?.toString() ?? '',
    raza: json['raza']?.toString() ?? '',
    edad: json['edad']?.toString() ?? '',
    sexo: json['sexo']?.toString() ?? '',
    color: json['color']?.toString() ?? '',
    peso: json['peso']?.toString() ?? '',

    idTaggy:
        json['device_uid']?.toString() ??
        'TAGGY-${json['id'] ?? ''}',

    extraviada:
        json['modo_extravio'] == true ||
        json['extraviada'] == true,

    // Por ahora no usamos foto_url aquí.
    // Lo conectaremos después con el servidor.
    imagenPath: json['imagenPath']?.toString(),
  );
}
}


// ======================================================
// FOTOS DE MASCOTAS
// ======================================================

// ======================================================
// FOTOS DE MASCOTAS
// ======================================================

Future<String?> seleccionarYGuardarImagen(
  BuildContext context,
) async {
  try {
    XFile? imagen;

    // WINDOWS
    if (Platform.isWindows) {
      final archivo = await FilePicker.pickFile(
        type: FileType.image,
      );

      if (archivo == null || archivo.path == null) {
        return null;
      }

      imagen = XFile(archivo.path!);
    }

    // ANDROID / IOS
    else {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: TaggyColors.surface,
        showDragHandle: true,
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                5,
                20,
                20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Foto de la mascota',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library_outlined,
                      color: TaggyColors.lightBlue,
                    ),
                    title: const Text(
                      'Elegir de la galería',
                    ),
                    onTap: () {
                      Navigator.pop(
                        sheetContext,
                        ImageSource.gallery,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.camera_alt_outlined,
                      color: TaggyColors.cyan,
                    ),
                    title: const Text(
                      'Tomar una foto',
                    ),
                    onTap: () {
                      Navigator.pop(
                        sheetContext,
                        ImageSource.camera,
                      );
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

      imagen = await picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
      );

      if (imagen == null) {
        return null;
      }
    }

    final directorio =
        await getApplicationDocumentsDirectory();

    final carpetaFotos = Directory(
      '${directorio.path}'
      '${Platform.pathSeparator}'
      'taggy_fotos',
    );

    if (!await carpetaFotos.exists()) {
      await carpetaFotos.create(
        recursive: true,
      );
    }

    final rutaOriginal = imagen.path.toLowerCase();

    String extension = '.jpg';

    if (rutaOriginal.endsWith('.png')) {
      extension = '.png';
    } else if (rutaOriginal.endsWith('.jpeg')) {
      extension = '.jpeg';
    } else if (rutaOriginal.endsWith('.webp')) {
      extension = '.webp';
    }

    final nombreArchivo =
        'mascota_${DateTime.now().millisecondsSinceEpoch}$extension';

    final nuevaRuta =
        '${carpetaFotos.path}'
        '${Platform.pathSeparator}'
        '$nombreArchivo';

    final archivoGuardado =
        await File(imagen.path).copy(
      nuevaRuta,
    );

    return archivoGuardado.path;
  } catch (e) {
    debugPrint(
      'ERROR FOTO TAGGY: $e',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo seleccionar la imagen: $e',
          ),
        ),
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
    final colorScheme = ColorScheme.fromSeed(
      seedColor: TaggyColors.blue,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TAGGY',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: TaggyColors.background,
        colorScheme: colorScheme.copyWith(
          primary: TaggyColors.blue,
          secondary: TaggyColors.cyan,
          surface: TaggyColors.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: TaggyColors.background,
          foregroundColor: TaggyColors.textPrimary,
          centerTitle: false,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: TaggyColors.surfaceLight,
          labelStyle: const TextStyle(
            color: TaggyColors.textSecondary,
          ),
          hintStyle: const TextStyle(
            color: TaggyColors.textSecondary,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF1E3552),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: TaggyColors.blue,
              width: 2,
            ),
          ),
        ),
      ),

      home: const AuthGate(),
    );
  }
}
// ======================================================
// CONTROL DE SESIÓN
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

    final sesion =
        prefs.getBool('taggy_logged_in') ?? false;

    if (!mounted) return;

    setState(() {
      sesionIniciada = sesion;
      cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (sesionIniciada) {
      return const HomePage();
    }

    return const LoginPage();
  }
}

// ======================================================
// INICIAR SESIÓN
// ======================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() =>
      _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final correoController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  bool ocultarPassword = true;

  Future<void> iniciarSesion() async {
  final correo = correoController.text.trim();
  final password = passwordController.text.trim();

  if (correo.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ingresa tu correo y contraseña.',
        ),
      ),
    );
    return;
  }

  try {
    await ApiService.login(
      email: correo,
      password: password,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Inicio de sesión correcto',
        ),
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePage(),
      ),
      (route) => false,
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.toString().replaceFirst(
                'Exception: ',
                '',
              ),
        ),
      ),
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
            padding:
                const EdgeInsets.all(25),
            child: Column(
              children: [
                Container(
                  width: 95,
                  height: 95,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        TaggyColors.blue,
                        TaggyColors.cyan,
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      28,
                    ),
                  ),
                  child: const Icon(
                    Icons.pets,
                    size: 55,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'TAGGY',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Protección inteligente para tu mascota',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color: TaggyColors
                        .textSecondary,
                  ),
                ),

                const SizedBox(height: 40),

                const Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Iniciar sesión',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller:
                      correoController,
                  keyboardType:
                      TextInputType
                          .emailAddress,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Correo electrónico',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                TextField(
                  controller:
                      passwordController,
                  obscureText:
                      ocultarPassword,
                  decoration:
                      InputDecoration(
                    labelText:
                        'Contraseña',
                    prefixIcon:
                        const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon:
                        IconButton(
                      onPressed: () {
                        setState(() {
                          ocultarPassword =
                              !ocultarPassword;
                        });
                      },
                      icon: Icon(
                        ocultarPassword
                            ? Icons
                                .visibility_outlined
                            : Icons
                                .visibility_off_outlined,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton(
                    onPressed:
                        iniciarSesion,
                    child: const Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    const Text(
                      '¿No tienes cuenta?',
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const RegistroPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Crear cuenta',
                      ),
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

class RegistroPage
    extends StatefulWidget {
  const RegistroPage({super.key});

  @override
  State<RegistroPage> createState() =>
      _RegistroPageState();
}

class _RegistroPageState
    extends State<RegistroPage> {
  final nombreController =
      TextEditingController();

  final correoController =
      TextEditingController();

  final telefonoController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  final confirmarController =
      TextEditingController();

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
      const SnackBar(
        content: Text(
          'Completa todos los campos.',
        ),
      ),
    );

    return;
  }

  if (password != confirmar) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Las contraseñas no coinciden.',
        ),
      ),
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

    // Después de crear la cuenta, inicia sesión automáticamente
    await ApiService.login(
      email: correo,
      password: password,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Cuenta creada correctamente',
        ),
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePage(),
      ),
      (route) => false,
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.toString().replaceFirst(
                'Exception: ',
                '',
              ),
        ),
      ),
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
      appBar: AppBar(
        title:
            const Text('Crear cuenta'),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(25),
        children: [
          const Text(
            'Crear cuenta TAGGY',
            style: TextStyle(
              fontSize: 28,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 25),

          TextField(
            controller:
                nombreController,
            decoration:
                const InputDecoration(
              labelText:
                  'Nombre completo',
              prefixIcon:
                  Icon(Icons.person),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller:
                correoController,
            decoration:
                const InputDecoration(
              labelText:
                  'Correo electrónico',
              prefixIcon:
                  Icon(Icons.email),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller:
                telefonoController,
            keyboardType:
                TextInputType.phone,
            decoration:
                const InputDecoration(
              labelText: 'Teléfono',
              prefixIcon:
                  Icon(Icons.phone),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller:
                passwordController,
            obscureText: true,
            decoration:
                const InputDecoration(
              labelText: 'Contraseña',
              prefixIcon:
                  Icon(Icons.lock),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller:
                confirmarController,
            obscureText: true,
            decoration:
                const InputDecoration(
              labelText:
                  'Confirmar contraseña',
              prefixIcon:
                  Icon(Icons.lock_reset),
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            height: 55,
            child: FilledButton.icon(
              onPressed: crearCuenta,
              icon: const Icon(
                Icons.person_add,
              ),
              label: const Text(
                'Crear cuenta',
              ),
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
      raza: 'Labrador',
      edad: '3 años',
      sexo: 'Macho',
      color: 'Amarillo',
      peso: '28 kg',
      idTaggy: 'TAGGY-X72F82',
    );
  }

Future<void> cargarMascotas() async {
  try {
    final lista = await ApiService.obtenerMascotas();

    mascotas = lista.map((item) {
      return Mascota.fromJson(
        Map<String, dynamic>.from(item),
      );
    }).toList();

    debugPrint(
      'Mascotas recibidas del backend: ${mascotas.length}',
    );
  } catch (e) {
    debugPrint(
      'ERROR AL CARGAR MASCOTAS: $e',
    );

    mascotas = [];

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudieron cargar las mascotas: $e',
            ),
          ),
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

    final datos = mascotas
        .map(
          (mascota) => mascota.toJson(),
        )
        .toList();

    await prefs.setString(
      storageKey,
      jsonEncode(datos),
    );
  }

  Future<void> agregarMascota(Mascota mascota) async {
  try {
    await ApiService.crearMascota(
      nombre: mascota.nombre,
      especie: 'Perro',
      raza: mascota.raza,
      sexo: mascota.sexo,
      color: mascota.color,
    );

    final lista = await ApiService.obtenerMascotas();

    final nuevasMascotas = lista.map((item) {
      return Mascota.fromJson(
        Map<String, dynamic>.from(item),
      );
    }).toList();

    if (!mounted) return;

    setState(() {
      mascotas = nuevasMascotas;
    });
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.toString().replaceFirst(
            'Exception: ',
            '',
          ),
        ),
      ),
    );

    rethrow;
  }
}

  Future<void> editarMascota(
    int index,
    Mascota mascotaActualizada,
  ) async {
    if (index < 0 || index >= mascotas.length) {
      return;
    }

    setState(() {
      mascotas[index] = mascotaActualizada;
    });

    await guardarMascotas();
  }

  Future<void> eliminarMascota(int index) async {
    if (index < 0 || index >= mascotas.length) {
      return;
    }

    setState(() {
      mascotas.removeAt(index);
    });

    await guardarMascotas();
  }

  Future<void> cambiarEstadoExtravio(
    int index,
    bool extraviada,
  ) async {
    if (index < 0 || index >= mascotas.length) {
      return;
    }

    setState(() {
      mascotas[index] = mascotas[index].copyWith(
        extraviada: extraviada,
      );
    });

    await guardarMascotas();
  }

  void cambiarPagina(int index) {
    setState(() {
      paginaActual = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
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
      UbicacionPage(
        mascotas: mascotas,
      ),
      AlertasPage(
        mascotas: mascotas,
      ),
      const PerfilPage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: paginaActual,
        children: paginas,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: TaggyColors.surface,
          border: Border(
            top: BorderSide(
              color: Color(0xFF182A42),
            ),
          ),
        ),
        child: NavigationBar(
          backgroundColor: TaggyColors.surface,
          indicatorColor: TaggyColors.blue.withOpacity(0.20),
          selectedIndex: paginaActual,
          onDestinationSelected: cambiarPagina,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(
                Icons.home_rounded,
                color: TaggyColors.lightBlue,
              ),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.pets_outlined),
              selectedIcon: Icon(
                Icons.pets,
                color: TaggyColors.lightBlue,
              ),
              label: 'Mascotas',
            ),
            NavigationDestination(
              icon: Icon(Icons.location_on_outlined),
              selectedIcon: Icon(
                Icons.location_on,
                color: TaggyColors.lightBlue,
              ),
              label: 'Ubicación',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(
                Icons.notifications,
                color: TaggyColors.lightBlue,
              ),
              label: 'Alertas',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(
                Icons.person,
                color: TaggyColors.lightBlue,
              ),
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

  final Future<void> Function(
    int index,
    bool extraviada,
  ) onEstadoExtravio;

  const InicioPage({
    super.key,
    required this.mascotas,
    required this.onCambiarPagina,
    required this.onEstadoExtravio,
  });

  @override
  Widget build(BuildContext context) {
    final Mascota? mascota =
        mascotas.isNotEmpty ? mascotas.first : null;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const TaggyLogo(),

          const SizedBox(height: 24),

          const Text(
            'Hola 👋',
            style: TextStyle(
              color: TaggyColors.textSecondary,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 3),

          const Text(
            'Bienvenido a TAGGY',
            style: TextStyle(
              color: TaggyColors.textPrimary,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 25),

          if (mascota == null)
            EmptyMascotasCard(
              onPressed: () {
                onCambiarPagina(1);
              },
            )
          else
            MascotaPrincipalCard(
              mascota: mascota,
            ),

          const SizedBox(height: 28),

          const SectionTitle(
            titulo: 'Accesos rápidos',
          ),

          const SizedBox(height: 15),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              QuickActionCard(
                titulo: 'Ubicación',
                subtitulo: 'Ver posición',
                icono: Icons.location_on_rounded,
                color: TaggyColors.blue,
                onTap: () {
                  onCambiarPagina(2);
                },
              ),
              QuickActionCard(
                titulo: 'Extravío',
                subtitulo: 'Modo perdido',
                icono: Icons.warning_amber_rounded,
                color: TaggyColors.red,
                onTap: mascota == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExtravioPage(
                              mascota: mascota,
                              onEstadoChanged: (estado) {
                                return onEstadoExtravio(
                                  0,
                                  estado,
                                );
                              },
                            ),
                          ),
                        );
                      },
              ),
              QuickActionCard(
                titulo: 'Código QR',
                subtitulo: 'Perfil público',
                icono: Icons.qr_code_2_rounded,
                color: TaggyColors.cyan,
                onTap: mascota == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QrPage(
                              mascota: mascota,
                            ),
                          ),
                        );
                      },
              ),
              QuickActionCard(
                titulo: 'Seguridad',
                subtitulo: 'Antirrobo',
                icono: Icons.shield_outlined,
                color: TaggyColors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const SeguridadPage(),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          const SectionTitle(
            titulo: 'Estado del dispositivo',
          ),

          const SizedBox(height: 15),

          const DeviceStatusCard(),
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

  final Future<void> Function(Mascota mascota)
      onAgregarMascota;

  final Future<void> Function(
    int index,
    Mascota mascota,
  ) onEditarMascota;

  final Future<void> Function(int index)
      onEliminarMascota;

  final Future<void> Function(
    int index,
    bool extraviada,
  ) onEstadoExtravio;

  const MascotasPage({
    super.key,
    required this.mascotas,
    required this.onAgregarMascota,
    required this.onEditarMascota,
    required this.onEliminarMascota,
    required this.onEstadoExtravio,
  });

  Future<void> abrirAgregarMascota(
    BuildContext context,
  ) async {
    final nuevaMascota =
        await Navigator.push<Mascota>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AgregarMascotaPage(),
      ),
    );

    if (nuevaMascota == null) {
      return;
    }

    await onAgregarMascota(nuevaMascota);

    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor:
              TaggyColors.surfaceLight,
          content: Text(
            '${nuevaMascota.nombre} fue agregada correctamente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          10,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const TaggyLogo(),

            const SizedBox(height: 25),

            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mis mascotas',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Administra tus mascotas',
                        style: TextStyle(
                          color: TaggyColors
                              .textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: TaggyColors.blue
                        .withOpacity(0.15),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${mascotas.length}',
                    style: const TextStyle(
                      color:
                          TaggyColors.lightBlue,
                      fontWeight:
                          FontWeight.bold,
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
                        style: TextStyle(
                          color: TaggyColors
                              .textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount:
                          mascotas.length,
                      separatorBuilder:
                          (_, __) =>
                              const SizedBox(
                        height: 12,
                      ),
                      itemBuilder:
                          (context, index) {
                        final mascota =
                            mascotas[index];

                        return MascotaListCard(
                          mascota: mascota,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DetalleMascotaPage(
                                  mascota:
                                      mascota,
                                  onEditar:
                                      (actualizada) {
                                    return onEditarMascota(
                                      index,
                                      actualizada,
                                    );
                                  },
                                  onEliminar:
                                      () {
                                    return onEliminarMascota(
                                      index,
                                    );
                                  },
                                  onEstadoChanged:
                                      (estado) {
                                    return onEstadoExtravio(
                                      index,
                                      estado,
                                    );
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
                  abrirAgregarMascota(
                    context,
                  );
                },
                icon:
                    const Icon(Icons.add),
                label: const Text(
                  'Agregar mascota',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
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

class AgregarMascotaPage
    extends StatefulWidget {
  const AgregarMascotaPage({super.key});

  @override
  State<AgregarMascotaPage> createState() =>
      _AgregarMascotaPageState();
}

class _AgregarMascotaPageState
    extends State<AgregarMascotaPage> {
  final formKey = GlobalKey<FormState>();

  final nombreController =
      TextEditingController();

  final razaController =
      TextEditingController();

  final edadController =
      TextEditingController();

  final colorController =
      TextEditingController();

  final pesoController =
      TextEditingController();

  String sexo = 'Macho';
  String? imagenPath;

  Future<void> agregarFoto() async {
    final nuevaImagen =
        await seleccionarYGuardarImagen(context);

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

    final timestamp = DateTime.now()
        .millisecondsSinceEpoch
        .toString();

    final codigo = timestamp.substring(
      timestamp.length - 6,
    );

    final mascota = Mascota(
      nombre: nombreController.text.trim(),
      raza: razaController.text.trim(),
      edad: edadController.text.trim(),
      sexo: sexo,
      color: colorController.text.trim(),
      peso: pesoController.text.trim(),
      idTaggy: 'TAGGY-$codigo',
      imagenPath: imagenPath,
    );

    Navigator.pop(
      context,
      mascota,
    );
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
      appBar: AppBar(
        title:
            const Text('Nueva mascota'),
      ),
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
                        PetAvatar(
                          size: 118,
                          imagenPath: imagenPath,
                        ),
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
                      imagenPath == null
                          ? 'Agregar foto'
                          : 'Cambiar foto',
                    ),
                  ),
                  const Text(
                    'Puedes elegir una imagen de tu galería o usar la cámara.',
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
              hint: 'Ejemplo: 3 años',
              icono: Icons.cake_outlined,
            ),

            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              initialValue: sexo,
              decoration:
                  const InputDecoration(
                labelText: 'Sexo',
                prefixIcon: Icon(
                  Icons.info_outline,
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Macho',
                  child: Text('Macho'),
                ),
                DropdownMenuItem(
                  value: 'Hembra',
                  child: Text('Hembra'),
                ),
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
              icono:
                  Icons.palette_outlined,
            ),

            const SizedBox(height: 15),

            CampoMascota(
              controller: pesoController,
              label: 'Peso',
              hint: 'Ejemplo: 28 kg',
              icono:
                  Icons.monitor_weight_outlined,
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 55,
              child: FilledButton.icon(
                onPressed: guardar,
                icon:
                    const Icon(Icons.save),
                label: const Text(
                  'Guardar mascota',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
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

class DetalleMascotaPage
    extends StatefulWidget {
  final Mascota mascota;

  final Future<void> Function(
    Mascota mascota,
  ) onEditar;

  final Future<void> Function()
      onEliminar;

  final Future<void> Function(bool estado)
      onEstadoChanged;

  const DetalleMascotaPage({
    super.key,
    required this.mascota,
    required this.onEditar,
    required this.onEliminar,
    required this.onEstadoChanged,
  });

  @override
  State<DetalleMascotaPage> createState() =>
      _DetalleMascotaPageState();
}

class _DetalleMascotaPageState
    extends State<DetalleMascotaPage> {
  late Mascota mascota;

  @override
  void initState() {
    super.initState();
    mascota = widget.mascota;
  }

  Future<void> editar() async {
    final actualizada =
        await Navigator.push<Mascota>(
      context,
      MaterialPageRoute(
        builder: (_) => EditarMascotaPage(
          mascota: mascota,
        ),
      ),
    );

    if (actualizada == null) {
      return;
    }

    await widget.onEditar(actualizada);

    if (mounted) {
      setState(() {
        mascota = actualizada;
      });
    }
  }

  Future<void> cambiarExtravio() async {
    final nuevoEstado =
        !mascota.extraviada;

    await widget.onEstadoChanged(
      nuevoEstado,
    );

    if (mounted) {
      setState(() {
        mascota = mascota.copyWith(
          extraviada: nuevoEstado,
        );
      });
    }
  }

  Future<void> eliminar() async {
    final confirmado =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              TaggyColors.surface,
          title: const Text(
            'Eliminar mascota',
          ),
          content: Text(
            '¿Seguro que deseas eliminar a ${mascota.nombre}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text('Cancelar'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    TaggyColors.red,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmado != true) {
      return;
    }

    await widget.onEliminar();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(mascota.nombre),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: PetAvatar(
              size: 120,
              imagenPath: mascota.imagenPath,
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: Text(
              mascota.nombre,
              style: const TextStyle(
                fontSize: 30,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: StatusBadge(
              extraviada:
                  mascota.extraviada,
            ),
          ),

          const SizedBox(height: 30),

          InfoCard(
            icono: Icons.category,
            titulo: 'Raza',
            valor: valorSeguro(
              mascota.raza,
            ),
          ),

          InfoCard(
            icono: Icons.cake,
            titulo: 'Edad',
            valor: valorSeguro(
              mascota.edad,
            ),
          ),

          InfoCard(
            icono: Icons.info_outline,
            titulo: 'Sexo',
            valor: valorSeguro(
              mascota.sexo,
            ),
          ),

          InfoCard(
            icono: Icons.palette,
            titulo: 'Color',
            valor: valorSeguro(
              mascota.color,
            ),
          ),

          InfoCard(
            icono:
                Icons.monitor_weight,
            titulo: 'Peso',
            valor: valorSeguro(
              mascota.peso,
            ),
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
              icon:
                  const Icon(Icons.edit),
              label: const Text(
                'Editar mascota',
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 52,
            child:
                FilledButton.tonalIcon(
              onPressed:
                  cambiarExtravio,
              icon: Icon(
                mascota.extraviada
                    ? Icons.check_circle
                    : Icons.warning_amber,
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
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    TaggyColors.red,
                side: const BorderSide(
                  color:
                      TaggyColors.red,
                ),
              ),
              onPressed: eliminar,
              icon:
                  const Icon(Icons.delete),
              label: const Text(
                'Eliminar mascota',
              ),
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

class EditarMascotaPage
    extends StatefulWidget {
  final Mascota mascota;

  const EditarMascotaPage({
    super.key,
    required this.mascota,
  });

  @override
  State<EditarMascotaPage> createState() =>
      _EditarMascotaPageState();
}

class _EditarMascotaPageState
    extends State<EditarMascotaPage> {
  final formKey = GlobalKey<FormState>();

  late TextEditingController nombreController;
  late TextEditingController razaController;
  late TextEditingController edadController;
  late TextEditingController colorController;
  late TextEditingController pesoController;

  late String sexo;
  String? imagenPath;

  @override
  void initState() {
    super.initState();

    nombreController =
        TextEditingController(
      text: widget.mascota.nombre,
    );

    razaController =
        TextEditingController(
      text: widget.mascota.raza,
    );

    edadController =
        TextEditingController(
      text: widget.mascota.edad,
    );

    colorController =
        TextEditingController(
      text: widget.mascota.color,
    );

    pesoController =
        TextEditingController(
      text: widget.mascota.peso,
    );

    sexo = widget.mascota.sexo == 'Hembra'
        ? 'Hembra'
        : 'Macho';

    imagenPath = widget.mascota.imagenPath;
  }

  Future<void> cambiarFoto() async {
    final nuevaImagen =
        await seleccionarYGuardarImagen(context);

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

    final actualizada =
        widget.mascota.copyWith(
      nombre: nombreController.text.trim(),
      raza: razaController.text.trim(),
      edad: edadController.text.trim(),
      sexo: sexo,
      color: colorController.text.trim(),
      peso: pesoController.text.trim(),
      imagenPath: imagenPath,
    );

    Navigator.pop(
      context,
      actualizada,
    );
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
      appBar: AppBar(
        title:
            const Text('Editar mascota'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding:
              const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: cambiarFoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        PetAvatar(
                          size: 112,
                          imagenPath: imagenPath,
                        ),
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
                    icon: const Icon(
                      Icons.photo_library_outlined,
                    ),
                    label: Text(
                      imagenPath == null
                          ? 'Agregar foto'
                          : 'Cambiar foto',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            CampoMascota(
              controller:
                  nombreController,
              label: 'Nombre',
              icono: Icons.pets,
              requerido: true,
            ),

            const SizedBox(height: 15),

            CampoMascota(
              controller: razaController,
              label: 'Raza',
              icono:
                  Icons.category_outlined,
              requerido: true,
            ),

            const SizedBox(height: 15),

            CampoMascota(
              controller: edadController,
              label: 'Edad',
              icono:
                  Icons.cake_outlined,
            ),

            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              initialValue: sexo,
              decoration:
                  const InputDecoration(
                labelText: 'Sexo',
                prefixIcon:
                    Icon(Icons.info_outline),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Macho',
                  child: Text('Macho'),
                ),
                DropdownMenuItem(
                  value: 'Hembra',
                  child: Text('Hembra'),
                ),
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
              controller:
                  colorController,
              label: 'Color',
              icono:
                  Icons.palette_outlined,
            ),

            const SizedBox(height: 15),

            CampoMascota(
              controller:
                  pesoController,
              label: 'Peso',
              icono: Icons
                  .monitor_weight_outlined,
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: guardar,
                icon:
                    const Icon(Icons.save),
                label: const Text(
                  'Guardar cambios',
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
// UBICACIÓN
// ======================================================

class UbicacionPage extends StatelessWidget {
  final List<Mascota> mascotas;

  const UbicacionPage({
    super.key,
    required this.mascotas,
  });

  @override
  Widget build(BuildContext context) {
    final mascota =
        mascotas.isNotEmpty ? mascotas.first : null;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const TaggyLogo(),

          const SizedBox(height: 25),

          const Text(
            'Ubicación',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Seguimiento GPS del collar',
            style: TextStyle(
              color:
                  TaggyColors.textSecondary,
            ),
          ),

          const SizedBox(height: 22),

          Container(
            height: 330,
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(
                begin: Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: [
                  Color(0xFF10243E),
                  Color(0xFF081624),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(24),
              border: Border.all(
                color:
                    const Color(0xFF1D3A5C),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.all(
                      18,
                    ),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TaggyColors.blue
                          .withOpacity(0.15),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      size: 65,
                      color:
                          TaggyColors.lightBlue,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    mascota == null
                        ? 'Sin mascota'
                        : mascota.nombre,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Guadalajara, Jalisco',
                    style: TextStyle(
                      color: TaggyColors
                          .textSecondary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    '20.6736, -103.3440',
                    style: TextStyle(
                      color:
                          TaggyColors.cyan,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Row(
            children: [
              Expanded(
                child: MiniStatusCard(
                  icono:
                      Icons.gps_fixed,
                  titulo: 'GPS',
                  valor: 'Activo',
                  color:
                      TaggyColors.green,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: MiniStatusCard(
                  icono: Icons
                      .signal_cellular_alt,
                  titulo: '4G',
                  valor: 'Conectado',
                  color:
                      TaggyColors.blue,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: MiniStatusCard(
                  icono:
                      Icons.battery_5_bar,
                  titulo: 'Batería',
                  valor: '78%',
                  color:
                      TaggyColors.cyan,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const InfoCard(
            icono: Icons.access_time,
            titulo:
                'Última actualización',
            valor: 'Hace 2 minutos',
          ),
        ],
      ),
    );
  }
}

// ======================================================
// ALERTAS
// ======================================================

class AlertasPage extends StatelessWidget {
  final List<Mascota> mascotas;

  const AlertasPage({
    super.key,
    required this.mascotas,
  });

  @override
  Widget build(BuildContext context) {
    final algunaExtraviada =
        mascotas.any(
      (mascota) => mascota.extraviada,
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const TaggyLogo(),

          const SizedBox(height: 25),

          const Text(
            'Alertas',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Actividad reciente de TAGGY',
            style: TextStyle(
              color:
                  TaggyColors.textSecondary,
            ),
          ),

          const SizedBox(height: 22),

          if (algunaExtraviada)
            const AlertaCard(
              icono:
                  Icons.warning_amber_rounded,
              titulo:
                  'Modo extravío activo',
              descripcion:
                  'Una de tus mascotas está marcada como extraviada.',
              color: TaggyColors.red,
              tiempo: 'Ahora',
            ),

          const AlertaCard(
            icono: Icons.qr_code,
            titulo:
                'Código QR escaneado',
            descripcion:
                'Alguien consultó el perfil público de Max.',
            color: TaggyColors.cyan,
            tiempo: 'Hace 5 min',
          ),

          const AlertaCard(
            icono: Icons.location_on,
            titulo:
                'Nueva ubicación',
            descripcion:
                'Se recibió una actualización GPS.',
            color: TaggyColors.blue,
            tiempo: 'Hace 12 min',
          ),

          const AlertaCard(
            icono:
                Icons.battery_alert,
            titulo: 'Batería baja',
            descripcion:
                'El collar llegó a 15% de batería.',
            color: TaggyColors.orange,
            tiempo: 'Ayer',
          ),

          const AlertaCard(
            icono: Icons.shield_outlined,
            titulo:
                'Posible manipulación',
            descripcion:
                'El sensor del collar detectó una apertura.',
            color: TaggyColors.red,
            tiempo: 'Ayer',
          ),
        ],
      ),
    );
  }
}

// ======================================================
// PERFIL
// ======================================================

class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});
    Future<void> cerrarSesion(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('taggy_logged_in', false);
    await prefs.remove('taggy_token');

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const TaggyLogo(),

          const SizedBox(height: 25),

          const Text(
            'Mi perfil',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 25),

          Center(
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    const LinearGradient(
                  colors: [
                    TaggyColors.blue,
                    TaggyColors.cyan,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: TaggyColors.blue
                        .withOpacity(0.25),
                    blurRadius: 25,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                size: 60,
              ),
            ),
          ),

          const SizedBox(height: 18),

          const Center(
            child: Text(
              'Joshua Alejandro',
              style: TextStyle(
                fontSize: 23,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 30),

          const InfoCard(
            icono: Icons.email_outlined,
            titulo: 'Correo',
            valor: 'usuario@taggy.mx',
          ),

          const InfoCard(
            icono: Icons.phone_outlined,
            titulo: 'Teléfono',
            valor: '33 0000 0000',
          ),

          const InfoCard(
            icono:
                Icons.notifications_outlined,
            titulo: 'Notificaciones',
            valor: 'Activadas',
          ),

          const InfoCard(
            icono:
                Icons.security_outlined,
            titulo: 'Seguridad',
            valor: 'Protección activa',
          ),
          const SizedBox(height: 25),

SizedBox(
  height: 54,
  child: OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: TaggyColors.red,
      side: const BorderSide(
        color: TaggyColors.red,
      ),
    ),
    onPressed: () => cerrarSesion(context),
    icon: const Icon(Icons.logout),
    label: const Text(
      'Cerrar sesión',
      style: TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
),
        ],
      ),
      
    );
  }
}

// ======================================================
// EXTRAVÍO
// ======================================================

class ExtravioPage
    extends StatefulWidget {
  final Mascota mascota;

  final Future<void> Function(
    bool estado,
  ) onEstadoChanged;

  const ExtravioPage({
    super.key,
    required this.mascota,
    required this.onEstadoChanged,
  });

  @override
  State<ExtravioPage> createState() =>
      _ExtravioPageState();
}

class _ExtravioPageState
    extends State<ExtravioPage> {
  late bool extraviada;

  @override
  void initState() {
    super.initState();
    extraviada =
        widget.mascota.extraviada;
  }

  Future<void> cambiarEstado() async {
    final nuevoEstado = !extraviada;

    await widget.onEstadoChanged(
      nuevoEstado,
    );

    if (mounted) {
      setState(() {
        extraviada = nuevoEstado;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Modo extravío')),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              padding:
                  const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: extraviada
                    ? TaggyColors.red
                        .withOpacity(0.15)
                    : TaggyColors.green
                        .withOpacity(0.15),
              ),
              child: Icon(
                extraviada
                    ? Icons.warning_rounded
                    : Icons.check_circle,
                size: 100,
                color: extraviada
                    ? TaggyColors.red
                    : TaggyColors.green,
              ),
            ),

            const SizedBox(height: 30),

            Text(
              extraviada
                  ? '${widget.mascota.nombre} está extraviado'
                  : '${widget.mascota.nombre} está seguro',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              extraviada
                  ? 'El perfil público mostrará que la mascota está perdida.'
                  : 'No hay ningún reporte de extravío activo.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color:
                    TaggyColors.textSecondary,
              ),
            ),

            const SizedBox(height: 35),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton.icon(
                style:
                    FilledButton.styleFrom(
                  backgroundColor:
                      extraviada
                          ? TaggyColors.green
                          : TaggyColors.red,
                ),
                onPressed: cambiarEstado,
                icon: Icon(
                  extraviada
                      ? Icons.check
                      : Icons.warning,
                ),
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

class QrPage extends StatelessWidget {
  final Mascota mascota;

  const QrPage({
    super.key,
    required this.mascota,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Código QR')),
      body: ListView(
        padding: const EdgeInsets.all(25),
        children: [
          const SizedBox(height: 20),

          Container(
            padding:
                const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: TaggyColors.blue
                      .withOpacity(0.25),
                  blurRadius: 30,
                ),
              ],
            ),
            child: const Icon(
              Icons.qr_code_2,
              color: Colors.black,
              size: 230,
            ),
          ),

          const SizedBox(height: 25),

          Center(
            child: Text(
              mascota.nombre,
              style: const TextStyle(
                fontSize: 28,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 5),

          Center(
            child: Text(
              mascota.idTaggy,
              style: const TextStyle(
                color: TaggyColors.cyan,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            height: 53,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PerfilPublicoPage(
                      mascota: mascota,
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.public,
              ),
              label: const Text(
                'Ver perfil público',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// PERFIL PÚBLICO
// ======================================================

class PerfilPublicoPage
    extends StatelessWidget {
  final Mascota mascota;

  const PerfilPublicoPage({
    super.key,
    required this.mascota,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('TAGGY')),
      body: ListView(
        padding: const EdgeInsets.all(25),
        children: [
          Center(
            child: PetAvatar(
              size: 125,
              imagenPath: mascota.imagenPath,
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: Text(
              mascota.nombre,
              style: const TextStyle(
                fontSize: 32,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: StatusBadge(
              extraviada:
                  mascota.extraviada,
            ),
          ),

          const SizedBox(height: 25),

          InfoCard(
            icono: Icons.pets,
            titulo: 'Raza',
            valor:
                valorSeguro(mascota.raza),
          ),

          InfoCard(
            icono: Icons.cake,
            titulo: 'Edad',
            valor:
                valorSeguro(mascota.edad),
          ),

          InfoCard(
            icono: Icons.palette,
            titulo: 'Color',
            valor:
                valorSeguro(mascota.color),
          ),

          const SizedBox(height: 18),

          SizedBox(
            height: 53,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Contactando al propietario...',
                    ),
                  ),
                );
              },
              icon:
                  const Icon(Icons.phone),
              label: const Text(
                'Contactar propietario',
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 53,
            child:
                FilledButton.tonalIcon(
              onPressed: () {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Avistamiento enviado (simulación).',
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.location_on,
              ),
              label: const Text(
                'Reportar avistamiento',
              ),
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

class SeguridadPage
    extends StatefulWidget {
  const SeguridadPage({super.key});

  @override
  State<SeguridadPage> createState() =>
      _SeguridadPageState();
}

class _SeguridadPageState
    extends State<SeguridadPage> {
  bool proteccion = true;
  bool mantenimiento = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Seguridad')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding:
                const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xFF102A46),
                  Color(0xFF0C192A),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  proteccion
                      ? Icons.shield
                      : Icons.shield_outlined,
                  size: 75,
                  color: proteccion
                      ? TaggyColors.green
                      : TaggyColors.red,
                ),

                const SizedBox(height: 12),

                Text(
                  proteccion
                      ? 'Protección activa'
                      : 'Protección desactivada',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          SwitchListTile(
            tileColor:
                TaggyColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(18),
            ),
            value: proteccion,
            onChanged: (value) {
              setState(() {
                proteccion = value;
              });
            },
            title: const Text(
              'Protección antirrobo',
            ),
            subtitle: const Text(
              'Activa las alertas de manipulación',
            ),
          ),

          const SizedBox(height: 12),

          const InfoCard(
            icono:
                Icons.lock_outline,
            titulo:
                'Sensor de carcasa',
            valor: 'Normal',
          ),

          const InfoCard(
            icono:
                Icons.link_outlined,
            titulo: 'Sensor de broche',
            valor: 'Cerrado',
          ),

          const InfoCard(
            icono:
                Icons.cell_tower,
            titulo:
                'Última comunicación',
            valor: 'Hace 30 segundos',
          ),

          const SizedBox(height: 15),

          SwitchListTile(
            tileColor:
                TaggyColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(18),
            ),
            value: mantenimiento,
            onChanged: (value) {
              setState(() {
                mantenimiento = value;
              });
            },
            title: const Text(
              'Modo mantenimiento',
            ),
            subtitle: const Text(
              'Evita alertas mientras manipulas el collar',
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// COMPONENTES DE DISEÑO
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
            gradient:
                const LinearGradient(
              colors: [
                TaggyColors.blue,
                TaggyColors.cyan,
              ],
            ),
            borderRadius:
                BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.pets,
            color: Colors.white,
          ),
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

  const PetAvatar({
    super.key,
    this.size = 90,
    this.imagenPath,
  });

  @override
  Widget build(BuildContext context) {
    final existeImagen =
        imagenPath != null &&
        imagenPath!.isNotEmpty &&
        File(imagenPath!).existsSync();

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
                colors: [
                  TaggyColors.blue,
                  TaggyColors.cyan,
                ],
              ),
        image: existeImagen
            ? DecorationImage(
                image: FileImage(
                  File(imagenPath!),
                ),
                fit: BoxFit.cover,
              )
            : null,
        border: Border.all(
          color: TaggyColors.blue.withValues(
            alpha: 0.28,
          ),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: TaggyColors.blue.withValues(
              alpha: 0.22,
            ),
            blurRadius: 25,
          ),
        ],
      ),
      child: existeImagen
          ? null
          : Icon(
              Icons.pets,
              size: size * 0.52,
              color: Colors.white,
            ),
    );
  }
}

class MascotaPrincipalCard
    extends StatelessWidget {
  final Mascota mascota;

  const MascotaPrincipalCard({
    super.key,
    required this.mascota,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF132B49),
            Color(0xFF0B1727),
          ],
        ),
        borderRadius:
            BorderRadius.circular(26),
        border: Border.all(
          color: mascota.extraviada
              ? TaggyColors.red
                  .withOpacity(0.5)
              : TaggyColors.blue
                  .withOpacity(0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: TaggyColors.blue
                .withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              PetAvatar(
                size: 72,
                imagenPath: mascota.imagenPath,
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      mascota.nombre,
                      style:
                          const TextStyle(
                        fontSize: 25,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${mascota.raza} • ${mascota.edad}',
                      style:
                          const TextStyle(
                        color: TaggyColors
                            .textSecondary,
                      ),
                    ),

                    const SizedBox(height: 9),

                    StatusBadge(
                      extraviada:
                          mascota.extraviada,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 23),

          const Row(
            children: [
              Expanded(
                child: MiniStatusCard(
                  icono:
                      Icons.gps_fixed,
                  titulo: 'GPS',
                  valor: 'Activo',
                  color:
                      TaggyColors.green,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: MiniStatusCard(
                  icono: Icons
                      .signal_cellular_alt,
                  titulo: '4G',
                  valor: 'Online',
                  color:
                      TaggyColors.blue,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: MiniStatusCard(
                  icono:
                      Icons.battery_5_bar,
                  titulo: 'Batería',
                  valor: '78%',
                  color:
                      TaggyColors.cyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MascotaListCard
    extends StatelessWidget {
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
      borderRadius:
          BorderRadius.circular(20),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(15),
          child: Row(
            children: [
              PetAvatar(
                size: 62,
                imagenPath: mascota.imagenPath,
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      mascota.nombre,
                      style:
                          const TextStyle(
                        fontSize: 19,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      '${mascota.raza} • ${mascota.edad}',
                      style:
                          const TextStyle(
                        color: TaggyColors
                            .textSecondary,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      mascota.extraviada
                          ? '● Extraviada'
                          : '● Segura',
                      style: TextStyle(
                        color:
                            mascota.extraviada
                                ? TaggyColors
                                    .red
                                : TaggyColors
                                    .green,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right,
                color:
                    TaggyColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickActionCard
    extends StatelessWidget {
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
      borderRadius:
          BorderRadius.circular(20),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.all(
                  9,
                ),
                decoration: BoxDecoration(
                  color:
                      color.withOpacity(
                    0.14,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  icono,
                  color: color,
                ),
              ),

              const Spacer(),

              Text(
                titulo,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitulo,
                style: const TextStyle(
                  color: TaggyColors
                      .textSecondary,
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

class MiniStatusCard
    extends StatelessWidget {
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
      padding:
          const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color:
            TaggyColors.surfaceLight,
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            icono,
            color: color,
            size: 22,
          ),

          const SizedBox(height: 6),

          Text(
            titulo,
            style: const TextStyle(
              color: TaggyColors
                  .textSecondary,
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            valor,
            style: const TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.bold,
            ),
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
      margin:
          const EdgeInsets.only(
        bottom: 11,
      ),
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: TaggyColors.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xFF182B44),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.all(
              10,
            ),
            decoration: BoxDecoration(
              color: TaggyColors.blue
                  .withOpacity(0.12),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              icono,
              color:
                  TaggyColors.lightBlue,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style:
                      const TextStyle(
                    color: TaggyColors
                        .textSecondary,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  valor,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
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
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TaggyColors.surface,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.all(
              11,
            ),
            decoration: BoxDecoration(
              color:
                  color.withOpacity(0.14),
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child: Icon(
              icono,
              color: color,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  descripcion,
                  style:
                      const TextStyle(
                    color: TaggyColors
                        .textSecondary,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  tiempo,
                  style: TextStyle(
                    color:
                        color.withOpacity(
                      0.9,
                    ),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge
    extends StatelessWidget {
  final bool extraviada;

  const StatusBadge({
    super.key,
    required this.extraviada,
  });

  @override
  Widget build(BuildContext context) {
    final color = extraviada
        ? TaggyColors.red
        : TaggyColors.green;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        extraviada
            ? '● EXTRAVIADA'
            : '● SEGURA',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class SectionTitle
    extends StatelessWidget {
  final String titulo;

  const SectionTitle({
    super.key,
    required this.titulo,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      titulo,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class CampoMascota
    extends StatelessWidget {
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
        if (requerido &&
            (value == null ||
                value.trim().isEmpty)) {
          return 'Este campo es obligatorio';
        }

        return null;
      },
    );
  }
}

class DeviceStatusCard
    extends StatelessWidget {
  const DeviceStatusCard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TaggyColors.surface,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.memory,
            color: TaggyColors.cyan,
            size: 34,
          ),

          SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Collar TAGGY',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                SizedBox(height: 3),

                Text(
                  'TAGGY-X72F82',
                  style: TextStyle(
                    color: TaggyColors
                        .textSecondary,
                  ),
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
      decoration:
          const BoxDecoration(
        color: TaggyColors.green,
        shape: BoxShape.circle,
      ),
    );
  }
}

class EmptyMascotasCard
    extends StatelessWidget {
  final VoidCallback onPressed;

  const EmptyMascotasCard({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: TaggyColors.surface,
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.pets,
            size: 60,
            color:
                TaggyColors.textSecondary,
          ),

          const SizedBox(height: 15),

          const Text(
            'No tienes mascotas registradas',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 15),

          FilledButton.icon(
            onPressed: onPressed,
            icon:
                const Icon(Icons.add),
            label: const Text(
              'Agregar mascota',
            ),
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